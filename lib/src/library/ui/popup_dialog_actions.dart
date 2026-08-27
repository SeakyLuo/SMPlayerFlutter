part of 'popup_dialog.dart';

class PopupDialogActions extends StatelessWidget {
  const PopupDialogActions({
    super.key,
    required this.children,
    this.compact = false,
  });

  final List<Widget> children;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          compact
              ? const EdgeInsets.only(top: 20)
              : const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 18,
        runSpacing: 10,
        children: children,
      ),
    );
  }
}

class PopupDialogActionButton extends StatelessWidget {
  const PopupDialogActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.primary = false,
    this.destructive = false,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool primary;
  final bool destructive;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final colors = PopupDialogColors.resolve(context);
    if (!primary) {
      return SmPlayerTextIconButton(
        label: label,
        loading: loading,
        disabled: onPressed == null,
        onPressed: onPressed,
        minWidth: 88,
        height: 36,
        horizontalPadding: 16,
        fontSize: 16,
        fontWeight: FontWeight.w700,
        fontVariations: const [],
        glassEnabled: false,
      );
    }

    return SmPlayerTextIconButtonTheme(
      colors: _popupDialogActionButtonColors(
        colors,
        primary: primary,
        destructive: destructive,
      ),
      child: SmPlayerTextIconButton(
        label: label,
        loading: loading,
        disabled: onPressed == null,
        onPressed: onPressed,
        minWidth: 88,
        height: 36,
        horizontalPadding: 16,
        fontSize: 16,
        fontWeight: FontWeight.w700,
        fontVariations: const [],
        glassEnabled: false,
      ),
    );
  }
}

SmPlayerTextIconButtonColors _popupDialogActionButtonColors(
  PopupDialogResolvedColors colors, {
  required bool primary,
  required bool destructive,
}) {
  if (primary && destructive) {
    return SmPlayerTextIconButtonColors(
      commandText: Colors.white,
      commandTextHover: Colors.white,
      control: colors.destructive,
      controlHover: PopupDialogColors.destructiveHover,
      controlHoverBorder: PopupDialogColors.destructiveHover,
      controlActive: PopupDialogColors.destructiveHover,
      controlBorder: colors.destructive,
      accentStrong: Colors.white,
    );
  }
  if (primary) {
    return SmPlayerTextIconButtonColors(
      commandText: Colors.white,
      commandTextHover: Colors.white,
      control: colors.accent,
      controlHover: colors.accentStrong,
      controlHoverBorder: colors.accentStrong,
      controlActive: colors.accentStrong,
      controlBorder: colors.accent,
      accentStrong: Colors.white,
    );
  }
  return SmPlayerTextIconButtonColors(
    commandText: colors.accentStrong,
    commandTextHover: colors.accentStrong,
    control: colors.buttonSurface,
    controlHover: colors.buttonHoverSurface,
    controlHoverBorder: colors.buttonBorder,
    controlActive: colors.activeButtonSurface,
    controlBorder: colors.buttonBorder,
    accentStrong: colors.accentStrong,
  );
}
