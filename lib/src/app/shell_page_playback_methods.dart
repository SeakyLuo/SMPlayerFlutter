part of 'shell_page.dart';

extension _SmPlayerShellPlaybackMethods on _SmPlayerShellPageState {
  bool _shouldIgnorePlaybackShortcutFocus(FocusNode? focus) {
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
      case SmPlayerPlaybackShortcut.play:
        _playFromCurrentQueue();
      case SmPlayerPlaybackShortcut.pause:
        _pauseCurrentPlayback();
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

  void _playFromCurrentQueue() {
    if (_mediaControlController.state.isPlaying) {
      return;
    }
    _togglePlayPauseFromCurrentQueue();
  }

  void _pauseCurrentPlayback() {
    if (!_mediaControlController.state.isPlaying) {
      return;
    }
    _mediaControlController.onTogglePlayPause();
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
    int? selectedQueueIndex;
    if (enablingShuffle) {
      selectedQueueIndex = _shuffleCurrentPlaybackQueue();
    }
    _mediaControlController.onToggleShuffle(
      selectedQueueIndex: selectedQueueIndex,
    );
  }

  int? _shuffleCurrentPlaybackQueue() {
    final snapshot = ref.read(libraryContentDataProvider).valueOrNull;
    if (snapshot == null) {
      return null;
    }
    final playbackSongIds = _playbackSongIds(snapshot);
    if (playbackSongIds.isEmpty) {
      return null;
    }
    final nextSongIds = shufflePlaybackQueueForCurrentTrack(
      playbackSongIds,
      _mediaControlController.state.track.id,
    );
    setNowPlayingQueue(ref, nextSongIds);
    final nextQueueIndex = currentPlaybackQueueIndex(
      nextSongIds,
      _mediaControlController.state.track.id,
    );
    return nextQueueIndex > -1 ? nextQueueIndex : null;
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
      _loadingAudioTrackId = null;
      _loadingAudioPath = null;
      _pendingAudioAutoplay = false;
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
      if (_loadingAudioTrackId == song.id && _loadingAudioPath == song.path) {
        _pendingAudioAutoplay = state.isPlaying;
        return;
      }
      unawaited(_loadAudioSong(song, state));
      return;
    }

    unawaited(_applyAudioPlaybackState(state));
  }

  Future<void> _loadAudioSong(LibrarySong song, MediaControlState state) async {
    final loadSerial = _audioLoadSerial + 1;
    _audioLoadSerial = loadSerial;
    _loadingAudioTrackId = song.id;
    _loadingAudioPath = song.path;
    _pendingAudioAutoplay = state.isPlaying;
    _syncingAudioPlayer = true;
    _mediaControlController.setTrackLoading(true);
    _syncingAudioPlayer = false;
    try {
      await verifyAudioFileReadable(song.path);
      final duration = await _audioPlayer.setFilePath(song.path);
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
      final playbackState = _mediaControlController.state;
      _loadingAudioTrackId = null;
      _loadingAudioPath = null;
      _pendingAudioAutoplay = false;
      _syncingAudioPlayer = false;
      await _applyAudioPlaybackState(playbackState);
    } on PlayerInterruptedException {
      return;
    } on Object catch (error, stackTrace) {
      if (loadSerial != _audioLoadSerial) {
        return;
      }
      debugPrint(
        'Simple Melody Player failed to load audio file: ${song.path}\n'
        '$error\n'
        '$stackTrace',
      );
      if (isAudioFilePermissionDenied(error) && mounted) {
        _showAudioFileAccessNotification();
      }
      _loadedAudioTrackId = null;
      _loadedAudioPath = null;
      _loadingAudioTrackId = null;
      _loadingAudioPath = null;
      _pendingAudioAutoplay = false;
      _syncingAudioPlayer = true;
      _mediaControlController.setPlaybackLoadFailed();
      _syncingAudioPlayer = false;
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
    final state = _mediaControlController.state;
    final trackId = state.track.id;
    if (_loadedAudioTrackId != trackId && _loadingAudioTrackId != trackId) {
      return;
    }
    if (Platform.isWindows && error.message == 'Error decoding audio.') {
      return;
    }
    debugPrint('Simple Melody Player audio playback error: $error');
    final progressSeconds = _audioPlayer.position.inMilliseconds / 1000;
    _audioLoadSerial += 1;
    _loadedAudioTrackId = null;
    _loadedAudioPath = null;
    _loadingAudioTrackId = null;
    _loadingAudioPath = null;
    _pendingAudioAutoplay = false;
    _pendingAudioSeekSeconds = null;
    _stopPlaybackStallTimer();
    unawaited(_recoverFromAudioPlaybackError(error, state, progressSeconds));
  }

  Future<void> _recoverFromAudioPlaybackError(
    PlayerException error,
    MediaControlState failedState,
    double progressSeconds,
  ) async {
    _syncingAudioPlayer = true;
    try {
      await _audioPlayer.stop();
    } finally {
      _syncingAudioPlayer = false;
    }
    if (!mounted) {
      return;
    }
    if (_mediaControlController.state.track.id != failedState.track.id) {
      _syncAudioPlayerFromController();
      return;
    }
    final permissionDenied = isAudioFilePermissionDenied(error);
    if (permissionDenied) {
      _showAudioFileAccessNotification();
    } else if (failedState.isPlaying &&
        failedState.mode != PlaybackMode.repeatOne &&
        _playNextFromCurrentQueue(automatic: true)) {
      return;
    }
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

    final canFinishCurrentTrack =
        _loadedAudioTrackId != null &&
        _loadedAudioTrackId == _mediaControlController.state.track.id &&
        _loadingAudioTrackId == null;
    if (state.processingState == ProcessingState.completed) {
      // The Windows adapter resets position to zero when it reports completion.
      // Events from the previous source can still arrive while loading a track.
      if (canFinishCurrentTrack) {
        _finishCurrentAudioTrack();
      }
      return;
    }

    final duration = _audioPlayer.duration;
    final reachedEnd =
        canFinishCurrentTrack &&
        _mediaControlController.state.isPlaying &&
        duration != null &&
        duration - _audioPlayer.position <= const Duration(milliseconds: 500) &&
        !state.playing;
    if (reachedEnd) {
      _finishCurrentAudioTrack();
      return;
    }

    if (state.playing) {
      _startPlaybackStallTimer();
    } else {
      _stopPlaybackStallTimer();
    }

    final backendLoading = _isAudioBackendLoading(state.processingState);
    final waitingForCurrentLoad =
        _loadingAudioTrackId == _mediaControlController.state.track.id;
    final pendingAutoplay = waitingForCurrentLoad && _pendingAudioAutoplay;
    final showTrackLoading = shouldShowAudioBackendLoading(
      backendLoading: backendLoading,
      waitingForCurrentLoad: waitingForCurrentLoad,
      pendingAutoplay: pendingAutoplay,
      backendPlaying: state.playing,
    );
    _syncingAudioPlayer = true;
    if (shouldApplyAudioBackendPlayingState(
      backendLoading: backendLoading,
      backendPlaying: state.playing,
      pendingAutoplay: pendingAutoplay,
    )) {
      _mediaControlController.setPlaybackActive(state.playing);
    }
    if (showTrackLoading) {
      _mediaControlController.setTrackLoading(
        true,
        buffering: state.processingState == ProcessingState.buffering,
      );
    } else {
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
    final state = _mediaControlController.state;
    final activeTrackId = state.track.id;
    if (activeTrackId != null && _finishingAudioTrackId == activeTrackId) {
      return;
    }
    _finishingAudioTrackId = activeTrackId;

    try {
      if (activeTrackId != null) {
        unawaited(_recordFinishedAudioTrack(activeTrackId));
      }
      if (state.mode == PlaybackMode.repeatOne) {
        await _restartCompletedAudioTrack(activeTrackId);
      } else {
        final advanced = _playNextFromCurrentQueue(automatic: true);
        if (!advanced) {
          _syncingAudioPlayer = true;
          _mediaControlController.completePlayback();
          _syncingAudioPlayer = false;
        }
      }
    } finally {
      if (_finishingAudioTrackId == activeTrackId) {
        _finishingAudioTrackId = null;
      }
    }
  }

  Future<void> _restartCompletedAudioTrack(int? activeTrackId) async {
    _syncingAudioPlayer = true;
    try {
      await _audioPlayer.seek(Duration.zero);
      final state = _mediaControlController.state;
      if (!mounted ||
          state.track.id != activeTrackId ||
          state.mode != PlaybackMode.repeatOne ||
          !state.isPlaying) {
        return;
      }
      _mediaControlController.syncPlaybackProgress(0);
      await _audioPlayer.play();
    } finally {
      _syncingAudioPlayer = false;
    }
    _startPlaybackStallTimer();
  }

  Future<void> _recordFinishedAudioTrack(int activeTrackId) async {
    await ref.read(libraryRepositoryProvider).markSongPlayed(activeTrackId);
    if (!mounted) {
      return;
    }
    final song =
        ref.read(librarySongOverridesProvider)[activeTrackId] ??
        ref
            .read(libraryContentDataProvider)
            .valueOrNull
            ?.songs
            .where((song) => song.id == activeTrackId)
            .firstOrNull;
    if (song != null) {
      final playedSong = song.copyWith(playCount: song.playCount + 1);
      patchLibrarySongOverride(ref, playedSong);
      ref
          .read(recentSongsProvider.notifier)
          .recordPlayed(
            playedSong,
            playedAt: DateTime.now().millisecondsSinceEpoch.toString(),
          );
    }
  }

  void _showAudioFileAccessNotification() {
    final i18n = context.smPlayerI18n;
    unawaited(
      showAppNotification(
        context: context,
        message: i18n.t('notification.playbackNoFileAccess'),
        duration: undoableNotificationDuration,
        actionLabel: i18n.t('notification.authorizeFileAccess'),
        onAction: () => _authorizeAudioFileAccess(i18n),
      ),
    );
  }

  Future<void> _authorizeAudioFileAccess(SmPlayerI18n i18n) async {
    final snapshot = ref.read(libraryContentDataProvider).valueOrNull;
    final rootPath =
        snapshot?.rootPath ?? _settingsController.snapshot.rootPath;
    final String? selectedRootPath;
    try {
      selectedRootPath = await pickDirectoryFromDesktopShell(
        title: i18n.t('local.chooseMusicLibraryFolderDialogTitle'),
        buttonLabel: i18n.t('notification.authorizeFileAccess'),
        defaultPath: rootPath.isEmpty ? null : rootPath,
        locale: i18n.locale,
      );
    } on PlatformException {
      if (mounted) {
        showAppNotification(
          context: context,
          message: i18n.t('library.folderPickerUnavailable'),
        );
      }
      return;
    }
    if (selectedRootPath == null || selectedRootPath.isEmpty) {
      return;
    }
    await ref
        .read(libraryRepositoryProvider)
        .scanAllMusicLibrary(selectedRootPath);
    await _settingsController.updateSettings(
      AppSettingsUpdate(rootPath: selectedRootPath),
    );
    ref
      ..invalidate(libraryContentDataProvider)
      ..invalidate(librarySongCountProvider)
      ..invalidate(recentPageDataProvider)
      ..invalidate(shellNavigationDataProvider)
      ..invalidate(recentSearchesProvider);
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

@visibleForTesting
Future<void> verifyAudioFileReadable(String path) async {
  final file = await File(path).open();
  await file.close();
}

@visibleForTesting
bool isAudioFilePermissionDenied(Object error) {
  if (error is FileSystemException) {
    final code = error.osError?.errorCode;
    return code == 1 || code == 13;
  }
  if (error is PlayerException) {
    final message = '${error.code} ${error.message}'.toLowerCase();
    return message.contains('operation not permitted') ||
        message.contains('permission denied') ||
        message.contains('not permitted');
  }
  return false;
}
