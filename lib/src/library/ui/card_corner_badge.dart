import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

class CardCornerBadge extends StatelessWidget {
  const CardCornerBadge({
    super.key,
    required this.child,
    this.size = 32,
    this.borderRadius = 8,
    this.shadowOffset = const Offset(0, 12),
    this.shadowBlurRadius = 26,
  });

  final Widget child;
  final double size;
  final double borderRadius;
  final Offset shadowOffset;
  final double shadowBlurRadius;

  @override
  Widget build(BuildContext context) {
    final nightMode = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: nightMode ? const Color(0x1fffffff) : const Color(0x9effffff),
        ),
        boxShadow: [
          BoxShadow(
            color:
                nightMode ? const Color(0x3d000000) : const Color(0x1f1e2a3a),
            offset: shadowOffset,
            blurRadius: shadowBlurRadius,
          ),
        ],
      ),
      child: GlassContainer(
        width: size,
        height: size,
        alignment: Alignment.center,
        useOwnLayer: true,
        quality: GlassQuality.minimal,
        clipBehavior: Clip.antiAlias,
        shape: LiquidRoundedRectangle(borderRadius: borderRadius),
        settings: LiquidGlassSettings(
          glassColor:
              nightMode ? const Color(0xc7181e26) : const Color(0xd1ffffff),
          blur: 16,
          thickness: 18,
          chromaticAberration: 0,
          lightIntensity: 0.18,
          ambientStrength: 0.12,
          saturation: 1.5,
          glowIntensity: 0,
        ),
        child: child,
      ),
    );
  }
}

class CardCornerGripIcon extends StatelessWidget {
  const CardCornerGripIcon({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _CardCornerGripPainter(color: color));
  }
}

class _CardCornerGripPainter extends CustomPainter {
  const _CardCornerGripPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.fill;
    final iconLeft = (size.width - 18) / 2;
    final iconTop = (size.height - 18) / 2;
    const scale = 18 / 24;
    const xPositions = [8.0, 12.0, 16.0];
    const yPositions = [6.0, 12.0, 18.0];
    for (final y in yPositions) {
      for (final x in xPositions) {
        canvas.drawCircle(
          Offset(iconLeft + x * scale, iconTop + y * scale),
          1 * scale,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CardCornerGripPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
