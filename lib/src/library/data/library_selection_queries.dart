part of 'library_repository.dart';

extension LibrarySelectionQueries on LibraryRepository {
  Future<List<LibrarySelectionKind>> readSelectionModes(
    int limit, {
    String? folder,
  }) async {
    final databasePath = (await _resolveDatabaseFile()).path;
    await LibrarySnapshotService.waitForPendingOperations();
    final scope =
        "Music.State = 1 AND Music.Path NOT LIKE 'smplayer-music://%'"
        "${folder == null ? '' : ' AND substr(Music.Path, 1, ?) = ?'}";
    final arguments = <Object?>[
      if (folder != null) ...[
        folder.length + 1,
        '$folder${Platform.pathSeparator}',
      ],
    ];
    Future<Map<String, int>> read(
      String sql, {
      required String operation,
      bool directory = false,
      int scopes = 1,
    }) => Isolate.run(() {
      final elapsed = Stopwatch()..start();
      final db = LibrarySnapshotService.openReadDatabase(databasePath);
      final openedMs = elapsed.elapsedMilliseconds;
      try {
        if (directory) {
          db.createFunction(
            functionName: 'song_directory',
            argumentCount: const AllowedArgumentCount(1),
            deterministic: true,
            function: (values) => p.dirname(values.single as String),
          );
        }
        final row =
            db.select(sql, [
              for (var index = 0; index < scopes; index++) ...arguments,
            ]).first;
        return {for (final key in row.keys) key: row[key] as int};
      } catch (error, stack) {
        SystemLog.error(
          'Random playback availability query failed: operation=$operation; '
          'openMs=$openedMs; totalMs=${elapsed.elapsedMilliseconds}',
          error,
          stack,
        );
        rethrow;
      } finally {
        db.dispose();
      }
    });
    final (inventory, directories, recent, lists) =
        await (
          read(
            'SELECT COUNT(*) AS total FROM Music WHERE $scope',
            operation: 'inventory',
          ),
          read(
            '''
        SELECT EXISTS(
          SELECT 1 FROM Folder WHERE State = 1 AND Path IN (
            SELECT song_directory(Music.Path) FROM Music WHERE $scope
          )
        ) AS available
      ''',
            directory: true,
            operation: 'directories',
          ),
          read('''
        SELECT EXISTS(
          SELECT 1 FROM Music WHERE $scope AND Id IN (
            SELECT CAST(ItemId AS INTEGER) FROM RecentRecord
            WHERE State = 1 AND Type = 0 AND CAST(ItemId AS INTEGER) IN (
              SELECT Id FROM Music WHERE State = 1
            ) ORDER BY Id DESC LIMIT 500
          )
        ) AS available
      ''', operation: 'recent'),
          read(
            '''
        SELECT
          EXISTS(SELECT 1 FROM PlaylistItem WHERE State = 1
            AND PlaylistId = (SELECT MyFavorites FROM Settings ORDER BY Id LIMIT 1)
            AND ItemId IN (SELECT Music.Id FROM Music WHERE $scope)) AS favorite,
          EXISTS(SELECT 1 FROM PlaylistItem WHERE State = 1
            AND PlaylistId IN (SELECT Id FROM Playlist WHERE State = 1 AND Type = 0 AND Id > 0)
            AND ItemId IN (SELECT Music.Id FROM Music WHERE $scope)) AS custom
      ''',
            scopes: 2,
            operation: 'playlists',
          ),
        ).wait;
    final count = inventory['total']!;
    return [
      if (count > 0) ...[
        LibrarySelectionKind.library,
        LibrarySelectionKind.artist,
        LibrarySelectionKind.album,
      ],
      if (directories['available'] == 1) LibrarySelectionKind.folder,
      if (count > 0) LibrarySelectionKind.recentAdded,
      if (recent['available'] == 1) LibrarySelectionKind.recentPlayed,
      if (count > limit) ...[
        LibrarySelectionKind.mostPlayed,
        LibrarySelectionKind.leastPlayed,
      ],
      if (lists['favorite'] == 1) LibrarySelectionKind.favorites,
      if (lists['custom'] == 1) LibrarySelectionKind.playlist,
    ];
  }
}
