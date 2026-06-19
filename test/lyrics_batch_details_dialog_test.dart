import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_repository.dart';
import 'package:smplayer_flutter/src/settings/lyrics_batch_details_dialog.dart';

void main() {
  testWidgets('LyricsBatchDetailsDialog uses PopupDialog desktop shell', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    await tester.pumpWidget(_TestApp(result: _mixedResult));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('popup-dialog-shell')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('popup-dialog-shell'))),
      const Size(1136, 836),
    );
    expect(find.byKey(const ValueKey('popup-dialog-close-button')), findsOne);
    expect(find.text('歌词任务详情'), findsOneWidget);

    final contentPadding = tester.widget<Padding>(
      find.byKey(const ValueKey('lyrics-detail-dialog-content')),
    );
    expect(contentPadding.padding, const EdgeInsets.fromLTRB(28, 18, 28, 28));
    expect(
      _boxDecoration(tester, 'lyrics-detail-status-saved').color,
      const Color(0xffdcfce7),
    );
    expect(
      _boxDecoration(tester, 'lyrics-detail-group-count-overwritten').color,
      const Color(0xffffedd5),
    );

    expect(
      tester.getTopLeft(find.widgetWithText(TextButton, '覆盖')).dy,
      lessThan(tester.getTopLeft(find.widgetWithText(TextButton, '保存')).dy),
    );

    await tester.tap(find.text('Track A'));
    await tester.pumpAndSettle();

    expect(find.text('Lyrics A'), findsOneWidget);
    expect(find.text('Before lyric'), findsNothing);
    expect(
      _boxDecoration(tester, 'lyrics-detail-inline-panel').color,
      const Color(0xfffbfdff),
    );
    final expandedPanel = _boxDecoration(
      tester,
      'lyrics-detail-expanded-panel',
    );
    expect(expandedPanel.border, isNotNull);
    expect(expandedPanel.borderRadius, BorderRadius.circular(14));
    expect(
      _boxDecoration(tester, 'lyrics-detail-text-preview').borderRadius,
      BorderRadius.circular(12),
    );
    expect(_textStyle(tester, 'Lyrics A').fontFamily, 'monospace');

    await tester.tap(find.text('Track C'));
    await tester.pumpAndSettle();

    expect(find.text('Lyrics A'), findsNothing);
    expect(find.text('Before lyric'), findsOneWidget);
    expect(find.text('After lyric'), findsOneWidget);
    expect(
      _boxDecoration(tester, 'lyrics-detail-inline-panel').color,
      Colors.white,
    );
  });

  testWidgets('LyricsBatchDetailsDialog stacks overwritten lyrics on mobile', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(700, 520);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    await tester.pumpWidget(_TestApp(result: _overwrittenResult));
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byKey(const ValueKey('popup-dialog-shell'))),
      const Size(700, 520),
    );
    final contentPadding = tester.widget<Padding>(
      find.byKey(const ValueKey('lyrics-detail-dialog-content')),
    );
    expect(contentPadding.padding, const EdgeInsets.fromLTRB(16, 14, 16, 0));

    await tester.tap(find.text('Track C'));
    await tester.pumpAndSettle();

    expect(find.byIcon(FluentIcons.arrow_down_20_regular), findsOneWidget);
    expect(find.byIcon(FluentIcons.arrow_right_20_regular), findsNothing);
  });

  testWidgets('LyricsBatchDetailsDialog expands duplicate details separately', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    await tester.pumpWidget(_TestApp(result: _duplicateResult));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Duplicate').first);
    await tester.pumpAndSettle();

    expect(find.text('First lyrics'), findsOneWidget);
    expect(find.text('Second lyrics'), findsNothing);

    await tester.tap(find.text('Duplicate').last);
    await tester.pumpAndSettle();

    expect(find.text('First lyrics'), findsNothing);
    expect(find.text('Second lyrics'), findsOneWidget);
  });
}

BoxDecoration _boxDecoration(WidgetTester tester, String key) {
  final widget = tester.widget(find.byKey(ValueKey(key)));
  return switch (widget) {
    DecoratedBox(:final decoration) => decoration as BoxDecoration,
    Container(:final decoration) => decoration! as BoxDecoration,
    _ => throw StateError('Widget $key does not expose a BoxDecoration'),
  };
}

TextStyle _textStyle(WidgetTester tester, String text) {
  final richText = tester.widget<RichText>(
    find
        .descendant(
          of: find.byKey(const ValueKey('lyrics-detail-text-preview')),
          matching: find.byType(RichText),
        )
        .last,
  );
  expect(richText.text.toPlainText(), text);
  return richText.text.style!;
}

class _TestApp extends StatelessWidget {
  const _TestApp({required this.result});

  final LyricsBatchResult result;

  @override
  Widget build(BuildContext context) {
    return SmPlayerI18nScope(
      i18n: const SmPlayerI18n(locale: 'zh-CN', messages: _messages),
      child: MaterialApp(
        home: Scaffold(
          body: LyricsBatchDetailsDialog(result: result, onClose: () {}),
        ),
      ),
    );
  }
}

const _mixedResult = LyricsBatchResult(
  total: 2,
  saved: 1,
  overwritten: 1,
  skipped: 0,
  missing: 0,
  failed: 0,
  backedUp: 1,
  backupBytes: 12,
  details: [
    LyricsBatchDetail(
      songId: 1,
      title: 'Track A',
      artist: 'Artist A',
      thumbnailPath: '',
      result: LyricsBatchDetailResult.saved,
      targetRawLyrics: 'Lyrics A',
    ),
    LyricsBatchDetail(
      songId: 3,
      title: 'Track C',
      artist: 'Artist C',
      thumbnailPath: '',
      result: LyricsBatchDetailResult.overwritten,
      sourceRawLyrics: 'Before lyric',
      targetRawLyrics: 'After lyric',
    ),
  ],
);

const _overwrittenResult = LyricsBatchResult(
  total: 1,
  saved: 0,
  overwritten: 1,
  skipped: 0,
  missing: 0,
  failed: 0,
  backedUp: 1,
  backupBytes: 12,
  details: [
    LyricsBatchDetail(
      songId: 3,
      title: 'Track C',
      artist: 'Artist C',
      thumbnailPath: '',
      result: LyricsBatchDetailResult.overwritten,
      sourceRawLyrics: 'Before lyric',
      targetRawLyrics: 'After lyric',
    ),
  ],
);

const _duplicateResult = LyricsBatchResult(
  total: 2,
  saved: 2,
  overwritten: 0,
  skipped: 0,
  missing: 0,
  failed: 0,
  backedUp: 0,
  backupBytes: 0,
  details: [
    LyricsBatchDetail(
      songId: 7,
      title: 'Duplicate',
      artist: 'Artist',
      thumbnailPath: '',
      result: LyricsBatchDetailResult.saved,
      targetRawLyrics: 'First lyrics',
    ),
    LyricsBatchDetail(
      songId: 7,
      title: 'Duplicate',
      artist: 'Artist',
      thumbnailPath: '',
      result: LyricsBatchDetailResult.saved,
      targetRawLyrics: 'Second lyrics',
    ),
  ],
);

const _messages = {
  'common.close': '关闭',
  'settings.lyricsBatchAgainOverwrite': '再次覆盖',
  'settings.lyricsBatchCancelOverwrite': '取消覆盖',
  'settings.lyricsBatchCurrentLyrics': '当前歌词',
  'settings.lyricsBatchDetailNoLyrics': '无歌词',
  'settings.lyricsBatchDetailWrittenLyrics': '写入歌词',
  'settings.lyricsBatchFailed': '失败',
  'settings.lyricsBatchMissing': '未找到',
  'settings.lyricsBatchNewLyrics': '新歌词',
  'settings.lyricsBatchNewVersion': '新版本',
  'settings.lyricsBatchOldVersion': '旧版本',
  'settings.lyricsBatchOverwritten': '覆盖',
  'settings.lyricsBatchOverwriteWarning': '覆盖会替换当前歌词。',
  'settings.lyricsBatchReasonAlreadyExists': '已有歌词',
  'settings.lyricsBatchReasonSameContent': '内容相同',
  'settings.lyricsBatchSaved': '保存',
  'settings.lyricsBatchSkipped': '跳过',
  'settings.lyricsBatchTaskDetails': '歌词任务详情',
};
