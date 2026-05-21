import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
import 'package:smplayer_flutter/src/library/data/library_repository.dart';
import 'package:smplayer_flutter/src/library/ui/artists_page.dart';
import 'package:smplayer_flutter/src/library/ui/artists_page_model.dart'
    show
        buildArtistGroups,
        compareArtistText,
        formatDuration,
        getArtistQuickJumpBucket;
import 'package:smplayer_flutter/src/library/ui/page_selection_store.dart';
import 'package:smplayer_flutter/src/playback/media_control_model.dart'
    hide formatDuration;
import 'package:smplayer_flutter/src/playback/media_control_provider.dart';

void main() {
  setUp(PageSelectionController.clearStoredStates);

  const i18n = SmPlayerI18n(
    locale: 'en-US',
    messages: {
      'artists.albumSummary': '{songs} songs, {duration}',
      'artists.artistSummary': '{albums} albums, {songs} songs',
      'artists.emptyCopy': 'No artists yet.',
      'artists.searchArtistsPlaceholder': 'Search artists',
      'artists.selectArtist': 'Select an artist',
      'albums.addSelectedTo': 'Add To',
      'albums.clearSelection': 'Clear Selection',
      'albums.playSelected': 'Play Selected',
      'albums.reverseSelection': 'Reverse Selection',
      'albums.selectAll': 'Select All',
      'albums.selectedCount': '{count} selected',
      'collection.artistNotFound': 'Artist not found',
      'collection.noArtists': 'No artists',
      'common.albumUnknown': 'Unknown Album',
      'common.artist': 'Artist',
      'common.artistSeparator': ' / ',
      'common.artists': 'Artists',
      'common.artistUnknown': 'Unknown Artist',
      'common.cancel': 'Cancel',
      'common.clear': 'Clear',
      'common.favorite': 'Favorite',
      'common.multiSelect': 'Multi Select',
      'common.myFavorites': 'My Favorites',
      'common.nowPlaying': 'Now Playing',
      'context.addToPlaylist': 'Add To',
      'context.play': 'Play',
      'context.playNext': 'Play Next',
      'context.seeAlbum': 'See Album',
      'context.seeAlbumArt': 'See Album Art',
      'context.seeArtist': 'See Artist',
      'context.seeLyrics': 'See Lyrics',
      'context.seeMusicInfo': 'See Music Info',
      'context.select': 'Select',
      'context.view': 'View',
      'library.scanHelp': 'Scan music first.',
      'library.tryAnotherSearch': 'Try another search.',
      'nowPlaying.randomPlay': 'Shuffle',
      'player.more': 'More',
      'playlists.newPlaylist': 'New Playlist',
      'preferences.level.dislike': 'Dislike',
      'preferences.level.do-not-appear': 'Do Not Appear',
      'preferences.level.high': 'High',
      'preferences.level.higher': 'Higher',
      'preferences.level.normal': 'Normal',
      'preferences.level.very-high': 'Very High',
      'quickJump.disabled': 'No {target} has {basis} starting with {group}',
      'quickJump.enabled': 'Jump to {target} whose {basis} starts with {group}',
      'quickJump.letterGroup': '{key}',
      'quickJump.symbolGroup': 'numbers, symbols, or other characters',
      'settings.preferenceSettings': 'Preference Settings',
      'sidebar.back': 'Back',
      'sidebar.recentSearches': 'Recent searches',
      'sidebar.removeRecentSearch': 'Remove {query}',
    },
  );

  test('artist quick jump folds latin accents like Electron', () {
    expect(getArtistQuickJumpBucket('\u00c9clair'), 'E');
    expect(getArtistQuickJumpBucket('\u00e5ngstr\u00f6m'), 'A');
  });

  test('artist quick jump buckets Chinese names like Electron pinyin', () {
    expect(getArtistQuickJumpBucket('\u9648\u5955\u8fc5'), 'C');
    expect(getArtistQuickJumpBucket('\u674e\u5b97\u76db'), 'L');
    expect(getArtistQuickJumpBucket('\u738b\u83f2'), 'W');
    expect(getArtistQuickJumpBucket('\u5468\u6770\u4f26'), 'Z');
  });

  test('compareArtistText sorts Chinese names by pinyin bucket', () {
    final artists = [
      '\u738b\u83f2',
      '\u5468\u6770\u4f26',
      '\u9648\u5955\u8fc5',
      '\u674e\u5b97\u76db',
    ]..sort(compareArtistText);

    expect(artists, [
      '\u9648\u5955\u8fc5',
      '\u674e\u5b97\u76db',
      '\u738b\u83f2',
      '\u5468\u6770\u4f26',
    ]);
  });

  test('compareArtistText follows Electron numeric collation', () {
    final titles = ['Song 10', 'Song 2', 'Song 1']..sort(compareArtistText);

    expect(titles, ['Song 1', 'Song 2', 'Song 10']);
  });

  test('buildArtistGroups picks Electron artwork song', () {
    final artistsWithArtwork = buildArtistGroups(_artistArtworkSongs, i18n);
    expect(artistsWithArtwork.single.artworkSongId, 2);

    final artistsWithoutArtwork = buildArtistGroups(
      _artistLatestFallbackSongs,
      i18n,
    );
    expect(artistsWithoutArtwork.single.artworkSongId, 4);
  });

  test('buildArtistGroups keeps Electron raw album queue order', () {
    final artists = buildArtistGroups(_artistUnknownAlbumOrderSongs, i18n);

    expect(artists.single.songs.map((song) => song.id), [5, 6]);
  });

  test('formatDuration matches Electron hour display', () {
    expect(formatDuration(65), '1:05');
    expect(formatDuration(3661), '1:01:01');
  });

  testWidgets('ArtistsPage song menu uses Electron Add To submenu', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(_ArtistsTestApp(snapshot: _snapshot, i18n: i18n));
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

  testWidgets('ArtistsPage song view menu opens MusicDialog', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _ArtistsTestApp(
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
    expect(find.text('See Lyrics'), findsOneWidget);
    expect(find.text('See Album Art'), findsOneWidget);
  });

  testWidgets('ArtistsPage shuffle button replaces Now Playing', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final repository = _FakeLibraryRepository();
    final mediaController = MediaControlController();

    await tester.pumpWidget(
      _ArtistsTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: repository,
        mediaController: mediaController,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Shuffle').first);
    await tester.pumpAndSettle();

    expect(repository.replacedNowPlaying, [1]);
    expect(repository.recordedArtists, ['Artist A']);
    expect(mediaController.state.track.id, 1);
    expect(mediaController.state.isPlaying, isTrue);
  });

  testWidgets('ArtistsPage multi-select adds selected songs to playlist', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final repository = _FakeLibraryRepository();

    await tester.pumpWidget(
      _ArtistsTestApp(snapshot: _snapshot, i18n: i18n, repository: repository),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('More').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Multi Select'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Blue Song'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add To'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mix'));
    await tester.pumpAndSettle();

    expect(repository.addedPlaylistId, 10);
    expect(repository.addedSongIds, [1]);
  });

  testWidgets('ArtistsPage keeps selection when Electron setting is off', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final repository = _FakeLibraryRepository();
    final mediaController = MediaControlController();

    await tester.pumpWidget(
      _ArtistsTestApp(
        snapshot: _keepSelectionSnapshot,
        i18n: i18n,
        repository: repository,
        mediaController: mediaController,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('More').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Multi Select'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Blue Song'));
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);

    await tester.tap(find.text('Play Selected'));
    await tester.pumpAndSettle();

    expect(repository.replacedNowPlaying, [1]);
    expect(find.text('1 selected'), findsOneWidget);
  });

  testWidgets(
    'ArtistsPage clears stored selection on wide remount like Electron',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 800);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final storedSelection = PageSelectionController<int>.stored('artists');
      storedSelection.enterMultiSelect();
      storedSelection.selectAll([1]);

      await tester.pumpWidget(_ArtistsTestApp(snapshot: _snapshot, i18n: i18n));
      await tester.pumpAndSettle();

      final restoredSelection = PageSelectionController<int>.stored('artists');
      expect(restoredSelection.multiSelect, isFalse);
      expect(restoredSelection.selectedItems, isEmpty);
      expect(find.text('1 selected'), findsNothing);
    },
  );

  testWidgets('ArtistsPage album shuffle records the album like Electron', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final repository = _FakeLibraryRepository();
    final mediaController = MediaControlController();

    await tester.pumpWidget(
      _ArtistsTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: repository,
        mediaController: mediaController,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Shuffle').last);
    await tester.pumpAndSettle();

    expect(repository.recordedAlbums, ['Blue Hour']);
    expect(repository.replacedNowPlaying, [1]);
    expect(mediaController.state.track.id, 1);
  });

  testWidgets('ArtistsPage artist group menu writes Electron preference', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final repository = _FakeLibraryRepository();

    await tester.pumpWidget(
      _ArtistsTestApp(snapshot: _snapshot, i18n: i18n, repository: repository),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('More').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Preference Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('High'));
    await tester.pumpAndSettle();

    expect(repository.preferenceType, 'artist');
    expect(repository.preferenceItemId, 'Artist A');
    expect(repository.preferenceName, 'Artist A');
    expect(repository.preferenceLevel, 'high');
  });

  testWidgets('ArtistsPage album group menu mirrors Electron actions', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final router = _createArtistsRouter();

    await tester.pumpWidget(
      _ArtistsRouterTestApp(snapshot: _snapshot, i18n: i18n, router: router),
    );
    router.go('/artists?artist=Artist%20A');
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('More').at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle();

    expect(find.text('1 selected'), findsOneWidget);

    await tester.tap(find.byTooltip('More').at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('See Album'));
    await tester.pumpAndSettle();

    final uri = router.routeInformationProvider.value.uri;
    expect(uri.path, '/albums');
    expect(uri.queryParameters['album'], 'Blue Hour');
  });

  testWidgets('ArtistsPage song row uses PlaylistControlItem actions', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final repository = _FakeLibraryRepository();
    final mediaController = MediaControlController();

    await tester.pumpWidget(
      _ArtistsTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: repository,
        mediaController: mediaController,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Blue Song'));
    await tester.pumpAndSettle();

    expect(repository.replacedNowPlaying, [1]);
    expect(mediaController.state.track.id, 1);
    expect(mediaController.state.selectedQueueIndex, 0);

    await tester.tap(find.byTooltip('Favorite'));
    await tester.pumpAndSettle();

    expect(repository.favoriteSongIds, [1]);
    expect(repository.favoriteValue, isTrue);

    await tester.tap(find.byTooltip('Play Next'));
    await tester.pumpAndSettle();

    expect(repository.replacedNowPlaying, [1]);
  });

  testWidgets('ArtistsPage song row Add To writes the target playlist', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final repository = _FakeLibraryRepository();

    await tester.pumpWidget(
      _ArtistsTestApp(snapshot: _snapshot, i18n: i18n, repository: repository),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Add To'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mix'));
    await tester.pumpAndSettle();

    expect(repository.addedPlaylistId, 10);
    expect(repository.addedSongIds, [1]);
  });

  testWidgets(
    'ArtistsPage wide artist selection keeps Electron route unchanged',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 800);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final router = _createArtistsRouter();

      await tester.pumpWidget(
        _ArtistsRouterTestApp(snapshot: _snapshot, i18n: i18n, router: router),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Artist A').first);
      await tester.pumpAndSettle();

      final uri = router.routeInformationProvider.value.uri;
      expect(uri.path, '/artists');
      expect(uri.queryParameters['artist'], isNull);
    },
  );

  testWidgets(
    'ArtistsPage search typing keeps the selected artist like Electron',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 800);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        _ArtistsTestApp(snapshot: _twoArtistSnapshot, i18n: i18n),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Artist B').first);
      await tester.pumpAndSettle();
      expect(find.text('Green Song'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Art');
      await tester.pumpAndSettle();

      expect(find.text('Green Song'), findsOneWidget);
    },
  );

  testWidgets(
    'ArtistsPage compact artist selection opens the Electron query route',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(640, 900);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final router = _createArtistsRouter();

      await tester.pumpWidget(
        _ArtistsRouterTestApp(snapshot: _snapshot, i18n: i18n, router: router),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Artist A').first);
      await tester.pumpAndSettle();

      final uri = router.routeInformationProvider.value.uri;
      expect(uri.path, '/artists');
      expect(uri.queryParameters['artist'], 'Artist A');
    },
  );

  testWidgets('ArtistsPage records submitted artist searches', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final repository = _FakeLibraryRepository();
    final router = _createArtistsRouter();

    await tester.pumpWidget(
      _ArtistsRouterTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        router: router,
        repository: repository,
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), ' Artist ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(repository.recordedSearches, [
      (query: 'Artist A', type: SearchHistoryType.artists),
    ]);
    final uri = router.routeInformationProvider.value.uri;
    expect(uri.path, '/artists');
    expect(uri.queryParameters['artist'], isNull);
  });

  testWidgets('ArtistsPage selects artist search suggestions', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final repository = _FakeLibraryRepository();
    final router = _createArtistsRouter();

    await tester.pumpWidget(
      _ArtistsRouterTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        router: router,
        repository: repository,
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Art');
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('PageSearchHistoryPanel.Item.Artist A')),
    );
    await tester.pumpAndSettle();

    expect(repository.recordedSearches, [
      (query: 'Artist A', type: SearchHistoryType.artists),
    ]);
    final uri = router.routeInformationProvider.value.uri;
    expect(uri.path, '/artists');
    expect(uri.queryParameters['artist'], isNull);
  });

  testWidgets('ArtistsPage selects recent artist searches', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final repository = _FakeLibraryRepository();
    final router = _createArtistsRouter();

    await tester.pumpWidget(
      _ArtistsRouterTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        router: router,
        repository: repository,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('PageSearchHistoryPanel.Item.Artist A')),
    );
    await tester.pumpAndSettle();

    expect(repository.recordedSearches, [
      (query: 'Artist A', type: SearchHistoryType.artists),
    ]);
    final uri = router.routeInformationProvider.value.uri;
    expect(uri.path, '/artists');
    expect(uri.queryParameters['artist'], isNull);
  });

  testWidgets(
    'ArtistsPage keeps route search out of empty focused suggestions',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 800);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        _ArtistsTestApp(
          snapshot: _twoArtistSnapshot,
          i18n: i18n,
          searchQuery: 'Artist B',
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('PageSearchHistoryPanel.Item.Artist B')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('PageSearchHistoryPanel.Item.Artist A')),
        findsNothing,
      );
    },
  );

  testWidgets('ArtistsPage album title opens the Electron album route', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final router = _createArtistsRouter();

    await tester.pumpWidget(
      _ArtistsRouterTestApp(snapshot: _snapshot, i18n: i18n, router: router),
    );
    router.go('/artists?artist=Artist%20A');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Blue Hour'));
    await tester.pumpAndSettle();

    final uri = router.routeInformationProvider.value.uri;
    expect(uri.path, '/albums');
    expect(uri.queryParameters['album'], 'Blue Hour');
  });

  testWidgets(
    'ArtistsPage See Album routes unknown albums through the i18n label',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 800);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final router = _createArtistsRouter();

      await tester.pumpWidget(
        _ArtistsRouterTestApp(
          snapshot: _unknownAlbumSnapshot,
          i18n: i18n,
          router: router,
        ),
      );
      router.go('/artists?artist=Artist%20A');
      await tester.pumpAndSettle();

      await tester.tap(
        find.text('Untitled Song'),
        buttons: kSecondaryMouseButton,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('View'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('See Album'));
      await tester.pumpAndSettle();

      final uri = router.routeInformationProvider.value.uri;
      expect(uri.path, '/albums');
      expect(uri.queryParameters['album'], 'Unknown Album');
    },
  );

  testWidgets(
    'ArtistsPage missing target artist shows Electron not found notice',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 800);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final router = _createArtistsRouter();

      await tester.pumpWidget(
        _ArtistsRouterTestApp(snapshot: _snapshot, i18n: i18n, router: router),
      );
      router.go('/artists?artist=Missing');
      await tester.pumpAndSettle();

      expect(find.text('Artist not found'), findsOneWidget);
    },
  );

  testWidgets(
    'ArtistsPage target route records search and fills input like Electron',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 800);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final repository = _FakeLibraryRepository();
      final router = _createArtistsRouter();

      await tester.pumpWidget(
        _ArtistsRouterTestApp(
          snapshot: _twoArtistSnapshot,
          i18n: i18n,
          router: router,
          repository: repository,
        ),
      );
      router.go('/artists?artist=Artist%20B');
      await tester.pumpAndSettle();

      expect(repository.recordedSearches, [
        (query: 'Artist B', type: SearchHistoryType.artists),
      ]);
      final searchBox = tester.widget<TextField>(find.byType(TextField));
      expect(searchBox.controller!.text, 'Artist B');
      expect(find.text('Green Song'), findsOneWidget);
    },
  );

  testWidgets(
    'ArtistsPage applies target after library refresh like Electron',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 800);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final snapshot = ValueNotifier(_snapshot);
      final repository = _ValueListenableArtistsRepository(snapshot);
      final router = _createArtistsRouter();

      await tester.pumpWidget(
        _ArtistsSnapshotRouterTestApp(
          snapshot: snapshot,
          i18n: i18n,
          router: router,
          repository: repository,
        ),
      );
      router.go('/artists?artist=Artist%20B');
      await tester.pumpAndSettle();

      expect(find.text('Artist not found'), findsOneWidget);

      snapshot.value = _twoArtistSnapshot;
      await tester.pumpAndSettle();

      expect(repository.recordedSearches, [
        (query: 'Artist B', type: SearchHistoryType.artists),
      ]);
      expect(find.text('Green Song'), findsOneWidget);
    },
  );

  testWidgets('ArtistsPage keeps quick jump visible in compact master list', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(640, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(_ArtistsTestApp(snapshot: _snapshot, i18n: i18n));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('Artists.QuickJump.A')), findsOneWidget);
    expect(
      find.byTooltip('Jump to Artists whose Artist starts with A'),
      findsOneWidget,
    );
  });

  testWidgets('ArtistsPage quick jump scrolls compact list like Electron', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(640, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _ArtistsTestApp(snapshot: _manyArtistsSnapshot(), i18n: i18n),
    );
    await tester.pumpAndSettle();

    expect(find.text('Beta Target'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('Artists.QuickJump.B')));
    await tester.pumpAndSettle();

    expect(find.text('Beta Target'), findsOneWidget);
  });
}

GoRouter _createArtistsRouter() {
  return GoRouter(
    initialLocation: '/artists',
    routes: [
      GoRoute(
        path: '/artists',
        builder:
            (context, state) => Scaffold(
              body: ArtistsPage(
                searchQuery: state.uri.queryParameters['search'] ?? '',
                targetArtistName: state.uri.queryParameters['artist'],
              ),
            ),
      ),
      GoRoute(
        path: '/albums',
        builder:
            (context, state) =>
                Scaffold(body: Text(state.uri.queryParameters['album'] ?? '')),
      ),
    ],
  );
}

class _ArtistsRouterTestApp extends StatelessWidget {
  const _ArtistsRouterTestApp({
    required this.snapshot,
    required this.i18n,
    required this.router,
    this.repository,
  });

  final MusicLibrarySnapshot snapshot;
  final SmPlayerI18n i18n;
  final GoRouter router;
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
        child: MaterialApp.router(routerConfig: router),
      ),
    );
  }
}

class _ArtistsTestApp extends StatelessWidget {
  const _ArtistsTestApp({
    required this.snapshot,
    required this.i18n,
    this.repository,
    this.mediaController,
    this.searchQuery = '',
  });

  final MusicLibrarySnapshot snapshot;
  final SmPlayerI18n i18n;
  final LibraryRepository? repository;
  final MediaControlController? mediaController;
  final String searchQuery;

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
        child: MaterialApp(
          home: Scaffold(body: ArtistsPage(searchQuery: searchQuery)),
        ),
      ),
    );
  }
}

class _ArtistsSnapshotRouterTestApp extends StatelessWidget {
  const _ArtistsSnapshotRouterTestApp({
    required this.snapshot,
    required this.i18n,
    required this.router,
    required this.repository,
  });

  final ValueNotifier<MusicLibrarySnapshot> snapshot;
  final SmPlayerI18n i18n;
  final GoRouter router;
  final _ValueListenableArtistsRepository repository;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        smPlayerI18nProvider.overrideWith((ref) async => i18n),
        libraryRepositoryProvider.overrideWithValue(repository),
      ],
      child: SmPlayerI18nScope(
        i18n: i18n,
        child: _ArtistsSnapshotInvalidator(snapshot: snapshot, router: router),
      ),
    );
  }
}

class _ArtistsSnapshotInvalidator extends ConsumerStatefulWidget {
  const _ArtistsSnapshotInvalidator({
    required this.snapshot,
    required this.router,
  });

  final ValueNotifier<MusicLibrarySnapshot> snapshot;
  final GoRouter router;

  @override
  ConsumerState<_ArtistsSnapshotInvalidator> createState() =>
      _ArtistsSnapshotInvalidatorState();
}

class _ArtistsSnapshotInvalidatorState
    extends ConsumerState<_ArtistsSnapshotInvalidator> {
  @override
  void initState() {
    super.initState();
    widget.snapshot.addListener(_invalidateSnapshot);
  }

  @override
  void didUpdateWidget(_ArtistsSnapshotInvalidator oldWidget) {
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
    return MaterialApp.router(routerConfig: widget.router);
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
  List<String> recordedArtists = [];
  List<String> recordedAlbums = [];
  List<({String query, SearchHistoryType type})> recordedSearches = [];
  String? preferenceType;
  String? preferenceItemId;
  String? preferenceName;
  String? preferenceLevel;

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
  Future<void> recordArtistPlayed(String artist) async {
    recordedArtists.add(artist);
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

  @override
  Future<void> addPreferenceItem(
    String type,
    String itemId,
    String name,
    String level,
  ) async {
    preferenceType = type;
    preferenceItemId = itemId;
    preferenceName = name;
    preferenceLevel = level;
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
  Future<LyricsSnapshot> getSongLyrics(int songId) async {
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

class _ValueListenableArtistsRepository extends _FakeLibraryRepository {
  _ValueListenableArtistsRepository(this.snapshot);

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
  ],
  recentSongs: [],
  recentPlaylists: [],
  recentAlbums: [],
  recentArtists: [],
  recentSearches: [
    SearchHistoryEntry(
      id: 31,
      query: 'Artist A',
      type: SearchHistoryType.artists,
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
  favoritePlaylistId: 3,
  nowPlaying: NowPlayingSnapshot(playlistId: 0, songIds: []),
  hasLibrary: true,
  sortCriterion: MusicLibrarySortCriterion.title,
  albumsSort: AlbumSortCriterion.defaultSort,
  showCount: true,
  hideMultiSelectCommandBarAfterOperation: true,
  databasePath: '',
);

const _twoArtistSnapshot = MusicLibrarySnapshot(
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
      path: r'C:\Music\green.mp3',
      title: 'Green Song',
      artist: 'Artist B',
      artists: ['Artist B'],
      album: 'Green Hour',
      duration: 120,
      playCount: 0,
      lyricsOffsetMs: 0,
      dateAdded: '2026-05-21T00:00:00',
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
  favoritePlaylistId: 3,
  nowPlaying: NowPlayingSnapshot(playlistId: 0, songIds: []),
  hasLibrary: true,
  sortCriterion: MusicLibrarySortCriterion.title,
  albumsSort: AlbumSortCriterion.defaultSort,
  showCount: true,
  hideMultiSelectCommandBarAfterOperation: true,
  databasePath: '',
);

const _artistArtworkSongs = [
  LibrarySong(
    id: 1,
    path: r'C:\Music\older.mp3',
    title: 'Older Song',
    artist: 'Artist A',
    artists: ['Artist A'],
    album: 'A Album',
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
    album: 'B Album',
    duration: 120,
    playCount: 0,
    lyricsOffsetMs: 0,
    dateAdded: '2026-05-19T00:00:00',
    favorite: false,
    thumbnailPath: r'C:\Music\cover.jpg',
  ),
];

const _artistLatestFallbackSongs = [
  LibrarySong(
    id: 3,
    path: r'C:\Music\older.mp3',
    title: 'Older Song',
    artist: 'Artist A',
    artists: ['Artist A'],
    album: 'A Album',
    duration: 120,
    playCount: 0,
    lyricsOffsetMs: 0,
    dateAdded: '2026-05-19T00:00:00',
    favorite: false,
    thumbnailPath: '',
  ),
  LibrarySong(
    id: 4,
    path: r'C:\Music\latest.mp3',
    title: 'Latest Song',
    artist: 'Artist A',
    artists: ['Artist A'],
    album: 'B Album',
    duration: 120,
    playCount: 0,
    lyricsOffsetMs: 0,
    dateAdded: '2026-05-20T00:00:00',
    favorite: false,
    thumbnailPath: '',
  ),
];

const _artistUnknownAlbumOrderSongs = [
  LibrarySong(
    id: 5,
    path: r'C:\Music\unknown.mp3',
    title: 'Unknown Album Song',
    artist: 'Artist A',
    artists: ['Artist A'],
    album: '',
    duration: 120,
    playCount: 0,
    lyricsOffsetMs: 0,
    dateAdded: '2026-05-19T00:00:00',
    favorite: false,
    thumbnailPath: '',
  ),
  LibrarySong(
    id: 6,
    path: r'C:\Music\alpha.mp3',
    title: 'Alpha Album Song',
    artist: 'Artist A',
    artists: ['Artist A'],
    album: 'Alpha',
    duration: 120,
    playCount: 0,
    lyricsOffsetMs: 0,
    dateAdded: '2026-05-20T00:00:00',
    favorite: false,
    thumbnailPath: '',
  ),
];

final _keepSelectionSnapshot = MusicLibrarySnapshot(
  songs: _snapshot.songs,
  recentSongs: _snapshot.recentSongs,
  recentPlaylists: _snapshot.recentPlaylists,
  recentAlbums: _snapshot.recentAlbums,
  recentArtists: _snapshot.recentArtists,
  recentSearches: _snapshot.recentSearches,
  playlists: _snapshot.playlists,
  favoritePlaylistId: _snapshot.favoritePlaylistId,
  nowPlaying: _snapshot.nowPlaying,
  hasLibrary: _snapshot.hasLibrary,
  sortCriterion: _snapshot.sortCriterion,
  albumsSort: _snapshot.albumsSort,
  showCount: _snapshot.showCount,
  hideMultiSelectCommandBarAfterOperation: false,
  databasePath: _snapshot.databasePath,
);

const _unknownAlbumSnapshot = MusicLibrarySnapshot(
  songs: [
    LibrarySong(
      id: 2,
      path: r'C:\Music\untitled.mp3',
      title: 'Untitled Song',
      artist: 'Artist A',
      artists: ['Artist A'],
      album: '',
      duration: 90,
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

MusicLibrarySnapshot _manyArtistsSnapshot() {
  return MusicLibrarySnapshot(
    songs: [
      for (var index = 0; index < 36; index += 1)
        LibrarySong(
          id: index + 1,
          path: r'C:\Music\alpha.mp3',
          title: 'Alpha Song $index',
          artist: 'Alpha $index',
          artists: ['Alpha $index'],
          album: 'Alpha Album',
          duration: 120,
          playCount: 0,
          lyricsOffsetMs: 0,
          dateAdded: '2026-05-20T00:00:00',
          favorite: false,
          thumbnailPath: '',
        ),
      const LibrarySong(
        id: 100,
        path: r'C:\Music\beta.mp3',
        title: 'Beta Song',
        artist: 'Beta Target',
        artists: ['Beta Target'],
        album: 'Beta Album',
        duration: 120,
        playCount: 0,
        lyricsOffsetMs: 0,
        dateAdded: '2026-05-20T00:00:00',
        favorite: false,
        thumbnailPath: '',
      ),
      for (var index = 0; index < 36; index += 1)
        LibrarySong(
          id: index + 101,
          path: r'C:\Music\charlie.mp3',
          title: 'Charlie Song $index',
          artist: 'Charlie $index',
          artists: ['Charlie $index'],
          album: 'Charlie Album',
          duration: 120,
          playCount: 0,
          lyricsOffsetMs: 0,
          dateAdded: '2026-05-20T00:00:00',
          favorite: false,
          thumbnailPath: '',
        ),
    ],
    hasLibrary: true,
    sortCriterion: MusicLibrarySortCriterion.title,
    albumsSort: AlbumSortCriterion.defaultSort,
    databasePath: '',
  );
}
