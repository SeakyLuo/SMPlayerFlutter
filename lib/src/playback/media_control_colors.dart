part of 'media_control.dart';

enum MediaControlCoverWashMode { linear, radial }

class MediaControlSliderColors {
  const MediaControlSliderColors({
    required this.progressActive,
    required this.progressInactive,
    required this.progressThumb,
    required this.progressThumbShadow,
    required this.volumeActive,
    required this.volumeInactive,
    required this.volumeThumb,
  });

  final Color progressActive;
  final Color progressInactive;
  final Color progressThumb;
  final BoxShadow progressThumbShadow;
  final Color volumeActive;
  final Color volumeInactive;
  final Color volumeThumb;

  static const light = MediaControlSliderColors(
    progressActive: MediaControlColors.accent,
    progressInactive: Color(0x2e5b697a),
    progressThumb: MediaControlColors.accent,
    progressThumbShadow: BoxShadow(
      color: Color(0x52445870),
      offset: Offset(0, 1),
      blurRadius: 8,
    ),
    volumeActive: Color(0xeb0078d7),
    volumeInactive: Color(0x2e323e4e),
    volumeThumb: MediaControlColors.accent,
  );

  static const dark = MediaControlSliderColors(
    progressActive: MediaControlColors.accent,
    progressInactive: Color(0x33ffffff),
    progressThumb: MediaControlColors.accent,
    progressThumbShadow: BoxShadow(
      color: Color(0x61000000),
      offset: Offset(0, 1),
      blurRadius: 8,
    ),
    volumeActive: MediaControlColors.accent,
    volumeInactive: Color(0x2ecbd5e1),
    volumeThumb: MediaControlColors.accent,
  );

  static const volumeThumbShadow = BoxShadow(
    color: Color(0x47000000),
    offset: Offset(0, 1),
    blurRadius: 4,
  );

  static MediaControlSliderColors forBrightness(Brightness brightness) {
    return switch (brightness) {
      Brightness.light => light,
      Brightness.dark => dark,
    };
  }

  static MediaControlSliderColors forNight(bool night) {
    return switch (night) {
      true => dark,
      false => light,
    };
  }
}

class MediaControlColors {
  const MediaControlColors._();

  static const textStrong = Color(0xff1f252b);
  static const textMuted = Color(0xff5f625f);
  static const nightText = Color(0xfff8fafc);
  static const nightMuted = Color(0xadcbd5e1);
  static const accent = Color(0xff0078d7);
  static const accentStrong = Color(0xff0063b1);
  static const accentHover = SmPlayerInteractionColors.hoverSurface;
  static const nightTransportHover = Color(0x2e0078d7);
  static const nightAccentStrong = Color(0xffffffff);
  static const nightAccentHover = SmPlayerInteractionColors.hoverSurfaceDark;
  static const accentBorder = Color(0x2e0078d7);
  static const accentShadow = Color(0x330078d7);
  static const favorite = SmPlayerFavoriteIcon.activeColor;
  static const favoriteActiveHover = Color(0x38ffffff);
  static const nightFavoriteActiveHover = Color(0x1fffffff);
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
  static const disabledPrimaryButtonSurface = Color(0xffffffff);
  static const disabledPrimaryButtonBorder = Color(0x4dd6eaff);
  static const disabledPrimaryButtonShadow = Color(0x120078d7);
  static const nightDisabledPrimaryButtonSurface = Color(0x33d6eaff);

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
    required this.primaryButtonBorder,
    required this.primaryButtonShadow,
    required this.buttonForeground,
    required this.buttonHoverForeground,
    required this.buttonHoverBackground,
    required this.buttonActiveBackground,
    required this.favoriteActiveHoverBackground,
    required this.volumeTooltipBackground,
    required this.volumeTooltipForeground,
    required this.volumeTooltipBorder,
    required this.volumeTooltipShadow,
    required this.sliderInactive,
    required this.disabledPrimaryButtonSurface,
    required this.disabledPrimaryButtonBorder,
    required this.disabledPrimaryIconColor,
    required this.disabledPrimaryIconHidden,
    required this.disabledPrimaryButtonShadow,
    required this.disabledPrimaryButtonShadowOffset,
    required this.disabledPrimaryButtonShadowBlur,
    required this.glassBlur,
    required this.glassThickness,
    required this.glassLightIntensity,
    required this.glassSaturation,
    required this.compactGlassBlur,
    required this.compactGlassSaturation,
    required this.glassColor,
    required this.coverWashAlpha,
    required this.compactCoverWashAlpha,
    required this.playerBorder,
    required this.compactPlayerBorder,
    required this.playerShadow,
    required this.compactPlayerShadow,
    required this.wideShadowOffsetY,
    required this.wideShadowBlur,
    required this.compactShadowOffsetY,
    required this.compactShadowBlur,
    required this.wideSurface,
    required this.compactSurface,
    required this.wideWashStop,
    required this.compactWashEnd,
    required this.compactWashStop,
    required this.compactBaseGradient,
    this.compactBaseGradientStops,
    required this.coverWashMode,
    required this.coverWashAlignment,
    required this.coverWashRadius,
    required this.wideHighlightGradient,
    this.wideHighlightStops,
    required this.wideInsetHighlight,
    required this.compactInsetHighlight,
  });

  final Color textStrong;
  final Color textMuted;
  final Color accentStrong;
  final Color accentHover;
  final Color primaryButtonHover;
  final Color primaryButtonBorder;
  final BoxShadow primaryButtonShadow;
  final Color buttonForeground;
  final Color buttonHoverForeground;
  final Color buttonHoverBackground;
  final Color buttonActiveBackground;
  final Color favoriteActiveHoverBackground;
  final Color volumeTooltipBackground;
  final Color volumeTooltipForeground;
  final Color volumeTooltipBorder;
  final BoxShadow volumeTooltipShadow;
  final Color sliderInactive;
  final Color disabledPrimaryButtonSurface;
  final Color disabledPrimaryButtonBorder;
  final Color disabledPrimaryIconColor;
  final bool disabledPrimaryIconHidden;
  final Color disabledPrimaryButtonShadow;
  final Offset disabledPrimaryButtonShadowOffset;
  final double disabledPrimaryButtonShadowBlur;
  final double glassBlur;
  final double glassThickness;
  final double glassLightIntensity;
  final double glassSaturation;
  final double compactGlassBlur;
  final double compactGlassSaturation;
  final Color glassColor;
  final double coverWashAlpha;
  final double compactCoverWashAlpha;
  final Color playerBorder;
  final Color compactPlayerBorder;
  final Color playerShadow;
  final Color compactPlayerShadow;
  final double wideShadowOffsetY;
  final double wideShadowBlur;
  final double compactShadowOffsetY;
  final double compactShadowBlur;
  final Color wideSurface;
  final Color compactSurface;
  final double wideWashStop;
  final Color compactWashEnd;
  final double compactWashStop;
  final List<Color> compactBaseGradient;
  final List<double>? compactBaseGradientStops;
  final MediaControlCoverWashMode coverWashMode;
  final Alignment coverWashAlignment;
  final double coverWashRadius;
  final List<Color> wideHighlightGradient;
  final List<double>? wideHighlightStops;
  final Color wideInsetHighlight;
  final Color compactInsetHighlight;

  static const light = MediaControlThemeColors(
    textStrong: MediaControlColors.textStrong,
    textMuted: MediaControlColors.textMuted,
    accentStrong: MediaControlColors.accentStrong,
    accentHover: MediaControlColors.accentHover,
    primaryButtonHover: MediaControlColors.accentStrong,
    primaryButtonBorder: MediaControlColors.accentBorder,
    primaryButtonShadow: BoxShadow(
      color: MediaControlColors.accentShadow,
      offset: Offset(0, 12),
      blurRadius: 24,
    ),
    buttonForeground: MediaControlColors.textStrong,
    buttonHoverForeground: MediaControlColors.accentStrong,
    buttonHoverBackground: MediaControlColors.accentHover,
    buttonActiveBackground: Color(0x240078d7),
    favoriteActiveHoverBackground: MediaControlColors.favoriteActiveHover,
    volumeTooltipBackground: Color(0xf5ffffff),
    volumeTooltipForeground: MediaControlColors.textStrong,
    volumeTooltipBorder: Color(0x1a323e4e),
    volumeTooltipShadow: BoxShadow(
      color: Color(0x2e2a384e),
      offset: Offset(0, 8),
      blurRadius: 18,
    ),
    sliderInactive: MediaControlColors.sliderInactive,
    disabledPrimaryButtonSurface:
        MediaControlColors.disabledPrimaryButtonSurface,
    disabledPrimaryButtonBorder: MediaControlColors.disabledPrimaryButtonBorder,
    disabledPrimaryIconColor: Colors.transparent,
    disabledPrimaryIconHidden: true,
    disabledPrimaryButtonShadow: MediaControlColors.disabledPrimaryButtonShadow,
    disabledPrimaryButtonShadowOffset: Offset(0, 8),
    disabledPrimaryButtonShadowBlur: 18,
    glassBlur: 28,
    glassThickness: 28,
    glassLightIntensity: 0.56,
    glassSaturation: 1.34,
    compactGlassBlur: 28,
    compactGlassSaturation: 1.45,
    glassColor: Color(0x30ffffff),
    coverWashAlpha: 0.24,
    compactCoverWashAlpha: 0.24,
    playerBorder: MediaControlColors.playerBorder,
    compactPlayerBorder: MediaControlColors.compactPlayerBorder,
    playerShadow: MediaControlColors.playerShadow,
    compactPlayerShadow: MediaControlColors.compactPlayerShadow,
    wideShadowOffsetY: 18,
    wideShadowBlur: 48,
    compactShadowOffsetY: -12,
    compactShadowBlur: 36,
    wideSurface: MediaControlColors.playerSurfaceSolid,
    compactSurface: MediaControlColors.compactPlayerSurface,
    wideWashStop: 0.42,
    compactWashEnd: Color(0xa8ffffff),
    compactWashStop: 0.54,
    compactBaseGradient: [
      MediaControlColors.compactPlayerTop,
      MediaControlColors.compactPlayerBottom,
    ],
    compactBaseGradientStops: null,
    coverWashMode: MediaControlCoverWashMode.linear,
    coverWashAlignment: Alignment.centerLeft,
    coverWashRadius: 0.42,
    wideHighlightGradient: [
      MediaControlColors.playerSurface,
      MediaControlColors.playerAccentWash,
    ],
    wideHighlightStops: null,
    wideInsetHighlight: Colors.transparent,
    compactInsetHighlight: MediaControlColors.compactPlayerInsetHighlight,
  );

  static const dark = MediaControlThemeColors(
    textStrong: MediaControlColors.nightText,
    textMuted: MediaControlColors.nightMuted,
    accentStrong: MediaControlColors.nightAccentStrong,
    accentHover: MediaControlColors.nightAccentHover,
    primaryButtonHover: MediaControlColors.nightTransportHover,
    primaryButtonBorder: MediaControlColors.accentBorder,
    primaryButtonShadow: BoxShadow(
      color: MediaControlColors.accentShadow,
      offset: Offset(0, 12),
      blurRadius: 24,
    ),
    buttonForeground: MediaControlColors.nightText,
    buttonHoverForeground: MediaControlColors.nightAccentStrong,
    buttonHoverBackground: MediaControlColors.nightAccentHover,
    buttonActiveBackground: Color(0x380078d7),
    favoriteActiveHoverBackground: MediaControlColors.nightFavoriteActiveHover,
    volumeTooltipBackground: Color(0xfa1d232b),
    volumeTooltipForeground: MediaControlColors.nightText,
    volumeTooltipBorder: MediaControlColors.nightPlayerBorder,
    volumeTooltipShadow: BoxShadow(
      color: Color(0x57000000),
      offset: Offset(0, 8),
      blurRadius: 18,
    ),
    sliderInactive: MediaControlColors.nightSliderInactive,
    disabledPrimaryButtonSurface:
        MediaControlColors.nightDisabledPrimaryButtonSurface,
    disabledPrimaryButtonBorder: MediaControlColors.accentBorder,
    disabledPrimaryIconColor: Colors.transparent,
    disabledPrimaryIconHidden: true,
    disabledPrimaryButtonShadow: MediaControlColors.accentShadow,
    disabledPrimaryButtonShadowOffset: Offset(0, 12),
    disabledPrimaryButtonShadowBlur: 24,
    glassBlur: 28,
    glassThickness: 34,
    glassLightIntensity: 0.42,
    glassSaturation: 1.18,
    compactGlassBlur: 28,
    compactGlassSaturation: 1.45,
    glassColor: Color(0x2411161c),
    coverWashAlpha: 0.22,
    compactCoverWashAlpha: 0.2,
    playerBorder: MediaControlColors.nightPlayerBorder,
    compactPlayerBorder: MediaControlColors.nightPlayerBorder,
    playerShadow: MediaControlColors.nightPlayerShadow,
    compactPlayerShadow: MediaControlColors.nightPlayerShadow,
    wideShadowOffsetY: -18,
    wideShadowBlur: 48,
    compactShadowOffsetY: -12,
    compactShadowBlur: 36,
    wideSurface: MediaControlColors.nightPlayerSurface,
    compactSurface: Color(0xeb101419),
    wideWashStop: 0.46,
    compactWashEnd: Color(0xc711161c),
    compactWashStop: 0.56,
    compactBaseGradient: [Color(0xe01d232b), Color(0xe0101419)],
    compactBaseGradientStops: null,
    coverWashMode: MediaControlCoverWashMode.linear,
    coverWashAlignment: Alignment.centerLeft,
    coverWashRadius: 0.46,
    wideHighlightGradient: [
      MediaControlColors.nightPlayerHighlight,
      MediaControlColors.nightPlayerAccentWash,
    ],
    wideHighlightStops: null,
    wideInsetHighlight: Colors.transparent,
    compactInsetHighlight: MediaControlColors.nightCompactPlayerInsetHighlight,
  );

  static MediaControlThemeColors of(BuildContext context) {
    return Theme.of(context).extension<MediaControlThemeColors>() ?? light;
  }

  @override
  MediaControlThemeColors copyWith({
    Color? textMuted,
    Color? primaryButtonHover,
    Color? primaryButtonBorder,
    BoxShadow? primaryButtonShadow,
    Color? disabledPrimaryButtonSurface,
    Color? buttonForeground,
    Color? buttonHoverForeground,
    Color? buttonHoverBackground,
    Color? buttonActiveBackground,
    Color? favoriteActiveHoverBackground,
    Color? volumeTooltipBackground,
    Color? volumeTooltipForeground,
    Color? volumeTooltipBorder,
    BoxShadow? volumeTooltipShadow,
    Color? playerBorder,
    Color? compactPlayerBorder,
    Color? playerShadow,
    Color? compactPlayerShadow,
    double? wideShadowOffsetY,
    double? wideShadowBlur,
    double? compactShadowOffsetY,
    double? compactShadowBlur,
    double? glassBlur,
    double? glassSaturation,
    double? compactGlassBlur,
    double? compactGlassSaturation,
    double? coverWashAlpha,
    double? compactCoverWashAlpha,
    Color? wideSurface,
    Color? compactSurface,
    MediaControlCoverWashMode? coverWashMode,
    Alignment? coverWashAlignment,
    double? coverWashRadius,
    List<Color>? wideHighlightGradient,
    List<double>? wideHighlightStops,
    Color? compactWashEnd,
    double? compactWashStop,
    List<Color>? compactBaseGradient,
    List<double>? compactBaseGradientStops,
    Color? wideInsetHighlight,
    Color? compactInsetHighlight,
  }) {
    return MediaControlThemeColors(
      textStrong: textStrong,
      textMuted: textMuted ?? this.textMuted,
      accentStrong: accentStrong,
      accentHover: accentHover,
      primaryButtonHover: primaryButtonHover ?? this.primaryButtonHover,
      primaryButtonBorder: primaryButtonBorder ?? this.primaryButtonBorder,
      primaryButtonShadow: primaryButtonShadow ?? this.primaryButtonShadow,
      buttonForeground: buttonForeground ?? this.buttonForeground,
      buttonHoverForeground:
          buttonHoverForeground ?? this.buttonHoverForeground,
      buttonHoverBackground:
          buttonHoverBackground ?? this.buttonHoverBackground,
      buttonActiveBackground:
          buttonActiveBackground ?? this.buttonActiveBackground,
      favoriteActiveHoverBackground:
          favoriteActiveHoverBackground ?? this.favoriteActiveHoverBackground,
      volumeTooltipBackground:
          volumeTooltipBackground ?? this.volumeTooltipBackground,
      volumeTooltipForeground:
          volumeTooltipForeground ?? this.volumeTooltipForeground,
      volumeTooltipBorder: volumeTooltipBorder ?? this.volumeTooltipBorder,
      volumeTooltipShadow: volumeTooltipShadow ?? this.volumeTooltipShadow,
      sliderInactive: sliderInactive,
      disabledPrimaryButtonSurface:
          disabledPrimaryButtonSurface ?? this.disabledPrimaryButtonSurface,
      disabledPrimaryButtonBorder: disabledPrimaryButtonBorder,
      disabledPrimaryIconColor: disabledPrimaryIconColor,
      disabledPrimaryIconHidden: disabledPrimaryIconHidden,
      disabledPrimaryButtonShadow: disabledPrimaryButtonShadow,
      disabledPrimaryButtonShadowOffset: disabledPrimaryButtonShadowOffset,
      disabledPrimaryButtonShadowBlur: disabledPrimaryButtonShadowBlur,
      glassBlur: glassBlur ?? this.glassBlur,
      glassThickness: glassThickness,
      glassLightIntensity: glassLightIntensity,
      glassSaturation: glassSaturation ?? this.glassSaturation,
      compactGlassBlur: compactGlassBlur ?? this.compactGlassBlur,
      compactGlassSaturation:
          compactGlassSaturation ?? this.compactGlassSaturation,
      glassColor: glassColor,
      coverWashAlpha: coverWashAlpha ?? this.coverWashAlpha,
      compactCoverWashAlpha:
          compactCoverWashAlpha ?? this.compactCoverWashAlpha,
      playerBorder: playerBorder ?? this.playerBorder,
      compactPlayerBorder: compactPlayerBorder ?? this.compactPlayerBorder,
      playerShadow: playerShadow ?? this.playerShadow,
      compactPlayerShadow: compactPlayerShadow ?? this.compactPlayerShadow,
      wideShadowOffsetY: wideShadowOffsetY ?? this.wideShadowOffsetY,
      wideShadowBlur: wideShadowBlur ?? this.wideShadowBlur,
      compactShadowOffsetY: compactShadowOffsetY ?? this.compactShadowOffsetY,
      compactShadowBlur: compactShadowBlur ?? this.compactShadowBlur,
      wideSurface: wideSurface ?? this.wideSurface,
      compactSurface: compactSurface ?? this.compactSurface,
      wideWashStop: wideWashStop,
      compactWashEnd: compactWashEnd ?? this.compactWashEnd,
      compactWashStop: compactWashStop ?? this.compactWashStop,
      compactBaseGradient: compactBaseGradient ?? this.compactBaseGradient,
      compactBaseGradientStops:
          compactBaseGradientStops ?? this.compactBaseGradientStops,
      coverWashMode: coverWashMode ?? this.coverWashMode,
      coverWashAlignment: coverWashAlignment ?? this.coverWashAlignment,
      coverWashRadius: coverWashRadius ?? this.coverWashRadius,
      wideHighlightGradient:
          wideHighlightGradient ?? this.wideHighlightGradient,
      wideHighlightStops: wideHighlightStops ?? this.wideHighlightStops,
      wideInsetHighlight: wideInsetHighlight ?? this.wideInsetHighlight,
      compactInsetHighlight:
          compactInsetHighlight ?? this.compactInsetHighlight,
    );
  }

  @override
  MediaControlThemeColors lerp(
    covariant ThemeExtension<MediaControlThemeColors>? other,
    double t,
  ) {
    return this;
  }
}
