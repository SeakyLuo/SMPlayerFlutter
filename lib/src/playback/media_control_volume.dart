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
const IconData _favoriteOutlineIcon = IconData(0xf001, fontFamily: 'SMPlayer');
const IconData _favoriteFilledIcon = IconData(0xf002, fontFamily: 'SMPlayer');

IconData get mediaControlPreviousIcon => _previousIcon;
IconData get mediaControlNextIcon => _nextIcon;
IconData get mediaControlPlayIcon => _playIcon;
IconData get mediaControlPauseIcon => _pauseIcon;
IconData get mediaControlQuickPlayIcon => _shuffleIcon;
IconData get mediaControlVoiceIcon => _voiceIcon;

IconData mediaControlPlaybackModeIcon(PlaybackMode mode) {
  return _playbackModeIcon(mode);
}

IconData mediaControlFavoriteIcon(bool favorite) {
  return favorite ? _favoriteFilledIcon : _favoriteOutlineIcon;
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
  late var _liveValue = clampVolumeValue(widget.value).toDouble();
  late var _lastEmittedValue = clampVolumeValue(widget.value);
  Timer? _tooltipTimer;
  var _tooltipActive = false;
  var _dragging = false;

  @override
  void initState() {
    super.initState();
    if (widget.showTooltipOnMount && !widget.disabled) {
      _tooltipActive = true;
      _tooltipTimer = Timer(const Duration(milliseconds: 900), () {
        if (mounted && !_dragging) {
          setState(() {
            _tooltipActive = false;
          });
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
    }
  }

  @override
  void dispose() {
    _tooltipTimer?.cancel();
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

    return SizedBox(
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
                _VolumeSliderTooltip(
                  value: value.round(),
                  orientation: widget.orientation,
                  sliderSize: constraints.biggest,
                  verticalTrackLength: widget.verticalTrackLength,
                  overlayRadius: widget.overlayRadius,
                  verticalTooltipSide: widget.verticalTooltipSide,
                  backgroundColor:
                      widget.tooltipBackgroundColor ??
                      MediaControlThemeColors.of(
                        context,
                      ).volumeTooltipBackground,
                  foregroundColor:
                      widget.tooltipForegroundColor ??
                      MediaControlThemeColors.of(
                        context,
                      ).volumeTooltipForeground,
                  borderColor:
                      widget.tooltipBorderColor ??
                      MediaControlThemeColors.of(context).volumeTooltipBorder,
                  shadow:
                      widget.tooltipShadow ??
                      MediaControlThemeColors.of(context).volumeTooltipShadow,
                ),
            ],
          );
        },
      ),
    );
  }

  void _handleSliderChanged(double value) {
    final nextValue = clampVolumeValue(value);
    setState(() {
      _liveValue = nextValue.toDouble();
    });
    if (_lastEmittedValue == nextValue) {
      return;
    }
    _lastEmittedValue = nextValue;
    widget.onChange(nextValue);
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
    if (!persistent) {
      _tooltipTimer = Timer(duration, () {
        if (mounted && !_dragging) {
          setState(() {
            _tooltipActive = false;
          });
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

  @override
  Widget build(BuildContext context) {
    final tooltip = DecoratedBox(
      key: const ValueKey('VolumeSlider.Tooltip'),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor),
        boxShadow: [shadow],
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 38),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: foregroundColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        ),
      ),
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
      final tooltipWithArrow = Stack(
        clipBehavior: Clip.none,
        children: [
          tooltip,
          Positioned(
            right: -5,
            top: 0,
            bottom: 0,
            child: Center(
              child: _VolumeSliderTooltipArrow(
                backgroundColor: backgroundColor,
                borderColor: borderColor,
                border: const _VolumeSliderTooltipArrowBorder.topRight(),
              ),
            ),
          ),
        ],
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
          child: tooltipWithArrow,
        ),
      );
    }
    final centerX = _volumeSliderHorizontalThumbCenterX(
      value,
      sliderSize.width,
      overlayRadius,
    );
    final tooltipWithArrow = Stack(
      clipBehavior: Clip.none,
      children: [
        tooltip,
        Positioned(
          left: 0,
          right: 0,
          bottom: -4,
          child: Center(
            child: _VolumeSliderTooltipArrow(
              backgroundColor: backgroundColor,
              borderColor: borderColor,
              border: const _VolumeSliderTooltipArrowBorder.bottomRight(),
            ),
          ),
        ),
      ],
    );
    return Positioned(
      key: const ValueKey('VolumeSlider.TooltipPosition'),
      left: centerX,
      bottom: sliderSize.height + _volumeSliderTooltipGap,
      child: FractionalTranslation(
        translation: const Offset(-0.5, 0),
        child: tooltipWithArrow,
      ),
    );
  }
}

class _VolumeSliderTooltipArrow extends StatelessWidget {
  const _VolumeSliderTooltipArrow({
    required this.backgroundColor,
    required this.borderColor,
    required this.border,
  });

  final Color backgroundColor;
  final Color borderColor;
  final _VolumeSliderTooltipArrowBorder border;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: pi / 4,
      child: DecoratedBox(
        key: const ValueKey('VolumeSlider.TooltipArrow'),
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border(
            top: border.top ? BorderSide(color: borderColor) : BorderSide.none,
            right:
                border.right ? BorderSide(color: borderColor) : BorderSide.none,
            bottom:
                border.bottom
                    ? BorderSide(color: borderColor)
                    : BorderSide.none,
            left:
                border.left ? BorderSide(color: borderColor) : BorderSide.none,
          ),
        ),
        child: const SizedBox(width: 7, height: 7),
      ),
    );
  }
}

class _VolumeSliderTooltipArrowBorder {
  const _VolumeSliderTooltipArrowBorder.bottomRight()
    : top = false,
      right = true,
      bottom = true,
      left = false;

  const _VolumeSliderTooltipArrowBorder.topRight()
    : top = true,
      right = true,
      bottom = false,
      left = false;

  final bool top;
  final bool right;
  final bool bottom;
  final bool left;
}

double _volumeSliderHorizontalThumbCenterX(
  int value,
  double width,
  double overlayRadius,
) {
  final trackWidth = max(0.0, width - (overlayRadius * 2));
  return overlayRadius + trackWidth * (clampVolumeValue(value) / 100);
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
