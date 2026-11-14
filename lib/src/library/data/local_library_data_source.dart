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
    return LibraryRepository._playlistService.createPlaylist(
      await repository._resolveDatabaseFile(),
      name,
      songIds,
    );
  }

  @override
  Future<void> deletePlaylist(int id) async {
    await LibraryRepository._playlistService.deletePlaylist(
      await repository._resolveDatabaseFile(),
      id,
    );
  }

  @override
  Future<void> restorePlaylist(LibraryPlaylist playlist) async {
    await LibraryRepository._playlistService.restorePlaylist(
      await repository._resolveDatabaseFile(),
      playlist,
    );
  }

  @override
  Future<void> renamePlaylist(int id, String name) async {
    await LibraryRepository._playlistService.renamePlaylist(
      await repository._resolveDatabaseFile(),
      id,
      name,
    );
  }

  @override
  Future<void> reorderPlaylists(List<int> ids) async {
    final file = await repository._resolveDatabaseFile();
    await LibrarySnapshotService.run(
      () => LibraryRepository._playlistService.reorderPlaylists(file, ids),
    );
  }

  @override
  Future<void> addSongsToPlaylist(int id, List<int> songIds) async {
    await LibraryRepository._playlistService.addSongsToPlaylist(
      await repository._resolveDatabaseFile(),
      id,
      songIds,
    );
  }

  @override
  Future<void> removeSongsFromPlaylist(int id, List<int> songIds) async {
    await LibraryRepository._playlistService.removeSongsFromPlaylist(
      await repository._resolveDatabaseFile(),
      id,
      songIds,
    );
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
  ) async => LibraryRepository._songPropertiesService.updateSongProperties(
    await repository._resolveDatabaseFile(),
    song.id,
    update,
  );

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
    return LibraryRepository._songPropertiesService.updateSongPropertiesBatch(
      await repository._resolveDatabaseFile(),
      updates,
    );
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
  }

  @override
  Future<void> updatePlayCount(LibrarySong song, int count) async {
    await LibraryRepository._songPropertiesService.updateSongPlayCount(
      await repository._resolveDatabaseFile(),
      song.id,
      count,
    );
  }

  @override
  Future<void> saveLyrics(LibrarySong song, String text) async {
    final file = await repository._resolveDatabaseFile();
    await repository._lyricsService.saveSongLyrics(file, song.id, text);
    await repository._lyricsSearchService.refreshSongIds(file, [song.id]);
  }

  @override
  Future<void> updateLyricsOffset(LibrarySong song, int offsetMs) async {
    await repository._lyricsService.updateLyricsOffset(
      await repository._resolveDatabaseFile(),
      song.id,
      offsetMs,
    );
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
  }

  @override
  Future<void> addPreferenceItem(
    String type,
    String itemId,
    String name,
    String level,
  ) async {
    return LibraryRepository._preferenceService.addPreferenceItem(
      await repository._resolveDatabaseFile(),
      type,
      itemId,
      name,
      level,
    );
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
    return LibraryRepository._preferenceService.removePreferenceItem(
      await repository._resolveDatabaseFile(),
      type,
      itemId,
    );
  }

  @override
  Future<void> updatePreferenceSettings(
    Map<PreferenceSectionKey, bool> enabled,
  ) async {
    return LibraryRepository._preferenceService.updatePreferenceSettings(
      await repository._resolveDatabaseFile(),
      enabled,
    );
  }

  @override
  Future<void> updatePreferenceItem(
    int itemId, {
    bool? isEnabled,
    PreferenceLevel? level,
  }) async {
    return LibraryRepository._preferenceService.updatePreferenceItem(
      await repository._resolveDatabaseFile(),
      itemId,
      isEnabled: isEnabled,
      level: level,
    );
  }

  @override
  Future<void> removePreferenceItemById(int itemId) async {
    return LibraryRepository._preferenceService.removePreferenceItemById(
      await repository._resolveDatabaseFile(),
      itemId,
    );
  }

  @override
  Future<void> clearInvalidPreferenceItems(PreferenceEntityType type) async {
    return LibraryRepository._preferenceService.clearInvalidPreferenceItems(
      await repository._resolveDatabaseFile(),
      type,
    );
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
