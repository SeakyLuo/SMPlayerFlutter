part of 'media_control.dart';

class _PlayerLiquidGlassFrame extends StatelessWidget {
  const _PlayerLiquidGlassFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final night = MediaControlColors.isNight(context);
    return GlassContainer(
      useOwnLayer: true,
      quality: GlassQuality.standard,
      shape: const LiquidRoundedRectangle(borderRadius: 0),
      settings: LiquidGlassSettings(
        blur: 18,
        thickness: night ? 34 : 28,
        lightIntensity: night ? 0.42 : 0.56,
        chromaticAberration: 0.08,
        saturation: night ? 1.18 : 1.34,
        glassColor: night ? const Color(0x2411161c) : const Color(0x30ffffff),
        standardOpacityMultiplier: 0.72,
      ),
      clipBehavior: Clip.hardEdge,
      allowElevation: false,
      child: child,
    );
  }
}

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
        final coverWash = _accentColor.withValues(alpha: 0.24);
        final nightCoverWash = _accentColor.withValues(
          alpha: compact ? 0.20 : 0.22,
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
                    coverWash: night ? nightCoverWash : coverWash,
                    child: widget.child,
                  )
                  : _PlayerWideTintedBackground(
                    night: night,
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
    required this.coverWash,
    required this.child,
  });

  final bool night;
  final Color coverWash;
  final Widget child;

  @override
  Widget build(BuildContext context) {
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
                        MediaControlColors.nightPlayerAccentWash,
                      ]
                      : [
                        MediaControlColors.playerSurface,
                        MediaControlColors.playerAccentWash,
                      ],
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _PlayerCompactTintedBackground extends StatelessWidget {
  const _PlayerCompactTintedBackground({
    required this.night,
    required this.coverWash,
    required this.child,
  });

  final bool night;
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
                            MediaControlColors.nightCompactPlayerWash,
                          ]
                          : [coverWash, MediaControlColors.compactPlayerWash],
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
