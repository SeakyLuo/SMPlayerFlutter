import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smplayer_flutter/src/app/shell_colors.dart';
import 'package:smplayer_flutter/src/app/shell_workspace.dart';
import 'package:smplayer_flutter/src/app/workspace_app_bar_portal.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
import 'package:smplayer_flutter/src/library/ui/artists_page.dart';
import 'package:smplayer_flutter/src/library/ui/albums_page.dart';
import 'package:smplayer_flutter/src/library/ui/command_bar.dart';
import 'package:smplayer_flutter/src/library/ui/default_album_artwork.dart';
import 'package:smplayer_flutter/src/library/ui/menu_flyout.dart';
import 'package:smplayer_flutter/src/library/ui/music_library_page.dart';
import 'package:smplayer_flutter/src/playback/now_playing_page.dart';

void main() {
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

class _WorkspaceAppBarTestApp extends ConsumerWidget {
  const _WorkspaceAppBarTestApp({
    this.currentPath = '/now-playing',
    this.currentLocation,
    this.snapshot = _snapshot,
    this.textScaler = const TextScaler.linear(1.5),
    this.child = const SizedBox.shrink(),
    this.portalTitle,
    this.portalRoutePath = '/now-playing',
    this.portalRouteLocation,
  });

  final String currentPath;
  final String? currentLocation;
  final LibraryContentData snapshot;
  final TextScaler textScaler;
  final Widget child;
  final String? portalTitle;
  final String portalRoutePath;
  final String? portalRouteLocation;

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
            content: const CommandBar(
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
          ),
        ),
      ],
      child: SmPlayerI18nScope(
        i18n: _i18n,
        child: MaterialApp(
          theme: ThemeData(
            extensions: const [
              ShellThemeColors.dark,
              DefaultAlbumArtworkThemeColors.dark,
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
                navigationAppBarTopInset: 0,
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
