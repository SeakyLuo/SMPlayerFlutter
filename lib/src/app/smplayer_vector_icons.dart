import 'package:flutter/material.dart';

class SmPlayerPlayIcon extends StatelessWidget {
  const SmPlayerPlayIcon({super.key, this.size = 21, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final resolvedColor =
        color ??
        IconTheme.of(context).color ??
        DefaultTextStyle.of(context).style.color!;
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _SmPlayerPlayIconPainter(resolvedColor)),
    );
  }
}

class SmPlayerAlbumIcon extends StatelessWidget {
  const SmPlayerAlbumIcon({super.key, this.size = 21, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final resolvedColor =
        color ??
        IconTheme.of(context).color ??
        DefaultTextStyle.of(context).style.color!;
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _SmPlayerAlbumIconPainter(resolvedColor)),
    );
  }
}

class SmPlayerPlaylistIcon extends StatelessWidget {
  const SmPlayerPlaylistIcon({super.key, this.size = 21, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final resolvedColor =
        color ??
        IconTheme.of(context).color ??
        DefaultTextStyle.of(context).style.color!;
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _SmPlayerPlaylistIconPainter(resolvedColor)),
    );
  }
}

class _SmPlayerPlayIconPainter extends CustomPainter {
  const _SmPlayerPlayIconPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 24;
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3 * scale
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
    final path = _roundedTransportPolygon([
      Offset(7.4 * scale, 3.9 * scale),
      Offset(21.0 * scale, 12 * scale),
      Offset(7.4 * scale, 20.1 * scale),
    ], 1.8 * scale);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SmPlayerPlayIconPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _SmPlayerAlbumIconPainter extends CustomPainter {
  const _SmPlayerAlbumIconPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 24;
    final center = Offset(size.width / 2, size.height / 2);
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.65 * scale;
    canvas.drawCircle(center, 8 * scale, paint);
    canvas.drawCircle(center, 3 * scale, paint);
    canvas.drawCircle(
      center,
      1 * scale,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _SmPlayerAlbumIconPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _SmPlayerPlaylistIconPainter extends CustomPainter {
  const _SmPlayerPlaylistIconPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 24;
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.65 * scale
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

    canvas.drawLine(
      Offset(4 * scale, 6 * scale),
      Offset(14 * scale, 6 * scale),
      paint,
    );
    canvas.drawLine(
      Offset(4 * scale, 12 * scale),
      Offset(13 * scale, 12 * scale),
      paint,
    );
    canvas.drawLine(
      Offset(4 * scale, 18 * scale),
      Offset(10 * scale, 18 * scale),
      paint,
    );
    canvas.drawLine(
      Offset(17 * scale, 8 * scale),
      Offset(17 * scale, 17 * scale),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(17 * scale, 8 * scale)
        ..quadraticBezierTo(20.5 * scale, 9 * scale, 21 * scale, 6.5 * scale),
      paint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(15.4 * scale, 18.1 * scale),
        width: 5.1 * scale,
        height: 4.1 * scale,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _SmPlayerPlaylistIconPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

Path _roundedTransportPolygon(List<Offset> points, double radius) {
  final path = Path();
  for (var index = 0; index < points.length; index += 1) {
    final previous = points[(index - 1 + points.length) % points.length];
    final current = points[index];
    final next = points[(index + 1) % points.length];
    final incoming = previous - current;
    final outgoing = next - current;
    final incomingLength = incoming.distance;
    final outgoingLength = outgoing.distance;
    final shortestCorner =
        incomingLength < outgoingLength
            ? incomingLength / 2
            : outgoingLength / 2;
    final cornerRadius =
        (radius < shortestCorner ? radius : shortestCorner).toDouble();
    final start = current + incoming / incomingLength * cornerRadius;
    final end = current + outgoing / outgoingLength * cornerRadius;
    if (index == 0) {
      path.moveTo(start.dx, start.dy);
    } else {
      path.lineTo(start.dx, start.dy);
    }
    path.quadraticBezierTo(current.dx, current.dy, end.dx, end.dy);
  }
  return path..close();
}
