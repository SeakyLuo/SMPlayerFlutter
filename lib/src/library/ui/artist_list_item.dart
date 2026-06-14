part of 'artists_page.dart';

class _ArtistListItem extends StatefulWidget {
  const _ArtistListItem({
    required this.artist,
    required this.active,
    required this.i18n,
    required this.onPressed,
    required this.onPlay,
    required this.onOpenContextMenu,
    required this.locateHighlighted,
    required this.locatePulse,
    this.compactNavMinimal = false,
  });

  final ArtistGroup artist;
  final bool active;
  final SmPlayerI18n i18n;
  final VoidCallback onPressed;
  final VoidCallback onPlay;
  final ValueChanged<Offset> onOpenContextMenu;
  final bool locateHighlighted;
  final int locatePulse;
  final bool compactNavMinimal;

  @override
  State<_ArtistListItem> createState() => _ArtistListItemState();
}

class _ArtistListItemState extends State<_ArtistListItem>
    with SingleTickerProviderStateMixin {
  final _focusNode = FocusNode();
  late final AnimationController _locateHighlightController;
  var _hovered = false;
  var _focused = false;

  @override
  void initState() {
    super.initState();
    _locateHighlightController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _focusNode.addListener(_handleFocusChange);
    if (widget.locateHighlighted && widget.locatePulse > 0) {
      _playLocateHighlight();
    }
  }

  @override
  void didUpdateWidget(covariant _ArtistListItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.locateHighlighted &&
        widget.locatePulse != oldWidget.locatePulse) {
      _playLocateHighlight();
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    _locateHighlightController.dispose();
    super.dispose();
  }

  void _playLocateHighlight() {
    _locateHighlightController.value = 1;
    unawaited(
      _locateHighlightController.animateTo(0, curve: Curves.easeOutCubic),
    );
  }

  void _handleFocusChange() {
    setState(() {
      _focused = _focusNode.hasFocus;
    });
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final activeForeground = _ArtistsColors.artistRowActiveForeground(
      brightness,
    );
    final activeMuted = _ArtistsColors.artistRowActiveMuted(brightness);
    final revealPlay = _hovered || _focused || _focusNode.hasFocus;
    final rowBorderRadius = BorderRadius.circular(10);
    return SizedBox(
      height: artistRowHeight,
      child: Center(
        child: SizedBox(
          height: artistRowContentHeight,
          child: Shortcuts(
            shortcuts: const {
              SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
              SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
            },
            child: Actions(
              actions: {
                ActivateIntent: CallbackAction<ActivateIntent>(
                  onInvoke: (_) {
                    widget.onPressed();
                    return null;
                  },
                ),
              },
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
                child: Material(
                  color: Colors.transparent,
                  borderRadius: rowBorderRadius,
                  child: InkWell(
                    key: ValueKey('Artists.ArtistRow.${widget.artist.name}'),
                    focusNode: _focusNode,
                    onFocusChange: (focused) {
                      setState(() {
                        _focused = focused;
                      });
                    },
                    borderRadius: rowBorderRadius,
                    overlayColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.hovered) ||
                          states.contains(WidgetState.focused)) {
                        return _ArtistsColors.artistRowHoverBackground(
                          brightness,
                        );
                      }
                      return null;
                    }),
                    onTap: widget.onPressed,
                    onSecondaryTapDown: (details) {
                      widget.onOpenContextMenu(details.globalPosition);
                    },
                    child: AnimatedBuilder(
                      animation: _locateHighlightController,
                      builder: (context, child) {
                        final locateColor =
                            widget.active
                                ? null
                                : Color.lerp(
                                  Colors.transparent,
                                  _ArtistsColors.artistRowHoverBackground(
                                    brightness,
                                  ),
                                  _locateHighlightController.value,
                                );
                        return Container(
                          key: ValueKey(
                            'Artists.ArtistRow.Decoration.${widget.artist.name}',
                          ),
                          constraints: const BoxConstraints(minHeight: 62),
                          padding: EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: widget.compactNavMinimal ? 4 : 5,
                          ),
                          decoration: BoxDecoration(
                            color:
                                widget.active
                                    ? _ArtistsColors.artistRowActiveBackground(
                                      brightness,
                                    )
                                    : locateColor,
                            borderRadius: rowBorderRadius,
                            border: Border.all(
                              color:
                                  widget.active
                                      ? _ArtistsColors.artistRowActiveBorder(
                                        brightness,
                                      )
                                      : Colors.transparent,
                            ),
                            boxShadow:
                                widget.active
                                    ? [
                                      _ArtistsColors.artistRowActiveShadow(
                                        brightness,
                                      ),
                                    ]
                                    : null,
                          ),
                          child: child,
                        );
                      },
                      child: Row(
                        children: [
                          ArtistListArtwork(
                            artist: widget.artist,
                            onPlay: widget.onPlay,
                            brightness: brightness,
                            revealPlay: revealPlay,
                          ),
                          SizedBox(width: widget.compactNavMinimal ? 10 : 12),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Tooltip(
                                  message: widget.artist.name,
                                  child: Text(
                                    widget.artist.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color:
                                          widget.active
                                              ? activeForeground
                                              : _ArtistsColors.textStrongFor(
                                                brightness,
                                              ),
                                      fontSize: 15,
                                      height: 1.2,
                                      fontWeight: FontWeight.w700,
                                      fontVariations: [
                                        FontVariation.weight(720),
                                      ],
                                    ),
                                  ),
                                ),
                                Text(
                                  _formatArtistSummary(
                                    widget.i18n,
                                    widget.artist.albumCount,
                                    widget.artist.songs.length,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color:
                                        widget.active
                                            ? activeMuted
                                            : _ArtistsColors.textMutedFor(
                                              brightness,
                                            ),
                                    fontSize: 13,
                                    height: 1.15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
