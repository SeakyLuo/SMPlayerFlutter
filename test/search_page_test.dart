import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
import 'package:smplayer_flutter/src/library/data/library_repository.dart';
import 'package:smplayer_flutter/src/library/ui/search_page.dart';

void main() {
  const i18n = SmPlayerI18n(
    locale: 'en-US',
    messages: {
      'albums.addSelectedTo': 'Add To',
      'albums.artistSeparator': ', ',
      'albums.clearSelection': 'Clear Selection',
      'albums.playSelected': 'Play Selected',
      'albums.reverseSelection': 'Reverse Selection',
      'albums.selectAll': 'Select All',
      'albums.selectedCount': '{count} selected',
      'common.all': 'All',
      'common.albumUnknown': 'Unknown Album',
      'common.albums': 'Albums',
      'common.duration': 'Duration',
      'common.folders': 'Folders',
      'common.myFavorites': 'My Favorites',
      'common.nowPlaying': 'Now Playing',
      'common.playCount': 'Play count',
      'common.playlists': 'Playlists',
      'common.search': 'Search',
      'common.songs': 'Songs',
      'common.sort': 'Sort',
      'common.artists': 'Artists',
      'context.addToPlaylist': 'Add To',
      'context.play': 'Play',
      'context.select': 'Select',
      'playlists.newPlaylist': 'New Playlist',
      'player.more': 'More',
      'search.directoryResultOf': 'Results for {query} in {folder}',
      'search.enterKeyword': 'Enter a keyword',
      'search.artistsWithCount': 'Artists {count}',
      'search.albumsWithCount': 'Albums {count}',
      'search.foldersWithCount': 'Folders {count}',
      'search.noResult': 'No results',
      'search.playlistsWithCount': 'Playlists {count}',
      'search.resultOf': 'Results for {query}',
      'search.resultSummary': '{count} results',
      'search.resultTitle': 'Search',
      'search.songsWithCount': 'Songs {count}',
      'search.sortDefault': 'Default',
      'search.sortTitle': 'Title',
      'search.viewAll': 'View all',
      'search.viewLess': 'View less',
    },
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('SearchPage scopes results to the Electron folder parameter', (
    tester,
  ) async {
    final repository = _FakeLibraryRepository();

    await tester.pumpWidget(
      _SearchPageTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: repository,
        child: const SearchPage(
          query: 'song',
          activeType: 'songs',
          folderRelativePath: 'Sub',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Child Song'), findsOneWidget);
    expect(find.text('Root Song'), findsNothing);
    expect(repository.recordedSearches, [
      (query: 'song', type: SearchHistoryType.folders),
    ]);
  });

  testWidgets('SearchPage sort opens shared MenuFlyout', (tester) async {
    await tester.pumpWidget(
      _SearchPageTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: _FakeLibraryRepository(),
        child: const SearchPage(query: 'song', activeType: 'songs'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Default'), findsOneWidget);

    await tester.tap(find.text('Default'));
    await tester.pumpAndSettle();

    expect(find.text('Default'), findsWidgets);
    expect(find.text('Title'), findsOneWidget);
  });

  testWidgets('SearchPage multi-select Add To can append to Now Playing', (
    tester,
  ) async {
    final repository = _FakeLibraryRepository();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    await tester.pumpWidget(
      _SearchPageTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: repository,
        child: const SearchPage(query: 'song', activeType: 'songs'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Root Song'), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add To'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Now Playing'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));

    expect(repository.replacedNowPlaying, [99, 1]);
  });

  testWidgets('SearchPage album add opens Electron Add To menu', (
    tester,
  ) async {
    final repository = _FakeLibraryRepository();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    await tester.pumpWidget(
      _SearchPageTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: repository,
        child: const SearchPage(query: 'root', activeType: 'albums'),
      ),
    );
    await tester.pumpAndSettle();

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(find.text('Root Album')));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(FluentIcons.add_20_regular).last);
    await tester.pumpAndSettle();

    expect(find.text('Now Playing'), findsOneWidget);
    expect(find.text('Mix'), findsOneWidget);
    expect(repository.replacedNowPlaying, isEmpty);
  });

  testWidgets('SearchPage single-song Add To uses Electron single add path', (
    tester,
  ) async {
    final repository = _FakeLibraryRepository();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    await tester.pumpWidget(
      _SearchPageTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: repository,
        child: const SearchPage(query: 'root', activeType: 'albums'),
      ),
    );
    await tester.pumpAndSettle();

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(find.text('Root Album')));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(FluentIcons.add_20_regular).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mix'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));

    expect(repository.addedSingleSongs, [(playlistId: 10, songId: 1)]);
    expect(repository.addedSongGroups, isEmpty);
  });

  testWidgets('SearchPage empty states do not render result tabs', (
    tester,
  ) async {
    await tester.pumpWidget(
      _SearchPageTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: _FakeLibraryRepository(),
        child: const SearchPage(query: '', activeType: null),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Enter a keyword'), findsOneWidget);
    expect(find.text('All'), findsNothing);

    await tester.pumpWidget(
      _SearchPageTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: _FakeLibraryRepository(),
        child: const SearchPage(query: 'zzzzzz', activeType: null),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No results'), findsOneWidget);
    expect(find.text('All'), findsNothing);
  });

  testWidgets('SearchPage view all expands the section without changing tabs', (
    tester,
  ) async {
    await tester.pumpWidget(
      _SearchPageTestApp(
        snapshot: _artistPreviewSnapshot,
        i18n: i18n,
        repository: _FakeLibraryRepository(),
        child: const SearchPage(query: 'Band', activeType: null),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Band 10'), findsNothing);

    await tester.tap(find.text('View all').first);
    await tester.pumpAndSettle();

    expect(find.text('Band 10'), findsOneWidget);
    expect(find.text('View less'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
  });

  testWidgets('SearchPage query changes reset the active filter to All', (
    tester,
  ) async {
    final repository = _FakeLibraryRepository();

    await tester.pumpWidget(
      _SearchPageTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: repository,
        child: const SearchPage(query: 'root', activeType: 'albums'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Root Album'), findsOneWidget);
    expect(find.text('Root Song'), findsNothing);

    await tester.pumpWidget(
      _SearchPageTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: repository,
        child: const SearchPage(query: 'song', activeType: 'albums'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Root Song'), findsOneWidget);
    expect(find.text('Child Song'), findsOneWidget);
  });

  testWidgets('SearchPage does not render empty typed sections', (
    tester,
  ) async {
    await tester.pumpWidget(
      _SearchPageTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: _FakeLibraryRepository(),
        child: const SearchPage(query: 'song', activeType: 'playlists'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('All'), findsOneWidget);
    expect(find.text('Playlists 0'), findsNothing);
    expect(find.text('Root Song'), findsNothing);
  });
}

class _SearchPageTestApp extends StatelessWidget {
  const _SearchPageTestApp({
    required this.snapshot,
    required this.i18n,
    required this.repository,
    required this.child,
  });

  final MusicLibrarySnapshot snapshot;
  final SmPlayerI18n i18n;
  final LibraryRepository repository;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        smPlayerI18nProvider.overrideWith((ref) async => i18n),
        musicLibrarySnapshotProvider.overrideWith((ref) async => snapshot),
        libraryRepositoryProvider.overrideWithValue(repository),
      ],
      child: SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp(home: Scaffold(body: child)),
      ),
    );
  }
}

class _FakeLibraryRepository extends LibraryRepository {
  List<int> replacedNowPlaying = [];
  List<({String query, SearchHistoryType type})> recordedSearches = [];
  List<({int playlistId, int songId})> addedSingleSongs = [];
  List<({int playlistId, List<int> songIds})> addedSongGroups = [];

  @override
  Future<void> replaceNowPlaying(List<int> songIds) async {
    replacedNowPlaying = songIds.toList();
  }

  @override
  Future<void> addRecentSearch(
    String query, [
    SearchHistoryType type = SearchHistoryType.sidebar,
  ]) async {
    recordedSearches.add((query: query, type: type));
  }

  @override
  Future<void> addSongToPlaylist(int playlistId, int songId) async {
    addedSingleSongs.add((playlistId: playlistId, songId: songId));
  }

  @override
  Future<void> addSongsToPlaylist(int playlistId, List<int> songIds) async {
    addedSongGroups.add((playlistId: playlistId, songIds: songIds.toList()));
  }

  @override
  Future<List<SongArtworkSnapshot>> getSongArtworkSnapshots(
    List<int> songIds,
  ) async {
    return [
      for (final songId in songIds)
        SongArtworkSnapshot(
          songId: songId,
          artworkUrl: '',
          sourceUrl: '',
          sourcePath: '',
          source: SongArtworkSource.none,
        ),
    ];
  }
}

const _snapshot = MusicLibrarySnapshot(
  songs: [
    LibrarySong(
      id: 1,
      path: r'C:\Music\root.mp3',
      title: 'Root Song',
      artist: 'Artist A',
      artists: ['Artist A'],
      album: 'Root Album',
      duration: 120,
      playCount: 0,
      lyricsOffsetMs: 0,
      dateAdded: '2026-05-20T00:00:00',
      favorite: false,
      thumbnailPath: '',
    ),
    LibrarySong(
      id: 2,
      path: r'C:\Music\Sub\child.mp3',
      title: 'Child Song',
      artist: 'Artist B',
      artists: ['Artist B'],
      album: 'Child Album',
      duration: 90,
      playCount: 0,
      lyricsOffsetMs: 0,
      dateAdded: '2026-05-20T00:00:00',
      favorite: false,
      thumbnailPath: '',
    ),
  ],
  folders: [
    LibraryFolder(id: 4, path: r'C:\Music\Sub', parentId: 0, criterion: 0),
  ],
  playlists: [
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
  favoritePlaylistId: 3,
  nowPlaying: NowPlayingSnapshot(playlistId: 0, songIds: [99]),
  hasLibrary: true,
  sortCriterion: MusicLibrarySortCriterion.title,
  albumsSort: AlbumSortCriterion.defaultSort,
  showCount: true,
  hideMultiSelectCommandBarAfterOperation: true,
  rootPath: r'C:\Music',
  databasePath: '',
);

final _artistPreviewSnapshot = MusicLibrarySnapshot(
  songs: [
    for (var index = 0; index < 11; index += 1)
      LibrarySong(
        id: index + 1,
        path:
            r'C:\Music\artist'
            '$index.mp3',
        title:
            index == 10
                ? 'Track 99'
                : 'Track ${index.toString().padLeft(2, '0')}',
        artist:
            index == 10
                ? 'Band 10'
                : 'Band ${index.toString().padLeft(2, '0')}',
        artists: [
          index == 10 ? 'Band 10' : 'Band ${index.toString().padLeft(2, '0')}',
        ],
        album: 'Album ${index.toString().padLeft(2, '0')}',
        duration: 120,
        playCount: 0,
        lyricsOffsetMs: 0,
        dateAdded: '2026-05-20T00:00:00',
        favorite: false,
        thumbnailPath: '',
      ),
  ],
  folders: [],
  playlists: [],
  favoritePlaylistId: 3,
  nowPlaying: NowPlayingSnapshot(playlistId: 0, songIds: []),
  hasLibrary: true,
  sortCriterion: MusicLibrarySortCriterion.title,
  albumsSort: AlbumSortCriterion.defaultSort,
  showCount: true,
  hideMultiSelectCommandBarAfterOperation: true,
  rootPath: r'C:\Music',
  databasePath: '',
);
