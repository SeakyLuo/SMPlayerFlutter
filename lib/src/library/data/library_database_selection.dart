part of 'library_repository.dart';

extension LibraryDatabaseSelection on LibraryRepository {
  Future<List<int>> selectLocalSongIds(
    LibrarySelectionRequest request, {
    String? folder,
    bool initializePreferences = true,
  }) async {
    final file = await _resolveDatabaseFile();
    final plan =
        request.kind == LibrarySelectionKind.quick
            ? quickPlayDatabasePlan(
              await getPreferenceSettings(
                source: 'local',
                initialize: initializePreferences,
                unknownAlbumName: request.unknownAlbumName,
              ),
            )
            : null;
    await LibrarySnapshotService.waitForPendingOperations();
    return Isolate.run(() {
      final db = sqlite3.open(file.path, mode: OpenMode.readOnly);
      try {
        registerLibraryTimeSql(db);
        db.execute('BEGIN');
        db.createFunction(
          functionName: 'song_directory',
          argumentCount: const AllowedArgumentCount(1),
          deterministic: true,
          function: (values) => p.dirname(values.single as String),
        );
        db.execute('CREATE TEMP TABLE SelectionScope (Id INTEGER PRIMARY KEY)');
        db.execute(
          '''INSERT INTO SelectionScope SELECT Id FROM Music WHERE State = 1
          ${request.kind == LibrarySelectionKind.selection && folder == null ? '' : "AND Path NOT LIKE 'smplayer-music://%'"}
          ${folder == null ? '' : 'AND substr(Path, 1, ?) = ?'}''',
          [
            if (folder != null) ...[
              folder.length + 1,
              '$folder${Platform.pathSeparator}',
            ],
          ],
        );
        final ids =
            request.kind == LibrarySelectionKind.quick
                ? _selectQuickPlayIds(db, plan!, request.limit)
                : _selectDatabaseSongIds(db, request);
        db.execute('COMMIT');
        return ids;
      } finally {
        db.dispose();
      }
    });
  }
}

List<int> _selectDatabaseSongIds(Database db, LibrarySelectionRequest request) {
  const scope = 'Id IN (SELECT Id FROM SelectionScope)';
  final limit = request.limit;
  final filter = switch (request.kind) {
    LibrarySelectionKind.library => '',
    LibrarySelectionKind.artist => '',
    LibrarySelectionKind.album =>
      'AND Album = (SELECT Album FROM Music WHERE $scope GROUP BY Album ORDER BY RANDOM() LIMIT 1)',
    LibrarySelectionKind.folder => '''AND song_directory(Path) = (
      SELECT Path FROM Folder WHERE State = 1 AND Path IN (
        SELECT song_directory(Path) FROM Music WHERE $scope
      ) ORDER BY RANDOM() LIMIT 1
    )''',
    LibrarySelectionKind.recentAdded =>
      'AND Id IN (SELECT Id FROM Music WHERE $scope ORDER BY library_time(CAST(DateAdded AS TEXT)) DESC LIMIT 500)',
    LibrarySelectionKind.recentPlayed => '''AND Id IN (
      SELECT CAST(ItemId AS INTEGER) FROM RecentRecord WHERE Type = 0 AND State = 1
      AND CAST(ItemId AS INTEGER) IN (SELECT Id FROM Music WHERE State = 1) ORDER BY Id DESC LIMIT 500
    )''',
    LibrarySelectionKind.mostPlayed =>
      'AND PlayCount IN (SELECT PlayCount FROM Music WHERE $scope ORDER BY PlayCount DESC LIMIT ${limit + 1})',
    LibrarySelectionKind.leastPlayed =>
      'AND PlayCount IN (SELECT PlayCount FROM Music WHERE $scope ORDER BY PlayCount ASC LIMIT ${limit + 1})',
    LibrarySelectionKind.favorites =>
      'AND Id IN (SELECT ItemId FROM PlaylistItem WHERE State = 1 AND PlaylistId = (SELECT MyFavorites FROM Settings ORDER BY Id LIMIT 1))',
    LibrarySelectionKind.playlist => '''AND Id IN (
      SELECT ItemId FROM PlaylistItem WHERE State = 1 AND PlaylistId = (
        SELECT Id FROM Playlist WHERE State = 1 AND Type = 0 AND Id > 0 AND Id IN (
          SELECT PlaylistId FROM PlaylistItem WHERE State = 1 AND ItemId IN (SELECT Id FROM SelectionScope)
        ) ORDER BY RANDOM() LIMIT 1
      )
    )''',
    LibrarySelectionKind.currentArtist =>
      '''AND (Artist IN (SELECT value FROM json_each(?))
      OR Id IN (SELECT MusicId FROM MusicArtist WHERE State = 1 AND Name IN (SELECT value FROM json_each(?))))''',
    LibrarySelectionKind.currentAlbum => 'AND Album = ?',
    LibrarySelectionKind.savedPlaylist =>
      'AND Id IN (SELECT ItemId FROM PlaylistItem WHERE State = 1 AND PlaylistId = ?)',
    LibrarySelectionKind.selection =>
      'AND Id IN (SELECT value FROM json_each(?))',
    LibrarySelectionKind.quick =>
      throw StateError('Quick play uses its preference query'),
  };
  final bounded =
      !{
        LibrarySelectionKind.currentArtist,
        LibrarySelectionKind.currentAlbum,
        LibrarySelectionKind.savedPlaylist,
        LibrarySelectionKind.selection,
        LibrarySelectionKind.recentPlayed,
      }.contains(request.kind);
  final artistCte =
      request.kind == LibrarySelectionKind.artist
          ? '''WITH SelectedArtist AS MATERIALIZED (
    SELECT Name AS Artist FROM (
      SELECT DISTINCT Name FROM MusicArtist WHERE State = 1 AND MusicId IN (SELECT Id FROM SelectionScope)
      UNION SELECT Artist FROM Music WHERE $scope AND Id NOT IN (SELECT MusicId FROM MusicArtist WHERE State = 1)
    ) ORDER BY RANDOM() LIMIT 1
  )'''
          : '';
  final artistFilter =
      request.kind == LibrarySelectionKind.artist
          ? '''AND (Id IN (
    SELECT MusicId FROM MusicArtist WHERE State = 1 AND Name = (SELECT Artist FROM SelectedArtist)
  ) OR (Artist = (SELECT Artist FROM SelectedArtist) AND Id NOT IN (SELECT MusicId FROM MusicArtist WHERE State = 1)))'''
          : filter;
  return db
      .select(
        '$artistCte SELECT Id FROM Music WHERE $scope $artistFilter ORDER BY RANDOM() ${bounded ? 'LIMIT ?' : ''}',
        [
          if (request.kind == LibrarySelectionKind.currentArtist) ...[
            jsonEncode(request.artists),
            jsonEncode(request.artists),
          ],
          if (request.kind == LibrarySelectionKind.currentAlbum) request.album,
          if (request.kind == LibrarySelectionKind.savedPlaylist)
            request.playlistId!,
          if (request.kind == LibrarySelectionKind.selection)
            jsonEncode(request.songIds),
          if (bounded) limit,
        ],
      )
      .map((row) => row['Id'] as int)
      .toList();
}
