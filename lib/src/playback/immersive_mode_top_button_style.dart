import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:smplayer_flutter/src/app/text_icon_button.dart';
import 'package:smplayer_flutter/src/playback/immersive_mode_constants.dart';
import 'package:smplayer_flutter/src/playback/immersive_mode_theme.dart';

bool immersiveModeUsesNightTopButton(ImmersiveModeThemeColors colors) {
  return colors.pageBackground == ImmersiveModeThemeColors.dark.pageBackground;
}

SmPlayerTextIconButtonColors immersiveModeTopButtonColors(
  BuildContext context,
  ImmersiveModeThemeColors colors,
) {
  final baseColors = SmPlayerTextIconButtonColors.of(context);
  if (immersiveModeUsesNightTopButton(colors)) {
    return baseColors.copyWith(
      commandText: const Color(0xe0ffffff),
      commandTextHover: SmPlayerTextIconButtonColors.night.commandTextHover,
      control: const Color(0x14ffffff),
      controlHover: SmPlayerTextIconButtonColors.night.controlHover,
      controlActive: SmPlayerTextIconButtonColors.night.controlActive,
      controlBorder: const Color(0x29ffffff),
      controlHoverBorder: SmPlayerTextIconButtonColors.night.controlHoverBorder,
      accentStrong: SmPlayerTextIconButtonColors.night.accentStrong,
    );
  }
  return baseColors.copyWith(
    control: const Color(0x18ffffff),
    controlBorder: const Color(0x2effffff),
  );
}

SmPlayerTextIconButtonColors immersiveModeLyricSeekButtonColors(
  BuildContext context,
  ImmersiveModeThemeColors colors,
) {
  return immersiveModeTopButtonColors(context, colors);
}

LiquidGlassSettings immersiveModeTopButtonGlassSettingsFor(
  ImmersiveModeThemeColors colors,
) {
  return immersiveModeUsesNightTopButton(colors)
      ? immersiveModeTopButtonNightGlassSettings
      : immersiveModeTopButtonGlassSettings;
}
