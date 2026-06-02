import 'package:flutter/material.dart';

class LocalHoverRegion extends StatefulWidget {
  const LocalHoverRegion({
    super.key,
    required this.builder,
    this.cursor = SystemMouseCursors.click,
  });

  final MouseCursor cursor;
  final Widget Function(BuildContext context, bool hovered, bool focused)
  builder;

  @override
  State<LocalHoverRegion> createState() => _LocalHoverRegionState();
}

class _LocalHoverRegionState extends State<LocalHoverRegion> {
  var _hovered = false;
  var _focused = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.cursor,
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
      child: Focus(
        onFocusChange: (focused) {
          setState(() {
            _focused = focused;
          });
        },
        child: Builder(
          builder: (context) => widget.builder(context, _hovered, _focused),
        ),
      ),
    );
  }
}
