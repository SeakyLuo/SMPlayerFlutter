part of 'media_control.dart';

class _PlayerBarShadowFrame extends StatelessWidget {
  const _PlayerBarShadowFrame({required this.compact, required this.child});

  final bool compact;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = MediaControlThemeColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        boxShadow:
            compact
                ? [
                  BoxShadow(
                    color: colors.compactPlayerShadow,
                    offset: const Offset(0, -12),
                    blurRadius: 36,
                  ),
                ]
                : [
                  BoxShadow(
                    color: colors.playerShadow,
                    offset: Offset(0, colors.wideShadowOffsetY),
                    blurRadius: 48,
                  ),
                ],
      ),
      child: child,
    );
  }
}

class _PlayerLiquidGlassFrame extends StatelessWidget {
  const _PlayerLiquidGlassFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = MediaControlThemeColors.of(context);
    return GlassContainer(
      useOwnLayer: true,
      quality: GlassQuality.standard,
      shape: const LiquidRoundedRectangle(borderRadius: 0),
      settings: LiquidGlassSettings(
        blur: 18,
        thickness: colors.glassThickness,
        lightIntensity: colors.glassLightIntensity,
        chromaticAberration: 0.08,
        saturation: colors.glassSaturation,
        glassColor: colors.glassColor,
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
        final colors = MediaControlThemeColors.of(context);
        final coverWash = _accentColor.withValues(alpha: colors.coverWashAlpha);
        final borderColor =
            compact ? colors.compactPlayerBorder : colors.playerBorder;
        final border =
            compact
                ? Border(top: BorderSide(color: borderColor))
                : Border(
                  top: BorderSide(color: borderColor),
                  left: BorderSide(color: borderColor),
                  right: BorderSide(color: borderColor),
                );

        return DecoratedBox(
          decoration: BoxDecoration(border: border),
          child:
              compact
                  ? _PlayerCompactTintedBackground(
                    colors: colors,
                    coverWash: coverWash,
                    child: widget.child,
                  )
                  : _PlayerWideTintedBackground(
                    colors: colors,
                    coverWash: coverWash,
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
    required this.colors,
    required this.coverWash,
    required this.child,
  });

  final MediaControlThemeColors colors;
  final Color coverWash;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: colors.wideSurface),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [coverWash, Colors.transparent],
            stops: [0, colors.wideWashStop],
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors.wideHighlightGradient,
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
    required this.colors,
    required this.coverWash,
    required this.child,
  });

  final MediaControlThemeColors colors;
  final Color coverWash;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(color: colors.wideSurface),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [coverWash, Colors.transparent],
                stops: [0, colors.wideWashStop],
              ),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: colors.wideHighlightGradient,
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
          child: ColoredBox(color: colors.compactInsetHighlight),
        ),
      ],
    );
  }
}
