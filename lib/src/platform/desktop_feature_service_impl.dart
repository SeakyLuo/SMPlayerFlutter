part of 'desktop_feature_service.dart';

abstract class DesktopFeatureService {
  Future<void> initialize(ValueChanged<DesktopFeatureAction> onAction);

  Future<List<String>> getSystemFonts();

  Future<void> updateTray(DesktopTrayState state);

  Future<void> showTrackNotification(TrackNotificationPayload payload);

  Future<void> updateMediaSession(MediaSessionDisplayState state);

  Future<void> updateDesktopLyricsState(DesktopLyricsDisplayState state);

  Future<void> enterMiniMode();

  Future<void> exitMiniMode();

  Future<void> startWindowDrag();

  Future<void> stopWindowDrag();

  Future<void> setWindowFullScreen(bool fullScreen);

  Future<void> setWindowControlsLight(bool light);

  Future<bool> getWindowFullScreen();

  Future<bool> getWindowMaximized();

  Future<bool> getWindowVisible();

  Future<void> showWindow();

  Future<void> toggleWindowVisibility();

  Future<void> minimizeWindow();

  Future<void> toggleWindowMaximized();

  Future<void> closeWindow();

  Future<void> quit();

  void dispose();
}

DesktopFeatureService createDesktopFeatureService({
  LibraryRepository? settingsRepository,
}) {
  if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
    return TrayWindowDesktopFeatureService(
      settingsRepository: settingsRepository ?? const LibraryRepository(),
    );
  }
  if (!kIsWeb && Platform.isAndroid) {
    return MobileExternalOpenFeatureService();
  }
  return const NoopDesktopFeatureService();
}

class NoopDesktopFeatureService implements DesktopFeatureService {
  const NoopDesktopFeatureService();

  @override
  Future<void> initialize(ValueChanged<DesktopFeatureAction> onAction) async {}

  @override
  Future<List<String>> getSystemFonts() async {
    return const [];
  }

  @override
  Future<void> updateTray(DesktopTrayState state) async {}

  @override
  Future<void> showTrackNotification(TrackNotificationPayload payload) async {}

  @override
  Future<void> updateMediaSession(MediaSessionDisplayState state) async {}

  @override
  Future<void> updateDesktopLyricsState(
    DesktopLyricsDisplayState state,
  ) async {}

  @override
  Future<void> enterMiniMode() async {}

  @override
  Future<void> exitMiniMode() async {}

  @override
  Future<void> startWindowDrag() async {}

  @override
  Future<void> stopWindowDrag() async {}

  @override
  Future<void> setWindowFullScreen(bool fullScreen) async {}

  @override
  Future<void> setWindowControlsLight(bool light) async {}

  @override
  Future<bool> getWindowFullScreen() async {
    return false;
  }

  @override
  Future<bool> getWindowMaximized() async {
    return false;
  }

  @override
  Future<bool> getWindowVisible() async {
    return true;
  }

  @override
  Future<void> showWindow() async {}

  @override
  Future<void> toggleWindowVisibility() async {}

  @override
  Future<void> minimizeWindow() async {}

  @override
  Future<void> toggleWindowMaximized() async {}

  @override
  Future<void> closeWindow() async {}

  @override
  Future<void> quit() async {}

  @override
  void dispose() {}
}

class MobileExternalOpenFeatureService extends NoopDesktopFeatureService {
  MobileExternalOpenFeatureService();

  ValueChanged<DesktopFeatureAction>? _onAction;

  @override
  Future<void> initialize(ValueChanged<DesktopFeatureAction> onAction) async {
    _onAction = onAction;
    _desktopFeatureChannel.setMethodCallHandler(_handlePlatformMethodCall);
    final arguments = await _desktopFeatureChannel.invokeMethod<List<dynamic>>(
      'takeInitialExternalArguments',
    );
    if (arguments == null || arguments.isEmpty) {
      return;
    }
    _handleExternalArguments(arguments.whereType<String>().toList());
  }

  Future<void> _handlePlatformMethodCall(MethodCall call) async {
    if (call.method != 'openExternalArguments') {
      return;
    }
    _handleExternalArguments(
      (call.arguments as List).whereType<String>().toList(growable: false),
    );
  }

  void _handleExternalArguments(List<String> arguments) {
    _emitOpenExternalAudioFiles(externalAudioPathsFromArgs(arguments));
    for (final command in externalAppCommandsFromArgs(arguments)) {
      _emit(_desktopFeatureActionFromExternal(command));
    }
  }

  void _emitOpenExternalAudioFiles(List<String> paths) {
    if (paths.isEmpty) {
      return;
    }
    _emit(
      DesktopFeatureAction(
        DesktopFeatureCommand.openExternalAudioFiles,
        filePaths: paths,
      ),
    );
  }

  void _emit(DesktopFeatureAction action) {
    _onAction?.call(action);
  }

  @override
  void dispose() {
    _desktopFeatureChannel.setMethodCallHandler(null);
  }
}

class TrayWindowDesktopFeatureService
    with tray.TrayListener, WindowListener
    implements DesktopFeatureService {
  TrayWindowDesktopFeatureService({LibraryRepository? settingsRepository})
    : _settingsRepository = settingsRepository ?? const LibraryRepository();

  static const _mainWindowStateSaveDelay = Duration(milliseconds: 350);

  final LibraryRepository _settingsRepository;
  ValueChanged<DesktopFeatureAction>? _onAction;
  DesktopTrayState? _lastTrayState;
  List<String>? _cachedSystemFonts;
  Rect? _boundsBeforeMiniMode;
  Timer? _mainWindowStateSaveDebounce;
  Future<void> _mainWindowStateWriteQueue = Future.value();
  var _wasMaximizedBeforeMiniMode = false;
  var _initialized = false;
  var _quitting = false;
  var _shownTrayHint = false;
  var _miniModeActive = false;
  bool? _windowControlsLight;

  @override
  Future<void> initialize(ValueChanged<DesktopFeatureAction> onAction) async {
    _onAction = onAction;
    if (_initialized) {
      return;
    }
    _initialized = true;
    WidgetsFlutterBinding.ensureInitialized();
    await _ignorePlatformErrors(windowManager.ensureInitialized());
    await _ignorePlatformErrors(windowManager.setPreventClose(true));
    windowManager.addListener(this);
    tray.trayManager.addListener(this);
    await _ignorePlatformErrors(
      tray.trayManager.setIcon('assets/branding/monotone_no_bg.png'),
    );
    _desktopFeatureChannel.setMethodCallHandler(_handlePlatformMethodCall);
    await _takeInitialExternalArguments();
  }

  Future<void> _takeInitialExternalArguments() async {
    try {
      final arguments = await _desktopFeatureChannel
          .invokeMethod<List<dynamic>>('takeInitialExternalArguments');
      if (arguments == null || arguments.isEmpty) {
        return;
      }
      _handleExternalArguments(arguments.whereType<String>().toList());
    } on Object {
      // Native argument handoff is only implemented where the platform shell
      // supports live file/protocol open events.
    }
  }

  @override
  Future<List<String>> getSystemFonts() async {
    final cached = _cachedSystemFonts;
    if (cached != null) {
      return cached;
    }
    final fonts = await loadDesktopSystemFonts();
    _cachedSystemFonts = fonts;
    return fonts;
  }

  @override
  Future<void> updateTray(DesktopTrayState state) async {
    _lastTrayState = state;
    final entries = buildDesktopTrayMenuEntries(state);
    final menu = tray.Menu(items: entries.map(_toTrayMenuItem).toList());
    await _ignorePlatformErrors(tray.trayManager.setToolTip(state.appTitle));
    await _ignorePlatformErrors(tray.trayManager.setContextMenu(menu));
    if (Platform.isWindows) {
      await _ignorePlatformErrors(
        _desktopFeatureChannel.invokeMethod<void>('setRecentDocuments', {
          'label': state.labels.recent,
          'paths':
              state.recentSongs
                  .take(desktopRecentSongLimit)
                  .map((song) => song.path)
                  .toList(),
        }),
      );
    }
  }

  @override
  Future<void> showTrackNotification(TrackNotificationPayload payload) async {
    final body = desktopNotificationBody(payload);
    if (Platform.isMacOS) {
      await _ignorePlatformErrors(
        _desktopFeatureChannel.invokeMethod<void>('showTrackNotification', {
          'title': payload.title,
          'body': body,
          'songId': payload.songId,
          'silent': payload.silent,
        }),
      );
      return;
    }

    if (Platform.isWindows) {
      await _ignorePlatformErrors(
        Process.run('powershell', [
          '-NoProfile',
          '-ExecutionPolicy',
          'Bypass',
          '-Command',
          windowsToastPowerShellCommand(payload, body),
        ]),
      );
      return;
    }

    if (Platform.isLinux) {
      await _ignorePlatformErrors(
        _desktopFeatureChannel.invokeMethod<void>('showTrackNotification', {
          'title': payload.title,
          'body': body,
          'songId': payload.songId,
          'silent': payload.silent,
        }),
      );
    }
  }

  @override
  Future<void> updateMediaSession(MediaSessionDisplayState state) async {
    await _ignorePlatformErrors(
      _desktopFeatureChannel.invokeMethod<void>(
        'updateMediaSession',
        state.toPlatformMap(),
      ),
    );
  }

  @override
  Future<void> updateDesktopLyricsState(DesktopLyricsDisplayState state) async {
    await _ignorePlatformErrors(
      _desktopFeatureChannel.invokeMethod<void>(
        'updateDesktopLyricsWindow',
        state.toPlatformMap(),
      ),
    );
  }

  @override
  Future<void> enterMiniMode() async {
    await _ignorePlatformErrors(_enterMiniMode());
  }

  @override
  Future<void> exitMiniMode() async {
    await _ignorePlatformErrors(_exitMiniMode());
  }

  @override
  Future<void> startWindowDrag() async {
    await _ignorePlatformErrors(windowManager.startDragging());
  }

  @override
  Future<void> stopWindowDrag() async {}

  @override
  Future<void> setWindowFullScreen(bool fullScreen) async {
    await _ignorePlatformErrors(_setWindowFullScreen(fullScreen));
  }

  @override
  Future<void> setWindowControlsLight(bool light) async {
    if (_windowControlsLight == light) {
      return;
    }
    _windowControlsLight = light;
    await _ignorePlatformErrors(
      _desktopFeatureChannel.invokeMethod<void>('setWindowControlsLight', {
        'light': light,
      }),
    );
  }

  @override
  Future<bool> getWindowFullScreen() async {
    try {
      return await windowManager.isFullScreen();
    } on Object {
      return false;
    }
  }

  @override
  Future<bool> getWindowMaximized() async {
    return await windowManager.isMaximized();
  }

  @override
  Future<bool> getWindowVisible() async {
    try {
      return await windowManager.isVisible();
    } on Object {
      return true;
    }
  }

  @override
  Future<void> showWindow() async {
    await windowManager.show();
    await windowManager.focus();
    _emit(
      const DesktopFeatureAction(
        DesktopFeatureCommand.windowVisibilityChanged,
        isWindowVisible: true,
      ),
    );
  }

  @override
  Future<void> toggleWindowVisibility() async {
    final visible = await windowManager.isVisible();
    if (visible) {
      await windowManager.hide();
      _emit(
        const DesktopFeatureAction(
          DesktopFeatureCommand.windowVisibilityChanged,
          isWindowVisible: false,
        ),
      );
    } else {
      await windowManager.show();
      await windowManager.focus();
      _emit(
        const DesktopFeatureAction(
          DesktopFeatureCommand.windowVisibilityChanged,
          isWindowVisible: true,
        ),
      );
    }
  }

  @override
  Future<void> minimizeWindow() async {
    await _ignorePlatformErrors(windowManager.minimize());
  }

  @override
  Future<void> toggleWindowMaximized() async {
    final isMaximized = await windowManager.isMaximized();
    if (isMaximized) {
      await _ignorePlatformErrors(windowManager.unmaximize());
    } else {
      await _ignorePlatformErrors(windowManager.maximize());
    }
  }

  @override
  Future<void> closeWindow() async {
    await _ignorePlatformErrors(windowManager.close());
  }

  @override
  Future<void> quit() async {
    _quitting = true;
    await _ignorePlatformErrors(tray.trayManager.destroy());
    await _ignorePlatformErrors(windowManager.destroy());
  }

  @override
  void onTrayIconMouseDown() {
    _emit(
      const DesktopFeatureAction(DesktopFeatureCommand.toggleWindowVisibility),
    );
  }

  @override
  void onWindowClose() {
    unawaited(_saveMainWindowState(immediate: true));
    final state = _lastTrayState;
    if (_quitting || state?.quitOnClose == true) {
      _emit(const DesktopFeatureAction(DesktopFeatureCommand.quit));
      return;
    }
    unawaited(windowManager.hide());
    _emit(
      const DesktopFeatureAction(
        DesktopFeatureCommand.windowVisibilityChanged,
        isWindowVisible: false,
      ),
    );
    if (!_shownTrayHint && state != null) {
      _shownTrayHint = true;
      unawaited(
        showTrackNotification(
          TrackNotificationPayload(
            songId: 0,
            title: state.labels.trayRunningTitle,
            artist: state.labels.trayRunningBody,
            album: '',
            silent: true,
          ),
        ),
      );
    }
  }

  @override
  void onWindowMoved() {
    unawaited(_saveMainWindowState());
  }

  @override
  void onWindowResized() {
    unawaited(_saveMainWindowState());
  }

  @override
  void onWindowMaximize() {
    _emit(
      const DesktopFeatureAction(
        DesktopFeatureCommand.windowMaximizedChanged,
        isWindowMaximized: true,
      ),
    );
    unawaited(_saveMainWindowState(immediate: true));
  }

  @override
  void onWindowUnmaximize() {
    _emit(
      const DesktopFeatureAction(
        DesktopFeatureCommand.windowMaximizedChanged,
        isWindowMaximized: false,
      ),
    );
    unawaited(_saveMainWindowState(immediate: true));
  }

  @override
  void onWindowEnterFullScreen() {
    _emit(
      const DesktopFeatureAction(
        DesktopFeatureCommand.windowFullScreenChanged,
        isWindowFullScreen: true,
      ),
    );
  }

  @override
  void onWindowLeaveFullScreen() {
    _emit(
      const DesktopFeatureAction(
        DesktopFeatureCommand.windowFullScreenChanged,
        isWindowFullScreen: false,
      ),
    );
  }

  @override
  void dispose() {
    _mainWindowStateSaveDebounce?.cancel();
    tray.trayManager.removeListener(this);
    windowManager.removeListener(this);
    _desktopFeatureChannel.setMethodCallHandler(null);
  }

  Future<void> _handlePlatformMethodCall(MethodCall call) async {
    if (call.method == 'openFiles') {
      _emitOpenExternalAudioFiles(
        (call.arguments as List).whereType<String>().toList(growable: false),
      );
      return;
    }

    if (call.method == 'openExternalArguments') {
      _handleExternalArguments(
        (call.arguments as List).whereType<String>().toList(growable: false),
      );
      return;
    }

    if (call.method == 'desktopLyricsBoundsChanged') {
      final bounds = call.arguments as String;
      _emit(
        DesktopFeatureAction(
          DesktopFeatureCommand.desktopLyricsBoundsChanged,
          desktopLyricsBounds: bounds,
        ),
      );
      return;
    }

    if (call.method != 'desktopCommand') {
      return;
    }
    final command = call.arguments as String;
    if (command.startsWith('seek-to:')) {
      final seconds = double.tryParse(command.substring('seek-to:'.length));
      if (seconds != null) {
        _emit(
          DesktopFeatureAction(
            DesktopFeatureCommand.mediaSessionSeekTo,
            seekSeconds: seconds,
          ),
        );
      }
      return;
    }
    _emit(DesktopFeatureAction(_desktopFeatureCommandFromPlatform(command)));
  }

  void _handleExternalArguments(List<String> arguments) {
    _emitOpenExternalAudioFiles(externalAudioPathsFromArgs(arguments));
    for (final command in externalAppCommandsFromArgs(arguments)) {
      _emit(_desktopFeatureActionFromExternal(command));
    }
  }

  void _emitOpenExternalAudioFiles(List<String> paths) {
    if (paths.isEmpty) {
      return;
    }
    _emit(
      DesktopFeatureAction(
        DesktopFeatureCommand.openExternalAudioFiles,
        filePaths: paths,
      ),
    );
  }

  tray.MenuItem _toTrayMenuItem(DesktopTrayMenuEntry entry) {
    if (entry.separator) {
      return tray.MenuItem.separator();
    }
    if (entry.children.isNotEmpty) {
      return tray.MenuItem.submenu(
        key: _menuKey(entry),
        label: entry.label,
        submenu: tray.Menu(items: entry.children.map(_toTrayMenuItem).toList()),
      );
    }
    return tray.MenuItem(
      key: _menuKey(entry),
      label: entry.label,
      onClick: (_) {
        final action = entry.action;
        if (action != null) {
          _emit(DesktopFeatureAction(action, songId: entry.songId));
        }
      },
    );
  }

  String _menuKey(DesktopTrayMenuEntry entry) {
    final action = entry.action?.name ?? 'submenu';
    return entry.songId == null ? action : '$action-${entry.songId}';
  }

  void _emit(DesktopFeatureAction action) {
    _onAction?.call(action);
  }

  Future<void> _saveMainWindowState({bool immediate = false}) async {
    if (_miniModeActive || await windowManager.isFullScreen()) {
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
      _mainWindowStateSaveDelay,
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
      await windowManager.setBounds(bounds, animate: true);
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

  Future<void> _ignorePlatformErrors<T>(Future<T> action) async {
    try {
      await action;
    } on Object {
      // Platform plugins are unavailable in widget tests and on unsupported
      // desktop shells. The feature service remains inert in that case.
    }
  }
}

Rect miniModeWindowBoundsFor(
  Rect currentBounds,
  Rect workArea, {
  Size miniModeSize = _miniModeWindowSize,
}) {
  final x =
      max(
        workArea.left,
        min(
          currentBounds.left + currentBounds.width - miniModeSize.width,
          workArea.right - miniModeSize.width,
        ),
      ).toDouble();
  final y =
      max(
        workArea.top,
        min(currentBounds.top, workArea.bottom - miniModeSize.height),
      ).toDouble();
  return Rect.fromLTWH(x, y, miniModeSize.width, miniModeSize.height);
}
