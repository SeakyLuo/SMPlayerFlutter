import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smplayer_flutter/src/recent/recent_scrollbar.dart';

void main() {
  testWidgets('RecentScrollbar appears only for scrollable hover/focus state', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 240);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 160,
            child: RecentScrollbar(
              builder:
                  (controller) => ListView.builder(
                    controller: controller,
                    itemExtent: 40,
                    itemCount: 20,
                    itemBuilder: (context, index) => Text('Item $index'),
                  ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_scrollbarThumbColor(tester), Colors.transparent);

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: tester.getCenter(find.byType(ListView)));
    await tester.pumpAndSettle();

    expect(find.byType(Scrollbar), findsOneWidget);
    expect(_scrollbarThumbColor(tester), const Color(0x805b697a));
    expect(_scrollbarCrossAxisMargin(tester), 0);

    await gesture.removePointer();
  });

  testWidgets('RecentScrollbar remains hidden when content cannot scroll', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 240);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 160,
            child: RecentScrollbar(
              builder:
                  (controller) => ListView.builder(
                    controller: controller,
                    itemExtent: 40,
                    itemCount: 2,
                    itemBuilder: (context, index) => Text('Item $index'),
                  ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: tester.getCenter(find.byType(ListView)));
    await tester.pumpAndSettle();

    expect(_scrollbarThumbColor(tester), Colors.transparent);

    await gesture.removePointer();
  });
}

Color? _scrollbarThumbColor(WidgetTester tester) {
  final theme = tester.widget<ScrollbarTheme>(find.byType(ScrollbarTheme));
  return theme.data.thumbColor?.resolve({});
}

double? _scrollbarCrossAxisMargin(WidgetTester tester) {
  final theme = tester.widget<ScrollbarTheme>(find.byType(ScrollbarTheme));
  return theme.data.crossAxisMargin;
}
