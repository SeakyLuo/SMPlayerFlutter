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
    required this.totalSongCount,
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

  final Map<int, LibrarySong> songs;
  final int totalSongCount;
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
  final FutureOr<void> Function(BuildContext buttonContext, LibrarySong song)
  onOpenAddToPlaylistMenu;
  final FutureOr<void> Function(Offset position, LibrarySong song)
  onOpenContextMenu;

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
                  padding: EdgeInsets.only(
                    bottom: multiSelect ? multiSelectCommandBarScrollSpacer : 0,
                  ),
                  itemExtent: _wideVirtualRowHeight,
                  itemCount: totalSongCount,
                  itemBuilder: (context, index) {
                    final song = songs[index];
                    if (song == null) return const _SongWindowPlaceholder();
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
                      onOpenAddToPlaylistMenu:
                          (buttonContext) =>
                              onOpenAddToPlaylistMenu(buttonContext, song),
                      onOpenContextMenu:
                          (position) => onOpenContextMenu(position, song),
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
    extends State<_MusicLibraryTableScrollbar>
    with AutoHideScrollbarVisibility {
  var _dimensionRefreshPending = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(showAutoHideScrollbar);
  }

  @override
  void didUpdateWidget(_MusicLibraryTableScrollbar oldWidget) {
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
        autoHideScrollbarExpanded
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
            final expanded = autoHideScrollbarExpanded;

            return MouseRegion(
              onEnter: (_) {
                setAutoHideScrollbarHovered(true);
              },
              onExit: (_) {
                setAutoHideScrollbarHovered(false);
              },
              child: Stack(
                children: [
                  AnimatedOpacity(
                    opacity: autoHideScrollbarVisible ? 1 : 0,
                    duration: const Duration(milliseconds: 140),
                    curve: Curves.easeOut,
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
                              beginAutoHideScrollbarDrag();
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
                              endAutoHideScrollbarDrag();
                            },
                            onVerticalDragCancel: () {
                              endAutoHideScrollbarDrag();
                            },
                            child: DecoratedBox(
                              key: const ValueKey(
                                'MusicLibrary.ScrollbarThumb',
                              ),
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
