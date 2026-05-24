import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

class ArtworkFloatingActionButton extends StatelessWidget {
  const ArtworkFloatingActionButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.size = 48,
    this.iconSize,
  });

  final String tooltip;
  final Widget icon;
  final VoidCallback? onPressed;
  final double size;
  final double? iconSize;

  static const _settings = LiquidGlassSettings(
    glassColor: Color(0xb20b0d12),
    thickness: 34,
    blur: 12,
    chromaticAberration: 0.012,
    lightIntensity: 0.42,
    ambientStrength: 0.08,
    refractiveIndex: 1.16,
    saturation: 1.12,
    glowIntensity: 0.28,
    standardOpacityMultiplier: 1.1,
  );

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GlassIconButton(
        size: size,
        iconSize: iconSize ?? size * 0.46,
        useOwnLayer: true,
        settings: _settings,
        glowColor: Colors.white.withValues(alpha: 0.18),
        glowRadius: size * 0.44,
        onPressed: onPressed,
        icon: IconTheme(
          data: IconThemeData(
            color: onPressed == null ? Colors.white54 : Colors.white,
            size: iconSize ?? size * 0.46,
          ),
          child: icon,
        ),
      ),
    );
  }
}
