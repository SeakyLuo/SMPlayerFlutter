import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smplayer_flutter/main.dart' as app;
import 'package:smplayer_flutter/src/app/app_route_model.dart';
import 'package:smplayer_flutter/src/app/app_router.dart';
import 'package:smplayer_flutter/src/app/splash_screen.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
import 'package:smplayer_flutter/src/library/data/library_repository.dart';
import 'package:smplayer_flutter/src/library/ui/playlists_page.dart';
import 'package:smplayer_flutter/src/playback/now_playing_page.dart';
import 'package:smplayer_flutter/src/settings/settings_controller.dart';
import 'package:smplayer_flutter/src/settings/settings_model.dart'
    show NightMode, SettingsSnapshot;
import 'package:smplayer_flutter/src/settings/settings_page.dart';

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
    rootPath: r'C:\Music',
  );
  const rootlessLibrarySnapshot = MusicLibrarySnapshot(
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
    rootPath: r'C:\Music',
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

    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getString(SmPlayerSettingsStorageKeys.lastPage),
      '/recent',
    );
  });

  test('restored page follows Electron restorable route list', () {
    expect(resolveRestoredPage('/recent'), '/recent');
    expect(resolveRestoredPage(' /local '), '/local');
    expect(resolveRestoredPage('/playlists/7'), '/songs');
    expect(resolveRestoredPage('/settings'), '/songs');
  });

  testWidgets('router restores the Electron last page on startup', (
    tester,
  ) async {
    final router = createSmPlayerRouter(initialLocation: '/recent');

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
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/recent');
  });

  testWidgets('rootless library tabs show missing-library-root prompt', (
    tester,
  ) async {
    final router = createSmPlayerRouter();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          smPlayerI18nProvider.overrideWith((ref) async => testI18n),
          musicLibrarySnapshotProvider.overrideWith(
            (ref) async => rootlessLibrarySnapshot,
          ),
        ],
        child: _RouterTestApp(router: router, i18n: testI18n),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('local.noRoot'), findsOneWidget);
    expect(find.text('local.noRootCopy'), findsOneWidget);
    expect(find.text('library.chooseFolder'), findsOneWidget);

    router.go('/recent');
    await tester.pumpAndSettle();

    expect(find.text('local.noRoot'), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, '/recent');
  });

  testWidgets('non-library-root tabs bypass missing-library-root prompt', (
    tester,
  ) async {
    final router = createSmPlayerRouter();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          smPlayerI18nProvider.overrideWith((ref) async => testI18n),
          musicLibrarySnapshotProvider.overrideWith(
            (ref) async => rootlessLibrarySnapshot,
          ),
        ],
        child: _RouterTestApp(router: router, i18n: testI18n),
      ),
    );
    await tester.pumpAndSettle();

    router.go('/settings');
    await tester.pumpAndSettle();

    expect(find.text('local.noRoot'), findsNothing);
    expect(find.byType(SettingsPage), findsOneWidget);

    router.go('/now-playing');
    await tester.pumpAndSettle();

    expect(find.text('local.noRoot'), findsNothing);
    expect(find.byType(NowPlayingPage), findsOneWidget);

    router.go('/playlists');
    await tester.pumpAndSettle();

    expect(find.text('local.noRoot'), findsNothing);
    expect(find.byType(PlaylistsPage), findsOneWidget);
  });

  testWidgets('SmPlayerApp provides Material localizations for zh-CN widgets', (
    tester,
  ) async {
    final settingsController = SettingsController();
    await settingsController.refresh();
    MaterialLocalizations? materialLocalizations;
    final router = GoRouter(
      initialLocation: '/settings',
      routes: [
        GoRoute(
          path: '/settings',
          builder: (context, _) {
            materialLocalizations = MaterialLocalizations.of(context);
            return SettingsPage(onLoadSystemFonts: () async => const []);
          },
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          smPlayerI18nProvider.overrideWith(
            (ref) async => const SmPlayerI18n(
              locale: 'zh-CN',
              messages: {'app.shell': '简音播放器'},
            ),
          ),
          musicLibrarySnapshotProvider.overrideWith(
            (ref) async => rootlessLibrarySnapshot,
          ),
        ],
        child: app.SmPlayerApp(
          router: router,
          settingsController: settingsController,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(materialLocalizations, isNotNull);
    expect(find.byType(SettingsPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('SmPlayerApp keeps splash visible until i18n is ready', (
    tester,
  ) async {
    final i18nCompleter = Completer<SmPlayerI18n>();
    final settingsController = SettingsController(
      const SettingsSnapshot.defaults().copyWith(nightMode: NightMode.onMode),
    );
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (context, _) => const Text('app.shell')),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          smPlayerI18nProvider.overrideWith((ref) => i18nCompleter.future),
        ],
        child: app.SmPlayerApp(
          router: router,
          settingsController: settingsController,
        ),
      ),
    );

    expect(find.byType(SmPlayerSplashScreen), findsOneWidget);
    expect(
      tester.widget<SmPlayerSplashScreen>(find.byType(SmPlayerSplashScreen)),
      isA<SmPlayerSplashScreen>().having(
        (screen) => screen.brightness,
        'brightness',
        Brightness.dark,
      ),
    );
    expect(find.text('app.shell'), findsNothing);

    i18nCompleter.complete(
      const SmPlayerI18n(locale: 'en-US', messages: {'app.shell': 'SMPlayer'}),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SmPlayerSplashScreen), findsNothing);
  });

  testWidgets('sidebar search commits to search route and recent history', (
    tester,
  ) async {
    final router = createSmPlayerRouter();
    final repository = _RecordingRouterRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          smPlayerI18nProvider.overrideWith((ref) async => testI18n),
          libraryRepositoryProvider.overrideWithValue(repository),
          musicLibrarySnapshotProvider.overrideWith(
            (ref) async => emptyLibrarySnapshot,
          ),
        ],
        child: _RouterTestApp(router: router, i18n: testI18n),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('MainNavigationView.SearchTextField')),
      '  Jazz  ',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    final uri = router.routeInformationProvider.value.uri;
    expect(uri.path, '/search');
    expect(uri.queryParameters['query'], 'Jazz');
    expect(repository.recordedSearches, [
      (query: 'Jazz', type: SearchHistoryType.sidebar),
    ]);
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

    expect(find.text('collection.albumNotFound'), findsOneWidget);
    expect(find.text('collection.albumNotFoundCopy'), findsOneWidget);
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

  testWidgets('sidebar restores remembered artist route like Electron', (
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
    router.go('/songs');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('ArtistsItem')));
    await tester.pumpAndSettle();

    final uri = router.routeInformationProvider.value.uri;
    expect(uri.path, '/artists');
    expect(uri.queryParameters['artist'], 'Blue');
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

class _RecordingRouterRepository extends LibraryRepository {
  final recordedSearches = <({String query, SearchHistoryType type})>[];

  @override
  Future<void> addRecentSearch(
    String query, [
    SearchHistoryType type = SearchHistoryType.sidebar,
  ]) async {
    recordedSearches.add((query: query.trim(), type: type));
  }
}
