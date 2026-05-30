part of 'media_control.dart';

class MediaControlPlayerFrame extends StatelessWidget {
  const MediaControlPlayerFrame({
    super.key,
    required this.artworkPath,
    required this.child,
    this.borderRadius = const BorderRadius.vertical(top: Radius.circular(18)),
  });

  final String? artworkPath;
  final Widget child;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: LayoutBuilder(
        builder: (context, outerConstraints) {
          final compact = outerConstraints.maxWidth <= _playerCompactBreakpoint;
          return _PlayerBarShadowFrame(
            compact: compact,
            child: ClipRRect(
              borderRadius: borderRadius,
              child: _PlayerLiquidGlassFrame(
                child: _PlayerTintedFrame(
                  artworkPath: artworkPath,
                  child: child,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class MediaControlSurfaceBar extends StatelessWidget {
  const MediaControlSurfaceBar({
    super.key,
    required this.artworkPath,
    required this.padding,
    required this.leading,
    required this.surfaceFlex,
    required this.trackId,
    required this.isLoading,
    required this.favorite,
    required this.disabled,
    required this.isPlaying,
    required this.volume,
    required this.isMuted,
    required this.mode,
    required this.progressSeconds,
    required this.durationSeconds,
    required this.previousButtonRestartsTrack,
    required this.onTogglePlayPause,
    required this.onPrevious,
    this.onForcePrevious,
    required this.onNext,
    required this.onSeek,
    required this.onBeginSeek,
    required this.onEndSeek,
    required this.onVolumeChange,
    required this.onToggleMute,
    required this.onToggleShuffle,
    required this.onToggleRepeat,
    required this.onToggleRepeatOne,
    required this.onToggleFavorite,
    required this.utilityCondensed,
    required this.onMoreClick,
    this.borderRadius = const BorderRadius.vertical(top: Radius.circular(18)),
    this.leadingFlex,
    this.leadingWidth,
    this.utilityWidth,
    this.onOpenVoiceAssistant,
    this.condensed = false,
    this.navMinimal = false,
    this.utilityMinimal = false,
  });

  final String? artworkPath;
  final EdgeInsetsGeometry padding;
  final Widget leading;
  final int? leadingFlex;
  final double? leadingWidth;
  final double? utilityWidth;
  final int surfaceFlex;
  final int? trackId;
  final bool isLoading;
  final bool favorite;
  final bool disabled;
  final bool isPlaying;
  final int volume;
  final bool isMuted;
  final PlaybackMode mode;
  final double progressSeconds;
  final double durationSeconds;
  final bool previousButtonRestartsTrack;
  final VoidCallback onTogglePlayPause;
  final VoidCallback onPrevious;
  final VoidCallback? onForcePrevious;
  final VoidCallback onNext;
  final ValueChanged<double> onSeek;
  final VoidCallback onBeginSeek;
  final VoidCallback onEndSeek;
  final ValueChanged<int> onVolumeChange;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleShuffle;
  final VoidCallback onToggleRepeat;
  final VoidCallback onToggleRepeatOne;
  final VoidCallback onToggleFavorite;
  final VoidCallback? onOpenVoiceAssistant;
  final bool condensed;
  final bool navMinimal;
  final bool utilityCondensed;
  final bool utilityMinimal;
  final ValueChanged<BuildContext> onMoreClick;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    return MediaControlPlayerFrame(
      artworkPath: artworkPath,
      borderRadius: borderRadius,
      child: Padding(
        padding: padding,
        child: Row(
          children: [
            if (leadingWidth == null)
              Expanded(flex: leadingFlex!, child: leading)
            else
              SizedBox(width: leadingWidth, child: leading),
            Expanded(
              flex: surfaceFlex,
              child: MediaControlSurface(
                trackId: trackId,
                isLoading: isLoading,
                favorite: favorite,
                disabled: disabled,
                isPlaying: isPlaying,
                volume: volume,
                isMuted: isMuted,
                mode: mode,
                progressSeconds: progressSeconds,
                durationSeconds: durationSeconds,
                previousButtonRestartsTrack: previousButtonRestartsTrack,
                onTogglePlayPause: onTogglePlayPause,
                onPrevious: onPrevious,
                onForcePrevious: onForcePrevious,
                onNext: onNext,
                onSeek: onSeek,
                onBeginSeek: onBeginSeek,
                onEndSeek: onEndSeek,
                onVolumeChange: onVolumeChange,
                onToggleMute: onToggleMute,
                onToggleShuffle: onToggleShuffle,
                onToggleRepeat: onToggleRepeat,
                onToggleRepeatOne: onToggleRepeatOne,
                onToggleFavorite: onToggleFavorite,
                onOpenVoiceAssistant: onOpenVoiceAssistant,
                condensed: condensed,
                navMinimal: navMinimal,
                utilityCondensed: utilityCondensed,
                utilityMinimal: utilityMinimal,
                utilityWidth: utilityWidth,
                onMoreClick: onMoreClick,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
