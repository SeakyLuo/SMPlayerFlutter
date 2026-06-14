part of 'page_search_history_panel.dart';

class _PageSearchTextButton extends StatefulWidget {
  const _PageSearchTextButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  State<_PageSearchTextButton> createState() => _PageSearchTextButtonState();
}

class _PageSearchTextButtonState extends State<_PageSearchTextButton> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final colors = _PageSearchColors.resolve(context, appBar: false);
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) {
        setState(() {
          _hovered = true;
        });
      },
      onExit: (_) {
        setState(() {
          _hovered = false;
        });
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        child: SizedBox(
          height: 30,
          child: Center(
            child: Text(
              widget.label,
              style: TextStyle(
                color: _hovered && enabled ? colors.accent : colors.header,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PageSearchIconButton extends StatefulWidget {
  const _PageSearchIconButton({
    required this.icon,
    required this.iconSize,
    required this.borderRadius,
    required this.onPressed,
    this.tooltip,
    this.hoverBackground = Colors.transparent,
    this.foreground = const Color(0xff5f625f),
    this.hoverForeground = const Color(0xff0063b1),
  });

  final IconData icon;
  final double iconSize;
  final double borderRadius;
  final VoidCallback onPressed;
  final String? tooltip;
  final Color hoverBackground;
  final Color foreground;
  final Color hoverForeground;

  @override
  State<_PageSearchIconButton> createState() => _PageSearchIconButtonState();
}

class _PageSearchIconButtonState extends State<_PageSearchIconButton> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final button = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        setState(() {
          _hovered = true;
        });
      },
      onExit: (_) {
        setState(() {
          _hovered = false;
        });
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _hovered ? widget.hoverBackground : Colors.transparent,
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
          child: Center(
            child: Icon(
              widget.icon,
              size: widget.iconSize,
              color: _hovered ? widget.hoverForeground : widget.foreground,
            ),
          ),
        ),
      ),
    );
    if (widget.tooltip == null) {
      return button;
    }
    return Tooltip(message: widget.tooltip!, child: button);
  }
}
