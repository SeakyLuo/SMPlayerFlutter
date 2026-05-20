import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
import 'package:smplayer_flutter/src/library/data/library_repository.dart';
import 'package:smplayer_flutter/src/library/ui/album_tile.dart'
    show getAlbumArtworkSong;
import 'package:smplayer_flutter/src/library/ui/albums_page.dart';
import 'package:smplayer_flutter/src/library/ui/page_selection_store.dart';
import 'package:smplayer_flutter/src/playback/media_control_model.dart';
import 'package:smplayer_flutter/src/playback/media_control_provider.dart';

void main() {
  setUp(PageSelectionController.clearStoredStates);

  const i18n = SmPlayerI18n(
    locale: 'zh-CN',
    messages: {
      'albums.addSelectedTo': '添加到',
      'albums.clearSelection': '清除选择',
      'albums.multiSelect': '多选',
      'albums.noMatch': '没有匹配的专辑',
      'albums.noMatchCopy': '换一个专辑或歌手关键词试试。',
      'albums.playSelected': '播放',
      'albums.reverseSelection': '反选',
      'albums.searchAlbumPlaceholder': '搜索专辑',
      'albums.selectAll': '全选',
      'albums.selectedCount': '已选择 {count} 项',
      'albums.sort.artist': '歌手',
      'albums.sort.default': '默认排序',
      'albums.sort.name': '名称',
      'albums.sort.reverse': '反向',
      'collection.noAlbums': '还没有专辑',
      'collection.scanFirst': '请先选择音乐文件夹并扫描。',
      'common.albumUnknown': '未知专辑',
      'common.artistUnknown': '未知歌手',
      'common.cancel': '取消',
      'common.albums': 'Albums',
      'common.multiSelect': 'Multi Select',
      'common.myFavorites': 'My Favorites',
      'common.clear': 'Clear',
      'common.nowPlaying': 'Now Playing',
      'common.sort': '排序',
      'context.addToPlaylist': '添加到',
      'context.select': '选择',
      'context.seeAlbumArt': '查看专辑插图',
      'local.sortReverseList': 'Reverse List',
      'nowPlaying.randomPlay': '随机播放',
      'playlists.newPlaylist': 'New Playlist',
      'sidebar.recentSearches': 'Recent searches',
      'sidebar.removeRecentSearch': 'Remove {query}',
      'player.more': '更多',
    },
  );

  testWidgets('AlbumsPage uses shared multi-select command bar', (
    tester,
  ) async {
    await tester.pumpWidget(_AlbumsTestApp(snapshot: _snapshot, i18n: i18n));
    await tester.pumpAndSettle();

    await tester.tap(find.text(i18n.t('common.multiSelect')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Blue Hour'));
    await tester.pumpAndSettle();

    expect(find.text('已选择 1 项'), findsOneWidget);

    await tester.tap(find.text('反选'));
    await tester.pumpAndSettle();

    expect(find.text('已选择 1 项'), findsOneWidget);
    expect(find.text('Red Days'), findsOneWidget);
  });

  testWidgets('AlbumsPage context menu can enter selection mode', (
    tester,
  ) async {
    await tester.pumpWidget(_AlbumsTestApp(snapshot: _snapshot, i18n: i18n));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Blue Hour'), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('选择'));
    await tester.pumpAndSettle();

    expect(find.text('已选择 1 项'), findsOneWidget);
  });

  testWidgets('AlbumsPage context menu uses Electron Add To submenu', (
    tester,
  ) async {
    await tester.pumpWidget(_AlbumsTestApp(snapshot: _snapshot, i18n: i18n));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Blue Hour'), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();

    expect(find.text(i18n.t('context.addToPlaylist')), findsAtLeastNWidgets(1));
    expect(find.text('Mix'), findsNothing);
    expect(find.text('Built in'), findsNothing);

    await tester.tap(find.text(i18n.t('context.addToPlaylist')).last);
    await tester.pumpAndSettle();

    expect(find.text('Now Playing'), findsOneWidget);
    expect(find.text('My Favorites'), findsOneWidget);
    expect(find.text('New Playlist'), findsOneWidget);
    expect(find.text('Mix'), findsOneWidget);
    expect(find.text('Built in'), findsNothing);
  });

  testWidgets('AlbumsPage multi-select play replaces Now Playing', (
    tester,
  ) async {
    final repository = _FakeLibraryRepository();
    final mediaController = MediaControlController();

    await tester.pumpWidget(
      _AlbumsTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: repository,
        mediaController: mediaController,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(i18n.t('common.multiSelect')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Blue Hour'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(i18n.t('albums.playSelected')));
    await tester.pumpAndSettle();

    expect(repository.replacedNowPlaying, [1]);
    expect(mediaController.state.track.id, 1);
    expect(mediaController.state.isPlaying, isTrue);
  });

  testWidgets('AlbumsPage multi-select adds album songs to playlist', (
    tester,
  ) async {
    final repository = _FakeLibraryRepository();

    await tester.pumpWidget(
      _AlbumsTestApp(snapshot: _snapshot, i18n: i18n, repository: repository),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(i18n.t('common.multiSelect')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Blue Hour'));
    await tester.pumpAndSettle();

    await tester.tap(find.text(i18n.t('albums.addSelectedTo')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mix'));
    await tester.pumpAndSettle();

    expect(repository.addedPlaylistId, 10);
    expect(repository.addedSongIds, [1]);
  });

  testWidgets('AlbumsPage exits multi-select in compact layout like Electron', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(640, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(_AlbumsTestApp(snapshot: _snapshot, i18n: i18n));
    await tester.pumpAndSettle();

    await tester.tap(find.text(i18n.t('common.multiSelect')));
    await tester.pumpAndSettle();

    expect(
      find.text(i18n.t('albums.selectedCount', {'count': 0})),
      findsNothing,
    );
  });

  testWidgets('AlbumsPage keeps quick jump visible in compact layout', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(640, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(_AlbumsTestApp(snapshot: _snapshot, i18n: i18n));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('Albums.QuickJump.B')), findsOneWidget);
    expect(find.byKey(const ValueKey('Albums.QuickJump.R')), findsOneWidget);
  });

  testWidgets('AlbumsPage reverse sort persists like Electron local state', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(_AlbumsTestApp(snapshot: _snapshot, i18n: i18n));
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.text('Blue Hour')).dx,
      lessThan(tester.getTopLeft(find.text('Red Days')).dx),
    );

    await tester.tap(find.text(i18n.t('albums.sort.default')).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(i18n.t('local.sortReverseList')));
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.text('Red Days')).dx,
      lessThan(tester.getTopLeft(find.text('Blue Hour')).dx),
    );
  });

  testWidgets('AlbumsPage quick jump keeps clicked key active on same row', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(640, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(_AlbumsTestApp(snapshot: _snapshot, i18n: i18n));
    await tester.pumpAndSettle();

    expect(_quickJumpBackground(tester, 'B'), isNot(Colors.transparent));
    expect(_quickJumpBackground(tester, 'R'), Colors.transparent);

    await tester.tap(find.byKey(const ValueKey('Albums.QuickJump.R')));
    await tester.pumpAndSettle();

    expect(_quickJumpBackground(tester, 'B'), Colors.transparent);
    expect(_quickJumpBackground(tester, 'R'), isNot(Colors.transparent));
  });

  testWidgets('AlbumsPage syncs Electron sort setting with selection', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final snapshot = ValueNotifier(_albumSortDefaultSnapshot);
    final repository = _ValueListenableAlbumsRepository(snapshot);

    await tester.pumpWidget(
      _AlbumsSnapshotListenableTestApp(
        snapshot: snapshot,
        i18n: i18n,
        repository: repository,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.text('Alpha Album')).dx,
      lessThan(tester.getTopLeft(find.text('Zeta Album')).dx),
    );

    await tester.tap(find.text(i18n.t('common.multiSelect')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alpha Album'));
    await tester.pumpAndSettle();

    snapshot.value = _albumSortArtistSnapshot;
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.text('Zeta Album')).dx,
      lessThan(tester.getTopLeft(find.text('Alpha Album')).dx),
    );
  });

  testWidgets('AlbumsPage album play records the album like Electron', (
    tester,
  ) async {
    final repository = _FakeLibraryRepository();
    final mediaController = MediaControlController();

    await tester.pumpWidget(
      _AlbumsTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: repository,
        mediaController: mediaController,
      ),
    );
    await tester.pumpAndSettle();

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    await gesture.moveTo(tester.getCenter(find.text('Blue Hour')));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(FluentIcons.play_20_filled).first);
    await tester.pumpAndSettle();

    expect(repository.recordedAlbums, ['Blue Hour']);
    expect(repository.replacedNowPlaying, [1]);
    expect(mediaController.state.track.id, 1);
    await gesture.removePointer();
  });

  testWidgets('AlbumsPage opens album tiles through the Electron query route', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/albums',
      routes: [
        GoRoute(
          path: '/albums',
          builder:
              (context, state) => Scaffold(
                body: AlbumsPage(
                  targetAlbumName: state.uri.queryParameters['album'],
                ),
              ),
        ),
      ],
    );

    await tester.pumpWidget(
      _AlbumsRouterTestApp(snapshot: _snapshot, i18n: i18n, router: router),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Blue Hour'));
    await tester.pumpAndSettle();

    final uri = router.routeInformationProvider.value.uri;
    expect(uri.path, '/albums');
    expect(uri.queryParameters['album'], 'Blue Hour');
  });

  testWidgets('AlbumsPage records submitted album searches', (tester) async {
    final repository = _FakeLibraryRepository();

    await tester.pumpWidget(
      _AlbumsTestApp(snapshot: _snapshot, i18n: i18n, repository: repository),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), ' Blue ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(repository.recordedSearches, [
      (query: 'Blue', type: SearchHistoryType.albums),
    ]);
  });

  test('searchAlbums follows Electron album-name scope', () {
    final albums = buildAlbumViews(_snapshot.songs, i18n);

    expect(searchAlbums(albums, 'Artist A'), isEmpty);
    expect(searchAlbums(albums, 'Blue').map((album) => album.name), [
      'Blue Hour',
    ]);
  });

  test('album artwork picks first song with artwork like Electron', () {
    expect(getAlbumArtworkSong(_albumArtworkSongs).id, 2);
  });

  test('buildAlbumViews keeps Electron source-order artwork', () {
    final albums = buildAlbumViews(_albumArtworkSourceOrderSongs, i18n);

    expect(albums.single.songs.map((song) => song.id), [4, 3]);
    expect(albums.single.artworkSong!.id, 3);
  });

  testWidgets('AlbumsPage selects album search suggestions', (tester) async {
    final repository = _FakeLibraryRepository();

    await tester.pumpWidget(
      _AlbumsTestApp(snapshot: _snapshot, i18n: i18n, repository: repository),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Blu');
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('PageSearchHistoryPanel.Item.Blue Hour')),
    );
    await tester.pumpAndSettle();

    expect(repository.recordedSearches, [
      (query: 'Blue Hour', type: SearchHistoryType.albums),
    ]);
    expect(find.text('Red Days'), findsNothing);
  });

  testWidgets('AlbumsPage selects recent album searches', (tester) async {
    final repository = _FakeLibraryRepository();

    await tester.pumpWidget(
      _AlbumsTestApp(snapshot: _snapshot, i18n: i18n, repository: repository),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('PageSearchHistoryPanel.Item.Red')),
    );
    await tester.pumpAndSettle();

    expect(repository.recordedSearches, [
      (query: 'Red', type: SearchHistoryType.albums),
    ]);
    expect(find.text('Blue Hour'), findsNothing);
  });
}

Color? _quickJumpBackground(WidgetTester tester, String key) {
  final button = tester.widget<TextButton>(
    find.byKey(ValueKey('Albums.QuickJump.$key')),
  );
  return button.style?.backgroundColor?.resolve({});
}

class _AlbumsRouterTestApp extends StatelessWidget {
  const _AlbumsRouterTestApp({
    required this.snapshot,
    required this.i18n,
    required this.router,
  });

  final MusicLibrarySnapshot snapshot;
  final SmPlayerI18n i18n;
  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        smPlayerI18nProvider.overrideWith((ref) async => i18n),
        musicLibrarySnapshotProvider.overrideWith((ref) async => snapshot),
      ],
      child: SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
  }
}

class _AlbumsTestApp extends StatelessWidget {
  const _AlbumsTestApp({
    required this.snapshot,
    required this.i18n,
    this.repository,
    this.mediaController,
  });

  final MusicLibrarySnapshot snapshot;
  final SmPlayerI18n i18n;
  final LibraryRepository? repository;
  final MediaControlController? mediaController;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        smPlayerI18nProvider.overrideWith((ref) async => i18n),
        musicLibrarySnapshotProvider.overrideWith((ref) async => snapshot),
        if (repository != null)
          libraryRepositoryProvider.overrideWithValue(repository!),
        if (mediaController != null)
          mediaControlControllerProvider.overrideWith(
            (ref) => mediaController!,
          ),
      ],
      child: SmPlayerI18nScope(
        i18n: i18n,
        child: const MaterialApp(home: Scaffold(body: AlbumsPage())),
      ),
    );
  }
}

class _AlbumsSnapshotListenableTestApp extends StatelessWidget {
  const _AlbumsSnapshotListenableTestApp({
    required this.snapshot,
    required this.i18n,
    required this.repository,
  });

  final ValueNotifier<MusicLibrarySnapshot> snapshot;
  final SmPlayerI18n i18n;
  final _ValueListenableAlbumsRepository repository;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        smPlayerI18nProvider.overrideWith((ref) async => i18n),
        libraryRepositoryProvider.overrideWithValue(repository),
      ],
      child: SmPlayerI18nScope(
        i18n: i18n,
        child: _AlbumsSnapshotInvalidator(snapshot: snapshot),
      ),
    );
  }
}

class _AlbumsSnapshotInvalidator extends ConsumerStatefulWidget {
  const _AlbumsSnapshotInvalidator({required this.snapshot});

  final ValueNotifier<MusicLibrarySnapshot> snapshot;

  @override
  ConsumerState<_AlbumsSnapshotInvalidator> createState() =>
      _AlbumsSnapshotInvalidatorState();
}

class _AlbumsSnapshotInvalidatorState
    extends ConsumerState<_AlbumsSnapshotInvalidator> {
  @override
  void initState() {
    super.initState();
    widget.snapshot.addListener(_invalidateSnapshot);
  }

  @override
  void didUpdateWidget(_AlbumsSnapshotInvalidator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.snapshot != widget.snapshot) {
      oldWidget.snapshot.removeListener(_invalidateSnapshot);
      widget.snapshot.addListener(_invalidateSnapshot);
    }
  }

  @override
  void dispose() {
    widget.snapshot.removeListener(_invalidateSnapshot);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: Scaffold(body: AlbumsPage()));
  }

  void _invalidateSnapshot() {
    ref.invalidate(musicLibrarySnapshotProvider);
  }
}

class _FakeLibraryRepository extends LibraryRepository {
  List<int> replacedNowPlaying = [];
  int? addedPlaylistId;
  List<int> addedSongIds = [];
  List<int> favoriteSongIds = [];
  bool? favoriteValue;
  List<String> recordedAlbums = [];
  List<({String query, SearchHistoryType type})> recordedSearches = [];

  @override
  Future<void> replaceNowPlaying(List<int> songIds) async {
    replacedNowPlaying = songIds.toList();
  }

  @override
  Future<void> addSongsToPlaylist(int playlistId, List<int> songIds) async {
    addedPlaylistId = playlistId;
    addedSongIds = songIds.toList();
  }

  @override
  Future<void> setSongsFavorite(List<int> songIds, bool favorite) async {
    favoriteSongIds = songIds.toList();
    favoriteValue = favorite;
  }

  @override
  Future<void> recordAlbumPlayed(String album) async {
    recordedAlbums.add(album);
  }

  @override
  Future<void> addRecentSearch(
    String query, [
    SearchHistoryType type = SearchHistoryType.sidebar,
  ]) async {
    recordedSearches.add((query: query, type: type));
  }
}

class _ValueListenableAlbumsRepository extends _FakeLibraryRepository {
  _ValueListenableAlbumsRepository(this.snapshot);

  final ValueNotifier<MusicLibrarySnapshot> snapshot;

  @override
  Future<MusicLibrarySnapshot> getMusicLibrarySnapshot() async {
    return snapshot.value;
  }
}

const _snapshot = MusicLibrarySnapshot(
  songs: [
    LibrarySong(
      id: 1,
      path: r'C:\Music\blue.mp3',
      title: 'Blue Song',
      artist: 'Artist A',
      artists: ['Artist A'],
      album: 'Blue Hour',
      duration: 120,
      playCount: 0,
      lyricsOffsetMs: 0,
      dateAdded: '2026-05-20T00:00:00',
      favorite: false,
      thumbnailPath: '',
    ),
    LibrarySong(
      id: 2,
      path: r'C:\Music\red.mp3',
      title: 'Red Song',
      artist: 'Artist B',
      artists: ['Artist B'],
      album: 'Red Days',
      duration: 120,
      playCount: 0,
      lyricsOffsetMs: 0,
      dateAdded: '2026-05-20T00:00:00',
      favorite: false,
      thumbnailPath: '',
    ),
  ],
  recentSongs: [],
  recentPlaylists: [],
  recentAlbums: [],
  recentArtists: [],
  recentSearches: [
    SearchHistoryEntry(
      id: 21,
      query: 'Red',
      type: SearchHistoryType.albums,
      searchedAt: '2026-05-20T00:00:00',
    ),
  ],
  playlists: [
    LibraryPlaylist(
      id: 3,
      name: 'Built in',
      priority: 0,
      songCount: 0,
      songIds: [],
      sortCriterion: PlaylistSortCriterion.title,
      isBuiltIn: true,
    ),
    LibraryPlaylist(
      id: 10,
      name: 'Mix',
      priority: 1,
      songCount: 0,
      songIds: [],
      sortCriterion: PlaylistSortCriterion.title,
      isBuiltIn: false,
    ),
  ],
  favoritePlaylistId: 1,
  nowPlaying: NowPlayingSnapshot(playlistId: 0, songIds: []),
  hasLibrary: true,
  sortCriterion: MusicLibrarySortCriterion.title,
  albumsSort: AlbumSortCriterion.defaultSort,
  showCount: true,
  hideMultiSelectCommandBarAfterOperation: true,
  databasePath: '',
);

const _albumSortDefaultSnapshot = MusicLibrarySnapshot(
  songs: [
    LibrarySong(
      id: 20,
      path: r'C:\Music\zeta.mp3',
      title: 'Zeta Song',
      artist: 'Artist A',
      artists: ['Artist A'],
      album: 'Zeta Album',
      duration: 120,
      playCount: 0,
      lyricsOffsetMs: 0,
      dateAdded: '2026-05-20T00:00:00',
      favorite: false,
      thumbnailPath: '',
    ),
    LibrarySong(
      id: 21,
      path: r'C:\Music\alpha.mp3',
      title: 'Alpha Song',
      artist: 'Artist B',
      artists: ['Artist B'],
      album: 'Alpha Album',
      duration: 120,
      playCount: 0,
      lyricsOffsetMs: 0,
      dateAdded: '2026-05-20T00:00:00',
      favorite: false,
      thumbnailPath: '',
    ),
  ],
  recentSongs: [],
  recentPlaylists: [],
  recentAlbums: [],
  recentArtists: [],
  recentSearches: [],
  playlists: [],
  favoritePlaylistId: 1,
  nowPlaying: NowPlayingSnapshot(playlistId: 0, songIds: []),
  hasLibrary: true,
  sortCriterion: MusicLibrarySortCriterion.title,
  albumsSort: AlbumSortCriterion.defaultSort,
  showCount: true,
  hideMultiSelectCommandBarAfterOperation: true,
  databasePath: '',
);

final _albumSortArtistSnapshot = MusicLibrarySnapshot(
  songs: _albumSortDefaultSnapshot.songs,
  recentSongs: _albumSortDefaultSnapshot.recentSongs,
  recentPlaylists: _albumSortDefaultSnapshot.recentPlaylists,
  recentAlbums: _albumSortDefaultSnapshot.recentAlbums,
  recentArtists: _albumSortDefaultSnapshot.recentArtists,
  recentSearches: _albumSortDefaultSnapshot.recentSearches,
  playlists: _albumSortDefaultSnapshot.playlists,
  favoritePlaylistId: _albumSortDefaultSnapshot.favoritePlaylistId,
  nowPlaying: _albumSortDefaultSnapshot.nowPlaying,
  hasLibrary: _albumSortDefaultSnapshot.hasLibrary,
  sortCriterion: MusicLibrarySortCriterion.title,
  albumsSort: AlbumSortCriterion.artist,
  showCount: _albumSortDefaultSnapshot.showCount,
  hideMultiSelectCommandBarAfterOperation:
      _albumSortDefaultSnapshot.hideMultiSelectCommandBarAfterOperation,
  databasePath: _albumSortDefaultSnapshot.databasePath,
);

const _albumArtworkSongs = [
  LibrarySong(
    id: 1,
    path: r'C:\Music\first.mp3',
    title: 'First Song',
    artist: 'Artist A',
    artists: ['Artist A'],
    album: 'Blue Hour',
    duration: 120,
    playCount: 0,
    lyricsOffsetMs: 0,
    dateAdded: '2026-05-20T00:00:00',
    favorite: false,
    thumbnailPath: '',
  ),
  LibrarySong(
    id: 2,
    path: r'C:\Music\artwork.mp3',
    title: 'Artwork Song',
    artist: 'Artist A',
    artists: ['Artist A'],
    album: 'Blue Hour',
    duration: 120,
    playCount: 0,
    lyricsOffsetMs: 0,
    dateAdded: '2026-05-19T00:00:00',
    favorite: false,
    thumbnailPath: r'C:\Music\cover.jpg',
  ),
];

const _albumArtworkSourceOrderSongs = [
  LibrarySong(
    id: 3,
    path: r'C:\Music\zulu-artwork.mp3',
    title: 'Zulu Artwork',
    artist: 'Artist A',
    artists: ['Artist A'],
    album: 'Blue Hour',
    duration: 120,
    playCount: 0,
    lyricsOffsetMs: 0,
    dateAdded: '2026-05-20T00:00:00',
    favorite: false,
    thumbnailPath: r'C:\Music\zulu-cover.jpg',
  ),
  LibrarySong(
    id: 4,
    path: r'C:\Music\alpha-artwork.mp3',
    title: 'Alpha Artwork',
    artist: 'Artist A',
    artists: ['Artist A'],
    album: 'Blue Hour',
    duration: 120,
    playCount: 0,
    lyricsOffsetMs: 0,
    dateAdded: '2026-05-19T00:00:00',
    favorite: false,
    thumbnailPath: r'C:\Music\alpha-cover.jpg',
  ),
];
