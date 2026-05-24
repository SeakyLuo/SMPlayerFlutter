import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';

bool isMultiSelectIcon(IconData icon) {
  return icon == FluentIcons.multiselect_ltr_20_regular ||
      icon == FluentIcons.multiselect_ltr_24_regular;
}

class UniformMultiSelectIcon extends StatelessWidget {
  const UniformMultiSelectIcon({
    super.key,
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _UniformMultiSelectIconPainter(color)),
    );
  }
}

class _UniformMultiSelectIconPainter extends CustomPainter {
  const _UniformMultiSelectIconPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 20;
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.7 * scale
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

    void drawCheck(double y) {
      final path =
          Path()
            ..moveTo(3.0 * scale, y + 1.3 * scale)
            ..lineTo(4.6 * scale, y + 2.9 * scale)
            ..lineTo(7.4 * scale, y - 0.8 * scale);
      canvas.drawPath(path, paint);
    }

    drawCheck(4.5 * scale);
    drawCheck(13.2 * scale);

    canvas.drawLine(
      Offset(10.0 * scale, 5.8 * scale),
      Offset(17.2 * scale, 5.8 * scale),
      paint,
    );
    canvas.drawLine(
      Offset(10.0 * scale, 14.5 * scale),
      Offset(17.2 * scale, 14.5 * scale),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _UniformMultiSelectIconPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
