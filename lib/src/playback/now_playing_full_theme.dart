import 'package:flutter/material.dart';

class NowPlayingFullColors {
  const NowPlayingFullColors._();

  static const accentStrong = Color(0xff0063b1);
  static const dayText = Color(0xff101828);
  static const dayMuted = Color(0xff667085);
  static const nightText = Color(0xfff8fafc);
  static const nightMuted = Color(0xffcbd5e1);
}

class NowPlayingFullThemeColors
    extends ThemeExtension<NowPlayingFullThemeColors> {
  const NowPlayingFullThemeColors({
    required this.pageBackground,
    required this.fallbackBackdrop,
    required this.backdropOverlay,
    required this.panel,
    required this.border,
    required this.topButtonBackground,
    required this.topButtonForeground,
    required this.topButtonActiveForeground,
    required this.text,
    required this.muted,
    required this.subtle,
    required this.artworkBackdropOpacity,
    required this.artworkShadowOpacity,
  });

  final Color pageBackground;
  final Decoration fallbackBackdrop;
  final Gradient backdropOverlay;
  final Color panel;
  final Color border;
  final Color topButtonBackground;
  final Color topButtonForeground;
  final Color topButtonActiveForeground;
  final Color text;
  final Color muted;
  final Color subtle;
  final double artworkBackdropOpacity;
  final double artworkShadowOpacity;

  static const light = NowPlayingFullThemeColors(
    pageBackground: Color(0xfaf6f9fc),
    fallbackBackdrop: BoxDecoration(
      gradient: RadialGradient(
        center: Alignment(-0.6, -0.56),
        radius: 0.78,
        colors: [Color(0x7aabd9ff), Colors.transparent],
      ),
    ),
    backdropOverlay: LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [Color(0xd1f6f9fc), Color(0x75f6f9fc), Color(0xd1f6f9fc)],
      stops: [0, 0.56, 1],
    ),
    panel: Color(0xc7ffffff),
    border: Color(0xb8ccd5e0),
    topButtonBackground: Color(0xa8ffffff),
    topButtonForeground: NowPlayingFullColors.dayText,
    topButtonActiveForeground: NowPlayingFullColors.accentStrong,
    text: NowPlayingFullColors.dayText,
    muted: NowPlayingFullColors.dayMuted,
    subtle: Color(0x945b697a),
    artworkBackdropOpacity: 0.92,
    artworkShadowOpacity: 0.22,
  );

  static const dark = NowPlayingFullThemeColors(
    pageBackground: Color(0xff07111f),
    fallbackBackdrop: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x3d140f0c), Color(0xc7100c08)],
      ),
    ),
    backdropOverlay: LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [Color(0xd6120e0a), Color(0x9419120c), Color(0xd10d0a08)],
      stops: [0, 0.52, 1],
    ),
    panel: Color(0xe612100e),
    border: Color(0x2effffff),
    topButtonBackground: Color(0x14ffffff),
    topButtonForeground: Color(0xe0ffffff),
    topButtonActiveForeground: Colors.white,
    text: NowPlayingFullColors.nightText,
    muted: NowPlayingFullColors.nightMuted,
    subtle: Color(0xb8ffffff),
    artworkBackdropOpacity: 1,
    artworkShadowOpacity: 0.38,
  );

  static NowPlayingFullThemeColors of(BuildContext context, {bool? night}) {
    if (night != null) {
      return night ? dark : light;
    }
    return Theme.of(context).extension<NowPlayingFullThemeColors>() ?? light;
  }

  @override
  NowPlayingFullThemeColors copyWith() {
    return this;
  }

  @override
  NowPlayingFullThemeColors lerp(
    covariant ThemeExtension<NowPlayingFullThemeColors>? other,
    double t,
  ) {
    return this;
  }
}
