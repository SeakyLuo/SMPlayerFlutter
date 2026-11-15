part of 'library_repository.dart';

mixin _LibraryRepositorySongEditing on _LibraryDataSources {
  Future<List<LibrarySong>> getLibrarySongs({required List<int> songIds});
  void _invalidateLyricsCache(Iterable<int> songIds);

  Future<SongPropertiesSnapshot> getSongProperties(int songId) async {
    final song = (await getLibrarySongs(songIds: [songId])).single;
    return dataSource(song.source).getProperty(song);
  }

  Future<void> updateSongProperties(
    int songId,
    SongPropertiesUpdate update,
  ) async {
    final song = (await getLibrarySongs(songIds: [songId])).single;
    await dataSource(song.source).updateProperty(song, update);
  }

  Future<void> updateSongPlayCount(int songId, int playCount) async {
    final song = (await getLibrarySongs(songIds: [songId])).single;
    await dataSource(song.source).updatePlayCount(song, playCount);
  }

  Future<void> saveSongLyrics(int songId, String rawLyrics) async {
    final song = (await getLibrarySongs(songIds: [songId])).single;
    await dataSource(song.source).saveLyrics(song, rawLyrics);
    _invalidateLyricsCache([songId]);
  }

  Future<void> saveSongArtwork(int songId, String sourcePath) =>
      _writeSongArtwork(songId, sourcePath);
  Future<void> deleteSongArtwork(int songId) => _writeSongArtwork(songId, null);
  Future<void> _writeSongArtwork(int songId, String? sourcePath) async {
    final song = (await getLibrarySongs(songIds: [songId])).single;
    await dataSource(
      song.source,
    ).writeArtwork({song.id: song.path}, sourcePath);
  }
}
