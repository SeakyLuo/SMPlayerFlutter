import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/ui/popup_dialog.dart';

void main() {
  testWidgets('writes popup delete hover verification screenshot', (
    tester,
  ) async {
    final repaintKey = GlobalKey();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1118, 626);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    await tester.pumpWidget(
      RepaintBoundary(
        key: repaintKey,
        child: SmPlayerI18nScope(
          i18n: _i18n,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              backgroundColor: const Color(0xffd8dde3),
              body: Center(
                child: Builder(
                  builder: (context) {
                    return TextButton(
                      onPressed: () {
                        showPopupConfirmDialog(
                          context: context,
                          title: '删除',
                          message: '从磁盘删除“Clockwork Reverie”？',
                          confirmLabel: '删除',
                        );
                      },
                      child: const Text('打开'),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(
      location: tester.getCenter(find.widgetWithText(TextButton, '删除')),
    );
    addTearDown(mouse.removePointer);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.runAsync(() async {
      final boundary =
          repaintKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      await File(
        '/tmp/smplayer_popup_delete_hover_verify.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
    });
  });
}

const _i18n = SmPlayerI18n(locale: 'zh-CN', messages: {'common.cancel': '取消'});
