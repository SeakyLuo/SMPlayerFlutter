import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smplayer_flutter/src/app/input_dialog.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';

void main() {
  const i18n = SmPlayerI18n(
    locale: 'en-US',
    messages: {'common.cancel': 'Cancel', 'common.confirm': 'Confirm'},
  );

  testWidgets('input dialog focuses and selects the default value', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder:
              (context) => TextButton(
                onPressed: () {
                  showSmPlayerInputDialog(
                    context: context,
                    i18n: i18n,
                    title: 'Name',
                    defaultValue: 'Playlist',
                    confirmText: 'Save',
                  );
                },
                child: const Text('Open'),
              ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.focusNode!.hasFocus, isTrue);
    expect(field.controller!.selection.baseOffset, 0);
    expect(field.controller!.selection.extentOffset, 'Playlist'.length);
  });

  testWidgets('input dialog validates before confirming', (tester) async {
    String? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder:
              (context) => TextButton(
                onPressed: () async {
                  result = await showSmPlayerInputDialog(
                    context: context,
                    i18n: i18n,
                    title: 'Name',
                    defaultValue: '',
                    confirmText: 'Save',
                    validate: (value) => value.isEmpty ? 'Required' : '',
                  );
                },
                child: const Text('Open'),
              ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Required'), findsOneWidget);
    expect(result, isNull);

    await tester.enterText(find.byType(TextField), 'Mix');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(result, 'Mix');
  });

  testWidgets('confirm dialog disables actions while async confirm runs', (
    tester,
  ) async {
    final completer = Completer<void>();

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder:
              (context) => TextButton(
                onPressed: () {
                  showSmPlayerConfirmDialog(
                    context: context,
                    i18n: i18n,
                    title: 'Delete',
                    message: 'Delete item?',
                    confirmText: 'Delete',
                    pendingText: 'Deleting',
                    onConfirm: () => completer.future,
                  );
                },
                child: const Text('Open'),
              ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pump();

    expect(find.text('Deleting'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Cancel'))
          .enabled,
      isFalse,
    );

    completer.complete();
    await tester.pumpAndSettle();

    expect(find.text('Delete item?'), findsNothing);
  });
}
