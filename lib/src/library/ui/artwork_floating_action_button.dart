import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:smplayer_flutter/src/library/ui/artwork_overlay_glass.dart';

class ArtworkFloatingActionButton extends StatelessWidget {
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

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: _ArtworkFloatingButtonSurface(
        icon: icon,
        onPressed: onPressed,
        size: size,
        iconSize: iconSize,
        hoverScale: hoverScale,
        scaleKey: scaleKey,
      ),
    );
  }
}

class _ArtworkFloatingButtonSurface extends StatefulWidget {
  const _ArtworkFloatingButtonSurface({
    required this.icon,
    required this.onPressed,
    required this.size,
    required this.iconSize,
    required this.hoverScale,
    required this.scaleKey,
  });

  final Widget icon;
  final VoidCallback? onPressed;
  final double size;
  final double? iconSize;
  final double hoverScale;
  final Key? scaleKey;

  @override
  State<_ArtworkFloatingButtonSurface> createState() =>
      _ArtworkFloatingButtonSurfaceState();
}

class _ArtworkFloatingButtonSurfaceState
    extends State<_ArtworkFloatingButtonSurface> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
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
        child: Container(
          foregroundDecoration: const BoxDecoration(
            shape: BoxShape.circle,
            border: Border.fromBorderSide(
              BorderSide(color: artworkOverlayBorderColor),
            ),
          ),
          child: AdaptiveGlass(
            shape: const LiquidOval(),
            useOwnLayer: true,
            quality: GlassQuality.minimal,
            settings: artworkOverlayGlassSettings,
            child: GlassGlow(
              glowColor: artworkOverlayGlowColor,
              glowRadius: widget.size * artworkOverlayGlowRadiusFactor,
              child: SizedBox.square(
                dimension: widget.size,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  iconSize: widget.iconSize ?? widget.size * 0.46,
                  style: IconButton.styleFrom(
                    foregroundColor: Colors.white,
                    disabledForegroundColor: Colors.white54,
                    backgroundColor: Colors.transparent,
                    disabledBackgroundColor: Colors.transparent,
                    minimumSize: Size.square(widget.size),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: const CircleBorder(),
                  ).copyWith(
                    overlayColor: const WidgetStatePropertyAll(
                      Colors.transparent,
                    ),
                    splashFactory: NoSplash.splashFactory,
                  ),
                  onPressed: widget.onPressed,
                  icon: IconTheme(
                    data: IconThemeData(
                      color:
                          widget.onPressed == null
                              ? Colors.white54
                              : Colors.white,
                      size: widget.iconSize ?? widget.size * 0.46,
                    ),
                    child: widget.icon,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
