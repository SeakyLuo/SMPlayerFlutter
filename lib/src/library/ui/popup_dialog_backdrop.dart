part of 'popup_dialog.dart';

class _PopupDialogLiquidGlassBackdrop extends StatelessWidget {
  const _PopupDialogLiquidGlassBackdrop({
    required this.colors,
    required this.child,
  });

  final PopupDialogResolvedColors colors;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      key: const ValueKey('popup-dialog-overlay'),
      child: Stack(
        fit: StackFit.expand,
        children: [
          GlassContainer(
            key: const ValueKey('popup-dialog-overlay-glass'),
            useOwnLayer: true,
            quality: GlassQuality.minimal,
            clipBehavior: Clip.hardEdge,
            allowElevation: false,
            shape: const LiquidRoundedRectangle(borderRadius: 0),
            settings: LiquidGlassSettings(
              blur: 46,
              thickness: 20,
              refractiveIndex: 1.06,
              saturation: 1.65,
              chromaticAberration: 0,
              lightIntensity: 0.1,
              ambientStrength: 0.08,
              glowIntensity: 0.04,
              glassColor: colors.overlay,
              standardOpacityMultiplier: 0.24,
            ),
            child: const SizedBox.expand(),
          ),
          DecoratedBox(decoration: BoxDecoration(color: colors.overlay)),
          child,
        ],
      ),
    );
  }
}
