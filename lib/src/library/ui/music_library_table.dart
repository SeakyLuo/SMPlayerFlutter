part of 'music_library_page.dart';

class _LibraryScaffold extends StatelessWidget {
  const _LibraryScaffold({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
      child: SizedBox.expand(child: child),
    );
  }
}

class _WideSongTable extends StatelessWidget {
  const _WideSongTable({
    required this.songs,
    required this.sortCriterion,
    required this.sortDirection,
    required this.scrollController,
    required this.selectedSongIds,
    required this.selectedTrackId,
    required this.isPlaying,
    required this.multiSelect,
    required this.i18n,
    required this.columnWidths,
    required this.onSort,
    required this.onResizeColumn,
    required this.onSelected,
    required this.onAddNextAndPlay,
    required this.onTogglePlayPause,
    required this.onToggleSelection,
    required this.onToggleFavorite,
    required this.onPlayNext,
    required this.onOpenAddToPlaylistMenu,
    required this.onOpenContextMenu,
  });

  final List<LibrarySong> songs;
  final MusicLibrarySortCriterion sortCriterion;
  final MusicLibrarySortDirection sortDirection;
  final ScrollController scrollController;
  final Set<int> selectedSongIds;
  final int? selectedTrackId;
  final bool isPlaying;
  final bool multiSelect;
  final SmPlayerI18n i18n;
  final Map<_LibraryColumn, double> columnWidths;
  final ValueChanged<MusicLibrarySortCriterion> onSort;
  final void Function(_LibraryColumn column, double deltaX) onResizeColumn;
  final ValueChanged<int> onSelected;
  final ValueChanged<int> onAddNextAndPlay;
  final VoidCallback onTogglePlayPause;
  final ValueChanged<int> onToggleSelection;
  final ValueChanged<int> onToggleFavorite;
  final ValueChanged<int> onPlayNext;
  final void Function(BuildContext buttonContext, LibrarySong song)
  onOpenAddToPlaylistMenu;
  final void Function(Offset position, LibrarySong song) onOpenContextMenu;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: _tableWidth(columnWidths),
        child: Column(
          children: [
            _TableHeader(
              sortCriterion: sortCriterion,
              sortDirection: sortDirection,
              i18n: i18n,
              columnWidths: columnWidths,
              onSort: onSort,
              onResizeColumn: onResizeColumn,
            ),
            Expanded(
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(
                  context,
                ).copyWith(scrollbars: false),
                child: ListView.builder(
                  controller: scrollController,
                  itemExtent: _wideVirtualRowHeight,
                  itemCount: songs.length,
                  itemBuilder: (context, index) {
                    final song = songs[index];
                    return _WideSongRow(
                      song: song,
                      selected: selectedSongIds.contains(song.id),
                      current: song.id == selectedTrackId,
                      playing: song.id == selectedTrackId && isPlaying,
                      selectionMode: multiSelect,
                      i18n: i18n,
                      columnWidths: columnWidths,
                      onSelected: () {
                        onSelected(song.id);
                      },
                      onAddNextAndPlay: () {
                        onAddNextAndPlay(song.id);
                      },
                      onTogglePlayPause: onTogglePlayPause,
                      onToggleSelection: () {
                        onToggleSelection(song.id);
                      },
                      onToggleFavorite: () {
                        onToggleFavorite(song.id);
                      },
                      onPlayNext: () {
                        onPlayNext(song.id);
                      },
                      onOpenAddToPlaylistMenu: (buttonContext) {
                        onOpenAddToPlaylistMenu(buttonContext, song);
                      },
                      onOpenContextMenu: (position) {
                        onOpenContextMenu(position, song);
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MusicLibraryTableScrollbar extends StatefulWidget {
  const _MusicLibraryTableScrollbar({required this.controller});

  final ScrollController controller;

  @override
  State<_MusicLibraryTableScrollbar> createState() =>
      _MusicLibraryTableScrollbarState();
}

class _MusicLibraryTableScrollbarState
    extends State<_MusicLibraryTableScrollbar> {
  var _hovered = false;
  var _dragging = false;
  var _dimensionRefreshPending = false;

  void _refreshAfterDimensions() {
    if (_dimensionRefreshPending) {
      return;
    }
    _dimensionRefreshPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _dimensionRefreshPending = false;
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final thumbColor =
        _hovered || _dragging
            ? _musicLibraryScrollbarThumbHover(brightness)
            : _musicLibraryScrollbarThumb(brightness);
    return LayoutBuilder(
      key: const ValueKey('MusicLibrary.Scrollbar'),
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
            if (!position.hasContentDimensions) {
              _refreshAfterDimensions();
              return const SizedBox.shrink();
            }
            final maxScrollExtent = position.maxScrollExtent;
            if (maxScrollExtent <= 0) {
              return const SizedBox.shrink();
            }

            final trackHeight = constraints.maxHeight;
            final contentHeight = trackHeight + maxScrollExtent;
            final thumbHeight = max(
              38.0,
              (trackHeight / contentHeight) * trackHeight,
            );
            final thumbTop =
                (position.pixels / maxScrollExtent) *
                max(0.0, trackHeight - thumbHeight);
            final expanded = _hovered || _dragging;

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
                  Positioned(
                    top: thumbTop.clamp(0.0, trackHeight - thumbHeight),
                    right: expanded ? 1.5 : 2.5,
                    width: expanded ? 7 : 5,
                    height: thumbHeight,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onVerticalDragStart: (_) {
                        setState(() {
                          _dragging = true;
                        });
                      },
                      onVerticalDragUpdate: (details) {
                        final trackDistance = max(
                          1.0,
                          trackHeight - thumbHeight,
                        );
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
                        key: const ValueKey('MusicLibrary.ScrollbarThumb'),
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
    );
  }
}

Color _musicLibraryScrollbarThumb(Brightness brightness) {
  return brightness == Brightness.dark
      ? const Color(0x5cd0dbe8)
      : const Color(0x705b697a);
}

Color _musicLibraryScrollbarThumbHover(Brightness brightness) {
  return brightness == Brightness.dark
      ? const Color(0x94dee7f2)
      : const Color(0xa6435060);
}

double _tableWidth(Map<_LibraryColumn, double> columnWidths) {
  return _LibraryColumn.values.fold<double>(
    0,
    (total, column) => total + columnWidths[column]!,
  );
}

class _TableHeader extends StatelessWidget {
  const _TableHeader({
    required this.sortCriterion,
    required this.sortDirection,
    required this.i18n,
    required this.columnWidths,
    required this.onSort,
    required this.onResizeColumn,
  });

  final MusicLibrarySortCriterion sortCriterion;
  final MusicLibrarySortDirection sortDirection;
  final SmPlayerI18n i18n;
  final Map<_LibraryColumn, double> columnWidths;
  final ValueChanged<MusicLibrarySortCriterion> onSort;
  final void Function(_LibraryColumn column, double deltaX) onResizeColumn;

  @override
  Widget build(BuildContext context) {
    final colors = _LibraryPalette.of(context);
    return Container(
      key: const ValueKey('MusicLibrary.TableHeader'),
      height: 44,
      color: colors.panel,
      child: Row(
        children: [
          _StaticHeaderCell(
            column: _LibraryColumn.artwork,
            width: columnWidths[_LibraryColumn.artwork]!,
            label: '',
            onResizeColumn: onResizeColumn,
          ),
          _HeaderCell(
            column: _LibraryColumn.title,
            width: columnWidths[_LibraryColumn.title]!,
            label: i18n.t('musicLibrary.titleHeader'),
            criterion: MusicLibrarySortCriterion.title,
            sortCriterion: sortCriterion,
            sortDirection: sortDirection,
            onSort: onSort,
            onResizeColumn: onResizeColumn,
          ),
          _HeaderCell(
            column: _LibraryColumn.artist,
            width: columnWidths[_LibraryColumn.artist]!,
            label: i18n.t('common.artist'),
            criterion: MusicLibrarySortCriterion.artist,
            sortCriterion: sortCriterion,
            sortDirection: sortDirection,
            onSort: onSort,
            onResizeColumn: onResizeColumn,
          ),
          _HeaderCell(
            column: _LibraryColumn.album,
            width: columnWidths[_LibraryColumn.album]!,
            label: i18n.t('common.album'),
            criterion: MusicLibrarySortCriterion.album,
            sortCriterion: sortCriterion,
            sortDirection: sortDirection,
            onSort: onSort,
            onResizeColumn: onResizeColumn,
          ),
          _HeaderCell(
            column: _LibraryColumn.duration,
            width: columnWidths[_LibraryColumn.duration]!,
            label: i18n.t('common.duration'),
            criterion: MusicLibrarySortCriterion.duration,
            sortCriterion: sortCriterion,
            sortDirection: sortDirection,
            onSort: onSort,
            onResizeColumn: onResizeColumn,
          ),
          _StaticHeaderCell(
            column: _LibraryColumn.favorite,
            width: columnWidths[_LibraryColumn.favorite]!,
            label: i18n.t('table.favorite'),
            onResizeColumn: onResizeColumn,
            resizable: false,
            alignment: Alignment.center,
          ),
          _HeaderCell(
            column: _LibraryColumn.playCount,
            width: columnWidths[_LibraryColumn.playCount]!,
            label: i18n.t('common.playCount'),
            criterion: MusicLibrarySortCriterion.playCount,
            sortCriterion: sortCriterion,
            sortDirection: sortDirection,
            onSort: onSort,
            onResizeColumn: onResizeColumn,
          ),
          _HeaderCell(
            column: _LibraryColumn.dateAdded,
            width: columnWidths[_LibraryColumn.dateAdded]!,
            label: i18n.t('common.dateAdded'),
            criterion: MusicLibrarySortCriterion.dateAdded,
            sortCriterion: sortCriterion,
            sortDirection: sortDirection,
            onSort: onSort,
            onResizeColumn: onResizeColumn,
          ),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({
    required this.column,
    required this.width,
    required this.label,
    required this.criterion,
    required this.sortCriterion,
    required this.sortDirection,
    required this.onSort,
    required this.onResizeColumn,
  });

  final _LibraryColumn column;
  final double width;
  final String label;
  final MusicLibrarySortCriterion criterion;
  final MusicLibrarySortCriterion sortCriterion;
  final MusicLibrarySortDirection sortDirection;
  final ValueChanged<MusicLibrarySortCriterion> onSort;
  final void Function(_LibraryColumn column, double deltaX) onResizeColumn;

  @override
  Widget build(BuildContext context) {
    final colors = _LibraryPalette.of(context);
    final sorted = sortCriterion == criterion;
    return SizedBox(
      key: ValueKey('MusicLibrary.Header.${column.name}'),
      width: width,
      child: Stack(
        children: [
          Positioned.fill(
            child: TextButton(
              style: TextButton.styleFrom(
                alignment: Alignment.centerLeft,
                backgroundColor:
                    sorted ? colors.accentSoft : Colors.transparent,
                foregroundColor: sorted ? colors.textStrong : colors.headerText,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: const RoundedRectangleBorder(),
              ),
              onPressed: () {
                onSort(criterion);
              },
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  if (sorted)
                    Icon(
                      sortDirection == MusicLibrarySortDirection.ascending
                          ? FluentIcons.chevron_up_16_regular
                          : FluentIcons.chevron_down_16_regular,
                      size: 14,
                      color: colors.accentStrong,
                    ),
                ],
              ),
            ),
          ),
          _ColumnResizer(column: column, onResizeColumn: onResizeColumn),
        ],
      ),
    );
  }
}

class _StaticHeaderCell extends StatelessWidget {
  const _StaticHeaderCell({
    required this.column,
    required this.width,
    required this.label,
    required this.onResizeColumn,
    this.resizable = true,
    this.alignment = Alignment.centerLeft,
  });

  final _LibraryColumn column;
  final double width;
  final String label;
  final void Function(_LibraryColumn column, double deltaX) onResizeColumn;
  final bool resizable;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final colors = _LibraryPalette.of(context);
    return SizedBox(
      key: ValueKey('MusicLibrary.Header.${column.name}'),
      width: width,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Align(
              alignment: alignment,
              child: Text(
                label,
                style: TextStyle(color: colors.headerText, fontSize: 12),
              ),
            ),
          ),
          if (resizable)
            _ColumnResizer(column: column, onResizeColumn: onResizeColumn),
        ],
      ),
    );
  }
}

class _ColumnResizer extends StatelessWidget {
  const _ColumnResizer({required this.column, required this.onResizeColumn});

  final _LibraryColumn column;
  final void Function(_LibraryColumn column, double deltaX) onResizeColumn;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 0,
      top: 0,
      bottom: 0,
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeLeftRight,
        child: GestureDetector(
          key: ValueKey('MusicLibrary.ColumnResizer.${column.name}'),
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: (details) {
            onResizeColumn(column, details.delta.dx);
          },
          child: const SizedBox(width: 8),
        ),
      ),
    );
  }
}

class _WideSongRow extends StatefulWidget {
  const _WideSongRow({
    required this.song,
    required this.selected,
    required this.current,
    required this.playing,
    required this.selectionMode,
    required this.i18n,
    required this.columnWidths,
    required this.onSelected,
    required this.onAddNextAndPlay,
    required this.onTogglePlayPause,
    required this.onToggleSelection,
    required this.onToggleFavorite,
    required this.onPlayNext,
    required this.onOpenAddToPlaylistMenu,
    required this.onOpenContextMenu,
  });

  final LibrarySong song;
  final bool selected;
  final bool current;
  final bool playing;
  final bool selectionMode;
  final SmPlayerI18n i18n;
  final Map<_LibraryColumn, double> columnWidths;
  final VoidCallback onSelected;
  final VoidCallback onAddNextAndPlay;
  final VoidCallback onTogglePlayPause;
  final VoidCallback onToggleSelection;
  final VoidCallback onToggleFavorite;
  final VoidCallback onPlayNext;
  final ValueChanged<BuildContext> onOpenAddToPlaylistMenu;
  final ValueChanged<Offset> onOpenContextMenu;

  @override
  State<_WideSongRow> createState() => _WideSongRowState();
}

class _WideSongRowState extends State<_WideSongRow> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = _LibraryPalette.of(context);
    return MouseRegion(
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
      child: InkWell(
        onTap: widget.onSelected,
        onDoubleTap: widget.selectionMode ? null : widget.onAddNextAndPlay,
        onSecondaryTapDown: (details) {
          widget.onOpenContextMenu(details.globalPosition);
        },
        hoverColor: Colors.transparent,
        child: Stack(
          children: [
            Container(
              key: ValueKey('MusicLibrary.Row.${widget.song.id}'),
              height: 58,
              decoration: BoxDecoration(
                color:
                    widget.selected
                        ? colors.rowSelected
                        : widget.current
                        ? colors.rowCurrent
                        : _hovered
                        ? colors.rowHover
                        : Colors.transparent,
                border: Border(top: BorderSide(color: colors.rowBorder)),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: widget.columnWidths[_LibraryColumn.artwork]!,
                    child: Center(
                      child:
                          widget.selectionMode
                              ? _SelectionMark(selected: widget.selected)
                              : LibraryRowArtwork(
                                song: widget.song,
                                size: 42,
                                current: widget.current,
                                playing: widget.playing,
                                rowHovered: _hovered,
                                onPlay: widget.onAddNextAndPlay,
                                onTogglePlayPause: widget.onTogglePlayPause,
                              ),
                    ),
                  ),
                  _SongTextCell(
                    width: widget.columnWidths[_LibraryColumn.title]!,
                    text: widget.song.title,
                    strong: true,
                    current: widget.current,
                  ),
                  _ArtistLinksCell(
                    width: widget.columnWidths[_LibraryColumn.artist]!,
                    song: widget.song,
                    i18n: widget.i18n,
                    current: widget.current,
                  ),
                  _RouteTextCell(
                    width: widget.columnWidths[_LibraryColumn.album]!,
                    text: _displayAlbum(widget.song, widget.i18n),
                    current: widget.current,
                    onTap: () {
                      context.go(
                        '/albums?album=${Uri.encodeQueryComponent(_displayAlbum(widget.song, widget.i18n))}',
                      );
                    },
                  ),
                  _SongTextCell(
                    width: widget.columnWidths[_LibraryColumn.duration]!,
                    text: _formatDuration(widget.song.duration),
                    current: widget.current,
                  ),
                  SizedBox(
                    width: widget.columnWidths[_LibraryColumn.favorite]!,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        IgnorePointer(
                          ignoring: _hovered,
                          child: AnimatedOpacity(
                            opacity: widget.song.favorite && !_hovered ? 1 : 0,
                            duration: const Duration(milliseconds: 120),
                            child: IconButton(
                              tooltip: widget.i18n.t('common.favorite'),
                              icon: const Icon(
                                FluentIcons.heart_16_filled,
                                size: 18,
                              ),
                              color: colors.favorite,
                              onPressed: widget.onToggleFavorite,
                            ),
                          ),
                        ),
                        IgnorePointer(
                          ignoring: !_hovered,
                          child: AnimatedOpacity(
                            opacity: _hovered ? 1 : 0,
                            duration: const Duration(milliseconds: 120),
                            child: _MusicLibraryRowActionButton(
                              key: ValueKey(
                                'MusicLibrary.FavoriteAction.${widget.song.id}',
                              ),
                              tooltip:
                                  widget.song.favorite
                                      ? widget.i18n.t('context.removeFavorite')
                                      : widget.i18n.t('context.addFavorite'),
                              icon: Icon(
                                widget.song.favorite
                                    ? FluentIcons.heart_20_filled
                                    : FluentIcons.heart_20_regular,
                                size: 18,
                              ),
                              active: widget.song.favorite,
                              onPressed: widget.onToggleFavorite,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _SongTextCell(
                    width: widget.columnWidths[_LibraryColumn.playCount]!,
                    text: widget.song.playCount.toString(),
                    current: widget.current,
                  ),
                  _SongTextCell(
                    width: widget.columnWidths[_LibraryColumn.dateAdded]!,
                    text: _formatDateTime(widget.song.dateAdded),
                    current: widget.current,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SongTextCell extends StatelessWidget {
  const _SongTextCell({
    required this.width,
    required this.text,
    this.strong = false,
    this.current = false,
  });

  final double width;
  final String text;
  final bool strong;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final colors = _LibraryPalette.of(context);
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Text(
          text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color:
                current
                    ? strong
                        ? colors.currentForeground
                        : colors.currentMuted
                    : strong
                    ? colors.textStrong
                    : colors.textMuted,
            fontSize: 14,
            fontWeight: strong ? FontWeight.w600 : FontWeight.w400,
            height: 1.35,
          ),
        ),
      ),
    );
  }
}

class _ArtistLinksCell extends StatelessWidget {
  const _ArtistLinksCell({
    required this.width,
    required this.song,
    required this.i18n,
    this.current = false,
  });

  final double width;
  final LibrarySong song;
  final SmPlayerI18n i18n;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final colors = _LibraryPalette.of(context);
    final artists = getSongArtists(song);
    final displayArtists =
        artists.isEmpty ? [i18n.t('common.artistUnknown')] : artists;
    final separator = i18n.t('common.artistSeparator');

    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Wrap(
          spacing: 0,
          runSpacing: 0,
          children: [
            for (var index = 0; index < displayArtists.length; index += 1) ...[
              if (index > 0)
                Text(
                  separator,
                  style: TextStyle(
                    color: current ? colors.currentMuted : colors.textMuted,
                    fontSize: 14,
                    height: 1.35,
                  ),
                ),
              _InlineRouteText(
                key: ValueKey(
                  'MusicLibrary.ArtistLink.${displayArtists[index]}',
                ),
                text: displayArtists[index],
                current: current,
                onTap: () {
                  context.go(
                    '/artists?artist=${Uri.encodeQueryComponent(displayArtists[index])}',
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RouteTextCell extends StatelessWidget {
  const _RouteTextCell({
    required this.width,
    required this.text,
    required this.onTap,
    this.current = false,
  });

  final double width;
  final String text;
  final VoidCallback onTap;
  final bool current;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Align(
          alignment: Alignment.centerLeft,
          child: _InlineRouteText(
            key: ValueKey('MusicLibrary.AlbumLink.$text'),
            text: text,
            current: current,
            onTap: onTap,
          ),
        ),
      ),
    );
  }
}

class _InlineRouteText extends StatelessWidget {
  const _InlineRouteText({
    super.key,
    required this.text,
    required this.onTap,
    this.current = false,
  });

  final String text;
  final VoidCallback onTap;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final colors = _LibraryPalette.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerUp: (_) {
          onTap();
        },
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: current ? colors.currentMuted : colors.routeText,
            fontSize: 14,
            height: 1.35,
          ),
        ),
      ),
    );
  }
}
