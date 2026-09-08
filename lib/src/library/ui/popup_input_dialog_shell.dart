part of 'popup_dialog.dart';

class _InputDialogShell extends StatelessWidget {
  const _InputDialogShell({
    required this.ariaLabel,
    required this.child,
    required this.onClose,
    required this.footer,
    this.canClose = true,
  });
  final String ariaLabel;
  final Widget child;
  final Widget footer;
  final VoidCallback onClose;
  final bool canClose;
  @override
  Widget build(BuildContext context) => PopupDialog(
    navLabel: ariaLabel,
    onClose: onClose,
    canClose: canClose,
    fitContent: true,
    fullScreenOnNarrow: false,
    width: 480,
    navChildren: [Expanded(child: PopupDialogTitle(ariaLabel))],
    footer: footer,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
      child: child,
    ),
  );
}

class PopupDialogTitle extends StatelessWidget {
  const PopupDialogTitle(this.text, {super.key, this.centered = false});

  final String text;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final colors = PopupDialogColors.resolve(context);
    final mobile =
        MediaQuery.sizeOf(context).width <= popupDialogMobileBreakpoint;
    return Text(
      text,
      textAlign: centered ? TextAlign.center : TextAlign.start,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: colors.textStrong,
        fontSize: mobile ? 18 : 22,
        fontWeight: FontWeight.w500,
        height: 1.25,
      ),
    );
  }
}
