import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smplayer_flutter/src/app/loading_state.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';

void main() {
  testWidgets('SmPlayerLoadingState mirrors Electron status loading shell', (
    tester,
  ) async {
    await tester.pumpWidget(
      const SmPlayerI18nScope(
        i18n: SmPlayerI18n(
          locale: 'en-US',
          messages: {'nowPlaying.loading': 'Loading...'},
        ),
        child: MaterialApp(home: Scaffold(body: SmPlayerLoadingState())),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Loading...'), findsOneWidget);
    final status = tester.widget<Semantics>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Loading...' &&
            widget.properties.liveRegion == true,
      ),
    );
    expect(status.container, isTrue);
  });

  testWidgets('SmPlayerLoadingState compact mode uses smaller spinner', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SmPlayerLoadingState(compact: true)),
      ),
    );

    expect(
      tester.getSize(find.byType(CircularProgressIndicator)),
      const Size(24, 24),
    );
  });
}
