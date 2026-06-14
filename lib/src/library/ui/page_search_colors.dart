part of 'page_search_history_panel.dart';

class _PageSearchColors {
  const _PageSearchColors({
    required this.searchSurface,
    required this.focusedSurface,
    required this.border,
    required this.focusedBorder,
    required this.focusRing,
    required this.insetHighlight,
    required this.placeholder,
    required this.iconButtonHover,
    required this.dropdownSurface,
    required this.dropdownBorder,
    required this.dropdownShadow,
    required this.header,
    required this.accent,
    required this.textStrong,
    required this.textMuted,
    required this.rowHover,
  });

  final Color searchSurface;
  final Color focusedSurface;
  final Color border;
  final Color focusedBorder;
  final Color focusRing;
  final Color insetHighlight;
  final Color placeholder;
  final Color iconButtonHover;
  final Color dropdownSurface;
  final Color dropdownBorder;
  final Color dropdownShadow;
  final Color header;
  final Color accent;
  final Color textStrong;
  final Color textMuted;
  final Color rowHover;

  static const light = _PageSearchColors(
    searchSurface: Color(0x090d1826),
    focusedSurface: Color(0xffffffff),
    border: Color(0x24536379),
    focusedBorder: Color(0x7a0078d7),
    focusRing: Color(0x1a0078d7),
    insetHighlight: Color(0x61ffffff),
    placeholder: Color(0x9e3d4958),
    iconButtonHover: Color(0x120078d7),
    dropdownSurface: Color(0x74ffffff),
    dropdownBorder: Color(0x3d7e8b9a),
    dropdownShadow: Color(0x1a35495f),
    header: Color(0x945f625f),
    accent: SearchCommitIconButton.lightHoverForeground,
    textStrong: Color(0xff1f252b),
    textMuted: SearchCommitIconButton.lightForeground,
    rowHover: Color(0x1a0078d7),
  );

  static const dark = _PageSearchColors(
    searchSurface: Color(0x0effffff),
    focusedSurface: Color(0x240078d7),
    border: Color(0x1fd6e0ec),
    focusedBorder: Color(0x800078d7),
    focusRing: Color(0x240078d7),
    insetHighlight: Color(0x0effffff),
    placeholder: Color(0xadcbd5e1),
    iconButtonHover: Color(0x240078d7),
    dropdownSurface: Color(0x7a181e26),
    dropdownBorder: Color(0x38d6e0ec),
    dropdownShadow: Color(0x42000000),
    header: Color(0x9ecbd5e1),
    accent: Color(0xff7fc4ff),
    textStrong: Color(0xebffffff),
    textMuted: Color(0xc7ffffff),
    rowHover: SmPlayerInteractionColors.hoverSurfaceDark,
  );

  static _PageSearchColors resolve(
    BuildContext context, {
    required bool appBar,
  }) {
    if (Theme.of(context).brightness == Brightness.dark) {
      return dark;
    }
    return light;
  }
}

class _ElectronSearchHistoryPanelColors {
  const _ElectronSearchHistoryPanelColors({
    required this.background,
    required this.border,
    required this.shadow,
  });

  final Color background;
  final Color border;
  final Color shadow;

  static const light = _ElectronSearchHistoryPanelColors(
    background: Color(0xf5f4f6f9),
    border: Color(0x24536379),
    shadow: Color(0x2935495f),
  );

  static const dark = _ElectronSearchHistoryPanelColors(
    background: Color(0xfa1d232b),
    border: Color(0x1fd6e0ec),
    shadow: Color(0x5c000000),
  );

  static _ElectronSearchHistoryPanelColors resolve(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? dark : light;
  }
}
