part of 'artists_page.dart';

class _ArtistsLoadingMaster extends StatelessWidget {
  const _ArtistsLoadingMaster({
    required this.showSearch,
    required this.artistSearch,
    required this.scrollController,
    required this.i18n,
    required this.searchFocused,
    required this.onChanged,
    required this.onFocusChanged,
    required this.onSubmitted,
  });

  final bool showSearch;
  final String artistSearch;
  final ScrollController scrollController;
  final SmPlayerI18n i18n;
  final bool searchFocused;
  final ValueChanged<String> onChanged;
  final ValueChanged<bool> onFocusChanged;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final navMinimal = !showSearch;
    return SizedBox(
      width: 300,
      child: DecoratedBox(
        key: const ValueKey('Artists.LoadingMasterPanel'),
        decoration: BoxDecoration(
          color:
              navMinimal
                  ? Colors.transparent
                  : _ArtistsColors.masterBackground(brightness),
          border:
              navMinimal
                  ? null
                  : Border(
                    right: BorderSide(
                      color: _ArtistsColors.masterBorder(brightness),
                    ),
                  ),
        ),
        child: Padding(
          key: const ValueKey('Artists.LoadingMasterPanel.Padding'),
          padding:
              navMinimal
                  ? const EdgeInsets.fromLTRB(14, 8, 14, 26)
                  : const EdgeInsets.fromLTRB(14, 16, 14, 8),
          child: Column(
            children: [
              if (showSearch)
                _ArtistsSearchBox(
                  artistSearch: artistSearch,
                  i18n: i18n,
                  searchFocused: searchFocused,
                  searchSuggestions: const [],
                  searchHistoryEntries: const [],
                  onChanged: onChanged,
                  onFocusChanged: onFocusChanged,
                  onSubmitted: onSubmitted,
                  onSelectSearchSuggestion: onChanged,
                  onRemoveRecentSearch: (_) {},
                  onClearRecentSearches: () {},
                ),
              const SizedBox(height: 8),
              _ArtistsProgress(
                key: const ValueKey('Artists.Progress'),
                label: i18n.t('nowPlaying.loading'),
              ),
              SizedBox(height: showSearch ? 14 : 0),
              Expanded(
                child: Row(
                  key: const ValueKey('Artists.LoadingMaster.ListShell'),
                  children: [
                    _ArtistQuickJump(
                      activeKey: '',
                      enabledKeys: const {},
                      i18n: i18n,
                      onJump: (_) {},
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            right: 12,
                            child: ListView(
                              key: const ValueKey('Artists.LoadingMaster.List'),
                              controller: scrollController,
                              clipBehavior: Clip.none,
                              padding: EdgeInsets.zero,
                              children: const [],
                            ),
                          ),
                          _ArtistsCustomScrollbar(
                            key: const ValueKey(
                              'Artists.LoadingMasterScrollbar',
                            ),
                            positionKey: const ValueKey(
                              'Artists.LoadingMasterScrollbar.Position',
                            ),
                            thumbKey: const ValueKey(
                              'Artists.LoadingMasterScrollbar.Thumb',
                            ),
                            controller: scrollController,
                            right: 0,
                          ),
                        ],
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

class _ArtistsProgress extends StatefulWidget {
  const _ArtistsProgress({super.key, required this.label});

  final String label;

  @override
  State<_ArtistsProgress> createState() => _ArtistsProgressState();
}

class _ArtistsProgressState extends State<_ArtistsProgress>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.label,
      child: SizedBox(
        height: 3,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: ColoredBox(
            color: _ArtistsColors.accentProgressTrack,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final offset = lerpDouble(-1.2, 3.4, _controller.value)!;
                return FractionalTranslation(
                  translation: Offset(offset, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: 0.34,
                      child: child,
                    ),
                  ),
                );
              },
              child: const ColoredBox(
                key: ValueKey('Artists.Progress.Thumb'),
                color: _ArtistsColors.accent,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ArtistsDetailLoadingState extends StatelessWidget {
  const _ArtistsDetailLoadingState();

  @override
  Widget build(BuildContext context) {
    final i18n =
        context.maybeSmPlayerI18n ??
        const SmPlayerI18n(locale: smPlayerFallbackLocale, messages: {});
    final brightness = Theme.of(context).brightness;
    final label = i18n.t('nowPlaying.loading');
    return ColoredBox(
      key: const ValueKey('Artists.DetailSurface'),
      color: _ArtistsColors.detailBackground(brightness),
      child: Center(
        child: DecoratedBox(
          key: const ValueKey('Artists.DetailLoadingState.Surface'),
          decoration: _ArtistsColors.detailEmptyStateDecoration(brightness),
          child: Padding(
            key: const ValueKey('Artists.DetailLoadingState.Padding'),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Semantics(
              container: true,
              liveRegion: true,
              label: label,
              child: ExcludeSemantics(
                child: Row(
                  key: const ValueKey('Artists.DetailLoadingState'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox.square(
                      key: ValueKey('Artists.DetailLoadingSpinner'),
                      dimension: 18,
                      child: _ArtistsLoadingSpinner(),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      key: const ValueKey('Artists.DetailLoadingTitle'),
                      label,
                      style: TextStyle(
                        color: _ArtistsColors.textStrongFor(brightness),
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
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

class _ArtistsLoadingSpinner extends StatefulWidget {
  const _ArtistsLoadingSpinner();

  @override
  State<_ArtistsLoadingSpinner> createState() => _ArtistsLoadingSpinnerState();
}

class _ArtistsLoadingSpinnerState extends State<_ArtistsLoadingSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      key: const ValueKey('Artists.DetailLoadingSpinner.Rotation'),
      turns: _controller,
      child: CustomPaint(
        key: const ValueKey('Artists.DetailLoadingSpinner.Paint'),
        painter: _ArtistsLoadingSpinnerPainter(
          trackColor: _ArtistsColors.loadingSpinnerTrack,
          topColor: _ArtistsColors.accent,
          strokeWidth: 2,
        ),
      ),
    );
  }
}

class _ArtistsLoadingSpinnerPainter extends CustomPainter {
  const _ArtistsLoadingSpinnerPainter({
    required this.trackColor,
    required this.topColor,
    required this.strokeWidth,
  });

  final Color trackColor;
  final Color topColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (min(size.width, size.height) - strokeWidth) / 2;
    final trackPaint =
        Paint()
          ..color = trackColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);
    final topPaint =
        Paint()
          ..color = topColor
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.butt
          ..strokeWidth = strokeWidth;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      pi / 2,
      false,
      topPaint,
    );
  }

  @override
  bool shouldRepaint(_ArtistsLoadingSpinnerPainter oldDelegate) {
    return oldDelegate.trackColor != trackColor ||
        oldDelegate.topColor != topColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

class _ArtistsCustomScrollbar extends StatefulWidget {
  const _ArtistsCustomScrollbar({
    super.key,
    required this.positionKey,
    required this.thumbKey,
    required this.controller,
    required this.right,
  });

  final Key positionKey;
  final Key thumbKey;
  final ScrollController controller;
  final double right;

  @override
  State<_ArtistsCustomScrollbar> createState() =>
      _ArtistsCustomScrollbarState();
}

class _ArtistsCustomScrollbarState extends State<_ArtistsCustomScrollbar> {
  var _hovered = false;
  var _dragging = false;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      key: widget.positionKey,
      top: 0,
      right: widget.right,
      bottom: 0,
      width: 9,
      child: LayoutBuilder(
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
              final maxScrollTop = position.maxScrollExtent;
              if (maxScrollTop <= 1) {
                return const SizedBox.shrink();
              }

              final trackHeight = constraints.maxHeight;
              final scrollHeight = trackHeight + maxScrollTop;
              final thumbHeight = max(
                38.0,
                (trackHeight / scrollHeight) * trackHeight,
              );
              final thumbTop =
                  (position.pixels / maxScrollTop) *
                  max(0.0, trackHeight - thumbHeight);
              final expanded = _hovered || _dragging;
              final brightness = Theme.of(context).brightness;
              final thumbColor =
                  expanded
                      ? _ArtistsColors.scrollbarThumbHover(brightness)
                      : _ArtistsColors.scrollbarThumb(brightness);

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
                    const Positioned.fill(child: SizedBox.expand()),
                    AnimatedOpacity(
                      opacity: expanded ? 1 : 0,
                      duration: const Duration(milliseconds: 140),
                      curve: Curves.easeOut,
                      child: Stack(
                        children: [
                          Positioned(
                            top: thumbTop.clamp(0.0, trackHeight - thumbHeight),
                            right: expanded ? 1 : 2,
                            left: expanded ? 1 : 2,
                            height: thumbHeight,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onVerticalDragStart: (_) {
                                setState(() {
                                  _dragging = true;
                                });
                              },
                              onVerticalDragUpdate: (details) {
                                final trackRange = max(
                                  1.0,
                                  trackHeight - thumbHeight,
                                );
                                final scrollDelta =
                                    details.delta.dy *
                                    (maxScrollTop / trackRange);
                                widget.controller.jumpTo(
                                  (position.pixels + scrollDelta).clamp(
                                    0.0,
                                    maxScrollTop,
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
                                key: widget.thumbKey,
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
      ),
    );
  }
}

class _ArtistsPagePanel extends StatelessWidget {
  const _ArtistsPagePanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.zero,
      child: SizedBox.expand(child: child),
    );
  }
}

class _ArtistsEmptyState extends StatelessWidget {
  const _ArtistsEmptyState({
    required this.title,
    required this.message,
    this.detail = false,
  });

  final String title;
  final String message;
  final bool detail;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final titleStyle = TextStyle(
      color: _ArtistsColors.textStrongFor(brightness),
      fontSize: 26,
      fontWeight: FontWeight.w700,
    );
    final messageStyle = TextStyle(
      color: _ArtistsColors.textMutedFor(brightness),
      fontSize: 14,
      height: 1.65,
    );
    final decoration = BoxDecoration(
      color: _ArtistsColors.emptyStateSurfaceFor(brightness),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _ArtistsColors.emptyStateBorderFor(brightness)),
    );
    if (detail) {
      return Center(
        child: DecoratedBox(
          key: const ValueKey('Artists.EmptyState'),
          decoration: _ArtistsColors.detailEmptyStateDecoration(brightness),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, textAlign: TextAlign.center, style: titleStyle),
                if (message.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Text(
                      message,
                      textAlign: TextAlign.center,
                      style: messageStyle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return DecoratedBox(
      key: const ValueKey('Artists.EmptyState'),
      decoration: decoration,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: titleStyle),
            if (message.isNotEmpty) ...[
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Text(message, style: messageStyle),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _formatArtistSummary(SmPlayerI18n i18n, int albums, int songs) {
  return i18n.t('artists.artistSummary', {'albums': albums, 'songs': songs});
}
