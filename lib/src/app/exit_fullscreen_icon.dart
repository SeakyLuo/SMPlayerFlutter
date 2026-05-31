import 'package:flutter/material.dart';

class SmPlayerFullscreenIcon extends StatelessWidget {
  const SmPlayerFullscreenIcon({
    super.key,
    this.size = 21,
    this.color,
    this.strokeWidth = 0,
    this.shadows = const [],
  });

  final double size;
  final Color? color;
  final double strokeWidth;
  final List<Shadow> shadows;

  @override
  Widget build(BuildContext context) {
    return _FullscreenIcon(
      mode: _FullscreenIconMode.enter,
      size: size,
      color: color,
      strokeWidth: strokeWidth,
      shadows: shadows,
    );
  }
}

class ExitFullscreenIcon extends StatelessWidget {
  const ExitFullscreenIcon({
    super.key,
    this.size = 21,
    this.color,
    this.strokeWidth = 0,
    this.shadows = const [],
  });

  final double size;
  final Color? color;
  final double strokeWidth;
  final List<Shadow> shadows;

  @override
  Widget build(BuildContext context) {
    return _FullscreenIcon(
      mode: _FullscreenIconMode.exit,
      size: size,
      color: color,
      strokeWidth: strokeWidth,
      shadows: shadows,
    );
  }
}

enum _FullscreenIconMode { enter, exit }

class _FullscreenIcon extends StatelessWidget {
  const _FullscreenIcon({
    required this.mode,
    required this.size,
    required this.color,
    required this.strokeWidth,
    required this.shadows,
  });

  final _FullscreenIconMode mode;
  final double size;
  final Color? color;
  final double strokeWidth;
  final List<Shadow> shadows;

  @override
  Widget build(BuildContext context) {
    final resolvedColor =
        color ??
        IconTheme.of(context).color ??
        DefaultTextStyle.of(context).style.color!;
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _FullscreenIconPainter(
          mode: mode,
          color: resolvedColor,
          strokeWidth: strokeWidth == 0 ? size * 0.083 : strokeWidth,
          shadows: shadows,
        ),
      ),
    );
  }
}

class _FullscreenIconPainter extends CustomPainter {
  const _FullscreenIconPainter({
    required this.mode,
    required this.color,
    required this.strokeWidth,
    required this.shadows,
  });

  final _FullscreenIconMode mode;
  final Color color;
  final double strokeWidth;
  final List<Shadow> shadows;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 24;
    final segments =
        mode == _FullscreenIconMode.enter ? _enterSegments : _exitSegments;
    for (final shadow in shadows) {
      _paintSegments(
        canvas,
        segments,
        scale,
        Paint()
          ..color = shadow.color
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, shadow.blurRadius),
        shadow.offset,
      );
    }
    _paintSegments(
      canvas,
      segments,
      scale,
      Paint()
        ..color = color
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
      Offset.zero,
    );
  }

  void _paintSegments(
    Canvas canvas,
    List<List<Offset>> segments,
    double scale,
    Paint paint,
    Offset offset,
  ) {
    for (final segment in segments) {
      final path = Path();
      final start = segment.first * scale + offset;
      path.moveTo(start.dx, start.dy);
      for (final point in segment.skip(1)) {
        final scaled = point * scale + offset;
        path.lineTo(scaled.dx, scaled.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_FullscreenIconPainter oldDelegate) {
    return oldDelegate.mode != mode ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.shadows != shadows;
  }
}

const _enterSegments = [
  [Offset(9, 5), Offset(5, 5), Offset(5, 9)],
  [Offset(15, 5), Offset(19, 5), Offset(19, 9)],
  [Offset(19, 15), Offset(19, 19), Offset(15, 19)],
  [Offset(5, 15), Offset(5, 19), Offset(9, 19)],
];

const _exitSegments = [
  [Offset(5, 9), Offset(9, 9), Offset(9, 5)],
  [Offset(15, 5), Offset(15, 9), Offset(19, 9)],
  [Offset(19, 15), Offset(15, 15), Offset(15, 19)],
  [Offset(9, 19), Offset(9, 15), Offset(5, 15)],
];
