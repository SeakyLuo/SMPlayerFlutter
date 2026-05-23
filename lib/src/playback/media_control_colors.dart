part of 'media_control.dart';

class MediaControlColors {
  const MediaControlColors._();

  static const textStrong = Color(0xff1f252b);
  static const textMuted = Color(0xff5f625f);
  static const nightText = Color(0xfff8fafc);
  static const nightMuted = Color(0xffcbd5e1);
  static const accent = Color(0xff0078d7);
  static const accentStrong = Color(0xff0063b1);
  static const accentHover = Color(0x1f0078d7);
  static const nightAccentStrong = Color(0xffffffff);
  static const nightAccentHover = Color(0x380078d7);
  static const accentBorder = Color(0x2e0078d7);
  static const accentShadow = Color(0x330078d7);
  static const favorite = Color(0xffd83b7d);
  static const playerSurface = Color(0xe0ffffff);
  static const playerAccentWash = Color(0x1a0078d7);
  static const emptyPlayerAccentWash = Color(0x100078d7);
  static const emptyPlayerLeftWash = Color(0xe0ffffff);
  static const emptyPlayerRightWash = Color(0x1a0078d7);
  static const playerSurfaceSolid = Color(0xd1ffffff);
  static const playerBorder = Color(0xd6ffffff);
  static const compactPlayerBorder = Color(0x9effffff);
  static const compactPlayerSurface = Color(0xd1f8fbfe);
  static const compactPlayerTop = Color(0xbdffffff);
  static const compactPlayerBottom = Color(0xb3f6fafe);
  static const compactPlayerWash = Color(0xa8ffffff);
  static const emptyCompactPlayerWash = Color(0xccffffff);
  static const compactPlayerInsetHighlight = Color(0xd1ffffff);
  static const nightPlayerHighlight = Color(0x0effffff);
  static const nightPlayerAccentWash = Color(0x1f0078d7);
  static const nightEmptyPlayerAccentWash = Color(0x120078d7);
  static const nightEmptyPlayerRightWash = Color(0x18162028);
  static const nightPlayerSurface = Color(0xe611161c);
  static const nightCompactPlayerSurface = Color(0xeb101419);
  static const nightCompactPlayerTop = Color(0xe01d232b);
  static const nightCompactPlayerBottom = Color(0xe0101419);
  static const nightCompactPlayerWash = Color(0xc711161c);
  static const nightEmptyCompactPlayerWash = Color(0xd611161c);
  static const nightCompactPlayerInsetHighlight = Color(0x0cffffff);
  static const nightPlayerBorder = Color(0x3dffffff);
  static const playerShadow = Color(0x382a384e);
  static const compactPlayerShadow = Color(0x242a384e);
  static const nightPlayerShadow = Color(0x57000000);
  static const artworkShadow = Color(0x382a384e);
  static const sliderInactive = Color(0x2e323e4e);
  static const nightSliderInactive = Color(0x2ecbd5e1);
  static const buttonSurface = Color(0xb8ffffff);
  static const disabledButtonSurface = Color(0x14ffffff);
  static const disabledPrimaryButtonSurface = Color(0xccffffff);
  static const disabledPrimaryButtonBorder = Color(0x4dd6eaff);
  static const disabledPrimaryButtonShadow = Color(0x120078d7);
  static const nightDisabledPrimaryButtonSurface = Color(0x14ffffff);

  static bool isNight(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color textStrongFor(BuildContext context) =>
      isNight(context) ? nightText : textStrong;

  static Color textMutedFor(BuildContext context) =>
      isNight(context) ? nightMuted : textMuted;

  static Color accentStrongFor(BuildContext context) =>
      isNight(context) ? nightAccentStrong : accentStrong;

  static Color accentHoverFor(BuildContext context) =>
      isNight(context) ? nightAccentHover : accentHover;

  static Color sliderInactiveFor(BuildContext context) =>
      isNight(context) ? nightSliderInactive : sliderInactive;

  static Color disabledPrimaryButtonSurfaceFor(BuildContext context) =>
      isNight(context)
          ? nightDisabledPrimaryButtonSurface
          : disabledPrimaryButtonSurface;

  static Color disabledPrimaryButtonBorderFor(BuildContext context) =>
      isNight(context) ? accentBorder : disabledPrimaryButtonBorder;

  static Color playerBorderFor(bool night) =>
      night ? nightPlayerBorder : playerBorder;

  static Color compactPlayerBorderFor(bool night) =>
      night ? nightPlayerBorder : compactPlayerBorder;

  static Color playerShadowFor(bool night) =>
      night ? nightPlayerShadow : playerShadow;

  static Color compactPlayerShadowFor(bool night) =>
      night ? nightPlayerShadow : compactPlayerShadow;
}
