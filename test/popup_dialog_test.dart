import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:smplayer_flutter/src/app/app_interaction_colors.dart';
import 'package:smplayer_flutter/src/app/svg_icon.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/ui/popup_dialog.dart';

void main() {
  testWidgets('PopupDialog uses Electron desktop shell dimensions', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    var closed = false;
    await tester.pumpWidget(
      _TestApp(
        child: PopupDialog(
          navLabel: 'Dialog title',
          navChildren: const [Text('Dialog title')],
          onClose: () => closed = true,
          child: const SizedBox.shrink(),
        ),
      ),
    );

    expect(
      tester.getSize(find.byKey(const ValueKey('popup-dialog-shell'))),
      const Size(780, 760),
    );
    expect(find.byKey(const ValueKey('popup-dialog-close-button')), findsOne);
    expect(
      tester.getSize(find.byKey(const ValueKey('popup-dialog-close-button'))),
      const Size(42, 40),
    );
    expect(_closeButtonSurface(tester).color, const Color(0xebffffff));

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await gesture.moveTo(
      tester.getCenter(find.byKey(const ValueKey('popup-dialog-close-button'))),
    );
    await tester.pumpAndSettle();

    expect(_closeButtonSurface(tester).color, GlobalUI.buttonHoverBgColorDay);
    expect(
      tester.getSize(
        find.byKey(const ValueKey('popup-dialog-window-drag-strip')),
      ),
      const Size(1062, 32),
    );

    await tester.tap(find.byKey(const ValueKey('popup-dialog-close-button')));
    expect(closed, isTrue);
  });

  testWidgets('PopupDialog portal covers the root app overlay', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    await tester.pumpWidget(
      _TestApp(
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 300,
            height: 300,
            child: PopupDialog(
              navLabel: 'Dialog title',
              navChildren: const [Text('Dialog title')],
              onClose: () {},
              child: const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byKey(const ValueKey('popup-dialog-overlay'))),
      const Size(1200, 900),
    );
    final overlayGlass = tester.widget<GlassContainer>(
      find.byKey(const ValueKey('popup-dialog-overlay-glass')),
    );
    final overlayGlassSettings = overlayGlass.settings!;
    expect(overlayGlass.quality, GlassQuality.minimal);
    expect(overlayGlass.useOwnLayer, isTrue);
    expect(overlayGlass.allowElevation, isFalse);
    expect(overlayGlassSettings.blur, 46);
    expect(overlayGlassSettings.thickness, 20);
    expect(overlayGlassSettings.refractiveIndex, 1.06);
    expect(overlayGlassSettings.saturation, 1.65);
    expect(overlayGlassSettings.standardOpacityMultiplier, 0.24);
    expect(overlayGlassSettings.glassColor, PopupDialogColors.overlay);
    expect(
      tester.getSize(find.byKey(const ValueKey('popup-dialog-shell'))),
      const Size(780, 760),
    );
  });

  testWidgets('PopupDialog switches to Electron mobile shell at 720px', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(700, 520);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    var closed = false;
    await tester.pumpWidget(
      _TestApp(
        child: PopupDialog(
          navLabel: 'Dialog title',
          navChildren: const [Text('Dialog title')],
          onClose: () => closed = true,
          child: const SizedBox.shrink(),
        ),
      ),
    );

    expect(
      tester.getSize(find.byKey(const ValueKey('popup-dialog-shell'))),
      const Size(700, 520),
    );
    expect(
      find.byKey(const ValueKey('popup-dialog-close-button')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('popup-dialog-mobile-titlebar')),
      findsOne,
    );
    expect(
      tester.getSize(
        find.byKey(const ValueKey('popup-dialog-mobile-titlebar')),
      ),
      const Size(562, 32),
    );
    expect(
      tester.getTopLeft(
        find.byKey(const ValueKey('popup-dialog-mobile-back-button')),
      ),
      const Offset(8, 0),
    );
    expect(
      tester.getSize(
        find.byKey(const ValueKey('popup-dialog-mobile-back-button')),
      ),
      const Size(40, 32),
    );
    final backIcon = tester.widget<SvgIcon>(
      find.byKey(const ValueKey('popup-dialog-mobile-back-icon')),
    );
    expect(backIcon.size, 18);
    expect(_mobileBackButtonSurface(tester).color, Colors.transparent);

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await gesture.moveTo(
      tester.getCenter(
        find.byKey(const ValueKey('popup-dialog-mobile-back-button')),
      ),
    );
    await tester.pumpAndSettle();

    expect(_mobileBackButtonSurface(tester).color, const Color(0x12111827));

    await gesture.down(
      tester.getCenter(
        find.byKey(const ValueKey('popup-dialog-mobile-back-button')),
      ),
    );
    await tester.pump();
    expect(_mobileBackButtonSurface(tester).color, const Color(0x1f0078d7));
    await gesture.up();
    await tester.pump();

    await tester.tap(
      find.byKey(const ValueKey('popup-dialog-mobile-back-button')),
    );
    expect(closed, isTrue);
  });

  testWidgets('PopupDialog drag callbacks are wired to desktop strip', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    var starts = 0;
    var ends = 0;
    await tester.pumpWidget(
      _TestApp(
        child: PopupDialog(
          navLabel: 'Dialog title',
          navChildren: const [Text('Dialog title')],
          onClose: () {},
          onWindowDragStart: () => starts += 1,
          onWindowDragEnd: () => ends += 1,
          child: const SizedBox.shrink(),
        ),
      ),
    );

    await tester.dragFrom(const Offset(10, 10), const Offset(12, 0));

    expect(starts, 1);
    expect(ends, 1);
  });

  testWidgets('PopupDialog closes only the top dialog from stack', (
    tester,
  ) async {
    var firstClosed = false;
    var secondClosed = false;
    await tester.pumpWidget(
      _TestApp(
        child: Stack(
          children: [
            PopupDialog(
              navLabel: 'First',
              navChildren: const [Text('First')],
              onClose: () => firstClosed = true,
              child: const SizedBox.shrink(),
            ),
            PopupDialog(
              navLabel: 'Second',
              navChildren: const [Text('Second')],
              onClose: () => secondClosed = true,
              child: const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );

    expect(closeTopPopupDialog(), isTrue);
    expect(firstClosed, isFalse);
    expect(secondClosed, isTrue);
  });

  testWidgets('PopupDialog closes top dialog on Escape', (tester) async {
    var closed = false;
    await tester.pumpWidget(
      _TestApp(
        child: PopupDialog(
          navLabel: 'Dialog title',
          navChildren: const [Text('Dialog title')],
          onClose: () => closed = true,
          child: const SizedBox.shrink(),
        ),
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(closed, isTrue);
  });

  testWidgets('PopupDialog tabs fill mobile nav cells like Electron', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 520);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    await tester.pumpWidget(
      _TestApp(
        child: PopupDialog(
          className: 'music-dialog ContentDialog MusicDialog',
          navClassName: 'music-dialog-pivot MusicDialogPivot',
          navLabel: 'Dialog title',
          navChildren: [
            PopupDialogTab(
              label: 'Info',
              icon: Icons.info,
              selected: true,
              first: true,
              onPressed: () {},
            ),
            PopupDialogTab(
              label: 'Lyrics',
              icon: Icons.notes,
              selected: false,
              onPressed: () {},
            ),
            PopupDialogTab(
              label: 'Art',
              icon: Icons.image,
              selected: false,
              last: true,
              onPressed: () {},
            ),
          ],
          onClose: () {},
          child: const SizedBox.shrink(),
        ),
      ),
    );

    expect(
      tester.getSize(find.widgetWithText(TextButton, 'Info')).width,
      moreOrLessEquals(112),
    );
    expect(
      tester.getSize(find.widgetWithText(TextButton, 'Lyrics')).width,
      moreOrLessEquals(112),
    );
  });

  testWidgets('Popup confirm uses Electron input-dialog chrome', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    await tester.pumpWidget(
      _TestApp(
        child: Builder(
          builder:
              (context) => TextButton(
                onPressed: () {
                  showPopupConfirmDialog(
                    context: context,
                    title: 'Confirm',
                    message: 'Discard unsaved lyrics changes?',
                    confirmLabel: 'Confirm',
                  );
                },
                child: const Text('Open confirm'),
              ),
        ),
      ),
    );

    await tester.tap(find.text('Open confirm'));
    await tester.pumpAndSettle();

    expect(find.byType(BackdropFilter), findsOneWidget);
    final overlayDecorations = tester.widgetList<DecoratedBox>(
      find.descendant(
        of: find.byKey(const ValueKey('popup-dialog-overlay')),
        matching: find.byType(DecoratedBox),
      ),
    );
    expect(
      overlayDecorations.any((decoratedBox) {
        final decoration = decoratedBox.decoration;
        return decoration is BoxDecoration &&
            decoration.color == PopupDialogColors.overlay;
      }),
      isTrue,
    );

    final surfaceFinder = find.byKey(
      const ValueKey('popup-input-dialog-surface'),
    );
    expect(tester.getSize(surfaceFinder).width, 480);

    final decoration =
        (tester.widget<DecoratedBox>(surfaceFinder).decoration
            as BoxDecoration);
    expect(decoration.color, PopupDialogColors.surface);
    expect(decoration.borderRadius, BorderRadius.circular(12));
    expect(decoration.border, Border.all(color: const Color(0x2e768499)));
    expect(decoration.boxShadow, [
      const BoxShadow(
        color: Color(0x2435495f),
        blurRadius: 70,
        offset: Offset(0, 26),
      ),
    ]);
    final confirmText = tester.widget<Text>(
      find.descendant(
        of: find.widgetWithText(TextButton, 'Confirm'),
        matching: find.text('Confirm'),
      ),
    );
    final confirmButton = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Confirm'),
    );
    expect(
      confirmButton.style?.backgroundColor?.resolve(const <WidgetState>{}),
      PopupDialogColors.destructive,
    );
    expect(
      confirmButton.style?.backgroundColor?.resolve(const <WidgetState>{
        WidgetState.hovered,
      }),
      PopupDialogColors.destructiveHover,
    );
    expect(
      confirmButton.style?.backgroundColor?.resolve(const <WidgetState>{
        WidgetState.pressed,
      }),
      PopupDialogColors.destructiveHover,
    );
    expect(
      confirmButton.style?.overlayColor?.resolve(const <WidgetState>{
        WidgetState.hovered,
      }),
      Colors.transparent,
    );
    expect(confirmText.style?.fontSize, 16);
    expect(confirmText.style?.fontWeight, FontWeight.w700);
    final messageText = tester.widget<Text>(
      find.text('Discard unsaved lyrics changes?'),
    );
    expect(messageText.textAlign, TextAlign.center);
    expect(messageText.style?.fontSize, 15);
    expect(messageText.style?.fontWeight, isNull);
    expect(messageText.style?.height, 1.55);
  });
}

BoxDecoration _closeButtonSurface(WidgetTester tester) {
  final decoratedBox = tester.widget<DecoratedBox>(
    find.byKey(const ValueKey('popup-dialog-close-button-surface')),
  );
  return decoratedBox.decoration as BoxDecoration;
}

BoxDecoration _mobileBackButtonSurface(WidgetTester tester) {
  final decoratedBox = tester.widget<DecoratedBox>(
    find.byKey(const ValueKey('popup-dialog-mobile-back-button-surface')),
  );
  return decoratedBox.decoration as BoxDecoration;
}

class _TestApp extends StatelessWidget {
  const _TestApp({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SmPlayerI18nScope(
      i18n: const SmPlayerI18n(
        locale: 'en-US',
        messages: {
          'app.shell': 'Simple Melody Player',
          'common.close': 'Close',
        },
      ),
      child: MaterialApp(home: Material(child: child)),
    );
  }
}
