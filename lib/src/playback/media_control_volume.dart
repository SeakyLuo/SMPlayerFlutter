part of 'media_control.dart';

enum VolumeSliderOrientation { horizontal, vertical }

enum VolumeSliderVerticalTooltipSide { left, right }

int clampVolumeValue(num value) => value.round().clamp(0, 100);

const double _volumeSliderHorizontalHeight = 44;
const double _volumeSliderVerticalHeight = 156;
const double _volumeSliderVerticalTrackLength = 132;
const double _mediaSliderTrackHeight = 2;
const double _mediaSliderThumbRadius = 8;
const double _mediaSliderOverlayRadius = 10;
const double _volumeSliderTooltipHorizontalTop = -18;
const double _volumeSliderTooltipGap = 8;

IconData playerVolumeIcon(int volume, bool isMuted) {
  if (isMuted) {
    return FluentIcons.speaker_mute_20_regular;
  }
  if (volume <= 0) {
    return FluentIcons.speaker_off_20_regular;
  }
  if (volume < 34) {
    return FluentIcons.speaker_1_20_regular;
  }
  if (volume < 67) {
    return FluentIcons.speaker_1_20_regular;
  }
  return FluentIcons.speaker_2_20_regular;
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

class VolumeSlider extends StatefulWidget {
  const VolumeSlider({
    super.key,
    required this.value,
    required this.disabled,
    required this.onChange,
    this.orientation = VolumeSliderOrientation.horizontal,
    this.showTooltipOnMount = false,
    this.verticalHeight = _volumeSliderVerticalHeight,
    this.verticalTrackLength = _volumeSliderVerticalTrackLength,
    this.trackHeight = _mediaSliderTrackHeight,
    this.thumbRadius = _mediaSliderThumbRadius,
    this.overlayRadius = _mediaSliderOverlayRadius,
    this.verticalTooltipSide = VolumeSliderVerticalTooltipSide.right,
    this.activeTrackColor = MediaControlColors.accent,
    this.inactiveTrackColor = MediaControlColors.sliderInactive,
    this.thumbColor = MediaControlColors.accent,
    this.overlayColor = MediaControlColors.accentHover,
    this.tooltipBackgroundColor = const Color(0xe60d1726),
    this.tooltipForegroundColor = Colors.white,
  });

  final int value;
  final bool disabled;
  final ValueChanged<int> onChange;
  final VolumeSliderOrientation orientation;
  final bool showTooltipOnMount;
  final double verticalHeight;
  final double verticalTrackLength;
  final double trackHeight;
  final double thumbRadius;
  final double overlayRadius;
  final VolumeSliderVerticalTooltipSide verticalTooltipSide;
  final Color activeTrackColor;
  final Color inactiveTrackColor;
  final Color thumbColor;
  final Color overlayColor;
  final Color tooltipBackgroundColor;
  final Color tooltipForegroundColor;

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
        thumbShape: RoundSliderThumbShape(
          enabledThumbRadius: widget.thumbRadius,
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
          if (focused) {
            _showTooltip();
          } else if (!_dragging) {
            _hideTooltip();
          }
        },
        child: MouseRegion(
          onEnter: (_) => _showTooltip(persistent: true),
          onExit: (_) {
            if (!_dragging) {
              _hideTooltip();
            }
          },
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
                      _showTooltip();
                    },
            onChanged: widget.disabled ? null : _handleSliderChanged,
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
                  backgroundColor: widget.tooltipBackgroundColor,
                  foregroundColor: widget.tooltipForegroundColor,
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

  void _showTooltip({bool persistent = false}) {
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
      _tooltipTimer = Timer(const Duration(milliseconds: 900), () {
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
  });

  final int value;
  final VolumeSliderOrientation orientation;
  final Size sliderSize;
  final double verticalTrackLength;
  final double overlayRadius;
  final VolumeSliderVerticalTooltipSide verticalTooltipSide;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    final tooltip = DecoratedBox(
      key: const ValueKey('VolumeSlider.Tooltip'),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: const Color(0x33ffffff)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          '$value',
          style: TextStyle(
            color: foregroundColor,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            height: 1.2,
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
      overlayRadius,
    );
    return Positioned(
      key: const ValueKey('VolumeSlider.TooltipPosition'),
      left: centerX,
      top: _volumeSliderTooltipHorizontalTop,
      child: FractionalTranslation(
        translation: const Offset(-0.5, 0),
        child: tooltip,
      ),
    );
  }
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
