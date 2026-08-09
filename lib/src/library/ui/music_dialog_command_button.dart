part of 'music_dialog.dart';

class _MusicDialogCommandButton extends StatelessWidget {
  const _MusicDialogCommandButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.iconWidget,
    this.primary = false,
    this.disabled = false,
    this.commandBar = false,
    this.compact = false,
    this.showLabel = true,
    this.canOverflow = true,
  });

  final String label;
  final IconData? icon;
  final Widget? iconWidget;
  final bool primary;
  final bool disabled;
  final bool commandBar;
  final bool compact;
  final bool showLabel;
  final bool canOverflow;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = PopupDialogColors.resolve(context);
    final nightMode = Theme.of(context).brightness == Brightness.dark;
    final commandBarSurface =
        nightMode ? const Color(0x0effffff) : CommandBarColors.buttonSurface;
    final commandBarHoverSurface =
        nightMode
            ? GlobalUI.buttonHoverBgColorNight
            : GlobalUI.buttonHoverBgColorDay;
    final commandBarBorder =
        nightMode ? colors.buttonBorder : CommandBarColors.buttonBorder;
    final primaryDisabledForeground =
        nightMode ? const Color(0xb8e2e8f0) : const Color(0xb85e6773);
    final primaryDisabledBackground =
        nightMode ? const Color(0x24ffffff) : const Color(0xc7e6ebf3);
    final primaryDisabledBorder =
        nightMode ? const Color(0x2e94a3b8) : const Color(0x619ba6b6);
    final commandBarDisabled = commandBar && disabled;
    final foreground =
        disabled
            ? primary
                ? primaryDisabledForeground
                : commandBar
                ? colors.textStrong
                : colors.buttonText
            : primary
            ? Colors.white
            : commandBar
            ? colors.textStrong
            : colors.buttonText;
    final hoverForeground = primary ? foreground : foreground;
    final background =
        disabled
            ? primary
                ? primaryDisabledBackground
                : commandBar
                ? commandBarSurface
                : colors.buttonSurface
            : primary
            ? colors.accent
            : commandBar
            ? commandBarSurface
            : colors.buttonSurface;
    final hoverBackground =
        primary && !disabled
            ? PopupDialogColors.accentStrong
            : disabled
            ? background
            : commandBar
            ? commandBarHoverSurface
            : nightMode
            ? GlobalUI.buttonHoverBgColorNight
            : colors.buttonHoverSurface;
    final borderColor =
        primary && disabled
            ? primaryDisabledBorder
            : primary
            ? colors.accent.withValues(alpha: 0.52)
            : commandBar
            ? commandBarBorder
            : colors.buttonBorder;
    final shadow =
        primary && !disabled
            ? [
              BoxShadow(
                color: colors.accent.withValues(alpha: 0.26),
                offset: const Offset(0, 10),
                blurRadius: 22,
              ),
            ]
            : commandBar
            ? const <BoxShadow>[]
            : colors.buttonShadow;
    final buttonHeight = compact ? 38.0 : 40.0;
    final buttonMinWidth = commandBar ? 44.0 : 0.0;
    final mobile =
        MediaQuery.sizeOf(context).width <= popupDialogMobileBreakpoint;
    final horizontalPadding =
        !showLabel
            ? 0.0
            : (compact ? 12.0 : (commandBar ? (mobile ? 10.0 : 14.0) : 18.0));

    final button = TextButton(
      style: TextButton.styleFrom(
        minimumSize: Size(buttonMinWidth, buttonHeight),
        fixedSize:
            !showLabel && commandBar
                ? Size(buttonMinWidth, buttonHeight)
                : null,
        maximumSize: Size(double.infinity, buttonHeight),
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: foreground,
        disabledForegroundColor: foreground,
        backgroundColor: background,
        disabledBackgroundColor: background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(commandBar ? 10 : 8),
          side: BorderSide(color: borderColor),
        ),
      ).copyWith(
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return foreground;
          }
          if (states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.focused)) {
            return hoverForeground;
          }
          return foreground;
        }),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.focused)) {
            return hoverBackground;
          }
          return background;
        }),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      onPressed: disabled ? null : onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon case final IconData icon) ...[
            Icon(icon, size: 20),
            if (showLabel) const SizedBox(width: 8),
          ],
          if (iconWidget case final Widget iconWidget) ...[
            iconWidget,
            if (showLabel) const SizedBox(width: 8),
          ],
          if (showLabel)
            Text(
              label,
              style: TextStyle(
                fontSize: commandBar ? 14 : 16,
                fontWeight: commandBar ? FontWeight.w700 : FontWeight.w600,
                fontVariations: [FontVariation.weight(commandBar ? 720 : 650)],
              ),
            ),
        ],
      ),
    );
    final styledButton = button
        .withCommandButtonInsetHighlight(
          commandBar && !primary && !disabled && !nightMode
              ? const Color(0x6bffffff)
              : null,
          radius: commandBar ? 10 : 8,
        )
        .withDialogButtonShadow(shadow, radius: commandBar ? 10 : 8);
    final resolvedButton =
        commandBarDisabled
            ? Opacity(opacity: 0.45, child: styledButton)
            : styledButton;
    if (commandBar) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: resolvedButton,
      );
    }
    return resolvedButton;
  }
}

class _MusicDialogButtonInsetHighlight extends StatelessWidget {
  const _MusicDialogButtonInsetHighlight({
    required this.child,
    required this.color,
    required this.radius,
  });

  final Widget child;
  final Color color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned(
          left: 1,
          right: 1,
          top: 1,
          height: 1,
          child: IgnorePointer(
            child: DecoratedBox(
              key: const ValueKey('MusicDialog.CommandButtonInsetHighlight'),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(radius - 1),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

extension _MusicDialogButtonShadow on Widget {
  Widget withCommandButtonInsetHighlight(
    Color? color, {
    required double radius,
  }) {
    if (color == null) {
      return this;
    }
    return _MusicDialogButtonInsetHighlight(
      color: color,
      radius: radius,
      child: this,
    );
  }

  Widget withDialogButtonShadow(
    List<BoxShadow> shadow, {
    required double radius,
  }) {
    if (shadow.isEmpty) {
      return this;
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: shadow,
      ),
      child: this,
    );
  }
}
