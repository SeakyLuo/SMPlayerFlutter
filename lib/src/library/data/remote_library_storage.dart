part of 'library_repository.dart';

mixin _RemoteLibraryStorage implements LibraryDataSource {
  MusicShareAccess get access;
  LibraryRepository get repository;
  @override
  RemoteLibrarySource get source;

  Future<Map<String, dynamic>> _storage(
    String path,
    String operation, {
    String? name,
    Map<String, dynamic> values = const {},
  }) => access.directoryOperation(
    source.deviceId,
    path,
    operation,
    name: name,
    values: values,
  );

  LibraryStorageChange _change(
    Map<String, dynamic> result,
    int count, {
    Set<int> deletedSongIds = const {},
    Set<String> deletedSongPaths = const {},
    Set<String> overwrittenSongPaths = const {},
    bool directoryOnly = false,
  }) {
    final ticket = result['ticket'] as String;
    return LibraryStorageChange(
      source: source,
      count: count,
      deletedSongIds: deletedSongIds,
      deletedSongPaths: deletedSongPaths,
      overwrittenSongPaths: overwrittenSongPaths,
      directoryOnly: directoryOnly,
      undo: () async {
        await _storage('', 'undo', values: {'ticket': ticket});
      },
      commit: () async {
        await _storage('', 'commit', values: {'ticket': ticket});
      },
    );
  }

  @override
  Future<LibraryStorageChange> deleteStorageItems(
    Map<int, String> songs,
    List<String> folders,
  ) async {
    final result = await _storage(
      '',
      'delete',
      values: {
        'songs':
            songs.values
                .map((song) => int.parse(Uri.parse(song).pathSegments.single))
                .toList(),
        'folders':
            folders
                .map((path) => Uri.parse(path).pathSegments.join('/'))
                .toList(),
      },
    );
    return _change(
      result,
      result['count'] as int,
      deletedSongIds: songs.keys.toSet(),
      deletedSongPaths: {
        // Hosts that predate this field only report the explicit selection.
        if (result['deletedSongIds'] case final List ids)
          for (final id in ids.cast<int>())
            remoteMusicPath(source.deviceId, id),
      },
    );
  }

  @override
  Future<LibraryStorageChange> moveStorageItems(
    Map<int, String> songs,
    List<String> folders,
    String target, {
    required LocalMoveConflictResolver resolveConflict,
  }) async {
    final path = Uri.parse(target).pathSegments.join('/');
    final values = <String, dynamic>{
      'songs':
          songs.values
              .map((song) => int.parse(Uri.parse(song).pathSegments.single))
              .toList(),
      'folders':
          folders
              .map((folder) => Uri.parse(folder).pathSegments.join('/'))
              .toList(),
    };
    var result = await _storage(path, 'move', values: values);
    if (result['conflicts'] case final List conflicts) {
      final choices = <String, String>{};
      for (final conflict in conflicts.cast<Map>()) {
        final resolution = await resolveConflict(
          conflict['source'] as String,
          conflict['target'] as String,
        );
        choices[conflict['source'] as String] = resolution.name;
      }
      result = await _storage(
        path,
        'move',
        values: {...values, 'conflicts': choices},
      );
    }
    final overwritten = (result['overwrittenSongIds'] as List?)?.cast<int>();
    return _change(
      result,
      result['count'] as int,
      overwrittenSongPaths: {
        if (overwritten != null)
          for (final id in overwritten) remoteMusicPath(source.deviceId, id),
      },
      directoryOnly: overwritten != null && overwritten.isEmpty,
    );
  }

  @override
  Future<LibraryStorageChange> hideSongFile(LibrarySong song) async {
    final result = await _storage(
      '',
      'hide-song',
      values: {'song': int.parse(Uri.parse(song.path).pathSegments.single)},
    );
    return _change(result, 1);
  }

  @override
  Future<void> createStorageFolder(
    String root,
    String parent,
    String name,
  ) async {
    await _storage(
      Uri.parse(parent).pathSegments.join('/'),
      'create',
      name: name,
    );
  }

  @override
  Future<LibraryStorageChange> renameStorageFolder(
    String path,
    String name,
  ) async => _change(
    await _storage(
      Uri.parse(path).pathSegments.join('/'),
      'rename',
      name: name,
    ),
    1,
  );

  @override
  Future<LibraryStorageChange> hideStorageFolder(String path) async => _change(
    await _storage(Uri.parse(path).pathSegments.join('/'), 'hide'),
    1,
  );

  @override
  Future<void> updateStorageFolderSort(
    String path,
    LocalFolderSortCriterion criterion,
  ) async {
    await _storage(
      Uri.parse(path).pathSegments.join('/'),
      'sort',
      values: {'criterion': criterion.index},
    );
  }

  @override
  Future<LibraryStorageFolders> getStorageFolders(String songPath) async {
    final data = await access.storageDirectoryIndex(source.deviceId);
    final folders = (data['folders'] as List).cast<String>();
    final info = (data['folderInfo'] as Map).cast<String, dynamic>();
    final root = '$remoteMusicScheme://${source.deviceId}';
    String path(String relative) => relative.isEmpty ? root : '$root/$relative';
    final ids = await repository.cacheRemoteSongReferences(source.deviceId, [
      int.parse(Uri.parse(songPath).pathSegments.single),
    ]);
    final page = await access.queryLibraryData(
      source.deviceId,
      LibraryDataQuery(LibraryQueryKind.songs, songIds: ids),
    );
    if (page.songs.isEmpty)
      throw const MusicShareException('share.fileChanged');
    final parent = page.songFolderPaths[ids.single]!;
    return LibraryStorageFolders(
      songParentPath: parent,
      folders: [
        for (final folder in folders)
          LibraryStorageFolder(
            id: info[folder]['id'] as int,
            path: path(folder),
            name:
                folder.isEmpty
                    ? data['rootName'] as String
                    : p.posix.basename(folder),
            parentId:
                folder.isEmpty
                    ? 0
                    : info[p.posix.dirname(folder) == '.'
                            ? ''
                            : p.posix.dirname(folder)]['id']
                        as int,
          ),
      ],
    );
  }

  @override
  Future<List<HiddenStorageItem>> getHiddenStorageItems() =>
      access.hiddenStorageItems(source.deviceId);

  @override
  Future<void> resumeHiddenStorageItem(HiddenStorageItem item) =>
      access.resumeHiddenStorage(source.deviceId, item);

  @override
  Future<LocalFolderRefreshResult> refreshStorageFolder(
    String path, {
    required LocalFolderScanCancellation cancellation,
    required void Function(LocalFolderRefreshProgress) onProgress,
    Future<void> Function(LocalFolderRefreshResult)? onLibraryCommitted,
  }) async {
    final value = await access.refreshStorageDirectory(
      source.deviceId,
      path,
      cancellation,
      onProgress,
    );
    final file = await repository._resolveDatabaseFile();
    final db = LibrarySnapshotService.openReadDatabase(file.path);
    final Map<String, int> ids;
    try {
      ids = {
        for (final row in db.select(
          'SELECT Id, Path FROM Music WHERE State = 1 AND Path LIKE ?',
          ['$remoteMusicScheme://${source.deviceId}/%'],
        ))
          Uri.parse(row['Path'] as String).pathSegments.single:
              row['Id'] as int,
      };
    } finally {
      db.dispose();
    }
    final result = readSharedScanResult(
      {
        ...value['result'] as Map<String, dynamic>,
        'songPaths': value['songPaths'],
      },
      source.deviceId,
      ids,
    );
    if (result.libraryChanged) await onLibraryCommitted?.call(result);
    return result;
  }
}
