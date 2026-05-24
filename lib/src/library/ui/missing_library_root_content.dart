import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:smplayer_flutter/src/app/text_icon_button.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';

import 'default_album_artwork.dart';

class MissingLibraryRootContent extends StatelessWidget {
  const MissingLibraryRootContent({
    super.key,
    required this.onPickLibraryRoot,
    this.buttonLoading = false,
    this.buttonLabel,
    this.topPadding = 0,
  });

  final VoidCallback? onPickLibraryRoot;
  final bool buttonLoading;
  final String? buttonLabel;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final colors = MissingLibraryRootThemeColors.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth ? constraints.maxWidth : null;
        final height =
            constraints.hasBoundedHeight ? constraints.maxHeight : null;
        return SizedBox(
          width: width,
          height: height,
          child: Padding(
            padding: EdgeInsets.fromLTRB(24, topPadding, 24, 0),
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width:
                    width == null
                        ? null
                        : (width - 48).clamp(0, double.infinity),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: colors.border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 16,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 104,
                          height: 104,
                          margin: const EdgeInsets.only(bottom: 4),
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: colors.artworkBorder),
                            boxShadow: [
                              BoxShadow(
                                color: colors.artworkShadow,
                                offset: const Offset(0, 8),
                                blurRadius: 18,
                              ),
                            ],
                          ),
                          child: DefaultAlbumArtwork(
                            logoScale: 0.72,
                            logoOpacity: colors.artworkLogoOpacity,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          i18n.t('local.noRoot'),
                          style: TextStyle(
                            color: colors.textStrong,
                            fontSize: 26,
                            fontWeight: FontWeight.w600,
                            fontVariations: const [FontVariation.weight(650)],
                          ),
                        ),
                        const SizedBox(height: 20),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 760),
                          child: Text(
                            i18n.t('local.noRootCopy'),
                            style: TextStyle(
                              color: colors.textMuted,
                              fontSize: 14,
                              height: 1.65,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        _MissingLibraryRootButton(
                          onPressed: onPickLibraryRoot,
                          icon:
                              buttonLoading
                                  ? null
                                  : FluentIcons.folder_20_regular,
                          label: buttonLabel ?? i18n.t('library.chooseFolder'),
                          loading: buttonLoading,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MissingLibraryRootButton extends StatelessWidget {
  const _MissingLibraryRootButton({
    this.icon,
    required this.label,
    required this.onPressed,
    required this.loading,
  });

  final IconData? icon;
  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SmPlayerTextIconButton(
      icon: icon,
      label: label,
      loading: loading,
      onPressed: onPressed,
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
        controlHover: Color(0x1a0078d7),
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
        controlHover: Color(0x290078d7),
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
