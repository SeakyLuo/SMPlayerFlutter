part of 'shell_page.dart';

extension _SmPlayerShellQueueMethods on _SmPlayerShellPageState {
  void _playSongQueue(List<LibrarySong> songs) {
    final songIds = songs.map((song) => song.id).toList();
    replaceNowPlayingQueueAndPlayIndex(
      ref: ref,
      snapshot: ref.read(libraryContentDataProvider).value!,
      i18n: context.smPlayerI18n,
      songIds: songIds,
      queueIndex: 0,
      mediaController: _mediaControlController,
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

    var currentIndex = _currentQueueIndex(snapshot, playbackSongIds);
    if (automatic && forward && currentIndex == -1) {
      currentIndex = uniquePlaybackQueueIndex(
        playbackSongIds,
        _mediaControlController.state.track.id,
      );
    }
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
    if (automatic && nextIndex == currentIndex) {
      unawaited(
        _audioPlayer.seek(Duration.zero).then((_) => _audioPlayer.play()),
      );
      _syncingAudioPlayer = true;
      _mediaControlController.syncPlaybackProgress(0);
      _mediaControlController.setPlaybackActive(true);
      _syncingAudioPlayer = false;
      return true;
    }

    return _playQueueIndex(snapshot, playbackSongIds, nextIndex);
  }

  bool _shuffleAndPlayNextRound(
    LibraryContentData snapshot,
    List<int> playbackSongIds,
  ) {
    final nextSongIds = shuffleNextRoundSongIds(
      playbackSongIds,
      _mediaControlController.state.track.id,
    );
    setNowPlayingQueue(ref, nextSongIds);
    return _playQueueSong(snapshot, nextSongIds, 0);
  }

  List<int> _playbackSongIds(LibraryContentData snapshot) {
    final override = ref.read(nowPlayingQueueOverrideProvider);
    if (override != null) {
      return normalizePlaybackQueueSongIds(
        override,
        snapshot.songs.map((song) => song.id),
      );
    }
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

  bool _playQueueIndex(
    LibraryContentData snapshot,
    List<int> playbackSongIds,
    int queueIndex,
  ) {
    final played = _playQueueSong(snapshot, playbackSongIds, queueIndex);
    if (!played) {
      return false;
    }
    return true;
  }

  bool _playQueueSong(
    LibraryContentData snapshot,
    List<int> songIds,
    int queueIndex,
  ) {
    final songsById = {for (final song in snapshot.songs) song.id: song};
    final songId = songIds[queueIndex];
    final song = songsById[songId];
    if (song == null) {
      return false;
    }

    final startSeconds = resolveQueuePlaybackStartSeconds(
      currentTrackId: _mediaControlController.state.track.id,
      nextTrackId: song.id,
      currentQueueIndex: _mediaControlController.state.selectedQueueIndex,
      nextQueueIndex: queueIndex,
      currentProgressSeconds: _mediaControlController.state.progressSeconds,
    );
    playQueueIndex(
      ref: ref,
      snapshot: snapshot,
      i18n: context.smPlayerI18n,
      songIds: songIds,
      queueIndex: queueIndex,
      mediaController: _mediaControlController,
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
    await recordRecentPlaylistPlayback(ref, playlistId);
    replaceNowPlayingQueueAndPlayIndex(
      ref: ref,
      snapshot: snapshot,
      i18n: i18n,
      songIds: songIds,
      queueIndex: 0,
      mediaController: _mediaControlController,
    );
  }
}
