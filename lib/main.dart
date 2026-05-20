import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smplayer_flutter/src/app/app_route_model.dart';
import 'package:smplayer_flutter/src/app/app_router.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/settings/settings_controller.dart';
import 'package:window_manager/window_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    await windowManager.ensureInitialized();
    await windowManager.setPreventClose(true);
  }
  final preferences = await SharedPreferences.getInstance();
  final initialLocation = resolveRestoredPage(
    preferences.getString(SmPlayerSettingsStorageKeys.lastPage) ?? '',
  );
  runApp(
    ProviderScope(
      child: SmPlayerApp(
        router: createSmPlayerRouter(initialLocation: initialLocation),
      ),
    ),
  );
}

class SmPlayerApp extends ConsumerWidget {
  const SmPlayerApp({super.key, required this.router});

  final GoRouter router;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final i18nValue = ref.watch(smPlayerI18nProvider);
    final i18n =
        i18nValue.valueOrNull ??
        const SmPlayerI18n(locale: smPlayerFallbackLocale, messages: {});

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: i18n.t('app.shell'),
      locale: smPlayerLocaleFromName(i18n.locale),
      supportedLocales: smPlayerSupportedLocales,
      routerConfig: router,
      builder: (context, child) {
        return SmPlayerI18nScope(
          i18n: i18n,
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
