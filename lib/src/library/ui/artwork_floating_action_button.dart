import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

class ArtworkFloatingActionButton extends StatefulWidget {
  const ArtworkFloatingActionButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.size = 48,
    this.iconSize,
    this.hoverScale = 1.1,
    this.scaleKey,
  });

  final String tooltip;
  final Widget icon;
  final VoidCallback? onPressed;
  final double size;
  final double? iconSize;
  final double hoverScale;
  final Key? scaleKey;

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
  State<ArtworkFloatingActionButton> createState() =>
      _ArtworkFloatingActionButtonState();
}

class _ArtworkFloatingActionButtonState
    extends State<ArtworkFloatingActionButton> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
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
        child: AnimatedScale(
          key: widget.scaleKey,
          scale: widget.onPressed != null && _hovered ? widget.hoverScale : 1,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          child: GlassIconButton(
            size: widget.size,
            iconSize: widget.iconSize ?? widget.size * 0.46,
            useOwnLayer: true,
            settings: ArtworkFloatingActionButton._settings,
            glowColor: Colors.white.withValues(alpha: 0.18),
            glowRadius: widget.size * 0.44,
            onPressed: widget.onPressed,
            icon: IconTheme(
              data: IconThemeData(
                color: widget.onPressed == null ? Colors.white54 : Colors.white,
                size: widget.iconSize ?? widget.size * 0.46,
              ),
              child: widget.icon,
            ),
          ),
        ),
      ),
    );
  }
}
