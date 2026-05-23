part of 'media_control.dart';

enum VolumeSliderOrientation { horizontal, vertical }

int clampVolumeValue(num value) => value.round().clamp(0, 100);

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
const IconData _playIcon = IconData(0xed79, fontFamily: 'FluentSystemIcons');
const IconData _pauseIcon = IconData(0xec59, fontFamily: 'FluentSystemIcons');
const IconData _nextIcon = FluentIcons.next_20_regular;
const IconData _shuffleIcon = FluentIcons.arrow_shuffle_20_regular;
const IconData _repeatIcon = FluentIcons.arrow_repeat_all_20_regular;
const IconData _repeatOneIcon = FluentIcons.arrow_repeat_1_20_regular;
const IconData _listPlaybackIcon = FluentIcons.music_note_2_24_regular;
const IconData _moreIcon = FluentIcons.more_horizontal_20_regular;

class VolumeSlider extends StatefulWidget {
  const VolumeSlider({
    super.key,
    required this.value,
    required this.disabled,
    required this.onChange,
    this.orientation = VolumeSliderOrientation.horizontal,
    this.showTooltipOnMount = false,
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
        trackHeight: 2,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
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
      height: widget.orientation == VolumeSliderOrientation.vertical ? 156 : 44,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          if (widget.orientation == VolumeSliderOrientation.vertical)
            RotatedBox(
              quarterTurns: -1,
              child: SizedBox(width: 132, child: slider),
            )
          else
            slider,
          if (_tooltipActive && !widget.disabled)
            _VolumeSliderTooltip(
              value: value.round(),
              orientation: widget.orientation,
              backgroundColor: widget.tooltipBackgroundColor,
              foregroundColor: widget.tooltipForegroundColor,
            ),
        ],
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
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final int value;
  final VolumeSliderOrientation orientation;
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
      return Positioned(right: -4, top: 8, child: tooltip);
    }
    return Positioned(top: -4, child: tooltip);
  }
}
