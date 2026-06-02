part of 'media_control.dart';

class _PlayerTrack extends StatefulWidget {
  const _PlayerTrack({
    required this.track,
    required this.artworkPath,
    required this.disabled,
    required this.onOpenNowPlaying,
    this.compact = false,
    this.currentLyricsLine,
    this.onArtworkError,
  });

  final MediaControlTrack track;
  final String? artworkPath;
  final bool disabled;
  final bool compact;
  final String? currentLyricsLine;
  final VoidCallback? onArtworkError;
  final VoidCallback onOpenNowPlaying;

  @override
  State<_PlayerTrack> createState() => _PlayerTrackState();
}

class _PlayerTrackState extends State<_PlayerTrack> {
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
    final trackCopyMaxWidth =
        widget.compact
            ? double.infinity
            : min(360.0, MediaQuery.sizeOf(context).width * 0.24);
    final trackPadding =
        widget.compact
            ? const EdgeInsets.fromLTRB(0, 0, 10, 0)
            : const EdgeInsets.fromLTRB(4, 12, 12, 12);
    final artworkSize = widget.compact ? 68.0 : 72.0;
    final preferredArtworkGap = widget.compact ? 12.0 : 14.0;
    return MouseRegion(
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
        child: TextButton(
          style: TextButton.styleFrom(
            foregroundColor: textStrong,
            disabledForegroundColor: textStrong,
            padding: trackPadding,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ).copyWith(
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.disabled)) {
                return Colors.transparent;
              }
              return states.contains(WidgetState.hovered) ||
                      states.contains(WidgetState.focused)
                  ? trackHoverBackground
                  : Colors.transparent;
            }),
            overlayColor: WidgetStateProperty.all(Colors.transparent),
            side: WidgetStateProperty.resolveWith((states) {
              final color =
                  !states.contains(WidgetState.disabled) &&
                          (states.contains(WidgetState.hovered) ||
                              states.contains(WidgetState.focused))
                      ? trackHoverBorder
                      : Colors.transparent;
              return BorderSide(color: color);
            }),
          ),
          onPressed: widget.disabled ? null : widget.onOpenNowPlaying,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final artworkGap =
                  widget.compact
                      ? min(
                        preferredArtworkGap,
                        max(0.0, constraints.maxWidth - artworkSize),
                      )
                      : preferredArtworkGap;
              return Row(
                mainAxisSize:
                    widget.compact ? MainAxisSize.max : MainAxisSize.min,
                children: [
                  Container(
                    width: artworkSize,
                    height: artworkSize,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: const [
                        BoxShadow(
                          color: MediaControlColors.artworkShadow,
                          offset: Offset(0, 10),
                          blurRadius: 24,
                        ),
                      ],
                    ),
                    child: Stack(
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
                  SizedBox(width: artworkGap),
                  Flexible(
                    child: ConstrainedBox(
                      key: const ValueKey('MediaControl.TrackCopy'),
                      constraints: BoxConstraints(
                        minWidth: widget.compact ? 0 : 120,
                        maxWidth: trackCopyMaxWidth,
                      ),
                      child: IntrinsicWidth(
                        child: SizedBox(
                          height: artworkSize,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
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
                              SizedBox(height: widget.compact ? 4 : 5),
                              Text(
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
                              if (lyricsText != null) ...[
                                SizedBox(height: widget.compact ? 4 : 5),
                                _PlayerTrackLyrics(
                                  line: lyricsText,
                                  compact: widget.compact,
                                  color: MediaControlColors.accent.withValues(
                                    alpha: 0.94,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PlayerTrackLyrics extends StatelessWidget {
  const _PlayerTrackLyrics({
    required this.line,
    required this.compact,
    required this.color,
  });

  final String line;
  final bool compact;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey('MediaControl.CurrentLyricsContainer'),
      height: 17,
      child: ClipRect(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
          switchInCurve: const Cubic(0.22, 1, 0.36, 1),
          switchOutCurve: Curves.easeOutCubic,
          transitionBuilder: (child, animation) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            );
          },
          child: Align(
            key: ValueKey(line),
            alignment: Alignment.centerLeft,
            child: Text(
              line,
              key: const ValueKey('MediaControl.CurrentLyricsLine'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: compact ? 12 : 13,
                fontWeight: FontWeight.w500,
                fontVariations: const [FontVariation.weight(560)],
                height: 17 / (compact ? 12 : 13),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
