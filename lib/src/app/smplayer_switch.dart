import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

class SmPlayerSwitch extends StatefulWidget {
  const SmPlayerSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.trackKey = const ValueKey('smplayer-switch-track'),
    this.thumbKey = const ValueKey('smplayer-switch-thumb'),
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final Key trackKey;
  final Key thumbKey;

  @override
  State<SmPlayerSwitch> createState() => _SmPlayerSwitchState();
}

class _SmPlayerSwitchState extends State<SmPlayerSwitch> {
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final trackColor =
        widget.value ? const Color(0xff0a84ff) : const Color(0xffc7c7c7);
    final borderColor =
        widget.value ? const Color(0xff0a84ff) : const Color(0xffcfcfcf);
    return Semantics(
      checked: widget.value,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          widget.onChanged(!widget.value);
        },
        onHorizontalDragStart: (_) {
          setState(() {
            _dragging = true;
          });
        },
        onHorizontalDragUpdate: (details) {
          final nextValue = details.localPosition.dx >= 24;
          if (nextValue != widget.value) {
            widget.onChanged(nextValue);
          }
        },
        onHorizontalDragEnd: (_) {
          setState(() {
            _dragging = false;
          });
        },
        onHorizontalDragCancel: () {
          setState(() {
            _dragging = false;
          });
        },
        child: AnimatedContainer(
          key: widget.trackKey,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: 48,
          height: 26,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: trackColor,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: borderColor),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            alignment:
                widget.value ? Alignment.centerRight : Alignment.centerLeft,
            child: _SmPlayerSwitchThumb(key: widget.thumbKey, glass: _dragging),
          ),
        ),
      ),
    );
  }
}

class _SmPlayerSwitchThumb extends StatelessWidget {
  const _SmPlayerSwitchThumb({super.key, required this.glass});

  final bool glass;

  @override
  Widget build(BuildContext context) {
    final Widget surface =
        glass
            ? const GlassContainer(
              useOwnLayer: true,
              quality: GlassQuality.minimal,
              shape: LiquidRoundedRectangle(borderRadius: 999),
              settings: LiquidGlassSettings(
                blur: 18,
                thickness: 8,
                refractiveIndex: 1.06,
                saturation: 1.35,
                chromaticAberration: 0,
                lightIntensity: 0.18,
                ambientStrength: 0.16,
                glowIntensity: 0.08,
                glassColor: Color(0xeeffffff),
                standardOpacityMultiplier: 0.62,
              ),
              clipBehavior: Clip.hardEdge,
              allowElevation: false,
              child: SizedBox.expand(),
            )
            : const DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            );

    return SizedBox(
      width: 20,
      height: 20,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 4,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: ClipOval(child: surface),
      ),
    );
  }
}
