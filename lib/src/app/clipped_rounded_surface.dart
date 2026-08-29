import 'package:flutter/material.dart';

class SmPlayerClippedRoundedSurface extends StatelessWidget {
  const SmPlayerClippedRoundedSurface({
    super.key,
    required this.color,
    required this.radius,
    required this.child,
    this.borderSide,
    this.boxShadow = const [],
    this.clipBehavior = Clip.antiAlias,
  });

  final Color color;
  final double radius;
  final BorderSide? borderSide;
  final List<BoxShadow> boxShadow;
  final Clip clipBehavior;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: boxShadow,
      ),
      foregroundDecoration:
          borderSide == null
              ? null
              : BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                border: Border.fromBorderSide(borderSide!),
              ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: clipBehavior,
        child: ColoredBox(color: color, child: child),
      ),
    );
  }
}
