part of 'popup_dialog.dart';

Future<T?> showScopedPopupDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  final container = ProviderScope.containerOf(context, listen: false);
  return showDialog<T>(
    context: context,
    barrierColor: Colors.transparent,
    barrierDismissible: false,
    builder:
        (context) => UncontrolledProviderScope(
          container: container,
          child: Builder(builder: builder),
        ),
  );
}
