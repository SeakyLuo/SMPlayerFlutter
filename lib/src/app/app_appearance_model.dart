import 'package:flutter/material.dart';
import 'package:smplayer_flutter/src/playback/now_playing_full_model.dart';
import 'package:smplayer_flutter/src/settings/settings_model.dart';

bool isAppNightMode(SettingsSnapshot settings) {
  return switch (settings.nightMode) {
    NightMode.onMode => true,
    NightMode.never => false,
    NightMode.auto => isMinuteInNightRange(
      getCurrentClockMinute(),
      timeToMinute(settings.nightModeStartTime),
      timeToMinute(settings.nightModeEndTime),
    ),
  };
}

Color appAccentColor(String themeColor) {
  return Color(0xff000000 + int.parse(themeColor.substring(1), radix: 16));
}

ThemeData buildSmPlayerTheme(SettingsSnapshot settings) {
  final accent = appAccentColor(settings.themeColor);
  final brightness =
      isAppNightMode(settings) ? Brightness.dark : Brightness.light;
  final colorScheme = ColorScheme.fromSeed(
    seedColor: accent,
    brightness: brightness,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor:
        brightness == Brightness.dark
            ? const Color(0xff111317)
            : const Color(0xfff5f7fb),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: accent),
    sliderTheme: SliderThemeData(
      activeTrackColor: accent,
      thumbColor: accent,
      overlayColor: accent.withValues(alpha: 0.16),
    ),
  );
}
