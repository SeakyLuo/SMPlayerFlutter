import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smplayer_flutter/src/app/shell_colors.dart';
import 'package:smplayer_flutter/src/app/shell_layout_state.dart';
import 'package:smplayer_flutter/src/app/shell_models.dart';
import 'package:smplayer_flutter/src/app/shell_workspace.dart';
import 'package:smplayer_flutter/src/app/workspace_app_bar_portal.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
import 'package:smplayer_flutter/src/library/ui/artists_page.dart';
import 'package:smplayer_flutter/src/library/ui/albums_page.dart';
import 'package:smplayer_flutter/src/library/ui/command_bar.dart';
import 'package:smplayer_flutter/src/library/ui/default_album_artwork.dart';
import 'package:smplayer_flutter/src/library/ui/headered_playlist_app_bar_portal.dart';
import 'package:smplayer_flutter/src/library/ui/local_page_quick_jump.dart';
import 'package:smplayer_flutter/src/library/ui/menu_flyout.dart';
import 'package:smplayer_flutter/src/library/ui/music_library_page.dart';
import 'package:smplayer_flutter/src/playback/now_playing_page.dart';

void main() {
  testWidgets('workspace app bar shows route title on first frame', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 360);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const _WorkspaceAppBarTestApp(
        currentPath: '/songs',
        textScaler: TextScaler.noScaling,
      ),
    );

    expect(find.text('所有歌曲'), findsOneWidget);

    await tester.pump();

    expect(find.text('所有歌曲（1）'), findsOneWidget);
  });

  testWidgets('minimal workspace app bar keeps Electron shadowless surface', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 360);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const _WorkspaceAppBarTestApp(
        currentPath: '/songs',
        textScaler: TextScaler.noScaling,
      ),
    );

    final surface = find.byKey(
      const ValueKey('WorkspaceNavigationAppBar.Surface'),
    );
    final surfaceMaterial = tester.widget<Material>(surface);

    expect(surfaceMaterial.color, ShellColors.nightWorkspaceSurface);
    expect(surfaceMaterial.elevation, 0);
  });

  testWidgets(
    'minimal workspace app bar leaves bottom padding before content',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(430, 360);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const _WorkspaceAppBarTestApp(
          currentPath: '/songs',
          textScaler: TextScaler.noScaling,
          child: SizedBox(
            key: ValueKey('WorkspaceAppBar.ContentProbe'),
            height: 20,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final surface = find.byKey(
        const ValueKey('WorkspaceNavigationAppBar.Surface'),
      );
      final content = find.byKey(
        const ValueKey('WorkspaceAppBar.ContentProbe'),
      );

      expect(tester.getSize(surface).height, 48);
      expect(tester.getTopLeft(content).dy, 48);
    },
  );

  testWidgets('minimal now-playing app bar keeps the full title visible', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 360);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const _WorkspaceAppBarTestApp(child: NowPlayingPage()),
    );
    await tester.pumpAndSettle();

    final titleRect = tester.getRect(find.text('正在播放（1）'));
    final actionsRect = tester.getRect(find.byType(CommandBar));

    expect(titleRect.width, greaterThan(96));
    expect(titleRect.right, lessThan(actionsRect.left));
  });

  testWidgets('workspace app bar uses portal title override', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 360);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const _WorkspaceAppBarTestApp(portalTitle: 'Artist A'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Artist A'), findsOneWidget);
    expect(find.text('正在播放（1）'), findsNothing);
  });

  testWidgets('search app bar title uses space from empty portal actions', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(600, 520);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    const title = '“流星冰淇淋”的搜索结果';
    await tester.pumpWidget(
      const _WorkspaceAppBarTestApp(
        currentPath: '/search',
        currentLocation:
            '/search?query=%E6%B5%81%E6%98%9F%E5%86%B0%E6%B7%87%E6%B7%8B',
        portalRoutePath: '/search',
        portalTitle: title,
        portalContent: SizedBox.shrink(),
        textScaler: TextScaler.noScaling,
      ),
    );
    await tester.pumpAndSettle();

    final titleRect = tester.getRect(find.text(title));
    final menuRect = tester.getRect(
      find.byKey(SmPlayerShellWorkspaceKeys.navigationMenuButton),
    );

    expect(titleRect.left, greaterThan(menuRect.right));
    expect(titleRect.width, greaterThan(360));
  });

  testWidgets(
    'workspace app bar title keeps Electron flex space before actions',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(430, 360);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const title = 'distinctivecomdistinctivecomdistinctivecom';
      await tester.pumpWidget(
        const _WorkspaceAppBarTestApp(
          currentPath: '/artists',
          portalRoutePath: '/artists',
          portalTitle: title,
          portalContent: CommandBar(
            style: CommandBarStyleVariant.appBar,
            overflowLabel: '更多',
            children: [
              CommandBarButton(
                key: ValueKey('WorkspaceAppBar.SearchAction'),
                icon: FluentIcons.search_20_regular,
                label: '搜索',
                showLabel: false,
                canOverflow: false,
                onPressed: null,
              ),
            ],
          ),
          textScaler: TextScaler.noScaling,
        ),
      );
      await tester.pumpAndSettle();

      final titleRect = tester.getRect(find.text(title));
      final titleWidget = tester.widget<Text>(find.text(title));
      final actionRect = tester.getRect(
        find.byKey(const ValueKey('WorkspaceAppBar.SearchAction')),
      );

      expect(titleWidget.textScaler, TextScaler.noScaling);
      expect(titleRect.width, greaterThan(240));
      expect(actionRect.width, 40);
      expect(titleRect.right, lessThanOrEqualTo(actionRect.left - 12));
    },
  );

  testWidgets(
    'workspace app bar bottom aligns ArtistDetail back with menu column',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(430, 360);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const _WorkspaceAppBarTestApp(
          currentPath: '/artists',
          portalRoutePath: '/artists',
          portalTitle: 'Artist A',
          portalContent: CommandBar(
            style: CommandBarStyleVariant.appBar,
            overflowLabel: '更多',
            children: [
              CommandBarButton(
                icon: FluentIcons.search_20_regular,
                label: '搜索',
                showLabel: false,
                canOverflow: false,
                onPressed: null,
              ),
            ],
          ),
          portalBottomContent: SizedBox(
            height: 40,
            child: Padding(
              padding: EdgeInsets.fromLTRB(0, 0, 4, 8),
              child: Row(
                children: [
                  SizedBox(
                    key: ValueKey('Artists.DetailHeader.Back'),
                    width: 32,
                    height: 32,
                  ),
                ],
              ),
            ),
          ),
          textScaler: TextScaler.noScaling,
        ),
      );
      await tester.pumpAndSettle();

      final menuRect = tester.getRect(
        find.byKey(SmPlayerShellWorkspaceKeys.navigationMenuButton),
      );
      final backRect = tester.getRect(
        find.byKey(const ValueKey('Artists.DetailHeader.Back')),
      );

      expect(backRect.left, menuRect.left);
      expect(backRect.size, const Size(32, 32));
    },
  );

  testWidgets('album detail ignores albums list app bar title portal', (
    tester,
  ) async {
    await tester.pumpWidget(
      const _WorkspaceAppBarTestApp(
        currentPath: '/albums',
        currentLocation: '/albums?album=Blue%20Hour',
        portalRoutePath: '/albums',
        portalRouteLocation: '/albums',
        portalTitle: '所有专辑（1）',
        textScaler: TextScaler.noScaling,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('所有专辑（1）'), findsNothing);
  });

  testWidgets('album detail does not use albums list route title', (
    tester,
  ) async {
    await tester.pumpWidget(
      const _WorkspaceAppBarTestApp(
        currentPath: '/albums',
        currentLocation: '/albums?album=Blue%20Hour',
        textScaler: TextScaler.noScaling,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('所有专辑（1）'), findsNothing);
    expect(find.text('所有专辑'), findsNothing);
  });

  testWidgets('minimal music library quick jump lives in the app bar', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(640, 480);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const _WorkspaceAppBarTestApp(
        currentPath: '/songs',
        textScaler: TextScaler.noScaling,
        child: MusicLibraryPage(),
      ),
    );
    await tester.pumpAndSettle();

    final quickJump = find.byKey(
      const ValueKey('MusicLibrary.QuickJumpToggle'),
    );
    expect(quickJump, findsOneWidget);
    final quickJumpRect = tester.getRect(quickJump);
    expect(quickJumpRect.top, lessThan(40));
    expect(quickJumpRect.width, 40);
    expect(quickJumpRect.height, 40);

    await tester.tap(quickJump);
    await tester.pumpAndSettle();

    final panelRect = tester.getRect(
      find.byKey(const ValueKey('MusicLibrary.QuickJumpPanel')),
    );
    expect(panelRect.left, 0);
    expect(panelRect.width, 640);

    final firstKeyRect = tester.getRect(
      find.byKey(const ValueKey('MusicLibrary.QuickJumpPanel.#')),
    );
    expect(firstKeyRect.top, 50);
  });

  testWidgets('albums title count includes Electron unknown-album bucket', (
    tester,
  ) async {
    await tester.pumpWidget(
      const _WorkspaceAppBarTestApp(
        currentPath: '/albums',
        snapshot: _unknownAlbumSnapshot,
        textScaler: TextScaler.noScaling,
        child: AlbumsPage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('所有专辑（1）'), findsOneWidget);
  });

  testWidgets('artists title count includes unknown artist bucket', (
    tester,
  ) async {
    await tester.pumpWidget(
      const _WorkspaceAppBarTestApp(
        currentPath: '/artists',
        snapshot: _unknownArtistSnapshot,
        textScaler: TextScaler.noScaling,
        child: ArtistsPage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('所有歌手（1）'), findsOneWidget);
  });

  testWidgets('local title hides after music folder is set', (tester) async {
    await tester.pumpWidget(
      const _WorkspaceAppBarTestApp(
        currentPath: '/local',
        snapshot: _localFolderSnapshot,
        textScaler: TextScaler.noScaling,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('本地'), findsNothing);
  });

  testWidgets(
    'local app bar shows compact breadcrumb after music folder is set',
    (tester) async {
      await tester.pumpWidget(
        const _WorkspaceAppBarTestApp(
          currentPath: '/local',
          currentLocation: '/local?path=Sub',
          snapshot: _localNestedFolderSnapshot,
          textScaler: TextScaler.noScaling,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('本地'), findsNothing);
      expect(find.text('Music'), findsOneWidget);
      expect(find.text('Sub'), findsOneWidget);
    },
  );

  testWidgets('local title shows before music folder is set', (tester) async {
    await tester.pumpWidget(
      const _WorkspaceAppBarTestApp(
        currentPath: '/local',
        snapshot: _localNoFolderSnapshot,
        textScaler: TextScaler.noScaling,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('本地'), findsOneWidget);
  });

  testWidgets('headered playlist topbar blurs titlebar and appbar together', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(700, 480);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _WorkspaceAppBarTestApp(
        currentPath: '/albums',
        currentLocation: '/albums?album=Blue%20Hour',
        textScaler: TextScaler.noScaling,
        navigationAppBarTopInset: 32,
        headeredPlaylistAppBar: HeaderedPlaylistAppBarPortalEntry(
          owner: Object(),
          routeLocation: '/albums?album=Blue%20Hour',
          title: 'Blue Hour',
          coverColor: const Color(0xff5b87b6),
          collapseProgress: 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final surface = find.byKey(
      const ValueKey('WorkspaceNavigationAppBar.ImmersiveSurface'),
    );
    expect(surface, findsOneWidget);
    expect(tester.getTopLeft(surface).dy, 0);
    expect(tester.getSize(surface).height, 72);
    expect(find.text('Blue Hour'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Blue Hour')).dy,
      greaterThanOrEqualTo(32),
    );
    final appBarTitle = tester.widget<Text>(find.text('Blue Hour'));
    expect(appBarTitle.style?.fontSize, 16);
  });

  testWidgets('headered playlist route starts at top before portal publishes', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(700, 480);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const _WorkspaceAppBarTestApp(
        currentPath: '/favorites',
        currentLocation: '/favorites',
        textScaler: TextScaler.noScaling,
        child: SizedBox.expand(
          key: ValueKey('HeaderedPlaylist.FirstFrameProbe'),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('WorkspaceNavigationAppBar.Surface')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('WorkspaceNavigationAppBar.ImmersiveSurface')),
      findsOneWidget,
    );
    expect(
      tester
          .getTopLeft(
            find.byKey(const ValueKey('HeaderedPlaylist.FirstFrameProbe')),
          )
          .dy,
      0,
    );
  });

  test(
    'shell layout treats headered playlist routes as immersive before portal publishes',
    () {
      final layout = ShellLayoutState.resolve(
        currentPath: '/favorites',
        currentLocation: '/favorites',
        windowWidth: 700,
        navigationPaneOpen: false,
        minimalNavigationOpen: false,
        canGoBack: true,
        rawHeaderedPlaylistAppBar: null,
      );

      expect(layout.headeredPlaylistAppBar, isNotNull);
      expect(layout.headeredPlaylistAppBar?.title, '');
      expect(layout.workspaceTop, 0);
      expect(layout.immersiveMinimalTitlebar, true);
      expect(layout.navigationSurfaceTop, 0);
      expect(
        layout.navigationContentTopInset,
        SmPlayerShellMetrics.minimalTitlebarHeight,
      );
    },
  );
}

const _i18n = SmPlayerI18n(
  locale: 'zh-CN',
  messages: {
    'common.nowPlaying': '正在播放',
    'common.local': '本地',
    'common.songs': '歌曲',
    'nowPlaying.titleWithCount': '正在播放（{count}）',
    'nowPlaying.quickPlay': '快速播放',
    'nowPlaying.randomPlay': '随机播放',
    'player.more': '更多',
    'library.allAlbumsWithCount': '所有专辑（{count}）',
    'library.allArtistsWithCount': '所有歌手（{count}）',
    'library.allSongsWithCount': '所有歌曲（{count}）',
    'library.allSongs': '所有歌曲',
    'common.title': '标题',
    'common.artist': '歌手',
    'common.album': '专辑',
    'common.albumUnknown': '未知专辑',
    'common.artistUnknown': '未知歌手',
    'common.duration': '时长',
    'table.playCount': '播放次数',
    'table.dateAdded': '添加日期',
    'quickJump.enabled': '跳转到 {basis} 以 {group} 开头的{target}',
    'quickJump.disabled': '没有 {basis} 以 {group} 开头的{target}',
    'quickJump.letterGroup': '{key}',
    'quickJump.symbolGroup': '数字或符号',
    'local.currentPath': '当前路径',
    'local.hiddenFolders': '隐藏的文件夹',
    'local.path': '路径',
    'sidebar.back': '返回',
  },
);

const _snapshot = LibraryContentData(
  songs: [
    LibrarySong(
      id: 1,
      path: '/tmp/song.mp3',
      title: 'Song',
      artist: 'Artist',
      artists: ['Artist'],
      album: 'Album',
      duration: 120,
      playCount: 0,
      lyricsOffsetMs: 0,
      dateAdded: '2026-05-24T00:00:00',
      favorite: false,
      thumbnailPath: '',
    ),
  ],
  hasLibrary: true,
  sortCriterion: MusicLibrarySortCriterion.title,
  albumsSort: AlbumSortCriterion.defaultSort,
  databasePath: '/tmp/library.db',
  nowPlaying: NowPlayingSnapshot(playlistId: 0, songIds: [1]),
);

const _unknownAlbumSnapshot = LibraryContentData(
  songs: [
    LibrarySong(
      id: 1,
      path: '/tmp/song.mp3',
      title: 'Song',
      artist: '',
      artists: [''],
      album: '',
      duration: 120,
      playCount: 0,
      lyricsOffsetMs: 0,
      dateAdded: '2026-05-24T00:00:00',
      favorite: false,
      thumbnailPath: '',
    ),
  ],
  hasLibrary: true,
  sortCriterion: MusicLibrarySortCriterion.title,
  albumsSort: AlbumSortCriterion.defaultSort,
  databasePath: '/tmp/library.db',
  showCount: true,
);

const _unknownArtistSnapshot = LibraryContentData(
  songs: [
    LibrarySong(
      id: 1,
      path: '/tmp/song.mp3',
      title: 'Song',
      artist: '',
      artists: [],
      album: 'Album',
      duration: 120,
      playCount: 0,
      lyricsOffsetMs: 0,
      dateAdded: '2026-05-24T00:00:00',
      favorite: false,
      thumbnailPath: '',
    ),
  ],
  hasLibrary: true,
  sortCriterion: MusicLibrarySortCriterion.title,
  albumsSort: AlbumSortCriterion.defaultSort,
  databasePath: '/tmp/library.db',
  showCount: true,
);

const _localFolderSnapshot = LibraryContentData(
  songs: [],
  folders: [],
  hasLibrary: true,
  sortCriterion: MusicLibrarySortCriterion.title,
  albumsSort: AlbumSortCriterion.defaultSort,
  databasePath: '/tmp/library.db',
  rootPath: '/Users/test/Music',
);

const _localNoFolderSnapshot = LibraryContentData(
  songs: [],
  folders: [],
  hasLibrary: false,
  sortCriterion: MusicLibrarySortCriterion.title,
  albumsSort: AlbumSortCriterion.defaultSort,
  databasePath: '/tmp/library.db',
);

const _localNestedFolderSnapshot = LibraryContentData(
  songs: [],
  folders: [
    LibraryFolder(
      id: 10,
      path: '/Users/test/Music/Sub',
      parentId: 0,
      criterion: 0,
    ),
  ],
  hasLibrary: true,
  sortCriterion: MusicLibrarySortCriterion.title,
  albumsSort: AlbumSortCriterion.defaultSort,
  databasePath: '/tmp/library.db',
  rootPath: '/Users/test/Music',
);

class _WorkspaceAppBarTestApp extends ConsumerWidget {
  const _WorkspaceAppBarTestApp({
    this.currentPath = '/now-playing',
    this.currentLocation,
    this.snapshot = _snapshot,
    this.textScaler = const TextScaler.linear(1.5),
    this.child = const SizedBox.shrink(),
    this.portalTitle,
    this.portalContent,
    this.portalBottomContent,
    this.portalRoutePath = '/now-playing',
    this.portalRouteLocation,
    this.headeredPlaylistAppBar,
    this.navigationAppBarTopInset = 0,
  });

  final String currentPath;
  final String? currentLocation;
  final LibraryContentData snapshot;
  final TextScaler textScaler;
  final Widget child;
  final String? portalTitle;
  final Widget? portalContent;
  final Widget? portalBottomContent;
  final String portalRoutePath;
  final String? portalRouteLocation;
  final HeaderedPlaylistAppBarPortalEntry? headeredPlaylistAppBar;
  final double navigationAppBarTopInset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ProviderScope(
      overrides: [
        smPlayerI18nProvider.overrideWith((ref) async => _i18n),
        libraryContentDataProvider.overrideWith((ref) async => snapshot),
        workspaceAppBarPortalProvider.overrideWith(
          (ref) => WorkspaceAppBarPortalEntry(
            owner: Object(),
            routePath: portalRoutePath,
            routeLocation: portalRouteLocation,
            content:
                portalContent ??
                const CommandBar(
                  style: CommandBarStyleVariant.appBar,
                  overflowLabel: '更多',
                  overflowItems: [
                    MenuFlyoutItem(
                      key: 'locate',
                      text: '当前音乐',
                      icon: FluentIcons.music_note_2_20_regular,
                    ),
                    MenuFlyoutItem(
                      key: 'clear',
                      text: '清空全部',
                      icon: FluentIcons.dismiss_20_regular,
                    ),
                  ],
                  children: [
                    CommandBarButton(
                      icon: FluentIcons.play_20_regular,
                      label: '快速播放',
                      canOverflow: false,
                      onPressed: null,
                    ),
                    CommandBarButton(
                      icon: FluentIcons.arrow_shuffle_20_regular,
                      label: '随机播放',
                      canOverflow: false,
                      onPressed: null,
                    ),
                  ],
                ),
            title: portalTitle,
            bottomContent: portalBottomContent,
          ),
        ),
        if (headeredPlaylistAppBar != null)
          headeredPlaylistAppBarPortalProvider.overrideWith(
            (ref) => headeredPlaylistAppBar,
          ),
      ],
      child: SmPlayerI18nScope(
        i18n: _i18n,
        child: MaterialApp(
          theme: ThemeData(
            brightness: Brightness.dark,
            extensions: const [
              ShellThemeColors.dark,
              DefaultAlbumArtworkThemeColors.dark,
              LocalPageColors.night,
            ],
          ),
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(
                size: Size(430, 360),
              ).copyWith(textScaler: textScaler),
              child: SmPlayerWorkspace(
                currentPath: currentPath,
                currentLocation: currentLocation ?? currentPath,
                headerHeight: 92,
                showNavigationAppBar: true,
                navigationMenuLabel: '菜单',
                onNavigationMenuPressed: _noop,
                navigationAppBarTopInset: navigationAppBarTopInset,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void _noop() {}
