import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:smplayer_flutter/src/app/app_appearance_model.dart';
import 'package:smplayer_flutter/src/app/main_navigation_view.dart';
import 'package:smplayer_flutter/src/app/shell_models.dart';
import 'package:smplayer_flutter/src/app/shell_page.dart';
import 'package:smplayer_flutter/src/app/shell_widgets.dart';
import 'package:smplayer_flutter/src/app/smplayer_vector_icons.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
import 'package:smplayer_flutter/src/library/data/library_repository.dart';
import 'package:smplayer_flutter/src/library/ui/menu_flyout.dart';
import 'package:smplayer_flutter/src/library/ui/search_commit_icon_button.dart';
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

void _noop() {}

void _ignoreString(String value) {}

void _ignoreSearchCommit(
  String value, [
  SearchHistoryType type = SearchHistoryType.sidebar,
]) {}

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

  testWidgets('collapsed active navigation item uses CommandBar more radius', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: SmPlayerShellMetrics.collapsedSidebarWidth,
          height: 900,
          child: MainNavigationView(
            isPaneOpen: false,
            currentPath: '/songs',
            searchText: '',
            i18n: testI18n,
            onPaneToggle: _noop,
            onSearchTextChanged: _ignoreString,
            onSearchCommitted: _ignoreSearchCommit,
            onSearchCleared: _noop,
            onItemInvoked: _ignoreString,
          ),
        ),
      ),
    );

    final activeItem = find.byKey(const ValueKey('MusicLibraryItem'));
    final activeBackground = tester.widget<Container>(
      find.descendant(of: activeItem, matching: find.byType(Container)).first,
    );
    expect(
      (activeBackground.decoration! as BoxDecoration).borderRadius,
      BorderRadius.circular(SmPlayerShellMetrics.navigationButtonRadius),
    );
  });

  testWidgets('collapsed navigation item keeps 40px button centered in rail', (
    tester,
  ) async {
    Widget buildNavigation({required bool open}) {
      return MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: open ? 320 : SmPlayerShellMetrics.collapsedSidebarWidth,
            height: 900,
            child: MainNavigationView(
              isPaneOpen: open,
              currentPath: '/songs',
              searchText: '',
              i18n: testI18n,
              onPaneToggle: _noop,
              onSearchTextChanged: _ignoreString,
              onSearchCommitted: _ignoreSearchCommit,
              onSearchCleared: _noop,
              onItemInvoked: _ignoreString,
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(buildNavigation(open: true));
    final libraryItem = find.byKey(const ValueKey('MusicLibraryItem'));
    final expandedItemSize = tester.getSize(libraryItem);

    await tester.pumpWidget(buildNavigation(open: false));
    await tester.pumpAndSettle();

    final toggleRect = tester.getRect(
      find.byKey(const ValueKey('MainNavigationView.TogglePaneButton')),
    );
    final searchRect = tester.getRect(
      find.byKey(const ValueKey('MainNavigationView.SearchButton')),
    );
    final collapsedItemRect = tester.getRect(libraryItem);
    for (final rect in [toggleRect, searchRect, collapsedItemRect]) {
      expect(
        rect.size,
        const Size(
          SmPlayerShellMetrics.navigationButtonSize,
          SmPlayerShellMetrics.navigationButtonSize,
        ),
      );
      expect(rect.center.dx, SmPlayerShellMetrics.collapsedSidebarWidth / 2);
    }
    expect(SmPlayerShellMetrics.collapsedSidebarWidth, 78);
    expect({
      toggleRect.center.dx,
      searchRect.center.dx,
      collapsedItemRect.center.dx,
    }, hasLength(1));
    expect(
      tester
          .widget<Icon>(
            find
                .descendant(
                  of: find.byKey(
                    const ValueKey('MainNavigationView.TogglePaneButton'),
                  ),
                  matching: find.byType(Icon),
                )
                .first,
          )
          .size,
      SmPlayerShellMetrics.navigationIconSize,
    );
    expect(
      tester
          .widget<Icon>(
            find
                .descendant(
                  of: find.byKey(
                    const ValueKey('MainNavigationView.SearchButton'),
                  ),
                  matching: find.byType(Icon),
                )
                .first,
          )
          .size,
      SmPlayerShellMetrics.navigationIconSize,
    );
    expect(
      tester
          .widget<Icon>(
            find.descendant(of: libraryItem, matching: find.byType(Icon)).first,
          )
          .size,
      21,
    );
    expect(expandedItemSize.height, SmPlayerShellMetrics.navigationButtonSize);
  });

  testWidgets('sidebar titlebar closes open MenuFlyout', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            SizedBox(
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
                onItemInvoked: (_) {},
              ),
            ),
            Positioned(
              left: 420,
              top: 80,
              child: Builder(
                builder: (context) {
                  return TextButton(
                    onPressed: () {
                      showMenuFlyout(
                        context,
                        items: [
                          MenuFlyoutItem(
                            key: 'first',
                            text: 'First',
                            onPressed: () {},
                          ),
                        ],
                      );
                    },
                    child: const Text('Open Flyout'),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

    await tester.tap(find.text('Open Flyout'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('MenuFlyout.GlassPanel')), findsOneWidget);

    await tester.tapAt(const Offset(24, 20));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('MenuFlyout.GlassPanel')), findsNothing);
  });

  testWidgets('expanded sidebar item content does not move when selected', (
    tester,
  ) async {
    Widget buildNavigation(String currentPath) {
      return MaterialApp(
        home: SizedBox(
          width: 320,
          height: 900,
          child: MainNavigationView(
            isPaneOpen: true,
            currentPath: currentPath,
            searchText: '',
            i18n: testI18n,
            onPaneToggle: () {},
            onSearchTextChanged: (_) {},
            onSearchCommitted: (_, [__ = SearchHistoryType.sidebar]) {},
            onSearchCleared: () {},
            onItemInvoked: (_) {},
          ),
        ),
      );
    }

    await tester.pumpWidget(buildNavigation('/songs'));
    await tester.pumpAndSettle();
    final inactiveIconCenter = tester.getCenter(
      find.byIcon(FluentIcons.hard_drive_24_regular),
    );
    final inactiveLabelLeft = tester.getTopLeft(find.text('本地')).dx;

    await tester.pumpWidget(buildNavigation('/local'));
    await tester.pumpAndSettle();

    expect(
      tester.getCenter(find.byIcon(FluentIcons.hard_drive_24_regular)),
      inactiveIconCenter,
    );
    expect(tester.getTopLeft(find.text('本地')).dx, inactiveLabelLeft);
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

  testWidgets('navigation glass surface does not clip floating labels', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 96,
          height: 900,
          child: ShellNavigationGlassSurface(
            surface: Colors.transparent,
            shadowColor: Colors.transparent,
            shadowBlur: 0,
            child: MainNavigationView(
              isPaneOpen: false,
              currentPath: '/songs',
              searchText: '',
              i18n: testI18n,
              onPaneToggle: _noop,
              onSearchTextChanged: _ignoreString,
              onSearchCommitted: _ignoreSearchCommit,
              onSearchCleared: _noop,
              onItemInvoked: _ignoreString,
            ),
          ),
        ),
      ),
    );

    final surfaceStack = tester.widget<Stack>(
      find
          .descendant(
            of: find.byType(ShellNavigationGlassSurface),
            matching: find.byType(Stack),
          )
          .first,
    );

    expect(surfaceStack.clipBehavior, Clip.none);

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    await tester.pump();
    await gesture.moveTo(
      tester.getCenter(find.byKey(const ValueKey('MusicLibraryItem'))),
    );
    await tester.pump();

    expect(find.text('音乐库'), findsOneWidget);
    expect(tester.getRect(find.text('音乐库')).right, greaterThan(96));
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

  testWidgets('macOS wide sidebar keeps the navigation back button', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    var backCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 320,
          height: 900,
          child: MainNavigationView(
            isPaneOpen: true,
            currentPath: '/albums',
            searchText: '',
            i18n: testI18n,
            canGoBack: true,
            onPaneToggle: _noop,
            onGoBack: () {
              backCount += 1;
            },
            onSearchTextChanged: _ignoreString,
            onSearchCommitted: _ignoreSearchCommit,
            onSearchCleared: _noop,
            onItemInvoked: _ignoreString,
          ),
        ),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey('MainNavigationView.BackButton')),
    );

    expect(backCount, 1);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('macOS collapsed sidebar keeps titlebar clear', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: SmPlayerShellMetrics.collapsedSidebarWidth,
          height: 900,
          child: MainNavigationView(
            isPaneOpen: false,
            currentPath: '/albums',
            searchText: '',
            i18n: testI18n,
            canGoBack: true,
            onPaneToggle: _noop,
            onSearchTextChanged: _ignoreString,
            onSearchCommitted: _ignoreSearchCommit,
            onSearchCleared: _noop,
            onItemInvoked: _ignoreString,
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('MainNavigationView.BackButton')),
      findsNothing,
    );
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('playlist route expands sidebar playlist group like Electron', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(420, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

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
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(420, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

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
    final historyPanel = tester.widget<GlassContainer>(
      find.byKey(const ValueKey('MainNavigationView.SearchHistoryPanel')),
    );
    expect(historyPanel.quality, GlassQuality.minimal);
    expect(historyPanel.settings?.blur, 46);
    expect(historyPanel.settings?.saturation, 1.65);
    expect(historyPanel.settings?.glassColor, const Color(0x74ffffff));
    expect(historyPanel.settings?.standardOpacityMultiplier, 0.32);
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

    await tester.tap(find.byKey(const ValueKey('SettingsItem')));
    await tester.pump();
    expect(find.text('最近搜索'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('MainNavigationView.SearchTextField')),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('jazz'));
    await tester.pump();
    expect(committedText, 'jazz');

    await tester.tap(
      find.byKey(const ValueKey('MainNavigationView.SearchTextField')),
    );
    await tester.pump();
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('MainNavigationView.SearchHistoryRemove.10')),
    );
    expect(removedId, 10);

    await tester.tap(find.text('清空'));
    expect(cleared, isTrue);
  });

  testWidgets('sidebar search remains focusable while history is open', (
    tester,
  ) async {
    var changedText = '';

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
            ],
            onPaneToggle: () {},
            onSearchTextChanged: (value) {
              changedText = value;
            },
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
    await tester.pump();
    expect(find.text('最近搜索'), findsOneWidget);
    final editableTextState = tester.state<EditableTextState>(
      find.byType(EditableText),
    );
    expect(editableTextState.widget.focusNode.hasFocus, isTrue);

    await tester.enterText(
      find.byKey(const ValueKey('MainNavigationView.SearchTextField')),
      'blue',
    );
    await tester.pump();

    final textField = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const ValueKey('MainNavigationView.SearchTextField')),
        matching: find.byType(EditableText),
      ),
    );
    expect(textField.controller.text, 'blue');
    expect(changedText, 'blue');
    expect(find.text('最近搜索'), findsOneWidget);
  });

  testWidgets('sidebar search keeps local input across unrelated rebuilds', (
    tester,
  ) async {
    var canGoBack = false;

    Future<void> pumpNavigation() {
      return tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 320,
            height: 720,
            child: MainNavigationView(
              isPaneOpen: true,
              currentPath: '/songs',
              searchText: '',
              i18n: testI18n,
              canGoBack: canGoBack,
              onPaneToggle: () {},
              onSearchTextChanged: (_) {},
              onSearchCommitted: (_, [__ = SearchHistoryType.sidebar]) {},
              onSearchCleared: () {},
              onItemInvoked: (_) {},
            ),
          ),
        ),
      );
    }

    await pumpNavigation();
    await tester.enterText(
      find.byKey(const ValueKey('MainNavigationView.SearchTextField')),
      'abc123',
    );
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: find.byKey(
                const ValueKey('MainNavigationView.SearchTextField'),
              ),
              matching: find.byType(EditableText),
            ),
          )
          .controller
          .text,
      'abc123',
    );

    canGoBack = true;
    await pumpNavigation();
    await tester.pump();

    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: find.byKey(
                const ValueKey('MainNavigationView.SearchTextField'),
              ),
              matching: find.byType(EditableText),
            ),
          )
          .controller
          .text,
      'abc123',
    );
  });

  testWidgets('sidebar search form tap focuses editable input', (tester) async {
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
    await tester.pump();

    final editableTextState = tester.state<EditableTextState>(
      find.byType(EditableText),
    );
    expect(editableTextState.widget.focusNode.hasFocus, isTrue);

    editableTextState.widget.focusNode.unfocus();
    await tester.pump();
    expect(editableTextState.widget.focusNode.hasFocus, isFalse);

    await tester.tapAt(
      tester.getCenter(
        find.byKey(const ValueKey('MainNavigationView.SearchForm')),
      ),
    );
    await tester.pump();

    expect(editableTextState.widget.focusNode.hasFocus, isTrue);
  });

  testWidgets('sidebar empty search icon focuses input', (tester) async {
    var committedText = 'not-committed';

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
            ],
            onPaneToggle: () {},
            onSearchTextChanged: (_) {},
            onSearchCommitted: (value, [__ = SearchHistoryType.sidebar]) {
              committedText = value;
            },
            onSearchCleared: () {},
            onItemInvoked: (_) {},
          ),
        ),
      ),
    );

    final searchFormRect = tester.getRect(
      find.byKey(const ValueKey('MainNavigationView.SearchForm')),
    );
    await tester.tapAt(searchFormRect.centerLeft + const Offset(20, 0));
    await tester.pump();
    await tester.pump();

    final editableTextState = tester.state<EditableTextState>(
      find.byType(EditableText),
    );
    expect(editableTextState.widget.focusNode.hasFocus, isTrue);
    expect(find.text('最近搜索'), findsOneWidget);
    expect(committedText, 'not-committed');
  });

  testWidgets('sidebar search clear keeps input focus like Electron', (
    tester,
  ) async {
    var changedText = '';
    var clearCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 320,
          height: 720,
          child: MainNavigationView(
            isPaneOpen: true,
            currentPath: '/songs',
            searchText: 'blue',
            i18n: testI18n,
            recentSearches: const [
              SearchHistoryEntry(
                id: 10,
                query: 'jazz',
                type: SearchHistoryType.sidebar,
                searchedAt: '2026-05-21T00:00:00Z',
              ),
            ],
            onPaneToggle: () {},
            onSearchTextChanged: (value) {
              changedText = value;
            },
            onSearchCommitted: (_, [__ = SearchHistoryType.sidebar]) {},
            onSearchCleared: () {
              clearCount += 1;
            },
            onItemInvoked: (_) {},
          ),
        ),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey('MainNavigationView.SearchTextField')),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('最近搜索'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('MainNavigationView.ClearSearchButton')),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();

    final editableTextState = tester.state<EditableTextState>(
      find.byType(EditableText),
    );
    expect(editableTextState.widget.focusNode.hasFocus, isTrue);
    expect(changedText, '');
    expect(clearCount, 1);
  });

  testWidgets('sidebar search history closes from shell dismiss token', (
    tester,
  ) async {
    var dismissEpoch = 0;
    final openStates = <bool>[];

    Future<void> pumpNavigation() {
      return tester.pumpWidget(
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
              ],
              searchHistoryDismissEpoch: dismissEpoch,
              onSearchHistoryOpenChanged: openStates.add,
              onPaneToggle: () {},
              onSearchTextChanged: (_) {},
              onSearchCommitted: (_, [__ = SearchHistoryType.sidebar]) {},
              onSearchCleared: () {},
              onItemInvoked: (_) {},
            ),
          ),
        ),
      );
    }

    await pumpNavigation();
    await tester.tap(
      find.byKey(const ValueKey('MainNavigationView.SearchTextField')),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('最近搜索'), findsOneWidget);
    expect(openStates, [true]);

    dismissEpoch += 1;
    await pumpNavigation();
    await tester.pump();

    expect(find.text('最近搜索'), findsNothing);
    expect(openStates, [true, false]);
    final editableTextState = tester.state<EditableTextState>(
      find.byType(EditableText),
    );
    expect(editableTextState.widget.focusNode.hasFocus, isFalse);
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
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();

    final editableTextState = tester.state<EditableTextState>(
      find.byType(EditableText),
    );
    expect(editableTextState.widget.focusNode.hasFocus, isTrue);

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

    final historyPanel = tester.widget<GlassContainer>(
      find.byKey(const ValueKey('MainNavigationView.SearchHistoryPanel')),
    );
    expect(historyPanel.quality, GlassQuality.minimal);
    expect(historyPanel.settings?.blur, 46);
    expect(historyPanel.settings?.saturation, 1.65);
    expect(historyPanel.settings?.glassColor, const Color(0x7a181e26));
    expect(historyPanel.settings?.standardOpacityMultiplier, 0.32);
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
    final randomIconFinder = find.byType(ShuffleIcon);
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

  testWidgets(
    'sidebar hides playlist actions and children at minimum app height',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(
        420,
        SmPlayerShellMetrics.navigationPlaylistChildrenCollapseHeight,
      );
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 320,
            height:
                SmPlayerShellMetrics.mainWindowMinimumHeight -
                SmPlayerShellMetrics.playerHeight,
            child: Padding(
              padding: const EdgeInsets.only(
                top: SmPlayerShellMetrics.minimalTitlebarHeight,
              ),
              child: MainNavigationView(
                isPaneOpen: true,
                showTitlebar: false,
                currentPath: '/playlists',
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
                onItemInvoked: (_) {},
              ),
            ),
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey('MainNavigationView.PlaylistsHeadingItem')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('PlaylistItem.7')), findsNothing);
      expect(
        find.byKey(const ValueKey('MainNavigationView.CreatePlaylistButton')),
        findsNothing,
      );
      expect(
        find.byKey(
          const ValueKey('MainNavigationView.TogglePlaylistSectionButton'),
        ),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('MainNavigationView.PlaylistScroll')),
        findsNothing,
      );
      final playlistRect = tester.getRect(
        find.byKey(const ValueKey('MainNavigationView.PlaylistsHeadingItem')),
      );
      final settingsRect = tester.getRect(
        find.byKey(const ValueKey('SettingsItem')),
      );
      expect(settingsRect.top - playlistRect.bottom, 8);
    },
  );

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

      final textField = tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(const ValueKey('MainNavigationView.SearchTextField')),
          matching: find.byType(EditableText),
        ),
      );
      expect(textField.controller.text, 'Jazz');
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
      expect(find.text('最近搜索'), findsOneWidget);
      expect(find.text('Jazz'), findsNWidgets(2));

      await tester.tap(find.byKey(SmPlayerShellKeys.workspace));
      await tester.pumpAndSettle();
      expect(find.text('最近搜索'), findsNothing);
    },
  );

  testWidgets('sidebar search unfocuses when tapping outside', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            SizedBox(
              width: 320,
              height: 240,
              child: MainNavigationView(
                isPaneOpen: true,
                currentPath: '/songs',
                searchText: '',
                i18n: testI18n,
                recentSearches: const [
                  SearchHistoryEntry(
                    id: 10,
                    query: 'Jazz',
                    type: SearchHistoryType.sidebar,
                    searchedAt: '2026-05-21T00:00:00Z',
                  ),
                ],
                onPaneToggle: () {},
                onSearchTextChanged: (_) {},
                onSearchCommitted: (_, [__ = SearchHistoryType.sidebar]) {},
                onSearchCleared: () {},
                onItemInvoked: (_) {},
              ),
            ),
            GestureDetector(
              key: const ValueKey('OutsideSearchTarget'),
              behavior: HitTestBehavior.opaque,
              child: const SizedBox(width: 200, height: 80),
            ),
          ],
        ),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey('MainNavigationView.SearchTextField')),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    await tester.pump();
    final editableTextState = tester.state<EditableTextState>(
      find.byType(EditableText),
    );
    expect(editableTextState.widget.focusNode.hasFocus, isTrue);
    expect(find.text('最近搜索'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('OutsideSearchTarget')),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();

    expect(editableTextState.widget.focusNode.hasFocus, isFalse);
    expect(find.text('最近搜索'), findsNothing);
  });

  testWidgets('sidebar search icon slot is square', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 320,
          height: 240,
          child: MainNavigationView(
            isPaneOpen: true,
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

    expect(
      tester.getSize(find.byType(SearchCommitIconButton).first),
      const Size.square(40),
    );
  });

  testWidgets('sidebar search input fills Electron input height', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 320,
          height: 240,
          child: MainNavigationView(
            isPaneOpen: true,
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

    final textField = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const ValueKey('MainNavigationView.SearchTextField')),
        matching: find.byType(EditableText),
      ),
    );
    expect(textField.cursorHeight, isNull);
    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('MainNavigationView.SearchTextField')),
    );
    expect(field.decoration?.isDense, isTrue);
    expect(
      field.decoration?.contentPadding,
      SearchTextInputMetrics.contentPaddingForHeight(40),
    );
    expect(tester.getSize(find.byType(TextField).first).height, 40);
  });

  testWidgets('sidebar search clear button only shows background on hover', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 320,
          height: 240,
          child: MainNavigationView(
            isPaneOpen: true,
            currentPath: '/songs',
            searchText: '流星',
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

    BoxDecoration clearDecoration() {
      final boxes = tester.widgetList<DecoratedBox>(
        find.descendant(
          of: find.byKey(
            const ValueKey('MainNavigationView.ClearSearchButton'),
          ),
          matching: find.byType(DecoratedBox),
        ),
      );
      return boxes
          .map((box) => box.decoration)
          .whereType<BoxDecoration>()
          .firstWhere(
            (decoration) => decoration.borderRadius == BorderRadius.circular(6),
          );
    }

    expect(clearDecoration().color, Colors.transparent);
    expect(
      tester
          .widget<Icon>(
            find.descendant(
              of: find.byKey(
                const ValueKey('MainNavigationView.ClearSearchButton'),
              ),
              matching: find.byIcon(FluentIcons.dismiss_16_regular),
            ),
          )
          .color,
      SearchCommitIconButton.foregroundFor(
        tester.element(find.byType(MainNavigationView)),
      ),
    );

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(
      tester.getCenter(
        find.byKey(const ValueKey('MainNavigationView.ClearSearchButton')),
      ),
    );
    await tester.pump();

    expect(clearDecoration().color, MainNavigationViewColors.clearButtonHover);
  });
}

class _MainNavigationShellRepository extends LibraryRepository {
  final recordedSearches = <({String query, SearchHistoryType type})>[];

  @override
  Future<void> commitPendingDeletes() async {}

  @override
  Future<LibraryContentData> getLibraryContentData() async {
    return LibraryContentData(
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
