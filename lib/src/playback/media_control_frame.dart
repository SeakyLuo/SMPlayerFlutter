part of 'media_control.dart';

class MediaControlPlayerFrame extends StatelessWidget {
  const MediaControlPlayerFrame({
    super.key,
    required this.artworkPath,
    required this.child,
    this.borderRadius = const BorderRadius.vertical(top: Radius.circular(18)),
    this.preserveWideBackground = false,
  });

  final String? artworkPath;
  final Widget child;
  final BorderRadius borderRadius;
  final bool preserveWideBackground;

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
                compact: compact,
                child: _PlayerTintedFrame(
                  artworkPath: artworkPath,
                  preserveWideBackground: preserveWideBackground,
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
    this.utilityFlex,
    this.columnGap = 0,
    this.onOpenVoiceAssistant,
    this.condensed = false,
    this.navMinimal = false,
    this.utilityMinimal = false,
    this.sliderActiveColor,
    this.sliderInactiveColor,
    this.sliderThumbColor,
    this.sliderThumbShadow,
    this.sliderOverlayColor,
    this.volumeSliderActiveColor,
    this.volumeSliderInactiveColor,
    this.volumeSliderThumbColor,
    this.volumeSliderThumbShadow,
    this.volumeSliderOverlayColor,
    this.preserveWideBackground = false,
  });

  final String? artworkPath;
  final EdgeInsetsGeometry padding;
  final Widget leading;
  final int? leadingFlex;
  final double? leadingWidth;
  final double? utilityWidth;
  final int? utilityFlex;
  final double columnGap;
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
  final Color? sliderActiveColor;
  final Color? sliderInactiveColor;
  final Color? sliderThumbColor;
  final BoxShadow? sliderThumbShadow;
  final Color? sliderOverlayColor;
  final Color? volumeSliderActiveColor;
  final Color? volumeSliderInactiveColor;
  final Color? volumeSliderThumbColor;
  final BoxShadow? volumeSliderThumbShadow;
  final Color? volumeSliderOverlayColor;
  final bool preserveWideBackground;
  final ValueChanged<BuildContext> onMoreClick;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final navTopRowHeight =
        navMinimal
            ? (utilityWidth != null && utilityWidth! <= 68 ? 72.0 : 74.0)
            : null;
    Widget navMinimalSideSlot(Widget child) {
      if (navTopRowHeight == null) {
        return child;
      }
      return Align(
        alignment: Alignment.topCenter,
        child: SizedBox(height: navTopRowHeight, child: child),
      );
    }

    final resolvedUtilityWidth = _resolvedMediaControlUtilityWidth(
      width: utilityWidth,
      minimal: utilityMinimal,
      condensed: utilityCondensed,
      hasVoiceAssistant: onOpenVoiceAssistant != null,
    );
    final leadingContentAligned = leadingWidth == null && utilityFlex != null;

    return MediaControlPlayerFrame(
      artworkPath: artworkPath,
      borderRadius: borderRadius,
      preserveWideBackground: preserveWideBackground,
      child: Padding(
        padding: padding,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (leadingWidth == null)
              Expanded(
                flex: leadingFlex!,
                child:
                    leadingContentAligned
                        ? Align(alignment: Alignment.centerLeft, child: leading)
                        : leading,
              )
            else
              SizedBox(width: leadingWidth, child: navMinimalSideSlot(leading)),
            if (columnGap > 0) SizedBox(width: columnGap),
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
                includeUtility: false,
                progressSideOverflow:
                    navMinimal && leadingWidth != null
                        ? leadingWidth! + columnGap - 9
                        : 0,
                sliderActiveColor: sliderActiveColor,
                sliderInactiveColor: sliderInactiveColor,
                sliderThumbColor: sliderThumbColor,
                sliderThumbShadow: sliderThumbShadow,
                sliderOverlayColor: sliderOverlayColor,
                onMoreClick: onMoreClick,
              ),
            ),
            if (columnGap > 0) SizedBox(width: columnGap),
            if (utilityWidth == null && utilityFlex != null)
              Expanded(
                flex: utilityFlex!,
                child: navMinimalSideSlot(
                  Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox(
                      width: resolvedUtilityWidth,
                      child: _MediaControlSurfaceBarUtility(
                        width: resolvedUtilityWidth,
                        trackId: trackId,
                        favorite: favorite,
                        disabled: disabled,
                        volume: volume,
                        isMuted: isMuted,
                        mode: mode,
                        onVolumeChange: onVolumeChange,
                        onToggleMute: onToggleMute,
                        onToggleShuffle: onToggleShuffle,
                        onToggleRepeat: onToggleRepeat,
                        onToggleRepeatOne: onToggleRepeatOne,
                        onToggleFavorite: onToggleFavorite,
                        onOpenVoiceAssistant: onOpenVoiceAssistant,
                        utilityCondensed: utilityCondensed,
                        utilityMinimal: utilityMinimal,
                        sliderActiveColor: sliderActiveColor,
                        sliderInactiveColor: sliderInactiveColor,
                        sliderThumbColor: sliderThumbColor,
                        sliderThumbShadow: sliderThumbShadow,
                        sliderOverlayColor: sliderOverlayColor,
                        volumeSliderActiveColor: volumeSliderActiveColor,
                        volumeSliderInactiveColor: volumeSliderInactiveColor,
                        volumeSliderThumbColor: volumeSliderThumbColor,
                        volumeSliderThumbShadow: volumeSliderThumbShadow,
                        volumeSliderOverlayColor: volumeSliderOverlayColor,
                        onMoreClick: onMoreClick,
                      ),
                    ),
                  ),
                ),
              )
            else if (utilityWidth == null)
              SizedBox(
                width: resolvedUtilityWidth,
                child: navMinimalSideSlot(
                  _MediaControlSurfaceBarUtility(
                    width: resolvedUtilityWidth,
                    trackId: trackId,
                    favorite: favorite,
                    disabled: disabled,
                    volume: volume,
                    isMuted: isMuted,
                    mode: mode,
                    onVolumeChange: onVolumeChange,
                    onToggleMute: onToggleMute,
                    onToggleShuffle: onToggleShuffle,
                    onToggleRepeat: onToggleRepeat,
                    onToggleRepeatOne: onToggleRepeatOne,
                    onToggleFavorite: onToggleFavorite,
                    onOpenVoiceAssistant: onOpenVoiceAssistant,
                    utilityCondensed: utilityCondensed,
                    utilityMinimal: utilityMinimal,
                    sliderActiveColor: sliderActiveColor,
                    sliderInactiveColor: sliderInactiveColor,
                    sliderThumbColor: sliderThumbColor,
                    sliderThumbShadow: sliderThumbShadow,
                    sliderOverlayColor: sliderOverlayColor,
                    volumeSliderActiveColor: volumeSliderActiveColor,
                    volumeSliderInactiveColor: volumeSliderInactiveColor,
                    volumeSliderThumbColor: volumeSliderThumbColor,
                    volumeSliderThumbShadow: volumeSliderThumbShadow,
                    volumeSliderOverlayColor: volumeSliderOverlayColor,
                    onMoreClick: onMoreClick,
                  ),
                ),
              )
            else
              SizedBox(
                width: resolvedUtilityWidth,
                child: navMinimalSideSlot(
                  _MediaControlSurfaceBarUtility(
                    width: resolvedUtilityWidth,
                    trackId: trackId,
                    favorite: favorite,
                    disabled: disabled,
                    volume: volume,
                    isMuted: isMuted,
                    mode: mode,
                    onVolumeChange: onVolumeChange,
                    onToggleMute: onToggleMute,
                    onToggleShuffle: onToggleShuffle,
                    onToggleRepeat: onToggleRepeat,
                    onToggleRepeatOne: onToggleRepeatOne,
                    onToggleFavorite: onToggleFavorite,
                    onOpenVoiceAssistant: onOpenVoiceAssistant,
                    utilityCondensed: utilityCondensed,
                    utilityMinimal: utilityMinimal,
                    sliderActiveColor: sliderActiveColor,
                    sliderInactiveColor: sliderInactiveColor,
                    sliderThumbColor: sliderThumbColor,
                    sliderThumbShadow: sliderThumbShadow,
                    sliderOverlayColor: sliderOverlayColor,
                    volumeSliderActiveColor: volumeSliderActiveColor,
                    volumeSliderInactiveColor: volumeSliderInactiveColor,
                    volumeSliderThumbColor: volumeSliderThumbColor,
                    volumeSliderThumbShadow: volumeSliderThumbShadow,
                    volumeSliderOverlayColor: volumeSliderOverlayColor,
                    onMoreClick: onMoreClick,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MediaControlSurfaceBarUtility extends StatelessWidget {
  const _MediaControlSurfaceBarUtility({
    required this.width,
    required this.trackId,
    required this.favorite,
    required this.disabled,
    required this.volume,
    required this.isMuted,
    required this.mode,
    required this.onVolumeChange,
    required this.onToggleMute,
    required this.onToggleShuffle,
    required this.onToggleRepeat,
    required this.onToggleRepeatOne,
    required this.onToggleFavorite,
    required this.onOpenVoiceAssistant,
    required this.utilityCondensed,
    required this.utilityMinimal,
    required this.sliderActiveColor,
    required this.sliderInactiveColor,
    required this.sliderThumbColor,
    required this.sliderThumbShadow,
    required this.sliderOverlayColor,
    required this.volumeSliderActiveColor,
    required this.volumeSliderInactiveColor,
    required this.volumeSliderThumbColor,
    required this.volumeSliderThumbShadow,
    required this.volumeSliderOverlayColor,
    required this.onMoreClick,
  });

  final double width;
  final int? trackId;
  final bool favorite;
  final bool disabled;
  final int volume;
  final bool isMuted;
  final PlaybackMode mode;
  final ValueChanged<int> onVolumeChange;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleShuffle;
  final VoidCallback onToggleRepeat;
  final VoidCallback onToggleRepeatOne;
  final VoidCallback onToggleFavorite;
  final VoidCallback? onOpenVoiceAssistant;
  final bool utilityCondensed;
  final bool utilityMinimal;
  final Color? sliderActiveColor;
  final Color? sliderInactiveColor;
  final Color? sliderThumbColor;
  final BoxShadow? sliderThumbShadow;
  final Color? sliderOverlayColor;
  final Color? volumeSliderActiveColor;
  final Color? volumeSliderInactiveColor;
  final Color? volumeSliderThumbColor;
  final BoxShadow? volumeSliderThumbShadow;
  final Color? volumeSliderOverlayColor;
  final ValueChanged<BuildContext> onMoreClick;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: utilityMinimal ? Alignment.center : Alignment.centerRight,
      child: MediaControlUtilityRows(
        trackId: trackId,
        favorite: favorite,
        disabled: disabled,
        volumeValue: disabled ? 0 : clampVolumeValue(volume),
        isMuted: isMuted,
        mode: mode,
        onVolumeChange: onVolumeChange,
        onToggleMute: onToggleMute,
        onToggleShuffle: onToggleShuffle,
        onToggleRepeat: onToggleRepeat,
        onToggleRepeatOne: onToggleRepeatOne,
        onToggleFavorite: onToggleFavorite,
        onOpenVoiceAssistant: onOpenVoiceAssistant,
        condensed: utilityCondensed,
        minimal: utilityMinimal,
        width: width,
        sliderActiveColor: sliderActiveColor,
        sliderInactiveColor: sliderInactiveColor,
        sliderThumbColor: sliderThumbColor,
        sliderThumbShadow: sliderThumbShadow,
        sliderOverlayColor: sliderOverlayColor,
        volumeSliderActiveColor: volumeSliderActiveColor,
        volumeSliderInactiveColor: volumeSliderInactiveColor,
        volumeSliderThumbColor: volumeSliderThumbColor,
        volumeSliderThumbShadow: volumeSliderThumbShadow,
        volumeSliderOverlayColor: volumeSliderOverlayColor,
        onMoreClick: onMoreClick,
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
      key: const ValueKey('MediaControl.PlayerFrameShadow'),
      decoration: BoxDecoration(
        boxShadow:
            compact
                ? [
                  BoxShadow(
                    color: colors.compactPlayerShadow,
                    offset: Offset(0, colors.compactShadowOffsetY),
                    blurRadius: colors.compactShadowBlur,
                  ),
                ]
                : [
                  BoxShadow(
                    color: colors.playerShadow,
                    offset: Offset(0, colors.wideShadowOffsetY),
                    blurRadius: colors.wideShadowBlur,
                  ),
                ],
      ),
      child: child,
    );
  }
}

class _PlayerLiquidGlassFrame extends StatelessWidget {
  const _PlayerLiquidGlassFrame({required this.compact, required this.child});

  final bool compact;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = MediaControlThemeColors.of(context);
    return GlassContainer(
      useOwnLayer: true,
      quality: GlassQuality.minimal,
      shape: const LiquidRoundedRectangle(borderRadius: 0),
      settings: LiquidGlassSettings(
        blur: 46,
        thickness: 20,
        lightIntensity: 0.1,
        chromaticAberration: 0,
        saturation: 1.65,
        glassColor: colors.glassColor,
        standardOpacityMultiplier: 0.35,
      ),
      clipBehavior: Clip.hardEdge,
      allowElevation: false,
      child: child,
    );
  }
}

class _PlayerTintedFrame extends StatefulWidget {
  const _PlayerTintedFrame({
    required this.artworkPath,
    required this.preserveWideBackground,
    required this.child,
  });

  final String? artworkPath;
  final bool preserveWideBackground;
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
        final compactCoverWash = _accentColor.withValues(
          alpha: colors.compactCoverWashAlpha,
        );
        final useCompactBackground = compact && !widget.preserveWideBackground;
        final borderColor =
            compact ? colors.compactPlayerBorder : colors.playerBorder;
        final border =
            compact
                ? Border(top: BorderSide(color: borderColor))
                : Border.all(color: borderColor);

        return DecoratedBox(
          key: const ValueKey('MediaControl.PlayerFrameBorder'),
          decoration: BoxDecoration(border: border),
          child:
              useCompactBackground
                  ? _PlayerCompactTintedBackground(
                    colors: colors,
                    coverWash: compactCoverWash,
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
    Widget withInsetHighlight(Widget child) {
      return Stack(
        fit: StackFit.expand,
        children: [
          child,
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 1,
            child: ColoredBox(
              key: const ValueKey('MediaControl.PlayerFrameInsetHighlight'),
              color: colors.wideInsetHighlight,
            ),
          ),
        ],
      );
    }

    if (colors.coverWashMode == MediaControlCoverWashMode.radial) {
      return withInsetHighlight(
        DecoratedBox(
          key: const ValueKey('MediaControl.PlayerFrameBackground'),
          decoration: BoxDecoration(
            color: colors.wideSurface,
            gradient: RadialGradient(
              center: colors.coverWashAlignment,
              radius: colors.coverWashRadius,
              colors: [coverWash, Colors.transparent],
            ),
          ),
          child: child,
        ),
      );
    }
    return withInsetHighlight(
      DecoratedBox(
        key: const ValueKey('MediaControl.PlayerFrameBackground'),
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
                stops: colors.wideHighlightStops,
              ),
            ),
            child: child,
          ),
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
    if (colors.coverWashMode == MediaControlCoverWashMode.radial) {
      return Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            key: const ValueKey('MediaControl.PlayerFrameBackground'),
            decoration: BoxDecoration(
              color: colors.compactSurface,
              gradient: RadialGradient(
                center: colors.coverWashAlignment,
                radius: colors.coverWashRadius,
                colors: [coverWash, Colors.transparent],
              ),
            ),
            child: child,
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 1,
            child: ColoredBox(
              key: const ValueKey('MediaControl.PlayerFrameInsetHighlight'),
              color: colors.compactInsetHighlight,
            ),
          ),
        ],
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          key: const ValueKey('MediaControl.PlayerFrameBackground'),
          decoration: BoxDecoration(color: colors.compactSurface),
          child: DecoratedBox(
            key: const ValueKey('MediaControl.PlayerCompactBaseGradient'),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: colors.compactBaseGradient,
                stops: colors.compactBaseGradientStops,
              ),
            ),
            child: DecoratedBox(
              key: const ValueKey('MediaControl.PlayerCompactCoverGradient'),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [coverWash, colors.compactWashEnd],
                  stops: [0, colors.compactWashStop],
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
            key: const ValueKey('MediaControl.PlayerFrameInsetHighlight'),
            color: colors.compactInsetHighlight,
          ),
        ),
      ],
    );
  }
}
