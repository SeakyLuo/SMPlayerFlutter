part of 'desktop_feature_service.dart';

extension _DesktopWindowStateService on TrayWindowDesktopFeatureService {
  Future<void> _handleWindowUnmaximize() async {
    await _ensureMainWindowVisible();
    await _saveMainWindowState(immediate: true);
  }

  Future<void> _saveMainWindowState({bool immediate = false}) async {
    if (_miniModeActive ||
        _windowMinimized ||
        await windowManager.isMinimized() ||
        await windowManager.isFullScreen()) {
      return;
    }
    final maximized = await windowManager.isMaximized();
    final bounds = await windowManager.getBounds();
    final snapshot = smPlayerGlobalSettingsSnapshot.copyWith(
      mainWindowBounds: serializeMainWindowBounds(bounds),
      mainWindowMaximized: maximized,
    );
    setSmPlayerGlobalSettingsSnapshot(snapshot);
    _mainWindowStateSaveDebounce?.cancel();
    if (immediate) {
      await _persistMainWindowState(snapshot);
      return;
    }
    _mainWindowStateSaveDebounce = Timer(
      TrayWindowDesktopFeatureService._mainWindowStateSaveDelay,
      () => unawaited(_persistMainWindowState(snapshot)),
    );
  }

  Future<void> _persistMainWindowState(SettingsSnapshot snapshot) {
    _mainWindowStateWriteQueue = _mainWindowStateWriteQueue
        .catchError((_) {})
        .then(
          (_) => _settingsRepository.saveMainWindowState(
            bounds: snapshot.mainWindowBounds,
            maximized: snapshot.mainWindowMaximized,
          ),
        );
    return _mainWindowStateWriteQueue;
  }

  Future<void> _enterMiniMode() async {
    if (!_miniModeActive) {
      _wasMaximizedBeforeMiniMode = await windowManager.isMaximized();
      if (_wasMaximizedBeforeMiniMode) {
        await windowManager.unmaximize();
      }
      _boundsBeforeMiniMode = await windowManager.getBounds();
    }
    if (await windowManager.isFullScreen()) {
      await windowManager.setFullScreen(false);
    }
    final bounds = await windowManager.getBounds();
    final workArea = await _workAreaForWindow(bounds);
    final miniBounds = miniModeWindowBoundsFor(bounds, workArea);
    _miniModeActive = true;
    await windowManager.setMinimumSize(_miniModeWindowSize);
    await windowManager.setBounds(miniBounds, animate: true);
    await windowManager.setResizable(true);
    await windowManager.setMaximizable(false);
    await windowManager.setAlwaysOnTop(true);
  }

  Future<void> _exitMiniMode() async {
    _miniModeActive = false;
    await windowManager.setAlwaysOnTop(false);
    await windowManager.setResizable(true);
    await windowManager.setMaximizable(true);
    await windowManager.setMinimumSize(_defaultWindowMinimumSize);
    final bounds = _boundsBeforeMiniMode;
    if (bounds != null) {
      final restoredBounds = clampMainWindowBounds(
        bounds,
        await _mainWindowWorkAreas(),
      );
      await windowManager.setBounds(restoredBounds, animate: true);
    }
    if (_wasMaximizedBeforeMiniMode) {
      await windowManager.maximize();
    }
    _boundsBeforeMiniMode = null;
    _wasMaximizedBeforeMiniMode = false;
  }

  Future<void> _setWindowFullScreen(bool fullScreen) async {
    if (fullScreen && _miniModeActive) {
      await _exitMiniMode();
    }
    await windowManager.setFullScreen(fullScreen);
    _emit(
      DesktopFeatureAction(
        DesktopFeatureCommand.windowFullScreenChanged,
        isWindowFullScreen: fullScreen,
      ),
    );
  }

  Future<Rect> _workAreaForWindow(Rect windowBounds) async {
    final displays = await screen.screenRetriever.getAllDisplays();
    if (displays.isEmpty) {
      final primary = await screen.screenRetriever.getPrimaryDisplay();
      return _workAreaForDisplay(primary);
    }
    var selected = displays.first;
    var selectedOverlap = -1.0;
    for (final display in displays) {
      final overlap = _rectOverlapArea(
        windowBounds,
        _workAreaForDisplay(display),
      );
      if (overlap > selectedOverlap) {
        selected = display;
        selectedOverlap = overlap;
      }
    }
    return _workAreaForDisplay(selected);
  }

  Future<List<Rect>> _mainWindowWorkAreas() async {
    final displays = await screen.screenRetriever.getAllDisplays();
    final primary = await screen.screenRetriever.getPrimaryDisplay();
    return [
      _workAreaForDisplay(primary),
      ...displays
          .where((display) => display.id != primary.id)
          .map(_workAreaForDisplay),
    ];
  }

  Future<void> _ensureMainWindowVisible() async {
    if (_windowMinimized ||
        await windowManager.isMinimized() ||
        await windowManager.isFullScreen() ||
        await windowManager.isMaximized()) {
      return;
    }
    if (Platform.isWindows) {
      await ensureMainWindowVisibleWithPlatformCoordinates();
      return;
    }
    final bounds = await windowManager.getBounds();
    final nextBounds = clampMainWindowBounds(
      bounds,
      await _mainWindowWorkAreas(),
      minimumSize:
          _miniModeActive ? _miniModeWindowSize : mainWindowMinimumSize,
    );
    if (nextBounds != bounds) {
      await windowManager.setBounds(nextBounds);
    }
  }

  Future<void> _ignorePlatformErrors<T>(Future<T> action) async {
    try {
      await action;
    } on Object {
      // Platform plugins are unavailable in widget tests and on unsupported
      // desktop shells. The feature service remains inert in that case.
    }
  }
}
