import 'dart:io';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:smplayer_flutter/src/app/shell_models.dart';
import 'package:smplayer_flutter/src/app/text_icon_button.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/playback/immersive_mode_theme.dart';
import 'package:smplayer_flutter/src/playback/immersive_mode_top_button_style.dart';

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
    final topButtonColors = immersiveModeTopButtonColors(
      context,
      immersiveColors,
    );
    final glassSettings = immersiveModeTopButtonGlassSettingsFor(
      immersiveColors,
    );
    final desktopTitlebarInset =
        Platform.isMacOS || Platform.isWindows
            ? SmPlayerShellMetrics.minimalTitlebarHeight
            : MediaQuery.viewPaddingOf(context).top;
    final top =
        desktopTitlebarInset +
        (Platform.isMacOS || Platform.isWindows ? 30 : 18);
    return SizedBox(
      width: double.infinity,
      height: top + 56,
      child: Stack(
        children: [
          Positioned(
            top: top,
            left: 76,
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
            top: top,
            right: 76,
            child: SmPlayerTextIconButtonTheme(
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
  }
}
