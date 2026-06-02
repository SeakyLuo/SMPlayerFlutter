import 'package:flutter/material.dart';

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
    background: Color(0xffd9ecfb),
    border: Color(0x260078d7),
    shadow: BoxShadow(
      color: Color(0x300078d7),
      offset: Offset(0, 8),
      blurRadius: 18,
    ),
    artworkShadow: BoxShadow(
      color: Color(0x120078d7),
      offset: Offset(0, 4),
      blurRadius: 10,
    ),
    foreground: Color(0xff0063b1),
    muted: Color(0xff0063b1),
  );

  static const lightHover = SelectedCollectionCardStyle(
    background: Color(0x140078d7),
    border: Color(0x260078d7),
    shadow: BoxShadow(
      color: Color(0x000078d7),
      offset: Offset(0, 0),
      blurRadius: 0,
    ),
    artworkShadow: BoxShadow(
      color: Color(0x0f0078d7),
      offset: Offset(0, 4),
      blurRadius: 10,
    ),
    foreground: Color(0xff0063b1),
    muted: Color(0xff0063b1),
  );

  static const dark = SelectedCollectionCardStyle(
    background: Color(0x330078d7),
    border: Color(0x380078d7),
    shadow: BoxShadow(
      color: Color(0x24000000),
      offset: Offset(0, 10),
      blurRadius: 24,
    ),
    artworkShadow: BoxShadow(
      color: Color(0x36000000),
      offset: Offset(0, 6),
      blurRadius: 14,
    ),
    foreground: Color(0xff459de2),
    muted: Color(0xc276b5dc),
  );

  static const darkHover = SelectedCollectionCardStyle(
    background: Color(0x260078d7),
    border: Color(0x330078d7),
    shadow: BoxShadow(
      color: Color(0x26000000),
      offset: Offset(0, 10),
      blurRadius: 24,
    ),
    artworkShadow: BoxShadow(
      color: Color(0x30000000),
      offset: Offset(0, 6),
      blurRadius: 14,
    ),
    foreground: Color(0xff459de2),
    muted: Color(0xc276b5dc),
  );
}
