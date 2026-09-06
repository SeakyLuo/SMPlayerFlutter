part of 'library_local_refresh_service.dart';

mixin _LibraryLocalRefreshOperations {
  LibrarySongPropertiesService get _songPropertiesService;

  Future<void> renameFolder(
    File databaseFile,
    String folderPath,
    String name,
  ) async {
    final targetPath = p.join(p.dirname(folderPath), name);
    await Directory(folderPath).rename(targetPath);

    final db = sqlite3.open(databaseFile.path);
    try {
      db.execute('BEGIN');
      try {
        updatePathPrefixInsideTransaction(
          db,
          table: 'Music',
          oldPath: folderPath,
          newPath: targetPath,
        );
        updatePathPrefixInsideTransaction(
          db,
          table: 'File',
          oldPath: folderPath,
          newPath: targetPath,
        );
        updatePathPrefixInsideTransaction(
          db,
          table: 'Folder',
          oldPath: folderPath,
          newPath: targetPath,
        );
        db.execute('COMMIT');
      } on Object {
        db.execute('ROLLBACK');
        rethrow;
      }
    } finally {
      db.dispose();
    }
  }

  Future<LocalFolderRefreshResult> createLocalFolder(
    String rootPath,
    String relativePath,
    String name, {
    required Future<LocalFolderRefreshResult> Function(
      String folderPath, {
      void Function(LocalFolderRefreshProgress progress)? onProgress,
      LocalFolderScanCancellation? cancellation,
    })
    refreshLocalFolder,
    void Function(LocalFolderRefreshProgress progress)? onProgress,
    LocalFolderScanCancellation? cancellation,
  }) async {
    final parentPath =
        relativePath.isEmpty ? rootPath : p.join(rootPath, relativePath);
    await Directory(p.join(parentPath, name)).create(recursive: true);
    return refreshLocalFolder(
      parentPath,
      onProgress: onProgress,
      cancellation: cancellation,
    );
  }

  List<String> readActiveSongPaths(Database db) {
    return db
        .select(
          '''
          SELECT Path AS path
          FROM Music
          WHERE State = ?
        ''',
          [_activeState],
        )
        .map((row) => row['path'] as String)
        .toList();
  }

  void markScannedTablesInactive(Database db, Set<String> scannedPaths) {
    for (final table in ['Music', 'File']) {
      final rows = db.select('SELECT Id, Path FROM $table WHERE State = ?', [
        _activeState,
      ]);
      final deactivate = db.prepare('UPDATE $table SET State = ? WHERE Id = ?');
      try {
        for (final row in rows) {
          if (!scannedPaths.contains(row['Path'] as String)) {
            deactivate.execute([_inactiveState, row['Id']]);
          }
        }
      } finally {
        deactivate.dispose();
      }
    }
    db.execute(
      '''
      UPDATE Folder
      SET State = ?
      WHERE State NOT IN (?, ?)
    ''',
      [_inactiveState, _hiddenState, _parentHiddenState],
    );
  }

  void markScannedFoldersInactive(Database db, String folderPath) {
    db.execute(
      '''
      UPDATE Folder
      SET State = ?
      WHERE State NOT IN (?, ?)
        AND (Path = ? OR Path LIKE ? OR Path LIKE ?)
    ''',
      [
        _inactiveState,
        _hiddenState,
        _parentHiddenState,
        folderPath,
        '$folderPath/%',
        '$folderPath\\%',
      ],
    );
  }

  void updateMovedSongPathInsideTransaction(
    Database db,
    RefreshMovedSong movedSong,
  ) {
    db.execute(
      '''
      UPDATE Music
      SET Path = ?
      WHERE Id = ?
        AND State = ?
    ''',
      [movedSong.newPath, movedSong.id, _activeState],
    );
    db.execute(
      '''
      UPDATE File
      SET Path = ?
      WHERE Path = ?
        AND State = ?
    ''',
      [movedSong.newPath, movedSong.oldPath, _activeState],
    );
  }

  void updatePathPrefixInsideTransaction(
    Database db, {
    required String table,
    required String oldPath,
    required String newPath,
  }) {
    db.execute(
      '''
      UPDATE $table
      SET Path = ? || substr(Path, ?)
      WHERE Path = ?
        OR Path LIKE ?
        OR Path LIKE ?
    ''',
      [newPath, oldPath.length + 1, oldPath, '$oldPath/%', '$oldPath\\%'],
    );
  }

  int upsertExternalAudioFile(
    Database db,
    String filePath, {
    required AudioFileMetadata metadata,
    bool useFilenameNotMusicName = false,
  }) {
    final properties = metadata.properties;
    final title =
        useFilenameNotMusicName || properties.title.trim().isEmpty
            ? p.basenameWithoutExtension(filePath)
            : properties.title.trim();
    final artists =
        _songPropertiesService
            .normalizeArtists(
              artist_tags.normalizeArtistTagValues(
                properties.artists,
                properties.artist,
              ),
            )
            .take(6)
            .toList();
    final artist = artists.join(', ');
    final album = properties.album.trim();
    final rows = db.select(
      '''
      INSERT INTO Music (
        Path,
        Name,
        Artist,
        Album,
        ThumbnailPath,
        Duration,
        PlayCount,
        DateAdded,
        FileSize,
        DateModifiedMs,
        State
      )
      VALUES (
        ?, ?, ?, ?, ?,
        ?,
        COALESCE((SELECT PlayCount FROM Music WHERE Path = ?), 0),
        ?, ?, ?,
        ?
      )
      ON CONFLICT(Path) DO UPDATE SET
        Name = excluded.Name,
        Artist = excluded.Artist,
        Album = excluded.Album,
        ThumbnailPath = excluded.ThumbnailPath,
        Duration = excluded.Duration,
        DateAdded = excluded.DateAdded,
        FileSize = excluded.FileSize,
        DateModifiedMs = excluded.DateModifiedMs,
        State = excluded.State
      RETURNING Id AS id
    ''',
      [
        filePath,
        title,
        artist,
        album,
        metadata.thumbnailPath,
        metadata.duration,
        filePath,
        metadata.dateAdded,
        metadata.fileSize,
        metadata.dateModifiedMs,
        _activeState,
      ],
    );
    final songId = rows.first['id'] as int;
    _songPropertiesService.syncSongArtists(db, songId, artists);
    return songId;
  }

  List<LibrarySong> _buildScannedSongs(
    List<String> paths,
    Map<String, AudioFileMetadata> metadataByPath, {
    required bool useFilenameNotMusicName,
  }) {
    return [
      for (final entry in paths.indexed)
        _scannedSongFromMetadata(
          entry.$1 + 1,
          entry.$2,
          metadataByPath[entry.$2]!,
          useFilenameNotMusicName: useFilenameNotMusicName,
        ),
    ];
  }

  LibrarySong _scannedSongFromMetadata(
    int tempId,
    String filePath,
    AudioFileMetadata metadata, {
    required bool useFilenameNotMusicName,
  }) {
    final properties = metadata.properties;
    final title =
        useFilenameNotMusicName || properties.title.trim().isEmpty
            ? p.basenameWithoutExtension(filePath)
            : properties.title.trim();
    final artists =
        _songPropertiesService
            .normalizeArtists(
              artist_tags.normalizeArtistTagValues(
                properties.artists,
                properties.artist,
              ),
            )
            .take(6)
            .toList();
    return LibrarySong(
      id: tempId,
      path: filePath,
      thumbnailPath: metadata.thumbnailPath,
      title: title,
      artist: artists.join(', '),
      artists: artists,
      album: properties.album.trim(),
      duration: metadata.duration,
      playCount: 0,
      lyricsOffsetMs: 0,
      dateAdded: metadata.dateAdded,
      favorite: false,
    );
  }

  ArtistSplitResultItem _withSongId(ArtistSplitResultItem item, int songId) {
    return ArtistSplitResultItem(
      songId: songId,
      title: item.title,
      artist: item.artist,
      artists: item.artists,
    );
  }

  Map<String, int> upsertScannedFolders(
    Database db,
    String rootPath,
    List<String> folderPaths,
  ) {
    final folderIds = <String, int>{};
    final activeFolderIds = {
      for (final row in db.select(
        '''
        SELECT Id AS id, Path AS path
        FROM Folder
        WHERE State = ?
      ''',
        [_activeState],
      ))
        localScanPathComparisonKey(row['path'] as String): row['id'] as int,
    };
    final sortedFolders =
        folderPaths.toList()..sort(
          (left, right) =>
              localScanPathDepth(left).compareTo(localScanPathDepth(right)),
        );
    final rootKey = localScanPathComparisonKey(rootPath);
    final upsertFolder = db.prepare('''
        INSERT INTO Folder (Path, Criterion, ParentId, State)
        VALUES (?, 0, ?, ?)
        ON CONFLICT(Path) DO UPDATE SET
          ParentId = excluded.ParentId,
          State = excluded.State
        RETURNING Id AS id
      ''');
    try {
      for (final folderPath in sortedFolders) {
        final folderKey = localScanPathComparisonKey(folderPath);
        final parentKey = localScanPathComparisonKey(p.dirname(folderPath));
        final parentId =
            folderKey == rootKey
                ? 0
                : folderIds[parentKey] ?? activeFolderIds[parentKey] ?? 0;
        final rows = upsertFolder.select([folderPath, parentId, _activeState]);
        folderIds[folderKey] = rows.first['id'] as int;
      }
    } finally {
      upsertFolder.dispose();
    }
    return folderIds;
  }

  void setRootPath(Database db, String rootPath) {
    db.execute('UPDATE Settings SET RootPath = ?', [rootPath]);
    final changedRows =
        db.select('SELECT changes() AS count').first['count'] as int;
    if (changedRows == 0) {
      db.execute('INSERT INTO Settings (RootPath) VALUES (?)', [rootPath]);
    }
  }
}

class RefreshMovedSong {
  const RefreshMovedSong({
    required this.id,
    required this.oldPath,
    required this.newPath,
  });

  final int id;
  final String oldPath;
  final String newPath;
}

class _RefreshRemovedSong {
  const _RefreshRemovedSong({required this.id, required this.path});

  final int id;
  final String path;
}
