part of 'recent_page.dart';

const _recentSongActionButtonSize = 32.0;
const _recentSongActionsSpacing = 4.0;
const _recentSongActionsRightInset = 8.0;
double _recentSongActionOverlayWidth(int actionCount) {
  return _recentSongActionButtonSize * actionCount +
      _recentSongActionsSpacing * (actionCount - 1) +
      _recentSongActionsRightInset +
      _recentSongActionButtonSize;
}

enum _RecentSongMenuPin { none, addTo, more, contextMenu }

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
    required this.onTogglePlayPause,
    required this.onToggleSelection,
    required this.onOpenAddToMenu,
    required this.onOpenContextMenu,
    required this.onToggleFavorite,
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
  final VoidCallback onTogglePlayPause;
  final VoidCallback onToggleSelection;
  final FutureOr<void> Function(Offset) onOpenAddToMenu;
  final FutureOr<void> Function(Offset) onOpenContextMenu;
  final VoidCallback onToggleFavorite;
  final VoidCallback onPlayNext;
  final FutureOr<void> Function(Offset) onOpenMoreMenu;

  @override
  State<_GridViewMusicItemControl> createState() =>
      _GridViewMusicItemControlState();
}

class _GridViewMusicItemControlState extends State<_GridViewMusicItemControl>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hoverActionsController;
  var _hovered = false;
  var _menuPin = _RecentSongMenuPin.none;
  var _suppressNextTileTap = false;

  bool get _hoverActive => _hovered || _menuPin != _RecentSongMenuPin.none;

  void _syncHoverActions() {
    if (_hoverActive && !widget.multiSelect) {
      _hoverActionsController.forward();
    } else {
      _hoverActionsController.reverse();
    }
  }

  Future<void> _openPinnedMenu(
    _RecentSongMenuPin pin,
    FutureOr<void> Function() open,
  ) async {
    setState(() {
      _menuPin = pin;
    });
    _syncHoverActions();
    try {
      await open();
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _menuPin != pin) {
          return;
        }
        setState(() {
          _menuPin = _RecentSongMenuPin.none;
        });
        _syncHoverActions();
      });
    }
  }

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
        _menuPin = _RecentSongMenuPin.none;
      }
      _syncHoverActions();
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
    _handlePlayback();
  }

  void _handlePlayback() {
    if (widget.current) {
      widget.onTogglePlayPause();
    } else {
      widget.onPlayTrack();
    }
  }

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width <= 520;
    final actionOverlayWidth = _recentSongActionOverlayWidth(narrow ? 4 : 3);
    final colors = _RecentSongTileColors.of(context);
    final hoverActive = _hoverActive;
    final active = widget.selected || hoverActive;
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
            : hoverActive
            ? hoverSurface
            : colors.inactiveSurface;
    final showHoverActions = hoverActive && !widget.multiSelect;
    final textColor = widget.current ? colors.currentText : colors.textStrong;
    final artistColor = widget.current ? colors.currentMuted : colors.textMuted;
    final detailColor = widget.current ? colors.currentSoft : colors.textSoft;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        setState(() {
          _hovered = true;
        });
        _syncHoverActions();
      },
      onExit: (_) {
        setState(() {
          _hovered = false;
        });
        _syncHoverActions();
      },
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        splashFactory: NoSplash.splashFactory,
        hoverColor: Colors.transparent,
        highlightColor: Colors.transparent,
        onSecondaryTapDown: (details) {
          unawaited(
            _openPinnedMenu(
              _RecentSongMenuPin.contextMenu,
              () => widget.onOpenContextMenu(details.globalPosition),
            ),
          );
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
                        else if (hoverActive)
                          Positioned.fill(
                            child: Center(
                              child: ArtworkFloatingActionButton(
                                tooltip: context.smPlayerI18n.t(
                                  widget.current && widget.playing
                                      ? 'context.pause'
                                      : 'context.play',
                                ),
                                size: 48,
                                iconSize: 19,
                                icon:
                                    widget.current && widget.playing
                                        ? const SmPlayerPauseIcon(
                                          color: Colors.white,
                                          size: 19,
                                        )
                                        : const SmPlayerPlayIcon(
                                          color: Colors.white,
                                          size: 19,
                                        ),
                                onPressed: _handlePlayback,
                              ),
                            ),
                          ),
                        if (widget.current &&
                            !hoverActive &&
                            !widget.multiSelect)
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
                                  actionOverlayWidth * progress) /
                              bounds.width)
                          .clamp(0.0, 1.0);
                      final fadeEnd = ((bounds.width -
                                  (actionOverlayWidth - 28) * progress) /
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
                    width: actionOverlayWidth,
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
                            if (narrow)
                              _RecentSongActionButton(
                                tooltip: context.smPlayerI18n.t(
                                  widget.song.favorite
                                      ? 'context.removeFavorite'
                                      : 'context.addFavorite',
                                ),
                                icon: SmPlayerFavoriteIcon(
                                  favorite: widget.song.favorite,
                                  size: 18,
                                ),
                                onPressed: widget.onToggleFavorite,
                              ),
                            Builder(
                              builder:
                                  (buttonContext) => _RecentSongActionButton(
                                    tooltip: context.smPlayerI18n.t(
                                      'context.addToPlaylist',
                                    ),
                                    icon: const Icon(
                                      FluentIcons.add_20_regular,
                                      size: 18,
                                    ),
                                    onPressed: () {
                                      final box =
                                          buttonContext.findRenderObject()
                                              as RenderBox;
                                      unawaited(
                                        _openPinnedMenu(
                                          _RecentSongMenuPin.addTo,
                                          () => widget.onOpenAddToMenu(
                                            box.localToGlobal(
                                              Offset(0, box.size.height + 8),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                            ),
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
                                      unawaited(
                                        _openPinnedMenu(
                                          _RecentSongMenuPin.more,
                                          () => widget.onOpenMoreMenu(
                                            box.localToGlobal(
                                              Offset(0, box.size.height + 8),
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
                        width: actionOverlayWidth * progress,
                        child: ClipRect(
                          child: OverflowBox(
                            alignment: Alignment.centerRight,
                            minWidth: actionOverlayWidth,
                            maxWidth: actionOverlayWidth,
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
