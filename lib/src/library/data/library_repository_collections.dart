part of 'library_repository.dart';

mixin _LibraryRepositoryCollections on _LibraryDataSources {
  Future<File> _resolveDatabaseFile();

  Future<LibraryPlaylist> createPlaylist(
    String name, [
    List<int> songIds = const [],
    LibrarySource source = const LocalLibrarySource(),
  ]) => dataSource(source).createPlaylist(name, songIds);
  Future<void> deletePlaylist(int playlistId) =>
      _playlistDataSource(playlistId).deletePlaylist(playlistId);
  Future<void> restorePlaylist(LibraryPlaylist playlist) =>
      dataSource(playlist.source).restorePlaylist(playlist);
  Future<void> renamePlaylist(int playlistId, String name) =>
      _playlistDataSource(playlistId).renamePlaylist(playlistId, name);
  Future<void> reorderPlaylists(List<int> playlistIds) =>
      _playlistOrderDataSource(playlistIds).reorderPlaylists(playlistIds);
  Future<void> addSongToPlaylist(int playlistId, int songId) =>
      addSongsToPlaylist(playlistId, [songId]);
  Future<void> addSongsToPlaylist(int playlistId, List<int> songIds) =>
      _playlistDataSource(playlistId).addSongsToPlaylist(playlistId, songIds);
  Future<void> removeSongFromPlaylist(int playlistId, int songId) =>
      removeSongsFromPlaylist(playlistId, [songId]);
  Future<void> removeSongsFromPlaylist(int playlistId, List<int> songIds) =>
      _playlistDataSource(
        playlistId,
      ).removeSongsFromPlaylist(playlistId, songIds);
  Future<void> reorderPlaylistSongs(
    int playlistId,
    List<int> songIds, [
    PlaylistSortCriterion? sortCriterion,
  ]) => _playlistDataSource(
    playlistId,
  ).reorderPlaylistSongs(playlistId, songIds, sortCriterion);

  Future<RecentPlaylistPlayback> recordPlaylistPlayed(int playlistId) async {
    if (playlistId < 0) {
      return RecentPlaylistPlayback(
        id: playlistId,
        playlistId: playlistId,
        playedAt: DateTime.now().millisecondsSinceEpoch.toString(),
      );
    }
    final databaseFile = await _resolveDatabaseFile();
    return LibraryRepository._playbackHistoryService.recordPlaylistPlayed(
      databaseFile,
      playlistId,
    );
  }

  Future<RecentAlbumPlayback> recordAlbumPlayed(String album) async {
    final databaseFile = await _resolveDatabaseFile();
    return LibraryRepository._playbackHistoryService.recordAlbumPlayed(
      databaseFile,
      album,
    );
  }

  Future<RecentArtistPlayback> recordArtistPlayed(String artist) async {
    final databaseFile = await _resolveDatabaseFile();
    return LibraryRepository._playbackHistoryService.recordArtistPlayed(
      databaseFile,
      artist,
    );
  }
}
