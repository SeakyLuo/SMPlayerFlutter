part of 'popup_dialog.dart';

class PopupDialogTab extends StatelessWidget {
  const PopupDialogTab({
    super.key,
    required this.label,
    required this.selected,
    required this.onPressed,
    this.icon,
    this.iconWidget,
    this.first = false,
    this.last = false,
  });

  final String label;
  final IconData? icon;
  final Widget? iconWidget;
  final bool selected;
  final VoidCallback onPressed;
  final bool first;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final colors = PopupDialogColors.resolve(context);
    final mobile =
        MediaQuery.sizeOf(context).width <= popupDialogMobileBreakpoint;
    final button = TextButton(
      style: TextButton.styleFrom(
        fixedSize: mobile ? null : const Size(138, 40),
        minimumSize: mobile ? const Size(0, 40) : const Size(138, 40),
        maximumSize:
            mobile ? const Size(double.infinity, 40) : const Size(138, 40),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        foregroundColor: selected ? colors.activeButtonText : colors.text,
        backgroundColor:
            selected ? colors.activeButtonSurface : colors.buttonSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(
            left: first ? const Radius.circular(8) : Radius.zero,
            right: last ? const Radius.circular(8) : Radius.zero,
          ),
          side: BorderSide(
            color: selected ? colors.activeButtonBorder : colors.buttonBorder,
          ),
        ),
      ),
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          iconWidget ?? Icon(icon, size: 18),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontVariations: [FontVariation.weight(650)],
              ),
            ),
          ),
        ],
      ),
    );
    if (!mobile) {
      if (first) {
        return SizedBox(width: 138, height: 40, child: button);
      }
      return SizedBox(
        width: 137,
        height: 40,
        child: OverflowBox(
          minWidth: 138,
          maxWidth: 138,
          minHeight: 40,
          maxHeight: 40,
          alignment: Alignment.centerLeft,
          child: Transform.translate(
            offset: const Offset(-1, 0),
            child: button,
          ),
        ),
      );
    }
    return SizedBox(width: double.infinity, height: 40, child: button);
  }
}
