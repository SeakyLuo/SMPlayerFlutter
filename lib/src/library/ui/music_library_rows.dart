part of 'music_library_page.dart';

class _CompactSongList extends StatelessWidget {
  const _CompactSongList({
    required this.songs,
    required this.scrollController,
    required this.sortCriterion,
    required this.sortDirection,
    required this.selectedSongIds,
    required this.selectedTrackId,
    required this.isPlaying,
    required this.multiSelect,
    required this.i18n,
    required this.onSort,
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
  final ScrollController scrollController;
  final MusicLibrarySortCriterion sortCriterion;
  final MusicLibrarySortDirection sortDirection;
  final Set<int> selectedSongIds;
  final int? selectedTrackId;
  final bool isPlaying;
  final bool multiSelect;
  final SmPlayerI18n i18n;
  final ValueChanged<MusicLibrarySortCriterion> onSort;
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
          child: _CompactSortBar(
            sortCriterion: sortCriterion,
            sortDirection: sortDirection,
            i18n: i18n,
            onSort: onSort,
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: scrollController,
            padding: EdgeInsets.only(
              bottom: multiSelect ? multiSelectCommandBarScrollSpacer : 4,
            ),
            itemExtent: 76,
            itemCount: songs.length,
            itemBuilder: (context, index) {
              final song = songs[index];
              return _CompactSongRow(
                song: song,
                selected: selectedSongIds.contains(song.id),
                current: song.id == selectedTrackId,
                playing: song.id == selectedTrackId && isPlaying,
                selectionMode: multiSelect,
                i18n: i18n,
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
      ],
    );
  }
}

class _CompactSortBar extends StatelessWidget {
  const _CompactSortBar({
    required this.sortCriterion,
    required this.sortDirection,
    required this.i18n,
    required this.onSort,
  });

  final MusicLibrarySortCriterion sortCriterion;
  final MusicLibrarySortDirection sortDirection;
  final SmPlayerI18n i18n;
  final ValueChanged<MusicLibrarySortCriterion> onSort;

  @override
  Widget build(BuildContext context) {
    final colors = _LibraryPalette.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 8),
      decoration: BoxDecoration(
        color: colors.panel,
        border: Border(bottom: BorderSide(color: colors.rowBorder)),
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          _CompactSortButton(
            label: i18n.t('musicLibrary.titleHeader'),
            criterion: MusicLibrarySortCriterion.title,
            activeCriterion: sortCriterion,
            direction: sortDirection,
            onSort: onSort,
          ),
          _CompactSortButton(
            label: i18n.t('common.artist'),
            criterion: MusicLibrarySortCriterion.artist,
            activeCriterion: sortCriterion,
            direction: sortDirection,
            onSort: onSort,
          ),
          _CompactSortButton(
            label: i18n.t('common.album'),
            criterion: MusicLibrarySortCriterion.album,
            activeCriterion: sortCriterion,
            direction: sortDirection,
            onSort: onSort,
          ),
          _CompactSortButton(
            label: i18n.t('common.duration'),
            criterion: MusicLibrarySortCriterion.duration,
            activeCriterion: sortCriterion,
            direction: sortDirection,
            onSort: onSort,
          ),
          _CompactSortButton(
            label: i18n.t('common.playCount'),
            criterion: MusicLibrarySortCriterion.playCount,
            activeCriterion: sortCriterion,
            direction: sortDirection,
            onSort: onSort,
          ),
          _CompactSortButton(
            label: i18n.t('common.dateAdded'),
            criterion: MusicLibrarySortCriterion.dateAdded,
            activeCriterion: sortCriterion,
            direction: sortDirection,
            onSort: onSort,
          ),
        ],
      ),
    );
  }
}

class _CompactSortButton extends StatelessWidget {
  const _CompactSortButton({
    required this.label,
    required this.criterion,
    required this.activeCriterion,
    required this.direction,
    required this.onSort,
  });

  final String label;
  final MusicLibrarySortCriterion criterion;
  final MusicLibrarySortCriterion activeCriterion;
  final MusicLibrarySortDirection direction;
  final ValueChanged<MusicLibrarySortCriterion> onSort;

  @override
  Widget build(BuildContext context) {
    final colors = _LibraryPalette.of(context);
    final active = criterion == activeCriterion;
    return TextButton.icon(
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 28),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        foregroundColor: active ? colors.accentStrong : colors.textMuted,
        backgroundColor: active ? colors.accentSoft : Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      onPressed: () {
        onSort(criterion);
      },
      icon:
          active
              ? Icon(
                direction == MusicLibrarySortDirection.ascending
                    ? FluentIcons.chevron_up_16_regular
                    : FluentIcons.chevron_down_16_regular,
                size: 13,
              )
              : const SizedBox.shrink(),
      label: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}

class _CompactSongRow extends StatefulWidget {
  const _CompactSongRow({
    required this.song,
    required this.selected,
    required this.current,
    required this.playing,
    required this.selectionMode,
    required this.i18n,
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
  final VoidCallback onSelected;
  final VoidCallback onAddNextAndPlay;
  final VoidCallback onTogglePlayPause;
  final VoidCallback onToggleSelection;
  final VoidCallback onToggleFavorite;
  final VoidCallback onPlayNext;
  final FutureOr<void> Function(BuildContext) onOpenAddToPlaylistMenu;
  final FutureOr<void> Function(Offset) onOpenContextMenu;

  @override
  State<_CompactSongRow> createState() => _CompactSongRowState();
}

class _CompactSongRowState extends State<_CompactSongRow> {
  var _hovered = false;
  var _menuOpen = false;

  bool get _hoverActive => _hovered || _menuOpen;

  Future<void> _openMenu(FutureOr<void> Function() open) async {
    setState(() {
      _menuOpen = true;
    });
    try {
      await open();
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        setState(() {
          _menuOpen = false;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _LibraryPalette.of(context);
    final hoverActive = _hoverActive;
    final rowBackground =
        widget.selected
            ? colors.rowSelected
            : widget.current
            ? colors.rowCurrent
            : hoverActive
            ? colors.rowHover
            : Colors.transparent;
    final rowSurface =
        widget.selected || widget.current || hoverActive
            ? Color.alphaBlend(rowBackground, colors.panel)
            : Colors.transparent;
    return MouseRegion(
      opaque: false,
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
        onTap:
            widget.selectionMode ? widget.onToggleSelection : widget.onSelected,
        onDoubleTap: widget.selectionMode ? null : widget.onAddNextAndPlay,
        hoverColor: Colors.transparent,
        onSecondaryTapDown: (details) {
          unawaited(
            _openMenu(() => widget.onOpenContextMenu(details.globalPosition)),
          );
        },
        child: Container(
          key: ValueKey('MusicLibrary.CompactRow.${widget.song.id}'),
          decoration: BoxDecoration(
            color:
                hoverActive || widget.current || widget.selected
                    ? rowSurface
                    : Colors.transparent,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Container(
              padding: const EdgeInsets.fromLTRB(6, 8, 8, 8),
              decoration: BoxDecoration(
                color:
                    hoverActive || widget.current || widget.selected
                        ? Colors.transparent
                        : rowSurface,
                border: Border(top: BorderSide(color: colors.rowBorder)),
              ),
              child: IgnorePointer(
                ignoring: widget.selectionMode,
                child: Stack(
                  alignment: Alignment.centerRight,
                  children: [
                    Row(
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            LibraryRowArtwork(
                              song: widget.song,
                              size: 46,
                              current: widget.current,
                              playing: widget.playing,
                              rowHovered: hoverActive && !widget.selectionMode,
                              onPlay: widget.onAddNextAndPlay,
                              onTogglePlayPause: widget.onTogglePlayPause,
                            ),
                            if (widget.selectionMode)
                              Positioned(
                                top: -5,
                                right: -5,
                                child: _SelectionMark(
                                  selected: widget.selected,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                widget.song.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color:
                                      widget.current
                                          ? colors.accentStrong
                                          : colors.textStrong,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Row(
                                children: [
                                  Flexible(
                                    child: _InlineRouteText(
                                      text: _displayArtists(
                                        widget.song,
                                        widget.i18n,
                                      ),
                                      current: widget.current,
                                      onTap: () {
                                        final artists = getSongArtists(
                                          widget.song,
                                        );
                                        final artist =
                                            artists.isEmpty
                                                ? widget.i18n.t(
                                                  'common.artistUnknown',
                                                )
                                                : artists.first;
                                        context.go(
                                          '/artists?artist=${Uri.encodeQueryComponent(artist)}',
                                        );
                                      },
                                    ),
                                  ),
                                  Text(
                                    ' · ',
                                    style: TextStyle(
                                      color:
                                          widget.current
                                              ? colors.currentMuted
                                              : colors.textMuted,
                                      fontSize: 14,
                                      height: 1.35,
                                    ),
                                  ),
                                  Flexible(
                                    child: _InlineRouteText(
                                      text: _displayAlbum(
                                        widget.song,
                                        widget.i18n,
                                      ),
                                      current: widget.current,
                                      onTap: () {
                                        context.go(
                                          '/albums?album=${Uri.encodeQueryComponent(_displayAlbum(widget.song, widget.i18n))}',
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                _compactSongDetailText(
                                  widget.song,
                                  widget.i18n,
                                ),
                                key: ValueKey(
                                  'MusicLibrary.CompactDetails.${widget.song.id}',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color:
                                      widget.current
                                          ? colors.currentMuted
                                          : colors.textMuted,
                                  fontSize: 12,
                                  height: 1.25,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          key: ValueKey(
                            'MusicLibrary.CompactDuration.${widget.song.id}',
                          ),
                          width: 42,
                          child: Text(
                            _formatDuration(widget.song.duration),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color:
                                  widget.current
                                      ? colors.currentMuted
                                      : colors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    _CompactMusicLibraryRowActionOverlay(
                      visible: hoverActive && !widget.selectionMode,
                      maskColor: rowSurface,
                      actions: _MusicLibraryRowActions(
                        song: widget.song,
                        visible: true,
                        i18n: widget.i18n,
                        onToggleFavorite: widget.onToggleFavorite,
                        onAddToPlaylist:
                            (buttonContext) => unawaited(
                              _openMenu(
                                () => widget.onOpenAddToPlaylistMenu(
                                  buttonContext,
                                ),
                              ),
                            ),
                        onPlayNext: widget.onPlayNext,
                        onOpenContextMenu:
                            (position) => unawaited(
                              _openMenu(
                                () => widget.onOpenContextMenu(position),
                              ),
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MusicLibraryRowActions extends StatelessWidget {
  const _MusicLibraryRowActions({
    required this.song,
    required this.visible,
    required this.i18n,
    required this.onToggleFavorite,
    required this.onAddToPlaylist,
    required this.onPlayNext,
    required this.onOpenContextMenu,
  });

  final LibrarySong song;
  final bool visible;
  final SmPlayerI18n i18n;
  final VoidCallback onToggleFavorite;
  final FutureOr<void> Function(BuildContext) onAddToPlaylist;
  final VoidCallback onPlayNext;
  final FutureOr<void> Function(Offset) onOpenContextMenu;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 120),
        child: SizedBox(
          width: 136,
          child: Row(
            key: ValueKey('MusicLibrary.RowActions.${song.id}'),
            mainAxisSize: MainAxisSize.min,
            children: [
              _MusicLibraryRowActionButton(
                key: ValueKey('MusicLibrary.FavoriteAction.${song.id}'),
                tooltip:
                    song.favorite
                        ? i18n.t('context.removeFavorite')
                        : i18n.t('context.addFavorite'),
                icon: SmPlayerFavoriteIcon(favorite: song.favorite, size: 18),
                active: song.favorite,
                onPressed: onToggleFavorite,
              ),
              Builder(
                builder:
                    (buttonContext) => _MusicLibraryRowActionButton(
                      key: ValueKey('MusicLibrary.AddToAction.${song.id}'),
                      tooltip: i18n.t('context.addToPlaylist'),
                      icon: const Icon(FluentIcons.add_20_regular, size: 18),
                      onPressed: () {
                        onAddToPlaylist(buttonContext);
                      },
                    ),
              ),
              _MusicLibraryRowActionButton(
                key: ValueKey('MusicLibrary.PlayNextAction.${song.id}'),
                tooltip: i18n.t('context.playNext'),
                icon: const SmPlayerPlayNextIcon(size: 18),
                onPressed: onPlayNext,
              ),
              Builder(
                builder:
                    (buttonContext) => _MusicLibraryRowActionButton(
                      key: ValueKey('MusicLibrary.MoreAction.${song.id}'),
                      tooltip: i18n.t('player.more'),
                      icon: const SmPlayerMoreHorizontalIcon(size: 18),
                      onPressed: () {
                        final box =
                            buttonContext.findRenderObject() as RenderBox;
                        onOpenContextMenu(
                          box.localToGlobal(Offset(0, box.size.height + 8)),
                        );
                      },
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _compactSongDetailText(LibrarySong song, SmPlayerI18n i18n) {
  return '${_formatDateTime(song.dateAdded)}'
      ' · ${i18n.t('common.playCount')} ${song.playCount}';
}

class _MusicLibraryRowActionButton extends StatefulWidget {
  const _MusicLibraryRowActionButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.active = false,
  });

  final String tooltip;
  final Widget icon;
  final VoidCallback onPressed;
  final bool active;

  @override
  State<_MusicLibraryRowActionButton> createState() =>
      _MusicLibraryRowActionButtonState();
}

class _MusicLibraryRowActionButtonState
    extends State<_MusicLibraryRowActionButton> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = _LibraryPalette.of(context);
    final foregroundColor =
        widget.active
            ? colors.favorite
            : _hovered
            ? colors.accentStrong
            : colors.textMuted;
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
      child: AnimatedSlide(
        offset: Offset(0, _hovered ? -1 / 34 : 0),
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: _hovered ? colors.accentSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: IconButton(
            tooltip: widget.tooltip,
            iconSize: 18,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 34, height: 34),
            style: IconButton.styleFrom(
              minimumSize: const Size.square(34),
              fixedSize: const Size.square(34),
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              backgroundColor: Colors.transparent,
              foregroundColor: foregroundColor,
              hoverColor: Colors.transparent,
              highlightColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: widget.onPressed,
            icon: IconTheme(
              data: IconThemeData(color: foregroundColor, size: 18),
              child: widget.icon,
            ),
          ),
        ),
      ),
    );
  }
}

class LibraryRowArtwork extends StatefulWidget {
  const LibraryRowArtwork({
    super.key,
    required this.song,
    required this.size,
    required this.current,
    required this.playing,
    required this.rowHovered,
    required this.onPlay,
    required this.onTogglePlayPause,
  });

  final LibrarySong song;
  final double size;
  final bool current;
  final bool playing;
  final bool rowHovered;
  final VoidCallback onPlay;
  final VoidCallback onTogglePlayPause;

  @override
  State<LibraryRowArtwork> createState() => _LibraryRowArtworkState();
}

class _LibraryRowArtworkState extends State<LibraryRowArtwork> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final hovered = _hovered || widget.rowHovered;
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox.square(
          dimension: widget.size,
          child: Stack(
            fit: StackFit.expand,
            children: [
              SongArtwork(artworkPath: widget.song.thumbnailPath),
              if (widget.current && !hovered)
                SmPlayerPlayingWaveGlass(
                  playing: widget.playing,
                  keyPrefix: 'MusicLibrary.Playing.${widget.song.id}',
                ),
              IgnorePointer(
                ignoring: !hovered,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 120),
                  opacity: hovered ? 1 : 0,
                  child: Center(
                    child: ArtworkFloatingActionButton(
                      key: ValueKey(
                        'MusicLibrary.ArtworkPlay.${widget.song.id}',
                      ),
                      tooltip:
                          widget.current && widget.playing
                              ? context.smPlayerI18n.t('context.pause')
                              : context.smPlayerI18n.t('context.play'),
                      size: widget.size - 8,
                      iconSize: 16,
                      icon:
                          widget.current && widget.playing
                              ? const SmPlayerPauseIcon(
                                color: Colors.white,
                                size: 16,
                              )
                              : const SmPlayerPlayIcon(
                                color: Colors.white,
                                size: 16,
                              ),
                      onPressed:
                          widget.current
                              ? widget.onTogglePlayPause
                              : widget.onPlay,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectionMark extends StatelessWidget {
  const _SelectionMark({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 24,
        height: 24,
        decoration: const BoxDecoration(
          color: Color(0xff0063b1),
          shape: BoxShape.circle,
        ),
        child:
            selected
                ? const Icon(
                  FluentIcons.checkmark_16_regular,
                  color: Colors.white,
                  size: 16,
                )
                : null,
      ),
    );
  }
}
