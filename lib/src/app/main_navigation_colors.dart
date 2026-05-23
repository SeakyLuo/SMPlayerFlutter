part of 'main_navigation_view.dart';

class MainNavigationViewColors {
  const MainNavigationViewColors._();

  static const textStrong = Color(0xff1f252b);
  static const textMuted = Color(0xff5f625f);
  static const accentStrong = Color(0xff0063b1);
  static const accentHover = Color(0x1a0078d7);
  static const iconButtonHover = Color(0x1f0078d7);
  static const collapsedHover = Color(0x210078d7);
  static const accentBorder = Color(0x140078d7);
  static const searchSurface = Color(0x090d1826);
  static const focusedSearchSurface = Color(0xffffffff);
  static const searchBorder = Color(0x24536379);
  static const focusedSearchBorder = Color(0x7a0078d7);
  static const searchFocusRing = Color(0x1a0078d7);
  static const searchInsetHighlight = Color(0x61ffffff);
  static const searchPlaceholder = Color(0x9e3d4958);
  static const clearButton = Color(0x140078d7);
  static const sectionDivider = Color(0x3d6c7580);
  static const sectionLabel = Color(0x8a5f625f);
  static const dropdownSurface = Color(0xf7ffffff);
  static const dropdownShadow = Color(0x1a273446);

  static MainNavigationPalette of(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (!dark) {
      return const MainNavigationPalette(
        textStrong: textStrong,
        textMuted: textMuted,
        highlightText: accentStrong,
        accentStrong: accentStrong,
        accentHover: accentHover,
        iconButtonHover: iconButtonHover,
        collapsedHover: collapsedHover,
        accentBorder: accentBorder,
        searchSurface: searchSurface,
        focusedSearchSurface: focusedSearchSurface,
        searchBorder: searchBorder,
        focusedSearchBorder: focusedSearchBorder,
        searchFocusRing: searchFocusRing,
        searchInsetHighlight: searchInsetHighlight,
        searchPlaceholder: searchPlaceholder,
        clearButton: clearButton,
        clearForeground: accentStrong,
        sectionDivider: sectionDivider,
        sectionLabel: sectionLabel,
        dropdownSurface: dropdownSurface,
        dropdownShadow: dropdownShadow,
      );
    }
    return const MainNavigationPalette(
      textStrong: Color(0xebffffff),
      textMuted: Color(0xc7ffffff),
      highlightText: Color(0xffffffff),
      accentStrong: Color(0xff7fc4ff),
      accentHover: Color(0x2e0078d7),
      iconButtonHover: Color(0x2e0078d7),
      collapsedHover: Color(0x330078d7),
      accentBorder: Color(0x330078d7),
      searchSurface: Color(0x0cffffff),
      focusedSearchSurface: Color(0x240078d7),
      searchBorder: Color(0x1fd6e0ec),
      focusedSearchBorder: Color(0x570078d7),
      searchFocusRing: Color(0x290078d7),
      searchInsetHighlight: Color(0x00ffffff),
      searchPlaceholder: Color(0x94ffffff),
      clearButton: Color(0x290078d7),
      clearForeground: Color(0xffffffff),
      sectionDivider: Color(0x1fd6e0ec),
      sectionLabel: Color(0x94ffffff),
      dropdownSurface: Color(0xfa1d232b),
      dropdownShadow: Color(0x5c000000),
    );
  }
}

class MainNavigationPalette {
  const MainNavigationPalette({
    required this.textStrong,
    required this.textMuted,
    required this.highlightText,
    required this.accentStrong,
    required this.accentHover,
    required this.iconButtonHover,
    required this.collapsedHover,
    required this.accentBorder,
    required this.searchSurface,
    required this.focusedSearchSurface,
    required this.searchBorder,
    required this.focusedSearchBorder,
    required this.searchFocusRing,
    required this.searchInsetHighlight,
    required this.searchPlaceholder,
    required this.clearButton,
    required this.clearForeground,
    required this.sectionDivider,
    required this.sectionLabel,
    required this.dropdownSurface,
    required this.dropdownShadow,
  });

  final Color textStrong;
  final Color textMuted;
  final Color highlightText;
  final Color accentStrong;
  final Color accentHover;
  final Color iconButtonHover;
  final Color collapsedHover;
  final Color accentBorder;
  final Color searchSurface;
  final Color focusedSearchSurface;
  final Color searchBorder;
  final Color focusedSearchBorder;
  final Color searchFocusRing;
  final Color searchInsetHighlight;
  final Color searchPlaceholder;
  final Color clearButton;
  final Color clearForeground;
  final Color sectionDivider;
  final Color sectionLabel;
  final Color dropdownSurface;
  final Color dropdownShadow;
}
