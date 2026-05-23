import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:smplayer_flutter/src/playback/now_playing_full_model.dart';
import 'package:smplayer_flutter/src/settings/settings_model.dart';

bool isAppNightMode(SettingsSnapshot settings) {
  return switch (settings.nightMode) {
    NightMode.system =>
      PlatformDispatcher.instance.platformBrightness == Brightness.dark,
    NightMode.onMode => true,
    NightMode.never => false,
    NightMode.auto => isMinuteInNightRange(
      getCurrentClockMinute(),
      timeToMinute(settings.nightModeStartTime),
      timeToMinute(settings.nightModeEndTime),
    ),
  };
}

ThemeMode resolveSmPlayerThemeMode(SettingsSnapshot settings) {
  return switch (settings.nightMode) {
    NightMode.system => ThemeMode.system,
    NightMode.onMode => ThemeMode.dark,
    NightMode.never => ThemeMode.light,
    NightMode.auto =>
      isAppNightMode(settings) ? ThemeMode.dark : ThemeMode.light,
  };
}

Color appAccentColor(String themeColor) {
  return Color(0xff000000 + int.parse(themeColor.substring(1), radix: 16));
}

ThemeData buildSmPlayerTheme(
  SettingsSnapshot settings, {
  Brightness? brightness,
}) {
  final accent = appAccentColor(settings.themeColor);
  final resolvedBrightness =
      brightness ??
      (isAppNightMode(settings) ? Brightness.dark : Brightness.light);
  final colorScheme = ColorScheme.fromSeed(
    seedColor: accent,
    brightness: resolvedBrightness,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor:
        resolvedBrightness == Brightness.dark
            ? const Color(0xff111317)
            : const Color(0xfff5f7fb),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: _NoPageTransitionsBuilder(),
        TargetPlatform.fuchsia: _NoPageTransitionsBuilder(),
        TargetPlatform.iOS: _NoPageTransitionsBuilder(),
        TargetPlatform.linux: _NoPageTransitionsBuilder(),
        TargetPlatform.macOS: _NoPageTransitionsBuilder(),
        TargetPlatform.windows: _NoPageTransitionsBuilder(),
      },
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: accent),
    sliderTheme: SliderThemeData(
      activeTrackColor: accent,
      thumbColor: accent,
      overlayColor: accent.withValues(alpha: 0.16),
    ),
  );
}

class _NoPageTransitionsBuilder extends PageTransitionsBuilder {
  const _NoPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}
