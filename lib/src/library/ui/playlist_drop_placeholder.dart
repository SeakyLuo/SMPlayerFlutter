part of 'playlists_page.dart';

class _PlaylistDropPlaceholder extends StatelessWidget {
  const _PlaylistDropPlaceholder({required this.i18n});

  final SmPlayerI18n i18n;

  @override
  Widget build(BuildContext context) {
    final night = Theme.of(context).brightness == Brightness.dark;
    final foregroundColor =
        night
            ? Color.lerp(
              _PlaylistsColors.accentStrong,
              const Color(0xfff5fbff),
              0.28,
            )!
            : _PlaylistsColors.accentStrong;
    final borderColor = _PlaylistsColors.accentStrong.withValues(
      alpha: night ? 0.74 : 0.76,
    );
    return Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        key: const ValueKey('Playlists.DropPlaceholder'),
        width: _playlistCardWidth,
        height: _playlistCardHeight,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: night ? const Color(0x0cffffff) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow:
                night
                    ? [
                      BoxShadow(
                        color: const Color(0x0effffff),
                        spreadRadius: -1,
                      ),
                    ]
                    : null,
          ),
          child: CustomPaint(
            painter: _PlaylistDropPlaceholderPainter(color: borderColor),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox.square(
                    dimension: 30,
                    child: CustomPaint(
                      painter: _PlaylistDropPlusPainter(color: foregroundColor),
                    ),
                  ),
                  const SizedBox(height: 13),
                  SizedBox(
                    width: 92,
                    child: Text(
                      i18n.t('playlists.dropHere'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: foregroundColor,
                        fontSize: 16,
                        fontVariations: const [FontVariation.weight(650)],
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlaylistDropPlusPainter extends CustomPainter {
  const _PlaylistDropPlusPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final strokePaint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, (size.shortestSide - 2) / 2, strokePaint);

    const plusHalfLength = 7.0;
    canvas
      ..drawLine(
        center.translate(-plusHalfLength, 0),
        center.translate(plusHalfLength, 0),
        strokePaint,
      )
      ..drawLine(
        center.translate(0, -plusHalfLength),
        center.translate(0, plusHalfLength),
        strokePaint,
      );
  }

  @override
  bool shouldRepaint(covariant _PlaylistDropPlusPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _PlaylistDropPlaceholderPainter extends CustomPainter {
  const _PlaylistDropPlaceholderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
    final path =
        Path()..addRRect(
          RRect.fromRectAndRadius(
            Offset.zero & size,
            const Radius.circular(12),
          ),
        );
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      const dash = 9.0;
      const gap = 6.0;
      while (distance < metric.length) {
        final end = (distance + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PlaylistDropPlaceholderPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
