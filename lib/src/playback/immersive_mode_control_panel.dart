import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smplayer_flutter/src/app/exit_fullscreen_icon.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/playback/media_control.dart';
import 'package:smplayer_flutter/src/playback/media_control_provider.dart';
import 'package:smplayer_flutter/src/playback/immersive_mode_constants.dart';
import 'package:smplayer_flutter/src/playback/immersive_mode_theme.dart';

class ImmersiveModeControlPanel extends ConsumerWidget {
  const ImmersiveModeControlPanel({
    super.key,
    required this.song,
    required this.disabled,
    required this.i18n,
    required this.night,
    required this.onPrevious,
    required this.onNext,
    required this.onTogglePlayPause,
    required this.onQuickPlay,
    required this.onToggleShuffle,
    required this.onToggleFavorite,
    required this.desktopLyricsEnabled,
    required this.onToggleDesktopLyrics,
    required this.onOpenVoiceAssistant,
    required this.onToggleWindowFullScreen,
    required this.isWindowFullScreen,
    required this.onEnterMiniMode,
    required this.onClose,
    required this.onMoreClick,
  });

  final LibrarySong? song;
  final bool disabled;
  final SmPlayerI18n i18n;
  final bool night;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onTogglePlayPause;
  final VoidCallback onQuickPlay;
  final VoidCallback onToggleShuffle;
  final VoidCallback? onToggleFavorite;
  final bool desktopLyricsEnabled;
  final VoidCallback? onToggleDesktopLyrics;
  final VoidCallback? onOpenVoiceAssistant;
  final VoidCallback? onToggleWindowFullScreen;
  final bool isWindowFullScreen;
  final VoidCallback? onEnterMiniMode;
  final VoidCallback onClose;
  final ValueChanged<BuildContext> onMoreClick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(
      mediaControlControllerProvider.select(
        (controller) => (
          track: controller.state.track,
          isPlaying: controller.state.isPlaying,
          volume: controller.state.volume,
          isMuted: controller.state.isMuted,
          mode: controller.state.mode,
          durationSeconds: controller.state.durationSeconds,
        ),
      ),
    );
    final controller = ref.read(mediaControlControllerProvider);
    final artworkPath = resolvePlayerArtworkPath(state.track, song);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth <= 520;
        final compactUtility = constraints.maxWidth <= 1200;
        final minimalUtility = constraints.maxWidth <= 800;
        final playerPadding = immersiveModePlayerPadding(constraints.maxWidth);
        final sideWidth = immersiveModePlayerSideWidth(
          constraints.maxWidth,
          contentWidth: constraints.maxWidth - playerPadding.horizontal,
        );
        final emptySong = song?.id == null;
        final transportDisabled = disabled || emptySong;
        final sliderColors = MediaControlSliderColors.forNight(night);
        Widget buildExitLeading(BuildContext context, bool compact) {
          return Align(
            alignment: Alignment.centerLeft,
            child: MediaControlTrackInfo(
              track: state.track,
              artworkPath: artworkPath,
              disabled: false,
              compact: compact,
              showTrackCopy: false,
              showSurfaceFeedback: false,
              decorateSquareAsArtwork: false,
              tooltip: i18n.t('nowPlaying.exitImmersiveMode'),
              onPressed: onClose,
              squareBuilder: (context, active, size) {
                return ImmersiveModeExitSquare(active: active);
              },
            ),
          );
        }

        if (minimalUtility) {
          return _NormalMediaControlTheme(
            night: night,
            child: MediaControl(
              track: state.track,
              currentSong: song,
              disabled: transportDisabled,
              isPlaying: state.isPlaying,
              volume: state.volume,
              isMuted: state.isMuted,
              mode: state.mode,
              progressSeconds: controller.state.progressSeconds,
              durationSeconds: resolvePlayerDurationSeconds(
                state.durationSeconds,
                song,
              ),
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
              desktopLyricsEnabled: desktopLyricsEnabled,
              onToggleDesktopLyrics: onToggleDesktopLyrics,
              onQuickPlay: onQuickPlay,
              onOpenNowPlaying: onClose,
              onToggleWindowFullScreen: onToggleWindowFullScreen,
              isWindowFullScreen: isWindowFullScreen,
              onEnterMiniMode: onEnterMiniMode,
              onOpenVoiceAssistant: onOpenVoiceAssistant,
              leadingBuilder: buildExitLeading,
              onMoreClick: onMoreClick,
            ),
          );
        }
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
            leading: buildExitLeading(context, false),
            trackId: song?.id,
            isLoading: false,
            favorite: song?.favorite ?? state.track.favorite,
            disabled: transportDisabled,
            isPlaying: state.isPlaying,
            volume: state.volume,
            isMuted: state.isMuted,
            mode: state.mode,
            progressSeconds: controller.state.progressSeconds,
            durationSeconds: resolvePlayerDurationSeconds(
              state.durationSeconds,
              song,
            ),
            previousButtonRestartsTrack: false,
            onTogglePlayPause: onTogglePlayPause,
            playButtonDisabled: emptySong ? false : null,
            playButtonTooltip:
                emptySong ? i18n.t('nowPlaying.quickPlay') : null,
            onPlayButtonPressed: emptySong ? onQuickPlay : null,
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
            desktopLyricsEnabled: desktopLyricsEnabled,
            onToggleDesktopLyrics: onToggleDesktopLyrics,
            onOpenVoiceAssistant: onOpenVoiceAssistant,
            condensed: compact,
            navMinimal: minimalUtility,
            utilityCondensed: compactUtility,
            utilityMinimal: minimalUtility,
            sliderActiveColor: sliderColors.progressActive,
            sliderInactiveColor: sliderColors.progressInactive,
            sliderThumbColor: sliderColors.progressThumb,
            sliderThumbShadow: sliderColors.progressThumbShadow,
            sliderOverlayColor: Colors.transparent,
            volumeSliderActiveColor: sliderColors.volumeActive,
            volumeSliderInactiveColor: sliderColors.volumeInactive,
            volumeSliderThumbColor: sliderColors.volumeThumb,
            volumeSliderThumbShadow: MediaControlSliderColors.volumeThumbShadow,
            volumeSliderOverlayColor: Colors.transparent,
            preserveWideBackground: true,
            onMoreClick: onMoreClick,
          ),
        );
      },
    );
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
  return mediaControlPlayerPadding(viewportWidth);
}

double immersiveModePlayerColumnGap(double viewportWidth) {
  return mediaControlPlayerColumnGap(viewportWidth);
}

double immersiveModePlayerSideWidth(
  double viewportWidth, {
  required double contentWidth,
}) {
  return mediaControlPlayerSideWidth(viewportWidth, contentWidth: contentWidth);
}

class ImmersiveModeExitSquare extends StatelessWidget {
  const ImmersiveModeExitSquare({super.key, required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final colors = ImmersiveModeThemeColors.of(context);
    final dark = colors.artworkShadowOpacity > 0.3;
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
    return AnimatedContainer(
      key: const ValueKey('ImmersiveMode.ExitArtworkShell'),
      duration: const Duration(milliseconds: 140),
      curve: Curves.ease,
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
