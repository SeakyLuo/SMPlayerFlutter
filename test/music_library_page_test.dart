import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
import 'package:smplayer_flutter/src/library/data/library_repository.dart';
import 'package:smplayer_flutter/src/library/ui/music_library_page.dart';
import 'package:smplayer_flutter/src/library/ui/page_selection_store.dart';
import 'package:smplayer_flutter/src/playback/media_control_model.dart';
import 'package:smplayer_flutter/src/playback/media_control_provider.dart';

void main() {
  setUp(PageSelectionController.clearStoredStates);

  const i18n = SmPlayerI18n(
    locale: 'en-US',
    messages: {
      'albums.addSelectedTo': 'Add To',
      'albums.clearSelection': 'Clear Selection',
      'albums.playSelected': 'Play Selected',
      'albums.reverseSelection': 'Reverse Selection',
      'albums.selectAll': 'Select All',
      'albums.selectedCount': '{count} selected',
      'common.albumUnknown': 'Unknown Album',
      'common.artistUnknown': 'Unknown Artist',
      'common.artistSeparator': ' / ',
      'common.cancel': 'Cancel',
      'common.myFavorites': 'My Favorites',
      'common.nowPlaying': 'Now Playing',
      'common.multiSelect': 'Multi Select',
      'common.play': 'Play',
      'common.songs': 'Songs',
      'common.undo': 'Undo',
      'common.favorite': 'Favorite',
      'common.artist': 'Artist',
      'common.album': 'Album',
      'common.duration': 'Duration',
      'common.playCount': 'Play Count',
      'common.dateAdded': 'Date Added',
      'context.addFavorite': 'Add Favorite',
      'context.addToPlaylist': 'Add To',
      'context.deleteFromDisk': 'Delete From Disk',
      'context.deleteSongConfirm': 'Delete {title}?',
      'context.hideFile': 'Hide File',
      'context.moveToFolder': 'Move To Folder',
      'context.pause': 'Pause',
      'context.play': 'Play',
      'context.playNext': 'Play Next',
      'context.removeFavorite': 'Remove Favorite',
      'context.seeAlbum': 'See Album',
      'context.seeAlbumArt': 'See Album Art',
      'context.seeArtist': 'See Artist',
      'context.seeLyrics': 'See Lyrics',
      'context.seeLocalFile': 'See In File Explorer',
      'context.seeMusicInfo': 'See Music Info',
      'context.select': 'Select',
      'context.view': 'View',
      'library.noSearchMatch': 'No results for {query}',
      'library.scanHelp': 'Scan music first.',
      'library.scanToBegin': 'Scan to begin',
      'library.tryAnotherSearch': 'Try another search.',
      'musicLibrary.titleHeader': 'Title',
      'notification.deletedFromDisk': 'Deleted {title} from disk',
      'notification.hiddenStorageItem': 'Hidden "{name}"',
      'notification.movedSong': 'Moved "{title}"',
      'nowPlaying.randomPlay': 'Shuffle',
      'player.more': 'More',
      'playlists.delete': 'Delete',
      'playlists.newPlaylist': 'New Playlist',
      'preferences.level.dislike': 'Dislike',
      'preferences.level.do-not-appear': 'Do Not Appear',
      'preferences.level.high': 'High',
      'preferences.level.higher': 'Higher',
      'preferences.level.normal': 'Normal',
      'preferences.level.very-high': 'Very High',
      'preferences.undoPrefer': 'Undo Prefer',
      'quickJump.disabled': 'No {basis} {target} starts with {group}',
      'quickJump.enabled': 'Jump to {basis} {target} starting with {group}',
      'quickJump.letterGroup': '{key}',
      'quickJump.symbolGroup': 'numbers or symbols',
      'remoteShare.libraryLoadFailed': 'Library failed',
      'settings.preferenceSettings': 'Preference Settings',
      'table.album': 'Album',
      'table.artist': 'Artist',
      'table.dateAdded': 'Date Added',
      'table.duration': 'Duration',
      'table.favorite': 'Favorite',
      'table.playCount': 'Play Count',
      'table.title': 'Title',
    },
  );

  test('PageSelectionController mirrors Electron range selection anchor', () {
    final selection = PageSelectionController<int>();

    selection.selectSingle(1);
    selection.selectWithModifiers(
      3,
      [1, 2, 3],
      extendSelection: true,
      rangeSelection: false,
    );
    selection.selectWithModifiers(
      2,
      [1, 2, 3],
      extendSelection: false,
      rangeSelection: true,
    );

    expect(selection.multiSelect, isTrue);
    expect(selection.selectedItems, {2, 3});
  });

  test('PageSelectionController stores page selection like Electron store', () {
    final selection = PageSelectionController<int>.stored('music-library');

    selection.selectSingle(1);
    selection.enterMultiSelect();

    final restored = PageSelectionController<int>.stored('music-library');

    expect(restored.multiSelect, isTrue);
    expect(restored.selectedItems, {1});
  });

  testWidgets('MusicLibraryPage supports Electron ctrl and shift selection', (
    tester,
  ) async {
    await tester.pumpWidget(
      _MusicLibraryTestApp(snapshot: _snapshot, i18n: i18n),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Blue Song'));
    await tester.pump(kDoubleTapTimeout);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.tap(find.text('Red Song'));
    await tester.pump(kDoubleTapTimeout);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    expect(find.text('2 selected'), findsOneWidget);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.tap(find.text('Green Song'));
    await tester.pump(kDoubleTapTimeout);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();

    expect(find.text('2 selected'), findsOneWidget);
  });

  testWidgets('MusicLibraryPage empty search state includes route query', (
    tester,
  ) async {
    await tester.pumpWidget(
      _MusicLibraryTestApp(
        snapshot: _emptySearchSnapshot,
        i18n: i18n,
        searchQuery: 'Jazz',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Jazz'), findsOneWidget);
    expect(find.text('Try another search.'), findsOneWidget);
  });

  testWidgets('MusicLibraryPage artist display follows Electron fallback', (
    tester,
  ) async {
    await tester.pumpWidget(
      _MusicLibraryTestApp(snapshot: _artistFallbackSnapshot, i18n: i18n),
    );
    await tester.pumpAndSettle();

    expect(find.text('Artist A'), findsWidgets);
    expect(find.text(' / '), findsWidgets);
    expect(find.text('Artist B'), findsWidgets);
  });

  testWidgets(
    'MusicLibraryPage reverses quick jump keys with descending sort',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1400, 800);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        _MusicLibraryTestApp(snapshot: _snapshot, i18n: i18n),
      );
      await tester.pumpAndSettle();

      expect(
        tester.getTopLeft(find.text('#')).dy,
        lessThan(tester.getTopLeft(find.text('Z')).dy),
      );

      await tester.tap(find.text('Title').first);
      await tester.pumpAndSettle();

      expect(
        tester.getTopLeft(find.text('Z')).dy,
        lessThan(tester.getTopLeft(find.text('#')).dy),
      );
    },
  );

  testWidgets('MusicLibraryPage quick jump active key follows scroll', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _MusicLibraryTestApp(snapshot: _quickJumpSnapshot, i18n: i18n),
    );
    await tester.pumpAndSettle();

    expect(_quickJumpRailBackground(tester, 'A'), isNot(Colors.transparent));
    expect(_quickJumpRailBackground(tester, 'R'), Colors.transparent);

    await tester.tap(
      find.byKey(const ValueKey('MusicLibrary.QuickJumpRail.R')),
    );
    await tester.pumpAndSettle();

    expect(_quickJumpRailBackground(tester, 'A'), Colors.transparent);
    expect(_quickJumpRailBackground(tester, 'R'), isNot(Colors.transparent));
  });

  testWidgets('MusicLibraryPage quick jump folds latin accents like Electron', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _MusicLibraryTestApp(snapshot: _accentQuickJumpSnapshot, i18n: i18n),
    );
    await tester.pumpAndSettle();

    expect(_quickJumpRailEnabled(tester, 'E'), isTrue);
    expect(_quickJumpRailEnabled(tester, '#'), isFalse);
  });

  testWidgets('MusicLibraryPage compact quick jump panel mirrors Electron', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(640, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _MusicLibraryTestApp(snapshot: _snapshot, i18n: i18n),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('MusicLibrary.QuickJumpPanel')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const ValueKey('MusicLibrary.QuickJumpToggle')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('MusicLibrary.QuickJumpPanel')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('MusicLibrary.QuickJumpPanel.R')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('MusicLibrary.QuickJumpPanel.R')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('MusicLibrary.QuickJumpPanel')),
      findsNothing,
    );
  });

  testWidgets('MusicLibraryPage compact sort bar uses Electron labels', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(640, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _MusicLibraryTestApp(snapshot: _snapshot, i18n: i18n),
    );
    await tester.pumpAndSettle();

    expect(find.text('Title'), findsOneWidget);
    expect(find.text('Artist'), findsWidgets);
    expect(find.text('Album'), findsWidgets);
    expect(find.text('Duration'), findsOneWidget);
    expect(find.text('Play Count'), findsOneWidget);
    expect(find.text('Date Added'), findsOneWidget);
  });

  testWidgets('MusicLibraryPage wide headers use Electron i18n keys', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final electronHeaderI18n = SmPlayerI18n(
      locale: i18n.locale,
      messages: {
        ...i18n.messages,
        'musicLibrary.titleHeader': 'Electron Title',
        'common.artist': 'Electron Artist',
        'common.album': 'Electron Album',
        'common.duration': 'Electron Duration',
        'common.playCount': 'Electron Play Count',
        'common.dateAdded': 'Electron Date Added',
        'table.title': 'Table Title',
        'table.artist': 'Table Artist',
        'table.album': 'Table Album',
        'table.duration': 'Table Duration',
        'table.playCount': 'Table Play Count',
        'table.dateAdded': 'Table Date Added',
      },
    );

    await tester.pumpWidget(
      _MusicLibraryTestApp(snapshot: _snapshot, i18n: electronHeaderI18n),
    );
    await tester.pumpAndSettle();

    expect(find.text('Electron Title'), findsOneWidget);
    expect(find.text('Electron Artist'), findsWidgets);
    expect(find.text('Electron Album'), findsWidgets);
    expect(find.text('Electron Duration'), findsOneWidget);
    expect(find.text('Electron Play Count'), findsOneWidget);
    expect(find.text('Electron Date Added'), findsOneWidget);
    expect(find.text('Table Play Count'), findsNothing);
    expect(find.text('Table Date Added'), findsNothing);
  });

  testWidgets('MusicLibraryPage resizes wide columns like Electron', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _MusicLibraryTestApp(snapshot: _snapshot, i18n: i18n),
    );
    await tester.pumpAndSettle();

    final titleHeader = find.byKey(const ValueKey('MusicLibrary.Header.title'));
    final initialWidth = tester.getSize(titleHeader).width;

    await tester.drag(
      find.byKey(const ValueKey('MusicLibrary.ColumnResizer.title')),
      const Offset(44, 0),
    );
    await tester.pumpAndSettle();

    expect(tester.getSize(titleHeader).width, greaterThan(initialWidth));
  });

  testWidgets('MusicLibraryPage duration display matches Electron hours', (
    tester,
  ) async {
    await tester.pumpWidget(
      _MusicLibraryTestApp(snapshot: _longDurationSnapshot, i18n: i18n),
    );
    await tester.pumpAndSettle();

    expect(find.text('1:01:01'), findsOneWidget);
    expect(find.text('61:01'), findsNothing);
  });

  testWidgets('MusicLibraryPage album sort uses Electron raw album order', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _MusicLibraryTestApp(snapshot: _unknownAlbumSortSnapshot, i18n: i18n),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.text('Unknown Album Song')).dy,
      lessThan(tester.getTopLeft(find.text('Alpha Album Song')).dy),
    );
  });

  testWidgets('MusicLibraryPage syncs Electron sort setting with selection', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final snapshot = ValueNotifier(_unknownAlbumTitleSortSnapshot);
    final repository = _ValueListenableLibraryRepository(snapshot);

    await tester.pumpWidget(
      _MusicLibrarySnapshotListenableTestApp(
        snapshot: snapshot,
        i18n: i18n,
        repository: repository,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Alpha Album Song'));
    await tester.pump(kDoubleTapTimeout);

    snapshot.value = _unknownAlbumSortSnapshot;
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.text('Unknown Album Song')).dy,
      lessThan(tester.getTopLeft(find.text('Alpha Album Song')).dy),
    );
  });

  testWidgets('MusicLibraryPage filters selected songs to visible songs', (
    tester,
  ) async {
    final snapshot = ValueNotifier(_snapshot);
    final repository = _ValueListenableLibraryRepository(snapshot);

    await tester.pumpWidget(
      _MusicLibrarySnapshotListenableTestApp(
        snapshot: snapshot,
        i18n: i18n,
        repository: repository,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Blue Song'));
    await tester.pump(kDoubleTapTimeout);
    expect(find.text('1 selected'), findsOneWidget);

    snapshot.value = _snapshotWithoutBlue;
    await tester.pumpAndSettle();

    expect(find.text('1 selected'), findsNothing);
    expect(find.text('Play Selected'), findsNothing);
    expect(repository.replacedNowPlaying, isEmpty);
  });

  testWidgets('MusicLibraryPage opens selection menu for selected songs', (
    tester,
  ) async {
    await tester.pumpWidget(
      _MusicLibraryTestApp(snapshot: _snapshot, i18n: i18n),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.tap(find.text('Blue Song'));
    await tester.pump(kDoubleTapTimeout);
    await tester.tap(find.text('Red Song'));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Red Song'), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();

    expect(find.text('Shuffle'), findsOneWidget);
    expect(find.text('Add To'), findsAtLeastNWidgets(1));
    expect(find.text('Mix'), findsNothing);

    await tester.tap(find.text('Add To').last);
    await tester.pumpAndSettle();

    expect(find.text('Now Playing'), findsOneWidget);
    expect(find.text('My Favorites'), findsOneWidget);
    expect(find.text('New Playlist'), findsOneWidget);
    expect(find.text('Mix'), findsOneWidget);
  });

  testWidgets('MusicLibraryPage single song menu uses Add To submenu', (
    tester,
  ) async {
    await tester.pumpWidget(
      _MusicLibraryTestApp(snapshot: _snapshot, i18n: i18n),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Blue Song'), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();

    expect(find.text('Add To'), findsAtLeastNWidgets(1));
    expect(find.text('Preference Settings'), findsOneWidget);
    expect(find.text('Delete From Disk'), findsOneWidget);
    expect(find.text('Hide File'), findsOneWidget);
    expect(find.text('View'), findsOneWidget);
    expect(find.text('Mix'), findsNothing);

    await tester.tap(find.text('Add To').last);
    await tester.pumpAndSettle();

    expect(find.text('Now Playing'), findsOneWidget);
    expect(find.text('My Favorites'), findsOneWidget);
    expect(find.text('New Playlist'), findsOneWidget);
    expect(find.text('Mix'), findsOneWidget);

    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Blue Song'), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('View'));
    await tester.pumpAndSettle();

    expect(find.text('See Lyrics'), findsOneWidget);
    expect(find.text('See Album Art'), findsOneWidget);
    expect(find.text('See In File Explorer'), findsOneWidget);
  });

  testWidgets('MusicLibraryPage song view menu opens MusicDialog', (
    tester,
  ) async {
    await tester.pumpWidget(
      _MusicLibraryTestApp(
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

  testWidgets('MusicLibraryPage multi-select play replaces Now Playing', (
    tester,
  ) async {
    final repository = _FakeLibraryRepository();
    final mediaController = MediaControlController();

    await tester.pumpWidget(
      _MusicLibraryTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: repository,
        mediaController: mediaController,
      ),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.tap(find.text('Blue Song'));
    await tester.pump(kDoubleTapTimeout);
    await tester.tap(find.text('Red Song'));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Play Selected'));
    await tester.pumpAndSettle();

    expect(repository.replacedNowPlaying, [1, 2]);
    expect(mediaController.state.track.id, 1);
    expect(mediaController.state.isPlaying, isTrue);
  });

  testWidgets('MusicLibraryPage keeps selection when Electron setting is off', (
    tester,
  ) async {
    final repository = _FakeLibraryRepository();
    final mediaController = MediaControlController();

    await tester.pumpWidget(
      _MusicLibraryTestApp(
        snapshot: _keepSelectionSnapshot,
        i18n: i18n,
        repository: repository,
        mediaController: mediaController,
      ),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.tap(find.text('Blue Song'));
    await tester.pump(kDoubleTapTimeout);
    await tester.tap(find.text('Red Song'));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(find.text('2 selected'), findsOneWidget);

    await tester.tap(find.text('Play Selected'));
    await tester.pumpAndSettle();

    expect(repository.replacedNowPlaying, [1, 2]);
    expect(find.text('2 selected'), findsOneWidget);
  });

  testWidgets('MusicLibraryPage double click adds next and starts playback', (
    tester,
  ) async {
    final repository = _FakeLibraryRepository();
    final mediaController = MediaControlController();

    await tester.pumpWidget(
      _MusicLibraryTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: repository,
        mediaController: mediaController,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Blue Song'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('Blue Song'));
    await tester.pumpAndSettle();

    expect(repository.replacedNowPlaying, [1]);
    expect(mediaController.state.track.id, 1);
    expect(mediaController.state.isPlaying, isTrue);
  });

  testWidgets('MusicLibraryPage favorite cell removes favorite directly', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final repository = _FakeLibraryRepository();

    await tester.pumpWidget(
      _MusicLibraryTestApp(
        snapshot: _favoriteSnapshot,
        i18n: i18n,
        repository: repository,
      ),
    );
    await tester.pumpAndSettle();

    final favoriteButton = find.ancestor(
      of: find.byTooltip('Favorite').first,
      matching: find.byType(IconButton),
    );
    tester.widget<IconButton>(favoriteButton).onPressed!();
    await tester.pumpAndSettle();

    expect(repository.favoriteSongIds, [1]);
    expect(repository.favoriteValue, isFalse);
  });

  testWidgets('MusicLibraryPage multi-select adds selected songs to playlist', (
    tester,
  ) async {
    final repository = _FakeLibraryRepository();

    await tester.pumpWidget(
      _MusicLibraryTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: repository,
      ),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.tap(find.text('Blue Song'));
    await tester.pump(kDoubleTapTimeout);
    await tester.tap(find.text('Red Song'));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add To').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mix'));
    await tester.pumpAndSettle();

    expect(repository.addedPlaylistId, 10);
    expect(repository.addedSongIds, [1, 2]);
  });

  testWidgets('MusicLibraryPage Add To updates now playing and favorites', (
    tester,
  ) async {
    final repository = _FakeLibraryRepository();

    await tester.pumpWidget(
      _MusicLibraryTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: repository,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Blue Song'), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add To').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Now Playing'));
    await tester.pumpAndSettle();

    expect(repository.replacedNowPlaying, [1]);

    await tester.tap(find.text('Blue Song'), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add To').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('My Favorites'));
    await tester.pumpAndSettle();

    expect(repository.favoriteSongIds, [1]);
    expect(repository.favoriteValue, isTrue);
  });

  testWidgets('MusicLibraryPage preference menu writes song preference', (
    tester,
  ) async {
    final repository = _FakeLibraryRepository();

    await tester.pumpWidget(
      _MusicLibraryTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: repository,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Blue Song'), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Preference Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('High'));
    await tester.pumpAndSettle();

    expect(repository.preferenceType, 'song');
    expect(repository.preferenceItemId, '1');
    expect(repository.preferenceName, 'Blue Song');
    expect(repository.preferenceLevel, 'high');
  });

  testWidgets('MusicLibraryPage right menu hides a song file', (tester) async {
    final repository = _FakeLibraryRepository();

    await tester.pumpWidget(
      _MusicLibraryTestApp(
        snapshot: _foldersSnapshot,
        i18n: i18n,
        repository: repository,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Blue Song'), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hide File'));
    await tester.pump();

    expect(repository.hiddenSongId, 1);
    expect(find.text('Undo'), findsOneWidget);
  });

  testWidgets('MusicLibraryPage right menu uses pending delete undo flow', (
    tester,
  ) async {
    final repository = _FakeLibraryRepository();

    await tester.pumpWidget(
      _MusicLibraryTestApp(
        snapshot: _foldersSnapshot,
        i18n: i18n,
        repository: repository,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Blue Song'), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete From Disk'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(repository.pendingDeletedSongId, 1);
    expect(find.text('Undo'), findsOneWidget);
  });

  testWidgets('MusicLibraryPage Move To Folder passes Electron folder path', (
    tester,
  ) async {
    final repository = _FakeLibraryRepository();

    await tester.pumpWidget(
      _MusicLibraryTestApp(
        snapshot: _foldersSnapshot,
        i18n: i18n,
        repository: repository,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Blue Song'), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move To Folder'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Target'));
    await tester.pumpAndSettle();

    expect(repository.movedSongId, 1);
    expect(repository.movedFolderPath, r'C:\Music\Target');
  });

  testWidgets('MusicLibraryPage artist link opens the Electron artist route', (
    tester,
  ) async {
    final router = _createMusicLibraryRouter();

    await tester.pumpWidget(
      _MusicLibraryRouterTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        router: router,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('MusicLibrary.ArtistLink.Artist A')),
    );
    await tester.pumpAndSettle();

    final uri = router.routeInformationProvider.value.uri;
    expect(uri.path, '/artists');
    expect(uri.queryParameters['artist'], 'Artist A');
  });

  testWidgets('MusicLibraryPage album link opens the Electron album route', (
    tester,
  ) async {
    final router = _createMusicLibraryRouter();

    await tester.pumpWidget(
      _MusicLibraryRouterTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        router: router,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('MusicLibrary.AlbumLink.Blue Hour')),
    );
    await tester.pumpAndSettle();

    final uri = router.routeInformationProvider.value.uri;
    expect(uri.path, '/albums');
    expect(uri.queryParameters['album'], 'Blue Hour');
  });
}

Color? _quickJumpRailBackground(WidgetTester tester, String key) {
  final button = tester.widget<TextButton>(
    find.byKey(ValueKey('MusicLibrary.QuickJumpRail.$key')),
  );
  return button.style?.backgroundColor?.resolve({});
}

bool _quickJumpRailEnabled(WidgetTester tester, String key) {
  final button = tester.widget<TextButton>(
    find.byKey(ValueKey('MusicLibrary.QuickJumpRail.$key')),
  );
  return button.onPressed != null;
}

GoRouter _createMusicLibraryRouter() {
  return GoRouter(
    initialLocation: '/music-library',
    routes: [
      GoRoute(
        path: '/music-library',
        builder: (context, state) => const Scaffold(body: MusicLibraryPage()),
      ),
      GoRoute(
        path: '/artists',
        builder:
            (context, state) =>
                Scaffold(body: Text(state.uri.queryParameters['artist'] ?? '')),
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

class _MusicLibraryRouterTestApp extends StatelessWidget {
  const _MusicLibraryRouterTestApp({
    required this.snapshot,
    required this.i18n,
    required this.router,
  });

  final MusicLibrarySnapshot snapshot;
  final SmPlayerI18n i18n;
  final GoRouter router;

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

class _MusicLibraryTestApp extends StatelessWidget {
  const _MusicLibraryTestApp({
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
          home: Scaffold(body: MusicLibraryPage(searchQuery: searchQuery)),
        ),
      ),
    );
  }
}

class _MusicLibrarySnapshotListenableTestApp extends StatelessWidget {
  const _MusicLibrarySnapshotListenableTestApp({
    required this.snapshot,
    required this.i18n,
    required this.repository,
  });

  final ValueNotifier<MusicLibrarySnapshot> snapshot;
  final SmPlayerI18n i18n;
  final _ValueListenableLibraryRepository repository;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        smPlayerI18nProvider.overrideWith((ref) async => i18n),
        libraryRepositoryProvider.overrideWithValue(repository),
      ],
      child: SmPlayerI18nScope(
        i18n: i18n,
        child: _MusicLibrarySnapshotInvalidator(snapshot: snapshot),
      ),
    );
  }
}

class _MusicLibrarySnapshotInvalidator extends ConsumerStatefulWidget {
  const _MusicLibrarySnapshotInvalidator({required this.snapshot});

  final ValueNotifier<MusicLibrarySnapshot> snapshot;

  @override
  ConsumerState<_MusicLibrarySnapshotInvalidator> createState() =>
      _MusicLibrarySnapshotInvalidatorState();
}

class _MusicLibrarySnapshotInvalidatorState
    extends ConsumerState<_MusicLibrarySnapshotInvalidator> {
  @override
  void initState() {
    super.initState();
    widget.snapshot.addListener(_invalidateSnapshot);
  }

  @override
  void didUpdateWidget(_MusicLibrarySnapshotInvalidator oldWidget) {
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
    return const MaterialApp(home: Scaffold(body: MusicLibraryPage()));
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
  String? preferenceType;
  String? preferenceItemId;
  String? preferenceName;
  String? preferenceLevel;
  int? pendingDeletedSongId;
  final committedDeleteIds = <String>[];
  final undoneDeleteIds = <String>[];
  int? hiddenSongId;
  int? movedSongId;
  String? movedFolderPath;

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
  Future<PendingSongDelete> beginDeleteSongFromDisk(int songId) async {
    pendingDeletedSongId = songId;
    return PendingSongDelete(id: 'pending-$songId', songId: songId);
  }

  @override
  Future<void> commitDeleteSongFromDisk(String deleteId) async {
    committedDeleteIds.add(deleteId);
  }

  @override
  Future<void> undoDeleteSongFromDisk(String deleteId) async {
    undoneDeleteIds.add(deleteId);
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
  Future<void> undoMoveLocalItems(LocalItemsMoveResult result) async {
    movedSongId = null;
    movedFolderPath = null;
  }

  @override
  Future<LocalItemsMoveResult> moveSongToFolder(
    int songId,
    String folderPath,
  ) async {
    movedSongId = songId;
    movedFolderPath = folderPath;
    return LocalItemsMoveResult(
      songs: [
        LocalSongMove(
          id: songId,
          oldPath: 'old-$songId.mp3',
          newPath: '$folderPath/$songId.mp3',
        ),
      ],
      folders: const [],
    );
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
      album: 'Blue Album',
      albumArtist: '',
      publisher: '',
      trackNumber: 0,
      year: 0,
      genre: '',
      composers: '',
      duration: 180,
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

class _ValueListenableLibraryRepository extends _FakeLibraryRepository {
  _ValueListenableLibraryRepository(this.snapshot);

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
    LibrarySong(
      id: 2,
      path: r'C:\Music\red.mp3',
      title: 'Red Song',
      artist: 'Artist B',
      artists: ['Artist B'],
      album: 'Red Days',
      duration: 120,
      playCount: 0,
      lyricsOffsetMs: 0,
      dateAdded: '2026-05-20T00:00:00',
      favorite: false,
      thumbnailPath: '',
    ),
    LibrarySong(
      id: 3,
      path: r'C:\Music\green.mp3',
      title: 'Green Song',
      artist: 'Artist C',
      artists: ['Artist C'],
      album: 'Green Rooms',
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
      id: 10,
      name: 'Mix',
      priority: 0,
      songCount: 0,
      songIds: [],
      sortCriterion: PlaylistSortCriterion.title,
      isBuiltIn: false,
    ),
  ],
  favoritePlaylistId: 1,
  nowPlaying: NowPlayingSnapshot(playlistId: 0, songIds: []),
  hasLibrary: true,
  sortCriterion: MusicLibrarySortCriterion.title,
  albumsSort: AlbumSortCriterion.defaultSort,
  showCount: true,
  hideMultiSelectCommandBarAfterOperation: true,
  databasePath: '',
);

final _snapshotWithoutBlue = MusicLibrarySnapshot(
  songs: _snapshot.songs.where((song) => song.id != 1).toList(),
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
  hideMultiSelectCommandBarAfterOperation:
      _snapshot.hideMultiSelectCommandBarAfterOperation,
  databasePath: _snapshot.databasePath,
);

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

final _quickJumpSnapshot = MusicLibrarySnapshot(
  songs: _quickJumpSongs,
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
  hideMultiSelectCommandBarAfterOperation:
      _snapshot.hideMultiSelectCommandBarAfterOperation,
  databasePath: _snapshot.databasePath,
);

final _quickJumpSongs = List.generate(40, (index) {
  final letter =
      index < 26 ? String.fromCharCode('A'.codeUnitAt(0) + index) : 'Z';
  return LibrarySong(
    id: 100 + index,
    path:
        r'C:\Music\quick-jump-'
        '$index.mp3',
    title: '$letter Song $index',
    artist: 'Artist $letter',
    artists: ['Artist $letter'],
    album: '$letter Album',
    duration: 120,
    playCount: 0,
    lyricsOffsetMs: 0,
    dateAdded: '2026-05-20T00:00:00',
    favorite: false,
    thumbnailPath: '',
  );
});

const _accentQuickJumpSnapshot = MusicLibrarySnapshot(
  songs: [
    LibrarySong(
      id: 200,
      path: r'C:\Music\eclair.mp3',
      title: 'Éclair Song',
      artist: 'Éclair Artist',
      artists: ['Éclair Artist'],
      album: 'Éclair Album',
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
  favoritePlaylistId: 1,
  nowPlaying: NowPlayingSnapshot(playlistId: 0, songIds: []),
  hasLibrary: true,
  sortCriterion: MusicLibrarySortCriterion.title,
  albumsSort: AlbumSortCriterion.defaultSort,
  showCount: true,
  hideMultiSelectCommandBarAfterOperation: true,
  databasePath: '',
);

const _longDurationSnapshot = MusicLibrarySnapshot(
  songs: [
    LibrarySong(
      id: 300,
      path: r'C:\Music\long.mp3',
      title: 'Long Song',
      artist: 'Artist A',
      artists: ['Artist A'],
      album: 'Long Album',
      duration: 3661,
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
  favoritePlaylistId: 1,
  nowPlaying: NowPlayingSnapshot(playlistId: 0, songIds: []),
  hasLibrary: true,
  sortCriterion: MusicLibrarySortCriterion.title,
  albumsSort: AlbumSortCriterion.defaultSort,
  showCount: true,
  hideMultiSelectCommandBarAfterOperation: true,
  databasePath: '',
);

const _unknownAlbumSortSnapshot = MusicLibrarySnapshot(
  songs: [
    LibrarySong(
      id: 30,
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
    LibrarySong(
      id: 31,
      path: r'C:\Music\unknown.mp3',
      title: 'Unknown Album Song',
      artist: 'Artist A',
      artists: ['Artist A'],
      album: '',
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
  favoritePlaylistId: 1,
  nowPlaying: NowPlayingSnapshot(playlistId: 0, songIds: []),
  hasLibrary: true,
  sortCriterion: MusicLibrarySortCriterion.album,
  albumsSort: AlbumSortCriterion.defaultSort,
  showCount: true,
  hideMultiSelectCommandBarAfterOperation: true,
  databasePath: '',
);

final _unknownAlbumTitleSortSnapshot = MusicLibrarySnapshot(
  songs: _unknownAlbumSortSnapshot.songs,
  recentSongs: _unknownAlbumSortSnapshot.recentSongs,
  recentPlaylists: _unknownAlbumSortSnapshot.recentPlaylists,
  recentAlbums: _unknownAlbumSortSnapshot.recentAlbums,
  recentArtists: _unknownAlbumSortSnapshot.recentArtists,
  recentSearches: _unknownAlbumSortSnapshot.recentSearches,
  playlists: _unknownAlbumSortSnapshot.playlists,
  favoritePlaylistId: _unknownAlbumSortSnapshot.favoritePlaylistId,
  nowPlaying: _unknownAlbumSortSnapshot.nowPlaying,
  hasLibrary: _unknownAlbumSortSnapshot.hasLibrary,
  sortCriterion: MusicLibrarySortCriterion.title,
  albumsSort: _unknownAlbumSortSnapshot.albumsSort,
  showCount: _unknownAlbumSortSnapshot.showCount,
  hideMultiSelectCommandBarAfterOperation:
      _unknownAlbumSortSnapshot.hideMultiSelectCommandBarAfterOperation,
  databasePath: _unknownAlbumSortSnapshot.databasePath,
);

final _foldersSnapshot = MusicLibrarySnapshot(
  songs: _snapshot.songs,
  recentSongs: _snapshot.recentSongs,
  recentPlaylists: _snapshot.recentPlaylists,
  recentAlbums: _snapshot.recentAlbums,
  recentArtists: _snapshot.recentArtists,
  recentSearches: _snapshot.recentSearches,
  playlists: _snapshot.playlists,
  folders: const [
    LibraryFolder(id: 20, path: r'C:\Music', parentId: 0, criterion: 0),
    LibraryFolder(id: 21, path: r'C:\Music\Target', parentId: 20, criterion: 0),
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

const _favoriteSnapshot = MusicLibrarySnapshot(
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
      favorite: true,
      thumbnailPath: '',
    ),
  ],
  recentSongs: [],
  recentPlaylists: [],
  recentAlbums: [],
  recentArtists: [],
  recentSearches: [],
  playlists: [],
  favoritePlaylistId: 1,
  nowPlaying: NowPlayingSnapshot(playlistId: 0, songIds: []),
  hasLibrary: true,
  sortCriterion: MusicLibrarySortCriterion.title,
  albumsSort: AlbumSortCriterion.defaultSort,
  showCount: true,
  hideMultiSelectCommandBarAfterOperation: true,
  databasePath: '',
);

const _emptySearchSnapshot = MusicLibrarySnapshot(
  songs: [],
  recentSongs: [],
  recentPlaylists: [],
  recentAlbums: [],
  recentArtists: [],
  recentSearches: [],
  playlists: [],
  favoritePlaylistId: 1,
  nowPlaying: NowPlayingSnapshot(playlistId: 0, songIds: []),
  hasLibrary: true,
  sortCriterion: MusicLibrarySortCriterion.title,
  albumsSort: AlbumSortCriterion.defaultSort,
  showCount: true,
  hideMultiSelectCommandBarAfterOperation: true,
  databasePath: '',
);

const _artistFallbackSnapshot = MusicLibrarySnapshot(
  songs: [
    LibrarySong(
      id: 4,
      path: r'C:\Music\duet.mp3',
      title: 'Duet Song',
      artist: 'Artist A; Artist B',
      artists: [],
      album: 'Duet Album',
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
  favoritePlaylistId: 1,
  nowPlaying: NowPlayingSnapshot(playlistId: 0, songIds: []),
  hasLibrary: true,
  sortCriterion: MusicLibrarySortCriterion.title,
  albumsSort: AlbumSortCriterion.defaultSort,
  showCount: true,
  hideMultiSelectCommandBarAfterOperation: true,
  databasePath: '',
);
