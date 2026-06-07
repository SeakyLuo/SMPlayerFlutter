// ignore_for_file: invalid_use_of_protected_member

part of 'shell_page.dart';

extension _SmPlayerShellNavigationMethods on _SmPlayerShellPageState {
  void _navigateTo(String target) {
    final restoredTarget = _routeMemory[target] ?? target;
    final currentPath = widget.currentPath ?? _currentPath;
    final targetPath = _pathFromLocation(restoredTarget);
    if (targetPath == '/now-playing/full') {
      unawaited(
        _settingsController.saveDisplayModeState(
          lastDisplayMode: SmPlayerDisplayMode.immersive,
        ),
      );
    } else if (currentPath == '/now-playing/full') {
      unawaited(
        _settingsController.saveDisplayModeState(
          lastDisplayMode: SmPlayerDisplayMode.normal,
        ),
      );
    }
    setState(() {
      _currentPath = restoredTarget;
      if (targetPath == '/now-playing/full') {
        _isWindowFullScreen = false;
      }
    });
    _closeNavigationOverlay();
    widget.onNavigate?.call(restoredTarget);
    unawaited(_desktopFeatureService.setWindowFullScreen(false));
  }

  void _rememberRoute(String path) {
    final uri = Uri.tryParse(path);
    final normalizedPath = uri?.path ?? path;
    final section = _routeSection(normalizedPath);
    if (section == null) {
      return;
    }
    _routeMemory[section] = path;
  }

  void _recordNavigationLocation(String location) {
    if (_navigationHistory.isEmpty) {
      _navigationHistory.add(location);
      return;
    }

    if (_navigationHistory.last == location) {
      return;
    }

    if (_navigationHistory.length > 1 &&
        _navigationHistory[_navigationHistory.length - 2] == location) {
      _navigationHistory.removeLast();
      return;
    }

    _navigationHistory.add(location);
  }

  String _pathFromLocation(String location) {
    return Uri.parse(location).path;
  }

  String? _routeSection(String path) {
    if (path.startsWith('/artists')) {
      return '/artists';
    }
    if (path.startsWith('/local')) {
      return '/local';
    }
    if (path.startsWith('/playlists')) {
      return '/playlists';
    }
    if (path.startsWith('/albums')) {
      return '/albums';
    }
    return restorableRoutes.contains(path) ? path : null;
  }

  void _toggleDesktopWindowFullScreen() {
    final nextFullScreen = !_isWindowFullScreen;
    _setDesktopWindowFullScreen(nextFullScreen);
    unawaited(_desktopFeatureService.setWindowFullScreen(nextFullScreen));
  }

  void _enterMiniMode() {
    final currentPath = widget.currentPath ?? _currentPath;
    final currentLocation = widget.currentLocation ?? currentPath;
    final exitTarget =
        currentPath == '/now-playing/full'
            ? nowPlayingFullReturnLocationFromLocation(currentLocation)
            : nowPlayingRoutePath;
    setState(() {
      _isMiniMode = true;
      if (currentPath == '/now-playing/full') {
        _currentPath = exitTarget;
      }
    });
    if (currentPath == '/now-playing/full') {
      widget.onNavigate?.call(exitTarget);
      unawaited(_desktopFeatureService.setWindowFullScreen(false));
    }
    unawaited(
      _settingsController.saveDisplayModeState(
        lastDisplayMode: SmPlayerDisplayMode.mini,
      ),
    );
    unawaited(_desktopFeatureService.enterMiniMode());
  }

  void _exitMiniMode() {
    setState(() {
      _isMiniMode = false;
    });
    unawaited(
      _settingsController.saveDisplayModeState(
        lastDisplayMode: SmPlayerDisplayMode.normal,
      ),
    );
    unawaited(_desktopFeatureService.exitMiniMode());
  }

  void _startWindowDrag() {
    unawaited(_desktopFeatureService.startWindowDrag());
  }

  void _stopWindowDrag() {
    unawaited(_desktopFeatureService.stopWindowDrag());
  }

  void _minimizeDesktopWindow() {
    unawaited(_desktopFeatureService.minimizeWindow());
  }

  void _toggleDesktopWindowMaximized() {
    unawaited(_desktopFeatureService.toggleWindowMaximized());
  }

  void _closeDesktopWindow() {
    unawaited(_desktopFeatureService.closeWindow());
  }

  void _goBack() {
    if (closeTopPopupDialog()) {
      return;
    }
    _closeNavigationOverlay();
    if (_navigationHistory.length > 1) {
      final targetLocation = _navigationHistory[_navigationHistory.length - 2];
      setState(() {
        _currentPath = _pathFromLocation(targetLocation);
      });
      widget.onNavigate?.call(targetLocation);
      return;
    }

    widget.onGoBack?.call();
  }

  void _syncNavigationMode(double width) {
    final nextNavigationMode = SmPlayerShellMetrics.navigationModeForWidth(
      width,
    );
    final currentNavigationMode = _navigationMode;
    if (currentNavigationMode == null) {
      _navigationMode = nextNavigationMode;
      if (nextNavigationMode != SmPlayerNavigationMode.wide) {
        _isMinimalNavigationOpen = false;
        _isNavigationPaneOpen = false;
        _saveNavigationCollapsed(true);
      }
      return;
    }

    if (currentNavigationMode == nextNavigationMode) {
      if (nextNavigationMode != SmPlayerNavigationMode.minimal &&
          _isMinimalNavigationOpen) {
        _isMinimalNavigationOpen = false;
      }
      return;
    }

    _navigationMode = nextNavigationMode;
    _isMinimalNavigationOpen = false;
    _isNavigationPaneOpen = nextNavigationMode == SmPlayerNavigationMode.wide;
    _saveNavigationCollapsed(nextNavigationMode != SmPlayerNavigationMode.wide);
  }

  void _toggleNavigationPane() {
    final navigationMode =
        _navigationMode ??
        SmPlayerShellMetrics.navigationModeForWidth(
          MediaQuery.sizeOf(context).width,
        );

    if (navigationMode == SmPlayerNavigationMode.minimal) {
      setState(() {
        _isMinimalNavigationOpen = !_isMinimalNavigationOpen;
        if (!_isMinimalNavigationOpen) {
          _searchText = '';
        }
      });
      return;
    }

    final nextIsPaneOpen = !_isNavigationPaneOpen;
    setState(() {
      _isNavigationPaneOpen = nextIsPaneOpen;
      if (!nextIsPaneOpen) {
        _searchText = '';
      }
    });
    _saveNavigationCollapsed(!nextIsPaneOpen);
  }

  void _closeNavigationOverlay({bool preserveSearchText = false}) {
    final navigationMode = _navigationMode;
    if (navigationMode == SmPlayerNavigationMode.minimal &&
        _isMinimalNavigationOpen) {
      setState(() {
        _isMinimalNavigationOpen = false;
        if (!preserveSearchText) {
          _searchText = '';
        }
      });
      return;
    }

    if (navigationMode == SmPlayerNavigationMode.overlay &&
        _isNavigationPaneOpen) {
      setState(() {
        _isNavigationPaneOpen = false;
        if (!preserveSearchText) {
          _searchText = '';
        }
      });
      _saveNavigationCollapsed(true);
    }
  }

  void _dismissNavigationSearchHistory() {
    if (!_isNavigationSearchHistoryOpen) {
      return;
    }
    setState(() {
      _isNavigationSearchHistoryOpen = false;
      _navigationSearchDismissEpoch += 1;
    });
  }

  Future<void> _restoreNavigationPaneState() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isNavigationPaneOpen = !_globalNavigationCollapsed;
    });
  }

  void _persistCurrentPage(String path) {
    if (!restorableRoutes.contains(path) || _lastPersistedPage == path) {
      return;
    }
    _lastPersistedPage = path;
    unawaited(_saveLastPage(path));
  }

  Future<void> _saveLastPage(String path) async {
    await _settingsController.saveViewState(lastPage: path);
  }

  Future<void> _restorePlaybackRuntimeSettings() async {
    await _settingsController.refresh();
    if (!mounted) {
      return;
    }

    _mediaControlController.applyPlaybackRuntimeSettings(
      _settingsController.getPlaybackSettingsImmediate(),
    );
    _playbackRuntimeSettingsRestored = true;
    _scheduleRestorePlaybackTrack(
      ref.read(libraryContentDataProvider).valueOrNull,
    );
    unawaited(_checkReleaseNotesVersion());
  }

  void _scheduleRestorePlaybackTrack(LibraryContentData? snapshot) {
    if (_playbackTrackRestored ||
        _playbackTrackRestoreScheduled ||
        !_playbackRuntimeSettingsRestored ||
        snapshot == null) {
      return;
    }
    _playbackTrackRestoreScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _playbackTrackRestoreScheduled = false;
      if (!mounted || _playbackTrackRestored) {
        return;
      }
      final latestSnapshot = ref.read(libraryContentDataProvider).valueOrNull;
      if (latestSnapshot == null) {
        return;
      }
      _restorePlaybackTrackFromSnapshot(latestSnapshot);
    });
  }

  void _restorePlaybackTrackFromSnapshot(LibraryContentData snapshot) {
    if (_playbackTrackRestored) {
      return;
    }
    if (_mediaControlController.state.track.id != null) {
      _playbackTrackRestored = true;
      return;
    }
    _playbackTrackRestored = true;
    final songIds = _playbackSongIds(snapshot);
    if (snapshot.songs.isEmpty || songIds.isEmpty) {
      return;
    }

    final settings = _settingsController.snapshot;
    final restoredIndex = settings.lastMusicIndex.clamp(0, songIds.length - 1);
    final songsById = {for (final song in snapshot.songs) song.id: song};
    final restoredSong = songsById[songIds[restoredIndex]];
    if (restoredSong == null) {
      return;
    }
    final progressSeconds =
        settings.saveMusicProgress ? settings.musicProgress : 0.0;
    _mediaControlController.playTrack(
      mediaControlTrackForSong(restoredSong, context.smPlayerI18n),
      durationSeconds: restoredSong.duration.toDouble(),
      queueIndex: restoredIndex,
      progressSeconds: progressSeconds,
      autoplay: settings.autoPlay,
    );
  }

  Future<void> _restoreDesktopWindowFullScreenState() async {
    final fullScreen = await _desktopFeatureService.getWindowFullScreen();
    if (!mounted) {
      return;
    }
    _setDesktopWindowFullScreen(fullScreen);
  }

  Future<void> _restoreDesktopWindowMaximizedState() async {
    final maximized = await _desktopFeatureService.getWindowMaximized();
    if (!mounted) {
      return;
    }
    _setDesktopWindowMaximized(maximized);
  }

  Future<void> _checkReleaseNotesVersion() async {
    if (_releaseNotesChecked) {
      return;
    }
    _releaseNotesChecked = true;
    final lastVersion = _settingsController.snapshot.lastReleaseNotesVersion;
    if (lastVersion.isEmpty) {
      unawaited(_checkStartupArtistSplits());
      return;
    }

    final currentVersion = await _currentAppVersion();
    if (!mounted) {
      return;
    }
    if (compareAppVersions(currentVersion, lastVersion) > 0) {
      setState(() {
        _releaseNotesDialogVersion = currentVersion;
      });
      return;
    }
    unawaited(_checkStartupArtistSplits());
  }

  Future<String> _currentAppVersion() async {
    final providedVersion = widget.appVersion;
    if (providedVersion != null) {
      return providedVersion;
    }

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return packageInfo.version;
    } catch (_) {
      return '';
    }
  }

  Future<void> _closeReleaseNotes(String version) async {
    await _settingsController.updateSettings(
      AppSettingsUpdate(lastReleaseNotesVersion: version),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _releaseNotesDialogVersion = null;
    });
    unawaited(_checkStartupArtistSplits());
  }

  Future<void> _checkStartupArtistSplits() async {
    if (_startupArtistSplitChecked ||
        _releaseNotesDialogVersion != null ||
        !_settingsController.snapshot.smartMultiArtistRecognition) {
      return;
    }
    _startupArtistSplitChecked = true;
    final repository = ref.read(libraryRepositoryProvider);
    final shouldCheck = await repository.shouldCheckStartupArtistSplits();
    if (!shouldCheck) {
      return;
    }
    final result = await repository.analyzeArtistSplits();
    if (!mounted || !result.hasSuggestions) {
      return;
    }
    setState(() {
      _startupArtistSplitResult = result;
    });
  }

  Future<void> _applyStartupArtistSplits(
    List<ArtistSplitResultItem> splits,
  ) async {
    setState(() {
      _startupArtistSplitApplying = true;
    });
    try {
      await ref.read(libraryRepositoryProvider).applyArtistSplits(splits);
      ref.invalidate(libraryContentDataProvider);
      if (!mounted) {
        return;
      }
      setState(() {
        _startupArtistSplitResult = null;
      });
    } finally {
      if (mounted) {
        setState(() {
          _startupArtistSplitApplying = false;
        });
      }
    }
  }

  void _dismissStartupArtistSplitReview() {
    setState(() {
      _startupArtistSplitResult = null;
    });
  }
}
