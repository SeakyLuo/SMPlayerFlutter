import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
import 'package:smplayer_flutter/src/library/data/library_repository.dart';
import 'package:smplayer_flutter/src/recent/recent_page.dart';

void main() {
  const i18n = SmPlayerI18n(
    locale: 'en-US',
    messages: {
      'albums.clearSelection': 'Clear Selection',
      'albums.addSelectedTo': 'Add To',
      'albums.multiSelect': 'Multi Select',
      'albums.playSelected': 'Play Selected',
      'albums.reverseSelection': 'Reverse Selection',
      'albums.selectAll': 'Select All',
      'albums.selectedCount': '{count} selected',
      'common.albumUnknown': 'Unknown Album',
      'common.artistUnknown': 'Unknown Artist',
      'common.cancel': 'Cancel',
      'common.clear': 'Clear',
      'common.confirm': 'Confirm',
      'common.myFavorites': 'My Favorites',
      'common.nowPlaying': 'Now Playing',
      'common.open': 'Open',
      'common.search': 'Search',
      'context.addToPlaylist': 'Add To',
      'context.pause': 'Pause',
      'context.play': 'Play',
      'context.playNext': 'Play Next',
      'context.removeFromList': 'Remove',
      'context.seeAlbum': 'See Album',
      'context.seeAlbumArt': 'See Album Art',
      'context.seeArtist': 'See Artist',
      'context.seeLyrics': 'See Lyrics',
      'context.seeMusicInfo': 'See Music Info',
      'context.select': 'Select',
      'nowPlaying.randomPlay': 'Shuffle',
      'playlists.create': 'Create',
      'playlists.createNew': 'Create Playlist',
      'playlists.namePlaceholder': 'Playlist name',
      'playlists.newPlaylist': 'New Playlist',
      'player.more': 'More',
      'recent.clearHistory': 'Clear History',
      'recent.clearPlayedConfirm': 'Clear played history?',
      'recent.clearSearchesConfirm': 'Clear search history?',
      'recent.added': 'Added',
      'recent.played': 'Played',
      'recent.searches': 'Searches',
      'recent.artists': 'Artists',
      'recent.albums': 'Albums',
      'recent.playlists': 'Playlists',
    },
  );

  testWidgets('RecentPage song menu uses Electron Add To submenu', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(_RecentTestApp(snapshot: _snapshot, i18n: i18n));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Blue Song'), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();

    expect(find.text('Add To'), findsOneWidget);
    expect(find.text('Mix'), findsNothing);
    expect(find.text('Built in'), findsNothing);

    await tester.tap(find.text('Add To'));
    await tester.pumpAndSettle();

    expect(find.text('Now Playing'), findsOneWidget);
    expect(find.text('My Favorites'), findsOneWidget);
    expect(find.text('New Playlist'), findsOneWidget);
    expect(find.text('Mix'), findsOneWidget);
    expect(find.text('Built in'), findsNothing);
  });

  testWidgets('RecentPage multi-select Add To writes to now playing', (
    tester,
  ) async {
    final repository = _FakeLibraryRepository();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _RecentTestApp(snapshot: _snapshot, i18n: i18n, repository: repository),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Multi Select'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Blue Song'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add To'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Now Playing'));
    await tester.pumpAndSettle();

    expect(repository.replacedNowPlaying, [1]);
    expect(find.text('1 selected'), findsNothing);
  });

  testWidgets('RecentPage confirms before clearing recent searches', (
    tester,
  ) async {
    final repository = _FakeLibraryRepository();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _RecentTestApp(
        snapshot: _snapshotWithSearches,
        i18n: i18n,
        repository: repository,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Searches  1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear History'));
    await tester.pumpAndSettle();

    expect(find.text('Clear search history?'), findsOneWidget);
    expect(repository.clearedRecentSearches, isFalse);

    await tester.tap(find.text('Confirm').last);
    await tester.pumpAndSettle();

    expect(repository.clearedRecentSearches, isTrue);
  });
}

class _RecentTestApp extends StatelessWidget {
  const _RecentTestApp({
    required this.snapshot,
    required this.i18n,
    this.repository,
  });

  final MusicLibrarySnapshot snapshot;
  final SmPlayerI18n i18n;
  final LibraryRepository? repository;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        smPlayerI18nProvider.overrideWith((ref) async => i18n),
        musicLibrarySnapshotProvider.overrideWith((ref) async => snapshot),
        if (repository != null)
          libraryRepositoryProvider.overrideWithValue(repository!),
      ],
      child: SmPlayerI18nScope(
        i18n: i18n,
        child: const MaterialApp(home: Scaffold(body: RecentPage())),
      ),
    );
  }
}

class _FakeLibraryRepository extends LibraryRepository {
  List<int> replacedNowPlaying = [];
  bool clearedRecentSearches = false;

  @override
  Future<void> replaceNowPlaying(List<int> songIds) async {
    replacedNowPlaying = songIds.toList();
  }

  @override
  Future<void> clearRecentSearches() async {
    clearedRecentSearches = true;
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
  ],
  recentSongs: [],
  recentPlaylists: [],
  recentAlbums: [],
  recentArtists: [],
  recentSearches: [],
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
  favoritePlaylistId: 3,
  nowPlaying: NowPlayingSnapshot(playlistId: 0, songIds: []),
  hasLibrary: true,
  sortCriterion: MusicLibrarySortCriterion.title,
  albumsSort: AlbumSortCriterion.defaultSort,
  showCount: true,
  hideMultiSelectCommandBarAfterOperation: true,
  databasePath: '',
);

const _snapshotWithSearches = MusicLibrarySnapshot(
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
  ],
  recentSearches: [
    SearchHistoryEntry(
      id: 4,
      query: 'blue',
      type: SearchHistoryType.sidebar,
      searchedAt: '2026-05-20T00:00:00',
    ),
  ],
  playlists: [],
  favoritePlaylistId: 0,
  nowPlaying: NowPlayingSnapshot(playlistId: 0, songIds: []),
  hasLibrary: true,
  sortCriterion: MusicLibrarySortCriterion.title,
  albumsSort: AlbumSortCriterion.defaultSort,
  showCount: true,
  hideMultiSelectCommandBarAfterOperation: true,
  databasePath: '',
);
