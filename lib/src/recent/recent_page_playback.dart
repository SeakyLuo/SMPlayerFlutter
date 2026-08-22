part of 'recent_page.dart';

// ignore_for_file: invalid_use_of_protected_member

extension _RecentPagePlaybackActions on _RecentPageState {
  void _playSong(LibrarySong song, List<int> queueSongIds, [int? queueIndex]) {
    final snapshot = ref.read(recentPageDataProvider).value!;
    setNowPlayingQueue(ref, queueSongIds);
    playQueueIndexFromSongs(
      ref: ref,
      songs: snapshot.songs,
      i18n: context.smPlayerI18n,
      songIds: queueSongIds,
      queueIndex: queueIndex ?? queueSongIds.indexOf(song.id),
    );
    ref.invalidate(recentPageDataProvider);
  }

  void _playSongIds(List<int> songIds) {
    if (songIds.isEmpty) {
      return;
    }

    final snapshot = ref.read(recentPageDataProvider).value!;
    replaceNowPlayingQueueAndPlayIndexFromSongs(
      ref: ref,
      songs: snapshot.songs,
      persistedSongIds: snapshot.nowPlaying.songIds,
      i18n: context.smPlayerI18n,
      songIds: songIds,
      queueIndex: 0,
    );
    ref.invalidate(recentPageDataProvider);
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
    final previousSongIds = effectiveNowPlayingSongIds(
      ref,
      snapshot.nowPlaying.songIds,
    );
    final queueSongIds = previousSongIds.toList();
    final insertIndex = insertIndexAfterCurrentOccurrence(
      ref.read(mediaControlControllerProvider).state,
      queueSongIds,
    );
    queueSongIds.insert(insertIndex, songId);
    setNowPlayingQueue(ref, queueSongIds);
    ref.invalidate(recentPageDataProvider);
    final songsById = {for (final song in snapshot.songs) song.id: song};
    showPlayNextUndoNotification(
      context: context,
      i18n: context.smPlayerI18n,
      songTitle: songsById[songId]!.title,
      onUndo: () {
        setNowPlayingQueue(ref, previousSongIds);
        ref.invalidate(recentPageDataProvider);
      },
    );
  }
}
