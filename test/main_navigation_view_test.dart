import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smplayer_flutter/src/app/main_navigation_view.dart';
import 'package:smplayer_flutter/src/app/shell_page.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';

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
    'sidebar.back': 'Back',
    'sidebar.library': '音乐库',
    'sidebar.playback': '播放',
    'sidebar.collapseNavigation': '收起导航',
    'sidebar.expandNavigation': '展开导航',
    'sidebar.recentSearches': '最近搜索',
    'sidebar.removeRecentSearch': '移除最近搜索 {query}',
    'playlists.createNew': '创建新播放列表',
    'nowPlaying.randomPlay': '随机播放',
  },
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('MainNavigationViewItem matches Electron route selection rules', () {
    const songsItem = MainNavigationViewItem(
      name: 'MusicLibraryItem',
      target: '/songs',
      label: '音乐库',
      icon: Icons.music_note,
    );
    const playlistsItem = MainNavigationViewItem(
      name: 'PlaylistsItem',
      target: '/playlists',
      label: '播放列表',
      icon: Icons.playlist_play,
      exactActive: true,
    );

    expect(songsItem.isActive('/songs'), isTrue);
    expect(songsItem.isActive('/songs/album'), isTrue);
    expect(songsItem.isActive('/search'), isFalse);
    expect(playlistsItem.isActive('/playlists'), isTrue);
    expect(playlistsItem.isActive('/playlists/1'), isFalse);
  });

  testWidgets('invokes UWP-named navigation items with Electron targets', (
    tester,
  ) async {
    var invokedTarget = '';

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 320,
          height: 900,
          child: MainNavigationView(
            isPaneOpen: true,
            currentPath: '/songs',
            searchText: '',
            i18n: testI18n,
            onPaneToggle: () {},
            onSearchTextChanged: (_) {},
            onSearchCommitted: (_, [__ = SearchHistoryType.sidebar]) {},
            onItemInvoked: (target) {
              invokedTarget = target;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('RecentItem')));
    expect(invokedTarget, '/recent');

    await tester.tap(find.byKey(const ValueKey('MyFavoritesItem')));
    expect(invokedTarget, '/favorites');

    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('SettingsItem')));
    expect(invokedTarget, '/settings');
  });

  testWidgets('collapsed search button asks shell to open the pane', (
    tester,
  ) async {
    var toggleCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 64,
          height: 900,
          child: MainNavigationView(
            isPaneOpen: false,
            currentPath: '/songs',
            searchText: '',
            i18n: testI18n,
            onPaneToggle: () {
              toggleCount += 1;
            },
            onSearchTextChanged: (_) {},
            onSearchCommitted: (_, [__ = SearchHistoryType.sidebar]) {},
            onItemInvoked: (_) {},
          ),
        ),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey('MainNavigationView.SearchButton')),
    );

    expect(toggleCount, 1);
  });

  testWidgets('back button follows Electron sidebar title behavior', (
    tester,
  ) async {
    var backCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 320,
          height: 900,
          child: MainNavigationView(
            isPaneOpen: true,
            currentPath: '/playlists/7',
            searchText: '',
            i18n: testI18n,
            canGoBack: true,
            onPaneToggle: () {},
            onGoBack: () {
              backCount += 1;
            },
            onSearchTextChanged: (_) {},
            onSearchCommitted: (_, [__ = SearchHistoryType.sidebar]) {},
            onItemInvoked: (_) {},
          ),
        ),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey('MainNavigationView.BackButton')),
    );

    expect(backCount, 1);
  });

  testWidgets('search box reports typed, submitted, and cleared values', (
    tester,
  ) async {
    var committedText = '';
    var changedText = '';

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 320,
          height: 900,
          child: MainNavigationView(
            isPaneOpen: true,
            currentPath: '/songs',
            searchText: 'abc',
            i18n: testI18n,
            onPaneToggle: () {},
            onSearchTextChanged: (value) {
              changedText = value;
            },
            onSearchCommitted: (value, [type = SearchHistoryType.sidebar]) {
              committedText = value;
            },
            onItemInvoked: (_) {},
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('MainNavigationView.SearchTextField')),
      '  Jazz  ',
    );
    expect(changedText, '  Jazz  ');

    await tester.testTextInput.receiveAction(TextInputAction.search);
    expect(committedText, '  Jazz  ');

    await tester.tap(
      find.byKey(const ValueKey('MainNavigationView.ClearSearchButton')),
    );
    expect(changedText, '');
  });

  testWidgets('sidebar renders recent searches like Electron dropdown', (
    tester,
  ) async {
    var committedText = '';
    var removedId = 0;
    var cleared = false;

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 320,
          height: 720,
          child: MainNavigationView(
            isPaneOpen: true,
            currentPath: '/songs',
            searchText: '',
            i18n: testI18n,
            recentSearches: const [
              SearchHistoryEntry(
                id: 7,
                query: 'Jazz',
                type: SearchHistoryType.sidebar,
                searchedAt: '2026-05-20T00:00:00Z',
              ),
              SearchHistoryEntry(
                id: 8,
                query: 'Album only',
                type: SearchHistoryType.albums,
                searchedAt: '2026-05-20T00:00:00Z',
              ),
            ],
            onPaneToggle: () {},
            onSearchTextChanged: (_) {},
            onSearchCommitted: (value, [type = SearchHistoryType.sidebar]) {
              committedText = value;
            },
            onItemInvoked: (_) {},
            onRecentSearchRemove: (entryId) {
              removedId = entryId;
            },
            onRecentSearchesClear: () {
              cleared = true;
            },
          ),
        ),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey('MainNavigationView.SearchTextField')),
    );
    await tester.pump();

    expect(find.text('最近搜索'), findsOneWidget);
    expect(find.text('Jazz'), findsOneWidget);
    expect(find.text('Album only'), findsNothing);

    await tester.tap(find.text('Jazz'));
    expect(committedText, 'Jazz');

    await tester.tap(
      find.byKey(const ValueKey('MainNavigationView.SearchTextField')),
    );
    await tester.pump();
    await tester.tap(find.byTooltip('移除最近搜索 Jazz'));
    expect(removedId, 7);

    await tester.tap(find.text('清空'));
    expect(cleared, isTrue);
  });

  testWidgets('sidebar playlist group expands and invokes playlist actions', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(420, 1000);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    var invokedTarget = '';
    var createRequested = false;
    var randomPlaylistId = 0;

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
                id: 3,
                name: 'Built in',
                priority: 0,
                songCount: 1,
                songIds: [1],
                sortCriterion: PlaylistSortCriterion.title,
                isBuiltIn: true,
              ),
              LibraryPlaylist(
                id: 7,
                name: 'Road Mix',
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
            onItemInvoked: (target) {
              invokedTarget = target;
            },
            onCreatePlaylist: () {
              createRequested = true;
            },
            onPlaylistRandomPlay: (playlistId) {
              randomPlaylistId = playlistId;
            },
          ),
        ),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey('MainNavigationView.CreatePlaylistButton')),
    );
    expect(createRequested, isTrue);

    await tester.tap(
      find.byKey(
        const ValueKey('MainNavigationView.TogglePlaylistSectionButton'),
      ),
    );
    await tester.pump();

    expect(find.text('Road Mix'), findsOneWidget);
    expect(find.text('Built in'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('PlaylistItem.7')));
    expect(invokedTarget, '/playlists/7');

    await tester.tap(find.byTooltip('随机播放'));
    expect(randomPlaylistId, 7);
  });

  testWidgets('shell trims committed sidebar searches', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1300, 600);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const MaterialApp(home: SmPlayerShellPage()));

    await tester.enterText(
      find.byKey(const ValueKey('MainNavigationView.SearchTextField')),
      '  Jazz  ',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();

    final textField = tester.widget<TextField>(
      find.byKey(const ValueKey('MainNavigationView.SearchTextField')),
    );
    expect(textField.controller?.text, 'Jazz');
  });
}
