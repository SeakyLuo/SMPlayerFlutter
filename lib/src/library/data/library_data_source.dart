part of 'library_repository.dart';

/// Operations on library-owned data, including library usage history.
/// Application settings and the current playback session remain local.
abstract interface class LibraryDataSource {
  Future<RecentPageData> readRecentData();
  LibrarySource get source;
  bool get canWrite;
  Future<LibraryContentData> query(LibraryDataQuery query);
  Future<List<LibrarySelectionKind>> selectionModes(int limit);
  Future<LibraryLyricsSearchPage> searchLyrics(
    String query, {
    required String folderPath,
    int offset = 0,
    MusicLibrarySortCriterion? order,
  });
  Future<void> applyArtistSplits(
    Map<int, String> songs,
    List<ArtistSplitResultItem> splits,
  );
  Future<List<int>> selectSongIds(LibrarySelectionRequest request);
  Future<List<int>> resolveSongIds(LibraryDataQuery query);
  Future<ArtistSplitAnalysisResult> analyzeArtists({
    void Function(double)? onProgress,
  });
  Future<LibraryStorageChange> deleteStorageItems(
    Map<int, String> songs,
    List<String> folders,
  );
  Future<LibraryStorageChange> moveStorageItems(
    Map<int, String> songs,
    List<String> folders,
    String target, {
    required LocalMoveConflictResolver resolveConflict,
  });
  Future<LibraryStorageChange> hideSongFile(LibrarySong song);
  Future<void> createStorageFolder(String root, String parent, String name);
  Future<LibraryStorageChange> renameStorageFolder(String path, String name);
  Future<LibraryStorageChange> hideStorageFolder(String path);
  Future<void> updateStorageFolderSort(
    String path,
    LocalFolderSortCriterion criterion,
  );
  Future<LibraryStorageFolders> getStorageFolders(String songPath);
  Future<List<HiddenStorageItem>> getHiddenStorageItems();
  Future<void> resumeHiddenStorageItem(HiddenStorageItem item);
  Future<LocalFolderRefreshResult> refreshStorageFolder(
    String path, {
    required LocalFolderScanCancellation cancellation,
    required void Function(LocalFolderRefreshProgress) onProgress,
    Future<void> Function(LocalFolderRefreshResult)? onLibraryCommitted,
  });
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
  Future<List<SongPropertiesSnapshot>> getProperties(Map<int, String> songs);
  Future<BatchSongPropertiesUpdateResult> updateProperties(
    Map<int, String> songs,
    Map<int, SongPropertiesUpdate> updates,
  );
  Future<List<int>> setFavorites(Map<int, String> songs, bool favorite);
  Future<void> updatePlayCount(LibrarySong song, int count);
  Future<void> saveLyrics(LibrarySong song, String text);
  Future<void> updateLyricsOffset(LibrarySong song, int offsetMs);
  Future<void> writeArtwork(Map<int, String> songs, String? sourcePath);
  Future<void> writeAlbumArtwork(String album, String? sourcePath);
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

  LibraryDataSource selectionDataSourceForSongs(Iterable<LibrarySong> songs) {
    final sources = songs.map((song) => song.source).toSet();
    return dataSource(
      sources.length == 1 ? sources.single : const LocalLibrarySource(),
    );
  }

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

  Map<LibrarySource, Map<int, String>> _groupSongReferences(
    Map<int, String> references,
  ) {
    final groups = <LibrarySource, Map<int, String>>{};
    for (final entry in references.entries) {
      groups.putIfAbsent(LibrarySource.fromPath(entry.value), () => {})[entry
              .key] =
          entry.value;
    }
    return groups;
  }

  void _requireWritable(LibraryDataSource source) {
    if (!source.canWrite) {
      throw const MusicShareException('share.readOnlyPermission');
    }
  }
}
