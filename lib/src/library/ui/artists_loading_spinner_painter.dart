part of 'artists_page.dart';

class _ArtistsLoadingSpinnerPainter extends CustomPainter {
  const _ArtistsLoadingSpinnerPainter({
    required this.trackColor,
    required this.topColor,
    required this.strokeWidth,
  });

  final Color trackColor;
  final Color topColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (min(size.width, size.height) - strokeWidth) / 2;
    final trackPaint =
        Paint()
          ..color = trackColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);
    final topPaint =
        Paint()
          ..color = topColor
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.butt
          ..strokeWidth = strokeWidth;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      pi / 2,
      false,
      topPaint,
    );
  }

  @override
  bool shouldRepaint(_ArtistsLoadingSpinnerPainter oldDelegate) {
    return oldDelegate.trackColor != trackColor ||
        oldDelegate.topColor != topColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
