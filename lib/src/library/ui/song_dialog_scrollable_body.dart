part of 'music_dialog.dart';

class _SongDialogScrollableBody extends StatefulWidget {
  const _SongDialogScrollableBody({required this.child, required this.padding});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  State<_SongDialogScrollableBody> createState() =>
      _SongDialogScrollableBodyState();
}

class _SongDialogScrollableBodyState extends State<_SongDialogScrollableBody> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SongDialogScrollbarHost(
      controller: _controller,
      right: 5,
      bottom: 0,
      child: SingleChildScrollView(
        controller: _controller,
        padding: widget.padding,
        child: widget.child,
      ),
    );
  }
}

class _SongDialogScrollbarHost extends StatefulWidget {
  const _SongDialogScrollbarHost({
    required this.controller,
    required this.child,
    required this.right,
    this.bottom = 0,
    this.trackWidth = 9,
    this.normalThumbLeft = 2,
    this.normalThumbRight = 2,
    this.hoverThumbLeft = 1,
    this.hoverThumbRight = 1,
    this.frameKey,
    this.positionKey = const ValueKey('MusicDialog.BodyScrollbar.Position'),
    this.thumbKey = const ValueKey('MusicDialog.BodyScrollbar.Thumb'),
  });

  final ScrollController controller;
  final Widget child;
  final double right;
  final double bottom;
  final double trackWidth;
  final double normalThumbLeft;
  final double normalThumbRight;
  final double hoverThumbLeft;
  final double hoverThumbRight;
  final Key? frameKey;
  final Key positionKey;
  final Key thumbKey;

  @override
  State<_SongDialogScrollbarHost> createState() =>
      _SongDialogScrollbarHostState();
}

class _SongDialogScrollbarHostState extends State<_SongDialogScrollbarHost>
    with AutoHideScrollbarVisibility {
  var _refreshScheduled = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(showAutoHideScrollbar);
    _scheduleLayoutRefresh();
  }

  @override
  void didUpdateWidget(covariant _SongDialogScrollbarHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(showAutoHideScrollbar);
      widget.controller.addListener(showAutoHideScrollbar);
    }
    _scheduleLayoutRefresh();
  }

  @override
  void dispose() {
    widget.controller.removeListener(showAutoHideScrollbar);
    super.dispose();
  }

  void _scheduleLayoutRefresh() {
    if (_refreshScheduled) {
      return;
    }
    _refreshScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshScheduled = false;
      if (!mounted) {
        return;
      }
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        setAutoHideScrollbarHovered(true);
      },
      onExit: (_) {
        setAutoHideScrollbarHovered(false);
      },
      child: Stack(
        key: widget.frameKey,
        clipBehavior: Clip.none,
        children: [
          widget.child,
          Positioned(
            key: widget.positionKey,
            top: 0,
            right: widget.right,
            bottom: widget.bottom,
            width: widget.trackWidth,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return AnimatedBuilder(
                  animation: widget.controller,
                  builder: (context, _) {
                    if (!widget.controller.hasClients ||
                        widget.controller.positions.length != 1) {
                      return const SizedBox.shrink();
                    }
                    final position = widget.controller.position;
                    final maxScrollTop = position.maxScrollExtent;
                    if (maxScrollTop <= 1) {
                      return const SizedBox.shrink();
                    }

                    final trackHeight = constraints.maxHeight;
                    final scrollHeight = trackHeight + maxScrollTop;
                    final thumbHeight = math.max(
                      38.0,
                      (trackHeight / scrollHeight) * trackHeight,
                    );
                    final thumbTop =
                        (position.pixels / maxScrollTop) *
                        math.max(0.0, trackHeight - thumbHeight);
                    final expanded = autoHideScrollbarExpanded;
                    final brightness = Theme.of(context).brightness;
                    final thumbColor =
                        expanded
                            ? _songDialogScrollbarThumbHover(brightness)
                            : _songDialogScrollbarThumb(brightness);

                    return AnimatedOpacity(
                      opacity: autoHideScrollbarVisible ? 1 : 0,
                      duration: const Duration(milliseconds: 140),
                      curve: Curves.easeOut,
                      child: Stack(
                        children: [
                          Positioned(
                            key: widget.thumbKey,
                            top: thumbTop.clamp(0.0, trackHeight - thumbHeight),
                            left:
                                expanded
                                    ? widget.hoverThumbLeft
                                    : widget.normalThumbLeft,
                            right:
                                expanded
                                    ? widget.hoverThumbRight
                                    : widget.normalThumbRight,
                            height: thumbHeight,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onVerticalDragStart: (_) {
                                beginAutoHideScrollbarDrag();
                              },
                              onVerticalDragUpdate: (details) {
                                final trackRange = math.max(
                                  1.0,
                                  trackHeight - thumbHeight,
                                );
                                final scrollDelta =
                                    details.delta.dy *
                                    (maxScrollTop / trackRange);
                                widget.controller.jumpTo(
                                  (position.pixels + scrollDelta).clamp(
                                    0.0,
                                    maxScrollTop,
                                  ),
                                );
                              },
                              onVerticalDragEnd: (_) {
                                endAutoHideScrollbarDrag();
                              },
                              onVerticalDragCancel: () {
                                endAutoHideScrollbarDrag();
                              },
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: thumbColor,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

Color _songDialogScrollbarThumb(Brightness brightness) {
  return brightness == Brightness.dark
      ? const Color(0x7396a4b6)
      : const Color(0x805b697a);
}

Color _songDialogScrollbarThumbHover(Brightness brightness) {
  return brightness == Brightness.dark
      ? const Color(0x9ebccadc)
      : const Color(0xad435060);
}
