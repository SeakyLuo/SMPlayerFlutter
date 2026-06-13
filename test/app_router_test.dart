import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:smplayer_flutter/main.dart' as app;
import 'package:smplayer_flutter/src/app/app_appearance_model.dart';
import 'package:smplayer_flutter/src/app/app_route_model.dart';
import 'package:smplayer_flutter/src/app/app_router.dart';
import 'package:smplayer_flutter/src/app/shell_workspace.dart';
import 'package:smplayer_flutter/src/app/splash_screen.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
import 'package:smplayer_flutter/src/library/data/library_repository.dart';
import 'package:smplayer_flutter/src/library/ui/headered_playlist_app_bar_portal.dart';
import 'package:smplayer_flutter/src/library/ui/playlists_page.dart';
import 'package:smplayer_flutter/src/playback/now_playing_page.dart';
import 'package:smplayer_flutter/src/playback/immersive_mode_route.dart';
import 'package:smplayer_flutter/src/recent/recent_page.dart';
import 'package:smplayer_flutter/src/settings/settings_controller.dart';
import 'package:smplayer_flutter/src/settings/settings_model.dart'
    show AppSettingsUpdate, NightMode, PreferredLanguage, SettingsSnapshot;
import 'package:smplayer_flutter/src/settings/settings_page.dart';

void main() {
  const emptyLibraryData = LibraryContentData(
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
  const rootlessLibraryData = LibraryContentData(
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
  const albumLibraryData = LibraryContentData(
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
    resetSmPlayerGlobalSettingsSnapshot();
  });

  testWidgets('sidebar navigation changes the app route', (tester) async {
    final router = createSmPlayerRouter();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          smPlayerI18nProvider.overrideWith((ref) async => testI18n),
          libraryContentDataProvider.overrideWith(
            (ref) async => emptyLibraryData,
          ),
        ],
        child: _RouterTestApp(router: router, i18n: testI18n),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('RecentItem')));
    await _pumpRouter(tester);

    expect(router.routeInformationProvider.value.uri.path, '/recent');

    expect(smPlayerGlobalSettingsSnapshot.lastPage, '/recent');
  });

  test('restored page follows Electron restorable route list', () {
    expect(resolveRestoredPage('/recent'), '/recent');
    expect(resolveRestoredPage(' /local '), '/local');
    expect(resolveRestoredPage('/local?path=Sub/Deep'), '/local');
    expect(resolveRestoredPage('/albums?album=Blue%20Hour'), '/albums');
    expect(resolveRestoredPage('/immersive-mode'), '/songs');
    expect(resolveRestoredPage('/playlists/7'), '/songs');
    expect(resolveRestoredPage('/settings'), '/songs');
  });

  test('immersive mode route uses a stable path without return query', () {
    final uri = Uri.parse(immersiveModeRoutePath);

    expect(uri.path, '/immersive-mode');
    expect(uri.queryParameters, isEmpty);
  });

  testWidgets(
    'now playing navigation tab opens root page after immersive mode',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1300, 900);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final router = createSmPlayerRouter();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            smPlayerI18nProvider.overrideWith((ref) async => testI18n),
            libraryContentDataProvider.overrideWith(
              (ref) async => emptyLibraryData,
            ),
            shellNavigationDataProvider.overrideWith(
              (ref) async => _shellNavigationData(emptyLibraryData),
            ),
          ],
          child: _RouterTestApp(router: router, i18n: testI18n),
        ),
      );
      await _pumpRouter(tester);

      router.go('/immersive-mode');
      await _pumpRouter(tester);
      expect(router.routeInformationProvider.value.uri.path, '/immersive-mode');

      router.go('/songs');
      await _pumpRouter(tester);
      expect(router.routeInformationProvider.value.uri.path, '/songs');

      await tester.tap(
        find.byKey(const ValueKey('NowPlayingItem')).hitTestable(),
      );
      await _pumpRouter(tester);

      expect(router.routeInformationProvider.value.uri.path, '/now-playing');
    },
  );

  testWidgets('router restores the Electron last page on startup', (
    tester,
  ) async {
    final router = createSmPlayerRouter(initialLocation: '/recent');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          smPlayerI18nProvider.overrideWith((ref) async => testI18n),
          libraryContentDataProvider.overrideWith(
            (ref) async => emptyLibraryData,
          ),
        ],
        child: _RouterTestApp(router: router, i18n: testI18n),
      ),
    );
    await _pumpRouter(tester);

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
          libraryContentDataProvider.overrideWith(
            (ref) async => rootlessLibraryData,
          ),
          shellNavigationDataProvider.overrideWith(
            (ref) async => _shellNavigationData(rootlessLibraryData),
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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('local.noRoot'), findsNothing);
    expect(find.byType(RecentPage), findsOneWidget);
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
          libraryContentDataProvider.overrideWith(
            (ref) async => rootlessLibraryData,
          ),
        ],
        child: _RouterTestApp(router: router, i18n: testI18n),
      ),
    );
    await _pumpRouter(tester);

    router.go('/settings');
    await _pumpRouter(tester);

    expect(find.text('local.noRoot'), findsNothing);
    expect(find.byType(SettingsPage), findsOneWidget);

    router.go('/now-playing');
    await _pumpRouter(tester);

    expect(find.text('local.noRoot'), findsNothing);
    expect(find.byType(NowPlayingPage), findsOneWidget);

    router.go('/playlists');
    await _pumpRouter(tester);

    expect(find.text('local.noRoot'), findsNothing);
    expect(find.byType(PlaylistsPage), findsOneWidget);
  });

  testWidgets('minimal navigation renders settings title in the app bar', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(600, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final router = createSmPlayerRouter();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          smPlayerI18nProvider.overrideWith((ref) async => testI18n),
          libraryContentDataProvider.overrideWith(
            (ref) async => emptyLibraryData,
          ),
        ],
        child: _RouterTestApp(router: router, i18n: testI18n),
      ),
    );
    router.go('/settings');
    await _pumpRouter(tester);

    expect(find.byType(SettingsPage), findsOneWidget);
    expect(
      find.byKey(SmPlayerShellWorkspaceKeys.navigationMenuButton),
      findsOneWidget,
    );
    final title = tester.widget<Text>(find.text('common.settings'));
    expect(title.style?.fontSize, 16);
  });

  testWidgets('minimal navigation ignores stale headered playlist app bar', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(600, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final router = createSmPlayerRouter(initialLocation: '/playlists');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          smPlayerI18nProvider.overrideWith((ref) async => testI18n),
          libraryContentDataProvider.overrideWith(
            (ref) async => emptyLibraryData,
          ),
          headeredPlaylistAppBarPortalProvider.overrideWith(
            (ref) => const HeaderedPlaylistAppBarPortalEntry(
              owner: 'stale-playlist-detail',
              routeLocation: '/playlists/7',
              title: 'Stale playlist',
              coverColor: Colors.blue,
              collapseProgress: 1,
            ),
          ),
        ],
        child: _RouterTestApp(router: router, i18n: testI18n),
      ),
    );
    await _pumpRouter(tester);

    expect(find.byType(PlaylistsPage), findsOneWidget);
    expect(find.text('Stale playlist'), findsNothing);
    expect(find.text('common.playlists'), findsNothing);
  });

  testWidgets(
    'minimal navigation clears recent app bar tabs after route change',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(600, 900);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final router = createSmPlayerRouter(initialLocation: '/recent');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            smPlayerI18nProvider.overrideWith((ref) async => testI18n),
            libraryContentDataProvider.overrideWith(
              (ref) async => albumLibraryData,
            ),
            recentPageDataProvider.overrideWith((ref) async {
              return RecentPageData(
                songs: albumLibraryData.songs,
                recentSongs: albumLibraryData.recentSongs,
                recentPlaylists: albumLibraryData.recentPlaylists,
                recentAlbums: albumLibraryData.recentAlbums,
                recentArtists: albumLibraryData.recentArtists,
                recentSearches: albumLibraryData.recentSearches,
                playlists: albumLibraryData.playlists,
                favoritePlaylistId: albumLibraryData.favoritePlaylistId,
                nowPlaying: albumLibraryData.nowPlaying,
                showCount: albumLibraryData.showCount,
                hideMultiSelectCommandBarAfterOperation:
                    albumLibraryData.hideMultiSelectCommandBarAfterOperation,
              );
            }),
          ],
          child: _RouterTestApp(router: router, i18n: testI18n),
        ),
      );
      await _pumpRouter(tester);

      expect(find.byType(RecentPage), findsOneWidget);
      expect(find.text('recent.added'), findsOneWidget);
    },
  );

  testWidgets('minimal navigation moves search tabs into the app bar bottom', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(600, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final router = createSmPlayerRouter(initialLocation: '/search?query=Blue');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          smPlayerI18nProvider.overrideWith((ref) async => testI18n),
          libraryContentDataProvider.overrideWith(
            (ref) async => albumLibraryData,
          ),
        ],
        child: _RouterTestApp(router: router, i18n: testI18n),
      ),
    );
    await _pumpRouter(tester);

    expect(router.routeInformationProvider.value.uri.path, '/songs');
    expect(
      find.byKey(const ValueKey('WorkspaceNavigationAppBar.Bottom')),
      findsNothing,
    );
    expect(find.text('common.all'), findsNothing);
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
          libraryContentDataProvider.overrideWith(
            (ref) async => rootlessLibraryData,
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

  testWidgets('SmPlayerApp switches interface language immediately', (
    tester,
  ) async {
    final initialSettings = const SettingsSnapshot.defaults().copyWith(
      preferredLanguage: PreferredLanguage.enUS,
    );
    setSmPlayerGlobalSettingsSnapshot(initialSettings);
    addTearDown(resetSmPlayerGlobalSettingsSnapshot);
    final settingsController = SettingsController(initialSettings);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) {
            return Text(context.smPlayerI18n.t('settings.interfaceLanguage'));
          },
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: app.SmPlayerApp(
          router: router,
          settingsController: settingsController,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Interface language'), findsOneWidget);

    await settingsController.updateSettings(
      const AppSettingsUpdate(preferredLanguage: PreferredLanguage.zhCN),
    );
    await tester.pumpAndSettle();

    expect(find.text('界面语言'), findsOneWidget);
    expect(find.text('Interface language'), findsNothing);
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
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1300, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final router = createSmPlayerRouter();
    final repository = _RecordingRouterRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          smPlayerI18nProvider.overrideWith((ref) async => testI18n),
          libraryRepositoryProvider.overrideWithValue(repository),
          libraryContentDataProvider.overrideWith(
            (ref) async => emptyLibraryData,
          ),
        ],
        child: _RouterTestApp(router: router, i18n: testI18n),
      ),
    );
    await _pumpRouter(tester);

    expect(
      find.byKey(const ValueKey('MainNavigationView.SearchTextField')),
      findsNothing,
    );
    expect(router.routeInformationProvider.value.uri.path, '/albums');
    expect(repository.recordedSearches, isEmpty);
  });

  testWidgets('committed sidebar search refreshes recent page searches', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1300, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final router = createSmPlayerRouter();
    final repository = _RecordingRouterRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          smPlayerI18nProvider.overrideWith((ref) async => testI18n),
          libraryRepositoryProvider.overrideWithValue(repository),
          libraryContentDataProvider.overrideWith(
            (ref) async => emptyLibraryData,
          ),
        ],
        child: _RouterTestApp(router: router, i18n: testI18n),
      ),
    );
    await _pumpRouter(tester);

    router.go('/recent');
    await _pumpRouter(tester);
    await tester.tap(find.text('recent.searches'));
    await _pumpRouter(tester);
    expect(find.text('Jazz'), findsNothing);

    expect(
      find.byKey(const ValueKey('MainNavigationView.SearchTextField')),
      findsNothing,
    );
    expect(repository.recordedSearches, isEmpty);
  });

  testWidgets('sidebar back returns playlist details to playlists', (
    tester,
  ) async {
    final router = createSmPlayerRouter();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          smPlayerI18nProvider.overrideWith((ref) async => testI18n),
          libraryContentDataProvider.overrideWith(
            (ref) async => emptyLibraryData,
          ),
        ],
        child: _RouterTestApp(router: router, i18n: testI18n),
      ),
    );

    router.go('/playlists/7');
    await _pumpRouter(tester);

    await tester.tap(
      find.byKey(const ValueKey('MainNavigationView.BackButton')),
    );
    await _pumpRouter(tester);

    expect(router.routeInformationProvider.value.uri.path, '/songs');
  });

  testWidgets('sidebar back returns album detail query to albums', (
    tester,
  ) async {
    final router = createSmPlayerRouter();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          smPlayerI18nProvider.overrideWith((ref) async => testI18n),
          libraryContentDataProvider.overrideWith(
            (ref) async => emptyLibraryData,
          ),
        ],
        child: _RouterTestApp(router: router, i18n: testI18n),
      ),
    );

    router.go('/albums?album=Blue');
    await _pumpRouter(tester);

    await tester.tap(
      find.byKey(const ValueKey('MainNavigationView.BackButton')),
    );
    await _pumpRouter(tester);

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
          libraryContentDataProvider.overrideWith(
            (ref) async => albumLibraryData,
          ),
        ],
        child: _RouterTestApp(router: router, i18n: testI18n),
      ),
    );

    router.go('/albums?album=Blue%20Hour');
    await _pumpRouter(tester);

    final uri = router.routeInformationProvider.value.uri;
    expect(uri.path, '/albums');
    expect(uri.queryParameters['album'], 'Blue Hour');
  });

  testWidgets('album query detail persists Electron-restorable albums page', (
    tester,
  ) async {
    final router = createSmPlayerRouter();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          smPlayerI18nProvider.overrideWith((ref) async => testI18n),
          libraryContentDataProvider.overrideWith(
            (ref) async => albumLibraryData,
          ),
        ],
        child: _RouterTestApp(router: router, i18n: testI18n),
      ),
    );

    router.go('/albums?album=Blue%20Hour');
    await _pumpRouter(tester);

    expect(smPlayerGlobalSettingsSnapshot.lastPage, '/albums');
  });

  testWidgets('missing album query route renders not found detail state', (
    tester,
  ) async {
    final router = createSmPlayerRouter();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          smPlayerI18nProvider.overrideWith((ref) async => testI18n),
          libraryContentDataProvider.overrideWith(
            (ref) async => albumLibraryData,
          ),
        ],
        child: _RouterTestApp(router: router, i18n: testI18n),
      ),
    );

    router.go('/albums?album=Missing');
    await _pumpRouter(tester);

    expect(router.routeInformationProvider.value.uri.path, '/albums');
    expect(find.text('collection.albumNotFound'), findsNothing);
    expect(find.text('collection.albumNotFoundCopy'), findsNothing);
  });

  testWidgets('sidebar back returns artist detail query to artists', (
    tester,
  ) async {
    final router = createSmPlayerRouter();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          smPlayerI18nProvider.overrideWith((ref) async => testI18n),
          libraryContentDataProvider.overrideWith(
            (ref) async => emptyLibraryData,
          ),
        ],
        child: _RouterTestApp(router: router, i18n: testI18n),
      ),
    );

    router.go('/artists?artist=Blue');
    await _pumpRouter(tester);

    await tester.tap(
      find.byKey(const ValueKey('MainNavigationView.BackButton')),
    );
    await _pumpRouter(tester);

    final uri = router.routeInformationProvider.value.uri;
    expect(uri.path, '/songs');
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
          libraryContentDataProvider.overrideWith(
            (ref) async => emptyLibraryData,
          ),
        ],
        child: _RouterTestApp(router: router, i18n: testI18n),
      ),
    );

    router.go('/artists?artist=Blue');
    await _pumpRouter(tester);
    router.go('/songs');
    await _pumpRouter(tester);

    await tester.tap(find.byKey(const ValueKey('ArtistsItem')));
    await _pumpRouter(tester);

    final uri = router.routeInformationProvider.value.uri;
    expect(uri.path, '/artists');
    expect(uri.queryParameters['artist'], 'Blue');
  });

  testWidgets('sidebar restores remembered local folder route like Electron', (
    tester,
  ) async {
    final router = createSmPlayerRouter();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          smPlayerI18nProvider.overrideWith((ref) async => testI18n),
          libraryContentDataProvider.overrideWith(
            (ref) async => emptyLibraryData,
          ),
        ],
        child: _RouterTestApp(router: router, i18n: testI18n),
      ),
    );

    router.go('/local?path=Jazz%2FBlue');
    await _pumpRouter(tester);
    router.go('/songs');
    await _pumpRouter(tester);

    await tester.tap(find.byKey(const ValueKey('LocalItem')));
    await _pumpRouter(tester);

    final uri = router.routeInformationProvider.value.uri;
    expect(uri.path, '/local');
    expect(uri.queryParameters['path'], 'Jazz/Blue');
  });

  testWidgets('sidebar local exits hidden folders route like Electron', (
    tester,
  ) async {
    final router = createSmPlayerRouter();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          smPlayerI18nProvider.overrideWith((ref) async => testI18n),
          libraryContentDataProvider.overrideWith(
            (ref) async => emptyLibraryData,
          ),
        ],
        child: _RouterTestApp(router: router, i18n: testI18n),
      ),
    );

    router.go('/hidden-folders');
    await _pumpRouter(tester);

    await tester.tap(find.byKey(const ValueKey('LocalItem')));
    await _pumpRouter(tester);

    expect(router.routeInformationProvider.value.uri.path, '/local');
  });

  testWidgets(
    'sidebar playlist root opens PlaylistsPage from playlist detail',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1400, 900);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final router = createSmPlayerRouter();
      final libraryData = _libraryDataWithSongs(
        3,
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
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            smPlayerI18nProvider.overrideWith((ref) async => testI18n),
            libraryContentDataProvider.overrideWith((ref) async => libraryData),
            shellNavigationDataProvider.overrideWith(
              (ref) async => _shellNavigationData(libraryData),
            ),
          ],
          child: _RouterTestApp(router: router, i18n: testI18n),
        ),
      );
      await _pumpRouter(tester);

      router.go('/playlists/7');
      await _pumpRouter(tester);

      expect(router.routeInformationProvider.value.uri.path, '/playlists/7');

      final playlistsHeading = find.byKey(
        const ValueKey('MainNavigationView.PlaylistsHeadingItem'),
      );
      await tester.tapAt(
        tester.getTopLeft(playlistsHeading.hitTestable()) +
            const Offset(20, 20),
      );
      await tester.pumpAndSettle();

      expect(router.routeInformationProvider.value.uri.path, '/playlists');
      expect(find.byType(PlaylistsPage), findsOneWidget);
    },
  );

  testWidgets('sidebar preserves recent page tab state', (tester) async {
    final router = createSmPlayerRouter(initialLocation: '/recent');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          smPlayerI18nProvider.overrideWith((ref) async => testI18n),
          libraryContentDataProvider.overrideWith(
            (ref) async => emptyLibraryData,
          ),
          recentPageDataProvider.overrideWith((ref) async {
            return RecentPageData(
              songs: emptyLibraryData.songs,
              recentSongs: emptyLibraryData.recentSongs,
              recentPlaylists: emptyLibraryData.recentPlaylists,
              recentAlbums: emptyLibraryData.recentAlbums,
              recentArtists: emptyLibraryData.recentArtists,
              recentSearches: emptyLibraryData.recentSearches,
              playlists: emptyLibraryData.playlists,
              favoritePlaylistId: emptyLibraryData.favoritePlaylistId,
              nowPlaying: emptyLibraryData.nowPlaying,
              showCount: emptyLibraryData.showCount,
              hideMultiSelectCommandBarAfterOperation:
                  emptyLibraryData.hideMultiSelectCommandBarAfterOperation,
            );
          }),
        ],
        child: _RouterTestApp(router: router, i18n: testI18n),
      ),
    );
    await _pumpRouter(tester);

    await tester.tap(find.text('recent.searches'));
    await _pumpRouter(tester);
    dynamic searchesTab = tester.widget(
      find.byKey(const ValueKey('RecentPage.Tab.searches')),
    );
    expect(searchesTab.active, isTrue);

    await tester.tap(
      find.byKey(const ValueKey('MusicLibraryItem')).hitTestable(),
    );
    await _pumpRouter(tester);
    await tester.tap(find.byKey(const ValueKey('RecentItem')).hitTestable());
    await _pumpRouter(tester);

    expect(router.routeInformationProvider.value.uri.path, '/recent');
    searchesTab = tester.widget(
      find.byKey(const ValueKey('RecentPage.Tab.searches')),
    );
    expect(searchesTab.active, isTrue);
  });

  testWidgets('sidebar indexed stack preserves music library scroll offset', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 820);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final libraryData = _libraryDataWithSongs(80);
    final router = createSmPlayerRouter();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          smPlayerI18nProvider.overrideWith((ref) async => testI18n),
          libraryContentDataProvider.overrideWith((ref) async => libraryData),
          shellNavigationDataProvider.overrideWith(
            (ref) async => _shellNavigationData(libraryData),
          ),
        ],
        child: _RouterTestApp(router: router, i18n: testI18n),
      ),
    );
    await _pumpRouter(tester);

    final visibleRow = find.byKey(const ValueKey('MusicLibrary.Row.4'));
    expect(visibleRow, findsOneWidget);
    final listView = tester.widget<ListView>(find.byType(ListView).first);
    final scrollController = listView.controller!;
    final initialOffset = scrollController.offset;

    await tester.dragFrom(tester.getCenter(visibleRow), const Offset(0, -120));
    await tester.pumpAndSettle();

    final scrolledOffset = scrollController.offset;
    expect(scrolledOffset, greaterThan(initialOffset));

    await tester.tap(find.byKey(const ValueKey('RecentItem')).hitTestable());
    await _pumpRouter(tester);
    await tester.tap(
      find.byKey(const ValueKey('MusicLibraryItem')).hitTestable(),
    );
    await _pumpRouter(tester);

    expect(router.routeInformationProvider.value.uri.path, '/songs');
    expect(scrollController.offset, moreOrLessEquals(scrolledOffset));
  });

  testWidgets('sidebar restores workspace app bar title for indexed tabs', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 820);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    const titledI18n = SmPlayerI18n(
      locale: 'en-US',
      messages: {
        'library.allSongs': 'All Songs',
        'library.allSongsWithCount': 'All Songs ({count})',
        'library.allAlbums': 'All Albums',
        'library.allAlbumsWithCount': 'All Albums ({count})',
      },
    );
    final libraryData = _libraryDataWithSongs(80);
    final router = createSmPlayerRouter();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          smPlayerI18nProvider.overrideWith((ref) async => titledI18n),
          libraryContentDataProvider.overrideWith((ref) async => libraryData),
          shellNavigationDataProvider.overrideWith(
            (ref) async => _shellNavigationData(libraryData),
          ),
        ],
        child: _RouterTestApp(router: router, i18n: titledI18n),
      ),
    );
    await _pumpRouter(tester);

    expect(find.text('All Songs (80)'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('AlbumsItem')).hitTestable());
    await _pumpRouter(tester);
    expect(find.text('All Albums (7)'), findsOneWidget);

    router.go('/albums?album=Album 1');
    await _pumpRouter(tester);
    expect(
      router.routeInformationProvider.value.uri.queryParameters['album'],
      'Album 1',
    );

    await tester.tap(
      find.byKey(const ValueKey('MusicLibraryItem')).hitTestable(),
    );
    await _pumpRouter(tester);
    expect(find.text('All Songs (80)'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('AlbumsItem')).hitTestable());
    await _pumpRouter(tester);
    final albumsUri = router.routeInformationProvider.value.uri;
    expect(albumsUri.path, '/albums');
    expect(albumsUri.queryParameters.containsKey('album'), isFalse);
    expect(find.text('All Albums (7)'), findsOneWidget);
  });

  testWidgets('library routes render migrated pages', (tester) async {
    final router = createSmPlayerRouter();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          smPlayerI18nProvider.overrideWith((ref) async => testI18n),
          libraryContentDataProvider.overrideWith(
            (ref) async => emptyLibraryData,
          ),
        ],
        child: _RouterTestApp(router: router, i18n: testI18n),
      ),
    );

    router.go('/artists');
    await _pumpRouter(tester);
    expect(router.routeInformationProvider.value.uri.path, '/artists');

    router.go('/albums');
    await _pumpRouter(tester);
    expect(router.routeInformationProvider.value.uri.path, '/albums');
  });
}

Future<void> _pumpRouter(WidgetTester tester) async {
  for (var pumpIndex = 0; pumpIndex < 6; pumpIndex += 1) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

LibraryContentData _libraryDataWithSongs(
  int count, {
  List<LibraryPlaylist> playlists = const [],
}) {
  final songs = [
    for (var index = 1; index <= count; index += 1)
      LibrarySong(
        id: index,
        path:
            r'C:\Music\song_'
            '$index.mp3',
        title: 'Song ${index.toString().padLeft(3, '0')}',
        artist: 'Artist ${index % 5}',
        artists: ['Artist ${index % 5}'],
        album: 'Album ${index % 7}',
        duration: 120,
        playCount: 0,
        lyricsOffsetMs: 0,
        dateAdded: '2026-05-20T00:00:00',
        favorite: false,
        thumbnailPath: '',
      ),
  ];
  return LibraryContentData(
    songs: songs,
    recentSongs: const [],
    recentPlaylists: const [],
    recentAlbums: const [],
    recentArtists: const [],
    recentSearches: const [],
    playlists: playlists,
    favoritePlaylistId: 0,
    nowPlaying: const NowPlayingSnapshot(playlistId: 0, songIds: []),
    hasLibrary: true,
    sortCriterion: MusicLibrarySortCriterion.title,
    albumsSort: AlbumSortCriterion.defaultSort,
    showCount: true,
    hideMultiSelectCommandBarAfterOperation: true,
    databasePath: '',
    rootPath: r'C:\Music',
  );
}

class _RouterTestApp extends StatelessWidget {
  const _RouterTestApp({required this.router, required this.i18n});

  final RouterConfig<Object> router;
  final SmPlayerI18n i18n;

  @override
  Widget build(BuildContext context) {
    return SmPlayerI18nScope(
      i18n: i18n,
      child: MaterialApp.router(
        theme: buildSmPlayerTheme(const SettingsSnapshot.defaults()),
        routerConfig: router,
      ),
    );
  }
}

ShellNavigationData _shellNavigationData(LibraryContentData data) {
  return ShellNavigationData(
    songs: data.songs,
    playlists: data.playlists,
    folders: data.folders,
    recentSearches: data.recentSearches,
    nowPlaying: data.nowPlaying,
    rootPath: data.rootPath,
  );
}

class _RecordingRouterRepository extends LibraryRepository {
  final recordedSearches = <({String query, SearchHistoryType type})>[];

  List<SearchHistoryEntry> get _recentSearchEntries {
    return [
      for (final entry in recordedSearches.indexed)
        SearchHistoryEntry(
          id: entry.$1 + 1,
          query: entry.$2.query,
          type: entry.$2.type,
          searchedAt: '2026-05-23T00:00:00Z',
        ),
    ];
  }

  @override
  Future<LibraryContentData> getLibraryContentData() async {
    return LibraryContentData(
      songs: const [],
      recentSongs: const [],
      recentPlaylists: const [],
      recentAlbums: const [],
      recentArtists: const [],
      recentSearches: _recentSearchEntries,
      playlists: const [],
      favoritePlaylistId: 0,
      nowPlaying: const NowPlayingSnapshot(playlistId: 0, songIds: []),
      hasLibrary: false,
      sortCriterion: MusicLibrarySortCriterion.title,
      albumsSort: AlbumSortCriterion.defaultSort,
      showCount: true,
      hideMultiSelectCommandBarAfterOperation: true,
      databasePath: '',
      rootPath: r'C:\Music',
    );
  }

  @override
  Future<RecentPageData> getRecentPageData() async {
    return RecentPageData(
      songs: const [],
      recentSongs: const [],
      recentPlaylists: const [],
      recentAlbums: const [],
      recentArtists: const [],
      recentSearches: _recentSearchEntries,
      playlists: const [],
      favoritePlaylistId: 0,
      nowPlaying: const NowPlayingSnapshot(playlistId: 0, songIds: []),
      showCount: true,
      hideMultiSelectCommandBarAfterOperation: true,
    );
  }

  @override
  Future<ShellNavigationData> getShellNavigationData() async {
    return ShellNavigationData(
      songs: const [],
      playlists: const [],
      folders: const [],
      recentSearches: _recentSearchEntries,
      nowPlaying: const NowPlayingSnapshot(playlistId: 0, songIds: []),
      rootPath: r'C:\Music',
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
