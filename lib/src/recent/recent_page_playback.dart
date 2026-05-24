part of 'recent_page.dart';

// ignore_for_file: invalid_use_of_protected_member

extension _RecentPagePlaybackActions on _RecentPageState {
  void _playSong(LibrarySong song, List<int> queueSongIds, [int? queueIndex]) {
    ref
        .read(mediaControlControllerProvider)
        .playTrack(
          mediaControlTrackForSong(song, context.smPlayerI18n),
          durationSeconds: song.duration.toDouble(),
          queueIndex: queueIndex,
        );
    ref.read(libraryRepositoryProvider).replaceNowPlaying(queueSongIds);
    ref.invalidate(recentPageDataProvider);
  }

  void _playSongIds(List<int> songIds) {
    if (songIds.isEmpty) {
      return;
    }

    final songs = ref.read(recentPageDataProvider).value?.songs ?? const [];
    final songsById = {for (final song in songs) song.id: song};
    _playSong(songsById[songIds.first]!, songIds, 0);
  }

  void _playShuffledSongIds(List<int> songIds) {
    _playSongIds(songIds.toList()..shuffle());
  }

  void _recordRecentCollectionPlayed(
    Future<void> Function(LibraryRepository repository) record,
  ) {
    unawaited(_recordRecentCollectionPlayedAsync(record));
  }

  Future<void> _recordRecentCollectionPlayedAsync(
    Future<void> Function(LibraryRepository repository) record,
  ) async {
    await record(ref.read(libraryRepositoryProvider));
    if (!mounted) {
      return;
    }
    ref.invalidate(recentPageDataProvider);
  }

  String _routeForSearchHistory(SearchHistoryEntry entry) {
    final query = Uri.encodeQueryComponent(entry.query);
    return switch (entry.type) {
      SearchHistoryType.sidebar => '/search?query=$query',
      SearchHistoryType.artists => '/artists?artist=$query',
      SearchHistoryType.albums => '/albums?album=$query',
      SearchHistoryType.songs => '/songs?search=$query',
      SearchHistoryType.playlists => '/playlists?search=$query',
      SearchHistoryType.folders => '/search?type=folders',
    };
  }

  void _playNext(int songId) {
    final snapshot = ref.read(recentPageDataProvider).value!;
    final queueSongIds = snapshot.nowPlaying.songIds.toList();
    final selectedQueueIndex =
        ref.read(mediaControlControllerProvider).state.selectedQueueIndex;
    final insertIndex =
        selectedQueueIndex != null && selectedQueueIndex < queueSongIds.length
            ? selectedQueueIndex + 1
            : queueSongIds.length;
    queueSongIds.insert(insertIndex, songId);
    ref.read(libraryRepositoryProvider).replaceNowPlaying(queueSongIds);
    ref.invalidate(recentPageDataProvider);
  }
}
