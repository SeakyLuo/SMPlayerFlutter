import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:smplayer_flutter/src/playback/media_control.dart';
import 'package:smplayer_flutter/src/playback/now_playing_full_theme.dart';

class NowPlayingFullScaffold extends StatelessWidget {
  const NowPlayingFullScaffold({
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
    final colors = NowPlayingFullThemeColors.of(context, night: night);
    final theme = Theme.of(context);
    final mediaControlColors = (night
            ? MediaControlThemeColors.dark
            : MediaControlThemeColors.light)
        .copyWith(
          textMuted:
              night ? const Color(0xa8ffffff) : MediaControlColors.textMuted,
          primaryButtonBorder:
              night ? const Color(0x6b0078d7) : Colors.transparent,
          primaryButtonHover: MediaControlColors.accentStrong,
          disabledPrimaryButtonSurface: MediaControlColors.accent,
          primaryButtonShadow: BoxShadow(
            color:
                night
                    ? const Color(0x52000000)
                    : MediaControlColors.accentShadow,
            offset: const Offset(0, 12),
            blurRadius: 26,
          ),
          buttonForeground:
              night ? const Color(0xf0f6f9fc) : MediaControlColors.textStrong,
          buttonHoverForeground:
              night ? Colors.white : MediaControlColors.accentStrong,
          buttonHoverBackground:
              night ? const Color(0x2e0078d7) : const Color(0x1a0078d7),
          buttonActiveBackground:
              night ? const Color(0x380078d7) : const Color(0x1a0078d7),
          favoriteActiveHoverBackground:
              night ? const Color(0x38ffffff) : const Color(0x1a0078d7),
          volumeTooltipBackground: const Color(0xe014181e),
          volumeTooltipForeground: Colors.white,
          volumeTooltipBorder: const Color(0x2effffff),
          volumeTooltipShadow: const BoxShadow(
            color: Color(0x57000000),
            offset: Offset(0, 10),
            blurRadius: 24,
          ),
          playerBorder:
              night ? const Color(0x1fd6e0ec) : const Color(0xb8ccd5e0),
          compactPlayerBorder:
              night ? const Color(0x1fd6e0ec) : const Color(0xb8ccd5e0),
          playerShadow:
              night ? const Color(0x57000000) : const Color(0x24445870),
          compactPlayerShadow:
              night ? const Color(0x57000000) : const Color(0x24445870),
          wideShadowOffsetY: -18,
          wideShadowBlur: night ? 48 : 56,
          compactShadowOffsetY: night ? -12 : -18,
          compactShadowBlur: night ? 36 : 56,
          glassBlur: night ? 28 : 18,
          glassSaturation: night ? 1 : 1.4,
          compactGlassBlur: night ? 28 : 18,
          compactGlassSaturation: night ? 1.45 : 1.4,
          coverWashAlpha: night ? 0.22 : 0.24,
          compactCoverWashAlpha: night ? 0.2 : 0.24,
          wideSurface:
              night ? const Color(0xe611161c) : const Color(0xc7ffffff),
          compactSurface:
              night ? const Color(0xeb101419) : const Color(0xc7ffffff),
          compactWashEnd: night ? const Color(0xc711161c) : Colors.transparent,
          compactWashStop: night ? 0.56 : 0.42,
          compactBaseGradient:
              night ? const [Color(0xe01d232b), Color(0xe0101419)] : null,
          coverWashMode: night ? null : MediaControlCoverWashMode.radial,
          coverWashAlignment: night ? null : const Alignment(-0.6, -0.56),
          coverWashRadius: night ? null : 0.42,
          wideHighlightGradient:
              night ? const [Color(0x0effffff), Color(0x1f0078d7)] : null,
          wideHighlightStops: null,
          wideInsetHighlight:
              night ? const Color(0x0cffffff) : const Color(0xc7ffffff),
          compactInsetHighlight:
              night ? const Color(0x0cffffff) : const Color(0xc7ffffff),
        );
    final scopedTheme = theme.copyWith(
      extensions: [
        for (final extension in theme.extensions.values)
          if (extension is! NowPlayingFullThemeColors &&
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
          const _NowPlayingFullNightArtworkShade()
        else
          _NowPlayingFullDayBackdropTint(coverColor: coverColor),
        if (!night) _NowPlayingFullDayCoverGlow(coverColor: coverColor),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: colors.backdropOverlay),
          ),
        ),
        if (night) const _NowPlayingFullNightWarmOverlay(),
        if (!night) _NowPlayingFullDayWashOverlay(coverColor: coverColor),
        Theme(data: scopedTheme, child: child),
      ],
    );
  }
}

class _NowPlayingFullDayBackdropTint extends StatelessWidget {
  const _NowPlayingFullDayBackdropTint({required this.coverColor});

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

class _NowPlayingFullNightArtworkShade extends StatelessWidget {
  const _NowPlayingFullNightArtworkShade();

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

class _NowPlayingFullDayCoverGlow extends StatelessWidget {
  const _NowPlayingFullDayCoverGlow({required this.coverColor});

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

class _NowPlayingFullDayWashOverlay extends StatelessWidget {
  const _NowPlayingFullDayWashOverlay({required this.coverColor});

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

class _NowPlayingFullNightWarmOverlay extends StatelessWidget {
  const _NowPlayingFullNightWarmOverlay();

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
