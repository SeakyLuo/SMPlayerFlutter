import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
      'common.duration': 'Duration',
      'common.myFavorites': 'My Favorites',
      'common.nowPlaying': 'Now Playing',
      'common.playCount': 'Play count',
      'common.search': 'Search',
      'common.songs': 'Songs',
      'common.sort': 'Sort',
      'context.addToPlaylist': 'Add To',
      'context.play': 'Play',
      'context.select': 'Select',
      'playlists.newPlaylist': 'New Playlist',
      'player.more': 'More',
      'search.directoryResultOf': 'Results for {query} in {folder}',
      'search.enterKeyword': 'Enter a keyword',
      'search.noResult': 'No results',
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

    expect(find.text('Results for song in Sub'), findsOneWidget);
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

    expect(repository.replacedNowPlaying, [99, 1]);
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
