part of 'shell_page.dart';

extension _SmPlayerShellQueueMethods on _SmPlayerShellPageState {
  void _playSongQueue(List<LibrarySong> songs) {
    final songIds = songs.map((song) => song.id).toList();
    final firstSong = songs.first;
    ref.read(libraryRepositoryProvider).replaceNowPlaying(songIds);
    ref.invalidate(libraryContentDataProvider);
    _mediaControlController.playTrack(
      mediaControlTrackForSong(firstSong, context.smPlayerI18n),
      durationSeconds: firstSong.duration.toDouble(),
      queueIndex: 0,
    );
  }

  bool _playNextFromCurrentQueue({bool automatic = false}) {
    return _playQueueDirection(forward: true, automatic: automatic);
  }

  bool _playPreviousFromCurrentQueue({bool forcePrevious = false}) {
    final snapshot = ref.read(libraryContentDataProvider).valueOrNull;
    if (snapshot == null) {
      return false;
    }
    final playbackSongIds = _playbackSongIds(snapshot);
    if (playbackSongIds.isEmpty) {
      return false;
    }
    final progressSeconds = _audioPlayer.position.inMilliseconds / 1000;
    if (!forcePrevious &&
        shouldRestartCurrentTrackForPrevious(
          progressSeconds: progressSeconds,
          queueLength: playbackSongIds.length,
          restartAfterThresholdEnabled:
              _settingsController.snapshot.previousButtonRestartsTrack,
        )) {
      unawaited(_audioPlayer.seek(Duration.zero));
      _syncingAudioPlayer = true;
      _mediaControlController.syncPlaybackProgress(0);
      if (!_mediaControlController.state.isPlaying) {
        _mediaControlController.setTrackLoading(false);
      }
      _syncingAudioPlayer = false;
      _settingsController.savePlaybackSettingsImmediate(
        const PlaybackSettingsUpdate(musicProgress: 0),
      );
      return true;
    }
    return _playQueueDirection(forward: false, automatic: false);
  }

  bool _playQueueDirection({required bool forward, required bool automatic}) {
    final snapshot = ref.read(libraryContentDataProvider).valueOrNull;
    if (snapshot == null) {
      return false;
    }
    final playbackSongIds = _playbackSongIds(snapshot);
    if (playbackSongIds.isEmpty) {
      return false;
    }

    final currentIndex = _currentQueueIndex(snapshot, playbackSongIds);
    if (automatic &&
        forward &&
        _mediaControlController.state.mode == PlaybackMode.shuffle &&
        _settingsController.snapshot.shuffleAfterOneRound &&
        currentIndex >= playbackSongIds.length - 1) {
      return _shuffleAndPlayNextRound(snapshot, playbackSongIds);
    }

    final nextIndex = nextQueueIndexForPlayback(
      queueLength: playbackSongIds.length,
      currentIndex: currentIndex,
      mode: _mediaControlController.state.mode,
      forward: forward,
      automatic: automatic,
    );
    if (nextIndex == null) {
      return false;
    }

    _playQueueIndex(snapshot, playbackSongIds, nextIndex);
    return true;
  }

  bool _shuffleAndPlayNextRound(
    LibraryContentData snapshot,
    List<int> playbackSongIds,
  ) {
    final nextSongIds = shuffleNextRoundSongIds(
      playbackSongIds,
      _mediaControlController.state.track.id,
    );
    unawaited(
      ref.read(libraryRepositoryProvider).replaceNowPlaying(nextSongIds),
    );
    ref.invalidate(libraryContentDataProvider);
    return _playQueueSong(snapshot, nextSongIds.first, 0);
  }

  List<int> _playbackSongIds(LibraryContentData snapshot) {
    return normalizePlaybackQueueSongIds(
      snapshot.nowPlaying.songIds,
      snapshot.songs.map((song) => song.id),
    );
  }

  int _currentQueueIndex(
    LibraryContentData snapshot, [
    List<int>? playbackSongIds,
  ]) {
    return currentPlaybackQueueIndex(
      playbackSongIds ?? _playbackSongIds(snapshot),
      _mediaControlController.state.track.id,
      _mediaControlController.state.selectedQueueIndex ?? -1,
    );
  }

  void _playQueueIndex(
    LibraryContentData snapshot,
    List<int> playbackSongIds,
    int queueIndex,
  ) {
    final played = _playQueueSong(
      snapshot,
      playbackSongIds[queueIndex],
      queueIndex,
    );
    if (!played) {
      return;
    }
  }

  bool _playQueueSong(LibraryContentData snapshot, int songId, int queueIndex) {
    final songsById = {for (final song in snapshot.songs) song.id: song};
    final song = songsById[songId];
    if (song == null) {
      return false;
    }

    final startSeconds = resolveQueuePlaybackStartSeconds(
      currentTrackId: _mediaControlController.state.track.id,
      nextTrackId: song.id,
      currentProgressSeconds: _mediaControlController.state.progressSeconds,
    );
    _mediaControlController.playTrack(
      mediaControlTrackForSong(song, context.smPlayerI18n),
      durationSeconds: song.duration.toDouble(),
      queueIndex: queueIndex,
      progressSeconds: startSeconds,
    );
    _settingsController.savePlaybackSettingsImmediate(
      PlaybackSettingsUpdate(
        lastMusicIndex: queueIndex,
        musicProgress: startSeconds,
      ),
    );
    return true;
  }

  Future<void> _randomPlayPlaylist(WidgetRef ref, int playlistId) async {
    final i18n = context.smPlayerI18n;
    final snapshot = ref.read(libraryContentDataProvider).value!;
    final playlist = snapshot.playlists.firstWhere(
      (playlist) => playlist.id == playlistId,
    );
    final songIds = playlist.songIds.toList()..shuffle(Random());
    if (songIds.isEmpty) {
      return;
    }
    final songsById = {for (final song in snapshot.songs) song.id: song};
    final firstSong = songsById[songIds.first]!;
    final repository = ref.read(libraryRepositoryProvider);
    await repository.recordPlaylistPlayed(playlistId);
    await repository.replaceNowPlaying(songIds);
    _mediaControlController.playTrack(
      mediaControlTrackForSong(firstSong, i18n),
      durationSeconds: firstSong.duration.toDouble(),
      queueIndex: 0,
    );
    ref.invalidate(libraryContentDataProvider);
  }
}
