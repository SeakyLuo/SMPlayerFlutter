part of 'library_repository.dart';

/// Operations on library-owned data. Application settings and playback history
/// remain local and do not follow the selected browsing source.
abstract interface class LibraryDataSource {
  LibrarySource get source;
  bool get canWrite;
  Future<LibraryPlaylist> createPlaylist(String name, List<int> songIds);
  Future<void> deletePlaylist(int id);
  Future<void> restorePlaylist(LibraryPlaylist playlist);
  Future<void> renamePlaylist(int id, String name);
  Future<void> reorderPlaylists(List<int> ids);
  Future<void> addSongsToPlaylist(int id, List<int> songIds);
  Future<void> removeSongsFromPlaylist(int id, List<int> songIds);
  Future<void> reorderPlaylistSongs(
    int id,
    List<int> songIds,
    PlaylistSortCriterion? criterion,
  );
  Future<SongPropertiesSnapshot> getProperty(LibrarySong song);
  Future<void> updateProperty(LibrarySong song, SongPropertiesUpdate update);
  Future<List<SongPropertiesSnapshot>> getProperties(List<LibrarySong> songs);
  Future<BatchSongPropertiesUpdateResult> updateProperties(
    List<LibrarySong> songs,
    Map<int, SongPropertiesUpdate> updates,
  );
  Future<void> setFavorites(List<LibrarySong> songs, bool favorite);
  Future<void> updatePlayCount(LibrarySong song, int count);
  Future<void> saveLyrics(LibrarySong song, String text);
  Future<void> updateLyricsOffset(LibrarySong song, int offsetMs);
  Future<void> writeArtwork(List<LibrarySong> songs, String? sourcePath);
  Future<void> writeAlbumArtwork(
    String album,
    List<LibrarySong> songs,
    String? sourcePath,
  );
  Future<void> addPreferenceItem(
    String type,
    String itemId,
    String name,
    String level,
  );
  Future<String?> getPreferenceLevel(String type, String itemId);
  Future<void> removePreferenceItem(String type, String itemId);
  Future<void> updatePreferenceSettings(
    Map<PreferenceSectionKey, bool> enabled,
  );
  Future<void> updatePreferenceItem(
    int itemId, {
    bool? isEnabled,
    PreferenceLevel? level,
  });
  Future<void> removePreferenceItemById(int itemId);
  Future<void> clearInvalidPreferenceItems(PreferenceEntityType type);
  Future<PreferenceSettingsSnapshot> getPreferenceSettings({
    required String unknownAlbumName,
    bool initialize = true,
  });
}

mixin _LibraryDataSources {
  LibraryDataSource dataSource(LibrarySource source) => switch (source) {
    LocalLibrarySource() => LocalLibraryDataSource(this as LibraryRepository),
    RemoteLibrarySource() => RemoteLibraryDataSource(
      source,
      activeMusicShareAccess!,
      this as LibraryRepository,
    ),
  };

  LibrarySource _playlistSource(int id) {
    // Legacy session IDs are decoded only at the repository boundary.
    if (id >= 0) return const LocalLibrarySource();
    return activeMusicShareAccess!.remotePlaylists
        .firstWhere((p) => p.id == id)
        .source;
  }

  LibraryDataSource _playlistDataSource(int id) =>
      dataSource(_playlistSource(id));

  LibraryDataSource _playlistOrderDataSource(List<int> ids) {
    final sources = ids.map(_playlistSource).toSet();
    if (sources.length > 1) {
      throw const MusicShareException('share.sameDeviceSongs');
    }
    return dataSource(
      sources.isEmpty ? const LocalLibrarySource() : sources.single,
    );
  }

  Map<LibrarySource, List<LibrarySong>> _groupEditingSongs(
    List<LibrarySong> songs,
  ) {
    final groups = <LibrarySource, List<LibrarySong>>{};
    for (final song in songs) {
      (groups[song.source] ??= []).add(song);
    }
    return groups;
  }

  void _requireWritable(LibraryDataSource source) {
    if (!source.canWrite) {
      throw const MusicShareException('share.readOnlyPermission');
    }
  }
}
