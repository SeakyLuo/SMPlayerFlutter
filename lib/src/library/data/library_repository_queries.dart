part of 'library_repository.dart';

mixin _LibraryRepositoryQueries on _LibraryDataSources {
  Future<File> _resolveDatabaseFile();
  File _resolveNowPlayingFile(File file);
  Future<LibraryContentData> queryLibrary(LibraryDataQuery query) async {
    final elapsed = Stopwatch()..start();
    try {
      return await dataSource(switch (query.kind) {
        LibraryQueryKind.context ||
        LibraryQueryKind.queue ||
        LibraryQueryKind.recent => const LocalLibrarySource(),
        _ => LibrarySource.fromDevice(query.source),
      }).query(query);
    } catch (error, stack) {
      SystemLog.error(
        'Library query failed: kind=${query.kind.name}; '
        'source=${query.source}; offset=${query.offset}; limit=${query.limit}; '
        'elapsedMs=${elapsed.elapsedMilliseconds}',
        error,
        stack,
      );
      rethrow;
    }
  }

  Future<LibraryContentData> _readDatabaseQuery(LibraryDataQuery query) async {
    final file = await _resolveDatabaseFile();
    final queuePath = _resolveNowPlayingFile(file).path;
    final remotePlaylists =
        activeMusicShareAccess?.remotePlaylists
            .where(
              (playlist) =>
                  playlist.source == LibrarySource.fromDevice(query.source),
            )
            .toList() ??
        const <LibraryPlaylist>[];
    await LibrarySnapshotService.waitForPendingOperations();
    return Isolate.run(() {
      final db = LibrarySnapshotService.openReadDatabase(file.path);
      try {
        db.execute('BEGIN');
        final settings = LibraryRepository._readService.readLibrarySettings(db);
        final queue = LibraryRepository._playbackHistoryService.readNowPlaying(
          db,
          File(queuePath),
          settings.nowPlayingId,
        );
        final playlists =
            (query.kind == LibraryQueryKind.playlists ||
                    query.kind == LibraryQueryKind.playlistIndex)
                ? query.source == 'local'
                    ? LibraryRepository._playlistService.readPlaylists(db)
                    : remotePlaylists
                : const <LibraryPlaylist>[];
        final ids = switch (query.kind) {
          LibraryQueryKind.context ||
          LibraryQueryKind.lyrics ||
          LibraryQueryKind.artistIndex ||
          LibraryQueryKind.albumIndex ||
          LibraryQueryKind.directoryIndex ||
          LibraryQueryKind.playlistIndex => <int>[],
          LibraryQueryKind.recent =>
            {
              ...db
                  .select(
                    'SELECT CAST(ItemId AS INTEGER) AS id FROM RecentRecord WHERE State = 1 AND Type = 0 ORDER BY Id DESC LIMIT 500',
                  )
                  .map((row) => row['id'] as int)
                  .toSet(),
              ...LibraryRepository._browseHistoryService
                  .read(db)
                  .where((entry) => entry.type == RecentBrowseType.song)
                  .map((entry) => int.parse(entry.itemId)),
              for (final record in LibraryRepository._playbackHistoryService
                  .readRecentNowPlaying(db))
                ...record.songIds.take(4),
            }.toList(),
          LibraryQueryKind.queue =>
            (query.useSongIds || query.songIds.isNotEmpty
                    ? query.songIds
                    : queue.songIds)
                .skip(query.offset)
                .take(query.limit ?? 200)
                .toList(),
          LibraryQueryKind.playlists =>
            query.playlistId == null
                ? <int>[]
                : playlists
                    .where((p) => p.id == query.playlistId)
                    .expand((p) => p.songIds)
                    .toSet()
                    .toList(),
          _ => query.songIds.isEmpty ? null : query.songIds,
        };
        final summaries =
            {
                  LibraryQueryKind.artistIndex,
                  LibraryQueryKind.albumIndex,
                }.contains(query.kind)
                ? _readCollectionSummaries(db, query)
                : null;
        var totalSongs = summaries?.count ?? 0;
        var totalDuration = 0;
        var pageOffset = query.offset;
        int? anchorIndex;
        var quickJump = const <String, int>{};
        final directoryRows =
            query.directWindows.isEmpty
                ? const <String, Map<int, LibrarySong>>{}
                : _readDirectoryWindows(db, query);
        final songs =
            query.directWindows.isNotEmpty
                ? directoryRows.values.expand((rows) => rows.values).toList()
                : ids != null && ids.isEmpty
                ? const <LibrarySong>[]
                : LibraryRepository._readService.readSongs(
                  db,
                  songIds: ids,
                  source:
                      query.kind == LibraryQueryKind.queue
                          ? null
                          : query.source,
                  album:
                      query.kind == LibraryQueryKind.album &&
                              query.albumNames.isEmpty
                          ? query.album
                          : null,
                  favoritesOnly: query.kind == LibraryQueryKind.favorites,
                  includeInactive: query.kind == LibraryQueryKind.queue,
                  folder: query.folder,
                  artistNames: query.artists,
                  albumNames: query.albumNames,
                  directFolders: query.directFolders,
                  recursiveFolders: query.recursiveFolders,
                  limit:
                      query.kind == LibraryQueryKind.queue ? null : query.limit,
                  offset:
                      query.kind == LibraryQueryKind.queue ? 0 : query.offset,
                  text: query.text,
                  order: query.order,
                  descending: query.descending,
                  relevance: query.relevance,
                  substringSearch: query.substringSearch,
                  unknownArtist: query.unknownArtist,
                  unknownAlbum: query.unknownAlbum,
                  onCount: (count) => totalSongs = count,
                  onDuration: (duration) => totalDuration = duration,
                  anchorSongId: query.anchorSongId,
                  onPagePosition: (offset, anchor) {
                    pageOffset = offset;
                    anchorIndex = anchor;
                  },
                  onQuickJump:
                      query.limit != null ? (value) => quickJump = value : null,
                );
        final songsById = {for (final song in songs) song.id: song};
        final rows =
            query.kind == LibraryQueryKind.queue
                ? {
                  for (var index = 0; index < ids!.length; index++)
                    if (songsById.containsKey(ids[index]))
                      query.offset + index: songsById[ids[index]]!,
                }
                : {
                  for (var index = 0; index < songs.length; index++)
                    pageOffset + index: songs[index],
                };
        if (query.kind == LibraryQueryKind.queue) {
          final references =
              !query.useSongIds && query.songIds.isEmpty
                  ? queue.songIds
                  : query.songIds;
          totalSongs = references.length;
          totalDuration =
              db.select(
                    'SELECT COALESCE(SUM(Duration),0) AS duration FROM Music INNER JOIN json_each(?) AS refs ON Music.Id=refs.value',
                    [jsonEncode(references)],
                  ).single['duration']
                  as int;
        }
        final folders =
            query.source == 'local' &&
                    (query.kind == LibraryQueryKind.folders ||
                        query.kind == LibraryQueryKind.directoryIndex)
                ? LibraryRepository._readService.readFolders(db)
                : const <LibraryFolder>[];
        final folderSummaries =
            query.kind == LibraryQueryKind.folders ||
                    query.kind == LibraryQueryKind.directoryIndex
                ? _readFolderSummaries(
                  db,
                  settings.rootPath,
                  text:
                      query.kind == LibraryQueryKind.folders ? query.text : '',
                )
                : const <LibraryFolderSummary>[];
        db.execute('COMMIT');
        return LibraryContentData(
          songs: songs,
          totalSongCount: totalSongs,
          totalDuration: totalDuration,
          pageOffset: pageOffset,
          anchorIndex: anchorIndex,
          songRows: rows,
          quickJumpOffsets: quickJump,
          artistSummaries: summaries?.artists ?? const [],
          albumSummaries: summaries?.albums ?? const [],
          folderSummaries: folderSummaries,
          folderSongRows: directoryRows,
          hasLibrary: totalSongs > 0,
          sortCriterion: settings.sortCriterion,
          albumsSort: settings.albumsSort,
          databasePath: file.path,
          folders: folders,
          playlists: playlists,
          nowPlaying: queue,
          favoritePlaylistId: settings.myFavoritesId,
          showCount: settings.showCount,
          hideMultiSelectCommandBarAfterOperation:
              settings.hideMultiSelectCommandBarAfterOperation,
          localViewMode: settings.localViewMode,
          rootPath: settings.rootPath,
        );
      } finally {
        db.dispose();
      }
    });
  }

  Future<Map<int, String>> getLocalStorageReferences(
    List<int> ids,
    List<String> folders,
  ) async {
    final file = await _resolveDatabaseFile();
    await LibrarySnapshotService.waitForPendingOperations();
    return Isolate.run(() {
      final db = LibrarySnapshotService.openReadDatabase(file.path);
      try {
        db.execute('BEGIN');
        final rows = db.select(
          "SELECT Id, Path FROM Music WHERE State = 1 AND Path NOT LIKE 'smplayer-music://%' AND (Id IN (SELECT value FROM json_each(?)) OR EXISTS (SELECT 1 FROM json_each(?) AS folder WHERE substr(Music.Path, 1, length(folder.value) + 1) = folder.value || ?))",
          [jsonEncode(ids), jsonEncode(folders), Platform.pathSeparator],
        );
        final songs = {
          for (final row in rows) row['Id'] as int: row['Path'] as String,
        };
        db.execute('COMMIT');
        return songs;
      } finally {
        db.dispose();
      }
    });
  }

  Future<Map<int, String>> readLocalSongPaths(String folder) async {
    final file = await _resolveDatabaseFile();
    await LibrarySnapshotService.waitForPendingOperations();
    return Isolate.run(() {
      final db = LibrarySnapshotService.openReadDatabase(file.path);
      try {
        return {
          for (final row in db.select(
            "SELECT Id, Path FROM Music WHERE State = 1 AND substr(Path, 1, ?) = ?",
            [folder.length + 1, '$folder${Platform.pathSeparator}'],
          ))
            row['Id'] as int: row['Path'] as String,
        };
      } finally {
        db.dispose();
      }
    });
  }

  Future<List<LibrarySong>> readRemoteSelection(
    String device,
    List<int> hostIds,
  ) async {
    final file = await _resolveDatabaseFile();
    final paths = hostIds.map((id) => remoteMusicPath(device, id)).toList();
    await LibrarySnapshotService.waitForPendingOperations();
    return Isolate.run(() {
      final db = LibrarySnapshotService.openReadDatabase(file.path);
      try {
        final rows = db.select(
          "SELECT Id FROM Music WHERE Path IN (SELECT value FROM json_each(?)) AND State = 1",
          [jsonEncode(paths)],
        );
        final songs = LibraryRepository._readService.readSongs(
          db,
          songIds: rows.map((row) => row['Id'] as int).toList(),
        );
        final byPath = {for (final song in songs) song.path: song};
        return [for (final path in paths) byPath[path]!];
      } finally {
        db.dispose();
      }
    });
  }
}
