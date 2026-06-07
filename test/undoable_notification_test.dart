import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
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

  testWidgets('notification glass follows MenuFlyout panel settings', (
    tester,
  ) async {
    await tester.pumpWidget(
      SmPlayerI18nScope(
        i18n: _i18n,
        child: MaterialApp(
          theme: ThemeData(extensions: [AppNotificationThemeColors.light]),
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: TextButton(
                  onPressed: () {
                    showAppNotification(context: context, message: 'Saved');
                  },
                  child: const Text('Show'),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show'));
    await tester.pumpAndSettle();

    final glass = tester.widget<GlassContainer>(find.byType(GlassContainer));
    final settings = glass.settings!;
    expect(glass.useOwnLayer, isTrue);
    expect(glass.quality, GlassQuality.minimal);
    expect(glass.clipBehavior, Clip.hardEdge);
    expect(settings.blur, 46);
    expect(settings.thickness, 20);
    expect(settings.refractiveIndex, 1.06);
    expect(settings.saturation, 1.65);
    expect(settings.chromaticAberration, 0);
    expect(settings.lightIntensity, 0.1);
    expect(settings.ambientStrength, 0.08);
    expect(settings.glowIntensity, 0.04);
    expect(settings.standardOpacityMultiplier, 0.24);

    await tester.pump(appNotificationDuration);
    await tester.pumpAndSettle();
  });

  testWidgets('notification action spinner follows Electron action index', (
    tester,
  ) async {
    final actionCompleter = Completer<void>();

    await tester.pumpWidget(
      SmPlayerI18nScope(
        i18n: _i18n,
        child: MaterialApp(
          theme: ThemeData(extensions: [AppNotificationThemeColors.light]),
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: TextButton(
                  onPressed: () {
                    showAppNotification(
                      context: context,
                      message: 'Pending lyrics',
                      actions: [
                        AppNotificationAction(
                          label: 'Save Immediately',
                          onPressed: () {},
                        ),
                        AppNotificationAction(
                          label: 'Discard Changes',
                          onPressed: () => actionCompleter.future,
                        ),
                      ],
                    );
                  },
                  child: const Text('Show'),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard Changes'));
    await tester.pump();

    expect(find.text('Save Immediately'), findsOneWidget);
    expect(find.text('Discard Changes'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    final saveButton = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Save Immediately'),
    );
    expect(saveButton.onPressed, isNull);

    actionCompleter.complete();
    await tester.pumpAndSettle();
  });
}

const _i18n = SmPlayerI18n(locale: 'en-US', messages: {'common.undo': 'Undo'});
