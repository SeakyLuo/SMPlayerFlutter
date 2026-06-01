part of 'search_page.dart';

class SearchPageThemeColors extends ThemeExtension<SearchPageThemeColors> {
  const SearchPageThemeColors({
    required this.textStrong,
    required this.textMuted,
    required this.controlBorder,
    required this.subtleBorder,
    required this.controlSurface,
    required this.controlHover,
    required this.accentStrong,
    required this.accentSelectedBorder,
    required this.selectionMarkBorder,
    required this.selectionMarkSurface,
    required this.cardHover,
    required this.cardSelected,
    required this.panel,
    required this.emptyStateSurface,
    required this.emptyStateBorder,
    required this.resultToolbarGradient,
  });

  final Color textStrong;
  final Color textMuted;
  final Color controlBorder;
  final Color subtleBorder;
  final Color controlSurface;
  final Color controlHover;
  final Color accentStrong;
  final Color accentSelectedBorder;
  final Color selectionMarkBorder;
  final Color selectionMarkSurface;
  final Color cardHover;
  final Color cardSelected;
  final Color panel;
  final Color emptyStateSurface;
  final Color emptyStateBorder;
  final List<Color> resultToolbarGradient;

  static const light = SearchPageThemeColors(
    textStrong: _SearchColors.textStrong,
    textMuted: _SearchColors.textMuted,
    controlBorder: _SearchColors.controlBorder,
    subtleBorder: _SearchColors.subtleBorder,
    controlSurface: _SearchColors.controlSurface,
    controlHover: _SearchColors.accentSoft,
    accentStrong: _SearchColors.accent,
    accentSelectedBorder: _SearchColors.accentSelectedBorder,
    selectionMarkBorder: Color(0x52768499),
    selectionMarkSurface: Colors.white,
    cardHover: _SearchColors.cardHover,
    cardSelected: _SearchColors.cardSelected,
    panel: Colors.white,
    emptyStateSurface: _SearchColors.emptyStateSurface,
    emptyStateBorder: _SearchColors.emptyStateBorder,
    resultToolbarGradient: [
      Color(0xf5fafcff),
      Color(0xe0fafcff),
      Color(0x00fafcff),
    ],
  );

  static const dark = SearchPageThemeColors(
    textStrong: Color(0xeff6f9fc),
    textMuted: Color(0xb8d8e2ef),
    controlBorder: Color(0x29d6e0ec),
    subtleBorder: Color(0x29d6e0ec),
    controlSurface: Color(0x0effffff),
    controlHover: SmPlayerInteractionColors.hoverSurfaceDark,
    accentStrong: Color(0xff5fb6ff),
    accentSelectedBorder: Color(0x6b0078d7),
    selectionMarkBorder: Color(0x6bdce6f2),
    selectionMarkSurface: Color(0xb812161d),
    cardHover: SmPlayerInteractionColors.hoverSurfaceDark,
    cardSelected: Color(0x2e0078d7),
    panel: Color(0x0cffffff),
    emptyStateSurface: _SearchColors.nightEmptyStateSurface,
    emptyStateBorder: _SearchColors.nightEmptyStateBorder,
    resultToolbarGradient: [
      Color(0xf5101419),
      Color(0xe0101419),
      Color(0x00101419),
    ],
  );

  static SearchPageThemeColors of(BuildContext context) {
    return Theme.of(context).extension<SearchPageThemeColors>() ?? light;
  }

  @override
  SearchPageThemeColors copyWith() {
    return this;
  }

  @override
  SearchPageThemeColors lerp(
    covariant ThemeExtension<SearchPageThemeColors>? other,
    double t,
  ) {
    return this;
  }
}

class _SearchColors {
  const _SearchColors._();

  static const accent = Color(0xff0063b1);
  static const accentSoft = SmPlayerInteractionColors.hoverSurface;
  static const controlBorder = Color(0x3d7e8b9a);
  static const subtleBorder = Color(0x2e768499);
  static const controlSurface = Color(0x94ffffff);
  static const cardHover = SmPlayerInteractionColors.hoverSurface;
  static const cardSelected = Color(0x1f0078d7);
  static const accentSelectedBorder = Color(0x6b0078d7);
  static const textStrong = Color(0xff111827);
  static const textMuted = Color(0xff5b697a);
  static const emptyStateSurface = Color(0x94ffffff);
  static const emptyStateBorder = Color(0x94ffffff);
  static const nightEmptyStateSurface = Color(0x0cffffff);
  static const nightEmptyStateBorder = Color(0x1fd6e0ec);
}
