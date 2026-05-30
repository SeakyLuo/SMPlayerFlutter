import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smplayer_flutter/src/library/ui/artwork_floating_action_button.dart';

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
