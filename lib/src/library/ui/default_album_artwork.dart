import 'dart:ui';

import 'package:flutter/material.dart';

class DefaultAlbumArtwork extends StatelessWidget {
  const DefaultAlbumArtwork({
    super.key,
    this.logoScale = 0.68,
    this.lightShadowOffset = 10,
    this.darkShadowOffset = 12,
    this.lightShadowBlur = 18,
    this.darkShadowBlur = 22,
    this.logoOpacity = 1,
  });

  final double logoScale;
  final double lightShadowOffset;
  final double darkShadowOffset;
  final double lightShadowBlur;
  final double darkShadowBlur;
  final double logoOpacity;

  @override
  Widget build(BuildContext context) {
    final colors = DefaultAlbumArtworkThemeColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(color: colors.background),
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.4, -0.6),
                radius: 0.72,
                colors: colors.radialGradient,
                stops: const [0.0, 0.26, 0.72],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: colors.linearGradient,
              ),
            ),
          ),
          Center(
            child: FractionallySizedBox(
              widthFactor: logoScale,
              heightFactor: logoScale,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Transform.translate(
                    offset: Offset(
                      0,
                      colors.shadowOffset(darkShadowOffset, lightShadowOffset),
                    ),
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(
                        sigmaX: colors.shadowBlur(
                          darkShadowBlur,
                          lightShadowBlur,
                        ),
                        sigmaY: colors.shadowBlur(
                          darkShadowBlur,
                          lightShadowBlur,
                        ),
                      ),
                      child: ColorFiltered(
                        colorFilter: ColorFilter.mode(
                          colors.shadowColor,
                          BlendMode.srcIn,
                        ),
                        child: Image.asset(
                          'assets/branding/app-icon.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  Opacity(
                    opacity: logoOpacity * colors.logoOpacity,
                    child: Image.asset(
                      'assets/branding/app-icon.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DefaultAlbumArtworkThemeColors
    extends ThemeExtension<DefaultAlbumArtworkThemeColors> {
  const DefaultAlbumArtworkThemeColors({
    required this.background,
    required this.radialGradient,
    required this.linearGradient,
    required this.shadowColor,
    required this.logoOpacity,
    required this.useDarkShadowMetrics,
  });

  final Color background;
  final List<Color> radialGradient;
  final List<Color> linearGradient;
  final Color shadowColor;
  final double logoOpacity;
  final bool useDarkShadowMetrics;

  static const light = DefaultAlbumArtworkThemeColors(
    background: Color(0xf0f7f9fc),
    radialGradient: [Color(0x45ffffff), Color(0x24ffffff), Color(0x00ffffff)],
    linearGradient: [Color(0x24ffffff), Color(0x00ffffff)],
    shadowColor: Color(0x1f263952),
    logoOpacity: 0.9,
    useDarkShadowMetrics: false,
  );

  static const dark = DefaultAlbumArtworkThemeColors(
    background: Color(0xf511161c),
    radialGradient: [Color(0x10ffffff), Color(0x08ffffff), Color(0x00ffffff)],
    linearGradient: [Color(0x0affffff), Color(0x00000000)],
    shadowColor: Color(0x52000000),
    logoOpacity: 0.78,
    useDarkShadowMetrics: true,
  );

  static DefaultAlbumArtworkThemeColors of(BuildContext context) {
    return Theme.of(context).extension<DefaultAlbumArtworkThemeColors>()!;
  }

  double shadowOffset(double dark, double light) {
    return useDarkShadowMetrics ? dark : light;
  }

  double shadowBlur(double dark, double light) {
    return useDarkShadowMetrics ? dark : light;
  }

  @override
  DefaultAlbumArtworkThemeColors copyWith() {
    return this;
  }

  @override
  DefaultAlbumArtworkThemeColors lerp(
    ThemeExtension<DefaultAlbumArtworkThemeColors>? other,
    double t,
  ) {
    return t < 0.5 || other is! DefaultAlbumArtworkThemeColors ? this : other;
  }
}
