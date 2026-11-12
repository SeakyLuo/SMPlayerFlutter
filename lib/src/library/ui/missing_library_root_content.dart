import 'dart:io';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:smplayer_flutter/src/app/app_interaction_colors.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';

import '../../remote/music_share_dialog.dart';
import 'popup_dialog.dart';

class MissingLibraryRootContent extends StatelessWidget {
  const MissingLibraryRootContent({
    super.key,
    required this.onPickLibraryRoot,
    this.buttonLoading = false,
    this.buttonLabel,
  });

  final VoidCallback? onPickLibraryRoot;
  final bool buttonLoading;
  final String? buttonLabel;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final colors = MissingLibraryRootThemeColors.of(context);
    final mobile = Platform.isAndroid || Platform.isIOS;
    final buttonHeight = mobile ? 48.0 : 40.0;

    return LayoutBuilder(
      builder:
          (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          FluentIcons.folder_48_regular,
                          size: 56,
                          color: colors.textMuted,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          i18n.t('local.noRoot'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: colors.textStrong,
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          i18n.t('local.noRootCopy'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: colors.textMuted,
                            fontSize: 14,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 24),
                        PopupDialogActionButton(
                          label: buttonLabel ?? i18n.t('library.chooseFolder'),
                          icon: FluentIcons.folder_20_regular,
                          primary: true,
                          height: buttonHeight,
                          loading: buttonLoading,
                          onPressed: onPickLibraryRoot,
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => showMusicShareDialog(context),
                          style: TextButton.styleFrom(
                            minimumSize: Size(48, buttonHeight),
                          ),
                          child: Text(i18n.t('share.connectComputer')),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
    );
  }
}

class MissingLibraryRootThemeColors
    extends ThemeExtension<MissingLibraryRootThemeColors> {
  const MissingLibraryRootThemeColors({
    required this.surface,
    required this.border,
    required this.artworkBorder,
    required this.artworkShadow,
    required this.artworkLogoOpacity,
    required this.textStrong,
    required this.textMuted,
    required this.commandText,
    required this.control,
    required this.controlHover,
    required this.controlBorder,
    required this.cardShadow,
    required this.accentStrong,
  });

  final Color surface;
  final Color border;
  final Color artworkBorder;
  final Color artworkShadow;
  final double artworkLogoOpacity;
  final Color textStrong;
  final Color textMuted;
  final Color commandText;
  final Color control;
  final Color controlHover;
  final Color controlBorder;
  final Color cardShadow;
  final Color accentStrong;

  static const MissingLibraryRootThemeColors day =
      MissingLibraryRootThemeColors(
        surface: Color(0x94ffffff),
        border: Color(0x94ffffff),
        artworkBorder: Color(0x2e768499),
        artworkShadow: Color(0x21202d3f),
        artworkLogoOpacity: 0.82,
        textStrong: Color(0xff1f252b),
        textMuted: Color(0xff5f625f),
        commandText: Color(0xff1f252b),
        control: Color(0x94ffffff),
        controlHover: SmPlayerInteractionColors.hoverSurface,
        controlBorder: Color(0x2e768499),
        cardShadow: Color(0x1f1e2a3a),
        accentStrong: Color(0xff0063b1),
      );

  static const MissingLibraryRootThemeColors night =
      MissingLibraryRootThemeColors(
        surface: Color(0x0cffffff),
        border: Color(0x1fd6e0ec),
        artworkBorder: Color(0x1fd6e0ec),
        artworkShadow: Color(0x4d000000),
        artworkLogoOpacity: 0.72,
        textStrong: Color(0xf0f6f9fc),
        textMuted: Color(0xadcbd5e1),
        commandText: Color(0xf0f6f9fc),
        control: Color(0x0effffff),
        controlHover: SmPlayerInteractionColors.hoverSurfaceDark,
        controlBorder: Color(0x1fd6e0ec),
        cardShadow: Color(0x3d000000),
        accentStrong: Color(0xff0063b1),
      );

  static MissingLibraryRootThemeColors of(BuildContext context) {
    return Theme.of(context).extension<MissingLibraryRootThemeColors>()!;
  }

  @override
  MissingLibraryRootThemeColors copyWith() {
    return this;
  }

  @override
  MissingLibraryRootThemeColors lerp(
    ThemeExtension<MissingLibraryRootThemeColors>? other,
    double t,
  ) {
    return t < 0.5 || other is! MissingLibraryRootThemeColors ? this : other;
  }
}
