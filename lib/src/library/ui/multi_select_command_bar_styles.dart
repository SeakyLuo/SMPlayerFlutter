part of 'multi_select_command_bar.dart';

const multiSelectCommandBarScrollSpacer = 108.0;
const multiSelectCommandBarShellBottomInset = 17.0;
const multiSelectCommandBarHiddenSlideFraction = 16.0 / 64.0;
const multiSelectCommandBarLayoutAnimationDuration = Duration(
  milliseconds: 160,
);
const multiSelectCommandBarVisibilityAnimationDuration = Duration(
  milliseconds: 180,
);
const multiSelectCommandBarBackdropSaturation = 1.65;
const multiSelectCommandBarBackdropSaturationMatrix = <double>[
  1.51155,
  -0.46475,
  -0.0468,
  0,
  0,
  -0.13845,
  1.18525,
  -0.0468,
  0,
  0,
  -0.13845,
  -0.46475,
  1.6032,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
];
final multiSelectCommandBarBackdropFilter = ImageFilter.compose(
  outer: const ColorFilter.matrix(
    multiSelectCommandBarBackdropSaturationMatrix,
  ),
  inner: ImageFilter.blur(sigmaX: 46, sigmaY: 46),
);
const multiSelectCommandBarGlassOverlayOpacity = 0.08;

class _MultiSelectCommandBarStyle {
  const _MultiSelectCommandBarStyle({
    required this.surface,
    required this.gradient,
    required this.border,
    required this.insetHighlight,
    required this.shadow,
    required this.separator,
    required this.actionSurface,
    required this.actionHoverSurface,
    required this.actionBorder,
    required this.actionHoverBorder,
    required this.actionForeground,
    required this.actionHoverForeground,
    required this.actionShadow,
    required this.actionHoverShadow,
    required this.actionDisabledShadow,
    required this.accent,
  });

  final Color surface;
  final List<Color> gradient;
  final Color border;
  final Color insetHighlight;
  final Color shadow;
  final Color separator;
  final Color actionSurface;
  final Color actionHoverSurface;
  final Color actionBorder;
  final Color actionHoverBorder;
  final Color actionForeground;
  final Color actionHoverForeground;
  final List<BoxShadow> actionShadow;
  final List<BoxShadow> actionHoverShadow;
  final List<BoxShadow> actionDisabledShadow;
  final Color accent;

  static const day = _MultiSelectCommandBarStyle(
    surface: CommandBarColors.multiSelectSurface,
    gradient: [
      CommandBarColors.multiSelectGradientTop,
      CommandBarColors.multiSelectGradientBottom,
    ],
    border: CommandBarColors.multiSelectBorder,
    insetHighlight: CommandBarColors.multiSelectInsetHighlight,
    shadow: CommandBarColors.multiSelectShadow,
    separator: CommandBarColors.separator,
    actionSurface: CommandBarColors.actionSurface,
    actionHoverSurface: CommandBarColors.actionHoverSurface,
    actionBorder: CommandBarColors.actionBorder,
    actionHoverBorder: CommandBarColors.actionHoverBorder,
    actionForeground: CommandBarColors.textStrong,
    actionHoverForeground: CommandBarColors.accentStrong,
    actionShadow: [
      BoxShadow(color: Color(0x0d182230), blurRadius: 2, offset: Offset(0, 1)),
      BoxShadow(color: Color(0xb3ffffff), blurRadius: 0, offset: Offset(0, 1)),
    ],
    actionHoverShadow: [
      BoxShadow(color: Color(0x1a3a5376), blurRadius: 10, offset: Offset(0, 3)),
      BoxShadow(color: Color(0xc7ffffff), blurRadius: 0, offset: Offset(0, 1)),
    ],
    actionDisabledShadow: [
      BoxShadow(color: Color(0x9effffff), blurRadius: 0, offset: Offset(0, 1)),
    ],
    accent: CommandBarColors.accentStrong,
  );

  static const night = _MultiSelectCommandBarStyle(
    surface: CommandBarColors.multiSelectNightSurface,
    gradient: [
      CommandBarColors.multiSelectNightGradientTop,
      CommandBarColors.multiSelectNightGradientBottom,
    ],
    border: CommandBarColors.multiSelectNightBorder,
    insetHighlight: CommandBarColors.multiSelectNightInsetHighlight,
    shadow: CommandBarColors.multiSelectNightShadow,
    separator: CommandBarColors.separatorNight,
    actionSurface: CommandBarColors.actionNightSurface,
    actionHoverSurface: CommandBarColors.actionNightHoverSurface,
    actionBorder: CommandBarColors.actionNightBorder,
    actionHoverBorder: CommandBarColors.actionNightHoverBorder,
    actionForeground: CommandBarColors.textNight,
    actionHoverForeground: CommandBarColors.accentStrongNight,
    actionShadow: [
      BoxShadow(color: Color(0x0effffff), blurRadius: 0, offset: Offset(0, 1)),
    ],
    actionHoverShadow: [],
    actionDisabledShadow: [
      BoxShadow(color: Color(0x0effffff), blurRadius: 0, offset: Offset(0, 1)),
    ],
    accent: CommandBarColors.accentStrongNight,
  );

  static _MultiSelectCommandBarStyle forBrightness(Brightness brightness) {
    return brightness == Brightness.dark ? night : day;
  }
}

class _MultiSelectCommandBarBorderPainter extends CustomPainter {
  const _MultiSelectCommandBarBorderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;
    final path =
        Path()
          ..moveTo(0.5, size.height)
          ..lineTo(0.5, 17)
          ..quadraticBezierTo(0.5, 0.5, 17, 0.5)
          ..lineTo(size.width - 17, 0.5)
          ..quadraticBezierTo(size.width - 0.5, 0.5, size.width - 0.5, 17)
          ..lineTo(size.width - 0.5, size.height);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(
    covariant _MultiSelectCommandBarBorderPainter oldDelegate,
  ) {
    return oldDelegate.color != color;
  }
}
