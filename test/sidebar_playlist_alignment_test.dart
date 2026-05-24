import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smplayer_flutter/src/app/main_navigation_view.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/settings/settings_controller.dart';

const testI18n = SmPlayerI18n(
  locale: 'zh-CN',
  messages: {
    'app.shell': '简音播放器',
    'library.title': '音乐库',
    'common.artists': '歌手',
    'common.albums': '专辑',
    'common.local': '本地',
    'common.recent': '最近',
    'common.nowPlaying': '正在播放',
    'common.myFavorites': '我喜欢',
    'common.playlists': '播放列表',
    'common.settings': '设置',
    'common.search': '搜索',
    'common.clear': '清空',
    'context.play': '播放',
    'sidebar.back': 'Back',
    'sidebar.library': '音乐库',
    'sidebar.playback': '播放',
    'sidebar.collapseNavigation': '收起导航',
    'sidebar.expandNavigation': '展开导航',
    'sidebar.recentSearches': '最近搜索',
    'sidebar.removeRecentSearch': '移除最近搜索 {query}',
    'playlists.createNew': '创建新播放列表',
    'playlists.duplicate': '复制播放列表',
    'playlists.rename': '重命名',
    'playlists.delete': '删除',
    'nowPlaying.randomPlay': '随机播放',
  },
);

void main() {
  setUp(() {
    resetSmPlayerGlobalSettingsSnapshot();
  });

  testWidgets('sidebar playlist heading and child match Electron spacing', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(420, 1000);
    var randomPlaylistId = 0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 320,
          height: 720,
          child: MainNavigationView(
            isPaneOpen: true,
            currentPath: '/playlists',
            searchText: '',
            i18n: testI18n,
            playlists: const [
              LibraryPlaylist(
                id: 7,
                name: '播放列表',
                priority: 1,
                songCount: 2,
                songIds: [1, 2],
                sortCriterion: PlaylistSortCriterion.title,
                isBuiltIn: false,
              ),
            ],
            onPaneToggle: () {},
            onSearchTextChanged: (_) {},
            onSearchCommitted: (_, [__ = SearchHistoryType.sidebar]) {},
            onSearchCleared: () {},
            onItemInvoked: (_) {},
            onCreatePlaylist: () {},
            onPlaylistRandomPlay: (playlistId) {
              randomPlaylistId = playlistId;
            },
          ),
        ),
      ),
    );

    final heading = find.byKey(
      const ValueKey('MainNavigationView.PlaylistsHeadingItem'),
    );
    final child = find.byKey(const ValueKey('PlaylistItem.7'));
    final headingRect = tester.getRect(heading);
    final childRect = tester.getRect(child);

    expect(childRect.top - headingRect.bottom, 0);
    expect(childRect.height, 48);

    final headingText = find.descendant(
      of: heading,
      matching: find.text('播放列表'),
    );
    final childText = find.descendant(of: child, matching: find.text('播放列表'));

    expect(
      (tester.getTopLeft(childText).dx - tester.getTopLeft(headingText).dx)
          .abs(),
      lessThanOrEqualTo(1),
    );

    final randomIcon = find.descendant(
      of: child,
      matching: find.byIcon(FluentIcons.arrow_shuffle_20_regular),
    );
    expect(randomIcon, findsOneWidget);
    expect(
      tester
          .widget<Opacity>(
            find.ancestor(of: randomIcon, matching: find.byType(Opacity)).first,
          )
          .opacity,
      0,
    );

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer();
    await mouse.moveTo(tester.getCenter(child));
    await tester.pump();

    expect(
      tester
          .widget<Opacity>(
            find.ancestor(of: randomIcon, matching: find.byType(Opacity)).first,
          )
          .opacity,
      1,
    );

    await tester.tap(find.byTooltip('随机播放'));
    expect(randomPlaylistId, 7);
  });
}
