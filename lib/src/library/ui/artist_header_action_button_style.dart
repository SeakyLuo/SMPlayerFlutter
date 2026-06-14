part of 'artists_page.dart';

ButtonStyle _artistHeaderActionButtonStyle(double size, Brightness brightness) {
  final foreground = _ArtistsColors.headerActionForeground(brightness);
  return IconButton.styleFrom(
    fixedSize: Size.square(size),
    minimumSize: Size.square(size),
    maximumSize: Size.square(size),
    padding: EdgeInsets.zero,
    shape: const CircleBorder(),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    visualDensity: VisualDensity.compact,
  ).copyWith(
    foregroundColor: WidgetStateProperty.resolveWith((states) {
      return foreground;
    }),
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.hovered) ||
          states.contains(WidgetState.focused)) {
        return _ArtistsColors.headerActionHoverBackground(brightness);
      }
      return Colors.transparent;
    }),
  );
}
