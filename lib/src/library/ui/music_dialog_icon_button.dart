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
    return SmPlayerTextIconButtonTheme(
      colors: SmPlayerTextIconButtonColors(
        commandText: foreground,
        commandTextHover: foreground,
        control: background,
        controlHover: hoverBackground,
        controlHoverBorder: colors.buttonBorder,
        controlActive: hoverBackground,
        controlBorder: colors.buttonBorder,
        accentStrong: foreground,
      ),
      child: SmPlayerTextIconButton(
        label: tooltip ?? '',
        tooltip: tooltip,
        tooltipEnabled: tooltip != null,
        showLabel: false,
        iconWidget: iconWidget,
        onPressed: onPressed,
        disabled: disabled,
        minWidth: size,
        height: size == 42 ? 40 : size,
        iconSize: iconSize,
        borderRadius: 8,
        opacityWhenDisabled: 1,
        glassEnabled: false,
      ).withDialogButtonShadow(colors.buttonShadow, radius: 8),
    );
  }
}
