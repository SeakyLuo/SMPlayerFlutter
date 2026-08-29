import 'package:flutter/material.dart';
import 'package:smplayer_flutter/src/app/auto_hide_scrollbar_visibility.dart';

class SmPlayerAutoHideScrollbar extends StatefulWidget {
  const SmPlayerAutoHideScrollbar({
    super.key,
    required this.controller,
    required this.child,
    this.normalThickness = 5,
    this.hoverThickness = 7,
    this.crossAxisMargin = 0,
    this.mainAxisMargin = 0,
  });

  final ScrollController controller;
  final Widget child;
  final double normalThickness;
  final double hoverThickness;
  final double crossAxisMargin;
  final double mainAxisMargin;

  @override
  State<SmPlayerAutoHideScrollbar> createState() =>
      _SmPlayerAutoHideScrollbarState();
}

class _SmPlayerAutoHideScrollbarState extends State<SmPlayerAutoHideScrollbar>
    with AutoHideScrollbarVisibility {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(showAutoHideScrollbar);
  }

  @override
  void didUpdateWidget(SmPlayerAutoHideScrollbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) {
      return;
    }
    oldWidget.controller.removeListener(showAutoHideScrollbar);
    widget.controller.addListener(showAutoHideScrollbar);
  }

  @override
  void dispose() {
    widget.controller.removeListener(showAutoHideScrollbar);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final thumb = dark ? const Color(0x5cd0dbe8) : const Color(0x705b697a);
    final hoverThumb = dark ? const Color(0x94dee7f2) : const Color(0xa6435060);
    return ScrollbarTheme(
      data: ScrollbarTheme.of(context).copyWith(
        thumbVisibility: const WidgetStatePropertyAll(true),
        trackVisibility: const WidgetStatePropertyAll(false),
        thumbColor: WidgetStateProperty.resolveWith((states) {
          final hovered = states.contains(WidgetState.hovered);
          final dragged = states.contains(WidgetState.dragged);
          if (!autoHideScrollbarVisible && !hovered && !dragged) {
            return Colors.transparent;
          }
          return hovered || dragged ? hoverThumb : thumb;
        }),
        thickness: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.hovered) ||
                  states.contains(WidgetState.dragged)
              ? widget.hoverThickness
              : widget.normalThickness;
        }),
        radius: const Radius.circular(999),
        trackColor: const WidgetStatePropertyAll(Colors.transparent),
        crossAxisMargin: widget.crossAxisMargin,
        mainAxisMargin: widget.mainAxisMargin,
      ),
      child: Scrollbar(
        controller: widget.controller,
        interactive: true,
        thumbVisibility: true,
        trackVisibility: false,
        child: widget.child,
      ),
    );
  }
}
