part of 'library_repository.dart';

final class LocalLibraryDataSource implements LibraryDataSource {
  const LocalLibraryDataSource(this.repository);
  final LibraryRepository repository;
  @override
  LocalLibrarySource get source => const LocalLibrarySource();
  @override
  bool get canWrite => true;

  @override
  Future<LibraryPlaylist> createPlaylist(String name, List<int> songIds) async {
    final result = await LibraryRepository._playlistService.createPlaylist(
      await repository._resolveDatabaseFile(),
      name,
      songIds,
    );
    activeMusicShareAccess?.localDataChanged('library');
    return result;
  }

  @override
  Future<void> deletePlaylist(int id) async {
    await LibraryRepository._playlistService.deletePlaylist(
      await repository._resolveDatabaseFile(),
      id,
    );
    activeMusicShareAccess?.localDataChanged('library');
  }

  @override
  Future<void> restorePlaylist(LibraryPlaylist playlist) async {
    await LibraryRepository._playlistService.restorePlaylist(
      await repository._resolveDatabaseFile(),
      playlist,
    );
    activeMusicShareAccess?.localDataChanged('library');
  }

  @override
  Future<void> renamePlaylist(int id, String name) async {
    await LibraryRepository._playlistService.renamePlaylist(
      await repository._resolveDatabaseFile(),
      id,
      name,
    );
    activeMusicShareAccess?.localDataChanged('library');
  }

  @override
  Future<void> reorderPlaylists(List<int> ids) async {
    final file = await repository._resolveDatabaseFile();
    await LibrarySnapshotService.run(
      () => LibraryRepository._playlistService.reorderPlaylists(file, ids),
    );
    activeMusicShareAccess?.localDataChanged('library');
  }

  @override
  Future<void> addSongsToPlaylist(int id, List<int> songIds) async {
    await LibraryRepository._playlistService.addSongsToPlaylist(
      await repository._resolveDatabaseFile(),
      id,
      songIds,
    );
    activeMusicShareAccess?.localDataChanged('library');
  }

  @override
  Future<void> removeSongsFromPlaylist(int id, List<int> songIds) async {
    await LibraryRepository._playlistService.removeSongsFromPlaylist(
      await repository._resolveDatabaseFile(),
      id,
      songIds,
    );
    activeMusicShareAccess?.localDataChanged('library');
  }

  @override
  Future<void> reorderPlaylistSongs(
    int id,
    List<int> songIds,
    PlaylistSortCriterion? criterion,
  ) async {
    await LibraryRepository._playlistService.reorderPlaylistSongs(
      await repository._resolveDatabaseFile(),
      id,
      songIds,
      criterion,
    );
    activeMusicShareAccess?.localDataChanged('library');
  }

  @override
  Future<SongPropertiesSnapshot> getProperty(LibrarySong song) async =>
      LibraryRepository._songPropertiesService.getSongProperties(
        await repository._resolveDatabaseFile(),
        song.id,
      );
  @override
  Future<void> updateProperty(
    LibrarySong song,
    SongPropertiesUpdate update,
  ) async {
    await LibraryRepository._songPropertiesService.updateSongProperties(
      await repository._resolveDatabaseFile(),
      song.id,
      update,
    );
    activeMusicShareAccess?.localDataChanged('library');
  }

  @override
  Future<List<SongPropertiesSnapshot>> getProperties(
    List<LibrarySong> songs,
  ) async {
    return LibraryRepository._songPropertiesService.getSongPropertiesBatch(
      await repository._resolveDatabaseFile(),
      songs.map((s) => s.id).toList(),
    );
  }

  @override
  Future<BatchSongPropertiesUpdateResult> updateProperties(
    List<LibrarySong> songs,
    Map<int, SongPropertiesUpdate> updates,
  ) async {
    final result = await LibraryRepository._songPropertiesService
        .updateSongPropertiesBatch(
          await repository._resolveDatabaseFile(),
          updates,
        );
    activeMusicShareAccess?.localDataChanged('library');
    return result;
  }

  @override
  Future<void> setFavorites(List<LibrarySong> songs, bool favorite) async {
    final file = await repository._resolveDatabaseFile();
    repository._initializeLibraryDatabaseFile(file);
    await LibraryRepository._playlistService.setSongsFavorite(
      file,
      songs.map((s) => s.id).toList(),
      favorite,
    );
    activeMusicShareAccess?.localDataChanged('library');
  }

  @override
  Future<void> updatePlayCount(LibrarySong song, int count) async {
    await LibraryRepository._songPropertiesService.updateSongPlayCount(
      await repository._resolveDatabaseFile(),
      song.id,
      count,
    );
    activeMusicShareAccess?.localDataChanged('library');
  }

  @override
  Future<void> saveLyrics(LibrarySong song, String text) async {
    final file = await repository._resolveDatabaseFile();
    await repository._lyricsService.saveSongLyrics(file, song.id, text);
    await repository._lyricsSearchService.refreshSongIds(file, [song.id]);
    activeMusicShareAccess?.localDataChanged('library');
  }

  @override
  Future<void> updateLyricsOffset(LibrarySong song, int offsetMs) async {
    await repository._lyricsService.updateLyricsOffset(
      await repository._resolveDatabaseFile(),
      song.id,
      offsetMs,
    );
    activeMusicShareAccess?.localDataChanged('library');
  }

  @override
  Future<void> writeArtwork(List<LibrarySong> songs, String? sourcePath) async {
    final file = await repository._resolveDatabaseFile();
    if (songs.length == 1) {
      if (sourcePath == null) {
        await repository._artworkService.deleteSongArtwork(
          file,
          songs.single.id,
        );
      } else {
        await repository._artworkService.saveSongArtwork(
          file,
          songs.single.id,
          sourcePath,
        );
      }
    } else {
      await repository._artworkService.updateSongsArtwork(
        file,
        songs.map((s) => s.id).toList(),
        sourcePath,
      );
    }
    activeMusicShareAccess?.localDataChanged('library');
  }

  @override
  Future<void> writeAlbumArtwork(
    String album,
    List<LibrarySong> songs,
    String? sourcePath,
  ) async {
    final file = await repository._resolveDatabaseFile();
    if (sourcePath == null) {
      await repository._artworkService.deleteAlbumArtwork(file, album);
    } else {
      await repository._artworkService.saveAlbumArtwork(
        file,
        album,
        sourcePath,
      );
    }
    activeMusicShareAccess?.localDataChanged('library');
  }

  @override
  Future<void> addPreferenceItem(
    String type,
    String itemId,
    String name,
    String level,
  ) async {
    await LibraryRepository._preferenceService.addPreferenceItem(
      await repository._resolveDatabaseFile(),
      type,
      itemId,
      name,
      level,
    );
    activeMusicShareAccess?.localDataChanged('preferences');
  }

  @override
  Future<String?> getPreferenceLevel(String type, String itemId) async {
    return LibraryRepository._preferenceService.getPreferenceLevel(
      await repository._resolveDatabaseFile(),
      type,
      itemId,
    );
  }

  @override
  Future<void> removePreferenceItem(String type, String itemId) async {
    await LibraryRepository._preferenceService.removePreferenceItem(
      await repository._resolveDatabaseFile(),
      type,
      itemId,
    );
    activeMusicShareAccess?.localDataChanged('preferences');
  }

  @override
  Future<void> updatePreferenceSettings(
    Map<PreferenceSectionKey, bool> enabled,
  ) async {
    await LibraryRepository._preferenceService.updatePreferenceSettings(
      await repository._resolveDatabaseFile(),
      enabled,
    );
    activeMusicShareAccess?.localDataChanged('preferences');
  }

  @override
  Future<void> updatePreferenceItem(
    int itemId, {
    bool? isEnabled,
    PreferenceLevel? level,
  }) async {
    await LibraryRepository._preferenceService.updatePreferenceItem(
      await repository._resolveDatabaseFile(),
      itemId,
      isEnabled: isEnabled,
      level: level,
    );
    activeMusicShareAccess?.localDataChanged('preferences');
  }

  @override
  Future<void> removePreferenceItemById(int itemId) async {
    await LibraryRepository._preferenceService.removePreferenceItemById(
      await repository._resolveDatabaseFile(),
      itemId,
    );
    activeMusicShareAccess?.localDataChanged('preferences');
  }

  @override
  Future<void> clearInvalidPreferenceItems(PreferenceEntityType type) async {
    await LibraryRepository._preferenceService.clearInvalidPreferenceItems(
      await repository._resolveDatabaseFile(),
      type,
    );
    activeMusicShareAccess?.localDataChanged('preferences');
  }

  @override
  Future<PreferenceSettingsSnapshot> getPreferenceSettings({
    required String unknownAlbumName,
    bool initialize = true,
  }) async => LibraryRepository._preferenceService.getPreferenceSettings(
    await repository._resolveDatabaseFile(),
    unknownAlbumName: unknownAlbumName,
    initialize: initialize,
  );
}
