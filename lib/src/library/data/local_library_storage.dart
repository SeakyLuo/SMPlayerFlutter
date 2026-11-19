part of 'library_repository.dart';

mixin _LocalLibraryStorage implements LibraryDataSource {
  LibraryRepository get repository;

  Future<void> _storageChanged(Future<void> Function() action) async {
    await action();
    activeMusicShareAccess?.localDataChanged('library');
  }

  @override
  Future<LibraryStorageChange> deleteStorageItems(
    Map<int, String> songs,
    List<String> folders,
  ) async {
    final pending = await repository.beginDeleteLocalItems(
      songs.keys.toList(),
      folders,
    );
    activeMusicShareAccess?.localDataChanged('library');
    return LibraryStorageChange(
      source: source,
      count: songs.length + folders.length,
      deletedSongIds: pending.songIds.toSet(),
      undo:
          () => _storageChanged(
            () => repository.undoDeleteLocalItems(pending.id),
          ),
      commit: () => repository.commitDeleteLocalItems(pending.id),
    );
  }

  @override
  Future<LibraryStorageChange> moveStorageItems(
    Map<int, String> songs,
    List<String> folders,
    String target, {
    required LocalMoveConflictResolver resolveConflict,
  }) async {
    final result = await repository.moveLocalItemsToFolder(
      songs.keys.toList(),
      folders,
      target,
      resolveConflict: resolveConflict,
    );
    if (result.itemCount > 0 ||
        result.inactiveFolders.isNotEmpty ||
        result.overwrittenSongIds.isNotEmpty) {
      activeMusicShareAccess?.localDataChanged('library');
    }
    return LibraryStorageChange(
      source: source,
      count: result.itemCount,
      localMove: result,
      undo: () => _storageChanged(() => repository.undoMoveLocalItems(result)),
      commit: () async {},
    );
  }

  @override
  Future<LibraryStorageChange> hideSongFile(LibrarySong song) async {
    await _storageChanged(() => repository.hideSong(song.id));
    return LibraryStorageChange(
      source: source,
      count: 1,
      undo: () => _storageChanged(() => repository.unhideSong(song.id)),
      commit: () async {},
    );
  }

  @override
  Future<void> createStorageFolder(String root, String parent, String name) =>
      _storageChanged(() async {
        await repository.createLocalFolder(root, parent, name);
      });

  @override
  Future<LibraryStorageChange> renameStorageFolder(
    String path,
    String name,
  ) async {
    await _storageChanged(() => repository.renameFolder(path, name));
    return LibraryStorageChange(
      source: source,
      count: 1,
      undo:
          () => _storageChanged(
            () => repository.renameFolder(
              p.join(p.dirname(path), name),
              p.basename(path),
            ),
          ),
      commit: () async {},
    );
  }

  @override
  Future<LibraryStorageChange> hideStorageFolder(String path) async {
    await _storageChanged(() => repository.hideFolder(path));
    return LibraryStorageChange(
      source: source,
      count: 1,
      undo: () => _storageChanged(() => repository.unhideFolder(path)),
      commit: () async {},
    );
  }

  @override
  Future<void> updateStorageFolderSort(
    String path,
    LocalFolderSortCriterion criterion,
  ) => _storageChanged(() => repository.updateLocalFolderSort(path, criterion));

  @override
  Future<LibraryStorageFolders> getStorageFolders(String songPath) async {
    final page = await repository.queryLibrary(
      const LibraryDataQuery(LibraryQueryKind.directoryIndex),
    );
    return LibraryStorageFolders(
      songParentPath: p.dirname(songPath),
      folders: [
        for (final folder in page.folders)
          LibraryStorageFolder(
            id: folder.id,
            path: folder.path,
            name: p.basename(folder.path),
            parentId: folder.parentId,
          ),
      ],
    );
  }

  @override
  Future<List<HiddenStorageItem>> getHiddenStorageItems() =>
      repository.getHiddenStorageItems();

  @override
  Future<void> resumeHiddenStorageItem(HiddenStorageItem item) =>
      _storageChanged(() => repository.resumeHiddenStorageItem(item));

  @override
  Future<LocalFolderRefreshResult> refreshStorageFolder(
    String path, {
    required LocalFolderScanCancellation cancellation,
    required void Function(LocalFolderRefreshProgress) onProgress,
    Future<void> Function(LocalFolderRefreshResult)? onLibraryCommitted,
  }) => repository.refreshLocalFolder(
    path,
    cancellation: cancellation,
    onProgress: onProgress,
    onLibraryCommitted: (result) async {
      activeMusicShareAccess?.localDataChanged('library');
      await onLibraryCommitted?.call(result);
    },
  );
}
