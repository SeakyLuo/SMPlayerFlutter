import 'package:flutter/material.dart';

class VoiceAssistantStartupPulse extends StatefulWidget {
  const VoiceAssistantStartupPulse({super.key, required this.accent});

  final Color accent;

  @override
  State<VoiceAssistantStartupPulse> createState() => _StartupPulseState();
}

class _StartupPulseState extends State<VoiceAssistantStartupPulse>
    with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
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
        painter: _StartupPulsePainter(_animation, widget.accent),
      ),
    ),
  );
}

class _StartupPulsePainter extends CustomPainter {
  _StartupPulsePainter(this.animation, this.accent) : super(repaint: animation);

  final Animation<double> animation;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final x = -32 + (size.width + 64) * animation.value;
    final path =
        Path()
          ..moveTo(x - 30, y)
          ..lineTo(x - 18, y)
          ..lineTo(x - 13, y - 3)
          ..lineTo(x - 8, y + 3)
          ..lineTo(x - 3, y - 10)
          ..lineTo(x + 2, y + 9)
          ..lineTo(x + 7, y - 4)
          ..lineTo(x + 13, y)
          ..lineTo(x + 30, y);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawLine(
      Offset(0, y),
      Offset(size.width, y),
      Paint()
        ..color = accent.withValues(alpha: .22)
        ..strokeWidth = 1,
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = accent.withValues(alpha: .45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = accent,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StartupPulsePainter oldDelegate) =>
      oldDelegate.animation != animation || oldDelegate.accent != accent;
}
