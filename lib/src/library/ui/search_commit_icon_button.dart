import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';

class SearchCommitIconButton extends StatefulWidget {
  const SearchCommitIconButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
    required this.foreground,
    required this.hoverForeground,
    this.hoverBackground = Colors.transparent,
    this.borderRadius = 0,
  });

  static const lightForeground = Color(0xff5f625f);
  static const darkForeground = Color(0xadcbd5e1);
  static const lightHoverForeground = Color(0xff0063b1);
  static const darkHoverForeground = Color(0xff459de2);
  static const transparentHoverBackground = Colors.transparent;

  static Color foregroundFor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkForeground
        : lightForeground;
  }

  static Color hoverForegroundFor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkHoverForeground
        : lightHoverForeground;
  }

  final String tooltip;
  final VoidCallback onPressed;
  final Color foreground;
  final Color hoverForeground;
  final Color hoverBackground;
  final double borderRadius;

  @override
  State<SearchCommitIconButton> createState() => _SearchCommitIconButtonState();
}

class _SearchCommitIconButtonState extends State<SearchCommitIconButton> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: Semantics(
        button: true,
        label: widget.tooltip,
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
                  FluentIcons.search_24_regular,
                  size: 19,
                  color: _hovered ? widget.hoverForeground : widget.foreground,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
