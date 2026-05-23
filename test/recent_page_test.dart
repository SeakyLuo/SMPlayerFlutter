import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
import 'package:smplayer_flutter/src/library/data/library_repository.dart';
import 'package:smplayer_flutter/src/recent/recent_page.dart';
import 'package:smplayer_flutter/src/settings/settings_model.dart'
    show LyricsRequestMode;

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
      'common.all': 'All',
      'common.artistUnknown': 'Unknown Artist',
      'common.cancel': 'Cancel',
      'common.clear': 'Clear',
      'common.confirm': 'Confirm',
      'common.folders': 'Folders',
      'common.myFavorites': 'My Favorites',
      'common.nowPlaying': 'Now Playing',
      'common.open': 'Open',
      'common.search': 'Search',
      'common.songs': 'Songs',
      'common.undo': 'Undo',
      'context.addToPlaylist': 'Add To',
      'context.hideFile': 'Hide File',
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
      'context.view': 'View',
      'nowPlaying.randomPlay': 'Shuffle',
      'notification.hiddenStorageItem': 'Hidden "{name}"',
      'notification.operationDone': 'Operation done',
      'playlists.create': 'Create',
      'playlists.createNew': 'Create Playlist',
      'playlists.namePlaceholder': 'Playlist name',
      'playlists.newPlaylist': 'New Playlist',
      'player.more': 'More',
      'recent.clearHistory': 'Clear History',
      'recent.clearPlayedConfirm': 'Clear played history?',
      'recent.clearSearchesConfirm': 'Clear search history?',
      'recent.added': 'Added',
      'recent.empty': 'Nothing here yet',
      'recent.noSearches': 'No recent searches',
      'recent.played': 'Played',
      'recent.searches': 'Searches',
      'recent.artists': 'Artists',
      'recent.albums': 'Albums',
      'recent.playlists': 'Playlists',
      'recent.time.today': 'Today',
      'recent.time.yesterday': 'Yesterday',
      'recent.time.recent7Days': 'Last 7 days',
      'recent.time.thisMonth': 'This month',
      'recent.time.recent30Days': 'Last 30 days',
      'recent.time.month1': 'January',
      'recent.time.month2': 'February',
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

  testWidgets('RecentPage song view menu opens MusicDialog', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _RecentTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: _FakeLibraryRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Blue Song'), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('View'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('See Music Info'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Blue Song'), findsWidgets);
    expect(find.text('Lyrics'), findsOneWidget);
    expect(find.text('Album Art'), findsOneWidget);
  });

  testWidgets(
    'RecentPage song menu hides file-management actions like Electron',
    (tester) async {
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

      expect(find.text('Move To Folder'), findsNothing);
      expect(find.text('Hide File'), findsNothing);
    },
  );

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
    await tester.pump(const Duration(seconds: 5));
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

  testWidgets('RecentPage recent search removal can be undone', (tester) async {
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
    await tester.tap(find.byTooltip('Remove').first);
    await tester.pumpAndSettle();

    expect(repository.removedRecentSearchIds, [4]);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(repository.restoredRecentSearches.single.id, 4);
    expect(repository.restoredRecentSearches.single.query, 'blue');
  });

  testWidgets('RecentPage opens recent searches with their saved type', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final router = GoRouter(
      initialLocation: '/recent',
      routes: [
        GoRoute(
          path: '/recent',
          builder: (_, _) => const Scaffold(body: RecentPage()),
        ),
        GoRoute(
          path: '/artists',
          builder:
              (_, state) =>
                  Text('artist:${state.uri.queryParameters['artist']}'),
        ),
        GoRoute(
          path: '/search',
          builder:
              (_, state) => Text(
                'search:${state.uri.queryParameters['query']}:${state.uri.queryParameters['type']}',
              ),
        ),
      ],
    );

    await tester.pumpWidget(
      _RecentRouterTestApp(
        router: router,
        snapshot: _snapshotWithArtistSearch,
        i18n: i18n,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Searches  1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Artist A'));
    await tester.pumpAndSettle();

    expect(find.text('artist:Artist A'), findsOneWidget);
  });

  testWidgets('RecentPage search history uses Electron type icons', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _RecentTestApp(snapshot: _snapshotWithArtistSearch, i18n: i18n),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Searches  1'));
    await tester.pumpAndSettle();

    expect(find.byIcon(FluentIcons.people_20_regular), findsOneWidget);
    expect(find.byIcon(FluentIcons.search_20_regular), findsNothing);
  });

  testWidgets('RecentPage played collections are grouped by time', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _RecentTestApp(snapshot: _snapshotWithRecentAlbums, i18n: i18n),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Played  2'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Albums'));
    await tester.pumpAndSettle();

    expect(find.text('2025.01'), findsOneWidget);
    expect(find.text('2024.12'), findsOneWidget);
  });

  testWidgets('RecentPage refreshes after collection play is recorded', (
    tester,
  ) async {
    final repository = _FakeLibraryRepository();
    final recordCompleter = Completer<void>();
    repository.albumRecordCompleter = recordCompleter;
    var snapshotLoads = 0;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 1000);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          smPlayerI18nProvider.overrideWith((ref) async => i18n),
          musicLibrarySnapshotProvider.overrideWith((ref) async {
            snapshotLoads += 1;
            return _snapshotWithRecentAlbums;
          }),
          libraryRepositoryProvider.overrideWithValue(repository),
        ],
        child: SmPlayerI18nScope(
          i18n: i18n,
          child: const MaterialApp(home: Scaffold(body: RecentPage())),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Played  2'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Albums'));
    await tester.pumpAndSettle();
    final loadsBeforePlay = snapshotLoads;
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer();
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.text('January Album')));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(FluentIcons.play_20_filled).first);
    await tester.pump();

    expect(repository.recordedAlbums, ['January Album']);
    final loadsBeforeRecordCompletes = snapshotLoads;
    expect(loadsBeforeRecordCompletes, greaterThanOrEqualTo(loadsBeforePlay));

    recordCompleter.complete();
    await tester.pumpAndSettle();

    expect(snapshotLoads, greaterThan(loadsBeforeRecordCompletes));
  });

  testWidgets('RecentPage recent played removal can be undone', (tester) async {
    final repository = _FakeLibraryRepository();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _RecentTestApp(
        snapshot: _snapshotWithRecentPlayed,
        i18n: i18n,
        repository: repository,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Played  1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Blue Song'), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    expect(repository.removedRecentPlayedIds, [1]);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(repository.restoredRecentPlayedIds, [1]);
  });

  testWidgets('RecentPage uses compact appbar tabs in narrow layout', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(480, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(_RecentTestApp(snapshot: _snapshot, i18n: i18n));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('Recent.AppBarTabs')), findsOneWidget);
    expect(find.text('Clear History'), findsNothing);

    await tester.tap(find.text('Played  0'));
    await tester.pumpAndSettle();

    expect(find.text('Songs'), findsOneWidget);
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

class _RecentRouterTestApp extends StatelessWidget {
  const _RecentRouterTestApp({
    required this.router,
    required this.snapshot,
    required this.i18n,
  });

  final GoRouter router;
  final MusicLibrarySnapshot snapshot;
  final SmPlayerI18n i18n;

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

class _FakeLibraryRepository extends LibraryRepository {
  List<int> replacedNowPlaying = [];
  bool clearedRecentSearches = false;
  List<int> removedRecentSearchIds = [];
  List<SearchHistoryEntry> restoredRecentSearches = [];
  List<int> removedRecentPlayedIds = [];
  List<int> restoredRecentPlayedIds = [];
  List<String> recordedAlbums = [];
  Completer<void>? albumRecordCompleter;
  int? hiddenSongId;

  @override
  Future<void> replaceNowPlaying(List<int> songIds) async {
    replacedNowPlaying = songIds.toList();
  }

  @override
  Future<void> clearRecentSearches() async {
    clearedRecentSearches = true;
  }

  @override
  Future<void> removeRecentSearches(List<int> entryIds) async {
    removedRecentSearchIds = entryIds.toList();
  }

  @override
  Future<void> removeRecentPlayed(List<int> songIds) async {
    removedRecentPlayedIds = songIds.toList();
  }

  @override
  Future<void> restoreRecentPlayed(List<int> songIds) async {
    restoredRecentPlayedIds = songIds.toList();
  }

  @override
  Future<void> recordAlbumPlayed(String album) async {
    recordedAlbums.add(album);
    await albumRecordCompleter?.future;
  }

  @override
  Future<void> restoreRecentSearches(List<SearchHistoryEntry> entries) async {
    restoredRecentSearches = entries.toList();
  }

  @override
  Future<void> hideSong(int songId) async {
    hiddenSongId = songId;
  }

  @override
  Future<void> unhideSong(int songId) async {
    hiddenSongId = null;
  }

  @override
  Future<SongPropertiesSnapshot> getSongProperties(int songId) async {
    return SongPropertiesSnapshot(
      songId: songId,
      path: r'C:\Music\blue.mp3',
      title: 'Blue Song',
      subtitle: '',
      artist: 'Artist A',
      artists: const ['Artist A'],
      album: 'Blue Hour',
      albumArtist: '',
      publisher: '',
      trackNumber: 0,
      year: 0,
      genre: '',
      composers: '',
      duration: 120,
      bitrate: 0,
      fileSize: 1024,
      dateCreated: '2026-01-01T00:00:00Z',
      dateModified: '2026-01-01T00:00:00Z',
      fileType: 'MP3',
      playCount: 0,
    );
  }

  @override
  Future<LyricsSnapshot> getSongLyrics(
    int songId, {
    LyricsRequestMode mode = LyricsRequestMode.auto,
  }) async {
    return const LyricsSnapshot(
      source: LyricsSource.none,
      isSynced: false,
      rawText: '',
      lines: [],
    );
  }

  @override
  Future<SongArtworkSnapshot> getSongArtworkSnapshot(int songId) async {
    return SongArtworkSnapshot(
      songId: songId,
      artworkUrl: '',
      sourceUrl: '',
      sourcePath: '',
      source: SongArtworkSource.none,
    );
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

const _snapshotWithArtistSearch = MusicLibrarySnapshot(
  songs: [],
  recentSearches: [
    SearchHistoryEntry(
      id: 8,
      query: 'Artist A',
      type: SearchHistoryType.artists,
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

const _snapshotWithRecentPlayed = MusicLibrarySnapshot(
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
  recentSongs: [
    RecentLibrarySong(
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
      playedAt: '2026-05-20T00:00:00',
    ),
  ],
  recentSearches: [],
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

const _snapshotWithRecentAlbums = MusicLibrarySnapshot(
  songs: [
    LibrarySong(
      id: 21,
      path: r'C:\Music\one.mp3',
      title: 'One',
      artist: 'Artist A',
      artists: ['Artist A'],
      album: 'January Album',
      duration: 120,
      playCount: 0,
      lyricsOffsetMs: 0,
      dateAdded: '2025-01-01T00:00:00',
      favorite: false,
      thumbnailPath: '',
    ),
    LibrarySong(
      id: 22,
      path: r'C:\Music\two.mp3',
      title: 'Two',
      artist: 'Artist B',
      artists: ['Artist B'],
      album: 'December Album',
      duration: 90,
      playCount: 0,
      lyricsOffsetMs: 0,
      dateAdded: '2024-12-01T00:00:00',
      favorite: false,
      thumbnailPath: '',
    ),
  ],
  recentAlbums: [
    RecentAlbumPlayback(
      id: 31,
      album: 'January Album',
      playedAt: '2025-01-15T00:00:00',
    ),
    RecentAlbumPlayback(
      id: 32,
      album: 'December Album',
      playedAt: '2024-12-15T00:00:00',
    ),
  ],
  recentSearches: [],
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
