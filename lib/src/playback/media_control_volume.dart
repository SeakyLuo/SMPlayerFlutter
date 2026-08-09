part of 'media_control.dart';

enum VolumeSliderOrientation { horizontal, vertical }

enum VolumeSliderVerticalTooltipSide { left, right }

int clampVolumeValue(num value) => value.round().clamp(0, 100);

const IconData _volumeMutedIcon = IconData(0xf004, fontFamily: 'SMPlayer');
const IconData _volumeOffIcon = IconData(0xf005, fontFamily: 'SMPlayer');
const IconData _volumeLowIcon = IconData(0xf006, fontFamily: 'SMPlayer');
const IconData _volumeMediumIcon = IconData(0xf007, fontFamily: 'SMPlayer');
const IconData _volumeHighIcon = IconData(0xf008, fontFamily: 'SMPlayer');

const double _volumeSliderHorizontalHeight = 44;
const double _volumeSliderVerticalHeight = 156;
const double _volumeSliderVerticalTrackLength = 132;
const double _mediaSliderInputHeight = 18;
const double _mediaSliderTrackHeight = 2;
const double _mediaSliderThumbRadius = 9;
const double _mediaSliderOverlayRadius = 10;
const double _volumeSliderTooltipGap = 8;

IconData playerVolumeIcon(int volume, bool isMuted) {
  if (isMuted) {
    return _volumeMutedIcon;
  }
  if (volume <= 0) {
    return _volumeOffIcon;
  }
  if (volume < 34) {
    return _volumeLowIcon;
  }
  if (volume < 67) {
    return _volumeMediumIcon;
  }
  return _volumeHighIcon;
}

const IconData _previousIcon = FluentIcons.previous_20_regular;
const IconData _playIcon = FluentIcons.play_20_regular;
const IconData _pauseIcon = FluentIcons.pause_20_regular;
const IconData _nextIcon = FluentIcons.next_20_regular;
const IconData _shuffleIcon = FluentIcons.arrow_shuffle_20_regular;
const IconData _repeatIcon = FluentIcons.arrow_repeat_all_20_regular;
const IconData _repeatOneIcon = FluentIcons.arrow_repeat_1_20_regular;
const IconData _listPlaybackIcon = FluentIcons.apps_list_detail_24_regular;
const IconData _moreIcon = IconData(0xf003, fontFamily: 'SMPlayer');
const IconData _voiceIcon = FluentIcons.mic_20_regular;
const IconData _desktopLyricsIcon = IconData(0xf009, fontFamily: 'SMPlayer');
const IconData _favoriteOutlineIcon = FluentIcons.heart_20_regular;
const IconData _favoriteFilledIcon = FluentIcons.heart_20_filled;

const String _desktopLyricsIconSvg =
    '<svg viewBox="0 0 20 20" fill="currentColor" xmlns="http://www.w3.org/2000/svg"><path d="M15.4 13.84h-4.92L6.21 17H6.2v-3.16H4.6c-.9 0-1.6-.71-1.6-1.56V5.57C3 4.7 3.7 4 4.6 4h10.8c.9 0 1.6.71 1.6 1.57v6.7c0 .86-.7 1.57-1.6 1.57Zm-10 3.76a1 1 0 0 0 1.4.2l4.01-2.96h4.59c1.44 0 2.6-1.15 2.6-2.56V5.57A2.58 2.58 0 0 0 15.4 3H4.6A2.58 2.58 0 0 0 2 5.57v6.7a2.58 2.58 0 0 0 2.6 2.57h.6v2.17c0 .22.07.42.2.6ZM9.5 10H15a.5.5 0 0 0 0-1H9.5a.5.5 0 0 0 0 1Zm-2-1H5a.5.5 0 0 0 0 1h2.5a.5.5 0 0 0 0-1ZM5 11a.5.5 0 0 0 0 1h5.5a.5.5 0 0 0 0-1H5Zm7.5 1a.5.5 0 0 1 0-1H15a.5.5 0 0 1 0 1h-2.5Z"/></svg>';

IconData get mediaControlPreviousIcon => _previousIcon;
IconData get mediaControlNextIcon => _nextIcon;
IconData get mediaControlPlayIcon => _playIcon;
IconData get mediaControlPauseIcon => _pauseIcon;
IconData get mediaControlQuickPlayIcon => _shuffleIcon;
IconData get mediaControlVoiceIcon => _voiceIcon;

IconData mediaControlPlaybackModeIcon(PlaybackMode mode) {
  return _playbackModeIcon(mode);
}

@visibleForTesting
IconData get mediaControlVolumeMutedIcon => _volumeMutedIcon;

@visibleForTesting
IconData get mediaControlVolumeOffIcon => _volumeOffIcon;

@visibleForTesting
IconData get mediaControlVolumeLowIcon => _volumeLowIcon;

@visibleForTesting
IconData get mediaControlVolumeMediumIcon => _volumeMediumIcon;

@visibleForTesting
IconData get mediaControlVolumeHighIcon => _volumeHighIcon;

class VolumeSlider extends StatefulWidget {
  const VolumeSlider({
    super.key,
    required this.value,
    required this.disabled,
    required this.onChange,
    this.orientation = VolumeSliderOrientation.horizontal,
    this.showTooltipOnMount = false,
    this.showTooltipOnHoverOrFocus = true,
    this.verticalHeight = _volumeSliderVerticalHeight,
    this.verticalTrackLength = _volumeSliderVerticalTrackLength,
    this.trackHeight = _mediaSliderTrackHeight,
    this.thumbRadius = _mediaSliderThumbRadius,
    this.overlayRadius = _mediaSliderOverlayRadius,
    this.verticalTooltipSide = VolumeSliderVerticalTooltipSide.right,
    this.activeTrackColor = MediaControlColors.accent,
    this.inactiveTrackColor = MediaControlColors.sliderInactive,
    this.thumbColor = MediaControlColors.accent,
    this.thumbShadow,
    this.overlayColor = MediaControlColors.accentHover,
    this.tooltipBackgroundColor,
    this.tooltipForegroundColor,
    this.tooltipBorderColor,
    this.tooltipShadow,
  });

  final int value;
  final bool disabled;
  final ValueChanged<int> onChange;
  final VolumeSliderOrientation orientation;
  final bool showTooltipOnMount;
  final bool showTooltipOnHoverOrFocus;
  final double verticalHeight;
  final double verticalTrackLength;
  final double trackHeight;
  final double thumbRadius;
  final double overlayRadius;
  final VolumeSliderVerticalTooltipSide verticalTooltipSide;
  final Color activeTrackColor;
  final Color inactiveTrackColor;
  final Color thumbColor;
  final BoxShadow? thumbShadow;
  final Color overlayColor;
  final Color? tooltipBackgroundColor;
  final Color? tooltipForegroundColor;
  final Color? tooltipBorderColor;
  final BoxShadow? tooltipShadow;

  @override
  State<VolumeSlider> createState() => _VolumeSliderState();
}

class _VolumeSliderState extends State<VolumeSlider> {
  final _sliderHostKey = GlobalKey();
  final _tooltipLayerLink = LayerLink();
  late var _liveValue = clampVolumeValue(widget.value).toDouble();
  late var _lastEmittedValue = clampVolumeValue(widget.value);
  OverlayEntry? _tooltipOverlayEntry;
  Timer? _tooltipTimer;
  var _tooltipActive = false;
  var _dragging = false;

  @override
  void initState() {
    super.initState();
    if (widget.showTooltipOnMount && !widget.disabled) {
      _tooltipActive = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _tooltipActive) {
          _showTooltipOverlay();
        }
      });
      _tooltipTimer = Timer(const Duration(milliseconds: 900), () {
        if (mounted && !_dragging) {
          setState(() {
            _tooltipActive = false;
          });
          _removeTooltipOverlay();
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant VolumeSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextValue = clampVolumeValue(widget.value);
    if (!_dragging && _liveValue.round() != nextValue) {
      _liveValue = nextValue.toDouble();
      _lastEmittedValue = nextValue;
    }
    if (widget.disabled && _tooltipActive) {
      _tooltipTimer?.cancel();
      _tooltipActive = false;
      _scheduleTooltipOverlayUpdate();
    } else if (_tooltipActive) {
      _scheduleTooltipOverlayUpdate();
    }
  }

  @override
  void dispose() {
    _tooltipTimer?.cancel();
    _removeTooltipOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.disabled ? 0.0 : _liveValue.clamp(0, 100).toDouble();
    final inactiveTrackColor =
        widget.inactiveTrackColor == MediaControlColors.sliderInactive
            ? MediaControlColors.sliderInactiveFor(context)
            : widget.inactiveTrackColor;
    final slider = SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: widget.trackHeight,
        trackShape: const _MediaProgressTrackShape(),
        thumbShape: _mediaSliderThumbShape(
          radius: widget.thumbRadius,
          shadow: widget.thumbShadow,
        ),
        overlayShape: RoundSliderOverlayShape(
          overlayRadius: widget.overlayRadius,
        ),
        activeTrackColor: widget.activeTrackColor,
        inactiveTrackColor: inactiveTrackColor,
        thumbColor: widget.thumbColor,
        overlayColor: widget.overlayColor,
      ),
      child: Focus(
        onFocusChange: (focused) {
          if (focused && widget.showTooltipOnHoverOrFocus) {
            _showTooltip();
          } else if (!_dragging) {
            _hideTooltip();
          }
        },
        child: MouseRegion(
          onEnter: (_) {
            if (widget.showTooltipOnHoverOrFocus) {
              _showTooltip(persistent: true);
            }
          },
          onExit: (_) {
            if (!_dragging) {
              _hideTooltip();
            }
          },
          child: Semantics(
            label: _mediaControlI18n(context).t('player.volume'),
            value: value.round().toString(),
            child: Slider(
              value: value,
              min: 0,
              max: 100,
              onChangeStart:
                  widget.disabled
                      ? null
                      : (_) {
                        _dragging = true;
                        _showTooltip(persistent: true);
                      },
              onChangeEnd:
                  widget.disabled
                      ? null
                      : (_) {
                        _dragging = false;
                        _showTooltip(
                          duration: const Duration(milliseconds: 650),
                        );
                      },
              onChanged: widget.disabled ? null : _handleSliderChanged,
            ),
          ),
        ),
      ),
    );

    final sliderHost = SizedBox(
      key: _sliderHostKey,
      height:
          widget.orientation == VolumeSliderOrientation.vertical
              ? widget.verticalHeight
              : _volumeSliderHorizontalHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              if (widget.orientation == VolumeSliderOrientation.vertical)
                RotatedBox(
                  quarterTurns: -1,
                  child: SizedBox(
                    width: widget.verticalTrackLength,
                    child: slider,
                  ),
                )
              else
                slider,
              if (_tooltipActive && !widget.disabled)
                if (widget.orientation == VolumeSliderOrientation.vertical)
                  _buildTooltip(context, constraints.biggest, value.round()),
            ],
          );
        },
      ),
    );
    if (widget.orientation == VolumeSliderOrientation.vertical) {
      return sliderHost;
    }
    return CompositedTransformTarget(
      link: _tooltipLayerLink,
      child: sliderHost,
    );
  }

  void _handleSliderChanged(double value) {
    final nextValue = clampVolumeValue(value);
    setState(() {
      _liveValue = nextValue.toDouble();
    });
    if (_lastEmittedValue == nextValue) {
      _tooltipOverlayEntry?.markNeedsBuild();
      return;
    }
    _lastEmittedValue = nextValue;
    widget.onChange(nextValue);
    _tooltipOverlayEntry?.markNeedsBuild();
  }

  void _showTooltip({
    bool persistent = false,
    Duration duration = const Duration(milliseconds: 900),
  }) {
    if (widget.disabled) {
      return;
    }
    _tooltipTimer?.cancel();
    if (!_tooltipActive) {
      setState(() {
        _tooltipActive = true;
      });
    }
    _showTooltipOverlay();
    if (!persistent) {
      _tooltipTimer = Timer(duration, () {
        if (mounted && !_dragging) {
          setState(() {
            _tooltipActive = false;
          });
          _removeTooltipOverlay();
        }
      });
    }
  }

  void _hideTooltip() {
    _tooltipTimer?.cancel();
    if (_tooltipActive) {
      setState(() {
        _tooltipActive = false;
      });
    }
    _removeTooltipOverlay();
  }

  Widget _buildTooltip(BuildContext context, Size sliderSize, int value) {
    return _VolumeSliderTooltip(
      value: value,
      orientation: widget.orientation,
      sliderSize: sliderSize,
      verticalTrackLength: widget.verticalTrackLength,
      overlayRadius: widget.overlayRadius,
      verticalTooltipSide: widget.verticalTooltipSide,
      backgroundColor:
          widget.tooltipBackgroundColor ??
          MediaControlThemeColors.of(context).volumeTooltipBackground,
      foregroundColor:
          widget.tooltipForegroundColor ??
          MediaControlThemeColors.of(context).volumeTooltipForeground,
      borderColor:
          widget.tooltipBorderColor ??
          MediaControlThemeColors.of(context).volumeTooltipBorder,
      shadow:
          widget.tooltipShadow ??
          MediaControlThemeColors.of(context).volumeTooltipShadow,
    );
  }

  void _showTooltipOverlay() {
    if (widget.orientation == VolumeSliderOrientation.vertical ||
        widget.disabled) {
      _removeTooltipOverlay();
      return;
    }
    if (_tooltipOverlayEntry != null) {
      _tooltipOverlayEntry!.markNeedsBuild();
      return;
    }
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      return;
    }
    _tooltipOverlayEntry = OverlayEntry(
      builder: (overlayContext) {
        final renderBox =
            _sliderHostKey.currentContext?.findRenderObject() as RenderBox?;
        final sliderSize = renderBox?.size ?? Size.zero;
        return Positioned.fill(
          child: IgnorePointer(
            child: CompositedTransformFollower(
              link: _tooltipLayerLink,
              showWhenUnlinked: false,
              targetAnchor: Alignment.topLeft,
              followerAnchor: Alignment.topLeft,
              child: UnconstrainedBox(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: sliderSize.width,
                  height: sliderSize.height,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _buildTooltip(
                        overlayContext,
                        sliderSize,
                        _liveValue.round(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
    overlay.insert(_tooltipOverlayEntry!);
  }

  void _removeTooltipOverlay() {
    _tooltipOverlayEntry?.remove();
    _tooltipOverlayEntry = null;
  }

  void _scheduleTooltipOverlayUpdate() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (widget.disabled || !_tooltipActive) {
        _removeTooltipOverlay();
        return;
      }
      _tooltipOverlayEntry?.markNeedsBuild();
    });
  }
}

SliderComponentShape _mediaSliderThumbShape({
  required double radius,
  required BoxShadow? shadow,
}) {
  if (shadow == null) {
    return RoundSliderThumbShape(
      enabledThumbRadius: radius,
      elevation: 0,
      pressedElevation: 0,
    );
  }
  return MediaSliderThumbShape(enabledThumbRadius: radius, shadow: shadow);
}

class MediaSliderThumbShape extends RoundSliderThumbShape {
  const MediaSliderThumbShape({
    required this.shadow,
    super.enabledThumbRadius,
    super.disabledThumbRadius,
    super.elevation = 0,
    super.pressedElevation = 0,
  });

  final BoxShadow shadow;

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    final paint =
        Paint()
          ..color = shadow.color
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, shadow.blurRadius);
    canvas.drawCircle(center + shadow.offset, enabledThumbRadius, paint);
    super.paint(
      context,
      center,
      activationAnimation: activationAnimation,
      enableAnimation: enableAnimation,
      isDiscrete: isDiscrete,
      labelPainter: labelPainter,
      parentBox: parentBox,
      sliderTheme: sliderTheme,
      textDirection: textDirection,
      value: value,
      textScaleFactor: textScaleFactor,
      sizeWithOverflow: sizeWithOverflow,
    );
  }
}

class _VolumeSliderTooltip extends StatelessWidget {
  const _VolumeSliderTooltip({
    required this.value,
    required this.orientation,
    required this.sliderSize,
    required this.verticalTrackLength,
    required this.overlayRadius,
    required this.verticalTooltipSide,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.borderColor,
    required this.shadow,
  });

  final int value;
  final VolumeSliderOrientation orientation;
  final Size sliderSize;
  final double verticalTrackLength;
  final double overlayRadius;
  final VolumeSliderVerticalTooltipSide verticalTooltipSide;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color borderColor;
  final BoxShadow shadow;

  static const _horizontalArrowWidth = 8.0;
  static const _horizontalArrowHeight = 6.0;
  static const _verticalArrowWidth = 6.0;
  static const _verticalArrowHeight = 12.0;
  static const _borderRadius = 6.0;
  static const _minBodyWidth = 44.0;
  static const _bodyHorizontalPadding = 10.0;
  static const _bodyVerticalPadding = 6.0;

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(
      color: foregroundColor,
      fontSize: 13,
      fontWeight: FontWeight.w700,
      height: 1.15,
    );
    if (orientation == VolumeSliderOrientation.vertical) {
      final centerY = _volumeSliderVerticalThumbCenterY(
        value,
        sliderSize.height,
        verticalTrackLength,
        overlayRadius,
      );
      final horizontalOffset =
          verticalTooltipSide == VolumeSliderVerticalTooltipSide.left
              ? sliderSize.width + _volumeSliderTooltipGap
              : (sliderSize.width / 2) +
                  overlayRadius +
                  _volumeSliderTooltipGap;
      final tooltip = _VolumeSliderTooltipBubble(
        value: value,
        textStyle: textStyle,
        backgroundColor: backgroundColor,
        borderColor: borderColor,
        shadow: shadow,
        arrowSide:
            verticalTooltipSide == VolumeSliderVerticalTooltipSide.left
                ? _VolumeSliderTooltipArrowSide.right
                : _VolumeSliderTooltipArrowSide.left,
        borderRadius: _borderRadius,
        minBodyWidth: _minBodyWidth,
        bodyHorizontalPadding: _bodyHorizontalPadding,
        bodyVerticalPadding: _bodyVerticalPadding,
        arrowWidth: _verticalArrowWidth,
        arrowHeight: _verticalArrowHeight,
      );
      return Positioned(
        key: const ValueKey('VolumeSlider.TooltipPosition'),
        left:
            verticalTooltipSide == VolumeSliderVerticalTooltipSide.right
                ? horizontalOffset
                : null,
        right:
            verticalTooltipSide == VolumeSliderVerticalTooltipSide.left
                ? horizontalOffset
                : null,
        top: centerY,
        child: FractionalTranslation(
          translation: const Offset(0, -0.5),
          child: tooltip,
        ),
      );
    }
    final centerX = _volumeSliderHorizontalThumbCenterX(
      value,
      sliderSize.width,
    );
    final tooltip = _VolumeSliderTooltipBubble(
      value: value,
      textStyle: textStyle,
      backgroundColor: backgroundColor,
      borderColor: borderColor,
      shadow: shadow,
      arrowSide: _VolumeSliderTooltipArrowSide.bottom,
      borderRadius: _borderRadius,
      minBodyWidth: _minBodyWidth,
      bodyHorizontalPadding: _bodyHorizontalPadding,
      bodyVerticalPadding: _bodyVerticalPadding,
      arrowWidth: _horizontalArrowWidth,
      arrowHeight: _horizontalArrowHeight,
    );
    return Positioned(
      key: const ValueKey('VolumeSlider.TooltipPosition'),
      left: centerX,
      bottom: sliderSize.height + _volumeSliderTooltipGap,
      child: FractionalTranslation(
        translation: const Offset(-0.5, 0),
        child: tooltip,
      ),
    );
  }
}

enum _VolumeSliderTooltipArrowSide { left, right, bottom }

class _VolumeSliderTooltipBubble extends StatelessWidget {
  const _VolumeSliderTooltipBubble({
    required this.value,
    required this.textStyle,
    required this.backgroundColor,
    required this.borderColor,
    required this.shadow,
    required this.arrowSide,
    required this.borderRadius,
    required this.minBodyWidth,
    required this.bodyHorizontalPadding,
    required this.bodyVerticalPadding,
    required this.arrowWidth,
    required this.arrowHeight,
  });

  final int value;
  final TextStyle textStyle;
  final Color backgroundColor;
  final Color borderColor;
  final BoxShadow shadow;
  final _VolumeSliderTooltipArrowSide arrowSide;
  final double borderRadius;
  final double minBodyWidth;
  final double bodyHorizontalPadding;
  final double bodyVerticalPadding;
  final double arrowWidth;
  final double arrowHeight;

  @override
  Widget build(BuildContext context) {
    final child = ConstrainedBox(
      constraints: BoxConstraints(minWidth: minBodyWidth),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: bodyHorizontalPadding,
          vertical: bodyVerticalPadding,
        ),
        child: Text('$value', textAlign: TextAlign.center, style: textStyle),
      ),
    );
    final body = KeyedSubtree(
      key: const ValueKey('VolumeSlider.TooltipBody'),
      child: child,
    );
    return CustomPaint(
      key: const ValueKey('VolumeSlider.Tooltip'),
      painter: _VolumeSliderTooltipBubblePainter(
        backgroundColor: backgroundColor,
        borderColor: borderColor,
        shadow: shadow,
        arrowSide: arrowSide,
        borderRadius: borderRadius,
        arrowWidth: arrowWidth,
        arrowHeight: arrowHeight,
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left:
              arrowSide == _VolumeSliderTooltipArrowSide.left ? arrowWidth : 0,
          right:
              arrowSide == _VolumeSliderTooltipArrowSide.right ? arrowWidth : 0,
          bottom:
              arrowSide == _VolumeSliderTooltipArrowSide.bottom
                  ? arrowHeight
                  : 0,
        ),
        child: body,
      ),
    );
  }
}

class _VolumeSliderTooltipBubblePainter extends CustomPainter {
  const _VolumeSliderTooltipBubblePainter({
    required this.backgroundColor,
    required this.borderColor,
    required this.shadow,
    required this.arrowSide,
    required this.borderRadius,
    required this.arrowWidth,
    required this.arrowHeight,
  });

  final Color backgroundColor;
  final Color borderColor;
  final BoxShadow shadow;
  final _VolumeSliderTooltipArrowSide arrowSide;
  final double borderRadius;
  final double arrowWidth;
  final double arrowHeight;

  @override
  void paint(Canvas canvas, Size size) {
    final bodyRect = Rect.fromLTWH(
      arrowSide == _VolumeSliderTooltipArrowSide.left ? arrowWidth : 0,
      0,
      size.width -
          (arrowSide == _VolumeSliderTooltipArrowSide.left ||
                  arrowSide == _VolumeSliderTooltipArrowSide.right
              ? arrowWidth
              : 0),
      size.height -
          (arrowSide == _VolumeSliderTooltipArrowSide.bottom ? arrowHeight : 0),
    );
    final path = _tooltipOutlinePath(bodyRect);
    final shadowPaint =
        Paint()
          ..color = shadow.color
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, shadow.blurRadius);
    canvas.drawPath(path.shift(shadow.offset), shadowPaint);
    canvas.drawPath(path, Paint()..color = backgroundColor);
    canvas.drawPath(
      path,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _VolumeSliderTooltipBubblePainter oldDelegate) {
    return oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.shadow != shadow ||
        oldDelegate.arrowSide != arrowSide ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.arrowWidth != arrowWidth ||
        oldDelegate.arrowHeight != arrowHeight;
  }

  Path _tooltipOutlinePath(Rect bodyRect) {
    final r = min(borderRadius, min(bodyRect.width, bodyRect.height) / 2);
    if (arrowSide == _VolumeSliderTooltipArrowSide.right) {
      final arrowTop = bodyRect.center.dy - arrowHeight / 2;
      final arrowBottom = bodyRect.center.dy + arrowHeight / 2;
      return Path()
        ..moveTo(bodyRect.left + r, bodyRect.top)
        ..lineTo(bodyRect.right - r, bodyRect.top)
        ..quadraticBezierTo(
          bodyRect.right,
          bodyRect.top,
          bodyRect.right,
          bodyRect.top + r,
        )
        ..lineTo(bodyRect.right, arrowTop)
        ..lineTo(bodyRect.right + arrowWidth, bodyRect.center.dy)
        ..lineTo(bodyRect.right, arrowBottom)
        ..lineTo(bodyRect.right, bodyRect.bottom - r)
        ..quadraticBezierTo(
          bodyRect.right,
          bodyRect.bottom,
          bodyRect.right - r,
          bodyRect.bottom,
        )
        ..lineTo(bodyRect.left + r, bodyRect.bottom)
        ..quadraticBezierTo(
          bodyRect.left,
          bodyRect.bottom,
          bodyRect.left,
          bodyRect.bottom - r,
        )
        ..lineTo(bodyRect.left, bodyRect.top + r)
        ..quadraticBezierTo(
          bodyRect.left,
          bodyRect.top,
          bodyRect.left + r,
          bodyRect.top,
        )
        ..close();
    }
    if (arrowSide == _VolumeSliderTooltipArrowSide.left) {
      final arrowTop = bodyRect.center.dy - arrowHeight / 2;
      final arrowBottom = bodyRect.center.dy + arrowHeight / 2;
      return Path()
        ..moveTo(bodyRect.left + r, bodyRect.top)
        ..lineTo(bodyRect.right - r, bodyRect.top)
        ..quadraticBezierTo(
          bodyRect.right,
          bodyRect.top,
          bodyRect.right,
          bodyRect.top + r,
        )
        ..lineTo(bodyRect.right, bodyRect.bottom - r)
        ..quadraticBezierTo(
          bodyRect.right,
          bodyRect.bottom,
          bodyRect.right - r,
          bodyRect.bottom,
        )
        ..lineTo(bodyRect.left + r, bodyRect.bottom)
        ..quadraticBezierTo(
          bodyRect.left,
          bodyRect.bottom,
          bodyRect.left,
          bodyRect.bottom - r,
        )
        ..lineTo(bodyRect.left, arrowBottom)
        ..lineTo(bodyRect.left - arrowWidth, bodyRect.center.dy)
        ..lineTo(bodyRect.left, arrowTop)
        ..lineTo(bodyRect.left, bodyRect.top + r)
        ..quadraticBezierTo(
          bodyRect.left,
          bodyRect.top,
          bodyRect.left + r,
          bodyRect.top,
        )
        ..close();
    }
    final arrowLeft = bodyRect.center.dx - arrowWidth / 2;
    final arrowRight = bodyRect.center.dx + arrowWidth / 2;
    return Path()
      ..moveTo(bodyRect.left + r, bodyRect.top)
      ..lineTo(bodyRect.right - r, bodyRect.top)
      ..quadraticBezierTo(
        bodyRect.right,
        bodyRect.top,
        bodyRect.right,
        bodyRect.top + r,
      )
      ..lineTo(bodyRect.right, bodyRect.bottom - r)
      ..quadraticBezierTo(
        bodyRect.right,
        bodyRect.bottom,
        bodyRect.right - r,
        bodyRect.bottom,
      )
      ..lineTo(arrowRight, bodyRect.bottom)
      ..lineTo(bodyRect.center.dx, bodyRect.bottom + arrowHeight)
      ..lineTo(arrowLeft, bodyRect.bottom)
      ..lineTo(bodyRect.left + r, bodyRect.bottom)
      ..quadraticBezierTo(
        bodyRect.left,
        bodyRect.bottom,
        bodyRect.left,
        bodyRect.bottom - r,
      )
      ..lineTo(bodyRect.left, bodyRect.top + r)
      ..quadraticBezierTo(
        bodyRect.left,
        bodyRect.top,
        bodyRect.left + r,
        bodyRect.top,
      )
      ..close();
  }
}

double _volumeSliderHorizontalThumbCenterX(int value, double width) {
  return width * (clampVolumeValue(value) / 100);
}

double _volumeSliderVerticalThumbCenterY(
  int value,
  double height,
  double trackLength,
  double overlayRadius,
) {
  final trackHeight = trackLength - (overlayRadius * 2);
  final rotatedTrackTop = (height - trackLength) / 2;
  return rotatedTrackTop +
      overlayRadius +
      trackHeight * (1 - clampVolumeValue(value) / 100);
}
