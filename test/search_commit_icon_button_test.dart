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
    await tester.enterText(find.byType(TextField), 'abc123');
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      'abc123',
    );

    hintText = 'Search albums';
    await pumpField();
    await tester.pump();

    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
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

    final icon = tester.widget<Icon>(
      find.byIcon(FluentIcons.search_24_regular),
    );
    expect(icon.color, const Color(0xadcbd5e1));

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.style?.color, const Color(0xf0f6f9fc));
    expect(field.decoration?.hintStyle?.color, const Color(0x85dee7f2));
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

    final icon = tester.widget<Icon>(
      find.byIcon(FluentIcons.search_24_regular),
    );
    expect(icon.color, const Color(0xff459de2));

    final hoverDecorations = tester
        .widgetList<DecoratedBox>(
          find.descendant(
            of: find.byType(SearchCommitIconButton),
            matching: find.byType(DecoratedBox),
          ),
        )
        .map((widget) => widget.decoration)
        .whereType<BoxDecoration>()
        .where((decoration) => decoration.color == const Color(0x2e0078d7));
    expect(hoverDecorations, isNotEmpty);
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
