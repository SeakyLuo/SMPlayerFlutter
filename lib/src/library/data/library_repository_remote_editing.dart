part of 'library_repository.dart';

mixin _LibraryRepositoryRemoteEditing on _LibraryDataSources {
  Future<File> _resolveDatabaseFile();
  Future<List<LibrarySong>> getLibrarySongs({required List<int> songIds});
  LibraryArtworkService get _artworkService;
  void _invalidateLyricsCache(Iterable<int> songIds);

  Future<List<SongPropertiesSnapshot>> getSongPropertiesBatch(
    List<int> songIds,
  ) async {
    final groups = _groupSongReferences(
      await (this as LibraryRepository).songReferences(songIds),
    );
    final results = await Future.wait(
      groups.entries.map((e) => dataSource(e.key).getProperties(e.value)),
    );
    final byId = {
      for (final item in results.expand((r) => r)) item.songId: item,
    };
    return songIds.map((id) => byId[id]!).toList();
  }

  Future<BatchSongPropertiesUpdateResult> updateSongPropertiesBatch(
    Map<int, SongPropertiesUpdate> updates,
  ) async {
    final groups = _groupSongReferences(
      await (this as LibraryRepository).songReferences(updates.keys.toList()),
    );
    for (final source in groups.keys) {
      _requireWritable(dataSource(source));
    }
    final results = await Future.wait(
      groups.entries.map((e) async {
        try {
          return await dataSource(e.key).updateProperties(e.value, {
            for (final id in e.value.keys) id: updates[id]!,
          });
        } on MusicShareException {
          return BatchSongPropertiesUpdateResult(
            updatedSongIds: const [],
            failedSongIds: e.value.keys.toList(),
          );
        }
      }),
    );
    return BatchSongPropertiesUpdateResult(
      updatedSongIds: results.expand((r) => r.updatedSongIds).toList(),
      failedSongIds: results.expand((r) => r.failedSongIds).toList(),
    );
  }

  Future<List<int>> setSongsFavorite(List<int> songIds, bool favorite) async {
    final groups = _groupSongReferences(
      await (this as LibraryRepository).songReferences(songIds),
    );
    for (final source in groups.keys) {
      _requireWritable(dataSource(source));
    }
    final results = await Future.wait(
      groups.entries.map(
        (e) => dataSource(e.key).setFavorites(e.value, favorite),
      ),
    );
    return results.expand((ids) => ids).toList();
  }

  Future<void> updateLyricsOffset(int songId, int offsetMs) async {
    final song = (await getLibrarySongs(songIds: [songId])).single;
    await dataSource(song.source).updateLyricsOffset(song, offsetMs);
    _invalidateLyricsCache([songId]);
  }

  Future<void> saveAlbumArtwork(
    String albumName,
    String sourcePath, {
    int? songId,
  }) => _writeAlbumArtwork(albumName, sourcePath, songId);
  Future<void> deleteAlbumArtwork(String albumName, {int? songId}) =>
      _writeAlbumArtwork(albumName, null, songId);
  Future<void> _writeAlbumArtwork(
    String albumName,
    String? sourcePath,
    int? songId,
  ) async {
    final source =
        songId == null
            ? const LocalLibrarySource()
            : (await getLibrarySongs(songIds: [songId])).single.source;
    await dataSource(source).writeAlbumArtwork(albumName, sourcePath);
  }

  Future<void> updateSharedSongsArtwork(
    List<int> songIds,
    String? sourcePath,
  ) async {
    await _artworkService.updateSongsArtwork(
      await _resolveDatabaseFile(),
      songIds,
      sourcePath,
    );
  }
}
