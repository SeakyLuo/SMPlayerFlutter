import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/ui/multi_select_command_bar.dart';

void main() {
  setUpAll(() async {
    final textFontData =
        await File('/System/Library/Fonts/Helvetica.ttc').readAsBytes();
    final textLoader = FontLoader('Roboto')..addFont(
      Future.value(ByteData.view(Uint8List.fromList(textFontData).buffer)),
    );
    await textLoader.load();

    final chineseFontData =
        await File('/System/Library/Fonts/STHeiti Medium.ttc').readAsBytes();
    final chineseLoader = FontLoader('SMPlayerTestChinese')..addFont(
      Future.value(ByteData.view(Uint8List.fromList(chineseFontData).buffer)),
    );
    await chineseLoader.load();

    final fluentIconData =
        await File(
          '${Platform.environment['HOME']}/.pub-cache/hosted/pub.dev/'
          'fluentui_system_icons-1.1.273/lib/fonts/'
          'FluentSystemIcons-Regular.ttf',
        ).readAsBytes();
    final fluentLoader = FontLoader(
      'packages/fluentui_system_icons/FluentSystemIcons-Regular',
    )..addFont(
      Future.value(ByteData.view(Uint8List.fromList(fluentIconData).buffer)),
    );
    await fluentLoader.load();
  });

  const i18n = SmPlayerI18n(
    locale: 'en-US',
    messages: {
      'common.cancel': 'Cancel',
      'common.myFavorites': 'Favorites',
      'albums.addSelectedTo': 'Add to',
      'albums.clearSelection': 'Clear...',
      'albums.playSelected': 'Play',
      'albums.reverseSelection': 'Invert',
      'albums.selectAll': 'Select',
      'albums.selectedCount': '{count} selected',
      'context.addToPlaylist': 'Add to',
      'context.removeFromList': 'Remove',
      'player.more': '更多',
      'playlists.newPlaylist': 'New Playlist',
    },
  );

  const zhI18n = SmPlayerI18n(
    locale: 'zh-CN',
    messages: {
      'common.cancel': '取消',
      'common.myFavorites': '我喜欢',
      'albums.addSelectedTo': '添加到',
      'albums.clearSelection': '清除...',
      'albums.playSelected': '播放',
      'albums.reverseSelection': '反选',
      'albums.selectAll': '全选',
      'albums.selectedCount': '已选择 {count} 项',
      'context.addToPlaylist': '添加到',
      'context.removeFromList': '移除',
      'player.more': '更多',
      'playlists.newPlaylist': '新建播放列表',
    },
  );

  testWidgets('desktop visual state', (tester) async {
    await _pumpVisualCase(
      tester,
      i18n: i18n,
      size: const Size(900, 260),
      brightness: Brightness.light,
    );

    await expectLater(
      find.byKey(_captureKey),
      matchesGoldenFile('goldens/multiselect_command_bar_desktop.png'),
    );
  });

  testWidgets('compact visual state at Electron 760 breakpoint', (
    tester,
  ) async {
    await _pumpVisualCase(
      tester,
      i18n: i18n,
      size: const Size(760, 260),
      brightness: Brightness.light,
    );

    await expectLater(
      find.byKey(_captureKey),
      matchesGoldenFile('goldens/multiselect_command_bar_760.png'),
    );
  });

  testWidgets('phone visual state at Electron 520 breakpoint', (tester) async {
    await _pumpVisualCase(
      tester,
      i18n: i18n,
      size: const Size(520, 260),
      brightness: Brightness.light,
    );

    await expectLater(
      find.byKey(_captureKey),
      matchesGoldenFile('goldens/multiselect_command_bar_520.png'),
    );
  });

  testWidgets('night visual state', (tester) async {
    await _pumpVisualCase(
      tester,
      i18n: i18n,
      size: const Size(900, 260),
      brightness: Brightness.dark,
    );

    await expectLater(
      find.byKey(_captureKey),
      matchesGoldenFile('goldens/multiselect_command_bar_night.png'),
    );
  });

  testWidgets('disabled visual state', (tester) async {
    await _pumpVisualCase(
      tester,
      i18n: i18n,
      size: const Size(900, 260),
      brightness: Brightness.light,
      selectedCount: 0,
    );

    await expectLater(
      find.byKey(_captureKey),
      matchesGoldenFile('goldens/multiselect_command_bar_disabled.png'),
    );
  });

  testWidgets('color blocks show through liquid glass surface', (tester) async {
    await _pumpVisualCase(
      tester,
      i18n: i18n,
      size: const Size(900, 260),
      brightness: Brightness.light,
      showColorBlocks: true,
    );

    await expectLater(
      find.byKey(_captureKey),
      matchesGoldenFile('goldens/multiselect_command_bar_color_blocks.png'),
    );
  });

  testWidgets('Chinese desktop visual state uses runtime CJK font', (
    tester,
  ) async {
    await _pumpVisualCase(
      tester,
      i18n: zhI18n,
      size: const Size(900, 260),
      brightness: Brightness.light,
      fontFamily: 'SMPlayerTestChinese',
    );

    await expectLater(
      find.byKey(_captureKey),
      matchesGoldenFile('goldens/multiselect_command_bar_zh_desktop.png'),
    );
  });

  testWidgets('Chinese compact visual state keeps Add To label', (
    tester,
  ) async {
    await _pumpVisualCase(
      tester,
      i18n: zhI18n,
      size: const Size(760, 260),
      brightness: Brightness.light,
      fontFamily: 'SMPlayerTestChinese',
    );

    await expectLater(
      find.byKey(_captureKey),
      matchesGoldenFile('goldens/multiselect_command_bar_zh_760.png'),
    );
  });
}

const _captureKey = ValueKey('MultiSelectCommandBar.VisualCapture');

Future<void> _pumpVisualCase(
  WidgetTester tester, {
  required SmPlayerI18n i18n,
  required Size size,
  required Brightness brightness,
  String fontFamily = 'Roboto',
  int selectedCount = 1,
  bool showColorBlocks = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final dark = brightness == Brightness.dark;
  await tester.pumpWidget(
    SmPlayerI18nScope(
      i18n: i18n,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(brightness: brightness),
        home: RepaintBoundary(
          key: _captureKey,
          child: Scaffold(
            backgroundColor: dark ? const Color(0xff0f1318) : Colors.white,
            body: Stack(
              children: [
                Positioned.fill(
                  child:
                      showColorBlocks
                          ? Row(
                            children: const [
                              Expanded(
                                child: ColoredBox(color: Color(0xffe95656)),
                              ),
                              Expanded(
                                child: ColoredBox(color: Color(0xff54c56d)),
                              ),
                              Expanded(
                                child: ColoredBox(color: Color(0xff4d8be8)),
                              ),
                              Expanded(
                                child: ColoredBox(color: Color(0xffd7b141)),
                              ),
                            ],
                          )
                          : DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors:
                                    dark
                                        ? const [
                                          Color(0xff0f1318),
                                          Color(0xff1e2935),
                                        ]
                                        : const [
                                          Color(0xffeef5fb),
                                          Color(0xffd9e5f0),
                                        ],
                              ),
                            ),
                          ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 18,
                  child: ColoredBox(
                    color:
                        dark
                            ? const Color(0xff111820)
                            : const Color(0xffdde9f5),
                  ),
                ),
                Positioned.fill(
                  child: DefaultTextStyle.merge(
                    style: TextStyle(fontFamily: fontFamily),
                    child: MultiSelectCommandBar(
                      visible: true,
                      bottomInset: multiSelectCommandBarShellBottomInset,
                      selectedCount: selectedCount,
                      addToSongIds: const [1],
                      includeNowPlayingInAddTo: true,
                      includeFavoritesInAddTo: true,
                      onAddToNowPlaying: () {},
                      onToggleFavorite: () {},
                      onPlay: () {},
                      onRemove: () {},
                      onSelectAll: () {},
                      onReverseSelection: () {},
                      onClearSelection: () {},
                      onCancel: () {},
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
