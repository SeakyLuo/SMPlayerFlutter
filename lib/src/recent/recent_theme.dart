part of 'recent_page.dart';

class _RecentColors {
  const _RecentColors._();

  static const accent = Color(0xff0078d7);
  static const accentStrong = Color(0xff0063b1);
  static const accentSoft = Color(0x1f0078d7);
  static const textStrong = Color(0xff111827);
  static const textRootMuted = Color(0xff5f625f);
  static const textMuted = Color(0xff5b697a);
  static const textSoft = Color(0xff8290a1);
  static const appBarTabSurface = Color(0x80ffffff);
  static const appBarTabBorder = Color(0x24536379);
  static const appBarTabActiveBorder = Color(0x380078d7);
  static const playedFilterBorder = Color(0x1f536379);
  static const playedFilterActiveBorder = Color(0x6b0078d7);
  static const playedFilterActiveSurface = Color(0x240078d7);
  static const playedFilterActiveRing = SmPlayerInteractionColors.hoverSurface;
  static const artwork = Color(0xffe8eef5);
  static const artworkIcon = Color(0xff607085);
  static const nightText = Color(0xfff6f9fc);
  static const nightMuted = Color(0xadcbd5e1);
  static const nightSubtle = Color(0x75cbd5e1);
  static const nightBorder = Color(0x1fd6e0ec);
  static const nightAccentText = Color(0xff459de2);
  static const nightControlSurface = Color(0x0effffff);
  static const nightRecentTabSurface = Color(0x09ffffff);
  static const nightAppBarTabActiveSurface = Color(0x290078d7);
  static const nightAppBarTabActiveBorder = Color(0x570078d7);
  static const nightRecentTabActiveSurface = Color(0x3d0078d7);
  static const nightRecentTabActiveBorder = Color(0x7a0078d7);
  static const nightPlayedFilterActiveSurface = Color(0x2e0078d7);
  static const nightPlayedFilterActiveBorder = Color(0x610078d7);
}

class RecentThemeColors extends ThemeExtension<RecentThemeColors> {
  const RecentThemeColors({
    required this.tabsHeight,
    required this.tabsSpacing,
    required this.appBarTabText,
    required this.appBarTabActiveText,
    required this.appBarTabSurface,
    required this.appBarTabActiveSurface,
    required this.appBarTabHoverText,
    required this.appBarTabHoverSurface,
    required this.appBarTabHoverBorder,
    required this.appBarTabBorder,
    required this.appBarTabActiveBorder,
    required this.appBarTabRadius,
    required this.primaryTabsUsePillStyle,
    required this.primaryTabText,
    required this.primaryTabActiveText,
    required this.primaryTabSurface,
    required this.primaryTabActiveSurface,
    required this.primaryTabBorder,
    required this.primaryTabActiveBorder,
    required this.primaryTabRadius,
    required this.playedFilterText,
    required this.playedFilterActiveText,
    required this.playedFilterSurface,
    required this.playedFilterActiveSurface,
    required this.playedFilterBorder,
    required this.playedFilterActiveBorder,
    required this.playedFilterActiveShadow,
  });

  final double tabsHeight;
  final double tabsSpacing;
  final Color appBarTabText;
  final Color appBarTabActiveText;
  final Color appBarTabSurface;
  final Color appBarTabActiveSurface;
  final Color appBarTabHoverText;
  final Color appBarTabHoverSurface;
  final Color appBarTabHoverBorder;
  final Color appBarTabBorder;
  final Color appBarTabActiveBorder;
  final double appBarTabRadius;
  final bool primaryTabsUsePillStyle;
  final Color primaryTabText;
  final Color primaryTabActiveText;
  final Color primaryTabSurface;
  final Color primaryTabActiveSurface;
  final Color primaryTabBorder;
  final Color primaryTabActiveBorder;
  final double primaryTabRadius;
  final Color playedFilterText;
  final Color playedFilterActiveText;
  final Color playedFilterSurface;
  final Color playedFilterActiveSurface;
  final Color playedFilterBorder;
  final Color playedFilterActiveBorder;
  final List<BoxShadow> playedFilterActiveShadow;

  static const light = RecentThemeColors(
    tabsHeight: 54,
    tabsSpacing: 34,
    appBarTabText: _RecentColors.textStrong,
    appBarTabActiveText: _RecentColors.accentStrong,
    appBarTabSurface: _RecentColors.appBarTabSurface,
    appBarTabActiveSurface: _RecentColors.accentSoft,
    appBarTabHoverText: _RecentColors.accentStrong,
    appBarTabHoverSurface: GlobalUI.hoverBgColorDay,
    appBarTabHoverBorder: GlobalUI.hoverBorderColorDay,
    appBarTabBorder: _RecentColors.appBarTabBorder,
    appBarTabActiveBorder: _RecentColors.appBarTabActiveBorder,
    appBarTabRadius: 10,
    primaryTabsUsePillStyle: false,
    primaryTabText: _RecentColors.textRootMuted,
    primaryTabActiveText: _RecentColors.accent,
    primaryTabSurface: Colors.transparent,
    primaryTabActiveSurface: Colors.transparent,
    primaryTabBorder: Colors.transparent,
    primaryTabActiveBorder: Colors.transparent,
    primaryTabRadius: 0,
    playedFilterText: _RecentColors.textStrong,
    playedFilterActiveText: _RecentColors.accent,
    playedFilterSurface: _RecentColors.appBarTabSurface,
    playedFilterActiveSurface: _RecentColors.playedFilterActiveSurface,
    playedFilterBorder: _RecentColors.playedFilterBorder,
    playedFilterActiveBorder: _RecentColors.playedFilterActiveBorder,
    playedFilterActiveShadow: [
      BoxShadow(color: _RecentColors.playedFilterActiveRing, spreadRadius: 2),
    ],
  );

  static const dark = RecentThemeColors(
    tabsHeight: 46,
    tabsSpacing: 10,
    appBarTabText: _RecentColors.nightText,
    appBarTabActiveText: _RecentColors.nightAccentText,
    appBarTabSurface: _RecentColors.nightControlSurface,
    appBarTabActiveSurface: _RecentColors.nightAppBarTabActiveSurface,
    appBarTabHoverText: _RecentColors.nightAccentText,
    appBarTabHoverSurface: GlobalUI.hoverBgColorNight,
    appBarTabHoverBorder: GlobalUI.hoverBorderColorNight,
    appBarTabBorder: _RecentColors.nightBorder,
    appBarTabActiveBorder: _RecentColors.nightAppBarTabActiveBorder,
    appBarTabRadius: 999,
    primaryTabsUsePillStyle: true,
    primaryTabText: _RecentColors.nightMuted,
    primaryTabActiveText: _RecentColors.nightAccentText,
    primaryTabSurface: _RecentColors.nightRecentTabSurface,
    primaryTabActiveSurface: _RecentColors.nightRecentTabActiveSurface,
    primaryTabBorder: _RecentColors.nightBorder,
    primaryTabActiveBorder: _RecentColors.nightRecentTabActiveBorder,
    primaryTabRadius: 999,
    playedFilterText: _RecentColors.nightText,
    playedFilterActiveText: _RecentColors.nightAccentText,
    playedFilterSurface: _RecentColors.nightControlSurface,
    playedFilterActiveSurface: _RecentColors.nightPlayedFilterActiveSurface,
    playedFilterBorder: _RecentColors.nightBorder,
    playedFilterActiveBorder: _RecentColors.nightPlayedFilterActiveBorder,
    playedFilterActiveShadow: [],
  );

  static RecentThemeColors of(BuildContext context) {
    return Theme.of(context).extension<RecentThemeColors>()!;
  }

  @override
  RecentThemeColors copyWith() {
    return this;
  }

  @override
  RecentThemeColors lerp(ThemeExtension<RecentThemeColors>? other, double t) {
    return t < 0.5 || other is! RecentThemeColors ? this : other;
  }
}
