part of 'recent_page.dart';

const _recentSongActionButtonSize = 32.0;
const _recentSongActionsSpacing = 4.0;
const _recentSongActionsRightInset = 8.0;
const _recentSongHoverActionsReservedWidth =
    _recentSongActionButtonSize * 2 +
    _recentSongActionsSpacing +
    _recentSongActionsRightInset;
const _recentSongArtistLineHoverReserveWidth =
    _recentSongHoverActionsReservedWidth + _recentSongActionButtonSize;

class _GridViewMusicItemControl extends StatefulWidget {
  const _GridViewMusicItemControl({
    required this.song,
    required this.detailLabel,
    required this.selected,
    required this.current,
    required this.playing,
    required this.multiSelect,
    required this.metrics,
    required this.onPlayTrack,
    required this.onToggleSelection,
    required this.onOpenAddToMenu,
    required this.onOpenContextMenu,
    required this.onPlayNext,
    required this.onOpenMoreMenu,
  });

  final LibrarySong song;
  final String detailLabel;
  final bool selected;
  final bool current;
  final bool playing;
  final bool multiSelect;
  final _RecentSongTileMetrics metrics;
  final VoidCallback onPlayTrack;
  final VoidCallback onToggleSelection;
  final ValueChanged<Offset> onOpenAddToMenu;
  final ValueChanged<Offset> onOpenContextMenu;
  final VoidCallback onPlayNext;
  final ValueChanged<Offset> onOpenMoreMenu;

  @override
  State<_GridViewMusicItemControl> createState() =>
      _GridViewMusicItemControlState();
}

class _GridViewMusicItemControlState extends State<_GridViewMusicItemControl> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = _RecentSongTileColors.of(context);
    final active = widget.selected || _hovered;
    final showHoverActions = active && !widget.multiSelect;
    final textColor = widget.current ? colors.currentText : colors.textStrong;
    final artistColor = widget.current ? colors.currentMuted : colors.textMuted;
    final detailColor = widget.current ? colors.currentSoft : colors.textSoft;
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
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        splashFactory: NoSplash.splashFactory,
        hoverColor: Colors.transparent,
        highlightColor: Colors.transparent,
        onSecondaryTapDown: (details) {
          widget.onOpenContextMenu(details.globalPosition);
        },
        onTap:
            widget.multiSelect ? widget.onToggleSelection : widget.onPlayTrack,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.ease,
          height: widget.metrics.tileExtent,
          padding: widget.metrics.padding,
          decoration: BoxDecoration(
            color: active ? colors.activeSurface : colors.inactiveSurface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: active ? colors.activeShadow : const [],
          ),
          foregroundDecoration:
              active
                  ? BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.activeBorder),
                  )
                  : null,
          child: Stack(
            children: [
              Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      SizedBox.square(
                        key: ValueKey('RecentSong.Artwork.${widget.song.id}'),
                        dimension: widget.metrics.artworkSize,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: active ? colors.artworkShadow : const [],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: colors.artworkSurface,
                              ),
                              child: _RecentSongArtwork(song: widget.song),
                            ),
                          ),
                        ),
                      ),
                      if (widget.multiSelect || widget.selected)
                        Positioned(
                          top: -6,
                          right: -6,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: _RecentColors.accent,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: colors.selectionMarkBorder,
                                width: 2,
                              ),
                              boxShadow: colors.selectionMarkShadow,
                            ),
                            child: SizedBox.square(
                              dimension: 30,
                              child:
                                  widget.selected
                                      ? const Icon(
                                        FluentIcons.checkmark_16_regular,
                                        color: Colors.white,
                                        size: 17,
                                      )
                                      : null,
                            ),
                          ),
                        )
                      else if (_hovered)
                        Positioned.fill(
                          child: Center(
                            child: Builder(
                              builder:
                                  (buttonContext) =>
                                      ArtworkFloatingActionButton(
                                        tooltip: context.smPlayerI18n.t(
                                          'context.addToPlaylist',
                                        ),
                                        size: 48,
                                        iconSize: 19,
                                        icon: const Icon(
                                          FluentIcons.add_20_regular,
                                          color: Colors.white,
                                          size: 19,
                                        ),
                                        onPressed: () {
                                          final box =
                                              buttonContext.findRenderObject()
                                                  as RenderBox;
                                          widget.onOpenAddToMenu(
                                            box.localToGlobal(
                                              Offset(0, box.size.height + 8),
                                            ),
                                          );
                                        },
                                      ),
                            ),
                          ),
                        ),
                      if (widget.current && !_hovered && !widget.multiSelect)
                        Positioned.fill(
                          child: SmPlayerPlayingWaveGlass(
                            playing: widget.playing,
                            dimension: 48,
                            keyPrefix: 'RecentSong.Playing.${widget.song.id}',
                          ),
                        ),
                    ],
                  ),
                  SizedBox(width: widget.metrics.copyGap),
                  Expanded(
                    child: SizedBox.expand(
                      child: Padding(
                        padding: widget.metrics.copyPadding,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.song.title,
                              maxLines: widget.detailLabel.isEmpty ? 2 : 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 15,
                                height: 1.32,
                                fontVariations: const [
                                  FontVariation('wght', 650),
                                ],
                              ),
                            ),
                            SizedBox(height: widget.metrics.copyLineGap),
                            AnimatedPadding(
                              duration: const Duration(milliseconds: 120),
                              curve: Curves.ease,
                              padding: EdgeInsets.only(
                                right:
                                    showHoverActions
                                        ? _recentSongArtistLineHoverReserveWidth
                                        : 0,
                              ),
                              child: Text(
                                key: const ValueKey('RecentSong.ArtistLine'),
                                displayArtists(
                                  widget.song,
                                  context.smPlayerI18n,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: artistColor,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            if (widget.detailLabel.isNotEmpty) ...[
                              SizedBox(height: widget.metrics.copyLineGap),
                              Text(
                                widget.detailLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: detailColor,
                                  fontSize: 12,
                                  height: 1.25,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (showHoverActions)
                Positioned(
                  top:
                      (widget.metrics.tileExtent -
                          _recentSongActionButtonSize) /
                      2,
                  right: _recentSongActionsRightInset,
                  child: Row(
                    spacing: _recentSongActionsSpacing,
                    children: [
                      _RecentSongActionButton(
                        tooltip: context.smPlayerI18n.t('context.playNext'),
                        icon: const SmPlayerPlayNextIcon(size: 18),
                        onPressed: widget.onPlayNext,
                      ),
                      Builder(
                        builder:
                            (buttonContext) => _RecentSongActionButton(
                              tooltip: context.smPlayerI18n.t('player.more'),
                              icon: const Icon(
                                FluentIcons.more_horizontal_20_regular,
                                size: 18,
                              ),
                              onPressed: () {
                                final box =
                                    buttonContext.findRenderObject()
                                        as RenderBox;
                                widget.onOpenMoreMenu(
                                  box.localToGlobal(
                                    Offset(0, box.size.height + 8),
                                  ),
                                );
                              },
                            ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentSongActionButton extends StatefulWidget {
  const _RecentSongActionButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final Widget icon;
  final VoidCallback onPressed;

  @override
  State<_RecentSongActionButton> createState() =>
      _RecentSongActionButtonState();
}

class _RecentSongActionButtonState extends State<_RecentSongActionButton> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = _RecentSongActionButtonColors.of(context);
    final foreground = _hovered ? colors.hoverForeground : colors.foreground;
    return Tooltip(
      message: widget.tooltip,
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          transform: Matrix4.translationValues(0, _hovered ? -1 : 0, 0),
          child: IconButton(
            tooltip: widget.tooltip,
            style: ButtonStyle(
              fixedSize: const WidgetStatePropertyAll(
                Size.square(_recentSongActionButtonSize),
              ),
              minimumSize: const WidgetStatePropertyAll(
                Size.square(_recentSongActionButtonSize),
              ),
              maximumSize: const WidgetStatePropertyAll(
                Size.square(_recentSongActionButtonSize),
              ),
              padding: const WidgetStatePropertyAll(EdgeInsets.zero),
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.hovered) ||
                    states.contains(WidgetState.focused)) {
                  return colors.hoverBackground;
                }
                return Colors.transparent;
              }),
              foregroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.hovered) ||
                    states.contains(WidgetState.focused)) {
                  return colors.hoverForeground;
                }
                return colors.foreground;
              }),
              overlayColor: const WidgetStatePropertyAll(Colors.transparent),
            ),
            onPressed: widget.onPressed,
            icon: IconTheme(
              data: IconThemeData(color: foreground, size: 18),
              child: widget.icon,
            ),
          ),
        ),
      ),
    );
  }
}

class _RecentSongActionButtonColors {
  const _RecentSongActionButtonColors({
    required this.foreground,
    required this.hoverBackground,
    required this.hoverForeground,
  });

  final Color foreground;
  final Color hoverBackground;
  final Color hoverForeground;

  static const light = _RecentSongActionButtonColors(
    foreground: Color(0xb8586474),
    hoverBackground: Color(0x9effffff),
    hoverForeground: _RecentColors.accentStrong,
  );

  static const dark = _RecentSongActionButtonColors(
    foreground: Color(0xadcbd5e1),
    hoverBackground: Color(0x17ffffff),
    hoverForeground: Color(0xff459de2),
  );

  static _RecentSongActionButtonColors of(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? dark : light;
  }
}

class _RecentSongArtwork extends ConsumerStatefulWidget {
  const _RecentSongArtwork({required this.song});

  final LibrarySong song;

  @override
  ConsumerState<_RecentSongArtwork> createState() => _RecentSongArtworkState();
}

class _RecentSongArtworkState extends ConsumerState<_RecentSongArtwork> {
  Future<String>? _artworkFuture;

  @override
  void initState() {
    super.initState();
    _syncArtworkFuture();
  }

  @override
  void didUpdateWidget(covariant _RecentSongArtwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.song.id != widget.song.id ||
        oldWidget.song.thumbnailPath != widget.song.thumbnailPath) {
      _syncArtworkFuture();
    }
  }

  @override
  Widget build(BuildContext context) {
    final artworkPath = widget.song.thumbnailPath;
    if (artworkPath.isNotEmpty && File(artworkPath).existsSync()) {
      return SongArtwork(artworkPath: artworkPath);
    }
    final future = _artworkFuture;
    if (future == null) {
      return const SongArtwork(artworkPath: '');
    }
    return FutureBuilder<String>(
      future: future,
      builder: (context, snapshot) {
        final path = snapshot.data ?? '';
        return SongArtwork(artworkPath: path);
      },
    );
  }

  void _syncArtworkFuture() {
    final thumbnailPath = widget.song.thumbnailPath;
    if (thumbnailPath.isNotEmpty && File(thumbnailPath).existsSync()) {
      _artworkFuture = null;
      return;
    }
    _artworkFuture = _recentArtworkResolver.resolve(
      ref.read(libraryRepositoryProvider),
      widget.song.id,
    );
  }
}

final _recentArtworkResolver = _RecentArtworkResolver();

class _RecentArtworkResolver {
  final _cache = <String, String>{};
  final _pending = <LibraryRepository, Map<int, Completer<String>>>{};
  Timer? _flushTimer;

  Future<String> resolve(LibraryRepository repository, int songId) {
    final key = _cacheKey(repository, songId);
    final cached = _cache[key];
    if (cached != null) {
      return Future.value(cached);
    }

    final repositoryPending =
        _pending[repository] ?? <int, Completer<String>>{};
    _pending[repository] = repositoryPending;
    final existing = repositoryPending[songId];
    if (existing != null) {
      return existing.future;
    }

    final completer = Completer<String>();
    repositoryPending[songId] = completer;
    _flushTimer ??= Timer(Duration.zero, _flush);
    return completer.future;
  }

  void _flush() {
    _flushTimer = null;
    final pending = Map<LibraryRepository, Map<int, Completer<String>>>.from(
      _pending,
    );
    _pending.clear();
    for (final entry in pending.entries) {
      unawaited(_resolveBatch(entry.key, entry.value));
    }
  }

  Future<void> _resolveBatch(
    LibraryRepository repository,
    Map<int, Completer<String>> completersBySongId,
  ) async {
    final songIds = completersBySongId.keys.toList();
    try {
      final snapshots = await repository.getSongArtworkSnapshots(songIds);
      final pathsBySongId = {
        for (final snapshot in snapshots) snapshot.songId: snapshot.artworkUrl,
      };
      for (final songId in songIds) {
        final path = pathsBySongId[songId] ?? '';
        _cache[_cacheKey(repository, songId)] = path;
        completersBySongId[songId]!.complete(path);
      }
    } on Object catch (error, stackTrace) {
      for (final completer in completersBySongId.values) {
        completer.completeError(error, stackTrace);
      }
    }
  }

  String _cacheKey(LibraryRepository repository, int songId) {
    return '${identityHashCode(repository)}:$songId';
  }
}
