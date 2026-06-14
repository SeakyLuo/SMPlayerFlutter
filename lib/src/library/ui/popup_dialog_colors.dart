part of 'popup_dialog.dart';

class PopupDialogColors {
  const PopupDialogColors._();

  static const overlay = Color(0x3d181e26);
  static const surface = Color(0xfafbfcff);
  static const border = Color(0x80b9c3d2);
  static const inputBorder = Color(0x94c0cad8);
  static const shadow = Color(0x47232d3c);
  static const buttonSurface = Color(0xebffffff);
  static const activeButtonSurface = Color(0xf5eff6ff);
  static const buttonBorder = Color(0x9ebec8d6);
  static const activeButtonBorder = Color(0x610078d7);
  static const accent = Color(0xff0078d7);
  static const accentStrong = Color(0xff0063b1);
  static const accentSoft = Color(0x290078d7);
  static const text = Color(0xff5f625f);
  static const textStrong = Color(0xff1f252b);
  static const textMuted = Color(0xff5f625f);
  static const fieldSurface = Color(0xe6ffffff);
  static const fieldDisabledSurface = Color(0xade6ebf3);
  static const focusRing = Color(0x290078d7);
  static const destructive = Color(0xffd13438);
  static const destructiveHover = Color(0xffa4262c);
  static const nightOverlay = Color(0x9e04080d);
  static const nightSurface = Color(0xfa161c24);
  static const nightBorder = Color(0x1fd6e0ec);
  static const nightInputBorder = Color(0x1fd6e0ec);
  static const nightShadow = Color(0x7a000000);
  static const nightButtonSurface = Color(0x11ffffff);
  static const nightActiveButtonSurface = Color(0x2e0078d7);
  static const nightButtonBorder = Color(0x1fd6e0ec);
  static const nightActiveButtonBorder = Color(0x610078d7);
  static const nightActiveText = Color(0xff459de2);
  static const nightText = Color(0xebffffff);
  static const nightTextStrong = Color(0xfff8fafc);
  static const nightTextMuted = Color(0xadcbd5e1);
  static const nightFieldSurface = Color(0x11ffffff);
  static const nightFieldDisabledSurface = Color(0x0affffff);

  static PopupDialogResolvedColors resolve(BuildContext context) {
    return Theme.of(context).extension<PopupDialogResolvedColors>() ??
        PopupDialogResolvedColors.light;
  }
}

class PopupDialogResolvedColors
    extends ThemeExtension<PopupDialogResolvedColors> {
  const PopupDialogResolvedColors({
    required this.overlay,
    required this.surface,
    required this.border,
    required this.inputBorder,
    required this.shadow,
    required this.buttonSurface,
    required this.activeButtonSurface,
    required this.buttonHoverSurface,
    required this.mobileBackHoverSurface,
    required this.mobileBackActiveSurface,
    required this.buttonText,
    required this.buttonHoverText,
    required this.activeButtonText,
    required this.buttonBorder,
    required this.activeButtonBorder,
    required this.buttonShadow,
    required this.accent,
    required this.accentStrong,
    required this.text,
    required this.textStrong,
    required this.textMuted,
    required this.fieldDisabledText,
    required this.fieldSurface,
    required this.fieldDisabledSurface,
    required this.focusRing,
    required this.destructive,
  });

  final Color overlay;
  final Color surface;
  final Color border;
  final Color inputBorder;
  final Color shadow;
  final Color buttonSurface;
  final Color activeButtonSurface;
  final Color buttonHoverSurface;
  final Color mobileBackHoverSurface;
  final Color mobileBackActiveSurface;
  final Color buttonText;
  final Color buttonHoverText;
  final Color activeButtonText;
  final Color buttonBorder;
  final Color activeButtonBorder;
  final List<BoxShadow> buttonShadow;
  final Color accent;
  final Color accentStrong;
  final Color text;
  final Color textStrong;
  final Color textMuted;
  final Color fieldDisabledText;
  final Color fieldSurface;
  final Color fieldDisabledSurface;
  final Color focusRing;
  final Color destructive;

  static const light = PopupDialogResolvedColors(
    overlay: PopupDialogColors.overlay,
    surface: PopupDialogColors.surface,
    border: PopupDialogColors.border,
    inputBorder: PopupDialogColors.inputBorder,
    shadow: PopupDialogColors.shadow,
    buttonSurface: PopupDialogColors.buttonSurface,
    activeButtonSurface: PopupDialogColors.activeButtonSurface,
    buttonHoverSurface: Color(0xfaf7fafe),
    mobileBackHoverSurface: Color(0x12111827),
    mobileBackActiveSurface: Color(0x1f0078d7),
    buttonText: PopupDialogColors.text,
    buttonHoverText: PopupDialogColors.text,
    activeButtonText: PopupDialogColors.accent,
    buttonBorder: PopupDialogColors.buttonBorder,
    activeButtonBorder: PopupDialogColors.activeButtonBorder,
    buttonShadow: [
      BoxShadow(color: Color(0x0f28374c), offset: Offset(0, 8), blurRadius: 18),
    ],
    accent: PopupDialogColors.accent,
    accentStrong: PopupDialogColors.accentStrong,
    text: PopupDialogColors.text,
    textStrong: PopupDialogColors.textStrong,
    textMuted: PopupDialogColors.textMuted,
    fieldDisabledText: Color(0xd1535d6c),
    fieldSurface: PopupDialogColors.fieldSurface,
    fieldDisabledSurface: PopupDialogColors.fieldDisabledSurface,
    focusRing: PopupDialogColors.focusRing,
    destructive: PopupDialogColors.destructive,
  );

  static const dark = PopupDialogResolvedColors(
    overlay: PopupDialogColors.nightOverlay,
    surface: PopupDialogColors.nightSurface,
    border: PopupDialogColors.nightBorder,
    inputBorder: PopupDialogColors.nightInputBorder,
    shadow: PopupDialogColors.nightShadow,
    buttonSurface: PopupDialogColors.nightButtonSurface,
    activeButtonSurface: PopupDialogColors.nightActiveButtonSurface,
    buttonHoverSurface: Color(0x290078d7),
    mobileBackHoverSurface: Color(0x14ffffff),
    mobileBackActiveSurface: Color(0x1f0078d7),
    buttonText: PopupDialogColors.nightText,
    buttonHoverText: PopupDialogColors.nightActiveText,
    activeButtonText: PopupDialogColors.nightActiveText,
    buttonBorder: PopupDialogColors.nightButtonBorder,
    activeButtonBorder: PopupDialogColors.nightActiveButtonBorder,
    buttonShadow: [],
    accent: PopupDialogColors.accent,
    accentStrong: Color(0xff66b7ff),
    text: PopupDialogColors.nightText,
    textStrong: PopupDialogColors.nightTextStrong,
    textMuted: PopupDialogColors.nightTextMuted,
    fieldDisabledText: PopupDialogColors.nightTextMuted,
    fieldSurface: PopupDialogColors.nightFieldSurface,
    fieldDisabledSurface: PopupDialogColors.nightFieldDisabledSurface,
    focusRing: Color(0x330078d7),
    destructive: PopupDialogColors.destructive,
  );

  @override
  PopupDialogResolvedColors copyWith() {
    return this;
  }

  @override
  PopupDialogResolvedColors lerp(
    ThemeExtension<PopupDialogResolvedColors>? other,
    double t,
  ) {
    return t < 0.5 || other is! PopupDialogResolvedColors ? this : other;
  }
}
