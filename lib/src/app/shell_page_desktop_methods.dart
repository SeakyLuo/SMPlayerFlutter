// ignore_for_file: invalid_use_of_protected_member

part of 'shell_page.dart';

extension _SmPlayerShellDesktopMethods on _SmPlayerShellPageState {
  void _syncDesktopFeatures({
    required SmPlayerI18n i18n,
    required LibraryContentData? snapshot,
    required List<LibrarySong> recentSongs,
    required MediaControlState mediaControlState,
    required LibrarySong? currentSong,
  }) {
    final settings = _settingsController.snapshot;
    final windowControlsLight = _isMiniMode || isAppNightMode(settings);
    if (_lastWindowControlsLight != windowControlsLight) {
      _lastWindowControlsLight = windowControlsLight;
      unawaited(
        _desktopFeatureService.setWindowControlsLight(windowControlsLight),
      );
    }

    final trayState = DesktopTrayState(
      appTitle: i18n.t('app.shell'),
      isPlaying: mediaControlState.isPlaying,
      isWindowVisible: _isWindowVisible,
      quitOnClose: settings.quitOnClose,
      labels: DesktopTrayLabels.fromI18n(i18n),
      recentSongs:
          recentSongs
              .take(desktopRecentSongLimit)
              .map(DesktopRecentSong.fromLibrarySong)
              .toList(),
    );
    if (_lastDesktopTraySignature != trayState.signature) {
      _lastDesktopTraySignature = trayState.signature;
      unawaited(_desktopFeatureService.updateTray(trayState));
    }

    final lyricsState = DesktopLyricsDisplayState.fromShell(
      settings: settings,
      currentSong: currentSong,
      lyrics: _desktopLyricsForSong(currentSong),
      lyricsLoading:
          currentSong != null && _desktopLyricsLoadingSongId == currentSong.id,
      isPlaying: mediaControlState.isPlaying,
      progressSeconds: mediaControlState.progressSeconds,
      durationSeconds: mediaControlState.durationSeconds,
      i18n: i18n,
    );
    _ensureDesktopLyricsLoaded(currentSong, mode: settings.playerLyricsSource);
    if (_lastDesktopLyricsSignature != lyricsState.signature) {
      _lastDesktopLyricsSignature = lyricsState.signature;
      unawaited(_desktopFeatureService.updateDesktopLyricsState(lyricsState));
    }

    final mediaSessionState = MediaSessionDisplayState.fromShell(
      currentSong: currentSong,
      i18n: i18n,
      isPlaying: mediaControlState.isPlaying,
      durationSeconds: mediaControlState.durationSeconds,
      progressSeconds: mediaControlState.progressSeconds,
    );
    if (_lastMediaSessionSignature != mediaSessionState.signature) {
      _lastMediaSessionSignature = mediaSessionState.signature;
      unawaited(_desktopFeatureService.updateMediaSession(mediaSessionState));
    }

    _notifyTrackChanged(
      currentSong,
      settings,
      i18n,
      mediaControlState.progressSeconds,
    );
  }

  LyricsSnapshot? _desktopLyricsForSong(LibrarySong? currentSong) {
    return currentSong != null && _desktopLyricsSongId == currentSong.id
        ? _desktopLyrics
        : null;
  }

  void _ensurePlayerArtworkResolved(LibrarySong? currentSong, WidgetRef ref) {
    if (currentSong == null) {
      return;
    }
    final artworkPath = currentSong.thumbnailPath;
    if (artworkPath.isNotEmpty && File(artworkPath).existsSync()) {
      return;
    }
    if (_playerArtworkResolveAttemptedSongIds.contains(currentSong.id) ||
        _playerArtworkResolvingSongIds.contains(currentSong.id)) {
      return;
    }

    _playerArtworkResolvingSongIds.add(currentSong.id);
    unawaited(
      ref
          .read(libraryRepositoryProvider)
          .getSongArtworkSnapshot(currentSong.id)
          .then((snapshot) {
            if (mounted && snapshot.artworkUrl.isNotEmpty) {
              ref.invalidate(libraryContentDataProvider);
            }
          })
          .whenComplete(() {
            _playerArtworkResolvingSongIds.remove(currentSong.id);
            _playerArtworkResolveAttemptedSongIds.add(currentSong.id);
          }),
    );
  }

  void _refreshPlayerArtworkAfterError(LibrarySong song, WidgetRef ref) {
    final key = '${song.id}:${song.thumbnailPath}';
    if (_playerArtworkErrorAttemptedKeys.contains(key) ||
        _playerArtworkErrorResolvingKeys.contains(key)) {
      return;
    }

    _playerArtworkErrorResolvingKeys.add(key);
    unawaited(
      ref
          .read(libraryRepositoryProvider)
          .getSongArtworkSnapshot(song.id)
          .then((snapshot) {
            if (mounted && snapshot.artworkUrl.isNotEmpty) {
              ref.invalidate(libraryContentDataProvider);
            }
          })
          .whenComplete(() {
            _playerArtworkErrorResolvingKeys.remove(key);
            _playerArtworkErrorAttemptedKeys.add(key);
          }),
    );
  }

  void _ensureDesktopLyricsLoaded(
    LibrarySong? currentSong, {
    required LyricsRequestMode mode,
  }) {
    if (currentSong == null) {
      _desktopLyricsSongId = null;
      _desktopLyricsLoadingSongId = null;
      _desktopLyricsMode = null;
      _desktopLyrics = null;
      return;
    }

    if ((_desktopLyricsSongId == currentSong.id &&
            _desktopLyricsMode == mode) ||
        (_desktopLyricsLoadingSongId == currentSong.id &&
            _desktopLyricsMode == mode)) {
      return;
    }

    final songId = currentSong.id;
    _desktopLyricsLoadingSongId = songId;
    _desktopLyricsMode = mode;
    unawaited(
      ref
          .read(libraryRepositoryProvider)
          .getSongLyrics(songId, mode: mode)
          .then((lyrics) {
            if (!mounted || _desktopLyricsLoadingSongId != songId) {
              return;
            }
            _desktopLyricsSongId = songId;
            _desktopLyricsLoadingSongId = null;
            _desktopLyrics = lyrics;
            _lastDesktopLyricsSignature = null;
            setState(() {});
          }),
    );
  }

  void _notifyTrackChanged(
    LibrarySong? currentSong,
    SettingsSnapshot settings,
    SmPlayerI18n i18n,
    double progressSeconds,
  ) {
    if (currentSong == null) {
      return;
    }

    if (_lastNotifiedSongId == null) {
      _lastNotifiedSongId = currentSong.id;
      return;
    }

    if (_lastNotifiedSongId == currentSong.id) {
      return;
    }

    _lastNotifiedSongId = currentSong.id;
    if (!settings.showNotifications ||
        settings.notificationSend != NotificationSendMode.musicChanged) {
      return;
    }

    unawaited(
      _showTrackChangedNotification(
        currentSong: currentSong,
        settings: settings,
        i18n: i18n,
        progressSeconds: progressSeconds,
      ),
    );
  }

  Future<void> _showTrackChangedNotification({
    required LibrarySong currentSong,
    required SettingsSnapshot settings,
    required SmPlayerI18n i18n,
    required double progressSeconds,
  }) async {
    var lyricsPreview = '';
    if (settings.showLyricsInNotification) {
      final cachedLyrics =
          settings.notificationLyricsSource == settings.playerLyricsSource
              ? _desktopLyricsForSong(currentSong)
              : null;
      final lyrics =
          cachedLyrics ??
          await ref
              .read(libraryRepositoryProvider)
              .getSongLyrics(
                currentSong.id,
                mode: settings.notificationLyricsSource,
              );
      if (!mounted || _lastNotifiedSongId != currentSong.id) {
        return;
      }
      lyricsPreview = desktopNotificationLyricsPreview(
        lyrics: lyrics,
        song: currentSong,
        progressSeconds: progressSeconds,
      );
    }

    unawaited(
      _desktopFeatureService.showTrackNotification(
        TrackNotificationPayload(
          songId: currentSong.id,
          title: currentSong.title,
          artist: desktopNotificationArtist(currentSong, i18n),
          album: desktopNotificationAlbum(currentSong, i18n),
          lyricsPreview: lyricsPreview,
        ),
      ),
    );
  }

  void _handleDesktopFeatureAction(DesktopFeatureAction action) {
    if (!mounted) {
      return;
    }

    switch (action.command) {
      case DesktopFeatureCommand.toggleWindowVisibility:
        unawaited(_toggleDesktopWindowVisibility());
      case DesktopFeatureCommand.showWindow:
        unawaited(_desktopFeatureService.showWindow());
      case DesktopFeatureCommand.windowVisibilityChanged:
        _setDesktopWindowVisible(action.isWindowVisible ?? true);
      case DesktopFeatureCommand.windowFullScreenChanged:
        _setDesktopWindowFullScreen(action.isWindowFullScreen ?? false);
      case DesktopFeatureCommand.windowMaximizedChanged:
        _setDesktopWindowMaximized(action.isWindowMaximized ?? false);
      case DesktopFeatureCommand.playPause:
        _togglePlayPauseFromCurrentQueue();
      case DesktopFeatureCommand.previous:
        _playPreviousFromCurrentQueue();
      case DesktopFeatureCommand.next:
        _playNextFromCurrentQueue();
      case DesktopFeatureCommand.stop:
        _mediaControlController.onStop();
      case DesktopFeatureCommand.quickPlay:
        _quickPlayLibrary(ref);
      case DesktopFeatureCommand.toggleDesktopLyrics:
        _toggleDesktopLyricsFromPlatform();
      case DesktopFeatureCommand.disableDesktopLyrics:
        _disableDesktopLyrics();
      case DesktopFeatureCommand.toggleDesktopLyricsLock:
        _toggleDesktopLyricsLock();
      case DesktopFeatureCommand.desktopLyricsOffsetBackward:
        _updateCurrentDesktopLyricsOffset(-100);
      case DesktopFeatureCommand.desktopLyricsOffsetForward:
        _updateCurrentDesktopLyricsOffset(100);
      case DesktopFeatureCommand.resetDesktopLyricsOffset:
        _resetCurrentDesktopLyricsOffset();
      case DesktopFeatureCommand.openSettings:
        _navigateTo('/settings#desktop-lyrics');
      case DesktopFeatureCommand.quit:
        unawaited(_desktopFeatureService.quit());
      case DesktopFeatureCommand.playRecentSong:
        _playRecentSongFromPlatform(action.songId!);
      case DesktopFeatureCommand.openExternalAudioFiles:
        unawaited(_openExternalAudioFiles(action.filePaths));
      case DesktopFeatureCommand.desktopLyricsBoundsChanged:
        unawaited(
          _settingsController.updateSettings(
            AppSettingsUpdate(desktopLyricsBounds: action.desktopLyricsBounds),
          ),
        );
      case DesktopFeatureCommand.mediaSessionSeekTo:
        _mediaControlController.onSeek(action.seekSeconds!);
      case DesktopFeatureCommand.voiceCommand:
        _executeExternalVoiceCommand(action.voiceCommandText!);
    }
  }

  Future<void> _toggleDesktopWindowVisibility() async {
    await _desktopFeatureService.toggleWindowVisibility();
    final visible = await _desktopFeatureService.getWindowVisible();
    if (!mounted) {
      return;
    }
    _setDesktopWindowVisible(visible);
  }

  void _setDesktopWindowVisible(bool visible) {
    if (_isWindowVisible == visible) {
      return;
    }
    setState(() {
      _isWindowVisible = visible;
      _lastDesktopTraySignature = null;
    });
  }

  void _setDesktopWindowFullScreen(bool fullScreen) {
    final currentPath = widget.currentPath ?? _currentPath;
    final currentLocation = widget.currentLocation ?? currentPath;
    final nextPath =
        !fullScreen && currentPath == '/now-playing/full'
            ? nowPlayingFullReturnLocationFromLocation(currentLocation)
            : currentPath;
    if (_isWindowFullScreen == fullScreen && nextPath == currentPath) {
      return;
    }
    setState(() {
      _isWindowFullScreen = fullScreen;
      if (nextPath != currentPath) {
        _currentPath = nextPath;
      }
    });
    if (nextPath != currentPath) {
      widget.onNavigate?.call(nextPath);
    }
  }

  void _setDesktopWindowMaximized(bool maximized) {
    if (_isWindowMaximized == maximized) {
      return;
    }
    setState(() {
      _isWindowMaximized = maximized;
    });
  }

  void _handleInitialExternalInputs() {
    for (final command in widget.initialExternalCommands) {
      _handleExternalAppCommand(command);
    }
    if (widget.initialExternalFilePaths.isNotEmpty) {
      unawaited(_openExternalAudioFiles(widget.initialExternalFilePaths));
    }
  }

  void _handleExternalAppCommand(ExternalAppCommand command) {
    switch (command.kind) {
      case ExternalAppCommandKind.playPause:
        _togglePlayPauseFromCurrentQueue();
      case ExternalAppCommandKind.next:
        _playNextFromCurrentQueue();
      case ExternalAppCommandKind.previous:
        _playPreviousFromCurrentQueue();
      case ExternalAppCommandKind.stop:
        _mediaControlController.onStop();
      case ExternalAppCommandKind.quickPlay:
        _quickPlayLibrary(ref);
      case ExternalAppCommandKind.showWindow:
        unawaited(_desktopFeatureService.showWindow());
      case ExternalAppCommandKind.toggleDesktopLyrics:
        _toggleDesktopLyricsFromPlatform();
      case ExternalAppCommandKind.voiceCommand:
        _executeExternalVoiceCommand(command.text);
    }
  }

  void _executeExternalVoiceCommand(String command) {
    final snapshot = ref.read(libraryContentDataProvider).valueOrNull;
    final i18n =
        ref.read(smPlayerI18nProvider).valueOrNull ??
        const SmPlayerI18n(locale: smPlayerFallbackLocale, messages: {});
    _executeVoiceAssistantCommand(command, snapshot, i18n);
  }

  Future<void> _openExternalAudioFiles(List<String> filePaths) async {
    final repository = ref.read(libraryRepositoryProvider);
    final openedSongIds = await repository.importExternalAudioFiles(filePaths);
    if (!mounted || openedSongIds.isEmpty) {
      return;
    }

    final snapshot = await repository.getLibraryContentData();
    final openedSongIdSet = openedSongIds.toSet();
    final queueWithoutOpened =
        snapshot.nowPlaying.songIds
            .where((songId) => !openedSongIdSet.contains(songId))
            .toList();
    final currentQueueIndex = _mediaControlController.state.selectedQueueIndex;
    final insertIndex =
        min(max(currentQueueIndex ?? -1, -1), queueWithoutOpened.length - 1) +
        1;
    final nextQueue = [
      ...queueWithoutOpened.take(insertIndex),
      ...openedSongIds,
      ...queueWithoutOpened.skip(insertIndex),
    ];
    await repository.replaceNowPlaying(nextQueue);
    if (!mounted) {
      return;
    }

    ref.invalidate(libraryContentDataProvider);
    _settingsController.savePlaybackSettingsImmediate(
      PlaybackSettingsUpdate(lastMusicIndex: insertIndex, musicProgress: 0),
    );

    final songsById = {for (final song in snapshot.songs) song.id: song};
    final song = songsById[openedSongIds.first]!;
    _mediaControlController.playTrack(
      mediaControlTrackForSong(song, context.smPlayerI18n),
      durationSeconds: song.duration.toDouble(),
      queueIndex: insertIndex,
    );
    _navigateTo('/now-playing');
    await _desktopFeatureService.showWindow();
  }

  void _toggleDesktopLyricsFromPlatform() {
    final nextEnabled = !_settingsController.snapshot.desktopLyricsEnabled;
    unawaited(
      _settingsController
          .updateSettings(AppSettingsUpdate(desktopLyricsEnabled: nextEnabled))
          .then((_) {
            if (mounted) {
              setState(() {});
            }
          }),
    );
  }

  void _playRecentSongFromPlatform(int songId) {
    final snapshot = ref.read(libraryContentDataProvider).valueOrNull;
    final songsById = {
      for (final song in snapshot?.songs ?? const <LibrarySong>[])
        song.id: song,
    };
    final song = songsById[songId];
    if (song == null) {
      return;
    }

    ref.read(libraryRepositoryProvider).replaceNowPlaying([song.id]);
    ref.invalidate(libraryContentDataProvider);
    _mediaControlController.playTrack(
      mediaControlTrackForSong(song, context.smPlayerI18n),
      durationSeconds: song.duration.toDouble(),
      queueIndex: 0,
    );
  }

  void _toggleDesktopLyricsLock() {
    final nextLocked = !_settingsController.snapshot.desktopLyricsLocked;
    unawaited(
      _settingsController
          .updateSettings(AppSettingsUpdate(desktopLyricsLocked: nextLocked))
          .then((_) {
            if (mounted) {
              setState(() {});
            }
          }),
    );
  }

  void _disableDesktopLyrics() {
    unawaited(
      _settingsController
          .updateSettings(const AppSettingsUpdate(desktopLyricsEnabled: false))
          .then((_) {
            if (mounted) {
              setState(() {});
            }
          }),
    );
  }

  void _updateCurrentDesktopLyricsOffset(int deltaMs) {
    final song = _currentDesktopLyricsSong();
    if (song == null) {
      return;
    }
    _updateDesktopLyricsOffset(song, song.lyricsOffsetMs + deltaMs);
  }

  void _resetCurrentDesktopLyricsOffset() {
    final song = _currentDesktopLyricsSong();
    if (song == null) {
      return;
    }
    _updateDesktopLyricsOffset(song, 0);
  }

  LibrarySong? _currentDesktopLyricsSong() {
    final snapshot = ref.read(libraryContentDataProvider).valueOrNull;
    return _resolvePlayerSong(_mediaControlController.state, snapshot);
  }

  void _updateDesktopLyricsOffset(LibrarySong song, int offsetMs) {
    unawaited(
      ref
          .read(libraryRepositoryProvider)
          .updateLyricsOffset(song.id, clampedDesktopLyricsOffset(offsetMs))
          .then((_) {
            ref.invalidate(libraryContentDataProvider);
            _lastDesktopLyricsSignature = null;
            if (mounted) {
              setState(() {});
            }
          }),
    );
  }

  void _saveNavigationCollapsed(bool collapsed) {
    _globalNavigationCollapsed = collapsed;
  }

  void _commitSearch(
    String value, [
    SearchHistoryType type = SearchHistoryType.sidebar,
  ]) {
    _commitSearchWithRepository(value, type);
  }

  void _commitSearchWithRepository(
    String value,
    SearchHistoryType type, {
    LibraryRepository? repository,
    VoidCallback? onRecentSearchRecorded,
  }) {
    final nextSearchText = value.trim();
    setState(() {
      _searchText = nextSearchText;
      if (nextSearchText.isNotEmpty) {
        _currentPath = '/search';
      }
    });
    if (nextSearchText.isNotEmpty) {
      final LibraryRepository searchRepository =
          repository ??
          widget.settingsRepository ??
          ref.read(libraryRepositoryProvider);
      unawaited(
        searchRepository.addRecentSearch(nextSearchText, type).then((entry) {
          if (onRecentSearchRecorded != null) {
            onRecentSearchRecorded();
          } else {
            _invalidateRecentSearchData();
          }
        }),
      );
      _closeNavigationOverlay(preserveSearchText: true);
      widget.onSearchCommit?.call(nextSearchText, type);
    }
  }

  void _clearSearch() {
    setState(() {
      _searchText = '';
    });
  }

  void _invalidateRecentSearchData() {
    invalidateRecentSearchData(ref);
  }

  Future<void> _showVoiceAssistantDialog(
    LibraryContentData? snapshot,
    SmPlayerI18n i18n,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return VoiceAssistantDialog(
          i18n: i18n,
          getHint: () => _getVoiceAssistantHint(snapshot, i18n),
          onExecute: (command) {
            return _executeVoiceAssistantCommand(command, snapshot, i18n);
          },
        );
      },
    );
  }
}
