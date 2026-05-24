import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smplayer_flutter/src/app/undoable_notification.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';

void main() {
  testWidgets('showUndoableSnackBar replaces the current undo notification', (
    tester,
  ) async {
    final closedReasons = <SnackBarClosedReason>[];
    var undoCount = 0;

    await tester.pumpWidget(
      SmPlayerI18nScope(
        i18n: _i18n,
        child: MaterialApp(
          theme: ThemeData(extensions: [AppNotificationThemeColors.light]),
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Column(
                  children: [
                    TextButton(
                      onPressed: () {
                        showUndoableSnackBar(
                          context: context,
                          i18n: _i18n,
                          message: 'First',
                          onUndo: () {
                            undoCount += 1;
                          },
                        ).then(closedReasons.add);
                      },
                      child: const Text('First'),
                    ),
                    TextButton(
                      onPressed: () {
                        showUndoableSnackBar(
                          context: context,
                          i18n: _i18n,
                          message: 'Second',
                          onUndo: () {
                            undoCount += 1;
                          },
                        ).then(closedReasons.add);
                      },
                      child: const Text('Second'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('First'));
    await tester.pump();
    expect(find.text('First'), findsNWidgets(2));

    await tester.tap(find.text('Second'));
    await tester.pumpAndSettle();

    expect(find.text('First'), findsOneWidget);
    expect(find.text('Second'), findsNWidgets(2));
    expect(closedReasons, [SnackBarClosedReason.hide]);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(undoCount, 1);
    expect(closedReasons.last, SnackBarClosedReason.action);
  });

  test('undoable notification duration matches Electron store', () {
    expect(undoableNotificationDuration, const Duration(seconds: 5));
  });
}

const _i18n = SmPlayerI18n(locale: 'en-US', messages: {'common.undo': 'Undo'});
