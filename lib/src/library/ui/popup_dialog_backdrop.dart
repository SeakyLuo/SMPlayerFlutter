part of 'popup_dialog.dart';

class _PopupDialogBackdrop extends StatelessWidget {
  const _PopupDialogBackdrop({required this.colors, required this.child});

  final PopupDialogResolvedColors colors;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      key: const ValueKey('popup-dialog-overlay'),
      child: ClipRect(
        child: BackdropFilter(
          key: const ValueKey('popup-dialog-overlay-blur'),
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: ColoredBox(color: colors.overlay, child: child),
        ),
      ),
    );
  }
}
