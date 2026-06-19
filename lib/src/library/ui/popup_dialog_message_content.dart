part of 'popup_dialog.dart';

class PopupDialogMessageContent extends StatelessWidget {
  const PopupDialogMessageContent({
    super.key,
    required this.message,
    this.padding = const EdgeInsets.fromLTRB(28, 0, 28, 0),
    this.maxWidth = 420,
  });

  final String message;
  final EdgeInsetsGeometry padding;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final colors = PopupDialogColors.resolve(context);
    return Padding(
      padding: padding,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.text, fontSize: 15, height: 1.55),
          ),
        ),
      ),
    );
  }
}
