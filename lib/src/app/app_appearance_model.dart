import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:smplayer_flutter/src/app/app_surface_colors.dart';
import 'package:smplayer_flutter/src/app/main_navigation_view.dart';
import 'package:smplayer_flutter/src/app/shell_colors.dart';
import 'package:smplayer_flutter/src/app/text_icon_button.dart';
import 'package:smplayer_flutter/src/app/undoable_notification.dart';
import 'package:smplayer_flutter/src/library/ui/default_album_artwork.dart';
import 'package:smplayer_flutter/src/library/ui/headered_playlist_control.dart';
import 'package:smplayer_flutter/src/library/ui/local_page_quick_jump.dart';
import 'package:smplayer_flutter/src/library/ui/menu_flyout.dart';
import 'package:smplayer_flutter/src/library/ui/missing_library_root_content.dart';
import 'package:smplayer_flutter/src/library/ui/popup_dialog.dart';
import 'package:smplayer_flutter/src/library/ui/search_page.dart';
import 'package:smplayer_flutter/src/playback/media_control.dart';
import 'package:smplayer_flutter/src/playback/now_playing_full_page.dart';
import 'package:smplayer_flutter/src/playback/now_playing_full_model.dart';
import 'package:smplayer_flutter/src/recent/recent_page.dart';
import 'package:smplayer_flutter/src/recent/recent_search_list.dart';
import 'package:smplayer_flutter/src/settings/settings_colors.dart';
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
            ? SmPlayerAppSurfaceColors.nightSurface
            : SmPlayerAppSurfaceColors.surface,
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
    extensions: [
      resolvedBrightness == Brightness.dark
          ? ShellThemeColors.dark
          : ShellThemeColors.light,
      resolvedBrightness == Brightness.dark
          ? MainNavigationPalette.dark
          : MainNavigationPalette.light,
      resolvedBrightness == Brightness.dark
          ? SmPlayerTextIconButtonColors.night
          : SmPlayerTextIconButtonColors.day,
      resolvedBrightness == Brightness.dark
          ? AppNotificationThemeColors.dark
          : AppNotificationThemeColors.light,
      resolvedBrightness == Brightness.dark
          ? MissingLibraryRootThemeColors.night
          : MissingLibraryRootThemeColors.day,
      resolvedBrightness == Brightness.dark
          ? DefaultAlbumArtworkThemeColors.dark
          : DefaultAlbumArtworkThemeColors.light,
      resolvedBrightness == Brightness.dark
          ? PopupDialogResolvedColors.dark
          : PopupDialogResolvedColors.light,
      resolvedBrightness == Brightness.dark
          ? MenuFlyoutThemeColors.dark
          : MenuFlyoutThemeColors.light,
      resolvedBrightness == Brightness.dark
          ? RecentThemeColors.dark
          : RecentThemeColors.light,
      resolvedBrightness == Brightness.dark
          ? RecentSearchThemeColors.dark
          : RecentSearchThemeColors.light,
      resolvedBrightness == Brightness.dark
          ? SearchPageThemeColors.dark
          : SearchPageThemeColors.light,
      resolvedBrightness == Brightness.dark
          ? SettingsPalette.dark
          : SettingsPalette.light,
      resolvedBrightness == Brightness.dark
          ? MediaControlThemeColors.dark
          : MediaControlThemeColors.light,
      resolvedBrightness == Brightness.dark
          ? NowPlayingFullThemeColors.dark
          : NowPlayingFullThemeColors.light,
      resolvedBrightness == Brightness.dark
          ? HeaderedPlaylistThemeColors.night
          : HeaderedPlaylistThemeColors.day,
      resolvedBrightness == Brightness.dark
          ? LocalPageColors.night
          : LocalPageColors.day,
    ],
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
