import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smplayer_flutter/src/app/app_appearance_model.dart';
import 'package:smplayer_flutter/src/app/app_route_model.dart';
import 'package:smplayer_flutter/src/app/app_router.dart';
import 'package:smplayer_flutter/src/app/app_window_state_model.dart';
import 'package:smplayer_flutter/src/app/splash_screen.dart';
import 'package:smplayer_flutter/src/app/touch_context_menu.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_repository.dart';
import 'package:smplayer_flutter/src/platform/desktop_feature_service.dart';
import 'package:smplayer_flutter/src/platform/external_open_model.dart';
import 'package:smplayer_flutter/src/playback/immersive_mode_route.dart';
import 'package:smplayer_flutter/src/settings/settings_controller.dart';
import 'package:smplayer_flutter/src/settings/settings_model.dart';
import 'package:screen_retriever/screen_retriever.dart' as screen;
import 'package:window_manager/window_manager.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(SmPlayerBootstrap(args: args));
}

class SmPlayerBootstrap extends StatefulWidget {
  const SmPlayerBootstrap({super.key, required this.args});

  final List<String> args;

  @override
  State<SmPlayerBootstrap> createState() => _SmPlayerBootstrapState();
}

class _SmPlayerBootstrapState extends State<SmPlayerBootstrap> {
  _SmPlayerStartupState? _startupState;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(dismissNativeSplash());
    });
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    const repository = LibraryRepository();
    final settingsSnapshot = await repository.initializeSettingsSnapshot();
    final settingsController = SettingsController(settingsSnapshot, repository);
    final settings = settingsController.snapshot;
    final restoredLocation = resolveRestoredPage(settings.lastPage);
    final initialLocation =
        settings.lastDisplayMode == SmPlayerDisplayMode.immersive
            ? immersiveModeRoutePath
            : restoredLocation;
    if (!mounted) {
      settingsController.dispose();
      return;
    }
    setState(() {
      _startupState = _SmPlayerStartupState(
        initialLocation: initialLocation,
        settingsController: settingsController,
      );
    });
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      unawaited(_initializeDesktopWindow(settings));
    }
  }

  @override
  Widget build(BuildContext context) {
    final startupState = _startupState;
    if (startupState == null) {
      return const SmPlayerSplashScreen();
    }
    return SmPlayerRoot(
      initialLocation: startupState.initialLocation,
      initialSettingsController: startupState.settingsController,
      initialExternalFilePaths: externalAudioPathsFromArgs(widget.args),
      initialExternalCommands: externalAppCommandsFromArgs(widget.args),
    );
  }
}

class _SmPlayerStartupState {
  const _SmPlayerStartupState({
    required this.initialLocation,
    required this.settingsController,
  });

  final String initialLocation;
  final SettingsController settingsController;
}

class SmPlayerRoot extends StatefulWidget {
  const SmPlayerRoot({
    super.key,
    required this.initialLocation,
    required this.initialSettingsController,
    this.initialExternalFilePaths = const [],
    this.initialExternalCommands = const [],
  });

  final String initialLocation;
  final SettingsController initialSettingsController;
  final List<String> initialExternalFilePaths;
  final List<ExternalAppCommand> initialExternalCommands;

  @override
  State<SmPlayerRoot> createState() => _SmPlayerRootState();
}

class _SmPlayerRootState extends State<SmPlayerRoot> {
  late SettingsController _settingsController;
  late GoRouter _router;
  var _reloadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _settingsController = widget.initialSettingsController;
    _router = _createRouter(
      initialLocation: widget.initialLocation,
      initialExternalFilePaths: widget.initialExternalFilePaths,
      initialExternalCommands: widget.initialExternalCommands,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      key: ValueKey('SmPlayerRoot.ProviderScope.$_reloadGeneration'),
      child: SmPlayerApp(
        key: ValueKey('SmPlayerApp.$_reloadGeneration'),
        router: _router,
        settingsController: _settingsController,
      ),
    );
  }

  GoRouter _createRouter({
    required String initialLocation,
    List<String> initialExternalFilePaths = const [],
    List<ExternalAppCommand> initialExternalCommands = const [],
  }) {
    return createSmPlayerRouter(
      initialLocation: initialLocation,
      settingsController: _settingsController,
      initialExternalFilePaths: initialExternalFilePaths,
      initialExternalCommands: initialExternalCommands,
      onDataImported: _reloadAfterDataImport,
    );
  }

  Future<void> _reloadAfterDataImport() async {
    final nextSettingsController = SettingsController(
      null,
      const LibraryRepository(),
    );
    await nextSettingsController.refresh();
    final nextLocation = resolveRestoredPage(
      nextSettingsController.snapshot.lastPage,
    );
    if (!mounted) {
      nextSettingsController.dispose();
      return;
    }
    setState(() {
      _settingsController = nextSettingsController;
      _router = _createRouter(initialLocation: nextLocation);
      _reloadGeneration += 1;
    });
  }
}

class SmPlayerApp extends ConsumerStatefulWidget {
  const SmPlayerApp({
    super.key,
    required this.router,
    required this.settingsController,
  });

  final GoRouter router;
  final SettingsController settingsController;

  @override
  ConsumerState<SmPlayerApp> createState() => _SmPlayerAppState();
}

class _SmPlayerAppState extends ConsumerState<SmPlayerApp> {
  Timer? _nightModeTimer;
  late PreferredLanguage _lastPreferredLanguage;

  @override
  void initState() {
    super.initState();
    _lastPreferredLanguage =
        widget.settingsController.snapshot.preferredLanguage;
    widget.settingsController.addListener(_handleSettingsChanged);
    _scheduleNightModeTimer();
  }

  @override
  void dispose() {
    _nightModeTimer?.cancel();
    widget.settingsController.removeListener(_handleSettingsChanged);
    widget.settingsController.dispose();
    super.dispose();
  }

  void _handleSettingsChanged() {
    final preferredLanguage =
        widget.settingsController.snapshot.preferredLanguage;
    if (_lastPreferredLanguage != preferredLanguage) {
      _lastPreferredLanguage = preferredLanguage;
      ref.invalidate(smPlayerI18nProvider);
    }
    setState(() {});
    _scheduleNightModeTimer();
  }

  void _scheduleNightModeTimer() {
    _nightModeTimer?.cancel();
    if (widget.settingsController.snapshot.nightMode != NightMode.auto) {
      return;
    }
    final now = DateTime.now();
    final nextMinute = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute + 1,
    );
    _nightModeTimer = Timer(nextMinute.difference(now), () {
      if (!mounted) {
        return;
      }
      setState(() {});
      _scheduleNightModeTimer();
    });
  }

  @override
  Widget build(BuildContext context) {
    final i18nValue = ref.watch(smPlayerI18nProvider);
    final settings = widget.settingsController.snapshot;
    final lightTheme = buildSmPlayerTheme(
      settings,
      brightness: Brightness.light,
    );
    final darkTheme = buildSmPlayerTheme(settings, brightness: Brightness.dark);
    final themeMode = resolveSmPlayerThemeMode(settings);
    final brightness =
        isAppNightMode(settings) ? Brightness.dark : lightTheme.brightness;
    final i18n = i18nValue.valueOrNull;

    if (i18n == null) {
      return SmPlayerSplashScreen(brightness: brightness);
    }

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: i18n.t('app.shell'),
      locale: smPlayerLocaleFromName(i18n.locale),
      supportedLocales: smPlayerSupportedLocales,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      routerConfig: widget.router,
      builder: (context, child) {
        return SmPlayerI18nScope(
          i18n: i18n,
          child: TouchContextMenuAdapter(
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}

Future<void> _initializeDesktopWindow(SettingsSnapshot settings) async {
  await windowManager.ensureInitialized();
  await Future.wait([
    windowManager.setTitleBarStyle(TitleBarStyle.hidden),
    windowManager.setPreventClose(true),
    _restoreMainWindowState(settings),
  ]);
}

Future<void> _restoreMainWindowState(SettingsSnapshot settings) async {
  await windowManager.setMinimumSize(mainWindowMinimumSize);
  final savedBounds = parseMainWindowBounds(settings.mainWindowBounds);
  final bounds = resolveInitialMainWindowBounds(
    savedBounds,
    await _mainWindowWorkAreas(),
  );
  await windowManager.setBounds(bounds);
  if (settings.mainWindowMaximized) {
    await windowManager.maximize();
  }
}

Future<List<Rect>> _mainWindowWorkAreas() async {
  final displays = await screen.screenRetriever.getAllDisplays();
  if (displays.isNotEmpty) {
    return displays.map(_workAreaForDisplay).toList();
  }
  final primary = await screen.screenRetriever.getPrimaryDisplay();
  return [_workAreaForDisplay(primary)];
}

Rect _workAreaForDisplay(screen.Display display) {
  final visiblePosition = display.visiblePosition ?? Offset.zero;
  final visibleSize = display.visibleSize ?? display.size;
  return Rect.fromLTWH(
    visiblePosition.dx,
    visiblePosition.dy,
    visibleSize.width,
    visibleSize.height,
  );
}
