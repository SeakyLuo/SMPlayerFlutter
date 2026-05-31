import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

const smPlayerPlayingWaveSaturate150 = ColorFilter.matrix([
  1.3935,
  -0.3575,
  -0.036,
  0,
  0,
  -0.1065,
  1.1425,
  -0.036,
  0,
  0,
  -0.1065,
  -0.3575,
  1.464,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
]);

class SmPlayerPlayingWaveGlass extends StatelessWidget {
  const SmPlayerPlayingWaveGlass({
    super.key,
    required this.playing,
    this.dimension = 34,
    this.backgroundColor = const Color(0xb81e2228),
    this.shadowColor = const Color(0x470e1620),
    this.keyPrefix = 'PlayingWave',
  });

  final bool playing;
  final double dimension;
  final Color backgroundColor;
  final Color shadowColor;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipOval(
          child: GlassContainer(
            key: ValueKey('$keyPrefix.Backdrop'),
            width: dimension,
            height: dimension,
            useOwnLayer: true,
            quality: GlassQuality.standard,
            shape: const LiquidOval(),
            settings: LiquidGlassSettings(
              glassColor: backgroundColor,
              thickness: 34,
              blur: 12,
              chromaticAberration: 0.012,
              lightIntensity: 0.42,
              ambientStrength: 0.08,
              refractiveIndex: 1.16,
              saturation: 1.12,
              glowIntensity: 0.28,
              standardOpacityMultiplier: 1.1,
            ),
            clipBehavior: Clip.hardEdge,
            allowElevation: false,
            child: ColorFiltered(
              key: ValueKey('$keyPrefix.Saturate150'),
              colorFilter: smPlayerPlayingWaveSaturate150,
              child: SizedBox.square(
                dimension: dimension,
                child: SmPlayerPlayingWaveBars(
                  keyPrefix: keyPrefix,
                  playing: playing,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SmPlayerPlayingWaveBars extends StatefulWidget {
  const SmPlayerPlayingWaveBars({
    super.key,
    required this.playing,
    this.color = Colors.white,
    this.keyPrefix = 'PlayingWave',
  });

  final bool playing;
  final Color color;
  final String keyPrefix;

  @override
  State<SmPlayerPlayingWaveBars> createState() =>
      _SmPlayerPlayingWaveBarsState();
}

class _SmPlayerPlayingWaveBarsState extends State<SmPlayerPlayingWaveBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const _staticHeights = [7.0, 12.0, 15.0, 9.0];
  static const _delays = [0.0, 120 / 780, 240 / 780, 360 / 780];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 780),
    );
    if (widget.playing) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(SmPlayerPlayingWaveBars oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.playing == oldWidget.playing) {
      return;
    }
    if (widget.playing) {
      _controller.repeat();
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      key: ValueKey('${widget.keyPrefix}.Wave'),
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < _staticHeights.length; index += 1)
              _PlayingWaveBar(
                key: ValueKey('${widget.keyPrefix}.Bar.$index'),
                color: widget.color,
                height:
                    widget.playing
                        ? _animatedHeight(_controller.value, _delays[index])
                        : _staticHeights[index],
              ),
          ],
        );
      },
    );
  }

  static double _animatedHeight(double progress, double delay) {
    final shifted = (progress - delay) % 1;
    final triangle = shifted <= 0.5 ? shifted * 2 : (1 - shifted) * 2;
    final eased = Curves.easeInOut.transform(triangle);
    return 5 + eased * 10;
  }
}

class _PlayingWaveBar extends StatelessWidget {
  const _PlayingWaveBar({super.key, required this.color, required this.height});

  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 2,
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}
