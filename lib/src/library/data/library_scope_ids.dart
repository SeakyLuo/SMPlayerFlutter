part of 'library_repository.dart';

extension LibraryScopeIds on LibraryRepository {
  Future<List<int>> resolveLocalSongIds(LibraryDataQuery query) async {
    final file = await _resolveDatabaseFile();
    if (query.kind == LibraryQueryKind.lyrics)
      return _lyricsSearchService.searchSongIds(
        file,
        query.text,
        folderPath: query.folder ?? '',
        order: query.relevance ? null : query.order,
      );
    final queueFile = _resolveNowPlayingFile(file);
    await LibrarySnapshotService.waitForPendingOperations();
    return Isolate.run(() {
      final db = LibrarySnapshotService.openReadDatabase(file.path);
      try {
        db.execute('BEGIN');
        final List<int>? ids;
        List<int>? queue;
        if (query.kind == LibraryQueryKind.queue) {
          final settings = LibraryRepository._readService.readLibrarySettings(
            db,
          );
          queue =
              query.useSongIds || query.songIds.isNotEmpty
                  ? query.songIds
                  : LibraryRepository._playbackHistoryService
                      .readNowPlaying(db, queueFile, settings.nowPlayingId)
                      .songIds;
          if (query.text.isEmpty) {
            db.execute('COMMIT');
            return queue;
          }
          ids = queue;
        } else if (query.kind == LibraryQueryKind.playlists &&
            query.playlistId != null) {
          ids =
              db
                  .select(
                    'SELECT ItemId FROM PlaylistItem WHERE State = 1 AND PlaylistId = ? ORDER BY Id',
                    [query.playlistId],
                  )
                  .map((row) => row['ItemId'] as int)
                  .toList();
        } else {
          ids = query.songIds.isEmpty ? null : query.songIds;
        }
        final selected = LibraryRepository._readService.readSongIds(
          db,
          songIds: ids,
          source: query.kind == LibraryQueryKind.queue ? null : 'local',
          album:
              query.kind == LibraryQueryKind.album && query.albumNames.isEmpty
                  ? query.album
                  : null,
          albumNames: query.albumNames,
          directFolders: query.directFolders,
          recursiveFolders: query.recursiveFolders,
          artistNames: query.artists,
          folder: query.folder,
          text: query.text,
          favoritesOnly: query.kind == LibraryQueryKind.favorites,
          order: query.order,
          descending: query.descending,
          libraryIndex: query.libraryIndex,
          relevance: query.relevance,
          substringSearch: query.substringSearch,
          unknownArtist: query.unknownArtist,
          unknownAlbum: query.unknownAlbum,
        );
        db.execute('COMMIT');
        if (queue == null) return selected;
        final available = selected.toSet();
        return queue.where(available.contains).toList();
      } finally {
        db.dispose();
      }
    });
  }
}
