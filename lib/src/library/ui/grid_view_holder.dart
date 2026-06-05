import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smplayer_flutter/src/app/app_interaction_colors.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
import 'package:smplayer_flutter/src/library/ui/default_album_artwork.dart';
import 'package:smplayer_flutter/src/library/ui/grid_artwork_card_content.dart';
import 'package:smplayer_flutter/src/library/ui/playlist_artwork.dart';
import 'package:smplayer_flutter/src/library/ui/selected_collection_card_style.dart';

const gridViewHolderWidth = 180.0;
const gridViewHolderHeight = 232.0;

class GridViewHolder extends ConsumerStatefulWidget {
  const GridViewHolder({
    super.key,
    required this.playlist,
    required this.songs,
    required this.subtitle,
    required this.playTooltip,
    required this.selected,
    required this.onOpen,
    required this.onPlay,
    this.dragging = false,
    this.sorting = false,
    this.selectionMode = false,
    this.showDragHandle = true,
    this.dragTooltip,
    this.cardKey,
    this.artworkKey,
    this.selectedMark,
    this.onContextMenu,
  });

  final LibraryPlaylist playlist;
  final List<LibrarySong> songs;
  final String subtitle;
  final String playTooltip;
  final bool selected;
  final bool dragging;
  final bool sorting;
  final bool selectionMode;
  final bool showDragHandle;
  final String? dragTooltip;
  final Key? cardKey;
  final Key? artworkKey;
  final Widget? selectedMark;
  final VoidCallback onOpen;
  final VoidCallback onPlay;
  final ValueChanged<Offset>? onContextMenu;

  @override
  ConsumerState<GridViewHolder> createState() => _GridViewHolderState();
}

class _GridViewHolderState extends ConsumerState<GridViewHolder> {
  var _hovered = false;
  var _artworkSignature = '';
  var _artworkGeneration = 0;
  List<String> _artworkUrls = const [];

  @override
  void initState() {
    super.initState();
    _refreshArtwork();
  }

  @override
  void didUpdateWidget(GridViewHolder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.songs != widget.songs) {
      _refreshArtwork();
    }
    if (widget.sorting && _hovered) {
      _hovered = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _GridViewHolderColors.forBrightness(
      Theme.of(context).brightness,
    );
    final selectedStyle = SelectedCollectionCardStyle.forBrightness(
      Theme.of(context).brightness,
    );
    final hoverStyle = SelectedCollectionCardStyle.hoverForBrightness(
      Theme.of(context).brightness,
    );
    final active = widget.dragging || (!widget.sorting && _hovered);
    final selectedMark =
        widget.selectedMark ??
        ((widget.selectionMode || widget.selected)
            ? GridViewSelectionMark(selected: widget.selected)
            : null);
    return MouseRegion(
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
      child: Align(
        alignment: Alignment.topLeft,
        child: GestureDetector(
          onTap: widget.onOpen,
          onSecondaryTapDown: (details) {
            widget.onContextMenu?.call(details.globalPosition);
          },
          child: AnimatedContainer(
            key: widget.cardKey,
            duration: const Duration(milliseconds: 120),
            width: gridViewHolderWidth,
            constraints: const BoxConstraints(minHeight: gridViewHolderHeight),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color:
                  widget.dragging
                      ? colors.dragSurface
                      : widget.selected
                      ? selectedStyle.background
                      : active
                      ? hoverStyle.background
                      : hoverStyle.transparentBackground,
              borderRadius: BorderRadius.circular(12),
              boxShadow:
                  widget.dragging
                      ? [
                        BoxShadow(
                          color: colors.dragShadow,
                          blurRadius: 70,
                          offset: const Offset(0, 26),
                        ),
                      ]
                      : widget.selected || active
                      ? [
                        BoxShadow(
                          color:
                              widget.selected
                                  ? selectedStyle.shadow.color
                                  : hoverStyle.shadow.color,
                          blurRadius:
                              widget.selected
                                  ? selectedStyle.shadow.blurRadius
                                  : hoverStyle.shadow.blurRadius,
                          offset:
                              widget.selected
                                  ? selectedStyle.shadow.offset
                                  : hoverStyle.shadow.offset,
                        ),
                      ]
                      : null,
            ),
            foregroundDecoration:
                widget.dragging
                    ? BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.dragBorder),
                    )
                    : widget.selected || active
                    ? BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            widget.selected
                                ? selectedStyle.border
                                : hoverStyle.border,
                      ),
                    )
                    : null,
            child: Stack(
              children: [
                GridArtworkCardContent(
                  title: widget.playlist.name,
                  subtitle: widget.subtitle,
                  artworkUrls: getPlaylistArtworkDisplayUrls(_artworkUrls),
                  fallback: const DefaultAlbumArtwork(),
                  selectedMark: selectedMark,
                  showActions:
                      !widget.selectionMode && !widget.sorting && _hovered,
                  artworkKey: widget.artworkKey,
                  textStrongColor:
                      widget.selected
                          ? selectedStyle.foreground
                          : colors.textStrong,
                  textMutedColor:
                      widget.selected ? selectedStyle.muted : colors.textMuted,
                  actions: [
                    GridArtworkAction(
                      title: widget.playTooltip,
                      onPressed: widget.songs.isEmpty ? null : widget.onPlay,
                    ),
                  ],
                ),
                if (widget.showDragHandle)
                  _GridViewHolderDragHandle(
                    visible: widget.dragging || (_hovered && !widget.sorting),
                    tooltip: widget.dragTooltip ?? '',
                    color: colors.textStrong,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _refreshArtwork() {
    final signature = getPlaylistArtworkSignature(widget.songs);
    if (signature == _artworkSignature) {
      return;
    }

    _artworkSignature = signature;
    final cachedArtworkUrls = getCachedPlaylistArtworkUrls(signature);
    if (cachedArtworkUrls != null) {
      _artworkUrls = cachedArtworkUrls;
      return;
    }

    _artworkUrls = const [];
    final generation = ++_artworkGeneration;
    unawaited(
      resolvePlaylistArtworkUrls(
        widget.songs,
        ref.read(libraryRepositoryProvider),
      ).then((artworkUrls) {
        cachePlaylistArtworkUrls(signature, artworkUrls);
        if (!mounted ||
            generation != _artworkGeneration ||
            signature != _artworkSignature) {
          return;
        }
        setState(() {
          _artworkUrls = artworkUrls;
        });
      }),
    );
  }
}

class _GridViewHolderDragHandle extends StatelessWidget {
  const _GridViewHolderDragHandle({
    required this.visible,
    required this.tooltip,
    required this.color,
  });

  final bool visible;
  final String tooltip;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final night = Theme.of(context).brightness == Brightness.dark;
    return Positioned(
      top: 2,
      right: 2,
      child:
          visible
              ? Tooltip(
                message: tooltip,
                child: MouseRegion(
                  cursor: SystemMouseCursors.grab,
                  child: AnimatedOpacity(
                    opacity: 1,
                    duration: const Duration(milliseconds: 120),
                    child: AnimatedSlide(
                      offset: Offset.zero,
                      duration: const Duration(milliseconds: 120),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x291e2a3a),
                              blurRadius: 18,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color:
                                    night
                                        ? const Color(0xc7181e26)
                                        : const Color(0xd1ffffff),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color:
                                      night
                                          ? const Color(0x1fffffff)
                                          : const Color(0x9effffff),
                                ),
                              ),
                              child: SizedBox.square(
                                dimension: 32,
                                child: CustomPaint(
                                  painter: _GridViewHolderGripPainter(
                                    color: color,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              )
              : const SizedBox.shrink(),
    );
  }
}

class _GridViewHolderGripPainter extends CustomPainter {
  const _GridViewHolderGripPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.fill;
    final iconLeft = (size.width - 18) / 2;
    final iconTop = (size.height - 18) / 2;
    const scale = 18 / 24;
    const xPositions = [8.0, 12.0, 16.0];
    const yPositions = [6.0, 12.0, 18.0];
    for (final y in yPositions) {
      for (final x in xPositions) {
        canvas.drawCircle(
          Offset(iconLeft + x * scale, iconTop + y * scale),
          1 * scale,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GridViewHolderGripPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _GridViewHolderColors {
  const _GridViewHolderColors({
    required this.hoverSurface,
    required this.hoverBorder,
    required this.hoverShadow,
    required this.dragSurface,
    required this.dragBorder,
    required this.dragShadow,
    required this.textStrong,
    required this.textMuted,
  });

  final Color hoverSurface;
  final Color hoverBorder;
  final Color hoverShadow;
  final Color dragSurface;
  final Color dragBorder;
  final Color dragShadow;
  final Color textStrong;
  final Color textMuted;

  static _GridViewHolderColors forBrightness(Brightness brightness) {
    return brightness == Brightness.dark ? dark : light;
  }

  static const light = _GridViewHolderColors(
    hoverSurface: GlobalUI.hoverBgColorDay,
    hoverBorder: GlobalUI.hoverBorderColorDay,
    hoverShadow: Color(0x1f1e2a3a),
    dragSurface: Color(0xf7ffffff),
    dragBorder: Color(0x660078d7),
    dragShadow: Color(0x3d1e2a3a),
    textStrong: Color(0xff1f252b),
    textMuted: Color(0xff5f625f),
  );

  static const dark = _GridViewHolderColors(
    hoverSurface: GlobalUI.hoverBgColorNight,
    hoverBorder: GlobalUI.hoverBorderColorNight,
    hoverShadow: Color(0x3d000000),
    dragSurface: Color(0xf01a2028),
    dragBorder: Color(0x660078d7),
    dragShadow: Color(0x66000000),
    textStrong: Color(0xf0f6f9fc),
    textMuted: Color(0xadcbd5e1),
  );
}
