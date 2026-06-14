import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:smplayer_flutter/src/app/app_interaction_colors.dart';
import 'package:smplayer_flutter/src/app/app_appearance_model.dart';
import 'package:smplayer_flutter/src/app/smplayer_vector_icons.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
import 'package:smplayer_flutter/src/library/data/library_repository.dart';
import 'package:smplayer_flutter/src/library/ui/command_bar.dart';
import 'package:smplayer_flutter/src/library/ui/grid_artwork_card_content.dart';
import 'package:smplayer_flutter/src/library/ui/multi_select_command_bar.dart';
import 'package:smplayer_flutter/src/playback/media_control_model.dart';
import 'package:smplayer_flutter/src/playback/media_control_provider.dart';
import 'package:smplayer_flutter/src/recent/recent_page.dart';
import 'package:smplayer_flutter/src/recent/recent_page_model.dart';
import 'package:smplayer_flutter/src/settings/settings_model.dart'
    show LyricsRequestMode, NightMode, SettingsSnapshot;

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
      'detail.playAlbum': 'Play Album',
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
      'notification.songAddedTo': 'Added {title} to {target}',
    },
  );

  test('Recent artist artwork uses first song with artwork like Electron', () {
    final artists = buildRecentArtistViews(
      const [
        LibrarySong(
          id: 1,
          path: r'C:\Music\a.mp3',
          title: 'No Cover',
          artist: 'Artist',
          artists: ['Artist'],
          album: 'Album A',
          duration: 120,
          playCount: 0,
          lyricsOffsetMs: 0,
          dateAdded: '2026-05-20T00:00:00',
          favorite: false,
          thumbnailPath: '',
        ),
        LibrarySong(
          id: 2,
          path: r'C:\Music\b.mp3',
          title: 'Has Cover',
          artist: 'Artist',
          artists: ['Artist'],
          album: 'Album B',
          duration: 120,
          playCount: 0,
          lyricsOffsetMs: 0,
          dateAdded: '2026-05-20T00:00:00',
          favorite: false,
          thumbnailPath: r'C:\covers\artist.png',
        ),
      ],
      const [
        RecentArtistPlayback(
          id: 1,
          artist: 'Artist',
          playedAt: '2026-05-20T00:00:00',
        ),
      ],
      i18n,
    );

    expect(artists.single.artworkUrl, r'C:\covers\artist.png');
  });

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

    expect(find.text('Add To'), findsWidgets);
    expect(find.text('Mix'), findsNothing);
    expect(find.text('Built in'), findsNothing);

    await tester.tap(find.text('Add To').last);
    await tester.pumpAndSettle();

    expect(find.text('Now Playing'), findsOneWidget);
    expect(find.text('My Favorites'), findsOneWidget);
    expect(find.text('New Playlist'), findsOneWidget);
    expect(find.text('Mix'), findsOneWidget);
    expect(find.text('Built in'), findsNothing);
  });

  testWidgets('RecentPage Add To My Favorites writes favorite state', (
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

    await tester.tap(find.text('Blue Song'), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add To').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('My Favorites'));
    await tester.pumpAndSettle();

    expect(repository.favoriteSongIds, [1]);
    expect(repository.favoriteValue, isTrue);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(repository.favoriteSongIds, [1]);
    expect(repository.favoriteValue, isFalse);
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

  testWidgets('RecentPage searches multi-select hides Play and Add To', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _RecentTestApp(snapshot: _snapshotWithSearches, i18n: i18n),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Searches'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Multi Select'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('Recent.SearchRow.4')));
    await tester.pumpAndSettle();

    expect(find.text('1 selected'), findsOneWidget);
    expect(find.text('Play Selected'), findsNothing);
    expect(find.text('Add To'), findsNothing);
    expect(find.text('Remove'), findsOneWidget);
  });

  testWidgets('RecentPage multi-select bar bleeds to workspace edges', (
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

    await tester.tap(find.text('Multi Select'));
    await tester.pumpAndSettle();

    final surfaceRect = tester.getRect(
      find.byKey(const ValueKey('MultiSelectCommandBar.Surface')),
    );
    expect(surfaceRect.left, 0);
    expect(surfaceRect.right, 1200);
    expect(surfaceRect.width, 1200);
    expect(surfaceRect.bottom, 800 - multiSelectCommandBarShellBottomInset);
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

    await tester.tap(find.text('Searches'));
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

    await tester.tap(find.text('Searches'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(FluentIcons.dismiss_16_regular).first);
    await tester.pumpAndSettle();

    expect(repository.removedRecentSearchIds, [4]);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(repository.restoredRecentSearches.single.id, 4);
    expect(repository.restoredRecentSearches.single.query, 'blue');
  });

  testWidgets('RecentPage aligns recent search rows to the command bar edge', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(2010, 900);
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
      ],
    );

    await tester.pumpWidget(
      _RecentRouterTestApp(
        router: router,
        snapshot: _snapshotWithSearches,
        i18n: i18n,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Searches'));
    await tester.pumpAndSettle();

    final commandBarRight = tester.getRect(find.byType(CommandBar)).right;
    final searchRowRight =
        tester.getRect(find.byKey(const ValueKey('Recent.SearchRow.4'))).right;

    expect(searchRowRight, commandBarRight);
  });

  testWidgets('RecentPage opens recent searches with their saved type', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1800, 1000);
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

    await tester.tap(find.text('Searches'));
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

    await tester.tap(find.text('Searches'));
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

    await tester.tap(find.text('Played'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Albums'));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.text('2025.01'), findsOneWidget);
    expect(find.text('2024.12'), findsOneWidget);
  });

  testWidgets('RecentPage played albums reuse playlist card content style', (
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

    await tester.tap(find.text('Played'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Albums'));
    await tester.pumpAndSettle();

    final card = find.byKey(const ValueKey('RecentAlbum.Card')).first;
    expect(find.byType(GridArtworkCardContent), findsWidgets);
    expect(find.byKey(const ValueKey('AlbumTile.Container')), findsNothing);
    expect(tester.getSize(card).width, 180);

    final container = tester.widget<AnimatedContainer>(card);
    expect(container.constraints!.minHeight, 232);
    expect(container.padding, const EdgeInsets.all(10));

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: tester.getCenter(card));
    await tester.pump();

    final hovered = tester.widget<AnimatedContainer>(card);
    final decoration = hovered.decoration! as BoxDecoration;
    final foregroundDecoration = hovered.foregroundDecoration! as BoxDecoration;
    expect(decoration.color, GlobalUI.hoverBgColorDay);
    expect(
      foregroundDecoration.border!.top.color,
      GlobalUI.hoverBorderColorDay,
    );
    expect(find.byTooltip('Play Album'), findsOneWidget);
    expect(find.byTooltip('Add To'), findsOneWidget);
  });

  testWidgets(
    'RecentPage played playlists hide selection mark outside select',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 800);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        _RecentTestApp(snapshot: _snapshotWithRecentPlaylists, i18n: i18n),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Played'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Playlists'));
      await tester.pumpAndSettle();

      expect(find.text('Mix'), findsOneWidget);
      expect(find.byType(GridViewSelectionMark), findsNothing);

      await tester.tap(find.text('Multi Select'));
      await tester.pumpAndSettle();

      expect(find.byType(GridViewSelectionMark), findsOneWidget);
    },
  );

  testWidgets('RecentPage refreshes after collection play is recorded', (
    tester,
  ) async {
    final repository = _FakeLibraryRepository();
    final recordCompleter = Completer<void>();
    repository.albumRecordCompleter = recordCompleter;
    var snapshotLoads = 0;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(2000, 1200);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          smPlayerI18nProvider.overrideWith((ref) async => i18n),
          recentPageDataProvider.overrideWith((ref) async {
            snapshotLoads += 1;
            return _recentPageData(_snapshotWithRecentAlbums);
          }),
          libraryContentDataProvider.overrideWith(
            (ref) async => _snapshotWithRecentAlbums,
          ),
          libraryRepositoryProvider.overrideWithValue(repository),
        ],
        child: SmPlayerI18nScope(
          i18n: i18n,
          child: MaterialApp(
            theme: _recentPageTestTheme(),
            home: const Scaffold(body: RecentPage()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Played'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Albums'));
    await tester.pumpAndSettle();
    tester.takeException();
    final loadsBeforePlay = snapshotLoads;
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer();
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.text('January Album')));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SmPlayerPlayIcon).first);
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

    await tester.tap(find.text('Played'));
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

  testWidgets('RecentPage grid music hover shows artist-style border', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _RecentTestApp(snapshot: _snapshotWithRecentPlayed, i18n: i18n),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Played'));
    await tester.pumpAndSettle();

    final tile =
        find
            .ancestor(
              of: find.text('Blue Song'),
              matching: find.byType(AnimatedContainer),
            )
            .first;
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(tile));
    addTearDown(mouse.removePointer);
    await tester.pump();

    final decoration = tester.widget<AnimatedContainer>(tile).decoration;
    expect(decoration, isA<BoxDecoration>());
    final boxDecoration = decoration! as BoxDecoration;
    final foregroundDecoration =
        tester.widget<AnimatedContainer>(tile).foregroundDecoration!
            as BoxDecoration;
    expect(boxDecoration.color, GlobalUI.hoverBgColorDay);
    expect(boxDecoration.border, isNull);
    expect(
      foregroundDecoration.border,
      Border.all(color: GlobalUI.hoverBorderColorDay),
    );
    expect(boxDecoration.boxShadow, isNotEmpty);
    expect(boxDecoration.boxShadow!.single, GlobalUI.hoverShadowDay);
    expect(tester.getSize(tile).height, 116);
    expect(tester.widget<AnimatedContainer>(tile).padding, EdgeInsets.zero);
    final artwork = find.byKey(const ValueKey('RecentSong.Artwork.1'));
    expect(tester.getTopLeft(artwork), tester.getTopLeft(tile));
    expect(tester.getSize(artwork).height, tester.getSize(tile).height);
    final artworkShell = tester.widget<SizedBox>(artwork);
    final artworkShadow =
        (artworkShell.child! as DecoratedBox).decoration as BoxDecoration;
    expect(artworkShadow.boxShadow, isNotEmpty);
  });

  testWidgets('RecentPage narrow song tiles use the smallest layout', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(640, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _RecentTestApp(snapshot: _snapshotWithRecentPlayed, i18n: i18n),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Played'));
    await tester.pumpAndSettle();

    final tile =
        find
            .ancestor(
              of: find.text('Blue Song'),
              matching: find.byType(AnimatedContainer),
            )
            .first;
    final artwork = find.byKey(const ValueKey('RecentSong.Artwork.1'));

    expect(tester.getSize(tile).height, 78);
    expect(tester.getSize(artwork), const Size(78, 78));
  });

  testWidgets(
    'RecentPage song hover artwork action opens Add To like Electron',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 800);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final repository = _FakeLibraryRepository();

      await tester.pumpWidget(
        _RecentTestApp(
          snapshot: _snapshotWithRecentPlayed,
          i18n: i18n,
          repository: repository,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Played'));
      await tester.pumpAndSettle();

      final tile =
          find
              .ancestor(
                of: find.text('Blue Song'),
                matching: find.byType(AnimatedContainer),
              )
              .first;
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: tester.getCenter(tile));
      addTearDown(mouse.removePointer);
      await tester.pump();

      final addButton = find.descendant(
        of: tile,
        matching: find.byIcon(FluentIcons.add_20_regular),
      );
      expect(addButton, findsOneWidget);
      expect(
        find.descendant(
          of: tile,
          matching: find.byIcon(FluentIcons.play_20_regular),
        ),
        findsNothing,
      );

      await tester.tap(addButton);
      await tester.pumpAndSettle();

      expect(repository.replacedNowPlaying, isEmpty);
      expect(find.text('Now Playing'), findsOneWidget);
      expect(find.text('My Favorites'), findsOneWidget);
      expect(find.text('New Playlist'), findsOneWidget);
    },
  );

  testWidgets(
    'RecentPage song hover actions match Electron Play Next and More',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 800);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final repository = _FakeLibraryRepository();

      await tester.pumpWidget(
        _RecentTestApp(
          snapshot: _snapshotWithRecentPlayed,
          i18n: i18n,
          repository: repository,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Played'));
      await tester.pumpAndSettle();

      final tile =
          find
              .ancestor(
                of: find.text('Blue Song'),
                matching: find.byType(AnimatedContainer),
              )
              .first;
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: tester.getCenter(tile));
      addTearDown(mouse.removePointer);
      await tester.pump();

      final playNext = find.descendant(
        of: tile,
        matching: find.byType(SmPlayerPlayNextIcon),
      );
      final more = find.descendant(
        of: tile,
        matching: find.byIcon(FluentIcons.more_horizontal_20_regular),
      );
      expect(playNext, findsOneWidget);
      expect(more, findsOneWidget);

      await tester.tap(playNext);
      await tester.pumpAndSettle();

      expect(repository.replacedNowPlaying, [1]);

      await tester.tap(more);
      await tester.pumpAndSettle();

      expect(find.text('Add To'), findsWidgets);
      expect(find.text('View'), findsOneWidget);
    },
  );

  testWidgets('RecentPage song artist line opens artist without playing', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repository = _FakeLibraryRepository();
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
      ],
    );

    await tester.pumpWidget(
      _RecentRouterTestApp(
        router: router,
        snapshot: _snapshotWithRecentPlayed,
        i18n: i18n,
        repository: repository,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Played'));
    await tester.pumpAndSettle();

    final tile =
        find
            .ancestor(
              of: find.text('Blue Song'),
              matching: find.byType(AnimatedContainer),
            )
            .first;
    final artistLine = find.descendant(
      of: tile,
      matching: find.byKey(const ValueKey('RecentSong.ArtistLine')),
    );
    Text artistText() => tester.widget<Text>(
      find.descendant(of: artistLine, matching: find.byType(Text)),
    );

    expect(artistLine, findsOneWidget);
    expect(artistText().style?.color, const Color(0xff5b697a));

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer();
    addTearDown(mouse.removePointer);
    final artistCenter = tester.getCenter(artistLine);
    await mouse.moveTo(artistCenter);
    await tester.pump();
    await mouse.moveTo(artistCenter + const Offset(1, 0));
    await tester.pump();

    expect(artistText().style?.color, const Color(0xff0063b1));

    await tester.tap(artistLine);
    await tester.pumpAndSettle();

    expect(find.text('artist:Artist A'), findsOneWidget);
    expect(repository.replacedNowPlaying, isEmpty);
  });

  testWidgets('RecentPage song hover narrows artist line before actions', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    const longArtist = 'distinctivecontactdistinctivecontactdistinctivecontact';
    const snapshot = LibraryContentData(
      songs: [
        LibrarySong(
          id: 21,
          path: r'C:\Music\drill.mp3',
          title: 'Meteor Drill',
          artist: longArtist,
          artists: [longArtist],
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
          id: 21,
          path: r'C:\Music\drill.mp3',
          title: 'Meteor Drill',
          artist: longArtist,
          artists: [longArtist],
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

    await tester.pumpWidget(_RecentTestApp(snapshot: snapshot, i18n: i18n));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Played'));
    await tester.pumpAndSettle();

    final tile =
        find
            .ancestor(
              of: find.text('Meteor Drill'),
              matching: find.byType(AnimatedContainer),
            )
            .first;
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(tile));
    addTearDown(mouse.removePointer);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 140));

    final artistLine = find.descendant(
      of: tile,
      matching: find.byKey(const ValueKey('RecentSong.ArtistLine')),
    );
    final playNextButton = find.ancestor(
      of: find.descendant(
        of: tile,
        matching: find.byType(SmPlayerPlayNextIcon),
      ),
      matching: find.byType(IconButton),
    );

    expect(artistLine, findsOneWidget);
    expect(playNextButton, findsOneWidget);
    expect(
      tester.getRect(artistLine).right,
      lessThanOrEqualTo(tester.getRect(playNextButton).left),
    );
  });

  testWidgets('RecentPage song hover actions use Electron night colors', (
    tester,
  ) async {
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
        theme: _recentPageTestTheme(brightness: Brightness.dark),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Played'));
    await tester.pumpAndSettle();

    final tile =
        find
            .ancestor(
              of: find.text('Blue Song'),
              matching: find.byType(AnimatedContainer),
            )
            .first;
    final tileMouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await tileMouse.addPointer(location: tester.getCenter(tile));
    addTearDown(tileMouse.removePointer);
    await tester.pump();

    final moreButton = find.ancestor(
      of: find.descendant(
        of: tile,
        matching: find.byIcon(FluentIcons.more_horizontal_20_regular),
      ),
      matching: find.byType(IconButton),
    );
    final button = tester.widget<IconButton>(moreButton);
    expect(button.style?.foregroundColor?.resolve({}), const Color(0xadcbd5e1));
    final playNextIconTheme = tester.widget<IconTheme>(
      find
          .ancestor(
            of: find.descendant(
              of: tile,
              matching: find.byType(SmPlayerPlayNextIcon),
            ),
            matching: find.byType(IconTheme),
          )
          .first,
    );
    expect(playNextIconTheme.data.color, const Color(0xadcbd5e1));

    await tileMouse.moveTo(tester.getCenter(moreButton));
    await tester.pump();

    final hoveredButton = tester.widget<IconButton>(moreButton);
    expect(
      hoveredButton.style?.backgroundColor?.resolve({WidgetState.hovered}),
      const Color(0x17ffffff),
    );
    expect(
      hoveredButton.style?.foregroundColor?.resolve({WidgetState.hovered}),
      const Color(0xff459de2),
    );
    final moreIconTheme = tester.widget<IconTheme>(
      find
          .ancestor(
            of: find.descendant(
              of: tile,
              matching: find.byIcon(FluentIcons.more_horizontal_20_regular),
            ),
            matching: find.byType(IconTheme),
          )
          .first,
    );
    expect(moreIconTheme.data.color, const Color(0xff459de2));
  });

  testWidgets('RecentPage grid music unknown artist uses i18n', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final zhI18n = SmPlayerI18n(
      locale: 'zh-CN',
      messages: {...i18n.messages, 'common.artistUnknown': '未知歌手'},
    );

    await tester.pumpWidget(
      _RecentTestApp(snapshot: _snapshotWithUnknownRecentPlayed, i18n: zhI18n),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Played'));
    await tester.pumpAndSettle();

    expect(find.text('未知歌手'), findsOneWidget);
    expect(find.text('Unknown Artist'), findsNothing);
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
    expect(tester.getSize(find.widgetWithText(TextButton, 'Added')).height, 34);
    final playedTab = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Played'),
    );
    expect(
      playedTab.style!.backgroundColor!.resolve({}),
      const Color(0x80ffffff),
    );
    expect(
      playedTab.style!.backgroundColor!.resolve({WidgetState.hovered}),
      GlobalUI.hoverBgColorDay,
    );
    expect(
      playedTab.style!.foregroundColor!.resolve({WidgetState.hovered}),
      const Color(0xff0063b1),
    );
    final hoveredShape =
        playedTab.style!.shape!.resolve({WidgetState.hovered})!
            as RoundedRectangleBorder;
    expect(hoveredShape.side.color, GlobalUI.hoverBorderColorDay);

    await tester.tap(find.text('Played'));
    await tester.pumpAndSettle();

    expect(find.text('Songs'), findsOneWidget);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('Recent.FilterButton.songs')))
          .height,
      36,
    );

    final artistsFilter = find.byKey(
      const ValueKey('Recent.FilterButton.artists'),
    );
    final regularDecoration =
        tester.widget<Container>(artistsFilter).decoration as BoxDecoration;
    expect(regularDecoration.color, const Color(0x80ffffff));

    tester.binding.handlePointerEvent(
      PointerHoverEvent(
        kind: PointerDeviceKind.mouse,
        position: tester.getCenter(artistsFilter),
      ),
    );
    await tester.pump();

    final hoverDecoration =
        tester.widget<Container>(artistsFilter).decoration as BoxDecoration;
    expect(hoverDecoration.color, GlobalUI.hoverBgColorDay);
    expect(
      hoverDecoration.border,
      Border.all(color: GlobalUI.hoverBorderColorDay),
    );
  });

  testWidgets('RecentPage keeps Electron appbar tabs through minimal width', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(640, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(_RecentTestApp(snapshot: _snapshot, i18n: i18n));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('Recent.AppBarTabs')), findsOneWidget);
  });

  testWidgets('RecentPage nav-minimal song grid keeps Electron row extent', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(640, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _RecentTestApp(snapshot: _snapshotWithThreeRecentAdded, i18n: i18n),
    );
    await tester.pumpAndSettle();

    final firstTile =
        find
            .ancestor(
              of: find.text('First Song'),
              matching: find.byType(AnimatedContainer),
            )
            .first;
    final thirdTile =
        find
            .ancestor(
              of: find.text('Third Song'),
              matching: find.byType(AnimatedContainer),
            )
            .first;

    expect(tester.getSize(firstTile).height, 92);
    expect(
      tester.getTopLeft(thirdTile).dy - tester.getTopLeft(firstTile).dy,
      136,
    );
  });

  testWidgets('RecentPage nav-minimal song copy stretches like Electron tile', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(640, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _RecentTestApp(snapshot: _snapshotWithThreeRecentAdded, i18n: i18n),
    );
    await tester.pumpAndSettle();

    final firstTile =
        find
            .ancestor(
              of: find.text('First Song'),
              matching: find.byType(AnimatedContainer),
            )
            .first;
    final copyPadding =
        find
            .ancestor(
              of: find.text('First Song'),
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is Padding &&
                    widget.padding == const EdgeInsets.fromLTRB(0, 4, 0, 4),
              ),
            )
            .first;

    expect(tester.getSize(copyPadding).height, 92);
    expect(
      tester.getTopLeft(copyPadding).dy - tester.getTopLeft(firstTile).dy,
      0,
    );
  });

  testWidgets('RecentPage narrow window uses Electron media compact tile', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(500, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _RecentTestApp(snapshot: _snapshotWithThreeRecentAdded, i18n: i18n),
    );
    await tester.pumpAndSettle();

    final firstTile =
        find
            .ancestor(
              of: find.text('First Song'),
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is AnimatedContainer &&
                    widget.padding == EdgeInsets.zero,
              ),
            )
            .first;
    final secondTile =
        find
            .ancestor(
              of: find.text('Second Song'),
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is AnimatedContainer &&
                    widget.padding == EdgeInsets.zero,
              ),
            )
            .first;
    final firstTileWidget = tester.widget<AnimatedContainer>(firstTile);

    expect(tester.getSize(firstTile).height, 78);
    expect(firstTileWidget.padding, EdgeInsets.zero);
    expect(
      tester.getTopLeft(secondTile).dy - tester.getTopLeft(firstTile).dy,
      88,
    );
  });

  testWidgets('RecentPage narrow content keeps nav-minimal tile padding', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(640, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      Center(
        child: SizedBox(
          width: 500,
          child: _RecentTestApp(
            snapshot: _snapshotWithThreeRecentAdded,
            i18n: i18n,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final firstTile =
        find
            .ancestor(
              of: find.text('First Song'),
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is AnimatedContainer &&
                    widget.padding == EdgeInsets.zero,
              ),
            )
            .first;
    final secondTile =
        find
            .ancestor(
              of: find.text('Second Song'),
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is AnimatedContainer &&
                    widget.padding == EdgeInsets.zero,
              ),
            )
            .first;
    final firstTileWidget = tester.widget<AnimatedContainer>(firstTile);

    expect(tester.getSize(firstTile).height, 92);
    expect(firstTileWidget.padding, EdgeInsets.zero);
    expect(
      tester.getTopLeft(secondTile).dy - tester.getTopLeft(firstTile).dy,
      104,
    );
  });

  testWidgets('RecentPage narrow scrollbar sticks to the right edge', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(500, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _RecentTestApp(snapshot: _snapshotWithThreeRecentAdded, i18n: i18n),
    );
    await tester.pumpAndSettle();

    final firstTile =
        find
            .ancestor(
              of: find.text('First Song'),
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is AnimatedContainer &&
                    widget.padding == EdgeInsets.zero,
              ),
            )
            .first;
    final tileRect = tester.getRect(firstTile);
    final scrollbar = find.byType(Scrollbar);
    expect(scrollbar, findsOneWidget);
    final scrollbarRect = tester.getRect(scrollbar);

    expect(tileRect.left, 8);
    expect(500 - tileRect.right, 8);
    expect(scrollbarRect.right, 500);
  });

  testWidgets('RecentPage song group header keeps Electron height', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _RecentTestApp(snapshot: _snapshotWithRecentAddedMonths, i18n: i18n),
    );
    await tester.pumpAndSettle();

    final headerShell =
        find
            .ancestor(
              of: find.text('2025.01'),
              matching: find.byWidgetPredicate(
                (widget) => widget is SizedBox && widget.height == 36,
              ),
            )
            .first;
    expect(tester.getSize(headerShell).height, 36);
  });

  testWidgets('RecentPage resolves song artwork through repository batch', (
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
      _RecentTestApp(
        snapshot: _snapshotWithRecentAddedMonths,
        i18n: i18n,
        repository: repository,
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.artworkSnapshotRequests, [
      [41, 42],
    ]);
  });

  testWidgets('RecentPage recent added groups by Electron month buckets', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _RecentTestApp(snapshot: _snapshotWithRecentAddedMonths, i18n: i18n),
    );
    await tester.pumpAndSettle();

    expect(find.text('2025.01'), findsOneWidget);
    expect(find.text('2024.08'), findsOneWidget);
    expect(find.text('Last 7 days'), findsNothing);
  });

  testWidgets('RecentPage current song tile shows Electron playing wave', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final mediaController = MediaControlController();
    mediaController.playTrack(
      const MediaControlTrack(
        id: 1,
        title: 'Blue Song',
        artist: 'Artist A',
        artworkUrl: '',
        isLoading: false,
      ),
      durationSeconds: 120,
    );

    await tester.pumpWidget(
      _RecentTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        mediaController: mediaController,
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('RecentSong.Playing.1.Wave')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('RecentSong.Playing.1.Backdrop')),
      findsOneWidget,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('RecentSong.Playing.1.Wave'))),
      const Size(48, 48),
    );

    final firstHeight = _playingBarHeight(tester, 'RecentSong.Playing.1', 0);
    await tester.pump(const Duration(milliseconds: 390));

    expect(
      _playingBarHeight(tester, 'RecentSong.Playing.1', 0),
      isNot(firstHeight),
    );

    final songTile = find.ancestor(
      of: find.text('Blue Song').first,
      matching: find.byType(InkWell),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(songTile.first));
    addTearDown(mouse.removePointer);
    await tester.pump();

    expect(
      find.descendant(
        of: songTile.first,
        matching: find.byIcon(FluentIcons.add_20_regular),
      ),
      findsOneWidget,
    );
    expect(find.byType(SmPlayerPauseIcon), findsNothing);
  });
}

class _RecentTestApp extends StatelessWidget {
  const _RecentTestApp({
    required this.snapshot,
    required this.i18n,
    this.repository,
    this.mediaController,
    this.theme,
  });

  final LibraryContentData snapshot;
  final SmPlayerI18n i18n;
  final LibraryRepository? repository;
  final MediaControlController? mediaController;
  final ThemeData? theme;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        smPlayerI18nProvider.overrideWith((ref) async => i18n),
        recentPageDataProvider.overrideWith(
          (ref) async => _recentPageData(snapshot),
        ),
        libraryContentDataProvider.overrideWith((ref) async => snapshot),
        libraryRepositoryProvider.overrideWithValue(
          repository ?? _FakeLibraryRepository(),
        ),
        if (mediaController != null)
          mediaControlControllerProvider.overrideWith(
            (ref) => mediaController!,
          ),
      ],
      child: SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp(
          theme: theme ?? _recentPageTestTheme(),
          home: const Scaffold(body: RecentPage()),
        ),
      ),
    );
  }
}

double _playingBarHeight(WidgetTester tester, String keyPrefix, int index) {
  return tester.getSize(find.byKey(ValueKey('$keyPrefix.Bar.$index'))).height;
}

RecentPageData _recentPageData(LibraryContentData data) {
  return RecentPageData(
    songs: data.songs,
    recentSongs: data.recentSongs,
    recentPlaylists: data.recentPlaylists,
    recentAlbums: data.recentAlbums,
    recentArtists: data.recentArtists,
    recentSearches: data.recentSearches,
    playlists: data.playlists,
    favoritePlaylistId: data.favoritePlaylistId,
    nowPlaying: data.nowPlaying,
    showCount: data.showCount,
    hideMultiSelectCommandBarAfterOperation:
        data.hideMultiSelectCommandBarAfterOperation,
  );
}

class _RecentRouterTestApp extends StatelessWidget {
  const _RecentRouterTestApp({
    required this.router,
    required this.snapshot,
    required this.i18n,
    this.repository,
  });

  final GoRouter router;
  final LibraryContentData snapshot;
  final SmPlayerI18n i18n;
  final LibraryRepository? repository;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        smPlayerI18nProvider.overrideWith((ref) async => i18n),
        recentPageDataProvider.overrideWith(
          (ref) async => _recentPageData(snapshot),
        ),
        libraryContentDataProvider.overrideWith((ref) async => snapshot),
        libraryRepositoryProvider.overrideWithValue(
          repository ?? _FakeLibraryRepository(),
        ),
      ],
      child: SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp.router(
          theme: _recentPageTestTheme(),
          routerConfig: router,
        ),
      ),
    );
  }
}

ThemeData _recentPageTestTheme({Brightness brightness = Brightness.light}) {
  return buildSmPlayerTheme(
    const SettingsSnapshot.defaults().copyWith(
      nightMode:
          brightness == Brightness.dark ? NightMode.onMode : NightMode.never,
    ),
  );
}

class _FakeLibraryRepository extends LibraryRepository {
  List<int> replacedNowPlaying = [];
  bool clearedRecentSearches = false;
  List<int> removedRecentSearchIds = [];
  List<SearchHistoryEntry> restoredRecentSearches = [];
  List<int> removedRecentPlayedIds = [];
  List<int> restoredRecentPlayedIds = [];
  List<String> recordedAlbums = [];
  List<List<int>> artworkSnapshotRequests = [];
  Completer<void>? albumRecordCompleter;
  int? hiddenSongId;
  List<int> favoriteSongIds = [];
  bool? favoriteValue;

  @override
  Future<void> replaceNowPlaying(List<int> songIds) async {
    replacedNowPlaying = songIds.toList();
  }

  @override
  Future<void> setSongsFavorite(List<int> songIds, bool favorite) async {
    favoriteSongIds = songIds.toList();
    favoriteValue = favorite;
  }

  @override
  Future<String?> getPreferenceLevel(String type, String itemId) async {
    return null;
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
    artworkSnapshotRequests.add(songIds.toList());
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

const _snapshot = LibraryContentData(
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

const _snapshotWithSearches = LibraryContentData(
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

const _snapshotWithArtistSearch = LibraryContentData(
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

const _snapshotWithRecentPlayed = LibraryContentData(
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

const _snapshotWithRecentPlaylists = LibraryContentData(
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
  recentPlaylists: [
    RecentPlaylistPlayback(
      id: 1,
      playlistId: 10,
      playedAt: '2026-05-20T00:00:00',
    ),
  ],
  recentSearches: [],
  playlists: [
    LibraryPlaylist(
      id: 10,
      name: 'Mix',
      priority: 1,
      songCount: 1,
      songIds: [1],
      sortCriterion: PlaylistSortCriterion.title,
      isBuiltIn: false,
    ),
  ],
  favoritePlaylistId: 0,
  nowPlaying: NowPlayingSnapshot(playlistId: 0, songIds: []),
  hasLibrary: true,
  sortCriterion: MusicLibrarySortCriterion.title,
  albumsSort: AlbumSortCriterion.defaultSort,
  showCount: true,
  hideMultiSelectCommandBarAfterOperation: true,
  databasePath: '',
);

const _snapshotWithRecentAddedMonths = LibraryContentData(
  songs: [
    LibrarySong(
      id: 41,
      path: r'C:\Music\jazz2.mp3',
      title: '80s Piano Jazz 2',
      artist: 'Unknown Artist',
      artists: ['Unknown Artist'],
      album: 'Unknown Album',
      duration: 170,
      playCount: 0,
      lyricsOffsetMs: 0,
      dateAdded: '2025-01-09T08:10:10.000Z',
      favorite: false,
      thumbnailPath: '',
    ),
    LibrarySong(
      id: 42,
      path: r'C:\Music\acid2.mp3',
      title: '60s Acid Jazz 2',
      artist: 'Unknown Artist',
      artists: ['Unknown Artist'],
      album: 'Unknown Album',
      duration: 227,
      playCount: 0,
      lyricsOffsetMs: 0,
      dateAdded: '2024-08-18T06:51:51.766Z',
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

const _snapshotWithThreeRecentAdded = LibraryContentData(
  songs: [
    LibrarySong(
      id: 51,
      path: r'C:\Music\first.mp3',
      title: 'First Song',
      artist: 'Unknown Artist',
      artists: ['Unknown Artist'],
      album: 'Unknown Album',
      duration: 120,
      playCount: 0,
      lyricsOffsetMs: 0,
      dateAdded: '2025-01-09T08:10:10.000Z',
      favorite: false,
      thumbnailPath: '',
    ),
    LibrarySong(
      id: 52,
      path: r'C:\Music\second.mp3',
      title: 'Second Song',
      artist: 'Unknown Artist',
      artists: ['Unknown Artist'],
      album: 'Unknown Album',
      duration: 120,
      playCount: 0,
      lyricsOffsetMs: 0,
      dateAdded: '2025-01-09T08:10:09.000Z',
      favorite: false,
      thumbnailPath: '',
    ),
    LibrarySong(
      id: 53,
      path: r'C:\Music\third.mp3',
      title: 'Third Song',
      artist: 'Unknown Artist',
      artists: ['Unknown Artist'],
      album: 'Unknown Album',
      duration: 120,
      playCount: 0,
      lyricsOffsetMs: 0,
      dateAdded: '2025-01-09T08:10:08.000Z',
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

const _snapshotWithUnknownRecentPlayed = LibraryContentData(
  songs: [
    LibrarySong(
      id: 2,
      path: r'C:\Music\unknown.mp3',
      title: 'Unknown Artist Song',
      artist: '',
      artists: [],
      album: 'Unknown Hour',
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
      id: 2,
      path: r'C:\Music\unknown.mp3',
      title: 'Unknown Artist Song',
      artist: '',
      artists: [],
      album: 'Unknown Hour',
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

const _snapshotWithRecentAlbums = LibraryContentData(
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
