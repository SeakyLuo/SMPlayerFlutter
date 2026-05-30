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

class SmPlayerPauseIcon extends StatelessWidget {
  const SmPlayerPauseIcon({super.key, this.size = 21, this.color});

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
      child: CustomPaint(painter: _SmPlayerPauseIconPainter(resolvedColor)),
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

class SmPlayerPlayNextIcon extends StatelessWidget {
  const SmPlayerPlayNextIcon({super.key, this.size = 21, this.color});

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
      child: CustomPaint(painter: _SmPlayerPlayNextIconPainter(resolvedColor)),
    );
  }
}

class SmPlayerMoreHorizontalIcon extends StatelessWidget {
  const SmPlayerMoreHorizontalIcon({super.key, this.size = 21, this.color});

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
      child: CustomPaint(
        painter: _SmPlayerMoreHorizontalIconPainter(resolvedColor),
      ),
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

class _SmPlayerPauseIconPainter extends CustomPainter {
  const _SmPlayerPauseIconPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 20;
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.fill;
    final path =
        Path()
          ..fillType = PathFillType.evenOdd
          ..addRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(3 * scale, 2 * scale, 6 * scale, 16 * scale),
              Radius.circular(2 * scale),
            ),
          )
          ..addRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(4 * scale, 3 * scale, 4 * scale, 14 * scale),
              Radius.circular(1 * scale),
            ),
          )
          ..addRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(11 * scale, 2 * scale, 6 * scale, 16 * scale),
              Radius.circular(2 * scale),
            ),
          )
          ..addRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(12 * scale, 3 * scale, 4 * scale, 14 * scale),
              Radius.circular(1 * scale),
            ),
          );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SmPlayerPauseIconPainter oldDelegate) {
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

class _SmPlayerPlayNextIconPainter extends CustomPainter {
  const _SmPlayerPlayNextIconPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 24;
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.35 * scale
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

    canvas.drawLine(
      Offset(6 * scale, 5.5 * scale),
      Offset(18 * scale, 5.5 * scale),
      paint,
    );
    canvas.drawLine(
      Offset(12 * scale, 18.5 * scale),
      Offset(12 * scale, 8.5 * scale),
      paint,
    );
    final head =
        Path()
          ..moveTo(7.8 * scale, 12.6 * scale)
          ..lineTo(12 * scale, 8.4 * scale)
          ..lineTo(16.2 * scale, 12.6 * scale);
    canvas.drawPath(head, paint);
  }

  @override
  bool shouldRepaint(covariant _SmPlayerPlayNextIconPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _SmPlayerMoreHorizontalIconPainter extends CustomPainter {
  const _SmPlayerMoreHorizontalIconPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 24;
    final fillPaint =
        Paint()
          ..color = color
          ..style = PaintingStyle.fill;
    for (final x in [5, 12.0, 19.0]) {
      canvas.drawCircle(Offset(x * scale, 12 * scale), 1.45 * scale, fillPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SmPlayerMoreHorizontalIconPainter oldDelegate) {
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
