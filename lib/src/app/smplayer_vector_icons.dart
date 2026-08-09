import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import 'svg_icon.dart';

class SmPlayerFavoriteIcon extends StatefulWidget {
  static const activeColor = Color(0xffff1d1d);

  const SmPlayerFavoriteIcon({
    super.key,
    required this.favorite,
    this.size = 20,
    this.color,
    this.pulseColor,
    this.animate = true,
  });

  final bool favorite;
  final double size;
  final Color? color;
  final Color? pulseColor;
  final bool animate;

  @override
  State<SmPlayerFavoriteIcon> createState() => _SmPlayerFavoriteIconState();
}

class _SmPlayerFavoriteIconState extends State<SmPlayerFavoriteIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool? _displayFavorite;

  bool get _resolvedFavorite => _displayFavorite ?? widget.favorite;

  @override
  void initState() {
    super.initState();
    _displayFavorite = widget.favorite;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 440),
      value: 1,
    );
  }

  @override
  void didUpdateWidget(covariant SmPlayerFavoriteIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.favorite != widget.favorite) {
      _displayFavorite = widget.favorite;
      if (widget.animate && widget.favorite && !_controller.isAnimating) {
        _controller.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inheritedColor =
        IconTheme.of(context).color ??
        DefaultTextStyle.of(context).style.color!;
    final color =
        _resolvedFavorite
            ? SmPlayerFavoriteIcon.activeColor
            : widget.color ?? inheritedColor;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) {
        if (widget.animate && !_resolvedFavorite) {
          setState(() {
            _displayFavorite = true;
          });
          _controller.forward(from: 0);
        }
      },
      onPointerCancel: (_) {
        if (_resolvedFavorite != widget.favorite) {
          setState(() {
            _displayFavorite = widget.favorite;
          });
          _controller.value = 1;
        }
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final pulseProgress = _controller.value;
          final heartScale = _favoriteJellyScale(pulseProgress);
          return SizedBox.square(
            dimension: widget.size,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                if (widget.animate && pulseProgress < 1)
                  _FavoriteRipple(
                    progress: pulseProgress,
                    color:
                        widget.pulseColor ?? SmPlayerFavoriteIcon.activeColor,
                    size: widget.size,
                  ),
                Transform(
                  alignment: Alignment.center,
                  transform:
                      Matrix4.identity()
                        ..scaleByDouble(heartScale.dx, heartScale.dy, 1, 1),
                  child: child,
                ),
              ],
            ),
          );
        },
        child: AnimatedSwitcher(
          duration:
              widget.animate
                  ? const Duration(milliseconds: 140)
                  : Duration.zero,
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            return FadeTransition(opacity: animation, child: child);
          },
          child: Icon(
            _resolvedFavorite
                ? FluentIcons.heart_20_filled
                : FluentIcons.heart_20_regular,
            key: ValueKey(_resolvedFavorite),
            size: widget.size,
            color: color,
          ),
        ),
      ),
    );
  }
}

class _FavoriteRipple extends StatelessWidget {
  const _FavoriteRipple({
    required this.progress,
    required this.color,
    required this.size,
  });

  final double progress;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        _ring(progress: _interval(progress, 0, 0.72), opacity: 0.36),
        _ring(progress: _interval(progress, 0.2, 1), opacity: 0.22),
      ],
    );
  }

  Widget _ring({required double progress, required double opacity}) {
    final easedProgress = Curves.easeOutCubic.transform(progress);
    final ringOpacity = Curves.easeOutCubic.transform(1 - progress) * opacity;
    return Opacity(
      opacity: ringOpacity,
      child: Transform.scale(
        scale: 0.58 + easedProgress * 1.2,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 1.5),
          ),
          child: SizedBox.square(dimension: size),
        ),
      ),
    );
  }
}

double _interval(double progress, double begin, double end) {
  return ((progress - begin) / (end - begin)).clamp(0, 1);
}

Offset _favoriteJellyScale(double progress) {
  if (progress < 0.16) {
    return _favoriteScaleLerp(
      const Offset(1, 1),
      const Offset(1.08, 0.9),
      progress / 0.16,
    );
  }
  if (progress < 0.46) {
    return _favoriteScaleLerp(
      const Offset(1.08, 0.9),
      const Offset(0.94, 1.16),
      (progress - 0.16) / 0.3,
    );
  }
  if (progress < 0.72) {
    return _favoriteScaleLerp(
      const Offset(0.94, 1.16),
      const Offset(1.06, 0.96),
      (progress - 0.46) / 0.26,
    );
  }
  return _favoriteScaleLerp(
    const Offset(1.06, 0.96),
    const Offset(1, 1),
    (progress - 0.72) / 0.28,
  );
}

Offset _favoriteScaleLerp(Offset begin, Offset end, double progress) {
  return Offset.lerp(begin, end, Curves.easeInOutCubic.transform(progress))!;
}

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
  const SmPlayerPlaylistIcon({
    super.key,
    this.size = 21,
    this.color,
    this.strokeWidth = 1.65,
  });

  final double size;
  final Color? color;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final resolvedColor =
        color ??
        IconTheme.of(context).color ??
        DefaultTextStyle.of(context).style.color!;
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _SmPlayerPlaylistIconPainter(resolvedColor, strokeWidth),
      ),
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

class ShuffleIcon extends StatelessWidget {
  const ShuffleIcon({
    super.key,
    this.size = 14,
    this.color,
    this.strokeWidth = 0.4,
  });

  final double size;
  final Color? color;
  final double strokeWidth;

  static const _path =
      'M874.00259 971.2c-14 0.1-25.5-11.3-25.5-25.3 0-6.7 2.6-13.2 7.4-18l80.7-80.8H821.30259c-103 0-200-61.6-266.2-168.9L366.70259 373.3C309.80259 281.5 228.60259 228.9 144.00259 228.9H25.50259c-14.3-0.2-25.7-12-25.5-26.2 0.1-6.6 2.7-13 7.4-17.7 4.8-4.8 11.3-7.6 18.1-7.5h118.7c103 0 200.1 61.5 266.2 168.7L598.80259 651c56.8 91.9 138 144.6 222.7 144.6h115.1L856.00259 714.8c-10.1-9.9-10.3-26.1-0.5-36.2 9.9-10.1 26.1-10.3 36.2-0.5l0.4 0.4 124.3 124.3c10 10 10 26.1 0.1 36.1l-0.1 0.1-124.2 124.7c-4.8 4.8-11.4 7.5-18.2 7.5zM140.20259 847.1H25.50259c-14.3-0.2-25.7-12-25.5-26.2 0.1-6.6 2.7-13 7.4-17.7 4.8-4.8 11.3-7.6 18.1-7.5H140.00259c84.7 0 165.9-52.7 222.7-144.6l31.3-50.6c4.7-7.6 13-12.3 21.9-12.3 4.7 0 9.4 1.3 13.4 3.9 12.1 7.4 15.8 23.1 8.5 35.2 0 0.1-0.1 0.1-0.1 0.2L406.40259 678c-66.2 107-163.2 168.7-266.2 169.1z m413.9-430.8c-4.7 0-9.3-1.3-13.4-3.8-12.1-7.4-15.8-23.2-8.5-35.2 0-0.1 0.1-0.1 0.1-0.2l19.2-31.2c66.2-107.2 163.3-168.7 266.2-168.7h118.9l-80.7-80.8c-10-10-10-26.1-0.1-36.1l0.1-0.1c9.9-10 26-10.1 36-0.2l0.2 0.2 124.1 124.6c10 10 10.1 26.1 0.2 36.2L892.20259 345.6c-9.8 10.2-26.1 10.5-36.3 0.6-10.2-9.8-10.5-26.1-0.6-36.3l0.6-0.6 80.7-80.8H817.80259c-84.8 0-166 52.6-222.7 144.4l-19.2 31.2c-4.8 7.6-12.9 12.2-21.8 12.2z';

  @override
  Widget build(BuildContext context) {
    final resolvedColor =
        color ??
        IconTheme.of(context).color ??
        DefaultTextStyle.of(context).style.color!;
    final strokeAttr = SvgIcon.strokeAttr(
      strokeWidth: strokeWidth,
      viewBoxSize: 1024,
      renderSize: size,
    );
    final svg =
        '<svg t="1780240213270" class="icon" viewBox="0 0 1024 1024" '
        'version="1.1" xmlns="http://www.w3.org/2000/svg" p-id="41079" '
        'width="200" height="200"><path $strokeAttr d="$_path" '
        'p-id="41080"></path></svg>';
    return SizedBox.square(
      dimension: size,
      child: SvgIcon(svg: svg, size: size, color: resolvedColor),
    );
  }
}

enum SmPlayerVolumeIconKind { muted, off, low, medium, high }

class SmPlayerVolumeIcon extends StatelessWidget {
  const SmPlayerVolumeIcon({
    super.key,
    required this.kind,
    this.size = 21,
    this.color,
  });

  final SmPlayerVolumeIconKind kind;
  final double size;
  final Color? color;

  static const _speakerPath =
      'M4.7 9.4q-.8 0-.8.8v3.6q0 .8.8.8h3.2l4.2 3.7q.9.8.9-.45V6.15q0-1.25-.9-.45L7.9 9.4z';
  static const _wave1Path = 'M15.3 9.55a4.1 4.1 0 0 1 0 4.9';
  static const _wave2Path = 'M17.6 7.55a7 7 0 0 1 0 8.9';
  static const _wave3Path = 'M19.9 5.6a10 10 0 0 1 0 12.8';

  @override
  Widget build(BuildContext context) {
    final resolvedColor =
        color ??
        IconTheme.of(context).color ??
        DefaultTextStyle.of(context).style.color!;
    final strokeAttr = SvgIcon.strokeAttr(
      strokeWidth: 1.3,
      viewBoxSize: 24,
      renderSize: size,
    );
    final paths = switch (kind) {
      SmPlayerVolumeIconKind.muted => [
        _speakerPath,
        'm20 10-4 4',
        'm16 10 4 4',
      ],
      SmPlayerVolumeIconKind.off => [_speakerPath],
      SmPlayerVolumeIconKind.low => [_speakerPath, _wave1Path],
      SmPlayerVolumeIconKind.medium => [_speakerPath, _wave1Path, _wave2Path],
      SmPlayerVolumeIconKind.high => [
        _speakerPath,
        _wave1Path,
        _wave2Path,
        _wave3Path,
      ],
    };
    final svg =
        '<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">'
        '${paths.map((path) => '<path $strokeAttr d="$path" />').join()}'
        '</svg>';
    return SizedBox.square(
      dimension: size,
      child: SvgIcon(svg: svg, size: size, color: resolvedColor),
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
  const _SmPlayerPlaylistIconPainter(this.color, this.strokeWidth);

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 24;
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth * scale
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
    return oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
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
