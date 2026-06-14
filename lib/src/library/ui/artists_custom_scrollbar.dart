part of 'artists_page.dart';

class _ArtistsCustomScrollbar extends StatefulWidget {
  const _ArtistsCustomScrollbar({
    super.key,
    required this.positionKey,
    required this.thumbKey,
    required this.controller,
    required this.right,
  });

  final Key positionKey;
  final Key thumbKey;
  final ScrollController controller;
  final double right;

  @override
  State<_ArtistsCustomScrollbar> createState() =>
      _ArtistsCustomScrollbarState();
}

class _ArtistsCustomScrollbarState extends State<_ArtistsCustomScrollbar> {
  var _hovered = false;
  var _dragging = false;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      key: widget.positionKey,
      top: 0,
      right: widget.right,
      bottom: 0,
      width: 9,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return AnimatedBuilder(
            animation: widget.controller,
            builder: (context, _) {
              if (!widget.controller.hasClients) {
                return const SizedBox.shrink();
              }
              if (widget.controller.positions.length != 1) {
                return const SizedBox.shrink();
              }

              final position = widget.controller.position;
              final maxScrollTop = position.maxScrollExtent;
              if (maxScrollTop <= 1) {
                return const SizedBox.shrink();
              }

              final trackHeight = constraints.maxHeight;
              final scrollHeight = trackHeight + maxScrollTop;
              final thumbHeight = max(
                38.0,
                (trackHeight / scrollHeight) * trackHeight,
              );
              final thumbTop =
                  (position.pixels / maxScrollTop) *
                  max(0.0, trackHeight - thumbHeight);
              final expanded = _hovered || _dragging;
              final brightness = Theme.of(context).brightness;
              final thumbColor =
                  expanded
                      ? _ArtistsColors.scrollbarThumbHover(brightness)
                      : _ArtistsColors.scrollbarThumb(brightness);

              return MouseRegion(
                onEnter: (_) {
                  setState(() {
                    _hovered = true;
                  });
                },
                onExit: (_) {
                  if (_dragging) {
                    return;
                  }
                  setState(() {
                    _hovered = false;
                  });
                },
                child: Stack(
                  children: [
                    const Positioned.fill(child: SizedBox.expand()),
                    AnimatedOpacity(
                      opacity: expanded ? 1 : 0,
                      duration: const Duration(milliseconds: 140),
                      curve: Curves.easeOut,
                      child: Stack(
                        children: [
                          Positioned(
                            top: thumbTop.clamp(0.0, trackHeight - thumbHeight),
                            right: expanded ? 1 : 2,
                            left: expanded ? 1 : 2,
                            height: thumbHeight,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onVerticalDragStart: (_) {
                                setState(() {
                                  _dragging = true;
                                });
                              },
                              onVerticalDragUpdate: (details) {
                                final trackRange = max(
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
                                setState(() {
                                  _dragging = false;
                                  _hovered = false;
                                });
                              },
                              onVerticalDragCancel: () {
                                setState(() {
                                  _dragging = false;
                                  _hovered = false;
                                });
                              },
                              child: DecoratedBox(
                                key: widget.thumbKey,
                                decoration: BoxDecoration(
                                  color: thumbColor,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
