part of 'recent_page.dart';

const _recentSongActionButtonSize = 32.0;
const _recentSongActionsSpacing = 4.0;
const _recentSongActionsRightInset = 8.0;
const _recentSongHoverActionsReservedWidth =
    _recentSongActionButtonSize * 2 +
    _recentSongActionsSpacing +
    _recentSongActionsRightInset;
const _recentSongActionOverlayWidth =
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

class _GridViewMusicItemControlState extends State<_GridViewMusicItemControl>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hoverActionsController;
  var _hovered = false;
  var _suppressNextTileTap = false;

  @override
  void initState() {
    super.initState();
    _hoverActionsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
      reverseDuration: const Duration(milliseconds: 180),
    );
  }

  @override
  void didUpdateWidget(covariant _GridViewMusicItemControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.multiSelect != widget.multiSelect) {
      if (widget.multiSelect) {
        _hoverActionsController.reverse();
      } else if (_hovered) {
        _hoverActionsController.forward();
      }
    }
  }

  @override
  void dispose() {
    _hoverActionsController.dispose();
    super.dispose();
  }

  void _suppressTileTapForLink() {
    _suppressNextTileTap = true;
  }

  void _releaseTileTapSuppression() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _suppressNextTileTap = false;
    });
  }

  void _handleTileTap() {
    if (_suppressNextTileTap) {
      _suppressNextTileTap = false;
      return;
    }
    if (widget.multiSelect) {
      widget.onToggleSelection();
      return;
    }
    widget.onPlayTrack();
  }

  @override
  Widget build(BuildContext context) {
    final colors = _RecentSongTileColors.of(context);
    final active = widget.selected || _hovered;
    final selectedSurface = Color.alphaBlend(
      colors.activeSurface,
      Theme.of(context).scaffoldBackgroundColor,
    );
    final hoverSurface =
        Theme.of(context).brightness == Brightness.dark
            ? colors.activeSurface
            : colors.activeSurface.withValues(alpha: 0.85);
    final surface =
        widget.selected
            ? selectedSurface
            : _hovered
            ? hoverSurface
            : colors.inactiveSurface;
    final showHoverActions = _hovered && !widget.multiSelect;
    final textColor = widget.current ? colors.currentText : colors.textStrong;
    final artistColor = widget.current ? colors.currentMuted : colors.textMuted;
    final detailColor = widget.current ? colors.currentSoft : colors.textSoft;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        if (!widget.multiSelect) {
          _hoverActionsController.forward();
        }
        setState(() {
          _hovered = true;
        });
      },
      onExit: (_) {
        _hoverActionsController.reverse();
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
        onTap: _handleTileTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.ease,
          clipBehavior: Clip.antiAlias,
          height: widget.metrics.tileExtent,
          padding: widget.metrics.padding,
          decoration: BoxDecoration(
            color: surface,
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
              AnimatedBuilder(
                animation: _hoverActionsController,
                child: Row(
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
                              boxShadow:
                                  active ? colors.artworkShadow : const [],
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
                              _RecentSongArtistLink(
                                song: widget.song,
                                foregroundColor: artistColor,
                                hoverColor: colors.currentText,
                                onPointerDown: _suppressTileTapForLink,
                                onPointerUp: _releaseTileTapSuppression,
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
                builder: (context, child) {
                  final progress = Curves.easeOut.transform(
                    _hoverActionsController.value,
                  );
                  return ShaderMask(
                    blendMode: BlendMode.dstIn,
                    shaderCallback: (bounds) {
                      final fadeStart = ((bounds.width -
                                  _recentSongActionOverlayWidth * progress) /
                              bounds.width)
                          .clamp(0.0, 1.0);
                      final fadeEnd = ((bounds.width -
                                  (_recentSongActionOverlayWidth - 28) *
                                      progress) /
                              bounds.width)
                          .clamp(0.0, 1.0);
                      return LinearGradient(
                        colors: const [
                          Colors.white,
                          Colors.white,
                          Colors.transparent,
                          Colors.transparent,
                        ],
                        stops: [0, fadeStart, fadeEnd, 1],
                      ).createShader(bounds);
                    },
                    child: child,
                  );
                },
              ),
              Positioned(
                top: 0,
                right: 0,
                bottom: 0,
                child: AnimatedBuilder(
                  animation: _hoverActionsController,
                  child: SizedBox(
                    width: _recentSongActionOverlayWidth,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(
                          right: _recentSongActionsRightInset,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          spacing: _recentSongActionsSpacing,
                          children: [
                            _RecentSongActionButton(
                              tooltip: context.smPlayerI18n.t(
                                'context.playNext',
                              ),
                              icon: const SmPlayerPlayNextIcon(size: 18),
                              onPressed: widget.onPlayNext,
                            ),
                            Builder(
                              builder:
                                  (buttonContext) => _RecentSongActionButton(
                                    tooltip: context.smPlayerI18n.t(
                                      'player.more',
                                    ),
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
                    ),
                  ),
                  builder: (context, child) {
                    final rawProgress = _hoverActionsController.value;
                    final progress = Curves.easeOutCubic.transform(rawProgress);
                    final opacity = const Interval(
                      0.12,
                      1,
                      curve: Curves.easeOut,
                    ).transform(rawProgress);
                    return IgnorePointer(
                      ignoring: !showHoverActions,
                      child: SizedBox(
                        width: _recentSongActionOverlayWidth * progress,
                        child: ClipRect(
                          child: OverflowBox(
                            alignment: Alignment.centerRight,
                            minWidth: _recentSongActionOverlayWidth,
                            maxWidth: _recentSongActionOverlayWidth,
                            child: Opacity(
                              opacity: opacity,
                              child: Transform.translate(
                                offset: Offset(10 * (1 - progress), 0),
                                child: child,
                              ),
                            ),
                          ),
                        ),
                      ),
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

class _RecentSongArtistLink extends StatefulWidget {
  const _RecentSongArtistLink({
    required this.song,
    required this.foregroundColor,
    required this.hoverColor,
    required this.onPointerDown,
    required this.onPointerUp,
  });

  final LibrarySong song;
  final Color foregroundColor;
  final Color hoverColor;
  final VoidCallback onPointerDown;
  final VoidCallback onPointerUp;

  @override
  State<_RecentSongArtistLink> createState() => _RecentSongArtistLinkState();
}

class _RecentSongArtistLinkState extends State<_RecentSongArtistLink> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final artist = displayArtists(widget.song, i18n);
    return MouseRegion(
      key: const ValueKey('RecentSong.ArtistLine'),
      opaque: false,
      hitTestBehavior: HitTestBehavior.opaque,
      cursor: SystemMouseCursors.click,
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
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) {
          widget.onPointerDown();
        },
        onPointerUp: (_) {
          context.go('/artists?artist=${Uri.encodeQueryComponent(artist)}');
          widget.onPointerUp();
        },
        child: ColoredBox(
          color: Colors.transparent,
          child: Text(
            artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _hovered ? widget.hoverColor : widget.foregroundColor,
              fontSize: 13,
            ),
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
