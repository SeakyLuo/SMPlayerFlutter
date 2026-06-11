import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:smplayer_flutter/src/app/text_icon_button.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/playback/immersive_mode_constants.dart';
import 'package:smplayer_flutter/src/playback/immersive_mode_theme.dart';

class ImmersiveModeAppBar extends StatelessWidget {
  const ImmersiveModeAppBar({
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
    final immersiveColors = ImmersiveModeThemeColors.of(context);
    final night =
        immersiveColors.pageBackground ==
        ImmersiveModeThemeColors.dark.pageBackground;
    final topButtonColors =
        night
            ? SmPlayerTextIconButtonColors.of(context).copyWith(
              commandText: const Color(0xe0ffffff),
              commandTextHover: Colors.white,
              accentStrong: Colors.white,
              control: const Color(0x14ffffff),
              controlHover: const Color(0x24ffffff),
              controlActive: const Color(0x24ffffff),
              controlBorder: const Color(0x29ffffff),
              controlHoverBorder: const Color(0x29ffffff),
            )
            : SmPlayerTextIconButtonColors.of(context).copyWith(
              control: const Color(0x18ffffff),
              controlHover: const Color(0x2effffff),
              controlActive: const Color(0x36ffffff),
              controlBorder: const Color(0x2effffff),
              controlHoverBorder: const Color(0x52ffffff),
            );
    final glassSettings =
        night
            ? immersiveModeTopButtonNightGlassSettings
            : immersiveModeTopButtonGlassSettings;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            MediaQuery.sizeOf(context).width <=
            immersiveModeLayoutCompactBreakpoint;
        return SizedBox(
          height: compact ? 92 : 118,
          child: Stack(
            children: [
              if (compact)
                Positioned(
                  top: 42,
                  left: 24,
                  child: SmPlayerTextIconButtonTheme(
                    colors: topButtonColors,
                    child: SmPlayerTextIconButton(
                      tooltip: i18n.t('sidebar.back'),
                      label: i18n.t('sidebar.back'),
                      tooltipEnabled: false,
                      showLabel: false,
                      borderRadius: 12,
                      glassSettings: glassSettings,
                      onPressed: onClose,
                      iconWidget: const Icon(
                        FluentIcons.arrow_left_24_regular,
                        key: ValueKey('ImmersiveMode.BackIcon'),
                      ),
                    ),
                  ),
                ),
              Positioned(
                top: compact ? 42 : 62,
                right: compact ? 24 : 76,
                child:
                    compact
                        ? SmPlayerTextIconButtonTheme(
                          colors: topButtonColors,
                          child: SmPlayerTextIconButton(
                            active: playlistOpen,
                            tooltip: i18n.t('common.nowPlaying'),
                            label: i18n.t('common.nowPlaying'),
                            tooltipEnabled: false,
                            borderRadius: 12,
                            glassSettings: glassSettings,
                            onPressed: onTogglePlaylist,
                            iconWidget: const Icon(
                              FluentIcons.music_note_2_20_regular,
                              key: ValueKey('ImmersiveMode.QueueIcon'),
                            ),
                            child: Text(
                              key: const ValueKey('ImmersiveMode.QueueLabel'),
                              i18n.t('common.nowPlaying'),
                            ),
                          ),
                        )
                        : SmPlayerTextIconButtonTheme(
                          colors: topButtonColors,
                          child: SmPlayerTextIconButton(
                            active: playlistOpen,
                            tooltip: i18n.t('common.nowPlaying'),
                            label: i18n.t('common.nowPlaying'),
                            tooltipEnabled: false,
                            borderRadius: 12,
                            glassSettings: glassSettings,
                            onPressed: onTogglePlaylist,
                            iconWidget: const Icon(
                              FluentIcons.music_note_2_20_regular,
                              key: ValueKey('ImmersiveMode.QueueIcon'),
                            ),
                            child: Text(
                              key: const ValueKey('ImmersiveMode.QueueLabel'),
                              i18n.t('common.nowPlaying'),
                            ),
                          ),
                        ),
              ),
            ],
          ),
        );
      },
    );
  }
}
