part of 'media_control.dart';

@visibleForTesting
const mediaProgressLoadingSegmentWidthFactor = 0.35;

@visibleForTesting
const mediaProgressLoadingTravelWidthFactor =
    mediaProgressLoadingSegmentWidthFactor * 3.85;

@visibleForTesting
const mediaSliderDisabledInputOpacity = 0.65;

@visibleForTesting
const mediaSliderDisabledThumbOpacity = 0.8;

class _MediaProgressSlider extends StatelessWidget {
  const _MediaProgressSlider({
    required this.value,
    required this.max,
    required this.disabled,
    required this.onChanged,
    required this.onChangeStart,
    required this.onChangeEnd,
    this.activeTrackColor,
    this.inactiveTrackColor,
    this.thumbColor,
    this.thumbShadow,
    this.overlayColor,
  });

  final double value;
  final double max;
  final bool disabled;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeStart;
  final ValueChanged<double> onChangeEnd;
  final Color? activeTrackColor;
  final Color? inactiveTrackColor;
  final Color? thumbColor;
  final BoxShadow? thumbShadow;
  final Color? overlayColor;

  @override
  Widget build(BuildContext context) {
    final activeTrackColor = this.activeTrackColor ?? MediaControlColors.accent;
    final inactiveTrackColor =
        this.inactiveTrackColor ??
        MediaControlColors.sliderInactiveFor(context);
    final thumbColor = this.thumbColor ?? MediaControlColors.accent;
    final overlayColor = this.overlayColor ?? MediaControlColors.accentHover;
    final disabledActiveTrackColor = activeTrackColor.withValues(
      alpha: activeTrackColor.a * mediaSliderDisabledInputOpacity,
    );
    final disabledInactiveTrackColor = inactiveTrackColor.withValues(
      alpha: inactiveTrackColor.a * mediaSliderDisabledInputOpacity,
    );
    final disabledThumbColor = thumbColor.withValues(
      alpha:
          thumbColor.a *
          mediaSliderDisabledInputOpacity *
          mediaSliderDisabledThumbOpacity,
    );
    final slider = SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: _mediaSliderTrackHeight,
        trackShape: const _MediaProgressTrackShape(),
        thumbShape: _mediaSliderThumbShape(
          radius: _mediaSliderThumbRadius,
          shadow: thumbShadow,
        ),
        overlayShape: const RoundSliderOverlayShape(
          overlayRadius: _mediaSliderOverlayRadius,
        ),
        activeTrackColor: activeTrackColor,
        inactiveTrackColor: inactiveTrackColor,
        thumbColor: thumbColor,
        disabledActiveTrackColor: disabledActiveTrackColor,
        disabledInactiveTrackColor: disabledInactiveTrackColor,
        disabledThumbColor: disabledThumbColor,
        overlayColor: overlayColor,
      ),
      child: Slider(
        key: const ValueKey('MediaControl.ProgressSlider'),
        value: max > 0 ? value.clamp(0, max).toDouble() : 0,
        min: 0,
        max: max > 0 ? max : 1,
        onChanged: disabled ? null : onChanged,
        onChangeStart: disabled ? null : onChangeStart,
        onChangeEnd: disabled ? null : onChangeEnd,
      ),
    );
    return Center(
      child: SizedBox(
        height: _mediaSliderInputHeight,
        child: Semantics(
          label: _mediaControlI18n(context).t('player.trackProgress'),
          value: formatDuration(max > 0 ? value.clamp(0, max).toDouble() : 0),
          child: slider,
        ),
      ),
    );
  }
}

class _MediaProgressTrackShape extends RoundedRectSliderTrackShape {
  const _MediaProgressTrackShape();

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final trackHeight = sliderTheme.trackHeight ?? _mediaSliderTrackHeight;
    final trackLeft = offset.dx;
    final trackTop = offset.dy + (parentBox.size.height - trackHeight) / 2;
    return Rect.fromLTWH(
      trackLeft,
      trackTop,
      parentBox.size.width,
      trackHeight,
    );
  }
}

class _MediaProgressLoading extends StatefulWidget {
  const _MediaProgressLoading();

  @override
  State<_MediaProgressLoading> createState() => _MediaProgressLoadingState();
}

class _MediaProgressLoadingState extends State<_MediaProgressLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _loadingAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _loadingAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _loadingAnimation.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inactiveTrackColor = MediaControlColors.sliderInactiveFor(context);
    return SizedBox(
      key: const ValueKey('MediaControl.ProgressLoading'),
      height: 18,
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            key: const ValueKey('MediaControl.ProgressLoadingTrack'),
            height: _mediaSliderTrackHeight,
            child: DecoratedBox(
              decoration: BoxDecoration(color: inactiveTrackColor),
              child: AnimatedBuilder(
                key: const ValueKey('MediaControl.ProgressLoadingAnimation'),
                animation: _loadingAnimation,
                builder: (context, _) {
                  return FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: 1,
                    child: CustomPaint(
                      painter: _MediaProgressLoadingPainter(
                        _loadingAnimation.value,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MediaProgressLoadingPainter extends CustomPainter {
  const _MediaProgressLoadingPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = MediaControlColors.accent;
    final segmentWidth = size.width * mediaProgressLoadingSegmentWidthFactor;
    final left =
        -segmentWidth +
        progress * (size.width * mediaProgressLoadingTravelWidthFactor);
    canvas.drawRect(Rect.fromLTWH(left, 0, segmentWidth, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant _MediaProgressLoadingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
