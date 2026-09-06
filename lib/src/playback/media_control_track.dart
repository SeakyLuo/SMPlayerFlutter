part of 'media_control.dart';

typedef MediaControlTrackSquareBuilder =
    Widget Function(BuildContext context, bool active, double size);

class MediaControlTrackInfo extends StatefulWidget {
  const MediaControlTrackInfo({
    super.key,
    required this.track,
    required this.artworkPath,
    required this.disabled,
    required this.onPressed,
    this.compact = false,
    this.currentLyricsLine,
    this.onArtworkError,
    this.squareBuilder,
    this.tooltip,
    this.showTrackCopy = true,
    this.showSurfaceFeedback = true,
    this.decorateSquareAsArtwork = true,
  });

  final MediaControlTrack track;
  final String? artworkPath;
  final bool disabled;
  final bool compact;
  final String? currentLyricsLine;
  final VoidCallback? onArtworkError;
  final VoidCallback onPressed;
  final MediaControlTrackSquareBuilder? squareBuilder;
  final String? tooltip;
  final bool showTrackCopy;
  final bool showSurfaceFeedback;
  final bool decorateSquareAsArtwork;

  @override
  State<MediaControlTrackInfo> createState() => _MediaControlTrackInfoState();
}

class _MediaControlTrackInfoState extends State<MediaControlTrackInfo> {
  var _hovered = false;
  var _focused = false;

  @override
  Widget build(BuildContext context) {
    final textStrong = MediaControlColors.textStrongFor(context);
    final textMuted = MediaControlColors.textMutedFor(context);
    final lyricsText =
        widget.currentLyricsLine?.isNotEmpty == true
            ? widget.currentLyricsLine
            : null;
    final overlayVisible = !widget.disabled && (_hovered || _focused);
    final trackHoverBackground =
        Theme.of(context).brightness == Brightness.dark
            ? const Color(0x12ffffff)
            : const Color(0x1f212b3a);
    final trackHoverBorder =
        Theme.of(context).brightness == Brightness.dark
            ? MediaControlColors.nightPlayerBorder
            : const Color(0x14212b3a);
    final trackActive = !widget.disabled && (_hovered || _focused);
    final trackCopyMaxWidth =
        widget.compact
            ? double.infinity
            : min(360.0, MediaQuery.sizeOf(context).width * 0.24);
    final artworkSize = widget.compact ? 68.0 : 72.0;
    final showTrackCopy = widget.showTrackCopy && widget.track.id != null;
    final trackPadding =
        showTrackCopy
            ? widget.compact
                ? const EdgeInsets.fromLTRB(0, 1, 9, 1)
                : const EdgeInsets.fromLTRB(8, 8, 12, 8)
            : widget.compact
            ? EdgeInsets.zero
            : const EdgeInsets.all(8);
    final preferredArtworkGap = widget.compact ? 12.0 : 14.0;
    final button = TextButton(
      style: TextButton.styleFrom(
        foregroundColor: textStrong,
        disabledForegroundColor: textStrong,
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ).copyWith(
        backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        side: const WidgetStatePropertyAll(
          BorderSide(color: Colors.transparent),
        ),
      ),
      onPressed: widget.disabled ? null : widget.onPressed,
      child: AnimatedContainer(
        key: const ValueKey('MediaControl.TrackHoverSurface'),
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        padding: trackPadding,
        decoration: BoxDecoration(
          color:
              widget.showSurfaceFeedback && trackActive
                  ? trackHoverBackground
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color:
                widget.showSurfaceFeedback && trackActive
                    ? trackHoverBorder
                    : Colors.transparent,
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final artworkGap =
                !showTrackCopy
                    ? 0.0
                    : widget.compact
                    ? min(
                      preferredArtworkGap,
                      max(0.0, constraints.maxWidth - artworkSize),
                    )
                    : preferredArtworkGap;
            return Row(
              mainAxisSize:
                  widget.compact && showTrackCopy
                      ? MainAxisSize.max
                      : MainAxisSize.min,
              children: [
                Container(
                  key: const ValueKey('MediaControl.TrackSquare'),
                  width: artworkSize,
                  height: artworkSize,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    boxShadow:
                        widget.decorateSquareAsArtwork
                            ? const [
                              BoxShadow(
                                color: MediaControlColors.artworkShadow,
                                offset: Offset(0, 10),
                                blurRadius: 24,
                              ),
                            ]
                            : null,
                  ),
                  child:
                      widget.squareBuilder?.call(
                        context,
                        trackActive,
                        artworkSize,
                      ) ??
                      Stack(
                        fit: StackFit.expand,
                        children: [
                          _PlayerArtwork(
                            artworkPath: widget.artworkPath,
                            onError: widget.onArtworkError,
                          ),
                          AnimatedOpacity(
                            key: const ValueKey('MediaControl.ArtworkOverlay'),
                            duration: const Duration(milliseconds: 140),
                            opacity: overlayVisible ? 1 : 0,
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xff0c1118,
                                  ).withValues(alpha: 0.44),
                                ),
                                child: const SmPlayerFullscreenIcon(
                                  color: Colors.white,
                                  size: 36,
                                  strokeWidth: 2,
                                  shadows: [
                                    Shadow(
                                      color: Color(0x57000000),
                                      offset: Offset(0, 2),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                ),
                if (showTrackCopy) ...[
                  SizedBox(width: artworkGap),
                  Flexible(
                    child: ConstrainedBox(
                      key: const ValueKey('MediaControl.TrackCopy'),
                      constraints: BoxConstraints(
                        minWidth: widget.compact ? 0 : 120,
                        maxWidth: trackCopyMaxWidth,
                      ),
                      child: SizedBox(
                        height: artworkSize,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Tooltip(
                              message: widget.track.title,
                              child: Text(
                                widget.track.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: textStrong,
                                  fontSize: widget.compact ? 15 : 17,
                                  fontWeight: FontWeight.w600,
                                  fontVariations: const [
                                    FontVariation.weight(650),
                                  ],
                                  height: 1.08,
                                ),
                              ),
                            ),
                            SizedBox(height: widget.compact ? 4 : 5),
                            Tooltip(
                              message: widget.track.artist,
                              child: Text(
                                widget.track.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: textMuted,
                                  fontSize: widget.compact ? 12 : 14,
                                  fontWeight: FontWeight.w500,
                                  fontVariations: const [
                                    FontVariation.weight(520),
                                  ],
                                  height: 1.1,
                                ),
                              ),
                            ),
                            if (lyricsText != null) ...[
                              SizedBox(height: widget.compact ? 4 : 5),
                              _PlayerTrackLyrics(
                                line: lyricsText,
                                compact: widget.compact,
                                color: textMuted,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
    final interactive = MouseRegion(
      cursor:
          widget.disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
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
      child: Focus(
        onFocusChange: (focused) {
          setState(() {
            _focused = focused;
          });
        },
        child: button,
      ),
    );
    if (widget.tooltip == null) {
      return interactive;
    }
    return Tooltip(message: widget.tooltip!, child: interactive);
  }
}

class _PlayerTrackLyrics extends StatefulWidget {
  const _PlayerTrackLyrics({
    required this.line,
    required this.compact,
    required this.color,
  });

  final String line;
  final bool compact;
  final Color color;

  @override
  State<_PlayerTrackLyrics> createState() => _PlayerTrackLyricsState();
}

class _PlayerTrackLyricsState extends State<_PlayerTrackLyrics>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scrollController;
  String? _measuredLine;
  bool? _measuredCompact;
  double? _measuredScaledFontSize;
  TextDirection? _measuredDirection;
  double _measuredLineWidth = 0;

  @override
  void initState() {
    super.initState();
    _scrollController = AnimationController(
      vsync: this,
      animationBehavior: AnimationBehavior.preserve,
    );
  }

  @override
  void didUpdateWidget(covariant _PlayerTrackLyrics oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.line != widget.line || oldWidget.compact != widget.compact) {
      _scrollController.reset();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: widget.color,
      fontSize: widget.compact ? 12 : 13,
      fontWeight: FontWeight.w500,
      fontVariations: const [FontVariation.weight(560)],
      height: 17 / (widget.compact ? 12 : 13),
    );
    return RepaintBoundary(
      child: SizedBox(
        key: const ValueKey('MediaControl.CurrentLyricsContainer'),
        height: 17,
        child: ClipRect(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final textDirection = Directionality.of(context);
              final textScaler = MediaQuery.textScalerOf(context);
              final lineWidth = _lineWidth(style, textDirection, textScaler);
              final overflowDistance = max(
                0.0,
                lineWidth - constraints.maxWidth,
              );
              final currentLine =
                  overflowDistance == 0
                      ? Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          widget.line,
                          key: const ValueKey('MediaControl.CurrentLyricsLine'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: style,
                        ),
                      )
                      : _buildScrollingLine(
                        lineWidth: lineWidth,
                        overflowDistance: overflowDistance,
                        style: style,
                      );
              if (overflowDistance == 0) {
                _scrollController.stop();
              }
              return currentLine;
            },
          ),
        ),
      ),
    );
  }

  Widget _buildScrollingLine({
    required double lineWidth,
    required double overflowDistance,
    required TextStyle style,
  }) {
    _scrollController.duration = Duration(
      seconds: min(8, max(3, (overflowDistance / 44).round() + 2)),
    );
    if (!_scrollController.isAnimating) {
      _scrollController.forward();
    }
    return AnimatedBuilder(
      animation: _scrollController,
      builder: (context, child) {
        final progress = _scrollController.value;
        final scrollProgress =
            progress <= 0.16
                ? 0.0
                : progress >= 0.84
                ? 1.0
                : Curves.easeInOut.transform((progress - 0.16) / 0.68);
        return Transform.translate(
          offset: Offset(-overflowDistance * scrollProgress, 0),
          child: child,
        );
      },
      child: OverflowBox(
        alignment: Alignment.centerLeft,
        minWidth: lineWidth,
        maxWidth: lineWidth,
        child: SizedBox(
          width: lineWidth,
          child: Text(
            widget.line,
            key: const ValueKey('MediaControl.CurrentLyricsLine'),
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.visible,
            style: style,
          ),
        ),
      ),
    );
  }

  double _lineWidth(
    TextStyle style,
    TextDirection textDirection,
    TextScaler textScaler,
  ) {
    final scaledFontSize = textScaler.scale(style.fontSize!);
    if (_measuredLine == widget.line &&
        _measuredCompact == widget.compact &&
        _measuredScaledFontSize == scaledFontSize &&
        _measuredDirection == textDirection) {
      return _measuredLineWidth;
    }

    final painter = TextPainter(
      text: TextSpan(text: widget.line, style: style),
      maxLines: 1,
      textDirection: textDirection,
      textScaler: textScaler,
    )..layout();
    _measuredLine = widget.line;
    _measuredCompact = widget.compact;
    _measuredScaledFontSize = scaledFontSize;
    _measuredDirection = textDirection;
    _measuredLineWidth = painter.width;
    return _measuredLineWidth;
  }
}
