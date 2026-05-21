import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smplayer_flutter/src/app/touch_context_menu.dart';

void main() {
  testWidgets(
    'touch long press opens secondary tap like Electron contextmenu',
    (tester) async {
      var contextMenuCount = 0;
      var tapCount = 0;
      Offset? contextMenuPosition;

      await tester.pumpWidget(
        MaterialApp(
          home: TouchContextMenuAdapter(
            child: Center(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  tapCount += 1;
                },
                onSecondaryTapDown: (details) {
                  contextMenuCount += 1;
                  contextMenuPosition = details.globalPosition;
                },
                child: const SizedBox(width: 220, height: 120),
              ),
            ),
          ),
        ),
      );

      final center = tester.getCenter(find.byType(SizedBox));
      final gesture = await tester.createGesture(kind: PointerDeviceKind.touch);
      await gesture.down(center);
      await tester.pump(touchContextMenuDelay);

      expect(contextMenuCount, 1);
      expect(contextMenuPosition, center);

      await gesture.up();
      await tester.pump();

      expect(tapCount, 0);
    },
  );

  testWidgets('touch move cancels synthetic contextmenu', (tester) async {
    var contextMenuCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: TouchContextMenuAdapter(
          child: Center(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onSecondaryTapDown: (_) {
                contextMenuCount += 1;
              },
              child: const SizedBox(width: 220, height: 120),
            ),
          ),
        ),
      ),
    );

    final center = tester.getCenter(find.byType(SizedBox));
    final gesture = await tester.createGesture(kind: PointerDeviceKind.touch);
    await gesture.down(center);
    await gesture.moveBy(const Offset(touchContextMenuMoveTolerance + 1, 0));
    await tester.pump(touchContextMenuDelay);

    expect(contextMenuCount, 0);
  });
}
