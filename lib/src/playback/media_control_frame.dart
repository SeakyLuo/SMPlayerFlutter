part of 'media_control.dart';

class _PlayerTintedFrame extends StatefulWidget {
  const _PlayerTintedFrame({required this.artworkPath, required this.child});

  final String? artworkPath;
  final Widget child;

  @override
  State<_PlayerTintedFrame> createState() => _PlayerTintedFrameState();
}

class _PlayerTintedFrameState extends State<_PlayerTintedFrame> {
  var _accentColor = _defaultArtworkAccentColor;
  var _loadSerial = 0;

  @override
  void initState() {
    super.initState();
    _loadArtworkAccentColor();
  }

  @override
  void didUpdateWidget(covariant _PlayerTintedFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.artworkPath != widget.artworkPath) {
      _loadArtworkAccentColor();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth <= _playerCompactBreakpoint;
        final night = MediaControlColors.isNight(context);
        final hasArtwork = widget.artworkPath?.isNotEmpty == true;
        final coverWash =
            hasArtwork
                ? _accentColor.withValues(alpha: 0.24)
                : Colors.transparent;
        final nightCoverWash = _accentColor.withValues(
          alpha:
              hasArtwork
                  ? compact
                      ? 0.20
                      : 0.22
                  : 0.10,
        );
        final borderColor =
            compact
                ? MediaControlColors.compactPlayerBorderFor(night)
                : MediaControlColors.playerBorderFor(night);
        final border =
            compact
                ? Border(top: BorderSide(color: borderColor))
                : Border(
                  top: BorderSide(color: borderColor),
                  left: BorderSide(color: borderColor),
                  right: BorderSide(color: borderColor),
                );
        final shadow =
            compact
                ? [
                  BoxShadow(
                    color: MediaControlColors.compactPlayerShadowFor(night),
                    offset: const Offset(0, -12),
                    blurRadius: 36,
                  ),
                ]
                : [
                  BoxShadow(
                    color: MediaControlColors.playerShadowFor(night),
                    offset: Offset(0, night ? -18 : 18),
                    blurRadius: 48,
                  ),
                ];

        return DecoratedBox(
          decoration: BoxDecoration(border: border, boxShadow: shadow),
          child:
              compact
                  ? _PlayerCompactTintedBackground(
                    night: night,
                    hasArtwork: hasArtwork,
                    coverWash: night ? nightCoverWash : coverWash,
                    child: widget.child,
                  )
                  : _PlayerWideTintedBackground(
                    night: night,
                    hasArtwork: hasArtwork,
                    coverWash: night ? nightCoverWash : coverWash,
                    child: widget.child,
                  ),
        );
      },
    );
  }

  void _loadArtworkAccentColor() {
    final loadSerial = _loadSerial + 1;
    _loadSerial = loadSerial;
    final artworkPath = widget.artworkPath ?? '';
    if (artworkPath.isEmpty) {
      _setAccentColor(_defaultArtworkAccentColor);
      return;
    }

    unawaited(
      extractPlayerArtworkAccentColor(artworkPath).then((color) {
        if (!mounted || loadSerial != _loadSerial) {
          return;
        }
        _setAccentColor(color);
      }),
    );
  }

  void _setAccentColor(Color color) {
    if (_accentColor == color) {
      return;
    }
    setState(() {
      _accentColor = color;
    });
  }
}

class _PlayerWideTintedBackground extends StatelessWidget {
  const _PlayerWideTintedBackground({
    required this.night,
    required this.hasArtwork,
    required this.coverWash,
    required this.child,
  });

  final bool night;
  final bool hasArtwork;
  final Color coverWash;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!hasArtwork) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color:
              night
                  ? MediaControlColors.nightPlayerSurface
                  : MediaControlColors.playerSurfaceSolid,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors:
                  night
                      ? [
                        MediaControlColors.nightPlayerHighlight,
                        MediaControlColors.nightEmptyPlayerRightWash,
                      ]
                      : [
                        MediaControlColors.emptyPlayerLeftWash,
                        MediaControlColors.emptyPlayerRightWash,
                      ],
            ),
          ),
          child: _PlayerGlassHighlight(child: child),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color:
            night
                ? MediaControlColors.nightPlayerSurface
                : MediaControlColors.playerSurfaceSolid,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [coverWash, Colors.transparent],
            stops: [0, night ? 0.46 : 0.42],
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors:
                  night
                      ? [
                        MediaControlColors.nightPlayerHighlight,
                        hasArtwork
                            ? MediaControlColors.nightPlayerAccentWash
                            : MediaControlColors.nightEmptyPlayerAccentWash,
                      ]
                      : [
                        MediaControlColors.playerSurface,
                        hasArtwork
                            ? MediaControlColors.playerAccentWash
                            : MediaControlColors.emptyPlayerAccentWash,
                      ],
            ),
          ),
          child: _PlayerGlassHighlight(child: child),
        ),
      ),
    );
  }
}

class _PlayerGlassHighlight extends StatelessWidget {
  const _PlayerGlassHighlight({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: const Alignment(-0.94, -1),
                end: const Alignment(0.72, 1),
                colors: [
                  Colors.white.withValues(alpha: 0.38),
                  Colors.white.withValues(alpha: 0.10),
                  Colors.white.withValues(alpha: 0.00),
                ],
                stops: const [0, 0.38, 1],
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _PlayerCompactTintedBackground extends StatelessWidget {
  const _PlayerCompactTintedBackground({
    required this.night,
    required this.hasArtwork,
    required this.coverWash,
    required this.child,
  });

  final bool night;
  final bool hasArtwork;
  final Color coverWash;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color:
                night
                    ? MediaControlColors.nightCompactPlayerSurface
                    : MediaControlColors.compactPlayerSurface,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors:
                    night
                        ? [
                          MediaControlColors.nightCompactPlayerTop,
                          MediaControlColors.nightCompactPlayerBottom,
                        ]
                        : [
                          MediaControlColors.compactPlayerTop,
                          MediaControlColors.compactPlayerBottom,
                        ],
              ),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors:
                      night
                          ? [
                            coverWash,
                            hasArtwork
                                ? MediaControlColors.nightCompactPlayerWash
                                : MediaControlColors
                                    .nightEmptyCompactPlayerWash,
                          ]
                          : [
                            coverWash,
                            hasArtwork
                                ? MediaControlColors.compactPlayerWash
                                : MediaControlColors.emptyCompactPlayerWash,
                          ],
                  stops: [0, night ? 0.56 : 0.54],
                ),
              ),
              child: child,
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 1,
          child: ColoredBox(
            color:
                night
                    ? MediaControlColors.nightCompactPlayerInsetHighlight
                    : MediaControlColors.compactPlayerInsetHighlight,
          ),
        ),
      ],
    );
  }
}
