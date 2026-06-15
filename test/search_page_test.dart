import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:smplayer_flutter/src/app/app_appearance_model.dart';
import 'package:smplayer_flutter/src/app/app_interaction_colors.dart';
import 'package:smplayer_flutter/src/app/smplayer_vector_icons.dart';
import 'package:smplayer_flutter/src/app/text_icon_button.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
import 'package:smplayer_flutter/src/library/data/library_repository.dart';
import 'package:smplayer_flutter/src/library/ui/music_dialog.dart';
import 'package:smplayer_flutter/src/library/ui/page_selection_store.dart';
import 'package:smplayer_flutter/src/library/ui/search_page.dart';
import 'package:smplayer_flutter/src/library/ui/search_page_model.dart'
    as search_model;
import 'package:smplayer_flutter/src/playback/playlist_control_item.dart';
import 'package:smplayer_flutter/src/settings/settings_controller.dart';
import 'package:smplayer_flutter/src/settings/settings_model.dart'
    show
        AppSettingsUpdate,
        LyricsRequestMode,
        NightMode,
        SearchSortCriterion,
        SettingsSnapshot;

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
      'common.artistUnknown': 'Unknown Artist',
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
      'cards.albumSubtitle': '{tracks} by {artists}',
      'cards.artistCount': '{count} artists',
      'cards.songCount': '{count} songs',
      'cards.trackCount': '{count} tracks',
      'context.addToPlaylist': 'Add To',
      'context.play': 'Play',
      'context.seeAlbumArt': 'Album Art',
      'context.seeLyrics': 'Lyrics',
      'context.seeMusicInfo': 'Music Info',
      'context.select': 'Select',
      'context.view': 'View',
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
    resetSmPlayerGlobalSettingsSnapshot();
    PageSelectionController.clearStoredStates();
  });

  test('SearchPage model matches Electron unknown and split artist search', () {
    final results = search_model.buildSearchResults(
      [
        const LibrarySong(
          id: 101,
          path: r'C:\Music\unknown.mp3',
          title: 'Mystery Song',
          artist: '',
          artists: [],
          album: 'Mystery Album',
          duration: 120,
          playCount: 0,
          lyricsOffsetMs: 0,
          dateAdded: '2026-05-20T00:00:00',
          favorite: false,
          thumbnailPath: '',
        ),
        const LibrarySong(
          id: 102,
          path: r'C:\Music\split.mp3',
          title: 'Split Song',
          artist: 'Alpha; Beta',
          artists: [],
          album: 'Split Album',
          duration: 120,
          playCount: 0,
          lyricsOffsetMs: 0,
          dateAdded: '2026-05-20T00:00:00',
          favorite: false,
          thumbnailPath: '',
        ),
      ],
      const [],
      const [],
      r'C:\Music',
      'unknown',
      i18n,
    );

    expect(results.artists.single.title, 'Unknown Artist');
    expect(results.songs.single.title, 'Mystery Song');

    final splitResults = search_model.buildSearchResults(
      [
        const LibrarySong(
          id: 102,
          path: r'C:\Music\split.mp3',
          title: 'Split Song',
          artist: 'Alpha; Beta',
          artists: [],
          album: 'Split Album',
          duration: 120,
          playCount: 0,
          lyricsOffsetMs: 0,
          dateAdded: '2026-05-20T00:00:00',
          favorite: false,
          thumbnailPath: '',
        ),
      ],
      const [],
      const [],
      r'C:\Music',
      'beta',
      i18n,
    );

    expect(splitResults.artists.single.title, 'Beta');
    expect(splitResults.songs.single.title, 'Split Song');
  });

  test('SearchPage song artist sort matches Electron primary artist logic', () {
    final sorted = search_model.sortSearchSongs(const [
      LibrarySong(
        id: 201,
        path: r'C:\Music\alpha-zulu.mp3',
        title: 'Alpha Zulu',
        artist: 'Alpha',
        artists: ['Alpha', 'Zulu'],
        album: 'Sort Album',
        duration: 120,
        playCount: 10,
        lyricsOffsetMs: 0,
        dateAdded: '2026-05-20T00:00:00',
        favorite: false,
        thumbnailPath: '',
      ),
      LibrarySong(
        id: 202,
        path: r'C:\Music\alpha-beta.mp3',
        title: 'Alpha Beta',
        artist: 'Alpha',
        artists: ['Alpha', 'Beta'],
        album: 'Sort Album',
        duration: 120,
        playCount: 0,
        lyricsOffsetMs: 0,
        dateAdded: '2026-05-20T00:00:00',
        favorite: false,
        thumbnailPath: '',
      ),
    ], SearchSortCriterion.artist);

    expect(sorted.map((song) => song.id), [201, 202]);
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
    expect(repository.recordedSearches, isEmpty);
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

    await tester.tap(find.byIcon(FluentIcons.arrow_sort_20_regular));
    await tester.pumpAndSettle();

    expect(find.text('Default'), findsWidgets);
    expect(find.text('Title'), findsOneWidget);
  });

  testWidgets('SearchPage narrow content hugs the scrollbar symmetrically', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(760, 800);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    await tester.pumpWidget(
      _SearchPageTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: _FakeLibraryRepository(),
        child: const SearchPage(query: 'song', activeType: 'songs'),
      ),
    );
    await tester.pumpAndSettle();

    final sectionRect = tester.getRect(find.text('Songs 2'));
    final sortButtonRect = tester.getRect(
      find.ancestor(
        of: find.text('Default').first,
        matching: find.byType(SmPlayerTextIconButton),
      ),
    );

    expect(sectionRect.left, 14);
    expect(sortButtonRect.right, 752);
  });

  testWidgets('SearchPage filter tabs reuse recent played filter styling', (
    tester,
  ) async {
    await tester.pumpWidget(
      _SearchPageTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: _FakeLibraryRepository(),
        child: const SearchPage(query: 'song', activeType: null),
      ),
    );
    await tester.pumpAndSettle();

    final songsTabFinder = find.ancestor(
      of: find.text('Songs').first,
      matching: find.byType(TextButton),
    );
    final songsIconFinder = find.descendant(
      of: songsTabFinder,
      matching: find.byIcon(FluentIcons.music_note_2_20_regular),
    );
    final songsTab = tester.widget<TextButton>(songsTabFinder);
    final shape = songsTab.style!.shape!.resolve({})! as RoundedRectangleBorder;
    final hoveredShape =
        songsTab.style!.shape!.resolve({WidgetState.hovered})!
            as RoundedRectangleBorder;

    expect(tester.getSize(songsTabFinder).height, 36);
    expect(tester.getSize(songsTabFinder).width, greaterThanOrEqualTo(72));
    expect(shape.borderRadius, BorderRadius.circular(999));
    expect(
      songsTab.style!.backgroundColor!.resolve({}),
      const Color(0x80ffffff),
    );
    expect(
      songsTab.style!.backgroundColor!.resolve({WidgetState.hovered}),
      GlobalUI.hoverBgColorDay,
    );
    expect(
      songsTab.style!.foregroundColor!.resolve({WidgetState.hovered}),
      const Color(0xff0063b1),
    );
    expect(hoveredShape.side.color, GlobalUI.hoverBorderColorDay);
    expect(songsIconFinder, findsOneWidget);
    expect(
      tester.getCenter(songsIconFinder).dx,
      lessThan(tester.getCenter(find.text('Songs').first).dx),
    );
    expect(
      tester.widget<Text>(find.text('Songs').first).style?.fontWeight,
      FontWeight.w700,
    );
  });

  testWidgets('SearchPage song rows use Electron narrow queue columns', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(760, 800);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    await tester.pumpWidget(
      _SearchPageTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: _FakeLibraryRepository(),
        child: const SearchPage(query: 'song', activeType: 'songs'),
      ),
    );
    await tester.pumpAndSettle();

    final firstRow = find.byType(PlaylistControlItem).first;
    final firstRowDuration = find.descendant(
      of: firstRow,
      matching: find.byKey(const ValueKey('PlaylistControlItem.Duration')),
    );
    final firstRowActions = find.descendant(
      of: firstRow,
      matching: find.byKey(const ValueKey('PlaylistControlItem.Actions')),
    );
    expect(
      tester.widget<PlaylistControlItem>(firstRow).variant,
      PlaylistControlItemVariant.headeredPlaylist,
    );
    expect(tester.getSize(firstRowDuration).width, 20);
    expect(tester.getSize(find.text('2:00').first).height, lessThan(24));
    expect(firstRowActions, findsOneWidget);
    expect(
      find.descendant(
        of: firstRow,
        matching: find.byKey(
          const ValueKey('PlaylistControlItem.RemoveAction'),
        ),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: firstRow,
        matching: find.byType(SingleChildScrollView),
      ),
      findsNothing,
    );
    final playNextAction = find.descendant(
      of: firstRow,
      matching: find.byKey(
        const ValueKey('PlaylistControlItem.PlayNextAction'),
      ),
    );
    final moreAction = find.descendant(
      of: firstRow,
      matching: find.byKey(const ValueKey('PlaylistControlItem.MoreAction')),
    );
    expect(playNextAction, findsOneWidget);
    expect(moreAction, findsOneWidget);
    expect(
      tester
          .widget<AnimatedSlide>(
            find
                .ancestor(
                  of: playNextAction,
                  matching: find.byType(AnimatedSlide),
                )
                .first,
          )
          .offset,
      const Offset(0.36, 0),
    );
    expect(
      tester
          .widget<AnimatedOpacity>(
            find
                .ancestor(
                  of: playNextAction,
                  matching: find.byType(AnimatedOpacity),
                )
                .first,
          )
          .opacity,
      0,
    );

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(firstRow));
    addTearDown(mouse.removePointer);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 140));

    expect(firstRowDuration, findsNothing);
    expect(firstRowActions, findsOneWidget);
    expect(
      find.descendant(
        of: firstRow,
        matching: find.byKey(
          const ValueKey('PlaylistControlItem.PlayNextAction'),
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: firstRow,
        matching: find.byKey(const ValueKey('PlaylistControlItem.MoreAction')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: firstRow,
        matching: find.byKey(
          const ValueKey('PlaylistControlItem.RemoveAction'),
        ),
      ),
      findsNothing,
    );
    expect(
      tester
          .widget<AnimatedSlide>(
            find
                .ancestor(
                  of: playNextAction,
                  matching: find.byType(AnimatedSlide),
                )
                .first,
          )
          .offset,
      Offset.zero,
    );
    expect(
      tester
          .widget<AnimatedOpacity>(
            find
                .ancestor(
                  of: playNextAction,
                  matching: find.byType(AnimatedOpacity),
                )
                .first,
          )
          .opacity,
      1,
    );
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

  testWidgets(
    'SearchPage multi-select Play respects Electron hide preference',
    (tester) async {
      final repository = _FakeLibraryRepository();
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 800);
      addTearDown(() {
        tester.view.resetDevicePixelRatio();
        tester.view.resetPhysicalSize();
      });

      await tester.pumpWidget(
        _SearchPageTestApp(
          snapshot: _keepSelectionSnapshot,
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
      expect(find.text('1 selected'), findsOneWidget);

      await tester.tap(find.text('Play Selected'));
      await tester.pumpAndSettle();

      expect(repository.replacedNowPlaying, [1]);
      expect(find.text('1 selected'), findsOneWidget);
    },
  );

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

  testWidgets('SearchPage card context Add To uses Electron grouped add path', (
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
        child: const SearchPage(query: 'Artist A', activeType: 'artists'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Artist A'), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add To'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mix'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));

    expect(repository.addedSongGroups, hasLength(1));
    expect(repository.addedSongGroups.single.playlistId, 10);
    expect(repository.addedSongGroups.single.songIds, [1]);
    expect(repository.addedSingleSongs, isEmpty);
  });

  testWidgets('SearchPage song play queue follows Electron sorted results', (
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
        snapshot: _songSortQueueSnapshot,
        i18n: i18n,
        repository: repository,
        child: const SearchPage(query: 'Common', activeType: 'songs'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(FluentIcons.arrow_sort_20_regular));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Duration'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Beta Long'));
    await tester.pumpAndSettle();

    expect(repository.replacedNowPlaying, [2, 1]);
  });

  testWidgets('SearchPage playlist card play keeps Electron playlist order', (
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
        snapshot: _playlistOrderSnapshot,
        i18n: i18n,
        repository: repository,
        child: const SearchPage(query: 'road', activeType: 'playlists'),
      ),
    );
    await tester.pumpAndSettle();

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(find.text('Road Mix')));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(SmPlayerPlayIcon).last);
    await tester.pumpAndSettle();

    expect(repository.replacedNowPlaying, [2, 1]);
  });

  testWidgets('SearchPage folder result opens local folder without query', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/search',
      routes: [
        GoRoute(
          path: '/search',
          builder:
              (context, state) => const Material(
                child: SearchPage(query: 'child', activeType: 'folders'),
              ),
        ),
        GoRoute(
          path: '/local',
          builder: (context, state) => Text(state.uri.toString()),
        ),
      ],
    );

    await tester.pumpWidget(
      _SearchPageRouterTestApp(
        router: router,
        snapshot: _snapshot,
        i18n: i18n,
        repository: _FakeLibraryRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sub'));
    await tester.pumpAndSettle();

    expect(find.text('/local?path=Sub'), findsOneWidget);
    expect(find.textContaining('query=child'), findsNothing);
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

  testWidgets('SearchPage empty state uses Electron night colors', (
    tester,
  ) async {
    await tester.pumpWidget(
      _SearchPageTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: _FakeLibraryRepository(),
        themeMode: ThemeMode.dark,
        child: const SearchPage(query: 'zzzzzz', activeType: null),
      ),
    );
    await tester.pumpAndSettle();

    final decoratedBox = tester.widget<DecoratedBox>(
      find
          .ancestor(
            of: find.text('No results'),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    final decoration = decoratedBox.decoration as BoxDecoration;
    final text = tester.widget<Text>(find.text('No results'));

    expect(decoration.color, const Color(0x0cffffff));
    expect(decoration.border?.top.color, const Color(0x1fd6e0ec));
    expect(text.style?.color, const Color(0xeff6f9fc));
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

  testWidgets('SearchPage section actions use shared text icon buttons', (
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

    final buttons =
        tester
            .widgetList<SmPlayerTextIconButton>(
              find.byType(SmPlayerTextIconButton),
            )
            .toList();

    expect(buttons.map((button) => button.label), contains('View all'));
    expect(buttons.map((button) => button.label), contains('Default'));
    expect(buttons.every((button) => button.height == 40), isTrue);
    expect(buttons.every((button) => button.horizontalPadding == 14), isTrue);
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

  testWidgets('SearchPage filter changes do not record search history', (
    tester,
  ) async {
    final repository = _FakeLibraryRepository();

    await tester.pumpWidget(
      _SearchPageTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: repository,
        child: const SearchPage(query: 'road', activeType: 'songs'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      _SearchPageTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: repository,
        child: const SearchPage(query: 'road', activeType: 'artists'),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.recordedSearches, isEmpty);
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

  testWidgets(
    'SearchPage selection operations only use visible typed results',
    (tester) async {
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

      await tester.tap(
        find.text('Root Album').first,
        buttons: kSecondaryMouseButton,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select'));
      await tester.pumpAndSettle();

      expect(find.text('1 selected'), findsOneWidget);

      await tester.pumpWidget(
        _SearchPageTestApp(
          snapshot: _snapshot,
          i18n: i18n,
          repository: repository,
          child: const SearchPage(query: 'root', activeType: 'songs'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1 selected'), findsNothing);

      await tester.tap(find.text('Play Selected'));
      await tester.pumpAndSettle();

      expect(repository.replacedNowPlaying, isEmpty);
    },
  );

  testWidgets(
    'SearchPage context menu selection replaces only the Electron selection bucket',
    (tester) async {
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
          repository: _FakeLibraryRepository(),
          child: const SearchPage(query: 'album', activeType: null),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.text('Root Album').first,
        buttons: kSecondaryMouseButton,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select'));
      await tester.pumpAndSettle();

      expect(find.text('1 selected'), findsOneWidget);

      await tester.tap(find.text('Root Song'), buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select'));
      await tester.pumpAndSettle();

      expect(find.text('2 selected'), findsOneWidget);

      await tester.tap(find.text('Child Song'), buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select'));
      await tester.pumpAndSettle();

      expect(find.text('2 selected'), findsOneWidget);
    },
  );

  testWidgets('SearchPage song view menu opens MusicDialog', (tester) async {
    await tester.pumpWidget(
      _SearchPageTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: _FakeLibraryRepository(),
        child: const SearchPage(query: 'song', activeType: 'songs'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Root Song'), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('View'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Music Info'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(MusicDialog), findsOneWidget);
    final dialog = tester.widget<MusicDialog>(find.byType(MusicDialog));
    expect(dialog.song.id, 1);
    expect(dialog.initialMode, SongDialogMode.properties);
    expect(dialog.queueSongIds, [2, 1]);
  });
}

class _SearchPageRouterTestApp extends StatelessWidget {
  const _SearchPageRouterTestApp({
    required this.router,
    required this.snapshot,
    required this.i18n,
    required this.repository,
  });

  final GoRouter router;
  final LibraryContentData snapshot;
  final SmPlayerI18n i18n;
  final LibraryRepository repository;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        smPlayerI18nProvider.overrideWith((ref) async => i18n),
        libraryContentDataProvider.overrideWith((ref) async => snapshot),
        libraryRepositoryProvider.overrideWithValue(repository),
      ],
      child: SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp.router(
          theme: buildSmPlayerTheme(const SettingsSnapshot.defaults()),
          routerConfig: router,
          builder: (context, child) => Scaffold(body: child),
        ),
      ),
    );
  }
}

class _SearchPageTestApp extends StatelessWidget {
  const _SearchPageTestApp({
    required this.snapshot,
    required this.i18n,
    required this.repository,
    required this.child,
    this.themeMode = ThemeMode.light,
  });

  final LibraryContentData snapshot;
  final SmPlayerI18n i18n;
  final LibraryRepository repository;
  final Widget child;
  final ThemeMode themeMode;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        smPlayerI18nProvider.overrideWith((ref) async => i18n),
        libraryContentDataProvider.overrideWith((ref) async => snapshot),
        libraryRepositoryProvider.overrideWithValue(repository),
      ],
      child: SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp(
          theme: buildSmPlayerTheme(const SettingsSnapshot.defaults()),
          darkTheme: buildSmPlayerTheme(
            const SettingsSnapshot.defaults().copyWith(
              nightMode: NightMode.onMode,
            ),
          ),
          themeMode: themeMode,
          home: Scaffold(body: child),
        ),
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
  Future<SearchHistoryEntry?> addRecentSearch(
    String query, [
    SearchHistoryType type = SearchHistoryType.sidebar,
  ]) async {
    recordedSearches.add((query: query, type: type));
    return SearchHistoryEntry(
      id: recordedSearches.length,
      query: query,
      type: type,
      searchedAt: '2026-05-23T00:00:00.000Z',
    );
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
  Future<void> updateSettings(AppSettingsUpdate update) async {}

  @override
  Future<String?> getPreferenceLevel(String type, String itemId) async {
    return null;
  }

  @override
  Future<void> addPreferenceItem(
    String type,
    String itemId,
    String name,
    String level,
  ) async {}

  @override
  Future<void> removePreferenceItem(String type, String itemId) async {}

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

  @override
  Future<SongPropertiesSnapshot> getSongProperties(int songId) async {
    final song = _snapshot.songs.firstWhere((song) => song.id == songId);
    return SongPropertiesSnapshot(
      songId: song.id,
      path: song.path,
      title: song.title,
      subtitle: '',
      artist: song.artist,
      artists: song.artists,
      album: song.album,
      albumArtist: '',
      publisher: '',
      trackNumber: 0,
      year: 0,
      genre: '',
      composers: '',
      duration: song.duration,
      bitrate: 0,
      fileSize: 0,
      dateCreated: '2026-06-06T00:00:00Z',
      dateModified: '2026-06-06T00:00:00Z',
      fileType: 'MP3',
      playCount: song.playCount,
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
}

const _snapshot = LibraryContentData(
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

final _keepSelectionSnapshot = LibraryContentData(
  songs: _snapshot.songs,
  folders: _snapshot.folders,
  playlists: _snapshot.playlists,
  favoritePlaylistId: _snapshot.favoritePlaylistId,
  nowPlaying: _snapshot.nowPlaying,
  hasLibrary: _snapshot.hasLibrary,
  sortCriterion: _snapshot.sortCriterion,
  albumsSort: _snapshot.albumsSort,
  showCount: _snapshot.showCount,
  hideMultiSelectCommandBarAfterOperation: false,
  rootPath: _snapshot.rootPath,
  databasePath: _snapshot.databasePath,
);

final _artistPreviewSnapshot = LibraryContentData(
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

const _playlistOrderSnapshot = LibraryContentData(
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
  folders: [],
  playlists: [
    LibraryPlaylist(
      id: 10,
      name: 'Road Mix',
      priority: 1,
      songCount: 2,
      songIds: [2, 1],
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
  rootPath: r'C:\Music',
  databasePath: '',
);

const _songSortQueueSnapshot = LibraryContentData(
  songs: [
    LibrarySong(
      id: 1,
      path: r'C:\Music\alpha.mp3',
      title: 'Alpha Short',
      artist: 'Artist A',
      artists: ['Artist A'],
      album: 'Common Album',
      duration: 300,
      playCount: 0,
      lyricsOffsetMs: 0,
      dateAdded: '2026-05-20T00:00:00',
      favorite: false,
      thumbnailPath: '',
    ),
    LibrarySong(
      id: 2,
      path: r'C:\Music\beta.mp3',
      title: 'Beta Long',
      artist: 'Artist B',
      artists: ['Artist B'],
      album: 'Common Album',
      duration: 100,
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
