part of 'library_repository.dart';

mixin _LibraryRepositorySongEditing {
  Future<File> _resolveDatabaseFile();
  Future<List<LibrarySong>> getLibrarySongs({List<int>? songIds});
  LibraryLyricsService get _lyricsService;
  LibraryLyricsSearchService get _lyricsSearchService;
  LibraryArtworkService get _artworkService;
  void _invalidateLyricsCache(Iterable<int> songIds);

  Future<SongPropertiesSnapshot> getSongProperties(int songId) async {
    final song = (await getLibrarySongs(songIds: [songId])).single;
    if (isRemoteMusicPath(song.path)) {
      final json = await activeMusicShareAccess!.songRequest(
        song.path,
        'properties',
      );
      return sharedPropertiesFromJson(json, songId, song.path);
    }
    final databaseFile = await _resolveDatabaseFile();
    return LibraryRepository._songPropertiesService.getSongProperties(
      databaseFile,
      songId,
    );
  }

  Future<void> updateSongProperties(
    int songId,
    SongPropertiesUpdate update,
  ) async {
    final song = (await getLibrarySongs(songIds: [songId])).single;
    if (isRemoteMusicPath(song.path)) {
      await activeMusicShareAccess!.songRequest(
        song.path,
        'properties',
        method: 'POST',
        body: sharedUpdateJson(update),
      );
      return;
    }
    final databaseFile = await _resolveDatabaseFile();
    await LibraryRepository._songPropertiesService.updateSongProperties(
      databaseFile,
      songId,
      update,
    );
  }

  Future<void> updateSongPlayCount(int songId, int playCount) async {
    final song = (await getLibrarySongs(songIds: [songId])).single;
    if (isRemoteMusicPath(song.path)) {
      await activeMusicShareAccess!.songRequest(
        song.path,
        'play-count',
        method: 'POST',
        body: {'playCount': playCount},
      );
      return;
    }
    final databaseFile = await _resolveDatabaseFile();
    await LibraryRepository._songPropertiesService.updateSongPlayCount(
      databaseFile,
      songId,
      playCount,
    );
  }

  Future<void> saveSongLyrics(int songId, String rawLyrics) async {
    final song = (await getLibrarySongs(songIds: [songId])).single;
    if (isRemoteMusicPath(song.path)) {
      await activeMusicShareAccess!.songRequest(
        song.path,
        'lyrics',
        method: 'POST',
        body: {'rawText': rawLyrics},
      );
      _invalidateLyricsCache([songId]);
      return;
    }
    final databaseFile = await _resolveDatabaseFile();
    await _lyricsService.saveSongLyrics(databaseFile, songId, rawLyrics);
    _invalidateLyricsCache([songId]);
    await _lyricsSearchService.refreshSongIds(databaseFile, [songId]);
  }

  Future<void> saveSongArtwork(int songId, String sourcePath) async {
    final song = (await getLibrarySongs(songIds: [songId])).single;
    if (isRemoteMusicPath(song.path)) {
      await _writeRemoteArtwork(
        song,
        method: 'POST',
        body: {'image': base64Encode(await File(sourcePath).readAsBytes())},
      );
      return;
    }
    final databaseFile = await _resolveDatabaseFile();
    await _artworkService.saveSongArtwork(databaseFile, songId, sourcePath);
  }

  Future<void> deleteSongArtwork(int songId) async {
    final song = (await getLibrarySongs(songIds: [songId])).single;
    if (isRemoteMusicPath(song.path)) {
      await _writeRemoteArtwork(song, method: 'DELETE');
      return;
    }
    final databaseFile = await _resolveDatabaseFile();
    await _artworkService.deleteSongArtwork(databaseFile, songId);
  }

  Future<void> _writeRemoteArtwork(
    LibrarySong song, {
    required String method,
    Object? body,
  }) async {
    final result = await activeMusicShareAccess!.songRequest(
      song.path,
      'artwork',
      method: method,
      body: body,
    );
    final path =
        result['artwork'] == true
            ? '${song.path}?art=${result['artworkRevision']}'
            : '';
    final databaseFile = await _resolveDatabaseFile();
    await LibrarySnapshotService.run(() {
      final db = sqlite3.open(databaseFile.path);
      try {
        db.execute('UPDATE Music SET ThumbnailPath = ? WHERE Id = ?', [
          path,
          song.id,
        ]);
      } finally {
        db.dispose();
      }
    });
  }
}
