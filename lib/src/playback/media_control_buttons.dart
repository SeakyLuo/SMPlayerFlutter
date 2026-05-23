part of 'media_control.dart';

class _PlayerIconButton extends StatefulWidget {
  const _PlayerIconButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.onLongPress,
    this.disabled = false,
    this.primary = false,
    this.active = false,
    this.favorite = false,
    this.loading = false,
    this.buttonSize,
    this.padding,
    this.iconSize,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final VoidCallback? onLongPress;
  final bool disabled;
  final bool primary;
  final bool active;
  final bool favorite;
  final bool loading;
  final double? buttonSize;
  final double? padding;
  final double? iconSize;

  @override
  State<_PlayerIconButton> createState() => _PlayerIconButtonState();
}

class _PlayerIconButtonState extends State<_PlayerIconButton> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final size = widget.buttonSize ?? (widget.primary ? 56.0 : 36.0);
    final padding = widget.padding ?? (widget.primary ? 14.0 : 6.0);
    final iconSize = widget.iconSize ?? size - padding * 2;
    final textStrong = MediaControlColors.textStrongFor(context);
    final accentStrong = MediaControlColors.accentStrongFor(context);
    final accentHover = MediaControlColors.accentHoverFor(context);
    final night = MediaControlColors.isNight(context);
    final hovered = !widget.disabled && _hovered;
    final primaryDisabled = widget.primary && widget.disabled;
    final color =
        widget.disabled
            ? widget.primary
                ? night
                    ? Colors.white
                    : Colors.transparent
                : textStrong
            : widget.favorite
            ? MediaControlColors.favorite
            : widget.primary
            ? Colors.white
            : widget.active || hovered
            ? accentStrong
            : textStrong;
    final background =
        widget.disabled
            ? widget.primary
                ? MediaControlColors.disabledPrimaryButtonSurfaceFor(context)
                : MediaControlColors.disabledButtonSurface
            : widget.primary
            ? hovered
                ? accentStrong
                : MediaControlColors.accent
            : widget.active || hovered
            ? accentHover
            : Colors.transparent;
    final border =
        widget.primary
            ? Border.all(
              color:
                  widget.disabled
                      ? MediaControlColors.disabledPrimaryButtonBorderFor(
                        context,
                      )
                      : MediaControlColors.accentBorder,
            )
            : null;
    final shadow =
        widget.primary
            ? widget.disabled
                ? night
                    ? const [
                      BoxShadow(
                        color: MediaControlColors.accentShadow,
                        offset: Offset(0, 12),
                        blurRadius: 24,
                      ),
                    ]
                    : const [
                      BoxShadow(
                        color: MediaControlColors.disabledPrimaryButtonShadow,
                        offset: Offset(0, 8),
                        blurRadius: 18,
                      ),
                    ]
                : const [
                  BoxShadow(
                    color: MediaControlColors.accentShadow,
                    offset: Offset(0, 12),
                    blurRadius: 24,
                  ),
                ]
            : null;

    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor:
            widget.disabled
                ? SystemMouseCursors.forbidden
                : SystemMouseCursors.click,
        onEnter: (_) {
          setState(() {
            _hovered = true;
          });
        },
        onExit: (_) {
          setState(() {
            _hovered = false;
          });
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.disabled ? null : widget.onPressed,
          onLongPress: widget.disabled ? null : widget.onLongPress,
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOut,
            offset: hovered ? Offset(0, -1 / size) : Offset.zero,
            child: Opacity(
              opacity: widget.disabled && (!widget.primary || night) ? 0.65 : 1,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                width: size,
                height: size,
                alignment: Alignment.center,
                padding: EdgeInsets.all(padding),
                decoration: BoxDecoration(
                  color: background,
                  shape: BoxShape.circle,
                  border: border,
                  boxShadow: shadow,
                ),
                child:
                    widget.loading
                        ? const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        )
                        : _PlayerButtonIcon(
                          icon: widget.icon,
                          color: color,
                          size: iconSize,
                          hidden: primaryDisabled && !night,
                        ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayerButtonIcon extends StatelessWidget {
  const _PlayerButtonIcon({
    required this.icon,
    required this.color,
    required this.size,
    required this.hidden,
  });

  final IconData icon;
  final Color color;
  final double size;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    if (hidden) {
      return const SizedBox.expand();
    }
    if (icon == _previousIcon || icon == _nextIcon) {
      return CustomPaint(
        painter: _SkipTransportIconPainter(
          color: color,
          previous: icon == _previousIcon,
        ),
        size: Size.square(size),
      );
    }
    if (icon == _playIcon) {
      return CustomPaint(
        painter: _PlayTransportIconPainter(color),
        size: Size.square(size),
      );
    }
    if (icon == _moreIcon) {
      return CustomPaint(
        painter: _MoreHorizontalIconPainter(color),
        size: Size.square(size),
      );
    }
    final iconWidget = Icon(icon, color: color, size: size);
    return iconWidget;
  }
}

class _MoreHorizontalIconPainter extends CustomPainter {
  const _MoreHorizontalIconPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    final fillPaint =
        Paint()
          ..color = color
          ..style = PaintingStyle.fill;
    for (final x in [7.0, 12.0, 17.0]) {
      canvas.drawCircle(Offset(x * scale, 12 * scale), 1.45 * scale, fillPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _MoreHorizontalIconPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _PlayTransportIconPainter extends CustomPainter {
  const _PlayTransportIconPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 * scale
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
    final points = [
      Offset(6.5 * scale, 5.25 * scale),
      Offset(19.8 * scale, 12 * scale),
      Offset(6.5 * scale, 18.75 * scale),
    ];
    canvas.drawPath(_roundedTrianglePath(points, 1.5 * scale), paint);
  }

  @override
  bool shouldRepaint(covariant _PlayTransportIconPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _SkipTransportIconPainter extends CustomPainter {
  const _SkipTransportIconPainter({
    required this.color,
    required this.previous,
  });

  final Color color;
  final bool previous;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.35 * scale
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
    final barX = (previous ? 4.4 : 19.6) * scale;
    canvas.drawLine(
      Offset(barX, 4.3 * scale),
      Offset(barX, 19.7 * scale),
      paint,
    );

    const triangleBackX = 20.1;
    const triangleTipX = 7.97;
    const triangleTopY = 3.0;
    const triangleBottomY = 21.0;
    final points = [
      Offset(
        (previous ? triangleBackX : 24 - triangleBackX) * scale,
        triangleTopY * scale,
      ),
      Offset((previous ? triangleTipX : 24 - triangleTipX) * scale, 12 * scale),
      Offset(
        (previous ? triangleBackX : 24 - triangleBackX) * scale,
        triangleBottomY * scale,
      ),
    ];
    canvas.drawPath(_roundedTrianglePath(points, 1.25 * scale), paint);
  }

  @override
  bool shouldRepaint(covariant _SkipTransportIconPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.previous != previous;
  }
}

Path _roundedTrianglePath(List<Offset> points, double radius) {
  final path = Path();
  for (var index = 0; index < points.length; index += 1) {
    final current = points[index];
    final previousPoint = points[(index + points.length - 1) % points.length];
    final nextPoint = points[(index + 1) % points.length];
    final start =
        current +
        (previousPoint - current) / (previousPoint - current).distance * radius;
    final end =
        current +
        (nextPoint - current) / (nextPoint - current).distance * radius;

    if (index == 0) {
      path.moveTo(start.dx, start.dy);
    } else {
      path.lineTo(start.dx, start.dy);
    }
    path.quadraticBezierTo(current.dx, current.dy, end.dx, end.dy);
  }
  return path..close();
}

class _PlayerArtwork extends StatelessWidget {
  const _PlayerArtwork({required this.artworkPath, this.onError});

  final String? artworkPath;
  final VoidCallback? onError;

  @override
  Widget build(BuildContext context) {
    final path = artworkPath;
    if (path != null && path.isNotEmpty) {
      final file = File(path);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) {
            onError?.call();
            return _playerDefaultAlbumArtwork();
          },
        );
      }
    }

    return _playerDefaultAlbumArtwork();
  }
}

DefaultAlbumArtwork _playerDefaultAlbumArtwork() {
  return const DefaultAlbumArtwork();
}
