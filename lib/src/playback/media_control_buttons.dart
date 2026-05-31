part of 'media_control.dart';

class _PlayerIconButton extends StatefulWidget {
  const _PlayerIconButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.onLongPress,
    this.longPressTooltip,
    this.disabled = false,
    this.primary = false,
    this.active = false,
    this.favorite = false,
    this.loading = false,
    this.showLongPressProgress = true,
    this.buttonSize,
    this.padding,
    this.iconSize,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final VoidCallback? onLongPress;
  final String? longPressTooltip;
  final bool disabled;
  final bool primary;
  final bool active;
  final bool favorite;
  final bool loading;
  final bool showLongPressProgress;
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                ? colors.primaryButtonHover
                : MediaControlColors.accent
            : widget.favorite
            ? hovered
                ? isDark
                    ? MediaControlColors.nightFavoriteActiveHover
                    : MediaControlColors.favoriteActiveHover
                : Colors.transparent
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

    return HoldReleaseAction(
      tooltip: widget.tooltip,
      holdTooltip: widget.longPressTooltip,
      disabled: widget.disabled,
      onPressed: widget.onPressed,
      onHoldRelease: widget.onLongPress,
      triggerHoldOnReady: !widget.showLongPressProgress,
      builder: (context, holdProgress) {
        return MouseRegion(
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
                decoration: BoxDecoration(
                  color: background,
                  shape: BoxShape.circle,
                  border: border,
                  boxShadow: shadow,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (widget.onLongPress != null &&
                        widget.showLongPressProgress)
                      Positioned.fill(
                        child: CustomPaint(
                          key: const ValueKey('MediaControl.LongPressProgress'),
                          painter: HoldReleaseProgressPainter(
                            progress: holdProgress,
                            color: widget.primary ? Colors.white : accentStrong,
                          ),
                        ),
                      ),
                    widget.loading
                        ? const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        )
                        : Padding(
                          padding: EdgeInsets.all(padding),
                          child: _PlayerButtonIcon(
                            icon: widget.icon,
                            color: color,
                            size: iconSize,
                            hidden:
                                primaryDisabled &&
                                colors.disabledPrimaryIconHidden,
                          ),
                        ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
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
    if (icon == _pauseIcon) {
      return SmPlayerPauseIcon(size: size, color: color);
    }
    if (icon == _moreIcon) {
      return SmPlayerMoreHorizontalIcon(size: size, color: color);
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
        painter: _AppsListDetailIconPainter(color),
        size: Size.square(size),
      );
    }
    if (icon == _shuffleIcon) {
      return ShuffleIcon(size: size * 0.75, color: color);
    }
    if (icon == _voiceIcon) {
      return CustomPaint(
        painter: _VoiceAssistantIconPainter(color),
        size: Size.square(size),
      );
    }
    if (icon == _favoriteOutlineIcon) {
      return CustomPaint(
        key: const ValueKey('MediaControl.FavoriteOutlineIcon'),
        painter: _FavoriteOutlineIconPainter(color),
        size: Size.square(size),
      );
    }
    if (icon == _favoriteFilledIcon) {
      return CustomPaint(
        key: const ValueKey('MediaControl.FavoriteFilledIcon'),
        painter: _FavoriteFilledIconPainter(color),
        size: Size.square(size),
      );
    }
    return Icon(icon, color: color, size: size);
  }
}

class MediaControlIconGlyph extends StatelessWidget {
  const MediaControlIconGlyph({
    super.key,
    required this.icon,
    required this.color,
    required this.size,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return _PlayerButtonIcon(
      icon: icon,
      color: color,
      size: size,
      hidden: false,
    );
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
    final path = _roundedTransportPolygon([
      Offset(7.4 * scale, 3.9 * scale),
      Offset(21.0 * scale, 12 * scale),
      Offset(7.4 * scale, 20.1 * scale),
    ], 1.8 * scale);
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
    final path = _roundedTransportPolygon([
      Offset(7.25 * scale, 5.5 * scale),
      Offset(16.25 * scale, 12 * scale),
      Offset(7.25 * scale, 18.5 * scale),
    ], 1.5 * scale);
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
    final cornerRadius = min(radius, min(incomingLength, outgoingLength) / 2);
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

class _FavoriteOutlineIconPainter extends CustomPainter {
  const _FavoriteOutlineIconPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 24;
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.45 * scale
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
    final path =
        Path()
          ..moveTo(20.8 * scale, 7.6 * scale)
          ..cubicTo(
            18.8 * scale,
            5.6 * scale,
            15.6 * scale,
            5.6 * scale,
            13.6 * scale,
            7.6 * scale,
          )
          ..lineTo(12 * scale, 9.2 * scale)
          ..lineTo(10.4 * scale, 7.6 * scale)
          ..cubicTo(
            8.4 * scale,
            5.6 * scale,
            5.2 * scale,
            5.6 * scale,
            3.2 * scale,
            7.6 * scale,
          )
          ..cubicTo(
            1.2 * scale,
            9.6 * scale,
            1.2 * scale,
            12.8 * scale,
            3.2 * scale,
            14.8 * scale,
          )
          ..lineTo(12 * scale, 22 * scale)
          ..lineTo(20.8 * scale, 14.8 * scale)
          ..cubicTo(
            22.8 * scale,
            12.8 * scale,
            22.8 * scale,
            9.6 * scale,
            20.8 * scale,
            7.6 * scale,
          );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _FavoriteOutlineIconPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _FavoriteFilledIconPainter extends CustomPainter {
  const _FavoriteFilledIconPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 24;
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.fill;
    final path =
        Path()
          ..moveTo(20.8 * scale, 7.6 * scale)
          ..cubicTo(
            18.8 * scale,
            5.6 * scale,
            15.6 * scale,
            5.6 * scale,
            13.6 * scale,
            7.6 * scale,
          )
          ..lineTo(12 * scale, 9.2 * scale)
          ..lineTo(10.4 * scale, 7.6 * scale)
          ..cubicTo(
            8.4 * scale,
            5.6 * scale,
            5.2 * scale,
            5.6 * scale,
            3.2 * scale,
            7.6 * scale,
          )
          ..cubicTo(
            1.2 * scale,
            9.6 * scale,
            1.2 * scale,
            12.8 * scale,
            3.2 * scale,
            14.8 * scale,
          )
          ..lineTo(12 * scale, 22 * scale)
          ..lineTo(20.8 * scale, 14.8 * scale)
          ..cubicTo(
            22.8 * scale,
            12.8 * scale,
            22.8 * scale,
            9.6 * scale,
            20.8 * scale,
            7.6 * scale,
          )
          ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _FavoriteFilledIconPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _AppsListDetailIconPainter extends CustomPainter {
  const _AppsListDetailIconPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 24;
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.45 * scale
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

    for (final top in const [5.25, 10.15, 15.05]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(4.5 * scale, top * scale, 3.3 * scale, 3.3 * scale),
          Radius.circular(0.7 * scale),
        ),
        paint,
      );
    }
    canvas.drawLine(
      Offset(10.5 * scale, 6.9 * scale),
      Offset(19.5 * scale, 6.9 * scale),
      paint,
    );
    canvas.drawLine(
      Offset(10.5 * scale, 11.8 * scale),
      Offset(18 * scale, 11.8 * scale),
      paint,
    );
    canvas.drawLine(
      Offset(10.5 * scale, 16.7 * scale),
      Offset(19.5 * scale, 16.7 * scale),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _AppsListDetailIconPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _PlayerArtwork extends StatelessWidget {
  const _PlayerArtwork({required this.artworkPath, this.onError});

  final String? artworkPath;
  final VoidCallback? onError;

  @override
  Widget build(BuildContext context) {
    return SongArtwork(
      artworkPath: artworkPath,
      fallback: _playerDefaultAlbumArtwork(),
      onError: onError,
    );
  }
}

DefaultAlbumArtwork _playerDefaultAlbumArtwork() {
  return const DefaultAlbumArtwork();
}
