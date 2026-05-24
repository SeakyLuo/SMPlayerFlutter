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
    final colors = MediaControlThemeColors.of(context);
    final hovered = !widget.disabled && _hovered;
    final primaryDisabled = widget.primary && widget.disabled;
    final color =
        widget.disabled
            ? widget.primary
                ? colors.disabledPrimaryIconColor
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
                ? [
                  BoxShadow(
                    color: colors.disabledPrimaryButtonShadow,
                    offset: colors.disabledPrimaryButtonShadowOffset,
                    blurRadius: colors.disabledPrimaryButtonShadowBlur,
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
              opacity:
                  widget.disabled &&
                          (!widget.primary || !colors.disabledPrimaryIconHidden)
                      ? 0.65
                      : 1,
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
                          hidden:
                              primaryDisabled &&
                              colors.disabledPrimaryIconHidden,
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
    if (icon == _playIcon) {
      return CustomPaint(
        painter: _CenteredPlayIconPainter(color),
        size: Size.square(size),
      );
    }
    if (icon == _moreIcon) {
      return CustomPaint(
        painter: _MoreHorizontalIconPainter(color),
        size: Size.square(size),
      );
    }
    if (icon == _previousIcon || icon == _nextIcon) {
      return CustomPaint(
        painter: _SkipTransportIconPainter(
          color,
          reverse: icon == _previousIcon,
        ),
        size: Size.square(size),
      );
    }
    if (icon == _listPlaybackIcon) {
      return CustomPaint(
        painter: _PlaylistPlaybackModeIconPainter(color),
        size: Size.square(size),
      );
    }
    if (icon == _voiceIcon) {
      return CustomPaint(
        painter: _VoiceAssistantIconPainter(color),
        size: Size.square(size),
      );
    }
    return Icon(icon, color: color, size: size);
  }
}

class _CenteredPlayIconPainter extends CustomPainter {
  const _CenteredPlayIconPainter(this.color);

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
    final path =
        Path()
          ..moveTo(7.4 * scale, 3.9 * scale)
          ..lineTo(21.0 * scale, 12 * scale)
          ..lineTo(7.4 * scale, 20.1 * scale)
          ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CenteredPlayIconPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _SkipTransportIconPainter extends CustomPainter {
  const _SkipTransportIconPainter(this.color, {required this.reverse});

  final Color color;
  final bool reverse;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 24;
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.55 * scale
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

    canvas.save();
    if (reverse) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }
    final path =
        Path()
          ..moveTo(7.25 * scale, 5.5 * scale)
          ..lineTo(16.25 * scale, 12 * scale)
          ..lineTo(7.25 * scale, 18.5 * scale)
          ..close();
    canvas.drawPath(path, paint);
    canvas.drawLine(
      Offset(18 * scale, 5.75 * scale),
      Offset(18 * scale, 18.25 * scale),
      paint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SkipTransportIconPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.reverse != reverse;
  }
}

class _VoiceAssistantIconPainter extends CustomPainter {
  const _VoiceAssistantIconPainter(this.color);

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
    final centerX = 12 * scale;
    final micBody = RRect.fromRectAndRadius(
      Rect.fromLTWH(8.3 * scale, 3.2 * scale, 7.4 * scale, 11.8 * scale),
      Radius.circular(3.7 * scale),
    );
    canvas.drawRRect(micBody, paint);
    final cradle =
        Path()
          ..moveTo(5.8 * scale, 11.2 * scale)
          ..cubicTo(
            5.8 * scale,
            15.0 * scale,
            8.5 * scale,
            17.8 * scale,
            centerX,
            17.8 * scale,
          )
          ..cubicTo(
            15.5 * scale,
            17.8 * scale,
            18.2 * scale,
            15.0 * scale,
            18.2 * scale,
            11.2 * scale,
          );
    canvas.drawPath(cradle, paint);
    canvas.drawLine(
      Offset(centerX, 17.8 * scale),
      Offset(centerX, 20.9 * scale),
      paint,
    );
    canvas.drawLine(
      Offset(9.0 * scale, 20.9 * scale),
      Offset(15.0 * scale, 20.9 * scale),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _VoiceAssistantIconPainter oldDelegate) {
    return oldDelegate.color != color;
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

class _PlaylistPlaybackModeIconPainter extends CustomPainter {
  const _PlaylistPlaybackModeIconPainter(this.color);

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
  bool shouldRepaint(covariant _PlaylistPlaybackModeIconPainter oldDelegate) {
    return oldDelegate.color != color;
  }
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
