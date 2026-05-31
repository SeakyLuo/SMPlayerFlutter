import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SvgIcon extends StatelessWidget {
  const SvgIcon({
    super.key,
    required this.svg,
    required this.size,
    this.color,
    this.fit = BoxFit.contain,
  });

  final String svg;
  final double size;
  final Color? color;
  final BoxFit fit;

  static String strokeAttr({
    required double strokeWidth,
    required double viewBoxSize,
    required double renderSize,
  }) {
    if (strokeWidth <= 0) {
      return '';
    }
    return 'stroke="white" stroke-width="${(strokeWidth * viewBoxSize / renderSize).toStringAsFixed(1)}" stroke-linejoin="round" stroke-linecap="round"';
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SvgPicture.string(
        svg,
        width: size,
        height: size,
        colorFilter:
            color == null ? null : ColorFilter.mode(color!, BlendMode.srcIn),
        fit: fit,
      ),
    );
  }
}
