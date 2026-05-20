import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smplayer_flutter/src/app/app_router.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';

void main() {
  const emptyLibrarySnapshot = MusicLibrarySnapshot(
    songs: [],
    recentSongs: [],
    recentPlaylists: [],
    recentAlbums: [],
    recentArtists: [],
    recentSearches: [],
    playlists: [],
    favoritePlaylistId: 0,
    nowPlaying: NowPlayingSnapshot(playlistId: 0, songIds: []),
    hasLibrary: false,
    sortCriterion: MusicLibrarySortCriterion.title,
    albumsSort: AlbumSortCriterion.defaultSort,
    showCount: true,
    hideMultiSelectCommandBarAfterOperation: true,
    databasePath: '',
  );
  const albumLibrarySnapshot = MusicLibrarySnapshot(
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
  const testI18n = SmPlayerI18n(locale: 'en-US', messages: {});

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('sidebar navigation changes the app route', (tester) async {
    final router = createSmPlayerRouter();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          smPlayerI18nProvider.overrideWith((ref) async => testI18n),
          musicLibrarySnapshotProvider.overrideWith(
            (ref) async => emptyLibrarySnapshot,
          ),
        ],
        child: _RouterTestApp(router: router, i18n: testI18n),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('RecentItem')));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/recent');
  });

  testWidgets('sidebar search commits to the search route', (tester) async {
    final router = createSmPlayerRouter();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          smPlayerI18nProvider.overrideWith((ref) async => testI18n),
          musicLibrarySnapshotProvider.overrideWith(
            (ref) async => emptyLibrarySnapshot,
          ),
        ],
        child: _RouterTestApp(router: router, i18n: testI18n),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('MainNavigationView.SearchTextField')),
      '  Jazz  ',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    final uri = router.routeInformationProvider.value.uri;
    expect(uri.path, '/search');
    expect(uri.queryParameters['query'], 'Jazz');
  });

  testWidgets('sidebar back returns playlist details to playlists', (
    tester,
  ) async {
    final router = createSmPlayerRouter();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          smPlayerI18nProvider.overrideWith((ref) async => testI18n),
          musicLibrarySnapshotProvider.overrideWith(
            (ref) async => emptyLibrarySnapshot,
          ),
        ],
        child: _RouterTestApp(router: router, i18n: testI18n),
      ),
    );

    router.go('/playlists/7');
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('MainNavigationView.BackButton')),
    );
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/playlists');
  });

  testWidgets('sidebar back returns album detail query to albums', (
    tester,
  ) async {
    final router = createSmPlayerRouter();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          smPlayerI18nProvider.overrideWith((ref) async => testI18n),
          musicLibrarySnapshotProvider.overrideWith(
            (ref) async => emptyLibrarySnapshot,
          ),
        ],
        child: _RouterTestApp(router: router, i18n: testI18n),
      ),
    );

    router.go('/albums?album=Blue');
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('MainNavigationView.BackButton')),
    );
    await tester.pumpAndSettle();

    final uri = router.routeInformationProvider.value.uri;
    expect(uri.path, '/albums');
    expect(uri.queryParameters.containsKey('album'), isFalse);
  });

  testWidgets('album query route opens Electron-style album detail', (
    tester,
  ) async {
    final router = createSmPlayerRouter();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          smPlayerI18nProvider.overrideWith((ref) async => testI18n),
          musicLibrarySnapshotProvider.overrideWith(
            (ref) async => albumLibrarySnapshot,
          ),
        ],
        child: _RouterTestApp(router: router, i18n: testI18n),
      ),
    );

    router.go('/albums?album=Blue%20Hour');
    await tester.pumpAndSettle();

    expect(find.text('Blue Hour'), findsOneWidget);
  });

  testWidgets('missing album query route renders not found detail state', (
    tester,
  ) async {
    final router = createSmPlayerRouter();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          smPlayerI18nProvider.overrideWith((ref) async => testI18n),
          musicLibrarySnapshotProvider.overrideWith(
            (ref) async => albumLibrarySnapshot,
          ),
        ],
        child: _RouterTestApp(router: router, i18n: testI18n),
      ),
    );

    router.go('/albums?album=Missing');
    await tester.pumpAndSettle();

    expect(find.textContaining('collection.albumNotFound'), findsOneWidget);
    expect(find.textContaining('collection.albumNotFoundCopy'), findsOneWidget);
  });

  testWidgets('sidebar back returns artist detail query to artists', (
    tester,
  ) async {
    final router = createSmPlayerRouter();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          smPlayerI18nProvider.overrideWith((ref) async => testI18n),
          musicLibrarySnapshotProvider.overrideWith(
            (ref) async => emptyLibrarySnapshot,
          ),
        ],
        child: _RouterTestApp(router: router, i18n: testI18n),
      ),
    );

    router.go('/artists?artist=Blue');
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('MainNavigationView.BackButton')),
    );
    await tester.pumpAndSettle();

    final uri = router.routeInformationProvider.value.uri;
    expect(uri.path, '/artists');
    expect(uri.queryParameters.containsKey('artist'), isFalse);
  });

  testWidgets('library routes render migrated pages', (tester) async {
    final router = createSmPlayerRouter();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          smPlayerI18nProvider.overrideWith((ref) async => testI18n),
          musicLibrarySnapshotProvider.overrideWith(
            (ref) async => emptyLibrarySnapshot,
          ),
        ],
        child: _RouterTestApp(router: router, i18n: testI18n),
      ),
    );

    router.go('/artists');
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/artists');

    router.go('/albums');
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/albums');
  });
}

class _RouterTestApp extends StatelessWidget {
  const _RouterTestApp({required this.router, required this.i18n});

  final RouterConfig<Object> router;
  final SmPlayerI18n i18n;

  @override
  Widget build(BuildContext context) {
    return SmPlayerI18nScope(
      i18n: i18n,
      child: MaterialApp.router(routerConfig: router),
    );
  }
}
