part of 'recent_page.dart';

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
    required this.onOpenContextMenu,
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
  final ValueChanged<Offset> onOpenContextMenu;

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
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox.square(
                      dimension: widget.metrics.artworkSize,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.artworkSurface,
                          boxShadow: active ? colors.artworkShadow : const [],
                        ),
                        child: _RecentSongArtwork(song: widget.song),
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
                        child: ArtworkFloatingActionButton(
                          tooltip: context.smPlayerI18n.t('context.play'),
                          size: 48,
                          iconSize: 19,
                          icon:
                              widget.playing
                                  ? const SmPlayerPauseIcon(
                                    size: 19,
                                    color: Colors.white,
                                  )
                                  : const SmPlayerPlayIcon(
                                    size: 19,
                                    color: Colors.white,
                                  ),
                          onPressed: widget.onPlayTrack,
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
                            fontVariations: const [FontVariation('wght', 650)],
                          ),
                        ),
                        SizedBox(height: widget.metrics.copyLineGap),
                        Text(
                          displayArtists(widget.song, context.smPlayerI18n),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: artistColor, fontSize: 13),
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
        ),
      ),
    );
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
