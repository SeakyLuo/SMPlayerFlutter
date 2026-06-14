part of 'page_search_history_panel.dart';

class AppBarPageSearchCloseButton extends StatefulWidget {
  const AppBarPageSearchCloseButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
  });

  final String tooltip;
  final VoidCallback onPressed;

  @override
  State<AppBarPageSearchCloseButton> createState() =>
      _AppBarPageSearchCloseButtonState();
}

class _AppBarPageSearchCloseButtonState
    extends State<AppBarPageSearchCloseButton> {
  var _hovered = false;
  var _pressed = false;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final foreground =
        dark
            ? CommandBarColors.appBarForegroundDark
            : CommandBarColors.appBarForeground;
    final hover =
        dark ? CommandBarColors.appBarHoverDark : CommandBarColors.appBarHover;
    final pressed =
        dark
            ? CommandBarColors.appBarPressedDark
            : CommandBarColors.appBarPressed;
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) {
          setState(() {
            _hovered = true;
          });
        },
        onExit: (_) {
          setState(() {
            _hovered = false;
            _pressed = false;
          });
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) {
            setState(() {
              _pressed = true;
            });
          },
          onTapCancel: () {
            setState(() {
              _pressed = false;
            });
          },
          onTapUp: (_) {
            setState(() {
              _pressed = false;
            });
          },
          onTap: widget.onPressed,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color:
                  _pressed
                      ? pressed
                      : _hovered
                      ? hover
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: SizedBox.square(
              dimension: 36,
              child: Center(
                child: Icon(
                  FluentIcons.dismiss_20_regular,
                  size: 18,
                  color: foreground,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
