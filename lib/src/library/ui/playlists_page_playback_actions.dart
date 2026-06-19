part of 'playlists_page.dart';

// ignore_for_file: invalid_use_of_protected_member

extension _PlaylistsPagePlaybackActions on _PlaylistsPageState {
  void _patchNowPlaying(List<int> songIds) {
    final patchedSongIds = songIds.toList();
    setState(() {
      _nowPlayingSongIdsOverride = patchedSongIds;
    });
    setNowPlayingQueue(ref, patchedSongIds);
  }

  void _playTrack(
    LibraryContentData snapshot,
    SmPlayerI18n i18n,
    int trackId,
    List<int> queueSongIds,
  ) {
    _patchNowPlaying(queueSongIds);
    playQueueIndex(
      ref: ref,
      snapshot: snapshot,
      i18n: i18n,
      songIds: queueSongIds,
      queueIndex: queueSongIds.indexOf(trackId),
    );
  }

  void _playNext(LibraryContentData snapshot, int songId) {
    final queueSongIds = currentNowPlayingSongIds(ref, snapshot);
    final currentIndex = currentQueueIndexForPlaybackOccurrence(
      ref.read(mediaControlControllerProvider).state,
      queueSongIds,
    );
    queueSongIds.insert(currentIndex < 0 ? 0 : currentIndex + 1, songId);
    _patchNowPlaying(queueSongIds);
  }
}
