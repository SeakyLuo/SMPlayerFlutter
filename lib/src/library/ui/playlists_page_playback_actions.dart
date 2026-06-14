part of 'playlists_page.dart';

extension _PlaylistsPagePlaybackActions on _PlaylistsPageState {
  void _patchNowPlaying(List<int> songIds) {
    final patchedSongIds = songIds.toList();
    setState(() {
      _nowPlayingSongIdsOverride = patchedSongIds;
    });
    ref.read(nowPlayingQueueOverrideProvider.notifier).state = patchedSongIds;
  }

  void _playTrack(
    LibraryContentData snapshot,
    SmPlayerI18n i18n,
    int trackId,
    List<int> queueSongIds,
  ) {
    final songsById = {for (final song in snapshot.songs) song.id: song};
    final song = songsById[trackId]!;
    _patchNowPlaying(queueSongIds);
    unawaited(
      ref.read(libraryRepositoryProvider).replaceNowPlaying(queueSongIds),
    );
    ref
        .read(mediaControlControllerProvider)
        .playTrack(
          mediaControlTrackForSong(song, i18n),
          durationSeconds: song.duration.toDouble(),
          queueIndex: queueSongIds.indexOf(trackId),
        );
  }

  void _playNext(LibraryContentData snapshot, int songId) {
    final queueSongIds = snapshot.nowPlaying.songIds.toList();
    final currentTrackId =
        ref.read(mediaControlControllerProvider).state.track.id;
    final currentIndex =
        currentTrackId == null ? -1 : queueSongIds.indexOf(currentTrackId);
    queueSongIds.insert(currentIndex < 0 ? 0 : currentIndex + 1, songId);
    _patchNowPlaying(queueSongIds);
    unawaited(
      ref.read(libraryRepositoryProvider).replaceNowPlaying(queueSongIds),
    );
  }
}
