import 'dart:async';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show CacheExtentStyle;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:smplayer_flutter/src/app/app_interaction_colors.dart';
import 'package:smplayer_flutter/src/app/smplayer_vector_icons.dart';
import 'package:smplayer_flutter/src/app/undoable_notification.dart';
import 'package:smplayer_flutter/src/app/workspace_app_bar_portal.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
import 'package:smplayer_flutter/src/library/data/library_repository.dart';
import 'package:smplayer_flutter/src/library/ui/artwork_floating_action_button.dart';
import 'package:smplayer_flutter/src/library/ui/artists_page.dart';
import 'package:smplayer_flutter/src/library/ui/artists_page_model.dart'
    show
        ArtistGroup,
        ArtistSortCriterion,
        artistCountQuickJumpKeys,
        artistRowContentHeight,
        artistOverscanRows,
        artistQuickJumpKeys,
        artistQuickJumpKeysForSort,
        artistRowHeight,
        artistRowSpacing,
        buildAlbumGroups,
        buildArtistQuickJumpMap,
        buildArtistGroups,
        compareArtistText,
        formatDuration,
        getArtistAlbumVirtualWindow,
        getArtistCountQuickJumpBucket,
        getArtistQuickJumpBucket,
        searchArtists;
import 'package:smplayer_flutter/src/library/ui/command_bar.dart';
import 'package:smplayer_flutter/src/library/ui/default_album_artwork.dart';
import 'package:smplayer_flutter/src/library/ui/music_dialog.dart';
import 'package:smplayer_flutter/src/library/ui/page_search_history_panel.dart';
import 'package:smplayer_flutter/src/library/ui/page_selection_store.dart';
import 'package:smplayer_flutter/src/playback/media_control_model.dart'
    hide formatDuration;
import 'package:smplayer_flutter/src/playback/media_control_provider.dart';
import 'package:smplayer_flutter/src/playback/playlist_control_item.dart';
import 'package:smplayer_flutter/src/settings/settings_model.dart'
    show LyricsRequestMode;

Finder _artistsMasterSearchTextField() {
  return find.descendant(
    of: find.byKey(const ValueKey('Artists.MasterPanel')),
    matching: find.byType(TextField),
  );
}

void main() {
  setUp(PageSelectionController.clearStoredStates);

  const i18n = SmPlayerI18n(
    locale: 'en-US',
    messages: {
      'artists.albumSummary': '{songs} songs, {duration}',
      'artists.artistSummary': '{albums} albums, {songs} songs',
      'artists.emptyCopy': 'No artists yet.',
      'artists.locateArtist': 'Locate Artist',
      'artists.searchArtistsPlaceholder': 'Search artists',
      'artists.selectArtist': 'Select an artist',
      'artists.sort.albumCount': 'Album Count',
      'artists.sort.name': 'Name',
      'artists.sort.songCount': 'Song Count',
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
      'common.close': 'Close',
      'common.confirm': 'Confirm',
      'common.favorite': 'Favorite',
      'common.import': 'Import',
      'common.multiSelect': 'Multi Select',
      'common.myFavorites': 'My Favorites',
      'common.nowPlaying': 'Now Playing',
      'common.search': 'Search',
      'local.sortReverseList': 'Reverse List',
      'common.undo': 'Undo',
      'context.addToPlaylist': 'Add To',
      'context.deleteFromDisk': 'Delete From Disk',
      'context.deleteSongConfirm': 'Delete "{title}" from disk?',
      'context.pause': 'Pause',
      'context.play': 'Play',
      'context.playNext': 'Play Next',
      'context.seeAlbum': 'See Album',
      'context.seeAlbumArt': 'See Album Art',
      'context.seeArtist': 'See Artist',
      'context.seeLyrics': 'See Lyrics',
      'context.seeLocalFile': 'See In File Explorer',
      'context.seeMusicInfo': 'See Music Info',
      'context.select': 'Select',
      'context.view': 'View',
      'library.scanHelp': 'Scan music first.',
      'library.allArtists': 'Artists',
      'library.allArtistsWithCount': '{count} Artists',
      'library.tryAnotherSearch': 'Try another search.',
      'notification.playNext': '"{title}" will play next',
      'notification.deletedFromDisk': 'Deleted {title} from disk',
      'notification.songAddedTo': 'Added "{title}" to {target}',
      'nowPlaying.loading': 'Loading',
      'nowPlaying.noLyrics': 'No Lyrics',
      'nowPlaying.randomPlay': 'Shuffle',
      'player.more': 'More',
      'playlists.create': 'Create',
      'playlists.createNew': 'Create New Playlist',
      'playlists.delete': 'Delete',
      'playlists.namePlaceholder': 'Playlist name',
      'playlists.newName': 'New Playlist',
      'playlists.newPlaylist': 'New Playlist',
      'preferences.level.dislike': 'Dislike',
      'preferences.level.do-not-appear': 'Do Not Appear',
      'preferences.level.high': 'High',
      'preferences.level.higher': 'Higher',
      'preferences.level.normal': 'Normal',
      'preferences.level.very-high': 'Very High',
      'preferences.undoPrefer': 'Undo Prefer',
      'quickJump.disabled': 'No {target} has {basis} starting with {group}',
      'quickJump.enabled': 'Jump to {target} whose {basis} starts with {group}',
      'quickJump.letterGroup': '{key}',
      'quickJump.symbolGroup': 'numbers, symbols, or other characters',
      'settings.preferenceSettings': 'Preference Settings',
      'settings.save': 'Save',
      'sidebar.back': 'Back',
      'sidebar.recentSearches': 'Recent searches',
      'sidebar.removeRecentSearch': 'Remove {query}',
      'song.changeArtwork': 'Change Artwork',
      'song.noAlbumArt': 'No Album Art',
    },
  );
  final zhCnI18n = SmPlayerI18n(
    locale: 'zh-CN',
    messages: {
      ...i18n.messages,
      'artists.sort.albumCount': '专辑数量',
      'artists.sort.name': '名称',
      'artists.sort.songCount': '歌曲数量',
      'local.sortReverseList': '倒序排列',
    },
  );

  test('artist quick jump folds latin accents like Electron', () {
    expect(getArtistQuickJumpBucket('\u00c9clair'), 'E');
    expect(getArtistQuickJumpBucket('\u00e5ngstr\u00f6m'), 'A');
    expect(getArtistQuickJumpBucket('\u015aade'), 'S');
    expect(getArtistQuickJumpBucket('\u015eebnem'), 'S');
    expect(getArtistQuickJumpBucket('\u011eazapizm'), 'G');
    expect(getArtistQuickJumpBucket('\u0130stanbul'), 'I');
    expect(getArtistQuickJumpBucket('\u017dena'), 'Z');
  });

  test('artist quick jump buckets Chinese names like Electron pinyin', () {
    expect(getArtistQuickJumpBucket('\u9648\u5955\u8fc5'), 'C');
    expect(getArtistQuickJumpBucket('\u674e\u5b97\u76db'), 'L');
    expect(getArtistQuickJumpBucket('\u738b\u83f2'), 'W');
    expect(getArtistQuickJumpBucket('\u5468\u6770\u4f26'), 'Z');
    expect(getArtistQuickJumpBucket('\u957f\u6c5f'), 'Z');
  });

  test('artist count quick jump uses 1 through 20 and 20+', () {
    expect(
      artistQuickJumpKeysForSort(ArtistSortCriterion.name),
      artistQuickJumpKeys,
    );
    expect(
      artistQuickJumpKeysForSort(ArtistSortCriterion.songCount),
      artistCountQuickJumpKeys,
    );
    expect(
      artistQuickJumpKeysForSort(ArtistSortCriterion.albumCount),
      artistCountQuickJumpKeys,
    );
    expect(artistCountQuickJumpKeys.first, '1');
    expect(artistCountQuickJumpKeys[19], '20');
    expect(artistCountQuickJumpKeys.last, '20+');
    expect(getArtistCountQuickJumpBucket(20), '20');
    expect(getArtistCountQuickJumpBucket(21), '20+');

    final artists = [
      ArtistGroup(
        name: 'Overflow',
        songs: _countSongs(21),
        albumCount: 21,
        artworkSongId: 1,
      ),
      ArtistGroup(
        name: 'Twenty',
        songs: _countSongs(20),
        albumCount: 20,
        artworkSongId: 1,
      ),
      ArtistGroup(
        name: 'One',
        songs: _countSongs(1),
        albumCount: 1,
        artworkSongId: 1,
      ),
    ];
    expect(buildArtistQuickJumpMap(artists, ArtistSortCriterion.songCount), {
      '20+': 0,
      '20': 1,
      '1': 2,
    });
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

  test('searchArtists follows Electron score order', () {
    const artists = [
      ArtistGroup(name: 'blue', songs: [], albumCount: 0, artworkSongId: 0),
      ArtistGroup(name: 'My Blue', songs: [], albumCount: 0, artworkSongId: 0),
      ArtistGroup(name: 'Bluebird', songs: [], albumCount: 0, artworkSongId: 0),
      ArtistGroup(name: 'Blue', songs: [], albumCount: 0, artworkSongId: 0),
      ArtistGroup(name: 'Blu', songs: [], albumCount: 0, artworkSongId: 0),
      ArtistGroup(name: 'Other', songs: [], albumCount: 0, artworkSongId: 0),
    ];

    expect(searchArtists(artists, 'Blue').map((artist) => artist.name), [
      'Blue',
      'blue',
      'Bluebird',
      'My Blue',
      'Blu',
    ]);
  });

  test('buildArtistGroups picks Electron artwork song', () {
    final artistsWithArtwork = buildArtistGroups(_artistArtworkSongs, i18n);
    expect(artistsWithArtwork.single.artworkSongId, 2);

    final artistsWithUnknownAlbumArtwork = buildArtistGroups(
      _artistArtworkFallbackAlbumOrderSongs,
      i18n,
    );
    expect(artistsWithUnknownAlbumArtwork.single.artworkSongId, 8);

    final artistsWithoutArtwork = buildArtistGroups(
      _artistLatestFallbackSongs,
      i18n,
    );
    expect(artistsWithoutArtwork.single.artworkSongId, 4);

    final artistsWithoutArtworkTicks = buildArtistGroups(
      _artistLatestFallbackSongsWithDotNetTicks,
      i18n,
    );
    expect(artistsWithoutArtworkTicks.single.artworkSongId, 4);
  });

  test(
    'buildArtistGroups mirrors Electron multi-artist and unknown grouping',
    () {
      final artists = buildArtistGroups(_artistGroupingSongs, i18n);
      final songsByArtist = {
        for (final artist in artists)
          artist.name: artist.songs.map((song) => song.id).toList(),
      };

      expect(songsByArtist['Artist A'], [1]);
      expect(songsByArtist['Artist B'], [1]);
      expect(songsByArtist['Unknown Artist'], [2]);

      final dedupedArtists = buildArtistGroups(_artistFallbackDedupSongs, i18n);
      expect(dedupedArtists.map((artist) => artist.name), ['Artist A']);
      expect(dedupedArtists.single.songs.map((song) => song.id), [3]);
    },
  );

  test('buildArtistGroups keeps Electron raw album queue order', () {
    final artists = buildArtistGroups(_artistUnknownAlbumOrderSongs, i18n);

    expect(artists.single.songs.map((song) => song.id), [5, 6]);
  });

  test('buildAlbumGroups mirrors Electron fallback order and duration', () {
    final albums = buildAlbumGroups(_albumGroupingSongs, i18n);

    expect(albums.map((album) => album.name), [
      'Alpha',
      'Blue Hour',
      'Unknown Album',
    ]);
    expect(albums.map((album) => album.duration), [90, 240, 75]);
    expect(albums[1].songs.map((song) => song.id), [11, 12]);
  });

  test('getArtistAlbumVirtualWindow mirrors Electron overscan math', () {
    final window = getArtistAlbumVirtualWindow(
      List.filled(10, 182.0),
      900,
      300,
    );

    expect(window.startIndex, 3);
    expect(window.endIndex, 9);
    expect(window.topSpacerHeight, 546);
    expect(window.bottomSpacerHeight, 182);
  });

  test('artist master overscan mirrors Electron row window', () {
    expect(artistRowContentHeight, 64);
    expect(artistRowSpacing, 2);
    expect(artistOverscanRows, 10);
    expect(artistRowHeight * artistOverscanRows, 660);
  });

  testWidgets('ArtistsPage appbar search keeps Electron close behavior', (
    tester,
  ) async {
    await tester.pumpWidget(
      _ArtistsAppBarPortalTestApp(snapshot: _snapshot, i18n: i18n),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('Artists.AppBar.Search')));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Search artists'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, 'Alpha');
    await tester.pumpAndSettle();

    expect(find.byTooltip('Clear'), findsOneWidget);
    expect(find.byTooltip('Close'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsWidgets);
    expect(find.byTooltip('Close'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    expect(find.byKey(const ValueKey('Artists.AppBar.Search')), findsOneWidget);
  });

  testWidgets(
    'ArtistsPage appbar search history dismisses outside like Electron',
    (tester) async {
      await tester.pumpWidget(
        _ArtistsAppBarPortalTestApp(snapshot: _snapshot, i18n: i18n),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('Artists.AppBar.Search')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('PageSearchHistoryPanel.Item.Artist A')),
        findsOneWidget,
      );

      await tester.tapAt(const Offset(16, 220));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextField, 'Search artists'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('PageSearchHistoryPanel.Item.Artist A')),
        findsNothing,
      );
    },
  );

  testWidgets('ArtistsPage nav-minimal master matches Electron shell spacing', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _ArtistsAppBarPortalTestApp(snapshot: _snapshot, i18n: i18n),
    );
    await tester.pumpAndSettle();

    final masterPadding = tester.widget<Padding>(
      find.byKey(const ValueKey('Artists.MasterPanel.Padding')),
    );
    expect(masterPadding.padding, const EdgeInsets.fromLTRB(14, 8, 14, 26));

    final masterPanel = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('Artists.MasterPanel')),
    );
    final masterDecoration = masterPanel.decoration as BoxDecoration;
    expect(masterDecoration.border, isNull);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('Artists.MasterPanel')),
        matching: find.byType(TextField),
      ),
      findsNothing,
    );
  });

  testWidgets('ArtistsPage light master border matches Electron color', (
    tester,
  ) async {
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

    final masterPanel = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('Artists.MasterPanel')),
    );
    final masterDecoration = masterPanel.decoration as BoxDecoration;
    expect(
      masterDecoration.border,
      const Border(right: BorderSide(color: Color(0x2e566271))),
    );
  });

  testWidgets('ArtistsPage night nav-minimal master is Electron transparent', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _ArtistsAppBarPortalTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        brightness: Brightness.dark,
      ),
    );
    await tester.pumpAndSettle();

    final masterPanel = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('Artists.MasterPanel')),
    );
    final masterDecoration = masterPanel.decoration as BoxDecoration;
    expect(masterDecoration.color, Colors.transparent);
    expect(masterDecoration.border, isNull);
  });

  testWidgets('ArtistsPage appbar search mirrors Electron night focus style', (
    tester,
  ) async {
    await tester.pumpWidget(
      _ArtistsAppBarPortalTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        brightness: Brightness.dark,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('Artists.AppBar.Search')));
    await tester.pumpAndSettle();

    final fieldDecoration =
        tester
                .widget<DecoratedBox>(
                  find
                      .descendant(
                        of: find.byKey(
                          const ValueKey('Artists.AppBar.SearchField'),
                        ),
                        matching: find.byType(DecoratedBox),
                      )
                      .first,
                )
                .decoration
            as BoxDecoration;

    expect(fieldDecoration.color, const Color(0x240078d7));
    expect(fieldDecoration.border, Border.all(color: const Color(0x800078d7)));
    expect(fieldDecoration.boxShadow?.single.color, const Color(0x240078d7));
    expect(fieldDecoration.boxShadow?.single.spreadRadius, 3);

    final field = tester.widget<TextField>(find.byType(TextField).last);
    expect(field.style?.color, const Color(0xebffffff));
    expect(field.decoration?.hintStyle?.color, const Color(0xadcbd5e1));
  });

  testWidgets('ArtistsPage compact detail appbar uses Electron night header', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(640, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _ArtistsAppBarPortalTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        brightness: Brightness.dark,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Artist A').first);
    await tester.pumpAndSettle();

    final appBarHeaderShadow = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('Artists.DetailHeader.AppBarShadow')),
    );
    final decoration = appBarHeaderShadow.decoration as BoxDecoration;
    final gradient = decoration.gradient! as LinearGradient;
    expect(gradient.colors, const [Color(0xf70f1319), Color(0xe00f1319)]);
    expect(decoration.color, isNull);
    expect(decoration.boxShadow, const [
      BoxShadow(
        color: Color(0x29000000),
        offset: Offset(0, 12),
        blurRadius: 24,
      ),
    ]);

    final summary = tester.widget<Text>(
      find.byKey(const ValueKey('Artists.DetailHeader.Summary')),
    );
    expect(summary.style?.color, const Color(0xadcbd5e1));
  });

  testWidgets('ArtistsPage compact detail writes Electron appbar title', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(640, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _ArtistsAppBarPortalTestApp(snapshot: _snapshot, i18n: i18n),
    );
    await tester.pumpAndSettle();

    expect(find.text('APPBAR_TITLE:1 Artists'), findsOneWidget);

    await tester.tap(find.text('Artist A').first);
    await tester.pumpAndSettle();

    expect(find.text('APPBAR_TITLE:Artist A'), findsOneWidget);
    final searchButton = tester.widget<CommandBarButton>(
      find.byKey(const ValueKey('Artists.AppBar.Search')),
    );
    expect(searchButton.active, isFalse);
    final appBarHeaderShadow = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('Artists.DetailHeader.AppBarShadow')),
    );
    expect((appBarHeaderShadow.decoration as BoxDecoration).boxShadow, const [
      BoxShadow(
        color: Color(0x0a445870),
        offset: Offset(0, 12),
        blurRadius: 24,
      ),
    ]);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('Artists.DetailHeader.AppBarShadow')),
        matching: find.byKey(const ValueKey('Artists.DetailHeader.Back')),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('Artists.DetailHeader.AppBarShadow')),
        matching: find.byKey(
          const ValueKey('Artists.DetailHeader.BackReservedSpace'),
        ),
      ),
      findsNothing,
    );
  });

  testWidgets('ArtistsPage compact target route keeps Electron appbar title', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(640, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _ArtistsAppBarPortalTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        initialLocation: '/artists?artist=Artist%20A',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('APPBAR_TITLE:Artist A'), findsOneWidget);
    expect(find.text('APPBAR_BOTTOM:true'), findsOneWidget);
  });

  testWidgets('ArtistsPage compact appbar title follows artist route target', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _ArtistsAppBarPortalTestApp(
        snapshot: _twoArtistSnapshot,
        i18n: i18n,
        initialLocation: '/artists?artist=Artist%20A',
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('Artists.ArtistRow.Artist B')));
    await tester.pumpAndSettle();

    tester.view.physicalSize = const Size(640, 800);
    await tester.pumpAndSettle();

    expect(find.text('APPBAR_TITLE:Artist A'), findsOneWidget);
    expect(find.text('APPBAR_TITLE:Artist B'), findsNothing);
  });

  testWidgets(
    'ArtistsPage appbar search query keeps Electron toolbar icon color',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(640, 800);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        _ArtistsAppBarPortalTestApp(
          snapshot: _snapshot,
          i18n: i18n,
          initialLocation: '/artists?artist=Artist%20A',
        ),
      );
      await tester.pumpAndSettle();

      final searchButton = tester.widget<CommandBarButton>(
        find.byKey(const ValueKey('Artists.AppBar.Search')),
      );
      expect(searchButton.active, isFalse);
      expect(searchButton.activeSurface, isFalse);
    },
  );

  testWidgets(
    'ArtistsPage compact nav-minimal master matches Electron spacing',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(640, 800);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        _ArtistsAppBarPortalTestApp(snapshot: _snapshot, i18n: i18n),
      );
      await tester.pumpAndSettle();

      final masterPadding = tester.widget<Padding>(
        find.byKey(const ValueKey('Artists.CompactMaster.Padding')),
      );
      expect(masterPadding.padding, const EdgeInsets.symmetric(horizontal: 12));

      final quickJumpPadding = tester.widget<Padding>(
        find.byKey(const ValueKey('Artists.CompactQuickJump.Padding')),
      );
      expect(
        quickJumpPadding.padding,
        const EdgeInsets.only(top: 2, bottom: 20),
      );

      final artistRow = tester.widget<Container>(
        find.byKey(const ValueKey('Artists.ArtistRow.Decoration.Artist A')),
      );
      expect(
        artistRow.padding,
        const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      );
      final artworkRect = tester.getRect(
        find.byKey(const ValueKey('Artists.ArtworkShell.Artist A')),
      );
      final titleRect = tester.getRect(find.text('Artist A').first);
      expect(titleRect.left - artworkRect.right, 10);
      final compactList = tester.widget<ListView>(
        find.byKey(const ValueKey('Artists.CompactMaster.List')),
      );
      expect(compactList.clipBehavior, Clip.none);
    },
  );

  testWidgets('ArtistsPage loading state shows Electron progress strip', (
    tester,
  ) async {
    final loading = Completer<LibraryContentData>();
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      _ArtistsLoadingTestApp(snapshotFuture: loading.future, i18n: i18n),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('Artists.Progress')), findsOneWidget);
    expect(
      tester.getSemantics(find.byKey(const ValueKey('Artists.Progress'))),
      matchesSemantics(label: 'Loading'),
    );
    final progressThumb = tester.widget<ColoredBox>(
      find.byKey(const ValueKey('Artists.Progress.Thumb')),
    );
    expect(progressThumb.color, const Color(0xff0078d7));
    expect(
      find.byKey(const ValueKey('Artists.LoadingMaster.ListShell')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('Artists.LoadingMaster.List')),
      findsOneWidget,
    );
    final loadingProgressRect = tester.getRect(
      find.byKey(const ValueKey('Artists.Progress')),
    );
    final loadingListShellRect = tester.getRect(
      find.byKey(const ValueKey('Artists.LoadingMaster.ListShell')),
    );
    expect(loadingListShellRect.top - loadingProgressRect.bottom, 14);
    expect(find.byKey(const ValueKey('Artists.QuickJump.#')), findsOneWidget);
    final loadingQuickJump = tester.widget<TextButton>(
      find.byKey(const ValueKey('Artists.QuickJump.#')),
    );
    expect(loadingQuickJump.onPressed, isNull);
    expect(find.byKey(const ValueKey('Artists.DetailSurface')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('Artists.DetailLoadingState')),
      findsOneWidget,
    );
    final loadingStatePadding = tester.widget<Padding>(
      find.byKey(const ValueKey('Artists.DetailLoadingState.Padding')),
    );
    expect(
      loadingStatePadding.padding,
      const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    );
    final lightLoadingSurface = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('Artists.DetailLoadingState.Surface')),
    );
    final lightLoadingDecoration =
        lightLoadingSurface.decoration as BoxDecoration;
    expect(lightLoadingDecoration.color, isNull);
    expect(lightLoadingDecoration.border, isNull);
    final loadingSpinner = tester.widget<SizedBox>(
      find.byKey(const ValueKey('Artists.DetailLoadingSpinner')),
    );
    expect(loadingSpinner.width, 18);
    expect(loadingSpinner.height, 18);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    final loadingSpinnerRotation = tester.widget<RotationTransition>(
      find.byKey(const ValueKey('Artists.DetailLoadingSpinner.Rotation')),
    );
    expect(
      (loadingSpinnerRotation.turns as AnimationController).duration,
      const Duration(milliseconds: 720),
    );
    final loadingSpinnerPaint = tester.widget<CustomPaint>(
      find.byKey(const ValueKey('Artists.DetailLoadingSpinner.Paint')),
    );
    final loadingSpinnerPainter = loadingSpinnerPaint.painter as dynamic;
    expect(loadingSpinnerPainter.strokeWidth, 2);
    expect(loadingSpinnerPainter.trackColor, const Color(0x2e0078d7));
    expect(loadingSpinnerPainter.topColor, const Color(0xff0078d7));
    final loadingTitle = tester.widget<Text>(
      find.byKey(const ValueKey('Artists.DetailLoadingTitle')),
    );
    expect(loadingTitle.style?.fontSize, 26);
    final loadingRow = tester.getRect(
      find.byKey(const ValueKey('Artists.DetailLoadingState')),
    );
    final loadingSpinnerRect = tester.getRect(
      find.byKey(const ValueKey('Artists.DetailLoadingSpinner')),
    );
    final loadingTitleRect = tester.getRect(
      find.byKey(const ValueKey('Artists.DetailLoadingTitle')),
    );
    expect(loadingTitleRect.left - loadingSpinnerRect.right, 12);
    expect(loadingRow.height, loadingTitleRect.height);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    await tester.pumpWidget(
      _ArtistsLoadingTestApp(
        snapshotFuture: Completer<LibraryContentData>().future,
        i18n: i18n,
        brightness: Brightness.dark,
      ),
    );
    await tester.pump();

    final nightLoadingSurface = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('Artists.DetailLoadingState.Surface')),
    );
    final nightLoadingDecoration =
        nightLoadingSurface.decoration as BoxDecoration;
    expect(nightLoadingDecoration.color, const Color(0x0bffffff));
    expect(
      nightLoadingDecoration.border,
      Border.all(color: const Color(0x1fd6e0ec)),
    );
    semantics.dispose();
  });

  testWidgets(
    'ArtistsPage nav-minimal loading master matches Electron spacing',
    (tester) async {
      final loading = Completer<LibraryContentData>();

      await tester.pumpWidget(
        _ArtistsLoadingTestApp(
          snapshotFuture: loading.future,
          i18n: i18n,
          workspaceAppBar: true,
        ),
      );
      await tester.pump();

      final loadingPadding = tester.widget<Padding>(
        find.byKey(const ValueKey('Artists.LoadingMasterPanel.Padding')),
      );
      expect(loadingPadding.padding, const EdgeInsets.fromLTRB(14, 8, 14, 26));

      final loadingPanel = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey('Artists.LoadingMasterPanel')),
      );
      final loadingDecoration = loadingPanel.decoration as BoxDecoration;
      expect(loadingDecoration.border, isNull);
      expect(find.byKey(const ValueKey('Artists.Progress')), findsOneWidget);
      final loadingList = tester.widget<ListView>(
        find.byKey(const ValueKey('Artists.LoadingMaster.List')),
      );
      expect(loadingList.clipBehavior, Clip.none);
      expect(
        find.byKey(const ValueKey('Artists.LoadingMaster.ListShell')),
        findsOneWidget,
      );
      final loadingProgressRect = tester.getRect(
        find.byKey(const ValueKey('Artists.Progress')),
      );
      final loadingListShellRect = tester.getRect(
        find.byKey(const ValueKey('Artists.LoadingMaster.ListShell')),
      );
      expect(loadingListShellRect.top - loadingProgressRect.bottom, 0);
    },
  );

  testWidgets('ArtistsPage loading search only records history like Electron', (
    tester,
  ) async {
    final loading = Completer<LibraryContentData>();
    final repository = _FakeLibraryRepository();

    await tester.pumpWidget(
      _ArtistsLoadingTestApp(
        snapshotFuture: loading.future,
        i18n: i18n,
        repository: repository,
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), ' Loading Artist ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(repository.recordedSearches, [
      (query: 'Loading Artist', type: SearchHistoryType.artists),
    ]);
    expect(find.byKey(const ValueKey('Artists.Progress')), findsOneWidget);
  });

  testWidgets('ArtistsPage mounts Electron master and detail scrollbars', (
    tester,
  ) async {
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

    expect(
      find.byKey(const ValueKey('Artists.MasterScrollbar')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('Artists.DetailScrollbar')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('Artists.MasterScrollbar.Position')),
      findsOneWidget,
    );
    final listRect = tester.getRect(find.byType(Scrollable).at(1));
    final masterList = tester.widget<ListView>(
      find.byKey(const ValueKey('Artists.Master.List')),
    );
    expect(masterList.clipBehavior, Clip.none);
    final scrollbarRect = tester.getRect(
      find.byKey(const ValueKey('Artists.MasterScrollbar.Position')),
    );
    final masterRect = tester.getRect(
      find.byKey(const ValueKey('Artists.MasterPanel')),
    );
    expect(scrollbarRect.width, 9);
    expect(listRect.right, masterRect.right - 14);
    expect(scrollbarRect.right, listRect.right);
  });

  testWidgets('ArtistsPage master scrollbar drag scrolls artist list', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _ArtistsTestApp(snapshot: _manyArtistsSnapshot(), i18n: i18n),
    );
    await tester.pumpAndSettle();

    final list = find.byType(Scrollable).at(1);
    final before = tester.state<ScrollableState>(list).position.pixels;
    final thumb = find.byKey(const ValueKey('Artists.MasterScrollbar.Thumb'));
    final thumbRect = tester.getRect(thumb);
    final gesture = await tester.startGesture(thumbRect.center);
    await gesture.moveBy(const Offset(0, 40));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(
      tester.state<ScrollableState>(list).position.pixels,
      greaterThan(before),
    );
  });

  testWidgets('ArtistsPage master list uses Electron overscan cache', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _ArtistsTestApp(snapshot: _manyArtistsSnapshot(), i18n: i18n),
    );
    await tester.pumpAndSettle();

    final masterList = tester.widget<ListView>(
      find.byKey(const ValueKey('Artists.Master.List')),
    );
    expect(masterList.itemExtent, artistRowHeight);
    expect(masterList.scrollCacheExtent?.style, CacheExtentStyle.pixel);
    expect(
      masterList.scrollCacheExtent?.value,
      artistRowHeight * artistOverscanRows,
    );
  });

  testWidgets('ArtistsPage compact master list uses Electron overscan cache', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(640, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _ArtistsTestApp(snapshot: _manyArtistsSnapshot(), i18n: i18n),
    );
    await tester.pumpAndSettle();

    final compactList = tester.widget<ListView>(
      find.byKey(const ValueKey('Artists.CompactMaster.List')),
    );
    expect(compactList.itemExtent, artistRowHeight);
    expect(compactList.scrollCacheExtent?.style, CacheExtentStyle.pixel);
    expect(
      compactList.scrollCacheExtent?.value,
      artistRowHeight * artistOverscanRows,
    );
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('Artists.QuickJump.A'))).dx,
      lessThan(
        tester
            .getTopLeft(
              find.byKey(const ValueKey('Artists.CompactMaster.List')),
            )
            .dx,
      ),
    );
  });

  testWidgets('ArtistsPage detail scrollbar drag scrolls only artist detail', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _ArtistsTestApp(snapshot: _manyAlbumsSnapshot(), i18n: i18n),
    );
    await tester.pumpAndSettle();

    final masterScrollables = find.descendant(
      of: find.byKey(const ValueKey('Artists.MasterPanel')),
      matching: find.byType(Scrollable),
    );
    final detailScrollables = find.descendant(
      of: find.byKey(const ValueKey('Artists.DetailSurface')),
      matching: find.byType(Scrollable),
    );
    final masterScrollable = find.byWidget(
      masterScrollables
          .evaluate()
          .firstWhere(
            (element) =>
                tester.getRect(find.byWidget(element.widget)).height > 100,
          )
          .widget,
    );
    final detailScrollable = find.byWidget(
      detailScrollables
          .evaluate()
          .firstWhere(
            (element) =>
                tester
                    .state<ScrollableState>(find.byWidget(element.widget))
                    .position
                    .maxScrollExtent >
                0,
          )
          .widget,
    );
    final masterState = tester.state<ScrollableState>(masterScrollable);
    final detailState = tester.state<ScrollableState>(detailScrollable);
    final masterBefore = masterState.position.pixels;
    final detailBefore = detailState.position.pixels;
    expect(detailState.position.maxScrollExtent, greaterThan(0));

    final thumb = find.byKey(const ValueKey('Artists.DetailScrollbar.Thumb'));
    final gesture = await tester.startGesture(tester.getCenter(thumb));
    await gesture.moveBy(const Offset(0, 80));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(detailState.position.pixels, greaterThan(detailBefore));
    expect(masterState.position.pixels, masterBefore);
  });

  testWidgets('ArtistsPage detail hides native scrollbar like Electron', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _ArtistsTestApp(snapshot: _manyAlbumsSnapshot(), i18n: i18n),
    );
    await tester.pumpAndSettle();

    final detailSurface = find.byKey(const ValueKey('Artists.DetailSurface'));
    final detailScrollConfig = find.descendant(
      of: detailSurface,
      matching: find.byKey(const ValueKey('Artists.DetailScrollConfiguration')),
    );

    expect(detailScrollConfig, findsOneWidget);
    expect(
      find.descendant(
        of: detailSurface,
        matching: find.byKey(const ValueKey('Artists.DetailScrollbar')),
      ),
      findsOneWidget,
    );
  });

  testWidgets('ArtistsPage virtualizes artist album cards like Electron', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _ArtistsTestApp(snapshot: _manyAlbumsSnapshot(), i18n: i18n),
    );
    await tester.pumpAndSettle();

    final renderedAlbumSections = find.byWidgetPredicate(
      (widget) =>
          widget is DecoratedBox &&
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith(
            'Artists.AlbumSection.Album ',
          ),
    );
    final renderedAlbumSectionCount = renderedAlbumSections.evaluate().length;
    expect(renderedAlbumSectionCount, greaterThan(0));
    expect(renderedAlbumSectionCount, lessThan(20));
    expect(find.text('Album 19'), findsNothing);
  });

  testWidgets('ArtistsPage 860px detail and album layout match Electron', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(840, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(_ArtistsTestApp(snapshot: _snapshot, i18n: i18n));
    await tester.pumpAndSettle();

    final detailSurface = tester.widget<ColoredBox>(
      find.byKey(const ValueKey('Artists.DetailSurface')),
    );
    expect(detailSurface.color, const Color(0xf5f8fbfe));

    final headerPadding = tester.widget<Padding>(
      find.byKey(const ValueKey('Artists.DetailHeader.Padding')),
    );
    expect(headerPadding.padding, const EdgeInsets.all(18));

    final albumSectionPadding = tester.widget<SliverPadding>(
      find.byKey(const ValueKey('Artists.AlbumSection.Padding.Blue Hour')),
    );
    expect(
      albumSectionPadding.padding,
      const EdgeInsets.fromLTRB(18, 0, 18, 22),
    );
    final albumSectionClip = tester.widget<ClipRRect>(
      find.byKey(const ValueKey('Artists.AlbumSection.Clip.Blue Hour')),
    );
    expect(
      albumSectionClip.borderRadius,
      const BorderRadius.vertical(top: Radius.circular(10)),
    );
    expect(albumSectionClip.clipBehavior, Clip.hardEdge);
    final albumSectionShadow = tester.widget<DecoratedSliver>(
      find.byKey(const ValueKey('Artists.AlbumSection.Shadow.Blue Hour')),
    );
    final albumShadowDecoration =
        albumSectionShadow.decoration as BoxDecoration;
    expect(albumShadowDecoration.boxShadow, const [
      BoxShadow(
        color: Color(0x14445870),
        offset: Offset(0, 16),
        blurRadius: 38,
      ),
    ]);
    final albumListTopPadding = tester.widget<SizedBox>(
      find.byKey(const ValueKey('Artists.AlbumList.TopPadding')),
    );
    expect(albumListTopPadding.height, 22);
    final detailBottomPadding = tester.widget<SizedBox>(
      find.byKey(const ValueKey('Artists.Detail.BottomPadding')),
    );
    expect(detailBottomPadding.height, 18);

    final albumArtwork = tester.widget<SizedBox>(
      find.byKey(const ValueKey('Artists.AlbumArtwork.Blue Hour')),
    );
    expect(albumArtwork.width, 64);
    expect(albumArtwork.height, 64);
    final albumArtworkBackground = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('Artists.AlbumArtwork.Background.Blue Hour')),
    );
    expect(
      (albumArtworkBackground.decoration as BoxDecoration).color,
      const Color(0x24818b98),
    );

    final albumActions = tester.widget<SizedBox>(
      find.byKey(const ValueKey('Artists.AlbumActions.Blue Hour')),
    );
    expect(albumActions.width, 36);
    expect(
      tester
          .getSize(
            find.descendant(
              of: find.byKey(const ValueKey('artist-song-1')),
              matching: find.byKey(
                const ValueKey('PlaylistControlItem.Actions'),
              ),
            ),
          )
          .width,
      34,
    );
    expect(
      tester
          .getSize(
            find.descendant(
              of: find.byKey(const ValueKey('artist-song-1')),
              matching: find.byKey(
                const ValueKey('PlaylistControlItem.Duration'),
              ),
            ),
          )
          .width,
      20,
    );
    final narrowActionsRect = tester.getRect(
      find.descendant(
        of: find.byKey(const ValueKey('artist-song-1')),
        matching: find.byKey(const ValueKey('PlaylistControlItem.Actions')),
      ),
    );
    final narrowDurationRect = tester.getRect(
      find.descendant(
        of: find.byKey(const ValueKey('artist-song-1')),
        matching: find.byKey(const ValueKey('PlaylistControlItem.Duration')),
      ),
    );
    expect(narrowDurationRect.left - narrowActionsRect.right, 12);
  });

  testWidgets('ArtistsPage desktop detail bottom padding matches Electron', (
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

    final detailBottomPadding = tester.widget<SizedBox>(
      find.byKey(const ValueKey('Artists.Detail.BottomPadding')),
    );
    expect(detailBottomPadding.height, 30);
  });

  testWidgets('ArtistsPage scrollbar uses Electron night hover colors', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _ArtistsTestApp(
        snapshot: _manyArtistsSnapshot(),
        i18n: i18n,
        brightness: Brightness.dark,
      ),
    );
    await tester.pumpAndSettle();

    final thumb = find.byKey(const ValueKey('Artists.MasterScrollbar.Thumb'));
    BoxDecoration decoration() {
      return tester.widget<DecoratedBox>(thumb).decoration as BoxDecoration;
    }

    AnimatedOpacity opacity() {
      return tester.widget<AnimatedOpacity>(
        find.ancestor(of: thumb, matching: find.byType(AnimatedOpacity)).first,
      );
    }

    expect(opacity().opacity, 0);
    expect(decoration().color, const Color(0x7396a4b6));

    final scrollbarRegion = tester.widget<MouseRegion>(
      find.descendant(
        of: find.byKey(const ValueKey('Artists.MasterScrollbar')),
        matching: find.byType(MouseRegion),
      ),
    );
    scrollbarRegion.onEnter?.call(
      PointerEnterEvent(position: tester.getCenter(thumb)),
    );
    await tester.pump();

    expect(opacity().opacity, 1);
    expect(decoration().color, const Color(0x9ebccadc));
  });

  testWidgets('ArtistsPage night surfaces match Electron shell colors', (
    tester,
  ) async {
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
        brightness: Brightness.dark,
      ),
    );
    await tester.pumpAndSettle();

    final detailSurface = tester.widget<ColoredBox>(
      find.byKey(const ValueKey('Artists.DetailSurface')),
    );
    expect(detailSurface.color, const Color(0xff0f1318));

    final masterPanel = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('Artists.MasterPanel')),
    );
    final masterDecoration = masterPanel.decoration as BoxDecoration;
    expect(masterDecoration.color, const Color(0x06ffffff));
    expect(
      masterDecoration.border,
      const Border(right: BorderSide(color: Color(0x1fd6e0ec))),
    );

    final albumSection = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('Artists.AlbumSection.Blue Hour')),
    );
    final albumDecoration = albumSection.decoration as BoxDecoration;
    expect(albumDecoration.color, const Color(0xff171c22));
    expect(
      albumDecoration.border,
      const Border(
        top: BorderSide(color: Color(0x1fd6e0ec)),
        left: BorderSide(color: Color(0x1fd6e0ec)),
        right: BorderSide(color: Color(0x1fd6e0ec)),
      ),
    );
    final albumSectionShadow = tester.widget<DecoratedSliver>(
      find.byKey(const ValueKey('Artists.AlbumSection.Shadow.Blue Hour')),
    );
    final albumShadowDecoration =
        albumSectionShadow.decoration as BoxDecoration;
    expect(
      albumShadowDecoration.boxShadow?.single.color,
      const Color(0x33000000),
    );

    final albumArtworkBackground = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('Artists.AlbumArtwork.Background.Blue Hour')),
    );
    expect(
      (albumArtworkBackground.decoration as BoxDecoration).color,
      const Color(0x14ffffff),
    );
  });

  testWidgets('ArtistsPage night detail header matches Electron colors', (
    tester,
  ) async {
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
        brightness: Brightness.dark,
      ),
    );
    await tester.pumpAndSettle();

    final header = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('Artists.DetailHeader')),
    );
    final decoration = header.decoration as BoxDecoration;
    final gradient = decoration.gradient! as LinearGradient;
    expect(gradient.colors, const [Color(0xf70f1319), Color(0xe00f1319)]);
    expect(decoration.boxShadow?.single.color, const Color(0x29000000));
    expect(
      find.byKey(const ValueKey('Artists.DetailHeader.Blur')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('Artists.DetailHeader.Saturate120')),
      findsOneWidget,
    );

    final title = tester.widget<Text>(
      find.byKey(const ValueKey('Artists.DetailHeader.Title')),
    );
    expect(title.style?.color, const Color(0xf0f6f9fc));
    expect(title.style?.fontSize, 28);
    expect(title.style?.height, 1.2);
    expect(title.style?.fontWeight, FontWeight.w600);
    expect(title.style?.fontVariations, const [FontVariation.weight(650)]);
    expect(title.style?.letterSpacing, 0);

    final summary = tester.widget<Text>(
      find.byKey(const ValueKey('Artists.DetailHeader.Summary')),
    );
    expect(summary.style?.color, const Color(0xadcbd5e1));

    final albumTitleFinder = find.byKey(
      const ValueKey('Artists.AlbumTitle.Blue Hour'),
    );
    final albumTitle = tester.widget<Text>(albumTitleFinder);
    expect(albumTitle.style?.color, const Color(0xf0f6f9fc));

    final albumSummary = tester.widget<Text>(
      find.byKey(const ValueKey('Artists.AlbumSummary.Blue Hour')),
    );
    expect(albumSummary.style?.color, const Color(0xadcbd5e1));

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(albumTitleFinder));
    addTearDown(mouse.removePointer);
    await tester.pumpAndSettle();

    final hoveredAlbumTitle = tester.widget<Text>(albumTitleFinder);
    expect(hoveredAlbumTitle.style?.color, const Color(0xff459de2));

    final shuffle = tester.widget<IconButton>(
      find.byKey(const ValueKey('Artists.DetailHeader.Shuffle')),
    );
    expect(
      shuffle.style?.foregroundColor?.resolve({}),
      const Color(0xf0f6f9fc),
    );
    expect(
      shuffle.style?.backgroundColor?.resolve({WidgetState.hovered}),
      const Color(0x290078d7),
    );
    expect(
      shuffle.style?.foregroundColor?.resolve({WidgetState.hovered}),
      const Color(0xf0f6f9fc),
    );
    final shuffleRect = tester.getRect(
      find.byKey(const ValueKey('Artists.DetailHeader.Shuffle')),
    );
    final moreRect = tester.getRect(
      find.byKey(const ValueKey('Artists.DetailHeader.More')),
    );
    expect(moreRect.left - shuffleRect.right, 6);
    final albumShuffle = tester.widget<IconButton>(
      find.byKey(const ValueKey('Artists.AlbumShuffle.Blue Hour')),
    );
    expect(
      albumShuffle.style?.foregroundColor?.resolve({}),
      const Color(0xf0f6f9fc),
    );
    expect(
      albumShuffle.style?.foregroundColor?.resolve({WidgetState.hovered}),
      const Color(0xf0f6f9fc),
    );
    expect(
      albumShuffle.style?.backgroundColor?.resolve({WidgetState.hovered}),
      const Color(0x290078d7),
    );
  });

  testWidgets('ArtistsPage detail header keeps long title single-line', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(970, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    const longArtistName = 'distinctivecompactdiscs146';
    final snapshot = LibraryContentData(
      songs: [
        _snapshot.songs.first.copyWith(
          artist: longArtistName,
          artists: const [longArtistName],
        ),
      ],
      recentSongs: _snapshot.recentSongs,
      recentPlaylists: _snapshot.recentPlaylists,
      recentAlbums: _snapshot.recentAlbums,
      recentArtists: _snapshot.recentArtists,
      recentSearches: _snapshot.recentSearches,
      playlists: _snapshot.playlists,
      folders: _snapshot.folders,
      favoritePlaylistId: _snapshot.favoritePlaylistId,
      nowPlaying: _snapshot.nowPlaying,
      hasLibrary: _snapshot.hasLibrary,
      sortCriterion: _snapshot.sortCriterion,
      albumsSort: _snapshot.albumsSort,
      showCount: _snapshot.showCount,
      hideMultiSelectCommandBarAfterOperation:
          _snapshot.hideMultiSelectCommandBarAfterOperation,
      localViewMode: _snapshot.localViewMode,
      rootPath: _snapshot.rootPath,
      databasePath: _snapshot.databasePath,
    );

    await tester.pumpWidget(_ArtistsTestApp(snapshot: snapshot, i18n: i18n));
    await tester.pumpAndSettle();

    final title = tester.widget<Text>(
      find.byKey(const ValueKey('Artists.DetailHeader.Title')),
    );
    final summary = tester.widget<Text>(
      find.byKey(const ValueKey('Artists.DetailHeader.Summary')),
    );

    expect(title.maxLines, 1);
    expect(title.textScaler, TextScaler.noScaling);
    expect(summary.textScaler, TextScaler.noScaling);
  });

  testWidgets(
    'ArtistsPage light detail actions keep Electron hover icon color',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 800);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_ArtistsTestApp(snapshot: _snapshot, i18n: i18n));
      await tester.pumpAndSettle();

      final shuffle = tester.widget<IconButton>(
        find.byKey(const ValueKey('Artists.DetailHeader.Shuffle')),
      );
      expect(
        shuffle.style?.foregroundColor?.resolve({}),
        const Color(0xff1f252b),
      );
      expect(
        shuffle.style?.foregroundColor?.resolve({WidgetState.hovered}),
        const Color(0xff1f252b),
      );
      expect(
        shuffle.style?.backgroundColor?.resolve({WidgetState.hovered}),
        const Color(0x0f0c1623),
      );
      final albumShuffle = tester.widget<IconButton>(
        find.byKey(const ValueKey('Artists.AlbumShuffle.Blue Hour')),
      );
      expect(
        albumShuffle.style?.foregroundColor?.resolve({}),
        const Color(0xff1f252b),
      );
      expect(
        albumShuffle.style?.foregroundColor?.resolve({WidgetState.hovered}),
        const Color(0xff1f252b),
      );
      expect(
        albumShuffle.style?.backgroundColor?.resolve({WidgetState.hovered}),
        const Color(0x0f0c1623),
      );
    },
  );

  testWidgets('ArtistsPage light album title hover uses Electron accent', (
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

    final albumTitleFinder = find.byKey(
      const ValueKey('Artists.AlbumTitle.Blue Hour'),
    );
    expect(
      tester.widget<Text>(albumTitleFinder).style?.color,
      const Color(0xff1f252b),
    );
    final albumTitle = tester.widget<Text>(albumTitleFinder);
    expect(albumTitle.style?.fontSize, 18);
    expect(albumTitle.style?.fontWeight, FontWeight.w700);
    final albumTitleLink = tester.widget<InkWell>(
      find.ancestor(of: albumTitleFinder, matching: find.byType(InkWell)).first,
    );
    expect(
      albumTitleLink.overlayColor?.resolve({WidgetState.hovered}),
      Colors.transparent,
    );
    expect(albumTitleLink.splashFactory, NoSplash.splashFactory);
    final albumTitleRect = tester.getRect(albumTitleFinder);
    final albumSummaryRect = tester.getRect(
      find.byKey(const ValueKey('Artists.AlbumSummary.Blue Hour')),
    );
    expect(albumSummaryRect.top - albumTitleRect.bottom, 8);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(albumTitleFinder));
    addTearDown(mouse.removePointer);
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(albumTitleFinder).style?.color,
      const Color(0xff0063b1),
    );
  });

  testWidgets('ArtistsPage night quick jump matches Electron colors', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _ArtistsTestApp(
        snapshot: _manyArtistsSnapshot(),
        i18n: i18n,
        brightness: Brightness.dark,
      ),
    );
    await tester.pumpAndSettle();

    final activeA = tester.widget<TextButton>(
      find.byKey(const ValueKey('Artists.QuickJump.A')),
    );
    expect(
      activeA.style?.foregroundColor?.resolve({}),
      const Color(0xff459de2),
    );
    expect(
      activeA.style?.backgroundColor?.resolve({}),
      const Color(0x2e0078d7),
    );

    final enabledB = tester.widget<TextButton>(
      find.byKey(const ValueKey('Artists.QuickJump.B')),
    );
    expect(
      enabledB.style?.foregroundColor?.resolve({}),
      const Color(0xadcbd5e1),
    );
    expect(
      enabledB.style?.backgroundColor?.resolve({WidgetState.hovered}),
      const Color(0x2e0078d7),
    );
    expect(
      enabledB.style?.foregroundColor?.resolve({WidgetState.hovered}),
      const Color(0xff459de2),
    );

    final disabledZ = tester.widget<TextButton>(
      find.byKey(const ValueKey('Artists.QuickJump.Z')),
    );
    expect(
      disabledZ.style?.foregroundColor?.resolve({WidgetState.disabled}),
      const Color(0x40dee7f2),
    );
    expect(
      disabledZ.style?.backgroundColor?.resolve({WidgetState.disabled}),
      Colors.transparent,
    );
    final disabledZOpacity = tester.widget<Opacity>(
      find.byKey(const ValueKey('Artists.QuickJump.Opacity.Z')),
    );
    expect(disabledZOpacity.opacity, 0.62);
  });

  testWidgets(
    'ArtistsPage quick jump renders Electron keys and disabled state',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 800);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        _ArtistsTestApp(snapshot: _manyArtistsSnapshot(), i18n: i18n),
      );
      await tester.pumpAndSettle();

      expect(artistQuickJumpKeys.join(), '#ABCDEFGHIJKLMNOPQRSTUVWXYZ');
      for (final key in artistQuickJumpKeys) {
        expect(find.byKey(ValueKey('Artists.QuickJump.$key')), findsOneWidget);
      }
      expect(
        tester.getSize(find.byKey(const ValueKey('Artists.QuickJump.A'))).width,
        20,
      );
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('Artists.QuickJump.A'))).dx,
        lessThan(
          tester
              .getTopLeft(find.byKey(const ValueKey('Artists.Master.List')))
              .dx,
        ),
      );
      final masterRect = tester.getRect(
        find.byKey(const ValueKey('Artists.MasterPanel')),
      );
      final masterListRect = tester.getRect(
        find.byKey(const ValueKey('Artists.Master.List')),
      );
      expect(masterListRect.right, masterRect.right - 14);
      expect(
        tester
            .getRect(find.byKey(const ValueKey('Artists.QuickJump.Z')))
            .bottom,
        lessThanOrEqualTo(masterRect.bottom - 20),
      );

      final enabledA = tester.widget<TextButton>(
        find.byKey(const ValueKey('Artists.QuickJump.A')),
      );
      final enabledB = tester.widget<TextButton>(
        find.byKey(const ValueKey('Artists.QuickJump.B')),
      );
      final disabledZ = tester.widget<TextButton>(
        find.byKey(const ValueKey('Artists.QuickJump.Z')),
      );

      expect(enabledA.enabled, isTrue);
      expect(enabledB.enabled, isTrue);
      expect(disabledZ.enabled, isFalse);
      expect(
        tester
            .widget<Opacity>(
              find.byKey(const ValueKey('Artists.QuickJump.Opacity.A')),
            )
            .opacity,
        1,
      );
      expect(
        tester
            .widget<Opacity>(
              find.byKey(const ValueKey('Artists.QuickJump.Opacity.Z')),
            )
            .opacity,
        0.62,
      );
    },
  );

  testWidgets('ArtistsPage night artist rows match Electron colors', (
    tester,
  ) async {
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
        brightness: Brightness.dark,
      ),
    );
    await tester.pumpAndSettle();

    final activeTitle = tester
        .widgetList<Text>(find.text('Artist A'))
        .firstWhere((text) => text.style?.fontSize == 15);
    expect(activeTitle.style?.color, const Color(0xff459de2));

    final inactiveTitle = tester
        .widgetList<Text>(find.text('Artist B'))
        .firstWhere((text) => text.style?.fontSize == 15);
    expect(inactiveTitle.style?.color, const Color(0xf0f6f9fc));

    final activeSubtitle = tester
        .widgetList<Text>(find.text('1 albums, 1 songs'))
        .firstWhere((text) => text.style?.fontSize == 13);
    expect(activeSubtitle.style?.color, const Color(0xc276b5dc));

    final inactiveSubtitle = tester
        .widgetList<Text>(find.text('1 albums, 1 songs'))
        .lastWhere((text) => text.style?.fontSize == 13);
    expect(inactiveSubtitle.style?.color, const Color(0xadcbd5e1));

    final activeRowDecoration = tester.widget<Container>(
      find.byKey(const ValueKey('Artists.ArtistRow.Decoration.Artist A')),
    );
    final activeRowBoxDecoration =
        activeRowDecoration.decoration! as BoxDecoration;
    expect(activeRowBoxDecoration.color, GlobalUI.selectedBgColorNight);
    expect(
      activeRowBoxDecoration.border,
      Border.all(color: GlobalUI.selectedBorderColorNight),
    );
    expect(activeRowBoxDecoration.boxShadow, [GlobalUI.selectedShadowNight]);

    final rowInkWell = tester
        .widgetList<InkWell>(find.byType(InkWell))
        .firstWhere(
          (inkWell) =>
              inkWell.overlayColor?.resolve({WidgetState.hovered}) ==
              GlobalUI.hoverBgColorNight,
        );
    expect(
      rowInkWell.overlayColor?.resolve({WidgetState.focused}),
      GlobalUI.hoverBgColorNight,
    );

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is ColoredBox && widget.color == const Color(0xff1d4a70),
      ),
      findsAtLeastNWidgets(2),
    );

    final artworkDecoration = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('Artists.ArtworkDecoration.Artist A')),
    );
    final artworkBox = artworkDecoration.decoration as BoxDecoration;
    expect(artworkBox.boxShadow, const [
      BoxShadow(color: Color(0x4d000000), offset: Offset(0, 8), blurRadius: 18),
    ]);
  });

  testWidgets('ArtistsPage light artist rows match Electron colors', (
    tester,
  ) async {
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

    final activeTitle = tester
        .widgetList<Text>(find.text('Artist A'))
        .firstWhere((text) => text.style?.fontSize == 15);
    expect(activeTitle.style?.color, const Color(0xff0063b1));

    final activeSubtitle = tester
        .widgetList<Text>(find.text('1 albums, 1 songs'))
        .firstWhere((text) => text.style?.fontSize == 13);
    expect(activeSubtitle.style?.color, const Color(0xff0063b1));

    final activeRowMaterial = tester.widget<Material>(
      find
          .ancestor(
            of: find.byKey(
              const ValueKey('Artists.ArtistRow.Decoration.Artist A'),
            ),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(activeRowMaterial.color, Colors.transparent);
    final activeRowDecoration = tester.widget<Container>(
      find.byKey(const ValueKey('Artists.ArtistRow.Decoration.Artist A')),
    );
    final activeRowBoxDecoration =
        activeRowDecoration.decoration! as BoxDecoration;
    expect(activeRowBoxDecoration.color, GlobalUI.selectedBgColorDay);
    expect(
      activeRowBoxDecoration.border,
      Border.all(color: GlobalUI.selectedBorderColorDay),
    );
    expect(activeRowBoxDecoration.boxShadow, [GlobalUI.selectedShadowDay]);
    final artistARow = find.byKey(const ValueKey('Artists.ArtistRow.Artist A'));
    final artistBRow = find.byKey(const ValueKey('Artists.ArtistRow.Artist B'));
    expect(tester.getSize(artistARow).height, artistRowContentHeight);
    expect(
      tester.getTopLeft(artistBRow).dy - tester.getTopLeft(artistARow).dy,
      artistRowHeight,
    );
    final rowInkWell = tester
        .widgetList<InkWell>(find.byType(InkWell))
        .firstWhere(
          (inkWell) =>
              inkWell.overlayColor?.resolve({WidgetState.hovered}) ==
              GlobalUI.hoverBgColorDay,
        );
    expect(
      rowInkWell.overlayColor?.resolve({WidgetState.focused}),
      GlobalUI.hoverBgColorDay,
    );

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is ColoredBox && widget.color == const Color(0xb8ffffff),
      ),
      findsAtLeastNWidgets(2),
    );
    final artworkDecoration = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('Artists.ArtworkDecoration.Artist A')),
    );
    final artworkBox = artworkDecoration.decoration as BoxDecoration;
    expect(artworkBox.boxShadow, const [
      BoxShadow(color: Color(0x21202d3f), offset: Offset(0, 8), blurRadius: 18),
    ]);
  });

  testWidgets('ArtistsPage artist row opens with Electron keyboard actions', (
    tester,
  ) async {
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

    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('Artists.DetailHeader.Title')),
          )
          .data,
      'Artist A',
    );

    final artistBRow = tester.widget<InkWell>(
      find.byKey(const ValueKey('Artists.ArtistRow.Artist B')),
    );
    FocusScope.of(
      tester.element(find.byKey(const ValueKey('Artists.ArtistRow.Artist B'))),
    ).requestFocus(artistBRow.focusNode);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('Artists.DetailHeader.Title')),
          )
          .data,
      'Artist B',
    );

    final artistARow = tester.widget<InkWell>(
      find.byKey(const ValueKey('Artists.ArtistRow.Artist A')),
    );
    artistARow.focusNode!.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('Artists.DetailHeader.Title')),
          )
          .data,
      'Artist A',
    );
  });

  testWidgets('ArtistsPage artist row focus reveals Electron hover play', (
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
        snapshot: _twoArtistSnapshot,
        i18n: i18n,
        repository: repository,
        mediaController: mediaController,
      ),
    );
    await tester.pumpAndSettle();

    final opacityBefore = tester.widget<AnimatedOpacity>(
      find.byKey(const ValueKey('Artists.ArtworkPlay.Opacity.Artist B')),
    );
    expect(opacityBefore.opacity, 0);

    final artistBRow = tester.widget<InkWell>(
      find.byKey(const ValueKey('Artists.ArtistRow.Artist B')),
    );
    artistBRow.focusNode!.requestFocus();
    await tester.pumpAndSettle();

    final opacityAfter = tester.widget<AnimatedOpacity>(
      find.byKey(const ValueKey('Artists.ArtworkPlay.Opacity.Artist B')),
    );
    expect(opacityAfter.opacity, 1);
    final scaleBeforeHover = tester.widget<AnimatedScale>(
      find.byKey(const ValueKey('Artists.ArtworkPlay.Scale.Artist B')),
    );
    expect(scaleBeforeHover.scale, 1);
    expect(
      tester.widgetList<Tooltip>(find.byType(Tooltip)).map((tooltip) {
        return tooltip.message;
      }),
      contains('Shuffle'),
    );

    final playButton = find.byKey(
      const ValueKey('Artists.ArtworkPlay.Artist B'),
    );
    expect(tester.getSize(playButton), const Size(44, 44));
    expect(tester.widget<ArtworkFloatingActionButton>(playButton).size, 44);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(playButton));
    addTearDown(mouse.removePointer);
    await tester.pumpAndSettle();

    final scaleAfterHover = tester.widget<AnimatedScale>(
      find.byKey(const ValueKey('Artists.ArtworkPlay.Scale.Artist B')),
    );
    expect(scaleAfterHover.scale, 1.1);

    await tester.tap(playButton);
    await tester.pumpAndSettle();

    expect(repository.recordedArtists, ['Artist B']);
    expect(repository.replacedNowPlaying, [2]);
    expect(mediaController.state.track.id, 2);
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('Artists.DetailHeader.Title')),
          )
          .data,
      'Artist A',
    );
  });

  testWidgets('ArtistsPage artist row name has tooltip', (tester) async {
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

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('Artists.ArtistRow.Artist B')),
        matching: find.byTooltip('Artist B'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('ArtistsPage artist row context menu mirrors Electron scope', (
    tester,
  ) async {
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
        repository: _FakeLibraryRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('Artists.ArtistRow.Artist B')),
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();

    expect(find.text('Shuffle'), findsOneWidget);
    expect(find.text('Add To'), findsOneWidget);
    expect(find.text('Multi Select'), findsOneWidget);
    expect(find.text('Preference Settings'), findsOneWidget);
    expect(find.text('Locate Artist'), findsNothing);
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('Artists.DetailHeader.Title')),
          )
          .data,
      'Artist A',
    );
  });

  testWidgets('ArtistsPage night empty and song rows match Electron colors', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final mediaController = MediaControlController();
    await tester.pumpWidget(
      _ArtistsTestApp(
        snapshot: _emptyArtistsSnapshot,
        i18n: i18n,
        mediaController: mediaController,
        brightness: Brightness.dark,
      ),
    );
    await tester.pumpAndSettle();

    final emptyState = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('Artists.EmptyState')),
    );
    final emptyDecoration = emptyState.decoration as BoxDecoration;
    expect(emptyDecoration.color, const Color(0x0bffffff));
    expect(emptyDecoration.border, Border.all(color: const Color(0x1fd6e0ec)));
    expect(
      tester.widget<Text>(find.text('No artists')).style?.color,
      const Color(0xf0f6f9fc),
    );
    expect(
      tester.widget<Text>(find.text('No artists yet.')).style?.color,
      const Color(0xadcbd5e1),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    final playingMediaController = MediaControlController();
    playingMediaController.playTrack(
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
      _ArtistsTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        mediaController: playingMediaController,
        brightness: Brightness.dark,
      ),
    );
    await tester.pump();

    final songList = tester.widget(
      find.byKey(const ValueKey('Artists.SongList.Blue Hour')),
    );
    expect(songList.runtimeType.toString(), '_ArtistAlbumSongRowShell');
    expect(
      find.byKey(const ValueKey('Artists.SongList.Footer.Blue Hour')),
      findsNothing,
    );

    final songRow = tester.widget<PlaylistControlItem>(
      find.byKey(const ValueKey('artist-song-1')),
    );
    expect(songRow.variant, PlaylistControlItemVariant.compact);
    expect(songRow.colors?.border, Colors.transparent);
    expect(songRow.colors?.hover, GlobalUI.hoverBgColorNight);
    expect(songRow.colors?.hoverBorder, GlobalUI.hoverBorderColorNight);
    expect(songRow.colors?.current, GlobalUI.selectedBgColorNight);
    expect(songRow.colors?.currentForeground, const Color(0xff459de2));
    expect(songRow.colors?.textStrong, const Color(0xf0f6f9fc));
    expect(songRow.colors?.textMuted, const Color(0xadcbd5e1));
    expect(songRow.colors?.artworkBackground, const Color(0x14ffffff));
    expect(songRow.colors?.actionHover, const Color(0x2e0078d7));

    final songRowContainer = tester.widget<AnimatedContainer>(
      find
          .descendant(
            of: find.byKey(const ValueKey('artist-song-1')),
            matching: find.byType(AnimatedContainer),
          )
          .first,
    );
    final songRowDecoration = songRowContainer.decoration! as BoxDecoration;
    expect(songRowDecoration.color, Colors.transparent);

    final title = tester.widget<Text>(
      find.byKey(const ValueKey('PlaylistControlItem.Title')),
    );
    expect(title.style?.color, const Color(0xff459de2));
    expect(title.style?.fontSize, 16);
    expect(title.style?.fontVariations, const [FontVariation.weight(760)]);
    expect(title.style?.height, 1.3);
    expect(
      find.byKey(const ValueKey('PlaylistControlItem.Playing.Backdrop')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('PlaylistControlItem.Playing.Saturate150')),
      findsOneWidget,
    );

    final metadata = tester
        .widgetList<Text>(find.text('Artist A'))
        .firstWhere((text) => text.style?.fontSize == 13);
    expect(metadata.style?.color, const Color(0xc276b5dc));
  });

  testWidgets('ArtistsPage empty library keeps Electron no-artists copy', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _ArtistsTestApp(snapshot: _emptyArtistsSnapshot, i18n: i18n),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('Artists.MasterPanel')), findsOneWidget);
    expect(find.byKey(const ValueKey('Artists.Master.List')), findsOneWidget);
    expect(find.byKey(const ValueKey('Artists.DetailSurface')), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('Artists.QuickJump.A'))).dx,
      lessThan(
        tester.getTopLeft(find.byKey(const ValueKey('Artists.Master.List'))).dx,
      ),
    );
    expect(find.text('No artists'), findsOneWidget);
    expect(find.text('No artists yet.'), findsOneWidget);
    final emptyState = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('Artists.EmptyState')),
    );
    final emptyDecoration = emptyState.decoration as BoxDecoration;
    expect(emptyDecoration.color, isNull);
    expect(emptyDecoration.border, isNull);
    expect(emptyDecoration.boxShadow, isNull);

    await tester.enterText(find.byType(TextField), 'Missing');
    await tester.pumpAndSettle();

    expect(find.text('No artists'), findsOneWidget);
    expect(find.text('No artists yet.'), findsOneWidget);
    expect(find.text('Try another search.'), findsNothing);
  });

  testWidgets('ArtistsPage compact empty library shows no-artists copy', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(600, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _ArtistsTestApp(snapshot: _emptyArtistsSnapshot, i18n: i18n),
    );
    await tester.pumpAndSettle();

    expect(find.text('No artists'), findsOneWidget);
    expect(find.text('No artists yet.'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('Artists.CompactMaster.List')),
      findsNothing,
    );
  });

  testWidgets('ArtistsPage night suggestions match Electron colors', (
    tester,
  ) async {
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
        brightness: Brightness.dark,
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Art');
    await tester.pumpAndSettle();

    final panelGlass =
        tester
            .widgetList<GlassContainer>(
              find.descendant(
                of: find.byType(PageSearchSuggestionPanel),
                matching: find.byType(GlassContainer),
              ),
            )
            .single;
    expect(panelGlass.quality, GlassQuality.minimal);
    expect(panelGlass.settings?.blur, 46);
    expect(panelGlass.settings?.saturation, 1.65);
    expect(panelGlass.settings?.glassColor, const Color(0x7a181e26));
    expect(panelGlass.settings?.standardOpacityMultiplier, 0.32);

    final panelDecorations =
        tester
            .widgetList<DecoratedBox>(
              find.descendant(
                of: find.byType(PageSearchSuggestionPanel),
                matching: find.byType(DecoratedBox),
              ),
            )
            .map((box) => box.decoration)
            .whereType<BoxDecoration>();
    final panelDecoration = panelDecorations.firstWhere(
      (decoration) => decoration.border != null,
    );
    expect(panelDecoration.border, Border.all(color: const Color(0x38d6e0ec)));
    final panelShadowDecoration = panelDecorations.firstWhere(
      (decoration) => decoration.boxShadow != null,
    );
    expect(
      panelShadowDecoration.boxShadow?.single.color,
      const Color(0x42000000),
    );

    final suggestionText = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('PageSearchHistoryPanel.Item.Artist A')),
        matching: find.text('Artist A'),
      ),
    );
    expect(suggestionText.style?.color, const Color(0xebffffff));

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(
      location: tester.getCenter(
        find.byKey(const ValueKey('PageSearchHistoryPanel.Item.Artist A')),
      ),
    );
    await tester.pump(const Duration(milliseconds: 140));
    final hoveredSuggestion = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('PageSearchHistoryPanel.Item.Artist A')),
    );
    expect(
      (hoveredSuggestion.decoration! as BoxDecoration).color,
      const Color(0x290078d7),
    );
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

  testWidgets(
    'ArtistsPage Add To filters existing single-song playlists like Electron',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 800);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final snapshot = LibraryContentData(
        songs: _snapshot.songs,
        recentSongs: _snapshot.recentSongs,
        recentPlaylists: _snapshot.recentPlaylists,
        recentAlbums: _snapshot.recentAlbums,
        recentArtists: _snapshot.recentArtists,
        recentSearches: _snapshot.recentSearches,
        playlists: [
          LibraryPlaylist(
            id: 3,
            name: 'Built in',
            priority: 0,
            songCount: 1,
            songIds: [1],
            sortCriterion: PlaylistSortCriterion.title,
            isBuiltIn: true,
          ),
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
        favoritePlaylistId: 3,
        nowPlaying: NowPlayingSnapshot(playlistId: 0, songIds: []),
        hasLibrary: true,
        sortCriterion: MusicLibrarySortCriterion.title,
        albumsSort: AlbumSortCriterion.defaultSort,
        showCount: true,
        hideMultiSelectCommandBarAfterOperation: true,
        databasePath: '',
      );

      await tester.pumpWidget(
        _ArtistsTestApp(
          snapshot: snapshot,
          i18n: i18n,
          repository: _FakeLibraryRepository(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Blue Song'), buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add To'));
      await tester.pumpAndSettle();

      expect(find.text('Now Playing'), findsOneWidget);
      expect(find.text('My Favorites'), findsOneWidget);
      expect(find.text('New Playlist'), findsOneWidget);
      expect(find.text('Mix'), findsNothing);
      expect(find.text('Built in'), findsNothing);
    },
  );

  testWidgets(
    'ArtistsPage group Add To keeps partial playlists like Electron',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 800);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final snapshot = LibraryContentData(
        songs: _mixedFavoriteGroupSnapshot.songs,
        recentSongs: _mixedFavoriteGroupSnapshot.recentSongs,
        recentPlaylists: _mixedFavoriteGroupSnapshot.recentPlaylists,
        recentAlbums: _mixedFavoriteGroupSnapshot.recentAlbums,
        recentArtists: _mixedFavoriteGroupSnapshot.recentArtists,
        recentSearches: _mixedFavoriteGroupSnapshot.recentSearches,
        playlists: [
          LibraryPlaylist(
            id: 3,
            name: 'Built in',
            priority: 0,
            songCount: 1,
            songIds: [1],
            sortCriterion: PlaylistSortCriterion.title,
            isBuiltIn: true,
          ),
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
        favoritePlaylistId: 3,
        nowPlaying: NowPlayingSnapshot(playlistId: 0, songIds: [99]),
        hasLibrary: true,
        sortCriterion: MusicLibrarySortCriterion.title,
        albumsSort: AlbumSortCriterion.defaultSort,
        showCount: true,
        hideMultiSelectCommandBarAfterOperation: true,
        databasePath: '',
      );

      await tester.pumpWidget(
        _ArtistsTestApp(
          snapshot: snapshot,
          i18n: i18n,
          repository: _FakeLibraryRepository(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('Artists.DetailHeader.More')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add To'));
      await tester.pumpAndSettle();

      expect(find.text('Now Playing'), findsOneWidget);
      expect(find.text('My Favorites'), findsOneWidget);
      expect(find.text('New Playlist'), findsOneWidget);
      expect(find.text('Mix'), findsOneWidget);
      expect(find.text('Built in'), findsNothing);
    },
  );

  testWidgets('ArtistsPage song menu Favorites mirrors Electron undo', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final snapshot = ValueNotifier(_snapshot);
    addTearDown(snapshot.dispose);
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
    await tester.pumpAndSettle();

    await tester.tap(find.text('Blue Song'), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add To'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('My Favorites'));
    await tester.pumpAndSettle();

    expect(repository.favoriteSongIds, [1]);
    expect(repository.favoriteValue, isTrue);
    expect(find.text('Added "Blue Song" to My Favorites'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(repository.favoriteSongIds, [1]);
    expect(repository.favoriteValue, isFalse);
  });

  testWidgets('ArtistsPage song menu Now Playing mirrors Electron undo', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final snapshot = ValueNotifier(_snapshot);
    addTearDown(snapshot.dispose);
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
    await tester.pumpAndSettle();

    await tester.tap(find.text('Blue Song'), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add To'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Now Playing'));
    await tester.pumpAndSettle();

    expect(repository.replacedNowPlaying, [1]);
    expect(find.text('Added "Blue Song" to Now Playing'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(repository.replacedNowPlaying, []);
  });

  testWidgets('ArtistsPage song menu playlist add mirrors Electron undo', (
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

    await tester.tap(find.text('Blue Song'), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add To'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mix'));
    await tester.pumpAndSettle();

    expect(repository.addedPlaylistId, 10);
    expect(repository.addedSongIds, [1]);
    expect(find.text('Added "Blue Song" to Mix'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(repository.removedPlaylistId, 10);
    expect(repository.removedSongIds, [1]);
  });

  testWidgets(
    'ArtistsPage song menu New Playlist mirrors Electron text dialog',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 800);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final repository = _FakeLibraryRepository();

      await tester.pumpWidget(
        _ArtistsTestApp(
          snapshot: _snapshot,
          i18n: i18n,
          repository: repository,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Blue Song'), buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add To'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New Playlist'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).last, 'Mix');
      expect(find.text('Confirm'), findsOneWidget);
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(repository.createdPlaylistName, 'Mix');
      expect(repository.createdPlaylistSongIds, [1]);
    },
  );

  testWidgets('ArtistsPage song menu Select mirrors Electron selection', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _ArtistsTestApp(
        snapshot: _multiSongArtistSnapshot,
        i18n: i18n,
        repository: _FakeLibraryRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Blue Song 2'), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle();

    final selection = PageSelectionController<int>.stored('artists');
    expect(selection.multiSelect, isTrue);
    expect(selection.selectedItems, {2});
    expect(find.text('1 selected'), findsOneWidget);
  });

  testWidgets('ArtistsPage song menu Play moves to music like Electron', (
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
        snapshot: _multiSongArtistSnapshot,
        i18n: i18n,
        repository: repository,
        mediaController: mediaController,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Blue Song 2'), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Play'));
    await tester.pumpAndSettle();

    expect(repository.replacedNowPlaying, [2]);
    expect(mediaController.state.track.id, 2);
    expect(mediaController.state.selectedQueueIndex, 0);
  });

  testWidgets('ArtistsPage song menu Pause mirrors current Electron track', (
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
    mediaController.playTrack(
      const MediaControlTrack(
        id: 2,
        title: 'Blue Song 2',
        artist: 'Artist A',
        artworkUrl: '',
        isLoading: false,
      ),
      durationSeconds: 121,
    );

    await tester.pumpWidget(
      _ArtistsTestApp(
        snapshot: _multiSongArtistSnapshot,
        i18n: i18n,
        repository: repository,
        mediaController: mediaController,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Blue Song 2'), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();

    expect(find.text('Pause'), findsOneWidget);
    expect(find.text('Play Next'), findsNothing);

    await tester.tap(find.text('Pause'));
    await tester.pumpAndSettle();

    expect(mediaController.state.isPlaying, isFalse);
    expect(repository.replacedNowPlaying, isEmpty);
  });

  testWidgets('ArtistsPage song menu Play Next mirrors Electron undo', (
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
    mediaController.playTrack(
      const MediaControlTrack(
        id: 1,
        title: 'Blue Song 1',
        artist: 'Artist A',
        artworkUrl: '',
        isLoading: false,
      ),
      durationSeconds: 120,
    );
    final snapshot = LibraryContentData(
      songs: _multiSongArtistSnapshot.songs,
      recentSongs: _multiSongArtistSnapshot.recentSongs,
      recentPlaylists: _multiSongArtistSnapshot.recentPlaylists,
      recentAlbums: _multiSongArtistSnapshot.recentAlbums,
      recentArtists: _multiSongArtistSnapshot.recentArtists,
      recentSearches: _multiSongArtistSnapshot.recentSearches,
      playlists: _multiSongArtistSnapshot.playlists,
      favoritePlaylistId: _multiSongArtistSnapshot.favoritePlaylistId,
      nowPlaying: const NowPlayingSnapshot(playlistId: 0, songIds: [1, 2]),
      hasLibrary: _multiSongArtistSnapshot.hasLibrary,
      sortCriterion: _multiSongArtistSnapshot.sortCriterion,
      albumsSort: _multiSongArtistSnapshot.albumsSort,
      showCount: _multiSongArtistSnapshot.showCount,
      hideMultiSelectCommandBarAfterOperation:
          _multiSongArtistSnapshot.hideMultiSelectCommandBarAfterOperation,
      databasePath: _multiSongArtistSnapshot.databasePath,
    );

    await tester.pumpWidget(
      _ArtistsTestApp(
        snapshot: snapshot,
        i18n: i18n,
        repository: repository,
        mediaController: mediaController,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Blue Song 3'), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Play Next'));
    await tester.pumpAndSettle();

    expect(repository.replacedNowPlaying, [1, 3, 2]);
    expect(find.text('"Blue Song 3" will play next'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(repository.replacedNowPlaying, [1, 2]);
  });

  testWidgets('ArtistsPage song menu Delete mirrors Electron pending undo', (
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
      _ArtistsTestApp(
        snapshot: _multiSongArtistSnapshot,
        i18n: i18n,
        repository: repository,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Blue Song 2'), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete From Disk'));
    await tester.pumpAndSettle();

    expect(find.text('Delete "Blue Song 2" from disk?'), findsOneWidget);

    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();

    expect(repository.beganDeleteSongIds, [2]);
    expect(find.text('Deleted Blue Song 2 from disk'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(repository.undoneDeleteIds, ['pending-2']);
    expect(repository.committedDeleteIds, isEmpty);
  });

  testWidgets('ArtistsPage song menu Preference mirrors Electron writes', (
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
      _ArtistsTestApp(
        snapshot: _multiSongArtistSnapshot,
        i18n: i18n,
        repository: repository,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Blue Song 2'), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Preference Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Higher'));
    await tester.pumpAndSettle();

    expect(repository.preferenceType, 'song');
    expect(repository.preferenceItemId, '2');
    expect(repository.preferenceName, 'Blue Song 2');
    expect(repository.preferenceLevel, 'higher');

    repository.preferenceLevels[('song', '2')] = 'higher';

    await tester.tap(find.text('Blue Song 2'), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Preference Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Undo Prefer'), findsOneWidget);

    await tester.tap(find.text('Undo Prefer'));
    await tester.pumpAndSettle();

    expect(repository.removedPreferenceType, 'song');
    expect(repository.removedPreferenceItemId, '2');
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

    expect(find.byType(MusicDialog), findsOneWidget);
    final dialog = tester.widget<MusicDialog>(find.byType(MusicDialog));
    expect(dialog.song.id, 1);
    expect(dialog.initialMode, SongDialogMode.properties);
    expect(dialog.queueSongIds, [1]);
  });

  testWidgets('ArtistsPage song View See Artist routes like Electron', (
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
      _ArtistsRouterTestApp(
        snapshot: _multiSongArtistSnapshot,
        i18n: i18n,
        router: router,
        repository: _FakeLibraryRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Blue Song 2'), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('View'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('See Artist'));
    await tester.pumpAndSettle();

    final uri = router.routeInformationProvider.value.uri;
    expect(uri.path, '/artists');
    expect(uri.queryParameters['artist'], 'Artist A');
  });

  testWidgets('ArtistsPage song View See Lyrics opens lyrics mode', (
    tester,
  ) async {
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
    await tester.tap(find.text('See Lyrics'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('No Lyrics'), findsOneWidget);
    expect(find.text('Import'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
  });

  testWidgets('ArtistsPage song View See Album Art opens album art mode', (
    tester,
  ) async {
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
    await tester.tap(find.text('See Album Art'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('No Album Art'), findsOneWidget);
    expect(find.text('Change Artwork'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
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

    await tester.tap(
      find.byKey(const ValueKey('Artists.DetailHeader.Shuffle')),
    );
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
    expect(find.text('1 selected'), findsOneWidget);
    final selection = PageSelectionController<int>.stored('artists');
    expect(selection.multiSelect, isTrue);
    expect(selection.selectedItems, {1});

    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('ArtistsPage desktop defaults to first artist like Electron', (
    tester,
  ) async {
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

    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('Artists.DetailHeader.Title')),
          )
          .data,
      'Artist A',
    );
    expect(find.text('Blue Song'), findsOneWidget);
    expect(find.text('Green Song'), findsNothing);
  });

  testWidgets('ArtistsPage sort menu orders artists by counts and reverse', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _ArtistsTestApp(snapshot: _artistSortSnapshot, i18n: i18n),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .getTopLeft(find.byKey(const ValueKey('Artists.ArtistRow.Alpha')))
          .dy,
      lessThan(
        tester
            .getTopLeft(find.byKey(const ValueKey('Artists.ArtistRow.Beta')))
            .dy,
      ),
    );

    await tester.tap(find.byKey(const ValueKey('Artists.SortButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('artists-sort-song-count')));
    await tester.pumpAndSettle();

    expect(
      tester
          .getTopLeft(find.byKey(const ValueKey('Artists.ArtistRow.Beta')))
          .dy,
      lessThan(
        tester
            .getTopLeft(find.byKey(const ValueKey('Artists.ArtistRow.Alpha')))
            .dy,
      ),
    );

    await tester.tap(find.byKey(const ValueKey('Artists.SortButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('artists-sort-album-count')));
    await tester.pumpAndSettle();

    expect(
      tester
          .getTopLeft(find.byKey(const ValueKey('Artists.ArtistRow.Gamma')))
          .dy,
      lessThan(
        tester
            .getTopLeft(find.byKey(const ValueKey('Artists.ArtistRow.Beta')))
            .dy,
      ),
    );

    await tester.tap(find.byKey(const ValueKey('Artists.SortButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('artists-sort-reverse')));
    await tester.pumpAndSettle();

    expect(
      tester
          .getTopLeft(find.byKey(const ValueKey('Artists.ArtistRow.Alpha')))
          .dy,
      lessThan(
        tester
            .getTopLeft(find.byKey(const ValueKey('Artists.ArtistRow.Gamma')))
            .dy,
      ),
    );
  });

  testWidgets('ArtistsPage sort menu renders localized labels', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _ArtistsTestApp(snapshot: _artistSortSnapshot, i18n: zhCnI18n),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('Artists.SortButton')));
    await tester.pumpAndSettle();

    expect(find.text('倒序排列'), findsOneWidget);
    expect(find.text('名称'), findsOneWidget);
    expect(find.text('歌曲数量'), findsOneWidget);
    expect(find.text('专辑数量'), findsOneWidget);
    expect(find.text('artists.sort.songCount'), findsNothing);
    expect(find.text('artists.sort.albumCount'), findsNothing);
  });

  testWidgets('ArtistsPage count sort swaps quick jump to count keys', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _ArtistsTestApp(snapshot: _artistCountQuickJumpSnapshot(), i18n: i18n),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('Artists.QuickJump.A')), findsWidgets);
    expect(find.byKey(const ValueKey('Artists.QuickJump.20+')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('Artists.SortButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('artists-sort-song-count')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('Artists.QuickJump.A')), findsNothing);
    for (final key in artistCountQuickJumpKeys) {
      expect(find.byKey(ValueKey('Artists.QuickJump.$key')), findsOneWidget);
    }
    expect(
      tester
          .widget<TextButton>(
            find.byKey(const ValueKey('Artists.QuickJump.20+')),
          )
          .enabled,
      isTrue,
    );
    final overflowQuickJumpText = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('Artists.QuickJump.20+')),
        matching: find.text('20+'),
      ),
    );
    expect(overflowQuickJumpText.maxLines, 1);
    expect(overflowQuickJumpText.softWrap, isFalse);
    expect(
      find.ancestor(of: find.text('20+'), matching: find.byType(FittedBox)),
      findsOneWidget,
    );
    expect(
      tester
          .widget<TextButton>(
            find.byKey(const ValueKey('Artists.QuickJump.20')),
          )
          .enabled,
      isTrue,
    );
    expect(
      tester
          .widget<TextButton>(find.byKey(const ValueKey('Artists.QuickJump.2')))
          .enabled,
      isFalse,
    );

    await tester.tap(find.byKey(const ValueKey('Artists.SortButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('artists-sort-album-count')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('Artists.QuickJump.A')), findsNothing);
    expect(
      tester
          .widget<TextButton>(
            find.byKey(const ValueKey('Artists.QuickJump.20+')),
          )
          .enabled,
      isTrue,
    );
  });

  testWidgets(
    'ArtistsPage artist summaries use Electron album and song counts',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 800);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        _ArtistsTestApp(snapshot: _twoAlbumArtistSnapshot, i18n: i18n),
      );
      await tester.pumpAndSettle();

      expect(find.text('2 albums, 3 songs'), findsNWidgets(2));
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('Artists.DetailHeader.Summary')),
            )
            .data,
        '2 albums, 3 songs',
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('Artists.DetailHeader.Summary')),
            )
            .style
            ?.color,
        const Color(0xff111111),
      );
    },
  );

  testWidgets('ArtistsPage compact defaults to master list like Electron', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(640, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _ArtistsTestApp(snapshot: _twoArtistSnapshot, i18n: i18n),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('Artists.DetailHeader.Title')),
      findsNothing,
    );
    expect(find.text('Artist A'), findsWidgets);
    expect(find.text('Artist B'), findsWidgets);
    expect(find.text('Blue Song'), findsNothing);
    expect(find.text('Green Song'), findsNothing);
  });

  testWidgets('ArtistsPage uses Electron 720px compact breakpoint', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(720, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _ArtistsTestApp(snapshot: _twoArtistSnapshot, i18n: i18n),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('Artists.DetailHeader.Title')),
      findsNothing,
    );
    expect(find.text('Blue Song'), findsNothing);

    tester.view.physicalSize = const Size(721, 900);
    await tester.pumpWidget(
      _ArtistsTestApp(snapshot: _twoArtistSnapshot, i18n: i18n),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('Artists.DetailHeader.Title')),
          )
          .data,
      'Artist A',
    );
    expect(find.text('Blue Song'), findsOneWidget);
  });

  testWidgets('ArtistsPage create playlist defaults match Electron contexts', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    Future<void> pumpArtists() async {
      await tester.pumpWidget(
        _ArtistsTestApp(
          snapshot: _playlistNameCollisionSnapshot,
          i18n: i18n,
          repository: _FakeLibraryRepository(),
        ),
      );
      await tester.pumpAndSettle();
    }

    String dialogText() {
      return tester
          .widget<TextField>(find.byType(TextField).last)
          .controller!
          .text;
    }

    await pumpArtists();
    await tester.tap(find.byKey(const ValueKey('Artists.DetailHeader.More')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add To'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New Playlist'));
    await tester.pumpAndSettle();

    expect(dialogText(), 'Artist A');
    expect(find.text('Confirm'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    await pumpArtists();
    await tester.tap(find.text('Blue Song'), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add To'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New Playlist'));
    await tester.pumpAndSettle();

    expect(dialogText(), 'Blue Song');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    await pumpArtists();
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(
      location: tester.getCenter(find.byKey(const ValueKey('artist-song-1'))),
    );
    addTearDown(mouse.removePointer);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add To'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New Playlist'));
    await tester.pumpAndSettle();

    expect(dialogText(), 'Blue Song');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    await pumpArtists();
    await tester.tap(find.byKey(const ValueKey('Artists.DetailHeader.More')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Multi Select'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Blue Song'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add To'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New Playlist'));
    await tester.pumpAndSettle();

    expect(dialogText(), 'Artist A');
  });

  testWidgets(
    'ArtistsPage create playlist ignores built-in name collisions like Electron',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 800);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final repository = _FakeLibraryRepository();
      final snapshot = LibraryContentData(
        songs: _snapshot.songs,
        recentSongs: _snapshot.recentSongs,
        recentPlaylists: _snapshot.recentPlaylists,
        recentAlbums: _snapshot.recentAlbums,
        recentArtists: _snapshot.recentArtists,
        recentSearches: _snapshot.recentSearches,
        playlists: const [
          LibraryPlaylist(
            id: 3,
            name: 'Blue Song',
            priority: 0,
            songCount: 0,
            songIds: [],
            sortCriterion: PlaylistSortCriterion.title,
            isBuiltIn: true,
          ),
        ],
        favoritePlaylistId: _snapshot.favoritePlaylistId,
        nowPlaying: _snapshot.nowPlaying,
        hasLibrary: _snapshot.hasLibrary,
        sortCriterion: _snapshot.sortCriterion,
        albumsSort: _snapshot.albumsSort,
        showCount: _snapshot.showCount,
        hideMultiSelectCommandBarAfterOperation:
            _snapshot.hideMultiSelectCommandBarAfterOperation,
        databasePath: _snapshot.databasePath,
      );

      await tester.pumpWidget(
        _ArtistsTestApp(snapshot: snapshot, i18n: i18n, repository: repository),
      );
      await tester.pumpAndSettle();

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(
        location: tester.getCenter(find.byKey(const ValueKey('artist-song-1'))),
      );
      addTearDown(mouse.removePointer);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Add To'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New Playlist'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(repository.createdPlaylistName, 'Blue Song');
      expect(repository.createdPlaylistSongIds, [1]);
    },
  );

  testWidgets('ArtistsPage group Add To mirrors Electron undo and favorites', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final snapshot = ValueNotifier(_mixedFavoriteGroupSnapshot);
    addTearDown(snapshot.dispose);
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
    router.go('/artists?artist=Artist%20A');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('Artists.DetailHeader.More')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add To'));
    await tester.pumpAndSettle();

    expect(find.text('Now Playing'), findsOneWidget);
    expect(find.text('My Favorites'), findsOneWidget);

    await tester.tap(find.text('Now Playing'));
    await tester.pumpAndSettle();

    expect(repository.replacedNowPlaying, [99, 1, 2]);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(repository.replacedNowPlaying, [99]);

    await tester.tap(find.byKey(const ValueKey('Artists.DetailHeader.More')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add To'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('My Favorites'));
    await tester.pumpAndSettle();

    expect(repository.favoriteSongIds, [2]);
    expect(repository.favoriteValue, isTrue);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(repository.favoriteSongIds, [2]);
    expect(repository.favoriteValue, isFalse);

    await tester.tap(find.byKey(const ValueKey('Artists.DetailHeader.More')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add To'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mix'));
    await tester.pumpAndSettle();

    expect(repository.addedPlaylistId, 10);
    expect(repository.addedSongIds, [1, 2]);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(repository.removedPlaylistId, 10);
    expect(repository.removedSongIds, [1, 2]);

    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('ArtistsPage group menu order matches Electron', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _ArtistsTestApp(
        snapshot: _mixedFavoriteGroupSnapshot,
        i18n: i18n,
        repository: _FakeLibraryRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('Artists.DetailHeader.More')));
    await tester.pumpAndSettle();

    final artistMenuLabels = [
      'Shuffle',
      'Add To',
      'Multi Select',
      'Preference Settings',
      'Locate Artist',
    ];
    final artistMenuTops =
        artistMenuLabels
            .map((label) => tester.getTopLeft(find.text(label)).dy)
            .toList();

    expect(artistMenuTops, orderedEquals(artistMenuTops.toList()..sort()));

    await tester.tapAt(Offset.zero);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('Artists.AlbumHeader.Padding.Blue Hour')),
        matching: find.byTooltip('More'),
      ),
    );
    await tester.pumpAndSettle();

    final albumMenuLabels = [
      'Shuffle',
      'Add To',
      'Select',
      'Preference Settings',
      'See Album',
    ];
    final albumMenuTops =
        albumMenuLabels
            .map((label) => tester.getTopLeft(find.text(label)).dy)
            .toList();

    expect(albumMenuTops, orderedEquals(albumMenuTops.toList()..sort()));
  });

  testWidgets(
    'ArtistsPage group Add To hides favorites when all are favorite',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 800);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        _ArtistsTestApp(
          snapshot: _allFavoriteGroupSnapshot,
          i18n: i18n,
          repository: _FakeLibraryRepository(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('Artists.DetailHeader.More')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add To'));
      await tester.pumpAndSettle();

      expect(find.text('Now Playing'), findsOneWidget);
      expect(find.text('My Favorites'), findsNothing);
      expect(find.text('New Playlist'), findsOneWidget);
    },
  );

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
    'ArtistsPage Play Selected hides multi-select when Electron setting is on',
    (tester) async {
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

      await tester.tap(find.byTooltip('More').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Multi Select'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Blue Song'));
      await tester.pumpAndSettle();
      expect(find.text('1 selected'), findsOneWidget);

      await tester.tap(find.text('Play Selected'));
      await tester.pump(const Duration(milliseconds: 220));

      expect(repository.replacedNowPlaying, [1]);
      expect(find.text('1 selected'), findsNothing);
      final selection = PageSelectionController<int>.stored('artists');
      expect(selection.multiSelect, isFalse);
      expect(selection.selectedItems, isEmpty);
    },
  );

  testWidgets(
    'ArtistsPage multi-select bar mirrors Electron selection actions',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1800, 800);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final repository = _FakeLibraryRepository();
      final mediaController = MediaControlController();

      await tester.pumpWidget(
        _ArtistsTestApp(
          snapshot: _multiSongArtistSnapshot,
          i18n: i18n,
          repository: repository,
          mediaController: mediaController,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('Artists.DetailHeader.More')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Multi Select'));
      await tester.pumpAndSettle();

      var selection = PageSelectionController<int>.stored('artists');
      expect(selection.multiSelect, isTrue);
      expect(selection.selectedItems, isEmpty);

      await tester.tap(find.text('Select All'));
      await tester.pumpAndSettle();

      expect(find.text('3 selected'), findsOneWidget);
      selection = PageSelectionController<int>.stored('artists');
      expect(selection.selectedItems, {1, 2, 3});

      await tester.tap(find.text('Reverse Selection'));
      await tester.pumpAndSettle();

      expect(find.text('3 selected'), findsNothing);
      selection = PageSelectionController<int>.stored('artists');
      expect(selection.multiSelect, isTrue);
      expect(selection.selectedItems, isEmpty);

      await tester.tap(find.text('Select All'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear Selection'));
      await tester.pumpAndSettle();

      selection = PageSelectionController<int>.stored('artists');
      expect(selection.multiSelect, isTrue);
      expect(selection.selectedItems, isEmpty);
      expect(find.text('Select All'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      selection = PageSelectionController<int>.stored('artists');
      expect(selection.multiSelect, isFalse);
      expect(selection.selectedItems, isEmpty);
      expect(find.text('Select All'), findsOneWidget);
      expect(
        _hasHiddenCommandBarAncestor(tester, find.text('Select All')),
        isTrue,
      );

      await tester.tap(find.byKey(const ValueKey('Artists.DetailHeader.More')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Multi Select'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select All'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Play Selected'));
      await tester.pump(const Duration(milliseconds: 220));

      expect(repository.replacedNowPlaying, [1, 2, 3]);
      expect(mediaController.state.track.id, 1);
      expect(mediaController.state.selectedQueueIndex, 0);
    },
  );

  testWidgets(
    'ArtistsPage multi-select play starts from first effective song',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1800, 800);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final repository = _FakeLibraryRepository();
      final mediaController = MediaControlController();

      await tester.pumpWidget(
        _ArtistsTestApp(
          snapshot: _multiSongArtistSnapshot,
          i18n: i18n,
          repository: repository,
          mediaController: mediaController,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('Artists.DetailHeader.More')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Multi Select'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Blue Song 2'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Blue Song 3'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Play Selected'));
      await tester.pumpAndSettle();

      expect(repository.replacedNowPlaying, [2, 3]);
      expect(mediaController.state.track.id, 2);
      expect(mediaController.state.selectedQueueIndex, 0);
    },
  );

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

  testWidgets(
    'ArtistsPage artist group menu shuffle records artist like Electron',
    (tester) async {
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
          snapshot: _twoAlbumArtistSnapshot,
          i18n: i18n,
          repository: repository,
          mediaController: mediaController,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('Artists.DetailHeader.More')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Shuffle'));
      await tester.pumpAndSettle();

      expect(repository.recordedArtists, ['Artist A']);
      expect(repository.recordedAlbums, isEmpty);
      expect(repository.replacedNowPlaying, unorderedEquals([1, 2, 3]));
      expect(mediaController.state.track.id, isIn([1, 2, 3]));
    },
  );

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

  testWidgets('ArtistsPage artist group menu can undo Electron preference', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final repository =
        _FakeLibraryRepository()
          ..preferenceLevels[('artist', 'Artist A')] = 'high';

    await tester.pumpWidget(
      _ArtistsTestApp(snapshot: _snapshot, i18n: i18n, repository: repository),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('More').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Preference Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Undo Prefer'), findsOneWidget);
    expect(find.byIcon(FluentIcons.checkmark_20_regular), findsOneWidget);

    await tester.tap(find.text('Undo Prefer'));
    await tester.pumpAndSettle();

    expect(repository.removedPreferenceType, 'artist');
    expect(repository.removedPreferenceItemId, 'Artist A');
  });

  testWidgets('ArtistsPage album group menu writes Electron preference', (
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

    await tester.tap(find.byTooltip('More').at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Preference Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('High'));
    await tester.pumpAndSettle();

    expect(repository.preferenceType, 'album');
    expect(repository.preferenceItemId, 'Blue Hour');
    expect(repository.preferenceName, 'Blue Hour');
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
      _ArtistsRouterTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        router: router,
        repository: _FakeLibraryRepository(),
      ),
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
    expect(find.text('See Album'), findsOneWidget);
    expect(find.text('Locate Artist'), findsNothing);
    await tester.tap(find.text('See Album'));
    await tester.pumpAndSettle();

    final uri = router.routeInformationProvider.value.uri;
    expect(uri.path, '/albums');
    expect(uri.queryParameters['album'], 'Blue Hour');
  });

  testWidgets('ArtistsPage album More context menu mirrors Electron', (
    tester,
  ) async {
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

    await tester.tap(
      find.byTooltip('More').at(1),
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();

    expect(find.text('See Album'), findsOneWidget);
    expect(find.text('Locate Artist'), findsNothing);
  });

  testWidgets('ArtistsPage album group Select only selects album songs', (
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
      _ArtistsRouterTestApp(
        snapshot: _twoAlbumArtistSnapshot,
        i18n: i18n,
        router: router,
        repository: _FakeLibraryRepository(),
      ),
    );
    router.go('/artists?artist=Artist%20A');
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('More').at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle();

    final selection = PageSelectionController<int>.stored('artists');
    expect(selection.multiSelect, isTrue);
    expect(selection.selectedItems, {1, 2});
    expect(find.text('2 selected'), findsOneWidget);
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

    AnimatedOpacity hoverOpacityFor(Finder action) {
      return tester.widget<AnimatedOpacity>(
        find.ancestor(of: action, matching: find.byType(AnimatedOpacity)).first,
      );
    }

    expect(
      hoverOpacityFor(
        find.byKey(const ValueKey('PlaylistControlItem.AddToAction')),
      ),
      isA<AnimatedOpacity>().having((opacity) => opacity.opacity, 'opacity', 0),
    );
    expect(
      hoverOpacityFor(
        find.byKey(const ValueKey('PlaylistControlItem.PlayNextAction')),
      ),
      isA<AnimatedOpacity>().having((opacity) => opacity.opacity, 'opacity', 0),
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('PlaylistControlItem.Actions')))
          .width,
      136,
    );
    final artistSongRow = find.byKey(const ValueKey('artist-song-1'));
    final favoriteAction = find.descendant(
      of: artistSongRow,
      matching: find.byKey(
        const ValueKey('PlaylistControlItem.FavoriteAction'),
      ),
    );
    final addToAction = find.descendant(
      of: artistSongRow,
      matching: find.byKey(const ValueKey('PlaylistControlItem.AddToAction')),
    );
    final playNextAction = find.descendant(
      of: artistSongRow,
      matching: find.byKey(
        const ValueKey('PlaylistControlItem.PlayNextAction'),
      ),
    );
    final moreAction = find.descendant(
      of: artistSongRow,
      matching: find.byKey(const ValueKey('PlaylistControlItem.MoreAction')),
    );
    expect(tester.getSize(favoriteAction), const Size.square(34));
    expect(tester.getSize(addToAction), const Size.square(34));
    expect(tester.getSize(playNextAction), const Size.square(34));
    expect(
      tester.getRect(addToAction).left - tester.getRect(favoriteAction).right,
      0,
    );
    expect(
      tester.getRect(playNextAction).left - tester.getRect(addToAction).right,
      0,
    );
    expect(
      tester.getRect(moreAction).left - tester.getRect(playNextAction).right,
      0,
    );
    final addToIconTheme = tester.widget<IconTheme>(
      find.descendant(of: addToAction, matching: find.byType(IconTheme)).last,
    );
    expect(addToIconTheme.data.color, const Color(0xb8586474));
    expect(
      tester
          .getSize(
            find.descendant(
              of: find.byKey(const ValueKey('artist-song-1')),
              matching: find.byKey(
                const ValueKey('PlaylistControlItem.Duration'),
              ),
            ),
          )
          .width,
      50,
    );
    final actionsRect = tester.getRect(
      find.byKey(const ValueKey('PlaylistControlItem.Actions')),
    );
    final durationRect = tester.getRect(
      find.descendant(
        of: find.byKey(const ValueKey('artist-song-1')),
        matching: find.byKey(const ValueKey('PlaylistControlItem.Duration')),
      ),
    );
    expect(durationRect.left - actionsRect.right, 12);

    await tester.tap(find.text('Blue Song'));
    await tester.pump(const Duration(milliseconds: 160));

    expect(repository.replacedNowPlaying, [1]);
    expect(mediaController.state.track.id, 1);
    expect(mediaController.state.selectedQueueIndex, 0);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(
      location: tester.getCenter(find.byKey(const ValueKey('artist-song-1'))),
    );
    addTearDown(mouse.removePointer);
    await tester.pump(const Duration(milliseconds: 160));

    expect(
      hoverOpacityFor(
        find.byKey(const ValueKey('PlaylistControlItem.AddToAction')),
      ),
      isA<AnimatedOpacity>().having((opacity) => opacity.opacity, 'opacity', 1),
    );
    expect(
      hoverOpacityFor(
        find.byKey(const ValueKey('PlaylistControlItem.PlayNextAction')),
      ),
      isA<AnimatedOpacity>().having((opacity) => opacity.opacity, 'opacity', 1),
    );
    final overlayButton = tester.widget<ArtworkFloatingActionButton>(
      find.byKey(const ValueKey('PlaylistControlItem.PlayOverlayButton')),
    );
    expect(overlayButton.size, 38);
    expect(overlayButton.iconSize, 17);

    await tester.tap(find.byTooltip('Favorite'));
    await tester.pump(const Duration(milliseconds: 160));

    expect(repository.favoriteSongIds, [1]);
    expect(repository.favoriteValue, isTrue);

    await tester.tap(find.byTooltip('Play Next'));
    await tester.pump(const Duration(milliseconds: 160));

    expect(repository.replacedNowPlaying, [1]);
    expect(find.text('"Blue Song" will play next'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pump(const Duration(milliseconds: 160));

    expect(repository.replacedNowPlaying, []);
  });

  testWidgets('ArtistsPage 800px song row hides Electron favorite action', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(_ArtistsTestApp(snapshot: _snapshot, i18n: i18n));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('PlaylistControlItem.FavoriteAction')),
      findsNothing,
    );
    expect(find.byTooltip('Favorite'), findsNothing);
    expect(
      find.byKey(const ValueKey('PlaylistControlItem.AddToAction')),
      findsWidgets,
    );
    expect(
      find.byKey(const ValueKey('PlaylistControlItem.PlayNextAction')),
      findsWidgets,
    );
  });

  testWidgets('ArtistsPage narrow song row uses Electron compact columns', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(840, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(_ArtistsTestApp(snapshot: _snapshot, i18n: i18n));
    await tester.pumpAndSettle();

    final artistSongRow = find.byKey(const ValueKey('artist-song-1'));
    final actions = find.descendant(
      of: artistSongRow,
      matching: find.byKey(const ValueKey('PlaylistControlItem.Actions')),
    );
    final favoriteAction = find.descendant(
      of: artistSongRow,
      matching: find.byKey(
        const ValueKey('PlaylistControlItem.FavoriteAction'),
      ),
    );
    expect(tester.getSize(actions).width, 136);
    final favoriteRect = tester.getRect(favoriteAction);
    final actionsRect = tester.getRect(actions);
    expect(favoriteRect.left, actionsRect.left);
    expect(tester.getSize(favoriteAction), const Size.square(34));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(artistSongRow));
    addTearDown(mouse.removePointer);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 160));
    final hoveredActionsRect = tester.getRect(actions);
    final hoveredFavoriteRect = tester.getRect(favoriteAction);
    expect(tester.getSize(actions).width, 136);
    expect(hoveredFavoriteRect.left, favoriteRect.left);
    expect(hoveredFavoriteRect.right, favoriteRect.right);
    expect(hoveredFavoriteRect.left, hoveredActionsRect.left);
    expect(hoveredFavoriteRect.width, 34);
    final moreAction = find.descendant(
      of: artistSongRow,
      matching: find.byKey(const ValueKey('PlaylistControlItem.MoreAction')),
    );
    final addToAction = find.descendant(
      of: artistSongRow,
      matching: find.byKey(const ValueKey('PlaylistControlItem.AddToAction')),
    );
    expect(tester.getRect(addToAction).left, hoveredFavoriteRect.right);
    final duration = find.descendant(
      of: artistSongRow,
      matching: find.byKey(const ValueKey('PlaylistControlItem.Duration')),
    );
    expect(
      tester.getRect(moreAction).right,
      lessThanOrEqualTo(tester.getRect(duration).left - 12),
    );
    expect(tester.getSize(duration).width, 20);
  });

  testWidgets('ArtistsPage 801px song row keeps Electron favorite action', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(801, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(_ArtistsTestApp(snapshot: _snapshot, i18n: i18n));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('PlaylistControlItem.FavoriteAction')),
      findsWidgets,
    );
    expect(find.byTooltip('Favorite'), findsWidgets);
  });

  testWidgets(
    'ArtistsPage song row play uses full artist queue like Electron',
    (tester) async {
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
          snapshot: _twoAlbumArtistSnapshot,
          i18n: i18n,
          repository: repository,
          mediaController: mediaController,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Green Song'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(repository.replacedNowPlaying, [1, 2, 3]);
      expect(mediaController.state.track.id, 3);
      expect(mediaController.state.selectedQueueIndex, 2);
      expect(mediaController.state.isPlaying, isTrue);
    },
  );

  testWidgets('ArtistsPage song row play mirrors Electron shuffle queue', (
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
    mediaController.onToggleShuffle();

    await tester.pumpWidget(
      _ArtistsTestApp(
        snapshot: _twoAlbumArtistSnapshot,
        i18n: i18n,
        repository: repository,
        mediaController: mediaController,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Green Song'));
    await tester.pumpAndSettle();

    expect(repository.replacedNowPlaying.first, 3);
    expect(repository.replacedNowPlaying.toSet(), {1, 2, 3});
    expect(mediaController.state.track.id, 3);
    expect(mediaController.state.selectedQueueIndex, 0);
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

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(
      location: tester.getCenter(find.byKey(const ValueKey('artist-song-1'))),
    );
    addTearDown(mouse.removePointer);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Add To'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mix'));
    await tester.pumpAndSettle();

    expect(repository.addedPlaylistId, 10);
    expect(repository.addedSongIds, [1]);

    await tester.pump(const Duration(seconds: 5));
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
        _ArtistsRouterTestApp(
          snapshot: _snapshot,
          i18n: i18n,
          router: router,
          repository: _FakeLibraryRepository(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('Artists.ArtistRow.Artist A')),
      );
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
    'ArtistsPage search clear hides query suggestions like Electron',
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

      final searchField = find.byType(TextField);
      await tester.tap(searchField);
      await tester.pumpAndSettle();
      await tester.enterText(searchField, 'Artist');
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('PageSearchHistoryPanel.Item.Artist A')),
        findsOneWidget,
      );
      expect(find.byTooltip('Clear'), findsOneWidget);

      await tester.tap(find.byTooltip('Clear'));
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(searchField);
      expect(field.controller?.text, '');
      expect(find.byTooltip('Clear'), findsNothing);
      expect(
        find.byKey(const ValueKey('PageSearchHistoryPanel.Item.Artist A')),
        findsNothing,
      );
    },
  );

  testWidgets('ArtistsPage search history overlays without moving list', (
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

    final artistRow = find.byKey(const ValueKey('Artists.ArtistRow.Artist A'));
    final rowTopBefore = tester.getTopLeft(artistRow).dy;

    await tester.tap(_artistsMasterSearchTextField());
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('PageSearchHistoryPanel.Item.Artist A')),
      findsOneWidget,
    );
    final historyPanel = find.byType(PageSearchHistoryPanel);
    expect(tester.getSize(historyPanel).width, lessThan(300));
    expect(tester.getSize(historyPanel).height, lessThan(160));
    expect(tester.getTopLeft(artistRow).dy, rowTopBefore);
  });

  testWidgets('ArtistsPage resets detail scroll when artist changes', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _ArtistsTestApp(snapshot: _manyAlbumsTwoArtistsSnapshot(), i18n: i18n),
    );
    await tester.pumpAndSettle();

    for (var attempt = 0; attempt < 8; attempt += 1) {
      if (find.text('Album 10').evaluate().isNotEmpty) {
        break;
      }
      await tester.drag(
        find.byKey(const ValueKey('Artists.DetailSurface')),
        const Offset(0, -450),
      );
      await tester.pumpAndSettle();
    }

    expect(find.text('Album 10'), findsOneWidget);
    expect(find.text('Album 00'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('Artists.ArtistRow.Artist B')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('Artists.ArtistRow.Artist A')));
    await tester.pumpAndSettle();

    expect(find.text('Album 00'), findsOneWidget);
    expect(find.text('Album 10'), findsNothing);
  });

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
        _ArtistsRouterTestApp(
          snapshot: _snapshot,
          i18n: i18n,
          router: router,
          repository: _FakeLibraryRepository(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Artist A').first);
      await tester.pumpAndSettle();

      final uri = router.routeInformationProvider.value.uri;
      expect(uri.path, '/artists');
      expect(uri.queryParameters['artist'], 'Artist A');
    },
  );

  testWidgets(
    'ArtistsPage compact back replaces route and clears selection like Electron',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(640, 900);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final router = _createArtistsRouter();

      await tester.pumpWidget(
        _ArtistsRouterTestApp(
          snapshot: _snapshot,
          i18n: i18n,
          router: router,
          repository: _FakeLibraryRepository(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Artist A').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('Artists.DetailHeader.More')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Multi Select'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Blue Song'));
      await tester.pumpAndSettle();

      expect(find.text('1 selected'), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      final uri = router.routeInformationProvider.value.uri;
      expect(uri.path, '/artists');
      expect(uri.queryParameters['artist'], isNull);
      expect(find.text('1 selected'), findsNothing);
      expect(find.text('Blue Song'), findsNothing);
      expect(find.text('Artist A'), findsWidgets);

      final selection = PageSelectionController<int>.stored('artists');
      expect(selection.multiSelect, isFalse);
      expect(selection.selectedItems, isEmpty);
    },
  );

  testWidgets('ArtistsPage compact detail More includes Locate Artist', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(640, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final router = _createArtistsRouter();

    await tester.pumpWidget(
      _ArtistsRouterTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        router: router,
        repository: _FakeLibraryRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Artist A').first);
    await tester.pumpAndSettle();

    final detailHeader = tester.getSize(
      find.byKey(const ValueKey('Artists.DetailHeader')),
    );
    expect(detailHeader.height, 40);
    final header = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('Artists.DetailHeader')),
    );
    final headerDecoration = header.decoration as BoxDecoration;
    expect(headerDecoration.color, const Color(0xfff8fbfe));
    expect(headerDecoration.gradient, isNull);
    expect(headerDecoration.boxShadow, const [
      BoxShadow(
        color: Color(0x0a445870),
        offset: Offset(0, 12),
        blurRadius: 24,
      ),
    ]);
    expect(
      find.byKey(const ValueKey('Artists.DetailHeader.Back')),
      findsNothing,
    );
    expect(
      tester.getSize(
        find.byKey(const ValueKey('Artists.DetailHeader.Shuffle')),
      ),
      const Size(32, 32),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('Artists.DetailHeader.More'))),
      const Size(32, 32),
    );
    final albumActions = tester.widget<SizedBox>(
      find.byKey(const ValueKey('Artists.AlbumActions.Blue Hour')),
    );
    expect(albumActions.width, 72);
    final compactCommandGap = tester.widget<SizedBox>(
      find.byKey(const ValueKey('Artists.DetailHeader.CompactCommandGap')),
    );
    expect(compactCommandGap.width, 6);
    expect(
      find.byKey(const ValueKey('Artists.DetailHeader.Summary')),
      findsOne,
    );
    final albumListTopPadding = tester.widget<SizedBox>(
      find.byKey(const ValueKey('Artists.AlbumList.TopPadding')),
    );
    expect(albumListTopPadding.height, 14);
    final albumSectionPadding = tester.widget<SliverPadding>(
      find.byKey(const ValueKey('Artists.AlbumSection.Padding.Blue Hour')),
    );
    expect(
      albumSectionPadding.padding,
      const EdgeInsets.fromLTRB(18, 0, 18, 12),
    );
    final albumSection = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('Artists.AlbumSection.Blue Hour')),
    );
    final albumSectionDecoration = albumSection.decoration as BoxDecoration;
    expect(
      albumSectionDecoration.borderRadius,
      const BorderRadius.vertical(top: Radius.circular(8)),
    );
    final albumSectionClip = tester.widget<ClipRRect>(
      find.byKey(const ValueKey('Artists.AlbumSection.Clip.Blue Hour')),
    );
    expect(
      albumSectionClip.borderRadius,
      const BorderRadius.vertical(top: Radius.circular(8)),
    );
    expect(albumSectionClip.clipBehavior, Clip.hardEdge);
    final albumHeader = tester.widget<ConstrainedBox>(
      find.byKey(const ValueKey('Artists.AlbumHeader.Blue Hour')),
    );
    expect(albumHeader.constraints.minHeight, 88);
    final albumHeaderPadding = tester.widget<Padding>(
      find.byKey(const ValueKey('Artists.AlbumHeader.Padding.Blue Hour')),
    );
    expect(
      albumHeaderPadding.padding,
      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
    final albumSummaryGap = tester.widget<SizedBox>(
      find.byKey(const ValueKey('Artists.AlbumSummary.Gap.Blue Hour')),
    );
    expect(albumSummaryGap.height, 6);
    final albumTitle = tester.widget<Text>(
      find.byKey(const ValueKey('Artists.AlbumTitle.Blue Hour')),
    );
    expect(albumTitle.style?.fontSize, 17);
    final albumShuffle = tester.widget<IconButton>(
      find.byKey(const ValueKey('Artists.AlbumShuffle.Blue Hour')),
    );
    expect(
      albumShuffle.constraints,
      const BoxConstraints.tightFor(width: 32, height: 32),
    );
    final compactDetailMoreRect = tester.getRect(
      find.byKey(const ValueKey('Artists.DetailHeader.More')),
    );
    final compactDetailShuffleRect = tester.getRect(
      find.byKey(const ValueKey('Artists.DetailHeader.Shuffle')),
    );
    expect(compactDetailMoreRect.left - compactDetailShuffleRect.right, 4);
    final detailShuffleIcon = tester.widget<ShuffleIcon>(
      find.descendant(
        of: find.byKey(const ValueKey('Artists.DetailHeader.Shuffle')),
        matching: find.byType(ShuffleIcon),
      ),
    );
    expect(detailShuffleIcon.size, 17);

    final compactAlbumMoreRect = tester.getRect(
      find.byKey(const ValueKey('Artists.AlbumMore.Blue Hour')),
    );
    final compactAlbumShuffleRect = tester.getRect(
      find.byKey(const ValueKey('Artists.AlbumShuffle.Blue Hour')),
    );
    expect(compactAlbumMoreRect.left - compactAlbumShuffleRect.right, 4);
    final shuffleIcon = tester.widget<ShuffleIcon>(
      find.descendant(
        of: find.byKey(const ValueKey('Artists.AlbumShuffle.Blue Hour')),
        matching: find.byType(ShuffleIcon),
      ),
    );
    expect(shuffleIcon.size, 17);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('artist-song-1')),
        matching: find.byKey(
          const ValueKey('PlaylistControlItem.FavoriteAction'),
        ),
      ),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('Artists.DetailHeader.More')));
    await tester.pumpAndSettle();

    expect(find.text('Locate Artist'), findsOneWidget);
    expect(
      find.byIcon(FluentIcons.apps_list_detail_20_regular),
      findsOneWidget,
    );
    expect(find.byIcon(FluentIcons.music_note_2_20_regular), findsNothing);
    expect(find.text('See Album'), findsNothing);
  });

  testWidgets('ArtistsPage detail More context menu mirrors Electron', (
    tester,
  ) async {
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

    await tester.tap(
      find.byKey(const ValueKey('Artists.DetailHeader.More')),
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();

    expect(find.text('Locate Artist'), findsOneWidget);
    expect(find.text('See Album'), findsNothing);
  });

  testWidgets('ArtistsPage Locate Artist exits detail and scrolls list', (
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
      _ArtistsRouterTestApp(
        snapshot: _manyArtistsSnapshot(),
        i18n: i18n,
        router: router,
        repository: _FakeLibraryRepository(),
      ),
    );
    router.go('/artists?artist=Beta%20Target');
    await tester.pumpAndSettle();

    final masterScrollable = find.byType(Scrollable).at(1);
    final position = tester.state<ScrollableState>(masterScrollable).position;
    position.jumpTo(0);
    await tester.pump();

    expect(
      find.byKey(const ValueKey('Artists.ArtistRow.Beta Target')),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('Artists.DetailHeader.More')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Locate Artist'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('Artists.ArtistRow.Beta Target')),
      findsOneWidget,
    );
    expect(position.pixels, greaterThan(0));
    final uri = router.routeInformationProvider.value.uri;
    expect(uri.path, '/artists');
    expect(uri.queryParameters.containsKey('artist'), isFalse);
  });

  testWidgets(
    'ArtistsPage compact Locate Artist exits detail and locates row',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(640, 900);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final router = _createArtistsRouter();

      await tester.pumpWidget(
        _ArtistsRouterTestApp(
          snapshot: _manyArtistsSnapshot(),
          i18n: i18n,
          router: router,
          repository: _FakeLibraryRepository(),
        ),
      );
      router.go('/artists?artist=Beta%20Target');
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('Artists.DetailHeader.More')), findsOne);
      expect(
        find.byKey(const ValueKey('Artists.ArtistRow.Beta Target')),
        findsNothing,
      );

      await tester.tap(find.byKey(const ValueKey('Artists.DetailHeader.More')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Locate Artist'));
      await tester.pumpAndSettle();

      final uri = router.routeInformationProvider.value.uri;
      expect(uri.path, '/artists');
      expect(uri.queryParameters.containsKey('artist'), isFalse);
      expect(
        find.byKey(const ValueKey('Artists.ArtistRow.Beta Target')),
        findsOneWidget,
      );
    },
  );

  testWidgets('ArtistsPage compact Locate Artist highlights visible row', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(640, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final router = _createArtistsRouter();

    await tester.pumpWidget(
      _ArtistsRouterTestApp(
        snapshot: _twoArtistSnapshot,
        i18n: i18n,
        router: router,
        repository: _FakeLibraryRepository(),
      ),
    );
    router.go('/artists?artist=Artist%20B');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('Artists.DetailHeader.More')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Locate Artist'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final uri = router.routeInformationProvider.value.uri;
    expect(uri.path, '/artists');
    expect(uri.queryParameters.containsKey('artist'), isFalse);
    expect(
      find.byKey(const ValueKey('Artists.ArtistRow.Artist B')),
      findsOneWidget,
    );
    final highlightedDecoration =
        tester
                .widget<Container>(
                  find.byKey(
                    const ValueKey('Artists.ArtistRow.Decoration.Artist B'),
                  ),
                )
                .decoration!
            as BoxDecoration;
    expect(highlightedDecoration.color, isNotNull);
    expect(highlightedDecoration.color, isNot(Colors.transparent));

    await tester.pumpAndSettle();
    final fadedDecoration =
        tester
                .widget<Container>(
                  find.byKey(
                    const ValueKey('Artists.ArtistRow.Decoration.Artist B'),
                  ),
                )
                .decoration!
            as BoxDecoration;
    expect(fadedDecoration.color, Colors.transparent);
  });

  testWidgets('ArtistsPage legacy artist route redirects like Electron', (
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
    router.go('/artists/Artist%20A');
    await tester.pumpAndSettle();

    final uri = router.routeInformationProvider.value.uri;
    expect(uri.path, '/artists');
    expect(uri.queryParameters['artist'], 'Artist A');
  });

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
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Artist A',
    );
    final uri = router.routeInformationProvider.value.uri;
    expect(uri.path, '/artists');
    expect(uri.queryParameters['artist'], isNull);
  });

  testWidgets('ArtistsPage unknown search only records history like Electron', (
    tester,
  ) async {
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

    await tester.enterText(find.byType(TextField), ' Ghost Artist ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(repository.recordedSearches, [
      (query: 'Ghost Artist', type: SearchHistoryType.artists),
    ]);
    final uri = router.routeInformationProvider.value.uri;
    expect(uri.path, '/artists');
    expect(uri.queryParameters['artist'], isNull);
    expect(find.text('Blue Hour'), findsOneWidget);
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

  testWidgets('ArtistsPage search suggestions are limited like Electron', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _ArtistsTestApp(
        snapshot: _artistSearchLimitSnapshot(),
        i18n: i18n,
        repository: _FakeLibraryRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Artist');
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key as ValueKey<String>).value.startsWith(
              'PageSearchHistoryPanel.Item.Artist ',
            ),
      ),
      findsNWidgets(8),
    );
    expect(
      find.byKey(const ValueKey('PageSearchHistoryPanel.Item.Artist 8')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('PageSearchHistoryPanel.Item.Artist 9')),
      findsNothing,
    );
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

    await tester.tap(_artistsMasterSearchTextField());
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('PageSearchHistoryPanel.Item.artist a')),
      findsNothing,
    );
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

  testWidgets('ArtistsPage recent artist searches are limited like Electron', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _ArtistsTestApp(snapshot: _searchHistoryLimitSnapshot(), i18n: i18n),
    );
    await tester.pumpAndSettle();

    await tester.tap(_artistsMasterSearchTextField());
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key as ValueKey<String>).value.startsWith(
              'PageSearchHistoryPanel.Item.Artist History ',
            ),
      ),
      findsNWidgets(10),
    );
    expect(
      find.byKey(
        const ValueKey('PageSearchHistoryPanel.Item.Artist History 10'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey('PageSearchHistoryPanel.Item.Artist History 11'),
      ),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('PageSearchHistoryPanel.Item.Album History')),
      findsNothing,
    );
  });

  testWidgets('ArtistsPage removes one recent artist search like Electron', (
    tester,
  ) async {
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
        snapshot: _searchHistoryActionsSnapshot,
        i18n: i18n,
        router: router,
        repository: repository,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(_artistsMasterSearchTextField());
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Remove Artist A'));
    await tester.pumpAndSettle();

    expect(repository.removedRecentSearchIds, [
      [31],
    ]);
  });

  testWidgets('ArtistsPage clears only artist search history like Electron', (
    tester,
  ) async {
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
        snapshot: _searchHistoryActionsSnapshot,
        i18n: i18n,
        router: router,
        repository: repository,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(_artistsMasterSearchTextField());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();

    expect(repository.removedRecentSearchIds, [
      [31, 32],
    ]);
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

      await tester.tap(_artistsMasterSearchTextField());
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

  testWidgets('ArtistsPage song artist text opens the Electron artist route', (
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
    await tester.pumpAndSettle();

    await tester.tap(find.text('Artist A').last);
    await tester.pumpAndSettle();

    final uri = router.routeInformationProvider.value.uri;
    expect(uri.path, '/artists');
    expect(uri.queryParameters['artist'], 'Artist A');
  });

  testWidgets('ArtistsPage song row uses Electron artist separator', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final localizedI18n = SmPlayerI18n(
      locale: 'zh-CN',
      messages: {...i18n.messages, 'common.artistSeparator': '、'},
    );

    await tester.pumpWidget(
      _ArtistsTestApp(snapshot: _multiArtistSongSnapshot, i18n: localizedI18n),
    );
    await tester.pumpAndSettle();

    expect(find.text('Artist A'), findsWidgets);
    expect(find.text('、'), findsOneWidget);
    expect(find.text('Artist B'), findsWidgets);
    expect(find.text(' / '), findsNothing);
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
          repository: _FakeLibraryRepository(),
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
      expect(find.text('Missing'), findsNothing);
      expect(find.text('Blue Song'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 2500));
      expect(find.text('Artist not found'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 900));
      expect(find.text('Artist not found'), findsNothing);
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

  testWidgets('ArtistsPage target route does not double-decode artist query', (
    tester,
  ) async {
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
        snapshot: _percentArtistSnapshot,
        i18n: i18n,
        router: router,
        repository: repository,
      ),
    );
    router.go('/artists?artist=100%25%20Pure');
    await tester.pumpAndSettle();

    expect(repository.recordedSearches, [
      (query: '100% Pure', type: SearchHistoryType.artists),
    ]);
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('Artists.DetailHeader.Title')),
          )
          .data,
      '100% Pure',
    );
    final searchBox = tester.widget<TextField>(find.byType(TextField));
    expect(searchBox.controller!.text, '100% Pure');
  });

  testWidgets('ArtistsPage target route scrolls master list like Electron', (
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
      _ArtistsRouterTestApp(
        snapshot: _manyArtistsSnapshot(),
        i18n: i18n,
        router: router,
        repository: _FakeLibraryRepository(),
      ),
    );
    router.go('/artists?artist=Beta%20Target');
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('Artists.ArtistRow.Beta Target')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('Artists.DetailHeader.Title')),
          )
          .data,
      'Beta Target',
    );
  });

  testWidgets('ArtistsPage target route resets detail scroll like Electron', (
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
      _ArtistsRouterTestApp(
        snapshot: _manyAlbumsTwoLargeArtistsSnapshot(),
        i18n: i18n,
        router: router,
        repository: _FakeLibraryRepository(),
      ),
    );
    await tester.pumpAndSettle();

    for (var attempt = 0; attempt < 8; attempt += 1) {
      if (find.text('A Album 10').evaluate().isNotEmpty) {
        break;
      }
      await tester.drag(
        find.byKey(const ValueKey('Artists.DetailSurface')),
        const Offset(0, -450),
      );
      await tester.pumpAndSettle();
    }

    expect(find.text('A Album 10'), findsOneWidget);
    expect(find.text('A Album 00'), findsNothing);

    router.go('/artists?artist=Artist%20B');
    await tester.pumpAndSettle();

    expect(find.text('B Album 00'), findsOneWidget);
    expect(find.text('B Album 10'), findsNothing);
  });

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
      await tester.pump(const Duration(milliseconds: 2500));
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
    await tester.pump();

    expect(find.text('Beta Target'), findsOneWidget);
    final activeB = tester.widget<TextButton>(
      find.byKey(const ValueKey('Artists.QuickJump.B')),
    );
    expect(
      activeB.style?.backgroundColor?.resolve({}),
      const Color(0x1f0078d7),
    );
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
        path: '/artists/:artistName',
        redirect: (context, state) {
          final artistName = state.pathParameters['artistName']!;
          return '/artists?artist=${Uri.encodeQueryComponent(artistName)}';
        },
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

  final LibraryContentData snapshot;
  final SmPlayerI18n i18n;
  final GoRouter router;
  final LibraryRepository? repository;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        smPlayerI18nProvider.overrideWith((ref) async => i18n),
        libraryContentDataProvider.overrideWith((ref) async => snapshot),
        if (repository != null)
          libraryRepositoryProvider.overrideWithValue(repository!),
      ],
      child: SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp.router(
          theme: _artistsPageTestTheme(),
          routerConfig: router,
        ),
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
    this.brightness = Brightness.light,
  });

  final LibraryContentData snapshot;
  final SmPlayerI18n i18n;
  final LibraryRepository? repository;
  final MediaControlController? mediaController;
  final String searchQuery;
  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        smPlayerI18nProvider.overrideWith((ref) async => i18n),
        libraryContentDataProvider.overrideWith((ref) async => snapshot),
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
          theme: _artistsPageTestTheme(brightness: brightness),
          home: Scaffold(body: ArtistsPage(searchQuery: searchQuery)),
        ),
      ),
    );
  }
}

class _ArtistsAppBarPortalTestApp extends StatelessWidget {
  const _ArtistsAppBarPortalTestApp({
    required this.snapshot,
    required this.i18n,
    this.brightness = Brightness.light,
    this.initialLocation = '/artists',
  });

  final LibraryContentData snapshot;
  final SmPlayerI18n i18n;
  final Brightness brightness;
  final String initialLocation;

  @override
  Widget build(BuildContext context) {
    final appBarRouter = GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: '/artists',
          builder:
              (context, state) => Scaffold(
                body: Column(
                  children: [
                    Consumer(
                      builder: (context, ref, _) {
                        final entry = ref.watch(workspaceAppBarPortalProvider);
                        return SizedBox(
                          height: 120,
                          child: Column(
                            children: [
                              Text('APPBAR_TITLE:${entry?.title ?? ''}'),
                              Text(
                                'APPBAR_BOTTOM:${entry?.bottomContent != null}',
                              ),
                              Expanded(
                                child: entry?.content ?? const SizedBox(),
                              ),
                              if (entry?.bottomContent case final bottom?)
                                SizedBox(height: 40, child: bottom),
                            ],
                          ),
                        );
                      },
                    ),
                    Expanded(
                      child: WorkspaceNavigationAppBarScope(
                        active: true,
                        child: ArtistsPage(
                          targetArtistName: state.uri.queryParameters['artist'],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        smPlayerI18nProvider.overrideWith((ref) async => i18n),
        libraryContentDataProvider.overrideWith((ref) async => snapshot),
      ],
      child: SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp.router(
          theme: _artistsPageTestTheme(brightness: brightness),
          routerConfig: appBarRouter,
        ),
      ),
    );
  }
}

class _ArtistsLoadingTestApp extends StatelessWidget {
  const _ArtistsLoadingTestApp({
    required this.snapshotFuture,
    required this.i18n,
    this.repository,
    this.workspaceAppBar = false,
    this.brightness = Brightness.light,
  });

  final Future<LibraryContentData> snapshotFuture;
  final SmPlayerI18n i18n;
  final LibraryRepository? repository;
  final bool workspaceAppBar;
  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        smPlayerI18nProvider.overrideWith((ref) async => i18n),
        libraryContentDataProvider.overrideWith((ref) => snapshotFuture),
        if (repository != null)
          libraryRepositoryProvider.overrideWithValue(repository!),
      ],
      child: SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp(
          theme: _artistsPageTestTheme(),
          darkTheme: _artistsPageTestTheme(brightness: Brightness.dark),
          themeMode:
              brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
          home: Scaffold(
            body: WorkspaceNavigationAppBarScope(
              active: workspaceAppBar,
              child: const ArtistsPage(),
            ),
          ),
        ),
      ),
    );
  }
}

ThemeData _artistsPageTestTheme({Brightness brightness = Brightness.light}) {
  final dark = brightness == Brightness.dark;
  return ThemeData(
    brightness: brightness,
    extensions: [
      dark ? AppNotificationThemeColors.dark : AppNotificationThemeColors.light,
      dark
          ? DefaultAlbumArtworkThemeColors.dark
          : DefaultAlbumArtworkThemeColors.light,
    ],
  );
}

class _ArtistsSnapshotRouterTestApp extends StatelessWidget {
  const _ArtistsSnapshotRouterTestApp({
    required this.snapshot,
    required this.i18n,
    required this.router,
    required this.repository,
  });

  final ValueNotifier<LibraryContentData> snapshot;
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

  final ValueNotifier<LibraryContentData> snapshot;
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
    return MaterialApp.router(
      theme: _artistsPageTestTheme(),
      routerConfig: widget.router,
    );
  }

  void _invalidateSnapshot() {
    ref.invalidate(libraryContentDataProvider);
  }
}

class _FakeLibraryRepository extends LibraryRepository {
  List<int> replacedNowPlaying = [];
  int? addedPlaylistId;
  List<int> addedSongIds = [];
  int? removedPlaylistId;
  List<int> removedSongIds = [];
  String? createdPlaylistName;
  List<int> createdPlaylistSongIds = [];
  List<int> favoriteSongIds = [];
  bool? favoriteValue;
  List<String> recordedArtists = [];
  List<String> recordedAlbums = [];
  List<({String query, SearchHistoryType type})> recordedSearches = [];
  List<List<int>> removedRecentSearchIds = [];
  List<int> beganDeleteSongIds = [];
  List<String> undoneDeleteIds = [];
  List<String> committedDeleteIds = [];
  String? preferenceType;
  String? preferenceItemId;
  String? preferenceName;
  String? preferenceLevel;
  String? removedPreferenceType;
  String? removedPreferenceItemId;
  final preferenceLevels = <(String, String), String>{};

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
  Future<void> removeSongsFromPlaylist(
    int playlistId,
    List<int> songIds,
  ) async {
    removedPlaylistId = playlistId;
    removedSongIds = songIds.toList();
  }

  @override
  Future<LibraryPlaylist> createPlaylist(
    String name, [
    List<int> songIds = const [],
  ]) async {
    createdPlaylistName = name;
    createdPlaylistSongIds = songIds.toList();
    return LibraryPlaylist(
      id: 99,
      name: name,
      priority: 0,
      songCount: songIds.length,
      songIds: songIds.toList(),
      sortCriterion: PlaylistSortCriterion.title,
      isBuiltIn: false,
    );
  }

  @override
  Future<PendingSongDelete> beginDeleteSongFromDisk(int songId) async {
    beganDeleteSongIds.add(songId);
    return PendingSongDelete(id: 'pending-$songId', songId: songId);
  }

  @override
  Future<void> undoDeleteSongFromDisk(String deleteId) async {
    undoneDeleteIds.add(deleteId);
  }

  @override
  Future<void> commitDeleteSongFromDisk(String deleteId) async {
    committedDeleteIds.add(deleteId);
  }

  @override
  Future<void> setSongsFavorite(List<int> songIds, bool favorite) async {
    favoriteSongIds = songIds.toList();
    favoriteValue = favorite;
  }

  @override
  Future<String?> getPreferenceLevel(String type, String itemId) async {
    return preferenceLevels[(type, itemId)];
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
  Future<SearchHistoryEntry?> addRecentSearch(
    String query, [
    SearchHistoryType type = SearchHistoryType.sidebar,
  ]) async {
    recordedSearches.add((query: query, type: type));
    return SearchHistoryEntry(
      id: recordedSearches.length,
      query: query.trim(),
      type: type,
      searchedAt: '2026-05-23T00:00:00Z',
    );
  }

  @override
  Future<void> removeRecentSearches(List<int> entryIds) async {
    removedRecentSearchIds.add(entryIds.toList());
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
  Future<void> removePreferenceItem(String type, String itemId) async {
    removedPreferenceType = type;
    removedPreferenceItemId = itemId;
    preferenceLevels.remove((type, itemId));
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

class _ValueListenableArtistsRepository extends _FakeLibraryRepository {
  _ValueListenableArtistsRepository(this.snapshot);

  final ValueNotifier<LibraryContentData> snapshot;

  @override
  Future<void> replaceNowPlaying(List<int> songIds) async {
    await super.replaceNowPlaying(songIds);
    final current = snapshot.value;
    snapshot.value = LibraryContentData(
      songs: current.songs,
      hasLibrary: current.hasLibrary,
      sortCriterion: current.sortCriterion,
      albumsSort: current.albumsSort,
      databasePath: current.databasePath,
      recentSongs: current.recentSongs,
      recentPlaylists: current.recentPlaylists,
      recentAlbums: current.recentAlbums,
      recentArtists: current.recentArtists,
      recentSearches: current.recentSearches,
      playlists: current.playlists,
      folders: current.folders,
      favoritePlaylistId: current.favoritePlaylistId,
      nowPlaying: NowPlayingSnapshot(
        playlistId: current.nowPlaying.playlistId,
        songIds: songIds.toList(),
      ),
      showCount: current.showCount,
      hideMultiSelectCommandBarAfterOperation:
          current.hideMultiSelectCommandBarAfterOperation,
      localViewMode: current.localViewMode,
      rootPath: current.rootPath,
    );
  }

  @override
  Future<LibraryContentData> getLibraryContentData() async {
    return snapshot.value;
  }
}

bool _hasHiddenCommandBarAncestor(WidgetTester tester, Finder descendant) {
  final hasHiddenOpacity = tester
      .widgetList<AnimatedOpacity>(
        find.ancestor(of: descendant, matching: find.byType(AnimatedOpacity)),
      )
      .any((widget) => widget.opacity == 0);
  final ignoresPointer = tester
      .widgetList<IgnorePointer>(
        find.ancestor(of: descendant, matching: find.byType(IgnorePointer)),
      )
      .any((widget) => widget.ignoring);
  return hasHiddenOpacity && ignoresPointer;
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
  recentSearches: [
    SearchHistoryEntry(
      id: 31,
      query: 'Artist A',
      type: SearchHistoryType.artists,
      searchedAt: '2026-05-21T00:00:00',
    ),
    SearchHistoryEntry(
      id: 30,
      query: 'artist a',
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

const _emptyArtistsSnapshot = LibraryContentData(
  songs: [],
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

const _playlistNameCollisionSnapshot = LibraryContentData(
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
      name: 'Artist A',
      priority: 1,
      songCount: 0,
      songIds: [],
      sortCriterion: PlaylistSortCriterion.title,
      isBuiltIn: false,
    ),
    LibraryPlaylist(
      id: 11,
      name: 'Blue Song',
      priority: 2,
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

const _twoArtistSnapshot = LibraryContentData(
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

const _artistSortSnapshot = LibraryContentData(
  songs: [
    LibrarySong(
      id: 1,
      path: r'C:\Music\alpha.mp3',
      title: 'Alpha Song',
      artist: 'Alpha',
      artists: ['Alpha'],
      album: 'Alpha Album',
      duration: 120,
      playCount: 0,
      lyricsOffsetMs: 0,
      dateAdded: '2026-05-20T00:00:00',
      favorite: false,
      thumbnailPath: '',
    ),
    LibrarySong(
      id: 2,
      path: r'C:\Music\beta-1.mp3',
      title: 'Beta Song 1',
      artist: 'Beta',
      artists: ['Beta'],
      album: 'Beta Album',
      duration: 120,
      playCount: 0,
      lyricsOffsetMs: 0,
      dateAdded: '2026-05-21T00:00:00',
      favorite: false,
      thumbnailPath: '',
    ),
    LibrarySong(
      id: 3,
      path: r'C:\Music\beta-2.mp3',
      title: 'Beta Song 2',
      artist: 'Beta',
      artists: ['Beta'],
      album: 'Beta Album',
      duration: 120,
      playCount: 0,
      lyricsOffsetMs: 0,
      dateAdded: '2026-05-22T00:00:00',
      favorite: false,
      thumbnailPath: '',
    ),
    LibrarySong(
      id: 4,
      path: r'C:\Music\beta-3.mp3',
      title: 'Beta Song 3',
      artist: 'Beta',
      artists: ['Beta'],
      album: 'Beta Album',
      duration: 120,
      playCount: 0,
      lyricsOffsetMs: 0,
      dateAdded: '2026-05-23T00:00:00',
      favorite: false,
      thumbnailPath: '',
    ),
    LibrarySong(
      id: 5,
      path: r'C:\Music\gamma-1.mp3',
      title: 'Gamma Song 1',
      artist: 'Gamma',
      artists: ['Gamma'],
      album: 'Gamma Album A',
      duration: 120,
      playCount: 0,
      lyricsOffsetMs: 0,
      dateAdded: '2026-05-24T00:00:00',
      favorite: false,
      thumbnailPath: '',
    ),
    LibrarySong(
      id: 6,
      path: r'C:\Music\gamma-2.mp3',
      title: 'Gamma Song 2',
      artist: 'Gamma',
      artists: ['Gamma'],
      album: 'Gamma Album B',
      duration: 120,
      playCount: 0,
      lyricsOffsetMs: 0,
      dateAdded: '2026-05-25T00:00:00',
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

const _multiArtistSongSnapshot = LibraryContentData(
  songs: [
    LibrarySong(
      id: 1,
      path: r'C:\Music\duet.mp3',
      title: 'Duet Song',
      artist: 'Artist A; Artist B',
      artists: ['Artist A', 'Artist B'],
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
  favoritePlaylistId: 3,
  nowPlaying: NowPlayingSnapshot(playlistId: 0, songIds: []),
  hasLibrary: true,
  sortCriterion: MusicLibrarySortCriterion.title,
  albumsSort: AlbumSortCriterion.defaultSort,
  showCount: true,
  hideMultiSelectCommandBarAfterOperation: true,
  databasePath: '',
);

const _percentArtistSnapshot = LibraryContentData(
  songs: [
    LibrarySong(
      id: 1,
      path: r'C:\Music\percent.mp3',
      title: 'Percent Song',
      artist: '100% Pure',
      artists: ['100% Pure'],
      album: 'Percent Album',
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

const _artistArtworkFallbackAlbumOrderSongs = [
  LibrarySong(
    id: 7,
    path: r'C:\Music\unknown-artwork.mp3',
    title: 'Unknown Artwork Song',
    artist: 'Artist A',
    artists: ['Artist A'],
    album: '',
    duration: 120,
    playCount: 0,
    lyricsOffsetMs: 0,
    dateAdded: '2026-05-20T00:00:00',
    favorite: false,
    thumbnailPath: r'C:\Music\unknown-cover.jpg',
  ),
  LibrarySong(
    id: 8,
    path: r'C:\Music\alpha-artwork.mp3',
    title: 'Alpha Artwork Song',
    artist: 'Artist A',
    artists: ['Artist A'],
    album: 'Alpha',
    duration: 120,
    playCount: 0,
    lyricsOffsetMs: 0,
    dateAdded: '2026-05-19T00:00:00',
    favorite: false,
    thumbnailPath: r'C:\Music\alpha-cover.jpg',
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

const _artistLatestFallbackSongsWithDotNetTicks = [
  LibrarySong(
    id: 3,
    path: r'C:\Music\older-ticks.mp3',
    title: 'Older Song (Ticks)',
    artist: 'Artist A',
    artists: ['Artist A'],
    album: 'A Album',
    duration: 120,
    playCount: 0,
    lyricsOffsetMs: 0,
    dateAdded: '637269492000000000',
    favorite: false,
    thumbnailPath: '',
  ),
  LibrarySong(
    id: 4,
    path: r'C:\Music\latest-ticks.mp3',
    title: 'Latest Song (Ticks)',
    artist: 'Artist A',
    artists: ['Artist A'],
    album: 'B Album',
    duration: 120,
    playCount: 0,
    lyricsOffsetMs: 0,
    dateAdded: '637270356960000000',
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

const _artistGroupingSongs = [
  LibrarySong(
    id: 1,
    path: r'C:\Music\duet.mp3',
    title: 'Duet Song',
    artist: 'Ignored Artist',
    artists: ['Artist A', 'Artist B'],
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
    path: r'C:\Music\unknown-artist.mp3',
    title: 'Unknown Artist Song',
    artist: '',
    artists: [],
    album: 'Blue Hour',
    duration: 90,
    playCount: 0,
    lyricsOffsetMs: 0,
    dateAdded: '2026-05-21T00:00:00',
    favorite: false,
    thumbnailPath: '',
  ),
];

const _artistFallbackDedupSongs = [
  LibrarySong(
    id: 3,
    path: r'C:\Music\duplicate-artist.mp3',
    title: 'Duplicate Artist Song',
    artist: 'Artist A; artist a; Artist A',
    artists: [],
    album: 'Blue Hour',
    duration: 120,
    playCount: 0,
    lyricsOffsetMs: 0,
    dateAdded: '2026-05-22T00:00:00',
    favorite: false,
    thumbnailPath: '',
  ),
];

const _albumGroupingSongs = [
  LibrarySong(
    id: 11,
    path: r'C:\Music\blue-b.mp3',
    title: 'Blue B',
    artist: 'Artist A',
    artists: ['Artist A'],
    album: 'Blue Hour',
    duration: 150,
    playCount: 0,
    lyricsOffsetMs: 0,
    dateAdded: '2026-05-20T00:00:00',
    favorite: false,
    thumbnailPath: '',
  ),
  LibrarySong(
    id: 12,
    path: r'C:\Music\blue-a.mp3',
    title: 'Blue A',
    artist: 'Artist A',
    artists: ['Artist A'],
    album: 'Blue Hour',
    duration: 90,
    playCount: 0,
    lyricsOffsetMs: 0,
    dateAdded: '2026-05-21T00:00:00',
    favorite: false,
    thumbnailPath: '',
  ),
  LibrarySong(
    id: 13,
    path: r'C:\Music\unknown.mp3',
    title: 'Unknown Song',
    artist: 'Artist A',
    artists: ['Artist A'],
    album: '',
    duration: 75,
    playCount: 0,
    lyricsOffsetMs: 0,
    dateAdded: '2026-05-22T00:00:00',
    favorite: false,
    thumbnailPath: '',
  ),
  LibrarySong(
    id: 14,
    path: r'C:\Music\alpha.mp3',
    title: 'Alpha Song',
    artist: 'Artist A',
    artists: ['Artist A'],
    album: 'Alpha',
    duration: 90,
    playCount: 0,
    lyricsOffsetMs: 0,
    dateAdded: '2026-05-23T00:00:00',
    favorite: false,
    thumbnailPath: '',
  ),
];

final _keepSelectionSnapshot = LibraryContentData(
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

final _searchHistoryActionsSnapshot = LibraryContentData(
  songs: _snapshot.songs,
  recentSongs: _snapshot.recentSongs,
  recentPlaylists: _snapshot.recentPlaylists,
  recentAlbums: _snapshot.recentAlbums,
  recentArtists: _snapshot.recentArtists,
  recentSearches: const [
    SearchHistoryEntry(
      id: 31,
      query: 'Artist A',
      type: SearchHistoryType.artists,
      searchedAt: '2026-05-21T00:00:00',
    ),
    SearchHistoryEntry(
      id: 32,
      query: 'Ghost Artist',
      type: SearchHistoryType.artists,
      searchedAt: '2026-05-20T00:00:00',
    ),
    SearchHistoryEntry(
      id: 33,
      query: 'Sidebar Query',
      type: SearchHistoryType.sidebar,
      searchedAt: '2026-05-19T00:00:00',
    ),
  ],
  playlists: _snapshot.playlists,
  favoritePlaylistId: _snapshot.favoritePlaylistId,
  nowPlaying: _snapshot.nowPlaying,
  hasLibrary: _snapshot.hasLibrary,
  sortCriterion: _snapshot.sortCriterion,
  albumsSort: _snapshot.albumsSort,
  showCount: _snapshot.showCount,
  hideMultiSelectCommandBarAfterOperation:
      _snapshot.hideMultiSelectCommandBarAfterOperation,
  databasePath: _snapshot.databasePath,
);

LibraryContentData _searchHistoryLimitSnapshot() {
  return LibraryContentData(
    songs: _snapshot.songs,
    recentSongs: _snapshot.recentSongs,
    recentPlaylists: _snapshot.recentPlaylists,
    recentAlbums: _snapshot.recentAlbums,
    recentArtists: _snapshot.recentArtists,
    recentSearches: [
      for (var index = 1; index <= 12; index += 1)
        SearchHistoryEntry(
          id: index,
          query: 'Artist History $index',
          type: SearchHistoryType.artists,
          searchedAt: '2026-05-${index.toString().padLeft(2, '0')}T00:00:00',
        ),
      const SearchHistoryEntry(
        id: 50,
        query: 'Album History',
        type: SearchHistoryType.albums,
        searchedAt: '2026-05-20T00:00:00',
      ),
    ],
    playlists: _snapshot.playlists,
    favoritePlaylistId: _snapshot.favoritePlaylistId,
    nowPlaying: _snapshot.nowPlaying,
    hasLibrary: _snapshot.hasLibrary,
    sortCriterion: _snapshot.sortCriterion,
    albumsSort: _snapshot.albumsSort,
    showCount: _snapshot.showCount,
    hideMultiSelectCommandBarAfterOperation:
        _snapshot.hideMultiSelectCommandBarAfterOperation,
    databasePath: _snapshot.databasePath,
  );
}

const _multiSongArtistSnapshot = LibraryContentData(
  songs: [
    LibrarySong(
      id: 1,
      path: r'C:\Music\blue-1.mp3',
      title: 'Blue Song 1',
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
      path: r'C:\Music\blue-2.mp3',
      title: 'Blue Song 2',
      artist: 'Artist A',
      artists: ['Artist A'],
      album: 'Blue Hour',
      duration: 121,
      playCount: 0,
      lyricsOffsetMs: 0,
      dateAdded: '2026-05-21T00:00:00',
      favorite: false,
      thumbnailPath: '',
    ),
    LibrarySong(
      id: 3,
      path: r'C:\Music\blue-3.mp3',
      title: 'Blue Song 3',
      artist: 'Artist A',
      artists: ['Artist A'],
      album: 'Blue Hour',
      duration: 122,
      playCount: 0,
      lyricsOffsetMs: 0,
      dateAdded: '2026-05-22T00:00:00',
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

const _twoAlbumArtistSnapshot = LibraryContentData(
  songs: [
    LibrarySong(
      id: 1,
      path: r'C:\Music\blue-1.mp3',
      title: 'Blue Song 1',
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
      path: r'C:\Music\blue-2.mp3',
      title: 'Blue Song 2',
      artist: 'Artist A',
      artists: ['Artist A'],
      album: 'Blue Hour',
      duration: 121,
      playCount: 0,
      lyricsOffsetMs: 0,
      dateAdded: '2026-05-21T00:00:00',
      favorite: false,
      thumbnailPath: '',
    ),
    LibrarySong(
      id: 3,
      path: r'C:\Music\green.mp3',
      title: 'Green Song',
      artist: 'Artist A',
      artists: ['Artist A'],
      album: 'Green Hour',
      duration: 122,
      playCount: 0,
      lyricsOffsetMs: 0,
      dateAdded: '2026-05-22T00:00:00',
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

LibraryContentData _artistSearchLimitSnapshot() {
  final songs = List.generate(10, (index) {
    final artistIndex = index + 1;
    return LibrarySong(
      id: artistIndex,
      path: r'C:\Music\artist-search.mp3',
      title: 'Song $artistIndex',
      artist: 'Artist $artistIndex',
      artists: ['Artist $artistIndex'],
      album: 'Album',
      duration: 120,
      playCount: 0,
      lyricsOffsetMs: 0,
      dateAdded: '2026-05-${artistIndex.toString().padLeft(2, '0')}T00:00:00',
      favorite: false,
      thumbnailPath: '',
    );
  });
  return LibraryContentData(
    songs: songs,
    recentSongs: const [],
    recentPlaylists: const [],
    recentAlbums: const [],
    recentArtists: const [],
    recentSearches: const [],
    playlists: const [],
    favoritePlaylistId: 0,
    nowPlaying: const NowPlayingSnapshot(playlistId: 0, songIds: []),
    hasLibrary: true,
    sortCriterion: MusicLibrarySortCriterion.title,
    albumsSort: AlbumSortCriterion.defaultSort,
    showCount: true,
    hideMultiSelectCommandBarAfterOperation: true,
    databasePath: '',
  );
}

const _mixedFavoriteGroupSnapshot = LibraryContentData(
  songs: [
    LibrarySong(
      id: 1,
      path: r'C:\Music\liked.mp3',
      title: 'Liked Song',
      artist: 'Artist A',
      artists: ['Artist A'],
      album: 'Blue Hour',
      duration: 120,
      playCount: 0,
      lyricsOffsetMs: 0,
      dateAdded: '2026-05-20T00:00:00',
      favorite: true,
      thumbnailPath: '',
    ),
    LibrarySong(
      id: 2,
      path: r'C:\Music\plain.mp3',
      title: 'Plain Song',
      artist: 'Artist A',
      artists: ['Artist A'],
      album: 'Blue Hour',
      duration: 121,
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
  nowPlaying: NowPlayingSnapshot(playlistId: 0, songIds: [99]),
  hasLibrary: true,
  sortCriterion: MusicLibrarySortCriterion.title,
  albumsSort: AlbumSortCriterion.defaultSort,
  showCount: true,
  hideMultiSelectCommandBarAfterOperation: true,
  databasePath: '',
);

const _allFavoriteGroupSnapshot = LibraryContentData(
  songs: [
    LibrarySong(
      id: 1,
      path: r'C:\Music\liked-1.mp3',
      title: 'Liked Song 1',
      artist: 'Artist A',
      artists: ['Artist A'],
      album: 'Blue Hour',
      duration: 120,
      playCount: 0,
      lyricsOffsetMs: 0,
      dateAdded: '2026-05-20T00:00:00',
      favorite: true,
      thumbnailPath: '',
    ),
    LibrarySong(
      id: 2,
      path: r'C:\Music\liked-2.mp3',
      title: 'Liked Song 2',
      artist: 'Artist A',
      artists: ['Artist A'],
      album: 'Blue Hour',
      duration: 121,
      playCount: 0,
      lyricsOffsetMs: 0,
      dateAdded: '2026-05-21T00:00:00',
      favorite: true,
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

const _unknownAlbumSnapshot = LibraryContentData(
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

List<LibrarySong> _countSongs(int count) {
  return [
    for (var index = 0; index < count; index += 1)
      LibrarySong(
        id: index + 1,
        path: r'C:\Music\count.mp3',
        title: 'Song ${index + 1}',
        artist: 'Count Artist',
        artists: const ['Count Artist'],
        album: 'Count Album',
        duration: 120,
        playCount: 0,
        lyricsOffsetMs: 0,
        dateAdded: '2026-05-20T00:00:00',
        favorite: false,
        thumbnailPath: '',
      ),
  ];
}

LibraryContentData _artistCountQuickJumpSnapshot() {
  return LibraryContentData(
    songs: [
      ..._artistSongsForCountJump('One', 1, 1),
      ..._artistSongsForCountJump('Twenty', 20, 100),
      ..._artistSongsForCountJump('Overflow', 21, 200),
    ],
    recentSongs: const [],
    recentPlaylists: const [],
    recentAlbums: const [],
    recentArtists: const [],
    recentSearches: const [],
    playlists: const [],
    favoritePlaylistId: 0,
    nowPlaying: const NowPlayingSnapshot(playlistId: 0, songIds: []),
    hasLibrary: true,
    sortCriterion: MusicLibrarySortCriterion.title,
    albumsSort: AlbumSortCriterion.defaultSort,
    showCount: true,
    hideMultiSelectCommandBarAfterOperation: true,
    databasePath: '',
  );
}

List<LibrarySong> _artistSongsForCountJump(
  String artist,
  int count,
  int startId,
) {
  return [
    for (var index = 0; index < count; index += 1)
      LibrarySong(
        id: startId + index,
        path: r'C:\Music\count-jump.mp3',
        title: '$artist Song ${index + 1}',
        artist: artist,
        artists: [artist],
        album: '$artist Album ${index + 1}',
        duration: 120,
        playCount: 0,
        lyricsOffsetMs: 0,
        dateAdded: '2026-05-20T00:00:00',
        favorite: false,
        thumbnailPath: '',
      ),
  ];
}

LibraryContentData _manyArtistsSnapshot() {
  return LibraryContentData(
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

LibraryContentData _manyAlbumsSnapshot() {
  return LibraryContentData(
    songs: [
      for (var index = 0; index < 20; index += 1)
        LibrarySong(
          id: index + 1,
          path: r'C:\Music\album.mp3',
          title: 'Album Song ${index.toString().padLeft(2, '0')}',
          artist: 'Artist A',
          artists: ['Artist A'],
          album: 'Album ${index.toString().padLeft(2, '0')}',
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
}

LibraryContentData _manyAlbumsTwoArtistsSnapshot() {
  return LibraryContentData(
    songs: [
      for (var index = 0; index < 20; index += 1)
        LibrarySong(
          id: index + 1,
          path: r'C:\Music\album.mp3',
          title: 'Album Song ${index.toString().padLeft(2, '0')}',
          artist: 'Artist A',
          artists: ['Artist A'],
          album: 'Album ${index.toString().padLeft(2, '0')}',
          duration: 120,
          playCount: 0,
          lyricsOffsetMs: 0,
          dateAdded: '2026-05-20T00:00:00',
          favorite: false,
          thumbnailPath: '',
        ),
      const LibrarySong(
        id: 101,
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
    favoritePlaylistId: 0,
    nowPlaying: NowPlayingSnapshot(playlistId: 0, songIds: []),
    hasLibrary: true,
    sortCriterion: MusicLibrarySortCriterion.title,
    albumsSort: AlbumSortCriterion.defaultSort,
    showCount: true,
    hideMultiSelectCommandBarAfterOperation: true,
    databasePath: '',
  );
}

LibraryContentData _manyAlbumsTwoLargeArtistsSnapshot() {
  return LibraryContentData(
    songs: [
      for (var index = 0; index < 20; index += 1)
        LibrarySong(
          id: index + 1,
          path: r'C:\Music\a-album.mp3',
          title: 'A Album Song ${index.toString().padLeft(2, '0')}',
          artist: 'Artist A',
          artists: ['Artist A'],
          album: 'A Album ${index.toString().padLeft(2, '0')}',
          duration: 120,
          playCount: 0,
          lyricsOffsetMs: 0,
          dateAdded: '2026-05-20T00:00:00',
          favorite: false,
          thumbnailPath: '',
        ),
      for (var index = 0; index < 20; index += 1)
        LibrarySong(
          id: index + 101,
          path: r'C:\Music\b-album.mp3',
          title: 'B Album Song ${index.toString().padLeft(2, '0')}',
          artist: 'Artist B',
          artists: ['Artist B'],
          album: 'B Album ${index.toString().padLeft(2, '0')}',
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
    favoritePlaylistId: 0,
    nowPlaying: NowPlayingSnapshot(playlistId: 0, songIds: []),
    hasLibrary: true,
    sortCriterion: MusicLibrarySortCriterion.title,
    albumsSort: AlbumSortCriterion.defaultSort,
    showCount: true,
    hideMultiSelectCommandBarAfterOperation: true,
    databasePath: '',
  );
}
