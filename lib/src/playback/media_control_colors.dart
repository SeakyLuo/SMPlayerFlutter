part of 'media_control.dart';

class MediaControlColors {
  const MediaControlColors._();

  static const textStrong = Color(0xff1f252b);
  static const textMuted = Color(0xff5f625f);
  static const nightText = Color(0xfff8fafc);
  static const nightMuted = Color(0xffcbd5e1);
  static const accent = Color(0xff0078d7);
  static const accentStrong = Color(0xff0063b1);
  static const accentHover = SmPlayerInteractionColors.hoverSurface;
  static const nightTransportHover = Color(0x2e0078d7);
  static const nightAccentStrong = Color(0xffffffff);
  static const nightAccentHover = SmPlayerInteractionColors.hoverSurfaceDark;
  static const accentBorder = Color(0x2e0078d7);
  static const accentShadow = Color(0x330078d7);
  static const favorite = Color(0xffd83b7d);
  static const playerSurface = Color(0xe0ffffff);
  static const playerAccentWash = Color(0x1aabd9ff);
  static const emptyPlayerAccentWash = Color(0x100078d7);
  static const emptyPlayerLeftWash = Color(0xe0ffffff);
  static const emptyPlayerRightWash = Color(0x1aebf6ff);
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

  static Color textStrongFor(BuildContext context) =>
      MediaControlThemeColors.of(context).textStrong;

  static Color textMutedFor(BuildContext context) =>
      MediaControlThemeColors.of(context).textMuted;

  static Color accentStrongFor(BuildContext context) =>
      MediaControlThemeColors.of(context).accentStrong;

  static Color accentHoverFor(BuildContext context) =>
      MediaControlThemeColors.of(context).accentHover;

  static Color sliderInactiveFor(BuildContext context) =>
      MediaControlThemeColors.of(context).sliderInactive;

  static Color disabledPrimaryButtonSurfaceFor(BuildContext context) =>
      MediaControlThemeColors.of(context).disabledPrimaryButtonSurface;

  static Color disabledPrimaryButtonBorderFor(BuildContext context) =>
      MediaControlThemeColors.of(context).disabledPrimaryButtonBorder;
}

class MediaControlThemeColors extends ThemeExtension<MediaControlThemeColors> {
  const MediaControlThemeColors({
    required this.textStrong,
    required this.textMuted,
    required this.accentStrong,
    required this.accentHover,
    required this.primaryButtonHover,
    required this.sliderInactive,
    required this.disabledPrimaryButtonSurface,
    required this.disabledPrimaryButtonBorder,
    required this.disabledPrimaryIconColor,
    required this.disabledPrimaryIconHidden,
    required this.disabledPrimaryButtonShadow,
    required this.disabledPrimaryButtonShadowOffset,
    required this.disabledPrimaryButtonShadowBlur,
    required this.glassThickness,
    required this.glassLightIntensity,
    required this.glassSaturation,
    required this.glassColor,
    required this.coverWashAlpha,
    required this.playerBorder,
    required this.compactPlayerBorder,
    required this.playerShadow,
    required this.compactPlayerShadow,
    required this.wideShadowOffsetY,
    required this.wideSurface,
    required this.wideWashStop,
    required this.wideHighlightGradient,
    required this.compactInsetHighlight,
  });

  final Color textStrong;
  final Color textMuted;
  final Color accentStrong;
  final Color accentHover;
  final Color primaryButtonHover;
  final Color sliderInactive;
  final Color disabledPrimaryButtonSurface;
  final Color disabledPrimaryButtonBorder;
  final Color disabledPrimaryIconColor;
  final bool disabledPrimaryIconHidden;
  final Color disabledPrimaryButtonShadow;
  final Offset disabledPrimaryButtonShadowOffset;
  final double disabledPrimaryButtonShadowBlur;
  final double glassThickness;
  final double glassLightIntensity;
  final double glassSaturation;
  final Color glassColor;
  final double coverWashAlpha;
  final Color playerBorder;
  final Color compactPlayerBorder;
  final Color playerShadow;
  final Color compactPlayerShadow;
  final double wideShadowOffsetY;
  final Color wideSurface;
  final double wideWashStop;
  final List<Color> wideHighlightGradient;
  final Color compactInsetHighlight;

  static const light = MediaControlThemeColors(
    textStrong: MediaControlColors.textStrong,
    textMuted: MediaControlColors.textMuted,
    accentStrong: MediaControlColors.accentStrong,
    accentHover: MediaControlColors.accentHover,
    primaryButtonHover: MediaControlColors.accentStrong,
    sliderInactive: MediaControlColors.sliderInactive,
    disabledPrimaryButtonSurface:
        MediaControlColors.disabledPrimaryButtonSurface,
    disabledPrimaryButtonBorder: MediaControlColors.disabledPrimaryButtonBorder,
    disabledPrimaryIconColor: Colors.transparent,
    disabledPrimaryIconHidden: true,
    disabledPrimaryButtonShadow: MediaControlColors.disabledPrimaryButtonShadow,
    disabledPrimaryButtonShadowOffset: Offset(0, 8),
    disabledPrimaryButtonShadowBlur: 18,
    glassThickness: 28,
    glassLightIntensity: 0.56,
    glassSaturation: 1.34,
    glassColor: Color(0x30ffffff),
    coverWashAlpha: 0.24,
    playerBorder: MediaControlColors.playerBorder,
    compactPlayerBorder: MediaControlColors.compactPlayerBorder,
    playerShadow: MediaControlColors.playerShadow,
    compactPlayerShadow: MediaControlColors.compactPlayerShadow,
    wideShadowOffsetY: 18,
    wideSurface: MediaControlColors.playerSurfaceSolid,
    wideWashStop: 0.42,
    wideHighlightGradient: [
      MediaControlColors.playerSurface,
      MediaControlColors.playerAccentWash,
    ],
    compactInsetHighlight: MediaControlColors.compactPlayerInsetHighlight,
  );

  static const dark = MediaControlThemeColors(
    textStrong: MediaControlColors.nightText,
    textMuted: MediaControlColors.nightMuted,
    accentStrong: MediaControlColors.nightAccentStrong,
    accentHover: MediaControlColors.nightAccentHover,
    primaryButtonHover: MediaControlColors.nightTransportHover,
    sliderInactive: MediaControlColors.nightSliderInactive,
    disabledPrimaryButtonSurface:
        MediaControlColors.nightDisabledPrimaryButtonSurface,
    disabledPrimaryButtonBorder: MediaControlColors.accentBorder,
    disabledPrimaryIconColor: Colors.white,
    disabledPrimaryIconHidden: false,
    disabledPrimaryButtonShadow: MediaControlColors.accentShadow,
    disabledPrimaryButtonShadowOffset: Offset(0, 12),
    disabledPrimaryButtonShadowBlur: 24,
    glassThickness: 34,
    glassLightIntensity: 0.42,
    glassSaturation: 1.18,
    glassColor: Color(0x2411161c),
    coverWashAlpha: 0.22,
    playerBorder: MediaControlColors.nightPlayerBorder,
    compactPlayerBorder: MediaControlColors.nightPlayerBorder,
    playerShadow: MediaControlColors.nightPlayerShadow,
    compactPlayerShadow: MediaControlColors.nightPlayerShadow,
    wideShadowOffsetY: -18,
    wideSurface: MediaControlColors.nightPlayerSurface,
    wideWashStop: 0.46,
    wideHighlightGradient: [
      MediaControlColors.nightPlayerHighlight,
      MediaControlColors.nightPlayerAccentWash,
    ],
    compactInsetHighlight: MediaControlColors.nightCompactPlayerInsetHighlight,
  );

  static MediaControlThemeColors of(BuildContext context) {
    return Theme.of(context).extension<MediaControlThemeColors>() ?? light;
  }

  @override
  MediaControlThemeColors copyWith() {
    return this;
  }

  @override
  MediaControlThemeColors lerp(
    covariant ThemeExtension<MediaControlThemeColors>? other,
    double t,
  ) {
    return this;
  }
}
