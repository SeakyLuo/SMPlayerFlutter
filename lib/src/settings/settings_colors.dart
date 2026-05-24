import 'package:flutter/material.dart';
import 'package:smplayer_flutter/src/app/app_interaction_colors.dart';

class SettingsPageColors {
  const SettingsPageColors._();

  static const textStrong = Color(0xff1f252b);
  static const textMuted = Color(0xff5f625f);
  static const accent = Color(0xff0078d7);
  static const accentStrong = Color(0xff0063b1);
  static const accentHover = SmPlayerInteractionColors.hoverSurface;
  static const cardSurface = Color(0x9effffff);
  static const cardBorder = Color(0x9eccd5e0);
  static const cardShadow = Color(0x14445870);
  static const inputSurface = Color(0xf4ffffff);
  static const inputBorder = Color(0x387e8b9a);
  static const selectOpenSurface = SmPlayerInteractionColors.hoverSurface;
  static const selectOpenBorder = Color(0x570078d7);
  static const dropdownSurface = Color(0xfaffffff);
  static const dropdownShadow = Color(0x2e263344);
  static const colorSwatchInset = Color(0xb8ffffff);
  static const buttonSurface = Color(0xb8ffffff);
  static const dialogSurface = Color(0xfffbfdff);
  static const overlay = Color(0x47202b36);
  static const preferenceHeader = Color(0x7affffff);
  static const danger = Color(0xffb42318);

  static SettingsPalette of(BuildContext context) {
    return Theme.of(context).extension<SettingsPalette>() ??
        SettingsPalette.light;
  }
}

class SettingsPalette extends ThemeExtension<SettingsPalette> {
  const SettingsPalette({
    required this.textStrong,
    required this.textMuted,
    required this.accent,
    required this.accentStrong,
    required this.accentHover,
    required this.cardSurface,
    required this.cardBorder,
    required this.cardShadow,
    required this.inputSurface,
    required this.inputBorder,
    required this.selectOpenSurface,
    required this.selectOpenBorder,
    required this.dropdownSurface,
    required this.dropdownShadow,
    required this.colorSwatchInset,
    required this.buttonSurface,
    required this.progressPanelSurface,
    required this.progressPanelBorder,
    required this.progressTrack,
    required this.dialogSurface,
    required this.overlay,
    required this.preferenceHeader,
  });

  static const light = SettingsPalette(
    textStrong: SettingsPageColors.textStrong,
    textMuted: SettingsPageColors.textMuted,
    accent: SettingsPageColors.accent,
    accentStrong: SettingsPageColors.accentStrong,
    accentHover: SettingsPageColors.accentHover,
    cardSurface: SettingsPageColors.cardSurface,
    cardBorder: SettingsPageColors.cardBorder,
    cardShadow: SettingsPageColors.cardShadow,
    inputSurface: SettingsPageColors.inputSurface,
    inputBorder: SettingsPageColors.inputBorder,
    selectOpenSurface: SettingsPageColors.selectOpenSurface,
    selectOpenBorder: SettingsPageColors.selectOpenBorder,
    dropdownSurface: SettingsPageColors.dropdownSurface,
    dropdownShadow: SettingsPageColors.dropdownShadow,
    colorSwatchInset: SettingsPageColors.colorSwatchInset,
    buttonSurface: SettingsPageColors.buttonSurface,
    progressPanelSurface: Color(0xc2ffffff),
    progressPanelBorder: Color(0x247e8b9a),
    progressTrack: Color(0x297e8b9a),
    dialogSurface: SettingsPageColors.dialogSurface,
    overlay: SettingsPageColors.overlay,
    preferenceHeader: SettingsPageColors.preferenceHeader,
  );

  static const dark = SettingsPalette(
    textStrong: Color(0xeff6f9fc),
    textMuted: Color(0xadCBD5E1),
    accent: SettingsPageColors.accent,
    accentStrong: Color(0xff7fc4ff),
    accentHover: SmPlayerInteractionColors.hoverSurfaceDark,
    cardSurface: Color(0x0cffffff),
    cardBorder: Color(0x1fd6e0ec),
    cardShadow: Color(0x33000000),
    inputSurface: Color(0x11ffffff),
    inputBorder: Color(0x1fd6e0ec),
    selectOpenSurface: SmPlayerInteractionColors.hoverSurfaceDark,
    selectOpenBorder: Color(0x570078d7),
    dropdownSurface: Color(0xfa181e26),
    dropdownShadow: Color(0x5c000000),
    colorSwatchInset: Color(0x1fffffff),
    buttonSurface: Color(0x11ffffff),
    progressPanelSurface: Color(0x11ffffff),
    progressPanelBorder: Color(0x1fd6e0ec),
    progressTrack: Color(0x2ecbd5e1),
    dialogSurface: Color(0xff181e26),
    overlay: Color(0x7a05070a),
    preferenceHeader: Color(0x14ffffff),
  );

  final Color textStrong;
  final Color textMuted;
  final Color accent;
  final Color accentStrong;
  final Color accentHover;
  final Color cardSurface;
  final Color cardBorder;
  final Color cardShadow;
  final Color inputSurface;
  final Color inputBorder;
  final Color selectOpenSurface;
  final Color selectOpenBorder;
  final Color dropdownSurface;
  final Color dropdownShadow;
  final Color colorSwatchInset;
  final Color buttonSurface;
  final Color progressPanelSurface;
  final Color progressPanelBorder;
  final Color progressTrack;
  final Color dialogSurface;
  final Color overlay;
  final Color preferenceHeader;

  @override
  SettingsPalette copyWith() {
    return this;
  }

  @override
  SettingsPalette lerp(
    covariant ThemeExtension<SettingsPalette>? other,
    double t,
  ) {
    return this;
  }
}
