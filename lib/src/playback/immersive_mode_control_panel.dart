import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smplayer_flutter/src/app/exit_fullscreen_icon.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/playback/media_control.dart';
import 'package:smplayer_flutter/src/playback/media_control_model.dart';
import 'package:smplayer_flutter/src/playback/media_control_provider.dart';
import 'package:smplayer_flutter/src/playback/immersive_mode_constants.dart';
import 'package:smplayer_flutter/src/playback/immersive_mode_theme.dart';

class ImmersiveModeControlPanel extends ConsumerWidget {
  const ImmersiveModeControlPanel({
    super.key,
    required this.song,
    required this.state,
    required this.disabled,
    required this.i18n,
    required this.night,
    required this.onPrevious,
    required this.onNext,
    required this.onTogglePlayPause,
    required this.onToggleShuffle,
    required this.onToggleFavorite,
    required this.onOpenVoiceAssistant,
    required this.onClose,
    required this.onMoreClick,
  });

  final LibrarySong? song;
  final MediaControlState state;
  final bool disabled;
  final SmPlayerI18n i18n;
  final bool night;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onTogglePlayPause;
  final VoidCallback onToggleShuffle;
  final VoidCallback? onToggleFavorite;
  final VoidCallback? onOpenVoiceAssistant;
  final VoidCallback onClose;
  final ValueChanged<BuildContext> onMoreClick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(mediaControlControllerProvider);
    final artworkPath = resolvePlayerArtworkPath(state.track, song);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth <= 520;
        final compactUtility = constraints.maxWidth <= 1200;
        final minimalUtility = constraints.maxWidth <= 800;
        final playerPadding = immersiveModePlayerPadding(constraints.maxWidth);
        final horizontalPadding = playerPadding.horizontal;
        final sideWidth = immersiveModePlayerSideWidth(
          constraints.maxWidth,
          contentWidth: constraints.maxWidth - horizontalPadding,
        );
        final transportDisabled = disabled || song?.id == null;
        final sliderColors = _ImmersiveModeSliderColors.forNight(night);
        return _NormalMediaControlTheme(
          night: night,
          child: MediaControlSurfaceBar(
            artworkPath: artworkPath,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(immersiveModePlayerTopRadius),
            ),
            padding: playerPadding,
            columnGap: immersiveModePlayerColumnGap(constraints.maxWidth),
            leadingWidth: sideWidth,
            utilityWidth: sideWidth,
            surfaceFlex: 1,
            leading: Align(
              alignment: Alignment.centerLeft,
              child: ImmersiveModeExitButton(
                minimal: minimalUtility,
                tooltip: i18n.t('nowPlaying.exitImmersiveMode'),
                onPressed: onClose,
              ),
            ),
            trackId: song?.id,
            isLoading: false,
            favorite: song?.favorite ?? state.track.favorite,
            disabled: transportDisabled,
            isPlaying: state.isPlaying,
            volume: state.volume,
            isMuted: state.isMuted,
            mode: state.mode,
            progressSeconds: state.progressSeconds,
            durationSeconds: resolvePlayerDurationSeconds(
              state.durationSeconds,
              song,
            ),
            previousButtonRestartsTrack: false,
            onTogglePlayPause: onTogglePlayPause,
            onPrevious: onPrevious,
            onNext: onNext,
            onSeek: controller.onSeek,
            onBeginSeek: controller.onBeginSeek,
            onEndSeek: controller.onEndSeek,
            onVolumeChange: controller.onVolumeChange,
            onToggleMute: controller.onToggleMute,
            onToggleShuffle: onToggleShuffle,
            onToggleRepeat: controller.onToggleRepeat,
            onToggleRepeatOne: controller.onToggleRepeatOne,
            onToggleFavorite: onToggleFavorite ?? controller.onToggleFavorite,
            onOpenVoiceAssistant: onOpenVoiceAssistant,
            condensed: compact,
            navMinimal: minimalUtility,
            utilityCondensed: compactUtility,
            utilityMinimal: minimalUtility,
            sliderActiveColor: sliderColors.progressActive,
            sliderInactiveColor: sliderColors.progressInactive,
            sliderThumbColor: Colors.white,
            sliderThumbShadow: sliderColors.progressThumbShadow,
            sliderOverlayColor: Colors.transparent,
            volumeSliderActiveColor: sliderColors.volumeActive,
            volumeSliderInactiveColor: sliderColors.volumeInactive,
            volumeSliderThumbColor: MediaControlColors.accent,
            volumeSliderThumbShadow: const BoxShadow(
              color: Color(0x47000000),
              offset: Offset(0, 1),
              blurRadius: 4,
            ),
            volumeSliderOverlayColor: Colors.transparent,
            preserveWideBackground: true,
            onMoreClick: onMoreClick,
          ),
        );
      },
    );
  }
}

class _ImmersiveModeSliderColors {
  const _ImmersiveModeSliderColors({
    required this.progressActive,
    required this.progressInactive,
    required this.progressThumbShadow,
    required this.volumeActive,
    required this.volumeInactive,
  });

  final Color progressActive;
  final Color progressInactive;
  final BoxShadow progressThumbShadow;
  final Color volumeActive;
  final Color volumeInactive;

  static const day = _ImmersiveModeSliderColors(
    progressActive: Color(0xc25b697a),
    progressInactive: Color(0x2e5b697a),
    progressThumbShadow: BoxShadow(
      color: Color(0x52445870),
      offset: Offset(0, 1),
      blurRadius: 8,
    ),
    volumeActive: Color(0xeb0078d7),
    volumeInactive: Color(0x2e323e4e),
  );

  static const night = _ImmersiveModeSliderColors(
    progressActive: Color(0xdbffffff),
    progressInactive: Color(0x33ffffff),
    progressThumbShadow: BoxShadow(
      color: Color(0x61000000),
      offset: Offset(0, 1),
      blurRadius: 8,
    ),
    volumeActive: Color(0xf20078d7),
    volumeInactive: Color(0x2ecbd5e1),
  );

  static _ImmersiveModeSliderColors forNight(bool night) {
    return switch (night) {
      true => _ImmersiveModeSliderColors.night,
      false => day,
    };
  }
}

class _NormalMediaControlTheme extends StatelessWidget {
  const _NormalMediaControlTheme({required this.night, required this.child});

  final bool night;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final normalColors = switch (night) {
      true => MediaControlThemeColors.dark,
      false => MediaControlThemeColors.light,
    };
    return Theme(
      data: theme.copyWith(
        extensions: [
          for (final extension in theme.extensions.values)
            if (extension is! MediaControlThemeColors) extension,
          normalColors,
        ],
      ),
      child: child,
    );
  }
}

EdgeInsets immersiveModePlayerPadding(double viewportWidth) {
  if (viewportWidth <= 520) {
    return const EdgeInsets.fromLTRB(12, 9, 12, 11);
  }
  if (viewportWidth <= immersiveModeImmersiveCompactBreakpoint) {
    return const EdgeInsets.fromLTRB(16, 8, 16, 10);
  }
  return const EdgeInsets.symmetric(horizontal: 16, vertical: 10);
}

double immersiveModePlayerColumnGap(double viewportWidth) {
  if (viewportWidth <= 520) {
    return 8;
  }
  if (viewportWidth <= immersiveModeImmersiveCompactBreakpoint) {
    return 10;
  }
  return 0;
}

double immersiveModePlayerSideWidth(
  double viewportWidth, {
  required double contentWidth,
}) {
  if (viewportWidth <= 520) {
    return 68;
  }
  if (viewportWidth <= immersiveModeImmersiveCompactBreakpoint) {
    return 80;
  }

  final minSide =
      viewportWidth <= 1200 ? clampDouble(viewportWidth * 0.24, 200, 280) : 280;
  final minCenter =
      viewportWidth <= 1200 ? clampDouble(viewportWidth * 0.40, 280, 420) : 420;
  final extra = max(0.0, contentWidth - minCenter - minSide * 2);
  return minSide + extra * 0.9 / 2.8;
}

class ImmersiveModeExitButton extends StatefulWidget {
  const ImmersiveModeExitButton({
    super.key,
    required this.minimal,
    required this.tooltip,
    required this.onPressed,
  });

  final bool minimal;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  State<ImmersiveModeExitButton> createState() =>
      ImmersiveModeExitButtonState();
}

class ImmersiveModeExitButtonState extends State<ImmersiveModeExitButton> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final colors = ImmersiveModeThemeColors.of(context);
    final dark = colors.artworkShadowOpacity > 0.3;
    final active = _hovered || _focused;
    final size = widget.minimal ? 68.0 : 72.0;
    final shellBorderColor =
        dark
            ? active
                ? const Color(0x2effffff)
                : const Color(0x1fffffff)
            : active
            ? const Color(0x14212b3a)
            : Colors.transparent;
    final iconColor =
        dark
            ? active
                ? Colors.white
                : const Color(0xe6ffffff)
            : const Color(0xe6080c12);
    return Tooltip(
      message: widget.tooltip,
      child: TextButton(
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          backgroundColor: Colors.transparent,
          foregroundColor: iconColor,
        ),
        onHover: (value) {
          setState(() {
            _hovered = value;
          });
        },
        onFocusChange: (value) {
          setState(() {
            _focused = value;
          });
        },
        onPressed: widget.onPressed,
        child: AnimatedContainer(
          key: const ValueKey('ImmersiveMode.ExitArtworkShell'),
          duration: const Duration(milliseconds: 140),
          curve: Curves.ease,
          width: size,
          height: size,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: shellBorderColor),
            color:
                dark
                    ? active
                        ? const Color(0x24ffffff)
                        : const Color(0x14ffffff)
                    : active
                    ? const Color(0x1f212b3a)
                    : Colors.transparent,
            gradient:
                dark && !active
                    ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0x1fffffff), Color(0x0affffff)],
                    )
                    : null,
            boxShadow:
                dark
                    ? [
                      BoxShadow(
                        color:
                            active
                                ? const Color(0x4d000000)
                                : const Color(0x57000000),
                        blurRadius: active ? 30 : 28,
                        offset: const Offset(0, 12),
                      ),
                    ]
                    : null,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (dark)
                const ColoredBox(
                  key: ValueKey('ImmersiveMode.ExitAlbumSwatch'),
                  color: Colors.transparent,
                ),
              if (dark)
                BackdropFilter(
                  key: const ValueKey('ImmersiveMode.ExitArtworkBackdrop'),
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: ImmersiveModeExitOverlay(
                    color: const Color(0x6b080c12),
                    iconColor: iconColor,
                    shadows: const [
                      Shadow(
                        color: Color(0x57000000),
                        offset: Offset(0, 2),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                )
              else
                ImmersiveModeExitOverlay(
                  color: Colors.transparent,
                  iconColor: iconColor,
                  shadows: const [],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class ImmersiveModeExitOverlay extends StatelessWidget {
  const ImmersiveModeExitOverlay({
    super.key,
    required this.color,
    required this.iconColor,
    required this.shadows,
  });

  final Color color;
  final Color iconColor;
  final List<Shadow> shadows;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const ValueKey('ImmersiveMode.ExitArtworkOverlay'),
      decoration: BoxDecoration(color: color),
      child: Center(
        child: ExitFullscreenIcon(
          key: const ValueKey('ImmersiveMode.ExitIcon'),
          size: 36,
          color: iconColor,
          strokeWidth: 2,
          shadows: shadows,
        ),
      ),
    );
  }
}

class ImmersiveModeErrorBanner extends StatelessWidget {
  const ImmersiveModeErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(minHeight: 38),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0x6b5c0c14),
          border: Border.all(color: const Color(0x47ff7373)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          message,
          style: const TextStyle(
            color: Color(0xf0ffebeb),
            fontSize: 14,
            fontWeight: FontWeight.w600,
            height: 1.28,
          ),
        ),
      ),
    );
  }
}
