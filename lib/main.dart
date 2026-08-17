import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
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
import 'package:smplayer_flutter/src/settings/settings_controller.dart';
import 'package:smplayer_flutter/src/settings/settings_model.dart';
import 'package:screen_retriever/screen_retriever.dart' as screen;
import 'package:window_manager/window_manager.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isWindows) {
    JustAudioMediaKit.ensureInitialized(windows: true, linux: false);
  }
  const repository = LibraryRepository();
  final settingsSnapshot = await repository.initializeSettingsSnapshot();
  final settingsController = SettingsController(settingsSnapshot, repository);
  final settings = settingsController.snapshot;
  runApp(
    SmPlayerRoot(
      initialLocation: resolveRestoredPage(settings.lastPage),
      initialSettingsController: settingsController,
      initialExternalFilePaths: externalAudioPathsFromArgs(args),
      initialExternalCommands: externalAppCommandsFromArgs(args),
    ),
  );
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(dismissNativeSplash());
  });
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    unawaited(_initializeDesktopWindow(settings));
  }
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
      evictSmPlayerLocaleAssets();
      ref.invalidate(smPlayerI18nProvider);
    }
    setState(() {});
    _scheduleNightModeTimer();
  }

  @override
  void reassemble() {
    evictSmPlayerLocaleAssets();
    ref.invalidate(smPlayerI18nProvider);
    super.reassemble();
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

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title:
          i18n?.t('app.shell') ??
          SmPlayerSplashAppName.resolve(
            WidgetsBinding.instance.platformDispatcher.locale,
          ),
      locale: i18n == null ? null : smPlayerLocaleFromName(i18n.locale),
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
        if (i18n == null) {
          return SmPlayerSplashView(brightness: brightness);
        }
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
