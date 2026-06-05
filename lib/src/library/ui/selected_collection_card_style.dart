import 'package:flutter/material.dart';
import 'package:smplayer_flutter/src/app/app_interaction_colors.dart';

class SelectedCollectionCardStyle {
  const SelectedCollectionCardStyle({
    required this.background,
    required this.border,
    required this.shadow,
    required this.artworkShadow,
    required this.foreground,
    required this.muted,
  });

  final Color background;
  final Color border;
  final BoxShadow shadow;
  final BoxShadow artworkShadow;
  final Color foreground;
  final Color muted;

  Color get transparentBackground => background.withValues(alpha: 0);
  Color get transparentBorder => border.withValues(alpha: 0);

  static SelectedCollectionCardStyle forBrightness(Brightness brightness) {
    return brightness == Brightness.dark ? dark : light;
  }

  static SelectedCollectionCardStyle hoverForBrightness(Brightness brightness) {
    return brightness == Brightness.dark ? darkHover : lightHover;
  }

  static const light = SelectedCollectionCardStyle(
    background: GlobalUI.selectedBgColorDay,
    border: GlobalUI.selectedBorderColorDay,
    shadow: GlobalUI.selectedShadowDay,
    artworkShadow: BoxShadow(
      color: Color(0x120078d7),
      offset: Offset(0, 4),
      blurRadius: 10,
    ),
    foreground: Color(0xff0063b1),
    muted: Color(0xff0063b1),
  );

  static const lightHover = SelectedCollectionCardStyle(
    background: GlobalUI.hoverBgColorDay,
    border: GlobalUI.hoverBorderColorDay,
    shadow: GlobalUI.hoverShadowDay,
    artworkShadow: BoxShadow(
      color: Color(0x0f0078d7),
      offset: Offset(0, 4),
      blurRadius: 10,
    ),
    foreground: Color(0xff0063b1),
    muted: Color(0xff0063b1),
  );

  static const dark = SelectedCollectionCardStyle(
    background: GlobalUI.selectedBgColorNight,
    border: GlobalUI.selectedBorderColorNight,
    shadow: GlobalUI.selectedShadowNight,
    artworkShadow: BoxShadow(
      color: Color(0x36000000),
      offset: Offset(0, 6),
      blurRadius: 14,
    ),
    foreground: Color(0xff459de2),
    muted: Color(0xc276b5dc),
  );

  static const darkHover = SelectedCollectionCardStyle(
    background: GlobalUI.hoverBgColorNight,
    border: GlobalUI.hoverBorderColorNight,
    shadow: GlobalUI.hoverShadowNight,
    artworkShadow: BoxShadow(
      color: Color(0x30000000),
      offset: Offset(0, 6),
      blurRadius: 14,
    ),
    foreground: Color(0xff459de2),
    muted: Color(0xc276b5dc),
  );
}
