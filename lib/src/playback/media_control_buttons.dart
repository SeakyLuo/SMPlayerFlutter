part of 'media_control.dart';

class _PlayerIconButton extends StatefulWidget {
  const _PlayerIconButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.onLongPress,
    this.onSecondaryTap,
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
    this.holdDuration,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final VoidCallback? onLongPress;
  final VoidCallback? onSecondaryTap;
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
  final Duration? holdDuration;

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
    final colors = MediaControlThemeColors.of(context);
    final hovered = !widget.disabled && _hovered;
    final hoverBackground = colors.buttonActiveBackground;
    final transparentHoverBackground = hoverBackground.withValues(alpha: 0);
    final transparentFavoriteHoverBackground = colors
        .favoriteActiveHoverBackground
        .withValues(alpha: 0);
    final color =
        widget.disabled
            ? widget.primary
                ? colors.disabledPrimaryIconColor
                : colors.buttonForeground
            : widget.favorite
            ? MediaControlColors.favorite
            : widget.primary
            ? Colors.white
            : widget.active || hovered
            ? colors.buttonHoverForeground
            : colors.buttonForeground;
    final background =
        widget.disabled
            ? widget.primary
                ? colors.disabledPrimaryButtonSurface
                : MediaControlColors.disabledButtonSurface
            : widget.primary
            ? hovered
                ? colors.primaryButtonHover
                : MediaControlColors.accent
            : widget.favorite
            ? hovered
                ? colors.favoriteActiveHoverBackground
                : transparentFavoriteHoverBackground
            : widget.active
            ? colors.buttonActiveBackground
            : hovered
            ? hoverBackground
            : transparentHoverBackground;
    final border =
        widget.primary
            ? Border.all(
              color:
                  widget.disabled
                      ? colors.primaryButtonBorder
                      : colors.primaryButtonBorder,
            )
            : null;
    final shadow =
        widget.primary
            ? widget.disabled
                ? [colors.primaryButtonShadow]
                : [colors.primaryButtonShadow]
            : null;
    final opacity = widget.disabled && !widget.primary ? 0.65 : 1.0;
    final iconHidden =
        widget.disabled && widget.primary
            ? colors.disabledPrimaryIconHidden
            : false;

    return HoldReleaseAction(
      tooltip: widget.tooltip,
      holdTooltip: widget.longPressTooltip,
      disabled: widget.disabled,
      onPressed: widget.onPressed,
      onHoldRelease: widget.onLongPress,
      onSecondaryTap: widget.onSecondaryTap,
      holdDuration: widget.holdDuration ?? const Duration(milliseconds: 200),
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
            curve: Curves.ease,
            offset: hovered ? Offset(0, -1 / size) : Offset.zero,
            child: Opacity(
              opacity: opacity,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                curve: Curves.ease,
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
                            color:
                                widget.primary
                                    ? Colors.white
                                    : colors.buttonHoverForeground,
                          ),
                        ),
                      ),
                    widget.loading
                        ? const _PlayerLoadingSpinner()
                        : Padding(
                          padding: EdgeInsets.all(padding),
                          child: _PlayerButtonIcon(
                            icon: widget.icon,
                            color: color,
                            size: iconSize,
                            hidden: iconHidden,
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
  final Color? color;
  final double size;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    if (hidden) {
      return const SizedBox.expand();
    }
    final resolvedColor =
        color ??
        IconTheme.of(context).color ??
        DefaultTextStyle.of(context).style.color!;
    if (icon == _playIcon) {
      return CustomPaint(
        painter: _CenteredPlayIconPainter(resolvedColor),
        size: Size.square(size),
      );
    }
    if (icon == _pauseIcon) {
      return SmPlayerPauseIcon(size: size, color: resolvedColor);
    }
    if (icon == _moreIcon) {
      return SmPlayerMoreHorizontalIcon(size: size, color: resolvedColor);
    }
    if (icon == _previousIcon || icon == _nextIcon) {
      return CustomPaint(
        painter: _SkipTransportIconPainter(
          resolvedColor,
          reverse: icon == _previousIcon,
        ),
        size: Size.square(size),
      );
    }
    if (icon == _listPlaybackIcon) {
      return SmPlayerPlaylistIcon(
        size: size,
        color: resolvedColor,
        strokeWidth: 1.25,
      );
    }
    if (icon == _shuffleIcon) {
      return ShuffleIcon(size: size * 0.75, color: resolvedColor);
    }
    if (icon == _voiceIcon) {
      return CustomPaint(
        painter: _VoiceAssistantIconPainter(resolvedColor),
        size: Size.square(size),
      );
    }
    if (icon == _desktopLyricsIcon) {
      return SvgIcon(
        key: const ValueKey('MediaControl.DesktopLyricsIcon'),
        svg: _desktopLyricsIconSvg,
        size: size,
        color: resolvedColor,
      );
    }
    if (icon == _volumeMutedIcon ||
        icon == _volumeOffIcon ||
        icon == _volumeLowIcon ||
        icon == _volumeMediumIcon ||
        icon == _volumeHighIcon) {
      return SmPlayerVolumeIcon(
        key: ValueKey('MediaControl.VolumeIcon.${icon.codePoint}'),
        kind:
            icon == _volumeMutedIcon
                ? SmPlayerVolumeIconKind.muted
                : icon == _volumeOffIcon
                ? SmPlayerVolumeIconKind.off
                : icon == _volumeLowIcon
                ? SmPlayerVolumeIconKind.low
                : icon == _volumeMediumIcon
                ? SmPlayerVolumeIconKind.medium
                : SmPlayerVolumeIconKind.high,
        size: size,
        color: resolvedColor,
      );
    }
    if (icon == _favoriteOutlineIcon) {
      return CustomPaint(
        key: const ValueKey('MediaControl.FavoriteOutlineIcon'),
        painter: _FavoriteOutlineIconPainter(resolvedColor),
        size: Size.square(size),
      );
    }
    if (icon == _favoriteFilledIcon) {
      return CustomPaint(
        key: const ValueKey('MediaControl.FavoriteFilledIcon'),
        painter: _FavoriteFilledIconPainter(resolvedColor),
        size: Size.square(size),
      );
    }
    return Icon(icon, color: resolvedColor, size: size);
  }
}

@visibleForTesting
const mediaControlLoadingSpinnerSize = 22.0;

@visibleForTesting
const mediaControlLoadingSpinnerStrokeWidth = 2.0;

@visibleForTesting
const mediaControlLoadingSpinnerTrackColor = Color(0x61ffffff);

@visibleForTesting
const mediaControlLoadingSpinnerTopColor = Colors.white;

@visibleForTesting
const mediaControlLoadingSpinnerDuration = Duration(milliseconds: 800);

class _PlayerLoadingSpinner extends StatefulWidget {
  const _PlayerLoadingSpinner();

  @override
  State<_PlayerLoadingSpinner> createState() => _PlayerLoadingSpinnerState();
}

class _PlayerLoadingSpinnerState extends State<_PlayerLoadingSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: mediaControlLoadingSpinnerDuration,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      key: const ValueKey('MediaControl.LoadingSpinner'),
      dimension: mediaControlLoadingSpinnerSize,
      child: AnimatedBuilder(
        key: const ValueKey('MediaControl.LoadingSpinnerAnimation'),
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _PlayerLoadingSpinnerPainter(_controller.value),
          );
        },
      ),
    );
  }
}

class _PlayerLoadingSpinnerPainter extends CustomPainter {
  const _PlayerLoadingSpinnerPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(
      mediaControlLoadingSpinnerStrokeWidth / 2,
    );
    final trackPaint =
        Paint()
          ..color = mediaControlLoadingSpinnerTrackColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = mediaControlLoadingSpinnerStrokeWidth;
    final topPaint =
        Paint()
          ..color = mediaControlLoadingSpinnerTopColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = mediaControlLoadingSpinnerStrokeWidth;
    canvas.drawOval(rect, trackPaint);
    canvas.drawArc(rect, -pi / 2 + progress * pi * 2, pi / 2, false, topPaint);
  }

  @override
  bool shouldRepaint(covariant _PlayerLoadingSpinnerPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class MediaControlIconGlyph extends StatelessWidget {
  const MediaControlIconGlyph({
    super.key,
    required this.icon,
    required this.size,
    this.color,
  });

  final IconData icon;
  final Color? color;
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
    final scale = size.shortestSide / 20;
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.fill;

    canvas.save();
    final dx = (size.width - size.shortestSide) / 2;
    final dy = (size.height - size.shortestSide) / 2;
    canvas.translate(dx, dy);
    if (reverse) {
      canvas.translate(size.shortestSide, 0);
      canvas.scale(-1, 1);
    }
    canvas.scale(scale);
    canvas.drawPath(_nextRegularPath(), paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SkipTransportIconPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.reverse != reverse;
  }
}

Path _nextRegularPath() {
  return Path()
    ..fillType = PathFillType.evenOdd
    ..addRRect(RRect.fromLTRBR(16, 3, 17, 17, const Radius.circular(0.5)))
    ..moveTo(3, 4.25)
    ..cubicTo(3, 3.25, 4.12, 2.65, 4.95, 3.21)
    ..lineTo(13.45, 8.92)
    ..cubicTo(14.18, 9.42, 14.18, 10.49, 13.45, 10.99)
    ..lineTo(4.95, 16.79)
    ..cubicTo(4.12, 17.35, 3, 16.75, 3, 15.75)
    ..lineTo(3, 4.25)
    ..close()
    ..moveTo(4.39, 4.05)
    ..cubicTo(4.22, 3.93, 4, 4.05, 4, 4.25)
    ..lineTo(4, 15.75)
    ..cubicTo(4, 15.95, 4.23, 16.07, 4.4, 15.95)
    ..lineTo(12.89, 10.17)
    ..cubicTo(13.04, 10.07, 13.04, 9.85, 12.89, 9.75)
    ..lineTo(4.39, 4.05)
    ..close();
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
