import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smplayer_flutter/src/app/shell_page.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
import 'package:smplayer_flutter/src/library/data/library_repository.dart';
import 'package:smplayer_flutter/src/platform/desktop_features.dart';
import 'package:smplayer_flutter/src/playback/media_control_model.dart';
import 'package:smplayer_flutter/src/settings/settings_controller.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('shell matches Electron navigation breakpoints', () {
    expect(
      SmPlayerShellMetrics.navigationModeForWidth(719),
      SmPlayerNavigationMode.minimal,
    );
    expect(
      SmPlayerShellMetrics.navigationModeForWidth(720),
      SmPlayerNavigationMode.overlay,
    );
    expect(
      SmPlayerShellMetrics.navigationModeForWidth(1199),
      SmPlayerNavigationMode.overlay,
    );
    expect(
      SmPlayerShellMetrics.navigationModeForWidth(1200),
      SmPlayerNavigationMode.wide,
    );
  });

  test('compareAppVersions mirrors Electron version ordering', () {
    expect(compareAppVersions('1.2.0', '1.1.9'), greaterThan(0));
    expect(compareAppVersions('1.0', '1.0.0'), 0);
    expect(compareAppVersions('1.0.0', '1.0.1'), lessThan(0));
  });

  test('nextQueueIndexForPlayback mirrors Electron queue modes', () {
    expect(
      nextQueueIndexForPlayback(
        queueLength: 3,
        currentIndex: 1,
        mode: PlaybackMode.once,
        forward: true,
        automatic: false,
      ),
      2,
    );
    expect(
      nextQueueIndexForPlayback(
        queueLength: 3,
        currentIndex: 2,
        mode: PlaybackMode.once,
        forward: true,
        automatic: true,
      ),
      isNull,
    );
    expect(
      nextQueueIndexForPlayback(
        queueLength: 3,
        currentIndex: 2,
        mode: PlaybackMode.repeat,
        forward: true,
        automatic: true,
      ),
      0,
    );
    expect(
      nextQueueIndexForPlayback(
        queueLength: 3,
        currentIndex: 1,
        mode: PlaybackMode.repeatOne,
        forward: true,
        automatic: true,
      ),
      1,
    );
    expect(
      nextQueueIndexForPlayback(
        queueLength: 3,
        currentIndex: 1,
        mode: PlaybackMode.shuffle,
        forward: true,
        automatic: true,
      ),
      2,
    );
    expect(
      nextQueueIndexForPlayback(
        queueLength: 3,
        currentIndex: 2,
        mode: PlaybackMode.shuffle,
        forward: true,
        automatic: true,
      ),
      0,
    );
    expect(
      nextQueueIndexForPlayback(
        queueLength: 3,
        currentIndex: 0,
        mode: PlaybackMode.shuffle,
        forward: false,
        automatic: false,
      ),
      2,
    );
  });

  test('playback shortcuts mirror Electron shell keys', () {
    expect(
      playbackShortcutForKey(
        key: LogicalKeyboardKey.space,
        control: false,
        alt: false,
        meta: false,
        shift: false,
      ),
      SmPlayerPlaybackShortcut.togglePlayPause,
    );
    expect(
      playbackShortcutForKey(
        key: LogicalKeyboardKey.arrowRight,
        control: true,
        alt: false,
        meta: false,
        shift: false,
      ),
      SmPlayerPlaybackShortcut.next,
    );
    expect(
      playbackShortcutForKey(
        key: LogicalKeyboardKey.arrowLeft,
        control: true,
        alt: false,
        meta: false,
        shift: false,
      ),
      SmPlayerPlaybackShortcut.previous,
    );
    expect(
      playbackShortcutForKey(
        key: LogicalKeyboardKey.arrowRight,
        control: false,
        alt: false,
        meta: false,
        shift: true,
      ),
      SmPlayerPlaybackShortcut.seekForwardLong,
    );
    expect(
      playbackShortcutForKey(
        key: LogicalKeyboardKey.arrowLeft,
        control: false,
        alt: false,
        meta: false,
        shift: false,
      ),
      SmPlayerPlaybackShortcut.seekBackwardShort,
    );
    expect(
      playbackShortcutForKey(
        key: LogicalKeyboardKey.keyS,
        control: false,
        alt: true,
        meta: false,
        shift: false,
      ),
      SmPlayerPlaybackShortcut.toggleShuffle,
    );
    expect(
      playbackShortcutForKey(
        key: LogicalKeyboardKey.keyR,
        control: false,
        alt: true,
        meta: false,
        shift: false,
      ),
      SmPlayerPlaybackShortcut.toggleRepeat,
    );
    expect(
      playbackShortcutForKey(
        key: LogicalKeyboardKey.digit1,
        control: false,
        alt: true,
        meta: false,
        shift: false,
      ),
      SmPlayerPlaybackShortcut.toggleRepeatOne,
    );
    expect(
      playbackShortcutForKey(
        key: LogicalKeyboardKey.arrowRight,
        control: false,
        alt: true,
        meta: false,
        shift: false,
      ),
      isNull,
    );
  });

  testWidgets('shell uses Electron wide layout metrics', (tester) async {
    _setViewSize(tester, const Size(1300, 600));

    await tester.pumpWidget(const _ShellPageTestApp());

    final sidebar = find.byKey(SmPlayerShellKeys.sidebar);
    final workspace = find.byKey(SmPlayerShellKeys.workspace);
    final reservedPlayer = find.byKey(SmPlayerShellKeys.reservedPlayer);

    expect(tester.getSize(sidebar).width, SmPlayerShellMetrics.sidebarWidth);
    expect(
      tester.getSize(sidebar).height,
      600 - SmPlayerShellMetrics.playerHeight,
    );
    expect(tester.getTopLeft(workspace).dx, SmPlayerShellMetrics.sidebarWidth);
    expect(
      tester.getSize(workspace).height,
      600 -
          SmPlayerShellMetrics.playerHeight +
          SmPlayerShellMetrics.playerTopRadius,
    );
    expect(
      tester.getSize(reservedPlayer).height,
      SmPlayerShellMetrics.playerHeight,
    );
  });

  testWidgets('shell collapses navigation to Electron rail width', (
    tester,
  ) async {
    _setViewSize(tester, const Size(1300, 600));

    await tester.pumpWidget(const _ShellPageTestApp());
    await tester.tap(
      find.byKey(const ValueKey('MainNavigationView.TogglePaneButton')),
    );
    await tester.pumpAndSettle();

    final sidebar = find.byKey(SmPlayerShellKeys.sidebar);
    final workspace = find.byKey(SmPlayerShellKeys.workspace);

    expect(
      tester.getSize(sidebar).width,
      SmPlayerShellMetrics.collapsedSidebarWidth,
    );
    expect(
      tester.getTopLeft(workspace).dx,
      SmPlayerShellMetrics.collapsedSidebarWidth,
    );
  });

  testWidgets('overlay navigation opens above the 64px shell rail', (
    tester,
  ) async {
    _setViewSize(tester, const Size(800, 600));

    await tester.pumpWidget(const _ShellPageTestApp());
    await tester.pumpAndSettle();

    final sidebar = find.byKey(SmPlayerShellKeys.sidebar);
    final workspace = find.byKey(SmPlayerShellKeys.workspace);

    expect(tester.getSize(sidebar).width, SmPlayerShellMetrics.sidebarWidth);
    expect(
      tester.getTopLeft(workspace).dx,
      SmPlayerShellMetrics.collapsedSidebarWidth,
    );
  });

  testWidgets('minimal navigation starts as Electron rail layout', (
    tester,
  ) async {
    _setViewSize(tester, const Size(600, 600));

    await tester.pumpWidget(const _ShellPageTestApp());
    await tester.pump();

    expect(
      tester.getSize(find.byKey(SmPlayerShellKeys.sidebar)).width,
      SmPlayerShellMetrics.collapsedSidebarWidth,
    );
    expect(
      tester.getTopLeft(find.byKey(SmPlayerShellKeys.workspace)).dx,
      SmPlayerShellMetrics.collapsedSidebarWidth,
    );
  });

  testWidgets('navigation mode changes follow Electron collapse rules', (
    tester,
  ) async {
    _setViewSize(tester, const Size(1300, 600));

    await tester.pumpWidget(const _ShellPageTestApp());
    await tester.pump();
    expect(
      tester.getSize(find.byKey(SmPlayerShellKeys.sidebar)).width,
      SmPlayerShellMetrics.sidebarWidth,
    );

    _setViewSize(tester, const Size(800, 600), resetAfterTest: false);
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(SmPlayerShellKeys.sidebar)).width,
      SmPlayerShellMetrics.collapsedSidebarWidth,
    );

    _setViewSize(tester, const Size(1300, 600), resetAfterTest: false);
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(SmPlayerShellKeys.sidebar)).width,
      SmPlayerShellMetrics.sidebarWidth,
    );
  });

  testWidgets('shell restores Electron navigation collapsed storage state', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      SmPlayerShellStorageKeys.navigationCollapsed: true,
    });
    _setViewSize(tester, const Size(800, 600));

    await tester.pumpWidget(const _ShellPageTestApp());
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byKey(SmPlayerShellKeys.sidebar)).width,
      SmPlayerShellMetrics.collapsedSidebarWidth,
    );
  });

  testWidgets('shell persists navigation collapsed changes', (tester) async {
    _setViewSize(tester, const Size(800, 600));

    await tester.pumpWidget(const _ShellPageTestApp());
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('MainNavigationView.TogglePaneButton')),
    );
    await tester.pumpAndSettle();

    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getBool(SmPlayerShellStorageKeys.navigationCollapsed),
      isTrue,
    );
  });

  testWidgets('release notes do not open on first install', (tester) async {
    await tester.pumpWidget(
      const _ShellPageTestApp(
        appVersion: '1.0.0',
        messages: _releaseNotesMessages,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Release Notes'), findsNothing);
  });

  testWidgets('shell commits pending deletes during startup', (tester) async {
    final repository = _StartupRepository();

    await tester.pumpWidget(_ShellPageTestApp(repository: repository));
    await tester.pump();

    expect(repository.commitPendingDeletesCount, 1);
  });

  testWidgets('shell syncs tray visibility state from desktop service', (
    tester,
  ) async {
    final desktopService = _ShellDesktopFeatureService();

    await tester.pumpWidget(_ShellPageTestApp(desktopService: desktopService));
    await tester.pump();
    expect(desktopService.trayStates.last.isWindowVisible, isTrue);

    desktopService.emit(
      const DesktopFeatureAction(
        DesktopFeatureCommand.windowVisibilityChanged,
        isWindowVisible: false,
      ),
    );
    await tester.pump();

    expect(desktopService.trayStates.last.isWindowVisible, isFalse);
  });

  testWidgets('shell shows window for external show-window command', (
    tester,
  ) async {
    final desktopService = _ShellDesktopFeatureService()..windowVisible = false;

    await tester.pumpWidget(_ShellPageTestApp(desktopService: desktopService));
    await tester.pump();

    desktopService.emit(
      const DesktopFeatureAction(DesktopFeatureCommand.showWindow),
    );
    await tester.pump();

    expect(desktopService.showWindowCount, 1);
    expect(desktopService.toggleWindowVisibilityCount, 0);
    expect(desktopService.windowVisible, isTrue);
  });

  testWidgets('shell syncs light window controls for night mode', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      SmPlayerSettingsStorageKeys.nightMode: 'on',
    });
    final desktopService = _ShellDesktopFeatureService();

    await tester.pumpWidget(_ShellPageTestApp(desktopService: desktopService));
    await tester.pumpAndSettle();

    expect(desktopService.windowControlsLight, isTrue);
  });

  testWidgets('shell mirrors desktop fullscreen change events', (tester) async {
    final desktopService = _ShellDesktopFeatureService();
    final navigations = <String>[];

    await tester.pumpWidget(
      ProviderScope(
        child: SmPlayerI18nScope(
          i18n: const SmPlayerI18n(locale: 'en-US', messages: {}),
          child: MaterialApp(
            home: SmPlayerShellPage(
              currentPath: '/now-playing/full',
              desktopFeatureService: desktopService,
              onNavigate: navigations.add,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    desktopService.emit(
      const DesktopFeatureAction(
        DesktopFeatureCommand.windowFullScreenChanged,
        isWindowFullScreen: false,
      ),
    );
    await tester.pump();

    expect(navigations.last, '/now-playing');
  });

  testWidgets('release notes open after app version upgrade', (tester) async {
    SharedPreferences.setMockInitialValues({
      SmPlayerSettingsStorageKeys.lastReleaseNotesVersion: '0.9.0',
    });

    await tester.pumpWidget(
      const _ShellPageTestApp(
        appVersion: '1.0.0',
        messages: _releaseNotesMessages,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Release Notes'), findsOneWidget);
    expect(find.text('Version 1.0.0'), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getString(
        SmPlayerSettingsStorageKeys.lastReleaseNotesVersion,
      ),
      '1.0.0',
    );
    expect(find.text('Release Notes'), findsNothing);
  });
}

class _ShellPageTestApp extends StatelessWidget {
  const _ShellPageTestApp({
    this.appVersion,
    this.messages = const {},
    this.repository,
    this.desktopService,
  });

  final String? appVersion;
  final Map<String, String> messages;
  final LibraryRepository? repository;
  final DesktopFeatureService? desktopService;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        if (repository != null)
          libraryRepositoryProvider.overrideWithValue(repository!),
      ],
      child: SmPlayerI18nScope(
        i18n: SmPlayerI18n(locale: 'en-US', messages: messages),
        child: MaterialApp(
          home: SmPlayerShellPage(
            appVersion: appVersion,
            desktopFeatureService: desktopService,
          ),
        ),
      ),
    );
  }
}

class _StartupRepository extends LibraryRepository {
  var commitPendingDeletesCount = 0;

  @override
  Future<void> commitPendingDeletes() async {
    commitPendingDeletesCount += 1;
  }
}

class _ShellDesktopFeatureService implements DesktopFeatureService {
  ValueChanged<DesktopFeatureAction>? onAction;
  final trayStates = <DesktopTrayState>[];
  var windowVisible = true;
  var windowFullScreen = false;
  var showWindowCount = 0;
  var toggleWindowVisibilityCount = 0;
  bool? windowControlsLight;

  void emit(DesktopFeatureAction action) {
    if (action.isWindowVisible case final isVisible?) {
      windowVisible = isVisible;
    }
    if (action.isWindowFullScreen case final isFullScreen?) {
      windowFullScreen = isFullScreen;
    }
    onAction!(action);
  }

  @override
  Future<void> initialize(ValueChanged<DesktopFeatureAction> onAction) async {
    this.onAction = onAction;
  }

  @override
  Future<List<String>> getSystemFonts() async {
    return const [];
  }

  @override
  Future<void> updateTray(DesktopTrayState state) async {
    trayStates.add(state);
  }

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
  Future<void> setWindowFullScreen(bool fullScreen) async {
    windowFullScreen = fullScreen;
  }

  @override
  Future<void> setWindowControlsLight(bool light) async {
    windowControlsLight = light;
  }

  @override
  Future<bool> getWindowFullScreen() async {
    return windowFullScreen;
  }

  @override
  Future<bool> getWindowVisible() async {
    return windowVisible;
  }

  @override
  Future<void> showWindow() async {
    showWindowCount += 1;
    windowVisible = true;
  }

  @override
  Future<void> toggleWindowVisibility() async {
    toggleWindowVisibilityCount += 1;
    windowVisible = !windowVisible;
  }

  @override
  Future<void> quit() async {}

  @override
  void dispose() {}
}

const _releaseNotesMessages = {
  'settings.releaseNotes': 'Release Notes',
  'settings.releaseNotesArtists': 'Artists',
  'settings.releaseNotesIntro': 'History Updates',
  'settings.releaseNotesLibrary': 'Library',
  'settings.releaseNotesUi': 'UI',
  'settings.releaseNotesVersion': 'Version',
  'releaseNotes.architectureFeedback': 'Feedback',
  'common.close': 'Close',
};

void _setViewSize(
  WidgetTester tester,
  Size size, {
  bool resetAfterTest = true,
}) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  if (resetAfterTest) {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }
}
