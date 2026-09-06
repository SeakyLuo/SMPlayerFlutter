part of 'library_repository.dart';

mixin _LibraryRepositoryCollections {
  Future<File> _resolveDatabaseFile();

  Future<LibraryPlaylist> createPlaylist(
    String name, [
    List<int> songIds = const [],
  ]) async {
    final databaseFile = await _resolveDatabaseFile();
    return LibraryRepository._playlistService.createPlaylist(
      databaseFile,
      name,
      songIds,
    );
  }

  Future<void> deletePlaylist(int playlistId) async {
    final databaseFile = await _resolveDatabaseFile();
    await LibraryRepository._playlistService.deletePlaylist(
      databaseFile,
      playlistId,
    );
  }

  Future<void> restorePlaylist(LibraryPlaylist playlist) async {
    final databaseFile = await _resolveDatabaseFile();
    await LibraryRepository._playlistService.restorePlaylist(
      databaseFile,
      playlist,
    );
  }

  Future<void> renamePlaylist(int playlistId, String name) async {
    final databaseFile = await _resolveDatabaseFile();
    await LibraryRepository._playlistService.renamePlaylist(
      databaseFile,
      playlistId,
      name,
    );
  }

  Future<void> reorderPlaylists(List<int> playlistIds) async {
    final databaseFile = await _resolveDatabaseFile();
    await LibraryRepository._playlistService.reorderPlaylists(
      databaseFile,
      playlistIds,
    );
  }

  Future<void> addPreferenceItem(
    String type,
    String itemId,
    String name,
    String level,
  ) async {
    final databaseFile = await _resolveDatabaseFile();
    await LibraryRepository._preferenceService.addPreferenceItem(
      databaseFile,
      type,
      itemId,
      name,
      level,
    );
  }

  Future<String?> getPreferenceLevel(String type, String itemId) async {
    final databaseFile = await _resolveDatabaseFile();
    return LibraryRepository._preferenceService.getPreferenceLevel(
      databaseFile,
      type,
      itemId,
    );
  }

  Future<void> removePreferenceItem(String type, String itemId) async {
    final databaseFile = await _resolveDatabaseFile();
    await LibraryRepository._preferenceService.removePreferenceItem(
      databaseFile,
      type,
      itemId,
    );
  }

  Future<PreferenceSettingsSnapshot> getPreferenceSettings({
    required String unknownAlbumName,
  }) async {
    final databaseFile = await _resolveDatabaseFile();
    return LibraryRepository._preferenceService.getPreferenceSettings(
      databaseFile,
      unknownAlbumName: unknownAlbumName,
    );
  }

  Future<void> updatePreferenceSettings(
    Map<PreferenceSectionKey, bool> enabled,
  ) async {
    final databaseFile = await _resolveDatabaseFile();
    await LibraryRepository._preferenceService.updatePreferenceSettings(
      databaseFile,
      enabled,
    );
  }

  Future<void> updatePreferenceItem(
    int itemId, {
    bool? isEnabled,
    PreferenceLevel? level,
  }) async {
    final databaseFile = await _resolveDatabaseFile();
    await LibraryRepository._preferenceService.updatePreferenceItem(
      databaseFile,
      itemId,
      isEnabled: isEnabled,
      level: level,
    );
  }

  Future<void> removePreferenceItemById(int itemId) async {
    final databaseFile = await _resolveDatabaseFile();
    await LibraryRepository._preferenceService.removePreferenceItemById(
      databaseFile,
      itemId,
    );
  }

  Future<void> clearInvalidPreferenceItems(PreferenceEntityType type) async {
    final databaseFile = await _resolveDatabaseFile();
    await LibraryRepository._preferenceService.clearInvalidPreferenceItems(
      databaseFile,
      type,
    );
  }

  Future<void> addSongToPlaylist(int playlistId, int songId) async {
    await addSongsToPlaylist(playlistId, [songId]);
  }

  Future<void> addSongsToPlaylist(int playlistId, List<int> songIds) async {
    final databaseFile = await _resolveDatabaseFile();
    await LibraryRepository._playlistService.addSongsToPlaylist(
      databaseFile,
      playlistId,
      songIds,
    );
  }

  Future<void> removeSongFromPlaylist(int playlistId, int songId) async {
    await removeSongsFromPlaylist(playlistId, [songId]);
  }

  Future<void> removeSongsFromPlaylist(
    int playlistId,
    List<int> songIds,
  ) async {
    final databaseFile = await _resolveDatabaseFile();
    await LibraryRepository._playlistService.removeSongsFromPlaylist(
      databaseFile,
      playlistId,
      songIds,
    );
  }

  Future<void> reorderPlaylistSongs(
    int playlistId,
    List<int> songIds, [
    PlaylistSortCriterion? sortCriterion,
  ]) async {
    final databaseFile = await _resolveDatabaseFile();
    await LibraryRepository._playlistService.reorderPlaylistSongs(
      databaseFile,
      playlistId,
      songIds,
      sortCriterion,
    );
  }

  Future<RecentPlaylistPlayback> recordPlaylistPlayed(int playlistId) async {
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
