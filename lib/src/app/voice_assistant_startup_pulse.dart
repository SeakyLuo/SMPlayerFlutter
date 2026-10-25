import 'dart:math' as math;

import 'package:flutter/material.dart';

class VoiceAssistantStartupPulse extends StatefulWidget {
  const VoiceAssistantStartupPulse({
    super.key,
    required this.accent,
    required this.quietWidth,
  });

  final Color accent;
  final double quietWidth;

  @override
  State<VoiceAssistantStartupPulse> createState() => _StartupPulseState();
}

class _StartupPulseState extends State<VoiceAssistantStartupPulse>
    with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _animation.stop();
      _animation.value = .5;
    } else {
      _animation.repeat();
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: RepaintBoundary(
      child: CustomPaint(
        painter: _StartupPulsePainter(
          _animation,
          widget.accent,
          widget.quietWidth,
        ),
      ),
    ),
  );
}

class _StartupPulsePainter extends CustomPainter {
  _StartupPulsePainter(this.animation, this.accent, this.quietWidth)
    : super(repaint: animation);

  final Animation<double> animation;
  final Color accent;
  final double quietWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final phase = animation.value * math.pi * 2;
    final amplitude = size.height * .58;
    final path = Path()..moveTo(0, y);
    // Fixed wave positions breathe vertically across the entire surface.
    final samples = (size.width * 4).ceil();
    for (var i = 1; i <= samples; i++) {
      final position = i / samples;
      final x = position * size.width;
      final edge = math.pow(math.sin(position * math.pi), .65);
      final body =
          .28 +
          .42 * math.exp(-math.pow((position - .27) / .14, 2)) +
          .3 * math.exp(-math.pow((position - .72) / .17, 2));
      final activity =
          .62 +
          .22 * math.sin(phase + position * 19) +
          .16 * math.sin(phase * 2 - position * 31);
      final texture = .68 + .2 * math.sin(x * .43) + .12 * math.sin(x * 1.17);
      final carrier =
          (math.sin(x * 2.8) +
              .45 * math.sin(x * 5.3 + .7) +
              .18 * math.sin(x * 8.7)) /
          1.3;
      path.lineTo(
        x,
        y + carrier * amplitude * edge * body * activity * texture,
      );
    }
    final gapEdge = (1 - math.min(quietWidth / size.width, .75)) / 2;
    final shader = LinearGradient(
      colors: [
        accent.withValues(alpha: 0),
        accent.withValues(alpha: .34),
        accent.withValues(alpha: .34),
        accent.withValues(alpha: 0),
        accent.withValues(alpha: 0),
        accent.withValues(alpha: .34),
        accent.withValues(alpha: .34),
        accent.withValues(alpha: 0),
      ],
      stops: [
        0,
        gapEdge * .3,
        gapEdge * .85,
        gapEdge,
        1 - gapEdge,
        1 - gapEdge * .85,
        1 - gapEdge * .3,
        1,
      ],
    ).createShader(Offset.zero & size);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..shader = shader
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .75
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..shader = shader,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StartupPulsePainter oldDelegate) =>
      oldDelegate.animation != animation ||
      oldDelegate.accent != accent ||
      oldDelegate.quietWidth != quietWidth;
}
