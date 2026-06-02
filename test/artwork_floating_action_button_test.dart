import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:smplayer_flutter/src/library/ui/artwork_floating_action_button.dart';
import 'package:smplayer_flutter/src/library/ui/artwork_overlay_glass.dart';

void main() {
  testWidgets('ArtworkFloatingActionButton scales on hover like Electron', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: ArtworkFloatingActionButton(
              tooltip: 'Play',
              icon: Icon(Icons.play_arrow_rounded),
              onPressed: _noop,
            ),
          ),
        ),
      ),
    );

    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
    final glassButton = tester.widget<GlassIconButton>(
      find.byType(GlassIconButton),
    );
    expect(glassButton.quality, GlassQuality.minimal);
    expect(glassButton.settings?.glassColor, artworkOverlayGlassColor);
    expect(glassButton.settings?.blur, 46);
    expect(glassButton.settings?.saturation, 1.65);
    expect(
      glassButton.settings?.standardOpacityMultiplier,
      artworkOverlayGlassOpacityMultiplier,
    );

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(
      location: tester.getCenter(find.byType(ArtworkFloatingActionButton)),
    );
    addTearDown(mouse.removePointer);
    await tester.pump();

    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1.1);
  });
}

void _noop() {}
