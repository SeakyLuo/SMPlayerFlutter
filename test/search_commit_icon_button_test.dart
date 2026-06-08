import 'dart:ui';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smplayer_flutter/src/library/ui/page_search_history_panel.dart';
import 'package:smplayer_flutter/src/library/ui/search_commit_icon_button.dart';

void main() {
  testWidgets('SearchCommitIconButton keeps Electron search icon sizing', (
    tester,
  ) async {
    var pressed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 40,
            height: 40,
            child: SearchCommitIconButton(
              tooltip: 'Search',
              foreground: const Color(0xff333333),
              hoverForeground: const Color(0xff0078d7),
              hoverBackground: const Color(0x1a0078d7),
              onPressed: () {
                pressed = true;
              },
            ),
          ),
        ),
      ),
    );

    final icon = tester.widget<Icon>(
      find.byIcon(FluentIcons.search_24_regular),
    );
    expect(icon.size, 19);
    expect(icon.color, const Color(0xff333333));

    await tester.tap(find.byType(SearchCommitIconButton));
    expect(pressed, isTrue);
  });

  testWidgets('SearchCommitIconButton applies configured hover colors', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 40,
            height: 40,
            child: SearchCommitIconButton(
              tooltip: 'Search',
              foreground: const Color(0xff333333),
              hoverForeground: const Color(0xff0078d7),
              hoverBackground: const Color(0x1a0078d7),
              onPressed: () {},
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    await gesture.moveTo(tester.getCenter(find.byType(SearchCommitIconButton)));
    await tester.pump();

    final icon = tester.widget<Icon>(
      find.byIcon(FluentIcons.search_24_regular),
    );
    expect(icon.color, const Color(0xff0078d7));

    final hoverDecorations = tester
        .widgetList<DecoratedBox>(
          find.descendant(
            of: find.byType(SearchCommitIconButton),
            matching: find.byType(DecoratedBox),
          ),
        )
        .map((widget) => widget.decoration)
        .whereType<BoxDecoration>()
        .where((decoration) => decoration.color == const Color(0x1a0078d7));
    expect(hoverDecorations, isNotEmpty);
  });

  testWidgets('SearchCommitIconButton exposes shared sidebar button colors', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        home: Builder(
          builder: (context) {
            expect(
              SearchCommitIconButton.foregroundFor(context),
              const Color(0xff5f625f),
            );
            expect(
              SearchCommitIconButton.hoverForegroundFor(context),
              const Color(0xff0063b1),
            );
            expect(
              SearchCommitIconButton.transparentHoverBackground,
              Colors.transparent,
            );
            return const SizedBox();
          },
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        home: Theme(
          data: ThemeData(brightness: Brightness.dark),
          child: Builder(
            builder: (context) {
              expect(
                SearchCommitIconButton.foregroundFor(context),
                const Color(0xadcbd5e1),
              );
              expect(
                SearchCommitIconButton.hoverForegroundFor(context),
                const Color(0xff459de2),
              );
              expect(
                SearchCommitIconButton.transparentHoverBackground,
                Colors.transparent,
              );
              return const SizedBox();
            },
          ),
        ),
      ),
    );
  });

  testWidgets(
    'SearchCommitIconButton shared sidebar colors render the button',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Builder(
            builder: (context) {
              return Center(
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: SearchCommitIconButton(
                    tooltip: 'Search',
                    foreground: SearchCommitIconButton.foregroundFor(context),
                    hoverForeground: SearchCommitIconButton.hoverForegroundFor(
                      context,
                    ),
                    hoverBackground:
                        SearchCommitIconButton.transparentHoverBackground,
                    onPressed: () {},
                  ),
                ),
              );
            },
          ),
        ),
      );

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      await gesture.moveTo(
        tester.getCenter(find.byType(SearchCommitIconButton)),
      );
      await tester.pump();

      final icon = tester.widget<Icon>(
        find.byIcon(FluentIcons.search_24_regular),
      );
      expect(icon.color, SearchCommitIconButton.lightHoverForeground);

      final hoverDecorations = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byType(SearchCommitIconButton),
              matching: find.byType(DecoratedBox),
            ),
          )
          .map((widget) => widget.decoration)
          .whereType<BoxDecoration>()
          .where(
            (decoration) =>
                decoration.color ==
                SearchCommitIconButton.transparentHoverBackground,
          );
      expect(hoverDecorations, isNotEmpty);
    },
  );

  testWidgets('PageSearchField keeps local input across unrelated rebuilds', (
    tester,
  ) async {
    var hintText = 'Search artists';

    Future<void> pumpField() {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 240,
                child: PageSearchField(
                  value: '',
                  hintText: hintText,
                  focused: false,
                  onChanged: (_) {},
                  onFocusChanged: (_) {},
                  onSubmitted: () {},
                  onClear: () {},
                  searchTooltip: 'Search',
                  clearTooltip: 'Clear',
                ),
              ),
            ),
          ),
        ),
      );
    }

    await pumpField();
    await tester.enterText(find.byType(EditableText), 'abc123');
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      'abc123',
    );

    hintText = 'Search albums';
    await pumpField();
    await tester.pump();

    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      'abc123',
    );
  });

  testWidgets('PageSearchField uses Electron night colors outside appbar', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 240,
              child: PageSearchField(
                value: '',
                hintText: 'Search artists',
                focused: false,
                onChanged: (_) {},
                onFocusChanged: (_) {},
                onSubmitted: () {},
                onClear: () {},
                searchTooltip: 'Search',
                clearTooltip: 'Clear',
              ),
            ),
          ),
        ),
      ),
    );

    final fieldDecoration = _fieldDecoration(tester);
    expect(fieldDecoration.color, const Color(0x0effffff));
    expect(fieldDecoration.border, Border.all(color: const Color(0x1fd6e0ec)));

    final searchButton = tester.widget<SearchCommitIconButton>(
      find.byType(SearchCommitIconButton),
    );
    expect(searchButton.foreground, const Color(0xc7ffffff));

    final field = tester.widget<EditableText>(find.byType(EditableText));
    expect(field.style.color, const Color(0xebffffff));
    final placeholder = tester.widget<Text>(find.text('Search artists'));
    expect(placeholder.style?.color, const Color(0xadcbd5e1));
  });

  testWidgets('PageSearchField uses Electron night hover accent', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 240,
              child: PageSearchField(
                value: '',
                hintText: 'Search artists',
                focused: false,
                onChanged: (_) {},
                onFocusChanged: (_) {},
                onSubmitted: () {},
                onClear: () {},
                searchTooltip: 'Search',
                clearTooltip: 'Clear',
              ),
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    await gesture.moveTo(tester.getCenter(find.byType(SearchCommitIconButton)));
    await tester.pump();

    final searchButton = tester.widget<SearchCommitIconButton>(
      find.byType(SearchCommitIconButton),
    );
    expect(searchButton.hoverForeground, const Color(0xff7fc4ff));
    expect(searchButton.hoverBackground, Colors.transparent);
  });

  testWidgets('PageSearchField unfocuses when tapping outside', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              SizedBox(
                width: 260,
                child: PageSearchField(
                  value: '',
                  hintText: 'Search',
                  focused: false,
                  onChanged: (_) {},
                  onFocusChanged: (_) {},
                  onSubmitted: () {},
                  onClear: () {},
                ),
              ),
              GestureDetector(
                key: const ValueKey('OutsidePageSearchTarget'),
                behavior: HitTestBehavior.opaque,
                child: const SizedBox(width: 200, height: 80),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byType(EditableText));
    await tester.pump();
    final editableTextState = tester.state<EditableTextState>(
      find.byType(EditableText),
    );
    expect(editableTextState.widget.focusNode.hasFocus, isTrue);

    await tester.tap(find.byKey(const ValueKey('OutsidePageSearchTarget')));
    await tester.pump();

    expect(editableTextState.widget.focusNode.hasFocus, isFalse);
  });

  testWidgets('PageSearchField search icon slot is square', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 260,
            child: PageSearchField(
              value: '',
              hintText: 'Search',
              focused: false,
              onChanged: (_) {},
              onFocusChanged: (_) {},
              onSubmitted: () {},
              onClear: () {},
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byType(SearchCommitIconButton)),
      const Size.square(40),
    );
  });

  testWidgets('PageSearchField fills Electron input height', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 260,
            child: PageSearchField(
              value: '',
              hintText: 'Search',
              focused: false,
              onChanged: (_) {},
              onFocusChanged: (_) {},
              onSubmitted: () {},
              onClear: () {},
            ),
          ),
        ),
      ),
    );

    final textField = tester.widget<EditableText>(find.byType(EditableText));
    expect(textField.cursorHeight, isNull);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.decoration?.isCollapsed, isTrue);
    expect(tester.getSize(find.byType(TextField)).height, 40);
  });
}

BoxDecoration _fieldDecoration(WidgetTester tester) {
  return tester
          .widget<DecoratedBox>(
            find
                .descendant(
                  of: find.byType(PageSearchField),
                  matching: find.byType(DecoratedBox),
                )
                .first,
          )
          .decoration
      as BoxDecoration;
}
