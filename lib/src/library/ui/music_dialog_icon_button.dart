part of 'music_dialog.dart';

class _MusicDialogIconButton extends StatelessWidget {
  const _MusicDialogIconButton({
    super.key,
    required this.onPressed,
    required this.iconWidget,
    this.tooltip,
    this.size = 42,
    this.iconSize = 16,
    this.disabled = false,
  });

  final Widget iconWidget;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final double iconSize;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final colors = PopupDialogColors.resolve(context);
    final nightMode = Theme.of(context).brightness == Brightness.dark;
    final foreground =
        disabled ? colors.textMuted.withValues(alpha: 0.48) : colors.text;
    final background = disabled ? colors.buttonSurface : colors.buttonSurface;
    final hoverBackground =
        disabled
            ? background
            : nightMode
            ? GlobalUI.buttonHoverBgColorNight
            : GlobalUI.buttonHoverBgColorDay;
    final button = IconButton(
      style: IconButton.styleFrom(
        fixedSize: Size(size, size == 42 ? 40 : size),
        minimumSize: Size(size, size == 42 ? 40 : size),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: foreground,
        disabledForegroundColor: foreground,
        backgroundColor: background,
        disabledBackgroundColor: background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: colors.buttonBorder),
        ),
        shadowColor: Colors.transparent,
      ).copyWith(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.focused)) {
            return hoverBackground;
          }
          return background;
        }),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      icon: iconWidget,
      onPressed: disabled ? null : onPressed,
    ).withDialogButtonShadow(colors.buttonShadow, radius: 8);
    final message = tooltip;
    if (message == null) {
      return button;
    }
    return Tooltip(message: message, child: button);
  }
}
