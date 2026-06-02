import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/playback/now_playing_full_constants.dart';
import 'package:smplayer_flutter/src/playback/now_playing_full_theme.dart';

class NowPlayingFullAppBar extends StatelessWidget {
  const NowPlayingFullAppBar({
    super.key,
    required this.i18n,
    required this.playlistOpen,
    required this.onClose,
    required this.onTogglePlaylist,
  });

  final SmPlayerI18n i18n;
  final bool playlistOpen;
  final VoidCallback onClose;
  final VoidCallback onTogglePlaylist;

  @override
  Widget build(BuildContext context) {
    final colors = NowPlayingFullThemeColors.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            MediaQuery.sizeOf(context).width <=
            nowPlayingFullLayoutCompactBreakpoint;
        final night = colors.artworkShadowOpacity > 0.3;
        return SizedBox(
          height: compact ? 92 : 118,
          child: Stack(
            children: [
              if (compact)
                Positioned(
                  top: 42,
                  left: 24,
                  child: NowPlayingFullCompactTopButton(
                    tooltip: i18n.t('sidebar.back'),
                    padding: EdgeInsets.zero,
                    width: 38,
                    colors: colors,
                    onPressed: onClose,
                    child: const Icon(
                      FluentIcons.arrow_left_24_regular,
                      key: ValueKey('NowPlayingFull.BackIcon'),
                      size: 16,
                    ),
                  ),
                ),
              Positioned(
                top: compact ? 42 : 62,
                right: compact ? 24 : 76,
                child:
                    compact
                        ? NowPlayingFullCompactTopButton(
                          colors: colors,
                          active: playlistOpen,
                          tooltip: i18n.t('common.nowPlaying'),
                          padding: const EdgeInsets.fromLTRB(14, 0, 18, 0),
                          onPressed: onTogglePlaylist,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                FluentIcons.music_note_2_20_regular,
                                key: ValueKey('NowPlayingFull.QueueIcon'),
                                size: 16,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                key: const ValueKey(
                                  'NowPlayingFull.QueueLabel',
                                ),
                                i18n.t('common.nowPlaying'),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        )
                        : TextButton.icon(
                          style: TextButton.styleFrom(
                            minimumSize: const Size(0, 44),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            foregroundColor:
                                playlistOpen
                                    ? colors.topButtonActiveForeground
                                    : colors.topButtonForeground,
                            backgroundColor:
                                playlistOpen
                                    ? (colors.artworkShadowOpacity > 0.3
                                        ? const Color(0x24ffffff)
                                        : const Color(0xdbffffff))
                                    : colors.topButtonBackground,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color:
                                    night
                                        ? const Color(0x29ffffff)
                                        : const Color(0x337e8b9a),
                              ),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          icon: const Icon(
                            FluentIcons.music_note_2_20_regular,
                            key: ValueKey('NowPlayingFull.QueueIcon'),
                            size: 18,
                          ),
                          label: Text(
                            key: const ValueKey('NowPlayingFull.QueueLabel'),
                            i18n.t('common.nowPlaying'),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          onPressed: onTogglePlaylist,
                        ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class NowPlayingFullCompactTopButton extends StatelessWidget {
  const NowPlayingFullCompactTopButton({
    super.key,
    required this.colors,
    required this.tooltip,
    required this.padding,
    required this.onPressed,
    required this.child,
    this.active = false,
    this.width,
  });

  final NowPlayingFullThemeColors colors;
  final String tooltip;
  final EdgeInsetsGeometry padding;
  final VoidCallback onPressed;
  final Widget child;
  final bool active;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final night = colors.artworkShadowOpacity > 0.3;
    final foreground =
        active ? colors.topButtonActiveForeground : colors.topButtonForeground;
    final glassColor =
        night
            ? (active ? const Color(0x30ffffff) : const Color(0x1cffffff))
            : (active ? const Color(0xccffffff) : const Color(0x86ffffff));
    return Tooltip(
      message: tooltip,
      child: GlassContainer(
        key: ValueKey('NowPlayingFull.TopButtonGlass.$tooltip'),
        useOwnLayer: true,
        quality: GlassQuality.minimal,
        shape: const LiquidRoundedRectangle(borderRadius: 12),
        settings: LiquidGlassSettings(
          blur: 46,
          thickness: active ? 22 : 20,
          refractiveIndex: 1.06,
          saturation: 1.65,
          chromaticAberration: 0,
          lightIntensity: 0.1,
          ambientStrength: 0.08,
          glowIntensity: active ? 0.08 : 0.04,
          glassColor: glassColor,
          standardOpacityMultiplier: night ? 0.35 : 0.28,
        ),
        clipBehavior: Clip.hardEdge,
        allowElevation: false,
        child: SizedBox(
          width: width,
          height: 38,
          child: TextButton(
            style: TextButton.styleFrom(
              minimumSize: Size.zero,
              padding: padding,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: foreground,
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            onPressed: onPressed,
            child: IconTheme.merge(
              data: IconThemeData(color: foreground, size: 16),
              child: DefaultTextStyle.merge(
                style: TextStyle(color: foreground),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
