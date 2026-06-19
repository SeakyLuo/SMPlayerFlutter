import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:smplayer_flutter/src/app/undoable_notification.dart';
import 'package:smplayer_flutter/src/app/text_icon_button.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/ui/command_bar_colors.dart';

void main() {
  testWidgets(
    'showUndoableNotification replaces the current undo notification',
    (tester) async {
      final closedReasons = <AppNotificationClosedReason>[];
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
                          showUndoableNotification(
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
                          showUndoableNotification(
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
      expect(closedReasons, [AppNotificationClosedReason.hide]);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      expect(undoCount, 1);
      expect(closedReasons.last, AppNotificationClosedReason.action);
    },
  );

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

  testWidgets('notification timeout pauses while hovered', (tester) async {
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
                      message: 'Hover pause',
                      duration: const Duration(milliseconds: 200),
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
    await tester.pump();

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(
      location: tester.getCenter(find.text('Hover pause')),
    );
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Hover pause'), findsOneWidget);

    await mouse.moveTo(Offset.zero);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    expect(find.text('Hover pause'), findsNothing);
    await mouse.removePointer();
  });

  testWidgets('notification tap dismisses the overlay', (tester) async {
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
                      message: 'Dismiss me',
                      duration: const Duration(seconds: 5),
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
    await tester.pump();
    await tester.tap(find.text('Dismiss me'));
    await tester.pumpAndSettle();

    expect(find.text('Dismiss me'), findsNothing);
  });

  testWidgets('notification action spinner follows Electron action index', (
    tester,
  ) async {
    final actionCompleter = Completer<void>();
    var actionStarted = false;

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
                          onPressed: () {
                            actionStarted = true;
                            return actionCompleter.future;
                          },
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

    expect(actionStarted, isFalse);

    await tester.pump();

    expect(actionStarted, isTrue);
    expect(find.text('Save Immediately'), findsOneWidget);
    expect(find.text('Discard Changes'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    final saveButton = tester.widget<SmPlayerTextIconButton>(
      find.widgetWithText(SmPlayerTextIconButton, 'Save Immediately'),
    );
    expect(saveButton.disabled, isTrue);
    final discardButton = tester.widget<SmPlayerTextIconButton>(
      find.widgetWithText(SmPlayerTextIconButton, 'Discard Changes'),
    );
    expect(discardButton.loading, isTrue);

    actionCompleter.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('notification action reuses CommandBar button styling', (
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
                    showUndoableNotification(
                      context: context,
                      i18n: _i18n,
                      message: 'Removed',
                      onUndo: () {},
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

    final undoButton = tester.widget<SmPlayerTextIconButton>(
      find.widgetWithText(SmPlayerTextIconButton, 'Undo'),
    );
    expect(undoButton.minWidth, 64);
    expect(undoButton.height, 36);
    expect(undoButton.horizontalPadding, 16);
    expect(undoButton.borderRadius, 10);
    expect(undoButton.fontWeight, FontWeight.w700);
    expect(undoButton.fontVariations, const [FontVariation.weight(720)]);
    final undoLabelStyle = tester.widget<DefaultTextStyle>(
      find
          .ancestor(
            of: find.text('Undo'),
            matching: find.byType(DefaultTextStyle),
          )
          .first,
    );
    expect(undoLabelStyle.style.decoration, TextDecoration.none);

    final decoratedBox =
        tester
            .widgetList<DecoratedBox>(
              find.descendant(
                of: find.widgetWithText(SmPlayerTextIconButton, 'Undo'),
                matching: find.byType(DecoratedBox),
              ),
            )
            .last;
    final decoration = decoratedBox.decoration as BoxDecoration;
    expect(decoration.color, CommandBarColors.actionSurface);
    expect(decoration.border, Border.all(color: CommandBarColors.actionBorder));

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
  });
}

const _i18n = SmPlayerI18n(locale: 'en-US', messages: {'common.undo': 'Undo'});
