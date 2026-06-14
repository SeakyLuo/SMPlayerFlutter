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
    final primaryDestructive = primary && destructive;
    final background =
        primary
            ? primaryDestructive
                ? colors.destructive
                : colors.accent
            : Colors.transparent;
    final foreground = primary ? Colors.white : colors.accentStrong;
    final resolvedForeground =
        onPressed == null
            ? primary
                ? foreground.withValues(alpha: 0.72)
                : colors.textMuted.withValues(alpha: 0.54)
            : foreground;
    final fontFamily = Theme.of(context).textTheme.bodyMedium?.fontFamily;

    return TextButton(
      style: TextButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.standard,
        minimumSize: const Size(88, 36),
        maximumSize: const Size(double.infinity, 36),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        foregroundColor: foreground,
        disabledForegroundColor: foreground.withValues(alpha: 0.72),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          height: 1,
        ).copyWith(fontFamily: fontFamily),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ).copyWith(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return primary
                ? background.withValues(alpha: 0.72)
                : Colors.transparent;
          }
          if (primaryDestructive &&
              (states.contains(WidgetState.hovered) ||
                  states.contains(WidgetState.pressed))) {
            return PopupDialogColors.destructiveHover;
          }
          if (primary &&
              (states.contains(WidgetState.hovered) ||
                  states.contains(WidgetState.pressed))) {
            return PopupDialogColors.accentStrong;
          }
          return background;
        }),
        side: const WidgetStatePropertyAll(BorderSide.none),
        elevation: const WidgetStatePropertyAll(0),
        shadowColor: const WidgetStatePropertyAll(Colors.transparent),
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return Colors.transparent;
          }
          if (primary) {
            return Colors.transparent;
          }
          return colors.accent.withValues(alpha: 0.10);
        }),
      ),
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (loading) ...[
            SizedBox.square(
              dimension: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
                backgroundColor: Colors.white.withValues(alpha: 0.42),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Text(
            label,
            style: TextStyle(
              color: resolvedForeground,
              fontFamily: fontFamily,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
            textHeightBehavior: const TextHeightBehavior(
              applyHeightToFirstAscent: false,
              applyHeightToLastDescent: false,
            ),
          ),
        ],
      ),
    );
  }
}
