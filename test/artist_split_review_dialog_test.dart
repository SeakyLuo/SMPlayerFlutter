import 'dart:async';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/ui/default_album_artwork.dart';
import 'package:smplayer_flutter/src/library/ui/folder_update_result_dialog.dart';
import 'package:smplayer_flutter/src/library/ui/local_folder_model.dart';
import 'package:smplayer_flutter/src/settings/artist_split_review_dialog.dart';

void main() {
  const i18n = SmPlayerI18n(
    locale: 'zh-CN',
    messages: {
      'common.add': '添加',
      'common.close': '关闭',
      'common.edit': '编辑',
      'local.applyingArtistSplits': '正在更新...',
      'local.applySelectedArtistSplits': '更新歌手（{count}）',
      'local.artistMergeAfter': '合并后',
      'local.artistMergeSuggestionsTitle': '可以合并的歌手',
      'local.artistSplitAfter': '拆分后',
      'local.artistSplitOriginal': '原始',
      'local.clearArtistSplitSelection': '清空选择',
      'local.directArtistSplitsTitle': '可以直接拆分',
      'local.libraryRoot': '音乐库',
      'local.keepArtistSplits': '保持原样',
      'local.refreshArtistUpdatesTab': '歌手',
      'local.refreshArtistSplitSuggestionsTitle': '可能的多歌手',
      'local.selectAllArtistSplits': '全选',
      'local.startupArtistSplitSuggestionsTitle': '歌手更新建议',
      'local.updateResultOfFolder': '{name} 更新结果',
      'playlists.removeSelected': '删除',
      'settings.save': '保存',
    },
  );

  testWidgets('ArtistSplitReviewDialog applies edited artist cells', (
    tester,
  ) async {
    final directSplit = ArtistSplitResultItem(
      songId: 1,
      title: 'Collab Song',
      artist: 'Alpha / Beta',
      artists: const ['Alpha', 'Beta'],
    );
    List<ArtistSplitResultItem>? appliedSplits;

    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp(
          theme: ThemeData(
            extensions: const [DefaultAlbumArtworkThemeColors.light],
          ),
          home: ArtistSplitReviewDialog(
            result: ArtistSplitAnalysisResult(
              directSplits: [directSplit],
              possibleSplits: const [],
              mergeSuggestions: const [],
            ),
            applying: false,
            onCancel: () {},
            onApply: (splits) {
              appliedSplits = splits;
            },
          ),
        ),
      ),
    );

    expect(find.text('歌手更新建议'), findsOneWidget);
    expect(find.text('可以直接拆分'), findsOneWidget);
    expect(find.text('Alpha / Beta'), findsOneWidget);
    expect(find.text('更新歌手（1）'), findsOneWidget);

    await tester.tap(find.byIcon(FluentIcons.edit_20_regular));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Beta'), 'Gamma');
    await tester.tap(find.byIcon(FluentIcons.checkmark_20_regular).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('更新歌手（1）'));
    await tester.pump();

    expect(appliedSplits, isNotNull);
    expect(appliedSplits!.single.songId, 1);
    expect(appliedSplits!.single.artists, ['Alpha', 'Gamma']);
  });

  testWidgets('FolderUpdateResultDialog reuses artist split review panel', (
    tester,
  ) async {
    final directSplit = ArtistSplitResultItem(
      songId: 1,
      title: 'Direct Song',
      artist: 'Alpha / Beta',
      artists: const ['Alpha', 'Beta'],
    );
    final possibleSplit = ArtistSplitResultItem(
      songId: 2,
      title: 'Maybe Song',
      artist: 'Gamma feat Delta',
      artists: const ['Gamma', 'Delta'],
    );
    List<ArtistSplitResultItem>? appliedSplits;

    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp(
          theme: ThemeData(
            extensions: const [DefaultAlbumArtworkThemeColors.light],
          ),
          home: FolderUpdateResultDialog(
            folder: createFolderNode('', '/Users/me/Music'),
            result: LocalFolderRefreshResult(
              filesAdded: const [],
              filesRemoved: const [],
              filesMoved: const [],
              artistSplitsApplied: [directSplit],
              artistSplitSuggestions: [possibleSplit],
              artistMergeSuggestions: const [],
            ),
            songs: const [],
            selectedTrackId: null,
            isPlaying: false,
            onPlay: (_) {},
            onApplyArtistSplits: (splits) {
              appliedSplits = splits;
            },
            onDismissArtistSplitSuggestions: () {},
            onClose: () {},
          ),
        ),
      ),
    );

    expect(find.text('歌手'), findsOneWidget);
    expect(find.text('可以直接拆分'), findsOneWidget);
    expect(find.text('可能的多歌手'), findsOneWidget);
    expect(find.text('Direct Song'), findsOneWidget);
    expect(find.text('Maybe Song'), findsOneWidget);
    expect(find.text('更新歌手（1）'), findsOneWidget);

    await tester.tap(find.text('Maybe Song'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('更新歌手（2）'));
    await tester.pump();

    expect(appliedSplits, isNotNull);
    expect(appliedSplits!.map((split) => split.songId), [1, 2]);
  });

  testWidgets('ArtistSplitReviewPanel waits for async apply callback', (
    tester,
  ) async {
    final applyCompleter = Completer<void>();

    await tester.pumpWidget(
      SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp(
          theme: ThemeData(
            extensions: const [DefaultAlbumArtworkThemeColors.light],
          ),
          home: Material(
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 760,
                height: 640,
                child: ArtistSplitReviewPanel(
                  directSplits: const [
                    ArtistSplitResultItem(
                      songId: 1,
                      title: 'Collab Song',
                      artist: 'Alpha / Beta',
                      artists: ['Alpha', 'Beta'],
                    ),
                  ],
                  possibleSplits: const [],
                  mergeSuggestions: const [],
                  applying: false,
                  onClose: () {},
                  onApply: (_) => applyCompleter.future,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('更新歌手（1）'));
    await tester.pump();

    expect(find.text('正在更新...'), findsOneWidget);

    applyCompleter.complete();
    await tester.pump();
    await tester.pump();

    expect(find.text('更新歌手（1）'), findsOneWidget);
  });

  testWidgets(
    'ArtistSplitReviewPanel uses compact group controls under 520px',
    (tester) async {
      await tester.pumpWidget(
        SmPlayerI18nScope(
          i18n: i18n,
          child: MaterialApp(
            theme: ThemeData(
              extensions: const [DefaultAlbumArtworkThemeColors.light],
            ),
            home: Material(
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 500,
                  height: 640,
                  child: ArtistSplitReviewPanel(
                    directSplits: const [
                      ArtistSplitResultItem(
                        songId: 1,
                        title: 'Collab Song',
                        artist: 'Alpha / Beta',
                        artists: ['Alpha', 'Beta'],
                      ),
                    ],
                    possibleSplits: const [],
                    mergeSuggestions: const [],
                    applying: false,
                    onClose: () {},
                    onApply: (_) {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      final toggleButton = find.ancestor(
        of: find.text('可以直接拆分'),
        matching: find.byType(TextButton),
      );

      expect(find.text('清空选择'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) => widget is SizedBox && widget.width == 76,
        ),
        findsOneWidget,
      );
      expect(tester.getSize(toggleButton).height, 40);
    },
  );
}
