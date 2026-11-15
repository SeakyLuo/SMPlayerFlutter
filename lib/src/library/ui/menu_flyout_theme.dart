part of 'menu_flyout.dart';

class MenuFlyoutThemeColors extends ThemeExtension<MenuFlyoutThemeColors> {
  const MenuFlyoutThemeColors({
    required this.surface,
    required this.border,
    required this.shadow,
    required this.text,
    required this.hoverText,
    required this.disabledText,
    required this.hoverSurface,
    required this.checked,
    required this.separator,
  });

  final Color surface;
  final Color border;
  final Color shadow;
  final Color text;
  final Color hoverText;
  final Color disabledText;
  final Color hoverSurface;
  final Color checked;
  final Color separator;

  static const light = MenuFlyoutThemeColors(
    surface: Color(0x48ffffff),
    border: Color(0x337e8b9a),
    shadow: Color(0x2e263344),
    text: Color(0xff1f252b),
    hoverText: Color(0xff0063b1),
    disabledText: Color(0x751f252b),
    hoverSurface: GlobalUI.selectedBgColorDay,
    checked: Color(0xff0063b1),
    separator: Color(0x5c5b697a),
  );

  static const dark = MenuFlyoutThemeColors(
    surface: Color(0x54181e26),
    border: Color(0x30d6e0ec),
    shadow: Color(0x5c000000),
    text: Colors.white,
    hoverText: Colors.white,
    disabledText: Color(0x8fffffff),
    hoverSurface: GlobalUI.selectedBgColorNight,
    checked: Colors.white,
    separator: Color(0x52ffffff),
  );

  static MenuFlyoutThemeColors of(BuildContext context) {
    return Theme.of(context).extension<MenuFlyoutThemeColors>() ?? light;
  }

  @override
  MenuFlyoutThemeColors copyWith() {
    return this;
  }

  @override
  MenuFlyoutThemeColors lerp(
    ThemeExtension<MenuFlyoutThemeColors>? other,
    double t,
  ) {
    return t < 0.5 || other is! MenuFlyoutThemeColors ? this : other;
  }
}
