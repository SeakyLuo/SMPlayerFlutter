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

class _ArtistsColors {
  const _ArtistsColors._();

  static Color detailBackground(Brightness brightness) {
    return brightness == Brightness.dark
        ? const Color(0xff0f1318)
        : const Color(0xf5f8fbfe);
  }

  static Color? masterBackground(Brightness brightness) {
    return brightness == Brightness.dark ? const Color(0x06ffffff) : null;
  }

  static Color albumSection(Brightness brightness) {
    return brightness == Brightness.dark
        ? const Color(0xff171c22)
        : const Color(0xa3ffffff);
  }

  static Color albumShadow(Brightness brightness) {
    return brightness == Brightness.dark
        ? const Color(0x33000000)
        : const Color(0x14685870);
  }

  static Color panelBorder(Brightness brightness) {
    return brightness == Brightness.dark
        ? const Color(0x1fd6e0ec)
        : const Color(0x2e7e8b9a);
  }

  static Color masterBorder(Brightness brightness) {
    return brightness == Brightness.dark
        ? const Color(0x1fd6e0ec)
        : const Color(0x2e566271);
  }

  static Color emptyStateSurfaceFor(Brightness brightness) {
    return brightness == Brightness.dark
        ? const Color(0x0bffffff)
        : emptyStateSurface;
  }

  static Color emptyStateBorderFor(Brightness brightness) {
    return brightness == Brightness.dark
        ? const Color(0x1fd6e0ec)
        : emptyStateBorder;
  }

  static BoxDecoration detailEmptyStateDecoration(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return BoxDecoration(
        color: emptyStateSurfaceFor(brightness),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: emptyStateBorderFor(brightness)),
      );
    }
    return const BoxDecoration();
  }

  static BoxDecoration detailHeaderDecoration(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xf70f1319), Color(0xe00f1319)],
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x29000000),
            offset: Offset(0, 12),
            blurRadius: 24,
          ),
        ],
      );
    }

    return const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xf5f8fbfe), Color(0xe0f8fbfe)],
      ),
      boxShadow: [
        BoxShadow(
          color: Color(0x0a445870),
          offset: Offset(0, 12),
          blurRadius: 24,
        ),
      ],
    );
  }

  static Color textStrongFor(Brightness brightness) {
    return brightness == Brightness.dark ? const Color(0xf0f6f9fc) : textStrong;
  }

  static Color textMutedFor(Brightness brightness) {
    return brightness == Brightness.dark ? const Color(0xadcbd5e1) : textMuted;
  }

  static Color detailSummaryFor(Brightness brightness) {
    return brightness == Brightness.dark
        ? const Color(0xadcbd5e1)
        : const Color(0xff111111);
  }

  static Color headerActionForeground(Brightness brightness) {
    return textStrongFor(brightness);
  }

  static Color headerActionHoverBackground(Brightness brightness) {
    return brightness == Brightness.dark
        ? const Color(0x290078d7)
        : const Color(0x0f0c1623);
  }

  static Color albumTitleHoverForeground(Brightness brightness) {
    return brightness == Brightness.dark
        ? const Color(0xff459de2)
        : accentStrong;
  }

  static Color artistRowActiveBackground(Brightness brightness) {
    return brightness == Brightness.dark
        ? const Color(0x330078d7)
        : accentProgressTrack;
  }

  static Color artistRowHoverBackground(Brightness brightness) {
    return brightness == Brightness.dark
        ? const Color(0x210078d7)
        : const Color(0x140078d7);
  }

  static Color artistRowActiveForeground(Brightness brightness) {
    return brightness == Brightness.dark ? const Color(0xff459de2) : textStrong;
  }

  static const artistRowActiveShadow = BoxShadow(
    color: Color(0x290078d7),
    offset: Offset(0, 14),
    blurRadius: 30,
  );

  static Color artistArtworkBackground(
    Brightness brightness, {
    required bool hasArtwork,
  }) {
    if (brightness != Brightness.dark) {
      return const Color(0xb8ffffff);
    }
    return hasArtwork ? const Color(0x14ffffff) : const Color(0xff1d4a70);
  }

  static BoxShadow artistArtworkShadow(
    Brightness brightness, {
    required bool elevated,
  }) {
    if (elevated) {
      return const BoxShadow(
        color: Color(0x33202d3f),
        offset: Offset(0, 12),
        blurRadius: 24,
      );
    }
    return brightness == Brightness.dark
        ? const BoxShadow(
          color: Color(0x4d000000),
          offset: Offset(0, 8),
          blurRadius: 18,
        )
        : const BoxShadow(
          color: Color(0x21202d3f),
          offset: Offset(0, 8),
          blurRadius: 18,
        );
  }

  static Color albumArtworkBackground(Brightness brightness) {
    return brightness == Brightness.dark
        ? const Color(0x14ffffff)
        : const Color(0x24818b98);
  }

  static Color artistSongListBorder(Brightness brightness) {
    return brightness == Brightness.dark
        ? const Color(0x1fd6e0ec)
        : const Color(0x297e8b9a);
  }

  static PlaylistControlItemColors? artistSongRowColors(Brightness brightness) {
    if (brightness != Brightness.dark) {
      return const PlaylistControlItemColors(
        border: Colors.transparent,
        hover: Color(0x140078d7),
        hoverBorder: Colors.transparent,
        current: Color(0x1f0078d7),
        currentForeground: accentStrong,
        currentMuted: accentStrong,
        textStrong: Color(0xff111827),
        textMuted: Color(0xff5b697a),
        artworkBackground: Colors.transparent,
        actionForeground: Color(0xb8586474),
        actionHover: Color(0x9effffff),
      );
    }
    return const PlaylistControlItemColors(
      border: Colors.transparent,
      hover: Color(0x240078d7),
      hoverBorder: Color(0x380078d7),
      current: Color(0x330078d7),
      currentForeground: Color(0xff459de2),
      currentMuted: Color(0xc276b5dc),
      textStrong: Color(0xf0f6f9fc),
      textMuted: Color(0xadcbd5e1),
      artworkBackground: Color(0x14ffffff),
      actionForeground: Color(0xadcbd5e1),
      actionHover: Color(0x2e0078d7),
    );
  }

  static Color quickJumpForeground(Brightness brightness) {
    return brightness == Brightness.dark ? const Color(0xadcbd5e1) : textMuted;
  }

  static Color quickJumpActiveBackground(Brightness brightness) {
    return brightness == Brightness.dark
        ? const Color(0x2e0078d7)
        : accentProgressTrack;
  }

  static Color quickJumpActiveForeground(Brightness brightness) {
    return brightness == Brightness.dark
        ? const Color(0xff459de2)
        : accentStrong;
  }

  static Color quickJumpDisabled(Brightness brightness) {
    return brightness == Brightness.dark ? const Color(0x40dee7f2) : disabled;
  }

  static const accent = Color(0xff0078d7);
  static const accentStrong = Color(0xff0063b1);
  static const accentProgressTrack = Color(0x1f0078d7);
  static const activeBorder = Color(0x6b0078d7);
  static const textStrong = Color(0xff1f252b);
  static const textMuted = Color(0xff5f625f);
  static const disabled = Color(0x3d5b697a);
  static const loadingSpinnerTrack = Color(0x2e0078d7);
  static const emptyStateSurface = Color(0x94ffffff);
  static const emptyStateBorder = Color(0x94ffffff);
  static Color scrollbarThumb(Brightness brightness) {
    return brightness == Brightness.dark
        ? const Color(0x7396a4b6)
        : const Color(0x805b697a);
  }

  static Color scrollbarThumbHover(Brightness brightness) {
    return brightness == Brightness.dark
        ? const Color(0x9ebccadc)
        : const Color(0xad435060);
  }
}
