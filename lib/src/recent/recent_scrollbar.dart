import 'package:flutter/material.dart';

class RecentScrollbar extends StatefulWidget {
  const RecentScrollbar({super.key, required this.builder});

  final Widget Function(ScrollController controller) builder;

  @override
  State<RecentScrollbar> createState() => _RecentScrollbarState();
}

class _RecentScrollbarState extends State<RecentScrollbar> {
  late final ScrollController _controller;
  var _hovered = false;
  var _focused = false;
  var _scrolling = false;
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

  void _setHovered(bool hovered) {
    if (_hovered == hovered) {
      return;
    }

    setState(() {
      _hovered = hovered;
    });
    if (hovered) {
      _syncCanScroll();
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _canScroll && (_hovered || _focused || _scrolling);
    return MouseRegion(
      onEnter: (_) {
        _setHovered(true);
      },
      onExit: (_) {
        _setHovered(false);
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
              setState(() {
                _scrolling = true;
              });
            } else if (notification is ScrollEndNotification) {
              setState(() {
                _scrolling = false;
              });
            }
            return false;
          },
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 140),
            opacity: visible ? 1 : 0,
            child: ScrollbarTheme(
              data: ScrollbarTheme.of(context).copyWith(
                thumbColor: WidgetStateProperty.resolveWith((states) {
                  return states.contains(WidgetState.hovered)
                      ? const Color(0xad435060)
                      : const Color(0x805b697a);
                }),
                trackColor: const WidgetStatePropertyAll(Colors.transparent),
                thickness: WidgetStateProperty.resolveWith((states) {
                  return states.contains(WidgetState.hovered) ? 7 : 5;
                }),
                radius: const Radius.circular(999),
                crossAxisMargin: 5,
                mainAxisMargin: 0,
              ),
              child: Scrollbar(
                controller: _controller,
                interactive: true,
                thumbVisibility: true,
                trackVisibility: false,
                child: widget.builder(_controller),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
