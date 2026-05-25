part of 'shell_page.dart';

extension _SmPlayerShellPlaybackMethods on _SmPlayerShellPageState {
  bool _isPlaybackShortcutEditableFocus(FocusNode? focus) {
    final context = focus?.context;
    if (context == null) {
      return false;
    }
    final widget = context.widget;
    return widget is EditableText ||
        context.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  void _applyPlaybackShortcut(SmPlayerPlaybackShortcut shortcut) {
    switch (shortcut) {
      case SmPlayerPlaybackShortcut.togglePlayPause:
        _togglePlayPauseFromCurrentQueue();
      case SmPlayerPlaybackShortcut.next:
        _playNextFromCurrentQueue();
      case SmPlayerPlaybackShortcut.previous:
        _playPreviousFromCurrentQueue();
      case SmPlayerPlaybackShortcut.seekForwardShort:
        _seekCurrentTrackBy(5);
      case SmPlayerPlaybackShortcut.seekBackwardShort:
        _seekCurrentTrackBy(-5);
      case SmPlayerPlaybackShortcut.seekForwardLong:
        _seekCurrentTrackBy(30);
      case SmPlayerPlaybackShortcut.seekBackwardLong:
        _seekCurrentTrackBy(-30);
      case SmPlayerPlaybackShortcut.toggleShuffle:
        _toggleShufflePlayback();
      case SmPlayerPlaybackShortcut.toggleRepeat:
        _mediaControlController.onToggleRepeat();
      case SmPlayerPlaybackShortcut.toggleRepeatOne:
        _mediaControlController.onToggleRepeatOne();
    }
  }

  void _seekCurrentTrackBy(double deltaSeconds) {
    final state = _mediaControlController.state;
    if (state.disabled) {
      return;
    }
    _mediaControlController.onSeek(state.progressSeconds + deltaSeconds);
  }

  bool _isPlaybackQueueEmpty(LibraryContentData? snapshot) {
    return snapshot == null || _playbackSongIds(snapshot).isEmpty;
  }

  bool _togglePlayPauseFromCurrentQueue() {
    final state = _mediaControlController.state;
    if (state.track.id != null) {
      _mediaControlController.onTogglePlayPause();
      return true;
    }

    final snapshot = ref.read(libraryContentDataProvider).valueOrNull;
    if (_isPlaybackQueueEmpty(snapshot)) {
      return false;
    }
    _playQueueIndex(snapshot!, _playbackSongIds(snapshot), 0);
    return true;
  }

  void _toggleShufflePlayback() {
    final enablingShuffle =
        _mediaControlController.state.mode != PlaybackMode.shuffle;
    if (enablingShuffle) {
      _shuffleCurrentPlaybackQueue();
    }
    _mediaControlController.onToggleShuffle();
  }

  void _shuffleCurrentPlaybackQueue() {
    final snapshot = ref.read(libraryContentDataProvider).valueOrNull;
    if (snapshot == null) {
      return;
    }
    final playbackSongIds = _playbackSongIds(snapshot);
    if (playbackSongIds.isEmpty) {
      return;
    }
    final nextSongIds = shufflePlaybackQueueForCurrentTrack(
      playbackSongIds,
      _mediaControlController.state.track.id,
    );
    unawaited(
      ref.read(libraryRepositoryProvider).replaceNowPlaying(nextSongIds),
    );
    ref.invalidate(libraryContentDataProvider);
    final nextQueueIndex = currentPlaybackQueueIndex(
      nextSongIds,
      _mediaControlController.state.track.id,
    );
    _mediaControlController.setSelectedQueueIndex(
      nextQueueIndex > -1 ? nextQueueIndex : null,
    );
  }

  void _syncAudioPlayerFromController() {
    if (_syncingAudioPlayer) {
      return;
    }

    final state = _mediaControlController.state;
    unawaited(_audioPlayer.setVolume(state.isMuted ? 0 : state.volume / 100));
    final trackId = state.track.id;
    if (trackId == null) {
      _loadedAudioTrackId = null;
      _loadedAudioPath = null;
      _pendingAudioSeekSeconds = null;
      unawaited(_audioPlayer.stop());
      return;
    }

    final song = _resolvePlayerSong(
      state,
      ref.read(libraryContentDataProvider).valueOrNull,
    );
    if (song == null) {
      return;
    }

    if (_loadedAudioTrackId != song.id || _loadedAudioPath != song.path) {
      unawaited(_loadAudioSong(song, state));
      return;
    }

    unawaited(_applyAudioPlaybackState(state));
  }

  Future<void> _loadAudioSong(LibrarySong song, MediaControlState state) async {
    final loadSerial = _audioLoadSerial + 1;
    _audioLoadSerial = loadSerial;
    _syncingAudioPlayer = true;
    _mediaControlController.setTrackLoading(true);
    _syncingAudioPlayer = false;
    try {
      final duration = await _audioPlayer.setAudioSource(
        LocalAudioFileSource(song.path),
      );
      if (!mounted || loadSerial != _audioLoadSerial) {
        return;
      }
      _loadedAudioTrackId = song.id;
      _loadedAudioPath = song.path;
      if (duration != null) {
        _persistResolvedAudioDuration(song.id, duration);
      }
      _syncingAudioPlayer = true;
      _mediaControlController.syncPlaybackProgress(
        state.progressSeconds,
        durationSeconds:
            duration?.inMilliseconds == null
                ? state.durationSeconds
                : duration!.inMilliseconds / 1000,
      );
      _mediaControlController.setTrackLoading(false);
      _syncingAudioPlayer = false;
      await _applyAudioPlaybackState(_mediaControlController.state);
    } on Object {
      if (loadSerial == _audioLoadSerial) {
        _loadedAudioTrackId = null;
        _loadedAudioPath = null;
        _syncingAudioPlayer = true;
        _mediaControlController.setPlaybackLoadFailed();
        _syncingAudioPlayer = false;
      }
    }
  }

  Future<void> _applyAudioPlaybackState(MediaControlState state) async {
    final targetPosition = Duration(
      milliseconds: (state.progressSeconds * 1000).round(),
    );
    if (!state.isProgressSeeking &&
        (_audioPlayer.position - targetPosition).abs() >
            const Duration(milliseconds: 850)) {
      _pendingAudioSeekSeconds = state.progressSeconds;
      await _audioPlayer.seek(targetPosition);
    }
    await _audioPlayer.setVolume(state.isMuted ? 0 : state.volume / 100);
    if (state.isPlaying) {
      await _audioPlayer.play();
      _startPlaybackStallTimer();
    } else {
      await _audioPlayer.pause();
      _stopPlaybackStallTimer();
    }
  }

  void _handleAudioPositionChanged(Duration position) {
    if (_syncingAudioPlayer ||
        _mediaControlController.state.isProgressSeeking) {
      return;
    }

    final positionSeconds = position.inMilliseconds / 1000;
    final pendingSeekSeconds = _pendingAudioSeekSeconds;
    if (shouldIgnoreAudioPositionForPendingSeek(
      positionSeconds: positionSeconds,
      pendingSeekSeconds: pendingSeekSeconds,
      toleranceSeconds: _SmPlayerShellPageState._pendingSeekToleranceSeconds,
    )) {
      return;
    }
    if (pendingSeekSeconds != null) {
      _pendingAudioSeekSeconds = null;
    }

    _syncingAudioPlayer = true;
    _mediaControlController.syncPlaybackProgress(
      positionSeconds,
      durationSeconds:
          _audioPlayer.duration?.inMilliseconds == null
              ? null
              : _audioPlayer.duration!.inMilliseconds / 1000,
    );
    _syncingAudioPlayer = false;
    _markPlaybackProgressForStallDetection(position);
  }

  void _handleAudioDurationChanged(Duration? duration) {
    if (_syncingAudioPlayer || duration == null) {
      return;
    }

    final trackId = _mediaControlController.state.track.id;
    if (trackId != null) {
      _persistResolvedAudioDuration(trackId, duration);
    }
    _syncingAudioPlayer = true;
    _mediaControlController.syncPlaybackProgress(
      _mediaControlController.state.progressSeconds,
      durationSeconds: duration.inMilliseconds / 1000,
    );
    _syncingAudioPlayer = false;
  }

  void _handleAudioPlaybackError(PlayerException error) {
    final progressSeconds = _audioPlayer.position.inMilliseconds / 1000;
    _pendingAudioSeekSeconds = null;
    _stopPlaybackStallTimer();
    unawaited(_audioPlayer.pause());
    _syncingAudioPlayer = true;
    _mediaControlController.setPlaybackRuntimeFailed(progressSeconds);
    _syncingAudioPlayer = false;
  }

  void _persistResolvedAudioDuration(int songId, Duration duration) {
    final durationSeconds = (duration.inMilliseconds / 1000).round();
    if (durationSeconds <= 0 ||
        _persistedAudioDurations[songId] == durationSeconds) {
      return;
    }

    _persistedAudioDurations[songId] = durationSeconds;
    unawaited(
      ref
          .read(libraryRepositoryProvider)
          .updateSongDuration(songId, durationSeconds),
    );
  }

  void _handleAudioPlayerStateChanged(PlayerState state) {
    if (_syncingAudioPlayer) {
      return;
    }

    if (state.processingState == ProcessingState.completed) {
      _finishCurrentAudioTrack();
      return;
    }

    if (state.playing) {
      _startPlaybackStallTimer();
    } else {
      _stopPlaybackStallTimer();
    }

    final backendLoading = _isAudioBackendLoading(state.processingState);
    _syncingAudioPlayer = true;
    if (backendLoading) {
      _mediaControlController.setPlaybackActive(state.playing);
      _mediaControlController.setTrackLoading(
        true,
        buffering: state.processingState == ProcessingState.buffering,
      );
    } else {
      _mediaControlController.setPlaybackActive(state.playing);
      _mediaControlController.setTrackLoading(false);
    }
    _syncingAudioPlayer = false;
    if (!state.playing && _loadedAudioTrackId != null && !backendLoading) {
      _settingsController.savePlaybackSettingsImmediate(
        PlaybackSettingsUpdate(
          musicProgress: _audioPlayer.position.inMilliseconds / 1000,
        ),
      );
    }
  }

  bool _isAudioBackendLoading(ProcessingState processingState) {
    return processingState == ProcessingState.loading ||
        processingState == ProcessingState.buffering;
  }

  void _finishCurrentAudioTrack() {
    unawaited(_finishCurrentAudioTrackAsync());
  }

  Future<void> _finishCurrentAudioTrackAsync() async {
    _stopPlaybackStallTimer();
    final activeTrackId = _mediaControlController.state.track.id;
    if (activeTrackId != null) {
      if (_finishingAudioTrackId == activeTrackId) {
        return;
      }
      _finishingAudioTrackId = activeTrackId;
      try {
        await ref.read(libraryRepositoryProvider).markSongPlayed(activeTrackId);
        if (!mounted) {
          return;
        }
        ref.invalidate(libraryContentDataProvider);
      } finally {
        if (_finishingAudioTrackId == activeTrackId) {
          _finishingAudioTrackId = null;
        }
      }
    }

    if (_mediaControlController.state.mode == PlaybackMode.repeatOne) {
      unawaited(
        _audioPlayer.seek(Duration.zero).then((_) {
          return _audioPlayer.play();
        }),
      );
      _syncingAudioPlayer = true;
      _mediaControlController.syncPlaybackProgress(0);
      _mediaControlController.setPlaybackActive(true);
      _syncingAudioPlayer = false;
      return;
    }
    final advanced = _playNextFromCurrentQueue(automatic: true);
    if (!advanced) {
      _syncingAudioPlayer = true;
      _mediaControlController.completePlayback();
      _syncingAudioPlayer = false;
    }
  }

  void _startPlaybackStallTimer() {
    if (_playbackStallTimer != null) {
      return;
    }
    _stalledProgressStartedAt = null;
    _stalledProgressSeconds = _audioPlayer.position.inMilliseconds / 1000;
    _playbackStallTimer = Timer.periodic(
      _SmPlayerShellPageState._playbackStallCheckInterval,
      (_) {
        _checkPlaybackStall();
      },
    );
  }

  void _stopPlaybackStallTimer() {
    _playbackStallTimer?.cancel();
    _playbackStallTimer = null;
    _stalledProgressStartedAt = null;
    _stalledProgressSeconds = _audioPlayer.position.inMilliseconds / 1000;
  }

  void _markPlaybackProgressForStallDetection(Duration position) {
    final progressSeconds = position.inMilliseconds / 1000;
    if ((progressSeconds - _stalledProgressSeconds).abs() >
        _SmPlayerShellPageState._playbackProgressEpsilonSeconds) {
      _stalledProgressSeconds = progressSeconds;
      _stalledProgressStartedAt = null;
    }
  }

  void _checkPlaybackStall() {
    final state = _mediaControlController.state;
    final currentProgressSeconds = _audioPlayer.position.inMilliseconds / 1000;
    final startedAt = _stalledProgressStartedAt;
    if ((currentProgressSeconds - _stalledProgressSeconds).abs() >
        _SmPlayerShellPageState._playbackProgressEpsilonSeconds) {
      _stalledProgressSeconds = currentProgressSeconds;
      _stalledProgressStartedAt = null;
      return;
    }
    final now = DateTime.now();
    _stalledProgressStartedAt ??= now;
    final stalledFor = now.difference(startedAt ?? now);
    final durationSeconds =
        _audioPlayer.duration?.inMilliseconds == null
            ? state.durationSeconds
            : _audioPlayer.duration!.inMilliseconds / 1000;
    final action = stalledPlaybackRecoveryAction(
      isPlaying: state.isPlaying,
      isUserSeeking: state.isProgressSeeking,
      currentProgressSeconds: currentProgressSeconds,
      lastProgressSeconds: _stalledProgressSeconds,
      stalledFor: stalledFor,
      durationSeconds: durationSeconds,
      progressEpsilonSeconds:
          _SmPlayerShellPageState._playbackProgressEpsilonSeconds,
      stallTimeout: _SmPlayerShellPageState._playbackStallTimeout,
    );
    switch (action) {
      case PlaybackStallRecoveryAction.none:
        return;
      case PlaybackStallRecoveryAction.finishTrack:
        _stalledProgressStartedAt = null;
        _finishCurrentAudioTrack();
      case PlaybackStallRecoveryAction.pauseAndRecover:
        _recoverFromStalledPlayback(currentProgressSeconds);
    }
  }

  void _recoverFromStalledPlayback(double progressSeconds) {
    _stopPlaybackStallTimer();
    unawaited(_audioPlayer.pause());
    _syncingAudioPlayer = true;
    _mediaControlController.setTrackLoading(false);
    _mediaControlController.setPlaybackActive(false);
    _mediaControlController.syncPlaybackProgress(progressSeconds);
    _mediaControlController.setPlaybackNotice('notification.playbackStalled');
    _syncingAudioPlayer = false;
    _settingsController.savePlaybackSettingsImmediate(
      PlaybackSettingsUpdate(musicProgress: progressSeconds),
    );
  }
}
