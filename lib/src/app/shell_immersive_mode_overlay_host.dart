import 'package:flutter/material.dart';
import 'package:smplayer_flutter/src/playback/immersive_mode_page.dart';

class ShellImmersiveModeOverlayHost extends StatelessWidget {
  const ShellImmersiveModeOverlayHost({super.key, required this.visible});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!visible) {
      return const SizedBox.shrink();
    }
    return const Positioned.fill(
      child: ImmersiveModePage(key: ValueKey('ShellImmersiveModeOverlay.Page')),
    );
  }
}
