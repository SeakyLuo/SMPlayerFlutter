part of 'media_control.dart';

class _MediaProgressSlider extends StatelessWidget {
  const _MediaProgressSlider({
    required this.value,
    required this.max,
    required this.disabled,
    required this.onChanged,
    required this.onChangeStart,
    required this.onChangeEnd,
  });

  final double value;
  final double max;
  final bool disabled;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeStart;
  final ValueChanged<double> onChangeEnd;

  @override
  Widget build(BuildContext context) {
    final inactiveTrackColor = MediaControlColors.sliderInactiveFor(context);
    final disabledThumbColor = MediaControlColors.accent.withValues(alpha: 0.8);
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 2,
        trackShape: const _MediaProgressTrackShape(),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
        activeTrackColor: MediaControlColors.accent,
        inactiveTrackColor: inactiveTrackColor,
        thumbColor: MediaControlColors.accent,
        disabledActiveTrackColor: MediaControlColors.accent.withValues(
          alpha: 0.92,
        ),
        disabledInactiveTrackColor: inactiveTrackColor,
        disabledThumbColor: disabledThumbColor,
        overlayColor: MediaControlColors.accentHover,
      ),
      child: Slider(
        value: max > 0 ? value.clamp(0, max).toDouble() : 0,
        min: 0,
        max: max > 0 ? max : 1,
        onChanged: disabled ? null : onChanged,
        onChangeStart: disabled ? null : onChangeStart,
        onChangeEnd: disabled ? null : onChangeEnd,
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
    final trackHeight = sliderTheme.trackHeight ?? 2;
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

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
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
            height: 2,
            child: DecoratedBox(
              decoration: BoxDecoration(color: inactiveTrackColor),
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  return FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: 1,
                    child: CustomPaint(
                      painter: _MediaProgressLoadingPainter(_controller.value),
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
    final segmentWidth = size.width * 0.35;
    final left = -segmentWidth + progress * (size.width + segmentWidth * 2);
    canvas.drawRect(Rect.fromLTWH(left, 0, segmentWidth, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant _MediaProgressLoadingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
