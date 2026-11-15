part of 'music_library_page.dart';

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
  final FutureOr<void> Function(BuildContext) onOpenAddToPlaylistMenu;
  final FutureOr<void> Function(Offset) onOpenContextMenu;

  @override
  State<_WideSongRow> createState() => _WideSongRowState();
}

class _WideSongRowState extends State<_WideSongRow> {
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
    final actionHoverActive = hoverActive && !widget.selectionMode;
    return MouseRegion(
      opaque: false,
      onEnter: (_) {
        setState(() {
          _hovered = true;
        });
      },
      onHover: (_) {
        if (!_hovered) {
          setState(() {
            _hovered = true;
          });
        }
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
        onSecondaryTapDown: (details) {
          unawaited(
            _openMenu(() => widget.onOpenContextMenu(details.globalPosition)),
          );
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
                        : hoverActive
                        ? colors.rowHover
                        : Colors.transparent,
                border: Border(top: BorderSide(color: colors.rowBorder)),
              ),
              child: IgnorePointer(
                ignoring: widget.selectionMode,
                child: Row(
                  children: [
                    SizedBox(
                      width: widget.columnWidths[_LibraryColumn.artwork]!,
                      child: Center(
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            LibraryRowArtwork(
                              song: widget.song,
                              size: 42,
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
                            ignoring: actionHoverActive,
                            child: AnimatedOpacity(
                              opacity:
                                  widget.song.favorite && !actionHoverActive
                                      ? 1
                                      : 0,
                              duration: const Duration(milliseconds: 120),
                              child: IconButton(
                                tooltip: widget.i18n.t('common.favorite'),
                                icon: const SmPlayerFavoriteIcon(
                                  favorite: true,
                                  size: 18,
                                  animate: false,
                                ),
                                color: colors.favorite,
                                onPressed: widget.onToggleFavorite,
                              ),
                            ),
                          ),
                          IgnorePointer(
                            ignoring: !actionHoverActive,
                            child: AnimatedOpacity(
                              opacity: actionHoverActive ? 1 : 0,
                              duration: const Duration(milliseconds: 120),
                              child: _MusicLibraryRowActionButton(
                                key: ValueKey(
                                  'MusicLibrary.FavoriteAction.${widget.song.id}',
                                ),
                                tooltip:
                                    widget.song.favorite
                                        ? widget.i18n.t(
                                          'context.removeFavorite',
                                        )
                                        : widget.i18n.t('context.addFavorite'),
                                icon: SmPlayerFavoriteIcon(
                                  favorite: widget.song.favorite,
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

class _InlineRouteText extends StatefulWidget {
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
  State<_InlineRouteText> createState() => _InlineRouteTextState();
}

class _InlineRouteTextState extends State<_InlineRouteText> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = _LibraryPalette.of(context);
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
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerHover: (_) {
          if (!_hovered) {
            setState(() {
              _hovered = true;
            });
          }
        },
        onPointerUp: (_) {
          widget.onTap();
        },
        child: ColoredBox(
          color: Colors.transparent,
          child: Text(
            widget.text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color:
                  _hovered
                      ? colors.currentForeground
                      : widget.current
                      ? colors.currentMuted
                      : colors.textMuted,
              fontSize: 14,
              height: 1.35,
            ),
          ),
        ),
      ),
    );
  }
}
