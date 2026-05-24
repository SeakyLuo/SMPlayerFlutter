part of 'headered_playlist_control.dart';

class _HeaderedPlaylistListSliver extends StatelessWidget {
  const _HeaderedPlaylistListSliver({
    required this.showAlbum,
    required this.itemCount,
    required this.itemBuilder,
    required this.bottomPadding,
  });

  final bool showAlbum;
  final int itemCount;
  final NullableIndexedWidgetBuilder itemBuilder;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width <= 720;
    final colors = HeaderedPlaylistThemeColors.of(context);
    final listSurface =
        compact ? colors.compactListSurface : colors.listSurface;
    final listBorder = compact ? colors.compactListBorder : colors.listBorder;
    final listShadows =
        compact
            ? colors.compactListShadows
            : [
              BoxShadow(
                color: colors.listShadow,
                offset: const Offset(0, 14),
                blurRadius: 34,
              ),
            ];
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(
        compact ? 2 : 40,
        compact ? 0 : 18,
        compact ? 2 : 40,
        bottomPadding,
      ),
      sliver: DecoratedSliver(
        decoration: BoxDecoration(
          color: listSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: listBorder),
          boxShadow: listShadows,
        ),
        sliver: SliverMainAxisGroup(
          slivers: [
            if (!compact)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: _HeaderedPlaylistListHeader(showAlbum: showAlbum),
                ),
              ),
            SliverPadding(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 0 : 10,
                vertical: compact ? 2 : 0,
              ),
              sliver: SliverList.builder(
                itemCount: itemCount,
                itemBuilder: (context, index) {
                  final item = itemBuilder(context, index);
                  if (!compact || item == null) {
                    return item;
                  }
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index == itemCount - 1 ? 0 : 2,
                    ),
                    child: item,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderedPlaylistListHeader extends StatelessWidget {
  const _HeaderedPlaylistListHeader({required this.showAlbum});

  final bool showAlbum;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final colors = HeaderedPlaylistThemeColors.of(context);
    final textStyle = TextStyle(
      color: colors.textMuted,
      fontSize: 14,
      fontWeight: FontWeight.w600,
      fontVariations: const [FontVariation.weight(750)],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth <= 1120;
        return SizedBox(
          key: const ValueKey('HeaderedPlaylist.ListHeader'),
          height: 42,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                const SizedBox(width: 64),
                const SizedBox(width: 14),
                Expanded(
                  flex: showAlbum && !narrow ? 118 : 100,
                  child: Text(
                    i18n.t('headeredPlaylist.songArtist'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textStyle,
                  ),
                ),
                const SizedBox(width: 14),
                SizedBox(width: narrow ? 0 : 170),
                if (showAlbum && !narrow) ...[
                  const SizedBox(width: 14),
                  Expanded(
                    flex: 72,
                    child: Text(
                      i18n.t('table.album'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textStyle,
                    ),
                  ),
                ],
                const SizedBox(width: 14),
                SizedBox(
                  width: 74,
                  child: Text(
                    i18n.t('table.duration'),
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: textStyle,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HeaderedPlaylistScrollbar extends StatefulWidget {
  const _HeaderedPlaylistScrollbar({
    required this.controller,
    required this.collapseProgress,
    required this.bottomOffset,
  });

  final ScrollController controller;
  final double collapseProgress;
  final double bottomOffset;

  @override
  State<_HeaderedPlaylistScrollbar> createState() =>
      _HeaderedPlaylistScrollbarState();
}

class _HeaderedPlaylistScrollbarState
    extends State<_HeaderedPlaylistScrollbar> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width <= 720;
    final colors = HeaderedPlaylistThemeColors.of(context);
    return Positioned(
      key: const ValueKey('HeaderedPlaylist.Scrollbar'),
      top:
          lerpDouble(
            compact ? 324 : 358,
            compact ? 142 : 130,
            widget.collapseProgress,
          )! +
          4,
      right: 2,
      bottom: widget.bottomOffset,
      width: 10,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return AnimatedBuilder(
            animation: widget.controller,
            builder: (context, _) {
              if (!widget.controller.hasClients) {
                return const SizedBox.shrink();
              }
              final position = widget.controller.position;
              final maxScrollExtent = position.maxScrollExtent;
              if (maxScrollExtent <= 0) {
                return const IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: 0,
                    duration: Duration(milliseconds: 140),
                    curve: Curves.easeOut,
                    child: SizedBox.expand(),
                  ),
                );
              }

              final scrollbarHeight = max(48.0, constraints.maxHeight);
              final contentHeight = scrollbarHeight + maxScrollExtent;
              final thumbHeight = max(
                38.0,
                (scrollbarHeight / contentHeight) * scrollbarHeight,
              );
              final thumbTop =
                  (position.pixels / maxScrollExtent) *
                  (scrollbarHeight - thumbHeight);
              final thumbColor =
                  _hovered ? colors.scrollbarThumbHover : colors.scrollbarThumb;

              return AnimatedOpacity(
                opacity: 1,
                duration: const Duration(milliseconds: 140),
                curve: Curves.easeOut,
                child: MouseRegion(
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
                  child: Stack(
                    children: [
                      Positioned(
                        top: thumbTop.clamp(0.0, scrollbarHeight - thumbHeight),
                        right: 2,
                        width: _hovered ? 6 : 4,
                        height: thumbHeight,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onVerticalDragUpdate: (details) {
                            final trackDistance = scrollbarHeight - thumbHeight;
                            final scrollDelta =
                                details.delta.dy *
                                (maxScrollExtent / trackDistance);
                            widget.controller.jumpTo(
                              (position.pixels + scrollDelta).clamp(
                                0.0,
                                maxScrollExtent,
                              ),
                            );
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
                ),
              );
            },
          );
        },
      ),
    );
  }
}
