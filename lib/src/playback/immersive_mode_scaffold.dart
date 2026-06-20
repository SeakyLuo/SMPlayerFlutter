import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:smplayer_flutter/src/playback/media_control.dart';
import 'package:smplayer_flutter/src/playback/immersive_mode_theme.dart';

MediaControlThemeColors immersiveMediaControlColors({required bool night}) {
  return switch (night) {
    true => _immersiveNightMediaControlColors,
    false => _immersiveDayMediaControlColors,
  };
}

final _immersiveDayMediaControlColors = MediaControlThemeColors.light.copyWith(
  textMuted: MediaControlColors.textMuted,
  primaryButtonBorder: Colors.transparent,
  primaryButtonHover: MediaControlColors.accentStrong,
  disabledPrimaryButtonSurface: MediaControlColors.disabledPrimaryButtonSurface,
  primaryButtonShadow: const BoxShadow(
    color: MediaControlColors.accentShadow,
    offset: Offset(0, 12),
    blurRadius: 26,
  ),
  buttonForeground: MediaControlColors.textStrong,
  buttonHoverForeground: MediaControlColors.accentStrong,
  buttonHoverBackground: const Color(0x1a0078d7),
  buttonActiveBackground: const Color(0x1a0078d7),
  favoriteActiveHoverBackground: const Color(0x1a0078d7),
  volumeTooltipBackground: const Color(0xe014181e),
  volumeTooltipForeground: Colors.white,
  volumeTooltipBorder: const Color(0x2effffff),
  volumeTooltipShadow: const BoxShadow(
    color: Color(0x57000000),
    offset: Offset(0, 10),
    blurRadius: 24,
  ),
  playerBorder: const Color(0xb8ccd5e0),
  compactPlayerBorder: const Color(0xb8ccd5e0),
  playerShadow: const Color(0x24445870),
  compactPlayerShadow: const Color(0x24445870),
  wideShadowOffsetY: -18,
  wideShadowBlur: 56,
  compactShadowOffsetY: -18,
  compactShadowBlur: 56,
  glassBlur: 18,
  glassSaturation: 1.4,
  compactGlassBlur: 18,
  compactGlassSaturation: 1.4,
  coverWashAlpha: 0.24,
  compactCoverWashAlpha: 0.24,
  wideSurface: const Color(0xc7ffffff),
  compactSurface: const Color(0xc7ffffff),
  compactWashEnd: Colors.transparent,
  compactWashStop: 0.42,
  coverWashMode: MediaControlCoverWashMode.radial,
  coverWashAlignment: const Alignment(-0.6, -0.56),
  coverWashRadius: 0.42,
  wideHighlightStops: null,
  wideInsetHighlight: const Color(0xc7ffffff),
  compactInsetHighlight: const Color(0xc7ffffff),
);

final _immersiveNightMediaControlColors = MediaControlThemeColors.dark.copyWith(
  textMuted: const Color(0xa8ffffff),
  primaryButtonBorder: const Color(0x6b0078d7),
  primaryButtonHover: MediaControlColors.accentStrong,
  disabledPrimaryButtonSurface: MediaControlColors.disabledPrimaryButtonSurface,
  primaryButtonShadow: const BoxShadow(
    color: Color(0x52000000),
    offset: Offset(0, 12),
    blurRadius: 26,
  ),
  buttonForeground: const Color(0xf0f6f9fc),
  buttonHoverForeground: Colors.white,
  buttonHoverBackground: const Color(0x2e0078d7),
  buttonActiveBackground: const Color(0x380078d7),
  favoriteActiveHoverBackground: const Color(0x38ffffff),
  volumeTooltipBackground: const Color(0xe014181e),
  volumeTooltipForeground: Colors.white,
  volumeTooltipBorder: const Color(0x2effffff),
  volumeTooltipShadow: const BoxShadow(
    color: Color(0x57000000),
    offset: Offset(0, 10),
    blurRadius: 24,
  ),
  playerBorder: const Color(0x1fd6e0ec),
  compactPlayerBorder: const Color(0x1fd6e0ec),
  playerShadow: const Color(0x57000000),
  compactPlayerShadow: const Color(0x57000000),
  wideShadowOffsetY: -18,
  wideShadowBlur: 48,
  compactShadowOffsetY: -12,
  compactShadowBlur: 36,
  glassBlur: 28,
  glassSaturation: 1,
  compactGlassBlur: 28,
  compactGlassSaturation: 1.45,
  coverWashAlpha: 0.22,
  compactCoverWashAlpha: 0.2,
  wideSurface: const Color(0xe611161c),
  compactSurface: const Color(0xeb101419),
  compactWashEnd: const Color(0xc711161c),
  compactWashStop: 0.56,
  compactBaseGradient: const [Color(0xe01d232b), Color(0xe0101419)],
  wideHighlightGradient: const [Color(0x0effffff), Color(0x1f0078d7)],
  wideHighlightStops: null,
  wideInsetHighlight: const Color(0x0cffffff),
  compactInsetHighlight: const Color(0x0cffffff),
);

class ImmersiveModeScaffold extends StatelessWidget {
  const ImmersiveModeScaffold({
    super.key,
    required this.child,
    required this.coverColor,
    this.artworkPath,
    this.night = false,
  });

  final String? artworkPath;
  final Color coverColor;
  final bool night;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final artworkFile =
        artworkPath == null || artworkPath!.isEmpty ? null : File(artworkPath!);
    final colors = ImmersiveModeThemeColors.of(context, night: night);
    final theme = Theme.of(context);
    final mediaControlColors = immersiveMediaControlColors(night: night);
    final scopedTheme = theme.copyWith(
      extensions: [
        for (final extension in theme.extensions.values)
          if (extension is! ImmersiveModeThemeColors &&
              extension is! MediaControlThemeColors)
            extension,
        colors,
        mediaControlColors,
      ],
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: colors.pageBackground),
        Positioned.fill(
          top: -40,
          right: -40,
          bottom: -40,
          left: -40,
          child: Transform.scale(
            scale: 1.08,
            child:
                artworkFile != null && artworkFile.existsSync()
                    ? ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 34, sigmaY: 34),
                      child: Opacity(
                        opacity: colors.artworkBackdropOpacity,
                        child: Image.file(artworkFile, fit: BoxFit.cover),
                      ),
                    )
                    : DecoratedBox(decoration: colors.fallbackBackdrop),
          ),
        ),
        if (night)
          const _ImmersiveModeNightArtworkShade()
        else
          _ImmersiveModeDayBackdropTint(coverColor: coverColor),
        if (!night) _ImmersiveModeDayCoverGlow(coverColor: coverColor),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: colors.backdropOverlay),
          ),
        ),
        if (night) const _ImmersiveModeNightWarmOverlay(),
        if (!night) _ImmersiveModeDayWashOverlay(coverColor: coverColor),
        Theme(
          data: scopedTheme,
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(
              context,
            ).copyWith(scrollbars: false),
            child: child,
          ),
        ),
      ],
    );
  }
}

class _ImmersiveModeDayBackdropTint extends StatelessWidget {
  const _ImmersiveModeDayBackdropTint({required this.coverColor});

  final Color coverColor;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      top: -40,
      right: -40,
      bottom: -40,
      left: -40,
      child: Transform.scale(
        scale: 1.08,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _CoverRadial(
              coverColor: coverColor,
              center: const Alignment(-0.6, -0.56),
              radius: 0.8,
              alpha: 0.48,
            ),
            _CoverRadial(
              coverColor: coverColor,
              center: const Alignment(0.44, -0.76),
              radius: 0.96,
              alpha: 0.24,
            ),
          ],
        ),
      ),
    );
  }
}

class _ImmersiveModeNightArtworkShade extends StatelessWidget {
  const _ImmersiveModeNightArtworkShade();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      top: -40,
      right: -40,
      bottom: -40,
      left: -40,
      child: Transform.scale(
        scale: 1.08,
        child: const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x3d140f0c), Color(0xc7100c08)],
            ),
          ),
        ),
      ),
    );
  }
}

class _ImmersiveModeDayCoverGlow extends StatelessWidget {
  const _ImmersiveModeDayCoverGlow({required this.coverColor});

  final Color coverColor;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      top: -120,
      right: -180,
      bottom: 120,
      left: -180,
      child: Transform.scale(
        scale: 1.04,
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 54, sigmaY: 54),
          child: Opacity(
            opacity: 0.98,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _CoverRadial(
                  coverColor: coverColor,
                  center: const Alignment(-0.6, -0.56),
                  radius: 0.72,
                  alpha: 0.6,
                ),
                _CoverRadial(
                  coverColor: coverColor,
                  center: const Alignment(0.2, -0.96),
                  radius: 0.8,
                  alpha: 0.3,
                ),
                _CoverRadial(
                  coverColor: coverColor,
                  center: const Alignment(0.76, -0.84),
                  radius: 0.72,
                  alpha: 0.2,
                ),
                _CoverRadial(
                  coverColor: coverColor,
                  center: const Alignment(-0.44, 0.36),
                  radius: 0.84,
                  alpha: 0.2,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ImmersiveModeDayWashOverlay extends StatelessWidget {
  const _ImmersiveModeDayWashOverlay({required this.coverColor});

  final Color coverColor;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Stack(
        fit: StackFit.expand,
        children: [
          _CoverRadial(
            coverColor: coverColor,
            center: const Alignment(-0.6, -0.56),
            radius: 0.84,
            alpha: 0.36,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x80f6f9fc),
                  Color(0xd1f6f9fc),
                  Color(0xf5f6f9fc),
                ],
                stops: [0, 0.72, 1],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImmersiveModeNightWarmOverlay extends StatelessWidget {
  const _ImmersiveModeNightWarmOverlay();

  @override
  Widget build(BuildContext context) {
    return const Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.64, -0.72),
            radius: 0.64,
            colors: [Color(0x2effd99c), Colors.transparent],
            stops: [0, 1],
          ),
        ),
      ),
    );
  }
}

class _CoverRadial extends StatelessWidget {
  const _CoverRadial({
    required this.coverColor,
    required this.center,
    required this.radius,
    required this.alpha,
  });

  final Color coverColor;
  final Alignment center;
  final double radius;
  final double alpha;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: center,
          radius: radius,
          colors: [coverColor.withValues(alpha: alpha), Colors.transparent],
          stops: const [0, 1],
        ),
      ),
    );
  }
}
