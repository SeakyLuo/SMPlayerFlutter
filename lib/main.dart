import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smplayer_flutter/src/app/app_appearance_model.dart';
import 'package:smplayer_flutter/src/app/app_route_model.dart';
import 'package:smplayer_flutter/src/app/app_router.dart';
import 'package:smplayer_flutter/src/app/app_window_state_model.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/platform/external_open_model.dart';
import 'package:smplayer_flutter/src/settings/settings_controller.dart';
import 'package:smplayer_flutter/src/settings/settings_model.dart';
import 'package:screen_retriever/screen_retriever.dart' as screen;
import 'package:window_manager/window_manager.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    await windowManager.ensureInitialized();
    await windowManager.setPreventClose(true);
  }
  final settingsController = SettingsController();
  await settingsController.refresh();
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    await _restoreMainWindowState(settingsController.snapshot);
  }
  final initialLocation = resolveRestoredPage(
    settingsController.snapshot.lastPage,
  );
  runApp(
    ProviderScope(
      child: SmPlayerApp(
        router: createSmPlayerRouter(
          initialLocation: initialLocation,
          settingsController: settingsController,
          initialExternalFilePaths: externalAudioPathsFromArgs(args),
          initialExternalCommands: externalAppCommandsFromArgs(args),
        ),
        settingsController: settingsController,
      ),
    ),
  );
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
  @override
  void initState() {
    super.initState();
    widget.settingsController.addListener(_handleSettingsChanged);
  }

  @override
  void dispose() {
    widget.settingsController.removeListener(_handleSettingsChanged);
    widget.settingsController.dispose();
    super.dispose();
  }

  void _handleSettingsChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final i18nValue = ref.watch(smPlayerI18nProvider);
    final i18n =
        i18nValue.valueOrNull ??
        const SmPlayerI18n(locale: smPlayerFallbackLocale, messages: {});
    final theme = buildSmPlayerTheme(widget.settingsController.snapshot);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: i18n.t('app.shell'),
      locale: smPlayerLocaleFromName(i18n.locale),
      supportedLocales: smPlayerSupportedLocales,
      theme: theme,
      darkTheme: theme,
      themeMode: ThemeMode.light,
      routerConfig: widget.router,
      builder: (context, child) {
        return SmPlayerI18nScope(
          i18n: i18n,
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}

Future<void> _restoreMainWindowState(SettingsSnapshot settings) async {
  await windowManager.setMinimumSize(mainWindowMinimumSize);
  final bounds = resolveInitialMainWindowBounds(
    parseMainWindowBounds(settings.mainWindowBounds),
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
