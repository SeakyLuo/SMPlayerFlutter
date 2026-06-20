import 'package:flutter/material.dart';
import 'package:smplayer_flutter/src/app/auto_hide_scrollbar_visibility.dart';

const edgeAutoHideScrollbarThickness = 5.0;
const edgeAutoHideScrollbarHoverThickness = 7.0;

class EdgeAutoHideScrollbar extends StatefulWidget {
  const EdgeAutoHideScrollbar({
    super.key,
    required this.builder,
    this.trailingEdgeOffset = 0,
  });

  final Widget Function(ScrollController controller) builder;
  final double trailingEdgeOffset;

  @override
  State<EdgeAutoHideScrollbar> createState() => _EdgeAutoHideScrollbarState();
}

class _EdgeAutoHideScrollbarState extends State<EdgeAutoHideScrollbar>
    with AutoHideScrollbarVisibility {
  late final ScrollController _controller;
  var _focused = false;
  var _canScroll = false;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController();
    _controller.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncCanScroll();
    });
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleScroll() {
    _syncCanScroll();
    if (_controller.hasClients && _controller.position.maxScrollExtent > 1) {
      showAutoHideScrollbar();
    }
  }

  void _syncCanScroll() {
    if (!_controller.hasClients) {
      return;
    }

    final canScroll = _controller.position.maxScrollExtent > 1;
    if (_canScroll != canScroll) {
      setState(() {
        _canScroll = canScroll;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _canScroll && (autoHideScrollbarVisible || _focused);
    final scrollableChild = ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: widget.builder(_controller),
    );
    final scrollable = Scrollbar(
      controller: _controller,
      interactive: visible,
      thumbVisibility: true,
      trackVisibility: false,
      child:
          widget.trailingEdgeOffset == 0
              ? scrollableChild
              : Transform.translate(
                offset: Offset(-widget.trailingEdgeOffset, 0),
                child: scrollableChild,
              ),
    );
    return MouseRegion(
      onEnter: (_) {
        _syncCanScroll();
        setAutoHideScrollbarHovered(true);
      },
      onExit: (_) {
        setAutoHideScrollbarHovered(false);
      },
      child: Focus(
        onFocusChange: (focused) {
          setState(() {
            _focused = focused;
          });
        },
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification.metrics.axis != Axis.vertical) {
              return false;
            }

            final canScroll = notification.metrics.maxScrollExtent > 1;
            if (_canScroll != canScroll) {
              setState(() {
                _canScroll = canScroll;
              });
            }
            if (notification is ScrollStartNotification) {
              showAutoHideScrollbar();
            } else if (notification is ScrollEndNotification) {
              scheduleAutoHideScrollbar();
            }
            return false;
          },
          child: ScrollbarTheme(
            data: ScrollbarTheme.of(context).copyWith(
              thumbColor: WidgetStateProperty.resolveWith((states) {
                if (!visible) {
                  return Colors.transparent;
                }
                return states.contains(WidgetState.hovered)
                    ? const Color(0xad435060)
                    : const Color(0x805b697a);
              }),
              trackColor: const WidgetStatePropertyAll(Colors.transparent),
              thickness: WidgetStateProperty.resolveWith((states) {
                if (!visible) {
                  return 0;
                }
                return states.contains(WidgetState.hovered)
                    ? edgeAutoHideScrollbarHoverThickness
                    : edgeAutoHideScrollbarThickness;
              }),
              radius: const Radius.circular(999),
              crossAxisMargin: 0,
              mainAxisMargin: 0,
            ),
            child: Transform.translate(
              offset: Offset(widget.trailingEdgeOffset, 0),
              child: scrollable,
            ),
          ),
        ),
      ),
    );
  }
}
