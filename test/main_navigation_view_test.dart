import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:smplayer_flutter/src/app/app_appearance_model.dart';
import 'package:smplayer_flutter/src/app/main_navigation_view.dart';
import 'package:smplayer_flutter/src/app/shell_models.dart';
import 'package:smplayer_flutter/src/app/shell_page.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
import 'package:smplayer_flutter/src/library/data/library_repository.dart';
import 'package:smplayer_flutter/src/settings/settings_controller.dart';
import 'package:smplayer_flutter/src/settings/settings_model.dart'
    show SettingsSnapshot;

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
            onSearchCleared: () {},
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
    expect(find.text('播放'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('SettingsItem')));
    expect(invokedTarget, '/settings');
    expect(
      tester.getBottomLeft(find.byKey(const ValueKey('SettingsItem'))).dy,
      lessThanOrEqualTo(900),
    );
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
            onSearchCleared: () {},
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

  testWidgets('collapsed sidebar shows Electron-style floating labels', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 96,
          height: 900,
          child: MainNavigationView(
            isPaneOpen: false,
            currentPath: '/songs',
            searchText: '',
            i18n: testI18n,
            onPaneToggle: () {},
            onSearchTextChanged: (_) {},
            onSearchCommitted: (_, [__ = SearchHistoryType.sidebar]) {},
            onSearchCleared: () {},
            onItemInvoked: (_) {},
          ),
        ),
      ),
    );

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    await tester.pump();
    await gesture.moveTo(
      tester.getCenter(find.byKey(const ValueKey('MusicLibraryItem'))),
    );
    await tester.pump();

    expect(find.text('音乐库'), findsOneWidget);

    await gesture.moveTo(const Offset(95, 895));
    await tester.pump();

    expect(find.text('音乐库'), findsNothing);
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
            onSearchCleared: () {},
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

  testWidgets('playlist route expands sidebar playlist group like Electron', (
    tester,
  ) async {
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
            playlists: const [
              LibraryPlaylist(
                id: 7,
                name: 'Road Trip',
                priority: 0,
                songCount: 0,
                songIds: [],
                sortCriterion: PlaylistSortCriterion.title,
                isBuiltIn: false,
              ),
            ],
            onPaneToggle: () {},
            onSearchTextChanged: (_) {},
            onSearchCommitted: (_, [__ = SearchHistoryType.sidebar]) {},
            onSearchCleared: () {},
            onItemInvoked: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Road Trip'), findsOneWidget);
  });

  testWidgets('sidebar playlist group is expanded by default', (tester) async {
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
            playlists: const [
              LibraryPlaylist(
                id: 8,
                name: 'Daily Mix',
                priority: 0,
                songCount: 1,
                songIds: [1],
                sortCriterion: PlaylistSortCriterion.title,
                isBuiltIn: false,
              ),
            ],
            onPaneToggle: () {},
            onSearchTextChanged: (_) {},
            onSearchCommitted: (_, [__ = SearchHistoryType.sidebar]) {},
            onSearchCleared: () {},
            onItemInvoked: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Daily Mix'), findsOneWidget);
  });

  testWidgets('search box reports typed, submitted, and cleared values', (
    tester,
  ) async {
    var committedText = '';
    var changedText = '';
    var clearCount = 0;

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
            onSearchCleared: () {
              clearCount += 1;
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
    expect(committedText, '  Jazz  ');
    expect(clearCount, 1);
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
                id: 10,
                query: 'jazz',
                type: SearchHistoryType.sidebar,
                searchedAt: '2026-05-21T00:00:00Z',
              ),
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
              SearchHistoryEntry(
                id: 9,
                query: 'Blues',
                type: SearchHistoryType.sidebar,
                searchedAt: '2026-05-20T00:00:00Z',
              ),
            ],
            onPaneToggle: () {},
            onSearchTextChanged: (_) {},
            onSearchCommitted: (value, [type = SearchHistoryType.sidebar]) {
              committedText = value;
            },
            onSearchCleared: () {},
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

    final libraryTop =
        tester.getTopLeft(find.byKey(const ValueKey('MusicLibraryItem'))).dy;

    await tester.tap(
      find.byKey(const ValueKey('MainNavigationView.SearchTextField')),
    );
    await tester.pump();

    expect(find.text('最近搜索'), findsOneWidget);
    expect(find.text('jazz'), findsOneWidget);
    expect(find.text('Jazz'), findsNothing);
    expect(find.text('Blues'), findsOneWidget);
    expect(find.text('Album only'), findsNothing);
    expect(
      find.byKey(const ValueKey('MainNavigationView.SearchHistoryItem.7')),
      findsNothing,
    );
    final searchFieldSize = tester.getSize(
      find.byKey(const ValueKey('MainNavigationView.SearchFieldShell')),
    );
    expect(searchFieldSize.height, 40);
    expect(
      tester
              .getTopLeft(
                find.byKey(
                  const ValueKey('MainNavigationView.SearchHistoryPanel'),
                ),
              )
              .dy -
          tester
              .getBottomLeft(
                find.byKey(const ValueKey('MainNavigationView.SearchForm')),
              )
              .dy,
      8,
    );
    expect(
      find.byKey(const ValueKey('MainNavigationView.SearchHistoryBackdrop')),
      findsOneWidget,
    );
    expect(
      tester
          .getSize(
            find.byKey(const ValueKey('MainNavigationView.SearchHistoryPanel')),
          )
          .width,
      searchFieldSize.width,
    );
    expect(
      tester
          .getSize(
            find.byKey(const ValueKey('MainNavigationView.SearchHistoryPanel')),
          )
          .height,
      130,
    );
    final historyPanel = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('MainNavigationView.SearchHistoryPanel')),
    );
    final historyDecoration = historyPanel.decoration as BoxDecoration;
    expect(historyDecoration.color, MainNavigationViewColors.dropdownSurface);
    expect(historyDecoration.borderRadius, BorderRadius.circular(14));
    expect(historyDecoration.boxShadow, const [
      BoxShadow(
        color: MainNavigationViewColors.dropdownShadow,
        blurRadius: 36,
        offset: Offset(0, 18),
      ),
    ]);
    expect(
      tester.getSize(
        find.byKey(const ValueKey('MainNavigationView.SearchHistoryHeader')),
      ),
      Size(searchFieldSize.width - 16, 30),
    );
    expect(
      tester
              .getTopLeft(
                find.byKey(
                  const ValueKey('MainNavigationView.SearchHistoryItem.10'),
                ),
              )
              .dy -
          tester
              .getBottomLeft(
                find.byKey(
                  const ValueKey('MainNavigationView.SearchHistoryHeader'),
                ),
              )
              .dy,
      6,
    );
    expect(
      tester
          .getSize(
            find.byKey(
              const ValueKey('MainNavigationView.SearchHistoryItem.10'),
            ),
          )
          .height,
      38,
    );
    expect(
      tester
          .getSize(
            find.byKey(
              const ValueKey('MainNavigationView.SearchHistorySelect.10'),
            ),
          )
          .height,
      38,
    );
    expect(
      tester.getSize(
        find.byKey(const ValueKey('MainNavigationView.SearchHistoryRemove.10')),
      ),
      const Size(30, 30),
    );
    expect(
      tester
              .getTopLeft(
                find.byKey(
                  const ValueKey('MainNavigationView.SearchHistoryItem.9'),
                ),
              )
              .dy -
          tester
              .getBottomLeft(
                find.byKey(
                  const ValueKey('MainNavigationView.SearchHistoryItem.10'),
                ),
              )
              .dy,
      2,
    );
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('MusicLibraryItem'))).dy,
      libraryTop,
    );

    await tester.tap(
      find.byKey(const ValueKey('MainNavigationView.SearchDismissLayer')),
    );
    await tester.pump();
    expect(find.text('最近搜索'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('MainNavigationView.SearchTextField')),
    );
    await tester.pump();

    await tester.tap(find.text('jazz'));
    await tester.pump();
    expect(committedText, 'jazz');

    await tester.tap(
      find.byKey(const ValueKey('MainNavigationView.SearchTextField')),
    );
    await tester.pump();
    await tester.tap(find.byTooltip('移除最近搜索 jazz'));
    expect(removedId, 10);

    await tester.tap(find.text('清空'));
    expect(cleared, isTrue);
  });

  testWidgets('sidebar search dropdown mirrors Electron night colors', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: Brightness.dark),
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
            ],
            onPaneToggle: () {},
            onSearchTextChanged: (_) {},
            onSearchCommitted: (_, [__ = SearchHistoryType.sidebar]) {},
            onSearchCleared: () {},
            onItemInvoked: (_) {},
          ),
        ),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey('MainNavigationView.SearchTextField')),
    );
    await tester.pump();

    final colors = MainNavigationViewColors.of(
      tester.element(find.byType(MainNavigationView)),
    );
    final searchForm = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('MainNavigationView.SearchForm')),
    );
    final searchDecoration = searchForm.decoration as BoxDecoration;
    expect(searchDecoration.color, colors.focusedSearchSurface);
    expect(
      searchDecoration.border,
      Border.all(color: colors.focusedSearchBorder),
    );

    final historyPanel = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('MainNavigationView.SearchHistoryPanel')),
    );
    final historyDecoration = historyPanel.decoration as BoxDecoration;
    expect(historyDecoration.color, colors.dropdownSurface);
    expect(historyDecoration.border, Border.all(color: colors.searchBorder));
    expect(historyDecoration.boxShadow, [
      BoxShadow(
        color: colors.dropdownShadow,
        blurRadius: 36,
        offset: const Offset(0, 18),
      ),
    ]);
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
            onSearchCleared: () {},
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

    expect(find.text('Road Mix'), findsOneWidget);
    expect(find.text('Built in'), findsNothing);
    final headingRect = tester.getRect(
      find.byKey(const ValueKey('MainNavigationView.PlaylistsHeadingItem')),
    );
    final playlistRect = tester.getRect(
      find.byKey(const ValueKey('PlaylistItem.7')),
    );
    expect(playlistRect.top - headingRect.bottom, 0);
    expect(playlistRect.height, 48);
    final randomIconFinder = find.byIcon(FluentIcons.arrow_shuffle_20_regular);
    expect(randomIconFinder, findsOneWidget);
    expect(
      tester
          .widget<Opacity>(
            find
                .ancestor(of: randomIconFinder, matching: find.byType(Opacity))
                .first,
          )
          .opacity,
      0,
    );

    await tester.tap(find.byKey(const ValueKey('PlaylistItem.7')));
    expect(invokedTarget, '/playlists/7');
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 320,
          height: 720,
          child: MainNavigationView(
            isPaneOpen: true,
            currentPath: '/playlists/7',
            searchText: '',
            i18n: testI18n,
            playlists: const [
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
            onSearchCleared: () {},
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
    await tester.pump();
    expect(
      tester
          .widget<Opacity>(
            find
                .ancestor(of: randomIconFinder, matching: find.byType(Opacity))
                .first,
          )
          .opacity,
      0,
    );

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer();
    await mouse.moveTo(
      tester.getCenter(find.byKey(const ValueKey('PlaylistItem.7'))),
    );
    await tester.pump();
    expect(
      tester
          .widget<Opacity>(
            find
                .ancestor(of: randomIconFinder, matching: find.byType(Opacity))
                .first,
          )
          .opacity,
      1,
    );

    await tester.tap(find.byTooltip('随机播放'));
    expect(randomPlaylistId, 7);
  });

  testWidgets('sidebar playlist item exposes Electron context menu actions', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(420, 1000);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    LibraryPlaylist? duplicated;
    LibraryPlaylist? renamed;
    LibraryPlaylist? deleted;

    const playlist = LibraryPlaylist(
      id: 7,
      name: 'Road Mix',
      priority: 1,
      songCount: 2,
      songIds: [1, 2],
      sortCriterion: PlaylistSortCriterion.title,
      isBuiltIn: false,
    );

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
            playlists: const [playlist],
            onPaneToggle: () {},
            onSearchTextChanged: (_) {},
            onSearchCommitted: (_, [__ = SearchHistoryType.sidebar]) {},
            onSearchCleared: () {},
            onItemInvoked: (_) {},
            onDuplicatePlaylist: (playlist) {
              duplicated = playlist;
            },
            onRenamePlaylist: (playlist) {
              renamed = playlist;
            },
            onDeletePlaylist: (playlist) {
              deleted = playlist;
            },
          ),
        ),
      ),
    );

    await tester.longPress(find.byKey(const ValueKey('PlaylistItem.7')));
    await tester.pumpAndSettle();
    expect(find.text('播放'), findsNothing);
    await tester.tap(find.text('复制播放列表'));
    await tester.pumpAndSettle();
    expect(duplicated?.id, 7);

    await tester.longPress(find.byKey(const ValueKey('PlaylistItem.7')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('重命名'));
    await tester.pumpAndSettle();
    expect(renamed?.id, 7);

    await tester.longPress(find.byKey(const ValueKey('PlaylistItem.7')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    expect(deleted?.id, 7);
  });

  testWidgets(
    'shell trims committed sidebar searches without retaining input',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1300, 600);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final repository = _MainNavigationShellRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryRepositoryProvider.overrideWithValue(repository),
            smPlayerI18nProvider.overrideWith((ref) async => testI18n),
          ],
          child: SmPlayerI18nScope(
            i18n: testI18n,
            child: MaterialApp(
              theme: buildSmPlayerTheme(const SettingsSnapshot.defaults()),
              home: const SmPlayerShellPage(),
            ),
          ),
        ),
      );

      await tester.enterText(
        find.byKey(const ValueKey('MainNavigationView.SearchTextField')),
        '  Jazz  ',
      );
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      final textField = tester.widget<TextField>(
        find.byKey(const ValueKey('MainNavigationView.SearchTextField')),
      );
      expect(textField.controller?.text, 'Jazz');
      expect(
        find.byKey(const ValueKey('MainNavigationView.ClearSearchButton')),
        findsOneWidget,
      );
      expect(repository.recordedSearches, [
        (query: 'Jazz', type: SearchHistoryType.sidebar),
      ]);
      final navigationView = tester.widget<MainNavigationView>(
        find.byType(MainNavigationView),
      );
      expect(navigationView.recentSearches.map((entry) => entry.query), [
        'Jazz',
      ]);

      await tester.tap(
        find.byKey(const ValueKey('MainNavigationView.SearchTextField')),
      );
      await tester.pumpAndSettle();

      expect(
        find
            .byKey(const ValueKey('MainNavigationView.SearchTextField'))
            .hitTestable(),
        findsOneWidget,
      );
      final navigationViewAfterTap = tester.widget<MainNavigationView>(
        find.byType(MainNavigationView),
      );
      expect(
        navigationViewAfterTap.recentSearches.map((entry) => entry.query),
        ['Jazz'],
      );
      expect(
        find.byKey(const ValueKey('MainNavigationView.SearchDismissLayer')),
        findsOneWidget,
      );
      expect(find.text('最近搜索'), findsOneWidget);
      expect(find.text('Jazz'), findsNWidgets(2));

      await tester.tap(find.byKey(SmPlayerShellKeys.workspace));
      await tester.pumpAndSettle();
      expect(find.text('最近搜索'), findsNothing);
    },
  );
}

class _MainNavigationShellRepository extends LibraryRepository {
  final recordedSearches = <({String query, SearchHistoryType type})>[];

  @override
  Future<void> commitPendingDeletes() async {}

  @override
  Future<LibraryViewData> getLibraryViewData() async {
    return LibraryViewData(
      songs: [],
      recentSearches: [
        for (final entry in recordedSearches.indexed)
          SearchHistoryEntry(
            id: entry.$1 + 1,
            query: entry.$2.query,
            type: entry.$2.type,
            searchedAt: '2026-05-23T00:00:00Z',
          ),
      ],
      hasLibrary: false,
      sortCriterion: MusicLibrarySortCriterion.title,
      albumsSort: AlbumSortCriterion.defaultSort,
      databasePath: '',
    );
  }

  @override
  Future<SearchHistoryEntry?> addRecentSearch(
    String query, [
    SearchHistoryType type = SearchHistoryType.sidebar,
  ]) async {
    recordedSearches.add((query: query.trim(), type: type));
    return SearchHistoryEntry(
      id: recordedSearches.length,
      query: query.trim(),
      type: type,
      searchedAt: '2026-05-23T00:00:00Z',
    );
  }
}
