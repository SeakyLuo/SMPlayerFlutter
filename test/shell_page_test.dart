import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smplayer_flutter/src/app/shell_page.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('shell matches Electron navigation breakpoints', () {
    expect(
      SmPlayerShellMetrics.navigationModeForWidth(719),
      SmPlayerNavigationMode.minimal,
    );
    expect(
      SmPlayerShellMetrics.navigationModeForWidth(720),
      SmPlayerNavigationMode.overlay,
    );
    expect(
      SmPlayerShellMetrics.navigationModeForWidth(1199),
      SmPlayerNavigationMode.overlay,
    );
    expect(
      SmPlayerShellMetrics.navigationModeForWidth(1200),
      SmPlayerNavigationMode.wide,
    );
  });

  testWidgets('shell uses Electron wide layout metrics', (tester) async {
    _setViewSize(tester, const Size(1300, 600));

    await tester.pumpWidget(const _ShellPageTestApp());

    final sidebar = find.byKey(SmPlayerShellKeys.sidebar);
    final workspace = find.byKey(SmPlayerShellKeys.workspace);
    final reservedPlayer = find.byKey(SmPlayerShellKeys.reservedPlayer);

    expect(tester.getSize(sidebar).width, SmPlayerShellMetrics.sidebarWidth);
    expect(
      tester.getSize(sidebar).height,
      600 - SmPlayerShellMetrics.playerHeight,
    );
    expect(tester.getTopLeft(workspace).dx, SmPlayerShellMetrics.sidebarWidth);
    expect(
      tester.getSize(workspace).height,
      600 -
          SmPlayerShellMetrics.playerHeight +
          SmPlayerShellMetrics.playerTopRadius,
    );
    expect(
      tester.getSize(reservedPlayer).height,
      SmPlayerShellMetrics.playerHeight,
    );
  });

  testWidgets('shell collapses navigation to Electron rail width', (
    tester,
  ) async {
    _setViewSize(tester, const Size(1300, 600));

    await tester.pumpWidget(const _ShellPageTestApp());
    await tester.tap(
      find.byKey(const ValueKey('MainNavigationView.TogglePaneButton')),
    );
    await tester.pumpAndSettle();

    final sidebar = find.byKey(SmPlayerShellKeys.sidebar);
    final workspace = find.byKey(SmPlayerShellKeys.workspace);

    expect(
      tester.getSize(sidebar).width,
      SmPlayerShellMetrics.collapsedSidebarWidth,
    );
    expect(
      tester.getTopLeft(workspace).dx,
      SmPlayerShellMetrics.collapsedSidebarWidth,
    );
  });

  testWidgets('overlay navigation opens above the 64px shell rail', (
    tester,
  ) async {
    _setViewSize(tester, const Size(800, 600));

    await tester.pumpWidget(const _ShellPageTestApp());
    await tester.pumpAndSettle();

    final sidebar = find.byKey(SmPlayerShellKeys.sidebar);
    final workspace = find.byKey(SmPlayerShellKeys.workspace);

    expect(tester.getSize(sidebar).width, SmPlayerShellMetrics.sidebarWidth);
    expect(
      tester.getTopLeft(workspace).dx,
      SmPlayerShellMetrics.collapsedSidebarWidth,
    );
  });

  testWidgets('minimal navigation starts as Electron rail layout', (
    tester,
  ) async {
    _setViewSize(tester, const Size(600, 600));

    await tester.pumpWidget(const _ShellPageTestApp());
    await tester.pump();

    expect(
      tester.getSize(find.byKey(SmPlayerShellKeys.sidebar)).width,
      SmPlayerShellMetrics.collapsedSidebarWidth,
    );
    expect(
      tester.getTopLeft(find.byKey(SmPlayerShellKeys.workspace)).dx,
      SmPlayerShellMetrics.collapsedSidebarWidth,
    );
  });

  testWidgets('navigation mode changes follow Electron collapse rules', (
    tester,
  ) async {
    _setViewSize(tester, const Size(1300, 600));

    await tester.pumpWidget(const _ShellPageTestApp());
    await tester.pump();
    expect(
      tester.getSize(find.byKey(SmPlayerShellKeys.sidebar)).width,
      SmPlayerShellMetrics.sidebarWidth,
    );

    _setViewSize(tester, const Size(800, 600), resetAfterTest: false);
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(SmPlayerShellKeys.sidebar)).width,
      SmPlayerShellMetrics.collapsedSidebarWidth,
    );

    _setViewSize(tester, const Size(1300, 600), resetAfterTest: false);
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(SmPlayerShellKeys.sidebar)).width,
      SmPlayerShellMetrics.sidebarWidth,
    );
  });

  testWidgets('shell restores Electron navigation collapsed storage state', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      SmPlayerShellStorageKeys.navigationCollapsed: true,
    });
    _setViewSize(tester, const Size(800, 600));

    await tester.pumpWidget(const _ShellPageTestApp());
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byKey(SmPlayerShellKeys.sidebar)).width,
      SmPlayerShellMetrics.collapsedSidebarWidth,
    );
  });

  testWidgets('shell persists navigation collapsed changes', (tester) async {
    _setViewSize(tester, const Size(800, 600));

    await tester.pumpWidget(const _ShellPageTestApp());
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('MainNavigationView.TogglePaneButton')),
    );
    await tester.pumpAndSettle();

    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getBool(SmPlayerShellStorageKeys.navigationCollapsed),
      isTrue,
    );
  });
}

class _ShellPageTestApp extends StatelessWidget {
  const _ShellPageTestApp();

  @override
  Widget build(BuildContext context) {
    return const ProviderScope(
      child: SmPlayerI18nScope(
        i18n: SmPlayerI18n(locale: 'en-US', messages: {}),
        child: MaterialApp(home: SmPlayerShellPage()),
      ),
    );
  }
}

void _setViewSize(
  WidgetTester tester,
  Size size, {
  bool resetAfterTest = true,
}) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  if (resetAfterTest) {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }
}
