import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:smplayer_flutter/src/app/app_appearance_model.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
import 'package:smplayer_flutter/src/library/data/library_repository.dart';
import 'package:smplayer_flutter/src/library/ui/music_library_page.dart';
import 'package:smplayer_flutter/src/library/ui/my_favorites_page.dart';
import 'package:smplayer_flutter/src/library/ui/page_selection_store.dart';
import 'package:smplayer_flutter/src/playback/media_control_model.dart';
import 'package:smplayer_flutter/src/playback/media_control_provider.dart';
import 'package:smplayer_flutter/src/settings/settings_model.dart'
    show LyricsRequestMode, SettingsSnapshot;

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

    await tester.tap(find.text('Red Song'), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    expect(find.text('Shuffle'), findsOneWidget);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.tap(find.text('Green Song'));
    await tester.pump(kDoubleTapTimeout);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Green Song'), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    expect(find.text('Shuffle'), findsOneWidget);
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

  testWidgets('MusicLibraryPage quick jump keeps clicked tail key active', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _MusicLibraryTestApp(snapshot: _tailQuickJumpSnapshot, i18n: i18n),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('MusicLibrary.QuickJumpRail.Z')),
    );
    await tester.pumpAndSettle();

    expect(_quickJumpRailBackground(tester, 'T'), Colors.transparent);
    expect(_quickJumpRailBackground(tester, 'Z'), isNot(Colors.transparent));
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

  testWidgets(
    'MusicLibraryPage compact quick jump panel uses Electron night colors',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(640, 900);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        _MusicLibraryTestApp(
          snapshot: _snapshot,
          i18n: i18n,
          brightness: Brightness.dark,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('MusicLibrary.QuickJumpToggle')),
      );
      await tester.pumpAndSettle();

      final panelDecoration =
          tester
                  .widget<DecoratedBox>(
                    find
                        .descendant(
                          of: find.byKey(
                            const ValueKey('MusicLibrary.QuickJumpPanel'),
                          ),
                          matching: find.byType(DecoratedBox),
                        )
                        .first,
                  )
                  .decoration
              as BoxDecoration;
      expect(panelDecoration.color, const Color(0xf5101419));
      expect(panelDecoration.boxShadow?.single.color, const Color(0x5c000000));

      final enabledButton = tester.widget<TextButton>(
        find.byKey(const ValueKey('MusicLibrary.QuickJumpPanel.R')),
      );
      expect(
        enabledButton.style?.backgroundColor?.resolve({}),
        const Color(0xff1d232b),
      );
      expect(
        enabledButton.style?.foregroundColor?.resolve({}),
        const Color(0xadcbd5e1),
      );
      expect(
        enabledButton.style?.side?.resolve({})?.color,
        const Color(0x1fd6e0ec),
      );
      expect(
        enabledButton.style?.backgroundColor?.resolve({WidgetState.hovered}),
        const Color(0x2e0078d7),
      );
      expect(
        enabledButton.style?.foregroundColor?.resolve({WidgetState.hovered}),
        Colors.white,
      );
      expect(
        enabledButton.style?.side?.resolve({WidgetState.hovered})?.color,
        const Color(0x570078d7),
      );

      final disabledButton = tester.widget<TextButton>(
        find.byKey(const ValueKey('MusicLibrary.QuickJumpPanel.#')),
      );
      expect(
        disabledButton.style?.backgroundColor?.resolve({WidgetState.disabled}),
        Colors.transparent,
      );
      expect(
        disabledButton.style?.foregroundColor?.resolve({WidgetState.disabled}),
        const Color(0x3dcbd5e1),
      );
    },
  );

  testWidgets('MusicLibraryPage main content uses Electron night colors', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _MusicLibraryTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        brightness: Brightness.dark,
      ),
    );
    await tester.pumpAndSettle();

    final shellDecoration =
        tester
                .widget<DecoratedBox>(
                  find.byKey(const ValueKey('MusicLibrary.ContentShell')),
                )
                .decoration
            as BoxDecoration;
    expect(shellDecoration.color, const Color(0xff171c22));
    expect(shellDecoration.gradient, isA<LinearGradient>());
    expect(shellDecoration.border?.top.color, const Color(0x1fd6e0ec));
    expect(shellDecoration.boxShadow?.single.color, const Color(0x57000000));

    final header = tester.widget<Container>(
      find.byKey(const ValueKey('MusicLibrary.TableHeader')),
    );
    expect(header.color, const Color(0xff171c22));

    final rowFinder = find.byKey(const ValueKey('MusicLibrary.Row.1'));
    var rowDecoration =
        tester.widget<Container>(rowFinder).decoration as BoxDecoration;
    expect(rowDecoration.border?.top.color, const Color(0x1fd6e0ec));

    final title = tester.widget<Text>(
      find.descendant(of: rowFinder, matching: find.text('Blue Song')),
    );
    expect(title.style?.color, const Color(0xeff6f9fc));

    final artist = tester.widget<Text>(
      find.descendant(of: rowFinder, matching: find.text('Artist A')),
    );
    expect(artist.style?.color, const Color(0xff459de2));

    await tester.tap(find.text('Blue Song'));
    await tester.pumpAndSettle();

    rowDecoration =
        tester.widget<Container>(rowFinder).decoration as BoxDecoration;
    expect(rowDecoration.color, const Color(0x2e0078d7));
  });

  testWidgets('MusicLibraryPage wide song row hover reveals artwork action', (
    tester,
  ) async {
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

    final rowFinder = find.byKey(const ValueKey('MusicLibrary.Row.1'));
    final playOpacityFinder =
        find
            .ancestor(
              of: find.byKey(const ValueKey('MusicLibrary.ArtworkPlay.1')),
              matching: find.byType(AnimatedOpacity),
            )
            .first;
    final favoriteActionOpacityFinder =
        find
            .ancestor(
              of: find.byKey(const ValueKey('MusicLibrary.FavoriteAction.1')),
              matching: find.byType(AnimatedOpacity),
            )
            .first;

    expect(tester.widget<AnimatedOpacity>(playOpacityFinder).opacity, 0);
    expect(
      tester.widget<AnimatedOpacity>(favoriteActionOpacityFinder).opacity,
      0,
    );
    var rowDecoration =
        tester.widget<Container>(rowFinder).decoration as BoxDecoration;
    expect(rowDecoration.color, Colors.transparent);

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer();
    await gesture.moveTo(tester.getCenter(rowFinder));
    await tester.pumpAndSettle();

    expect(tester.widget<AnimatedOpacity>(playOpacityFinder).opacity, 1);
    expect(
      tester.widget<AnimatedOpacity>(favoriteActionOpacityFinder).opacity,
      1,
    );
    rowDecoration =
        tester.widget<Container>(rowFinder).decoration as BoxDecoration;
    expect(rowDecoration.color, const Color(0xffeaf6ff));
    expect(
      find.byKey(const ValueKey('MusicLibrary.FavoriteAction.1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('MusicLibrary.AddToAction.1')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('MusicLibrary.PlayNextAction.1')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('MusicLibrary.MoreAction.1')),
      findsNothing,
    );

    await gesture.removePointer();
  });

  testWidgets(
    'MusicLibraryPage compact song row hover reveals artwork action',
    (tester) async {
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

      final rowFinder = find.byKey(const ValueKey('MusicLibrary.CompactRow.1'));
      final playOpacityFinder =
          find
              .ancestor(
                of: find.byKey(const ValueKey('MusicLibrary.ArtworkPlay.1')),
                matching: find.byType(AnimatedOpacity),
              )
              .first;
      final actionsOpacityFinder =
          find
              .ancestor(
                of: find.byKey(const ValueKey('MusicLibrary.RowActions.1')),
                matching: find.byType(AnimatedOpacity),
              )
              .first;

      expect(tester.widget<AnimatedOpacity>(playOpacityFinder).opacity, 0);
      expect(tester.widget<AnimatedOpacity>(actionsOpacityFinder).opacity, 0);
      var rowDecoration =
          tester.widget<Container>(rowFinder).decoration as BoxDecoration;
      expect(rowDecoration.color, Colors.transparent);

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer();
      await gesture.moveTo(tester.getCenter(rowFinder));
      await tester.pumpAndSettle();

      expect(tester.widget<AnimatedOpacity>(playOpacityFinder).opacity, 1);
      expect(tester.widget<AnimatedOpacity>(actionsOpacityFinder).opacity, 1);
      rowDecoration =
          tester.widget<Container>(rowFinder).decoration as BoxDecoration;
      expect(rowDecoration.color, const Color(0xffeaf6ff));
      expect(
        find.byKey(const ValueKey('MusicLibrary.MoreAction.1')),
        findsOneWidget,
      );

      await gesture.removePointer();
    },
  );

  testWidgets('MusicLibraryPage hover actions run song commands', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(640, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final repository = _FakeLibraryRepository();

    await tester.pumpWidget(
      _MusicLibraryTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: repository,
      ),
    );
    await tester.pumpAndSettle();

    final rowFinder = find.byKey(const ValueKey('MusicLibrary.CompactRow.1'));
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer();
    await gesture.moveTo(tester.getCenter(rowFinder));
    await tester.pumpAndSettle();

    tester
        .widget<IconButton>(
          find
              .descendant(
                of: find.byKey(const ValueKey('MusicLibrary.PlayNextAction.1')),
                matching: find.byType(IconButton),
              )
              .first,
        )
        .onPressed!();
    await tester.pumpAndSettle();
    expect(repository.replacedNowPlaying, [1]);

    tester
        .widget<IconButton>(
          find
              .descendant(
                of: find.byKey(const ValueKey('MusicLibrary.MoreAction.1')),
                matching: find.byType(IconButton),
              )
              .first,
        )
        .onPressed!();
    await tester.pumpAndSettle();
    expect(find.text('Play'), findsOneWidget);
    await tester.tapAt(Offset.zero);
    await tester.pumpAndSettle();
    await gesture.moveTo(tester.getCenter(rowFinder));
    await tester.pumpAndSettle();

    tester
        .widget<IconButton>(
          find
              .descendant(
                of: find.byKey(const ValueKey('MusicLibrary.FavoriteAction.1')),
                matching: find.byType(IconButton),
              )
              .first,
        )
        .onPressed!();
    await tester.pumpAndSettle();
    expect(repository.favoriteSongIds, [1]);
    expect(repository.favoriteValue, isTrue);

    tester
        .widget<IconButton>(
          find
              .descendant(
                of: find.byKey(const ValueKey('MusicLibrary.AddToAction.1')),
                matching: find.byType(IconButton),
              )
              .first,
        )
        .onPressed!();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mix'));
    await tester.pumpAndSettle();
    expect(repository.addedPlaylistId, 10);
    expect(repository.addedSongIds, [1]);

    await gesture.removePointer();
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('MusicLibraryPage empty state uses Electron night colors', (
    tester,
  ) async {
    await tester.pumpWidget(
      _MusicLibraryTestApp(
        snapshot: _emptySearchSnapshot,
        i18n: i18n,
        searchQuery: 'Jazz',
        brightness: Brightness.dark,
      ),
    );
    await tester.pumpAndSettle();

    final decoration =
        tester
                .widget<DecoratedBox>(
                  find.byKey(const ValueKey('MusicLibrary.EmptyState')),
                )
                .decoration
            as BoxDecoration;
    expect(decoration.color, const Color(0xdb171c22));
    expect(decoration.border?.top.color, const Color(0x1fd6e0ec));

    final title = tester.widget<Text>(find.textContaining('Jazz'));
    expect(title.style?.color, const Color(0xeff6f9fc));
  });

  testWidgets(
    'MusicLibraryPage compact quick jump panel closes on outside tap',
    (tester) async {
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

      await tester.tap(
        find.byKey(const ValueKey('MusicLibrary.QuickJumpToggle')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('MusicLibrary.QuickJumpPanel')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('MusicLibrary.QuickJumpDismissBarrier')),
        findsOneWidget,
      );

      await tester.tapAt(const Offset(320, 760));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('MusicLibrary.QuickJumpPanel')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('MusicLibrary.QuickJumpDismissBarrier')),
        findsNothing,
      );
    },
  );

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
    expect(
      tester
          .getSize(find.byKey(const ValueKey('MusicLibrary.Header.favorite')))
          .width,
      96,
    );
  });

  testWidgets('MusicLibraryPage sorted wide header has selected background', (
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

    final titleButton = tester.widget<TextButton>(
      find.descendant(
        of: find.byKey(const ValueKey('MusicLibrary.Header.title')),
        matching: find.byType(TextButton),
      ),
    );
    final artistButton = tester.widget<TextButton>(
      find.descendant(
        of: find.byKey(const ValueKey('MusicLibrary.Header.artist')),
        matching: find.byType(TextButton),
      ),
    );

    expect(
      titleButton.style?.backgroundColor?.resolve({}),
      const Color(0x1a0078d7),
    );
    expect(
      artistButton.style?.backgroundColor?.resolve({}),
      Colors.transparent,
    );
  });

  testWidgets('MusicLibraryPage wide table shows zero play count', (
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

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('MusicLibrary.Row.1')),
        matching: find.text('0'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('MusicLibraryPage favorite column cannot resize', (tester) async {
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

    expect(
      find.byKey(const ValueKey('MusicLibrary.ColumnResizer.favorite')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('MusicLibrary.ColumnResizer.artwork')),
      findsOneWidget,
    );
  });

  testWidgets(
    'MusicLibraryPage wide table header stays fixed while rows scroll',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1400, 520);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        _MusicLibraryTestApp(snapshot: _quickJumpSnapshot, i18n: i18n),
      );
      await tester.pumpAndSettle();

      final header = find.byKey(const ValueKey('MusicLibrary.TableHeader'));
      final visibleRow = find.byKey(const ValueKey('MusicLibrary.Row.107'));
      final headerTop = tester.getTopLeft(header).dy;
      final visibleRowTop = tester.getTopLeft(visibleRow).dy;

      await tester.dragFrom(
        tester.getTopLeft(visibleRow) + const Offset(20, 20),
        const Offset(0, -260),
      );
      await tester.pumpAndSettle();

      expect(tester.getTopLeft(header).dy, headerTop);
      expect(tester.getTopLeft(visibleRow).dy, lessThan(visibleRowTop));
    },
  );

  testWidgets('MusicLibraryPage wide table scrollbar stays on card edge', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 520);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _MusicLibraryTestApp(snapshot: _quickJumpSnapshot, i18n: i18n),
    );
    await tester.pumpAndSettle();

    final header = find.byKey(const ValueKey('MusicLibrary.TableHeader'));
    final thumb = find.byKey(const ValueKey('MusicLibrary.ScrollbarThumb'));
    final visibleRow = find.byKey(const ValueKey('MusicLibrary.Row.107'));
    final shellRight =
        tester
            .getTopRight(
              find.byKey(const ValueKey('MusicLibrary.ContentShell')),
            )
            .dx;
    final thumbRight = tester.getTopRight(thumb).dx;
    final visibleRowTop = tester.getTopLeft(visibleRow).dy;

    expect(shellRight - thumbRight, inInclusiveRange(0, 20));

    await tester.dragFrom(
      tester.getTopLeft(header) + const Offset(360, 20),
      const Offset(-260, 0),
    );
    await tester.pumpAndSettle();

    expect(tester.getTopRight(thumb).dx, thumbRight);

    await tester.drag(thumb, const Offset(0, 80));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(visibleRow).dy, lessThan(visibleRowTop));
  });

  testWidgets('MusicLibraryPage wide table virtualizes rows', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _MusicLibraryTestApp(snapshot: _virtualizedTableSnapshot, i18n: i18n),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('MusicLibrary.Row.5000')), findsOneWidget);
    expect(find.byKey(const ValueKey('MusicLibrary.Row.5499')), findsNothing);
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

  testWidgets('MusicLibraryPage current row shows Electron playing wave', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final mediaController = MediaControlController();
    mediaController.playTrack(
      const MediaControlTrack(
        id: 1,
        title: 'Blue Hour',
        artist: 'Artist A',
        artworkUrl: '',
        isLoading: false,
      ),
      durationSeconds: 180,
    );

    await tester.pumpWidget(
      _MusicLibraryTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        mediaController: mediaController,
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('MusicLibrary.Playing.1.Wave')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('MusicLibrary.Playing.1.Backdrop')),
      findsOneWidget,
    );
    final rowFinder = find.byKey(const ValueKey('MusicLibrary.Row.1'));
    final rowDecoration =
        tester.widget<Container>(rowFinder).decoration as BoxDecoration;
    expect(rowDecoration.color, const Color(0x1f0078d7));

    final title = tester.widget<Text>(
      find.descendant(of: rowFinder, matching: find.text('Blue Song')),
    );
    expect(title.style?.color, const Color(0xff0063b1));

    final artist = tester.widget<Text>(
      find.descendant(of: rowFinder, matching: find.text('Artist A')),
    );
    expect(artist.style?.color, const Color(0xff0063b1));

    final firstHeight = _playingBarHeight(tester, 'MusicLibrary.Playing.1', 0);
    await tester.pump(const Duration(milliseconds: 390));

    expect(
      _playingBarHeight(tester, 'MusicLibrary.Playing.1', 0),
      isNot(firstHeight),
    );
  });

  testWidgets('MusicLibraryPage compact current row highlights full row', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(640, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final mediaController = MediaControlController();
    mediaController.playTrack(
      const MediaControlTrack(
        id: 1,
        title: 'Blue Hour',
        artist: 'Artist A',
        artworkUrl: '',
        isLoading: false,
      ),
      durationSeconds: 180,
    );

    await tester.pumpWidget(
      _MusicLibraryTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        mediaController: mediaController,
      ),
    );
    await tester.pump();

    final rowFinder = find.byKey(const ValueKey('MusicLibrary.CompactRow.1'));
    final rowDecoration =
        tester.widget<Container>(rowFinder).decoration as BoxDecoration;
    expect(rowDecoration.color, const Color(0x1f0078d7));

    final title = tester.widget<Text>(
      find.descendant(of: rowFinder, matching: find.text('Blue Song')),
    );
    expect(title.style?.color, const Color(0xff0063b1));

    final artist = tester.widget<Text>(
      find.descendant(of: rowFinder, matching: find.text('Artist A')),
    );
    expect(artist.style?.color, const Color(0xff0063b1));

    final duration = tester.widget<Text>(
      find.descendant(of: rowFinder, matching: find.text('2:00')),
    );
    expect(duration.style?.color, const Color(0xff0063b1));
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
      _LibraryContentDataListenableTestApp(
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

  testWidgets('MusicLibraryPage header click sorts immediately', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final repository = _FakeLibraryRepository();

    await tester.pumpWidget(
      _MusicLibraryTestApp(
        snapshot: _interactiveSortSnapshot,
        i18n: i18n,
        repository: repository,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.text('Alpha Title Song')).dy,
      lessThan(tester.getTopLeft(find.text('Beta Title Song')).dy),
    );

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('MusicLibrary.Header.artist')),
        matching: find.byType(TextButton),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.musicLibrarySort, MusicLibrarySortCriterion.artist);
    expect(
      tester.getTopLeft(find.text('Beta Title Song')).dy,
      lessThan(tester.getTopLeft(find.text('Alpha Title Song')).dy),
    );

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('MusicLibrary.Header.artist')),
        matching: find.byType(TextButton),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.text('Alpha Title Song')).dy,
      lessThan(tester.getTopLeft(find.text('Beta Title Song')).dy),
    );
  });

  testWidgets('MusicLibraryPage filters selected songs to visible songs', (
    tester,
  ) async {
    final snapshot = ValueNotifier(_snapshot);
    final repository = _ValueListenableLibraryRepository(snapshot);

    await tester.pumpWidget(
      _LibraryContentDataListenableTestApp(
        snapshot: snapshot,
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

    await tester.tap(find.text('Red Song'), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    expect(find.text('Shuffle'), findsOneWidget);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    snapshot.value = _snapshotWithoutBlue;
    await tester.pumpAndSettle();

    expect(find.text('Play Selected'), findsNothing);
    await tester.tap(find.text('Red Song'), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    expect(find.text('Shuffle'), findsNothing);
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
      _MusicLibraryTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: _FakeLibraryRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Blue Song'), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();

    expect(find.text('Add To'), findsAtLeastNWidgets(1));
    expect(find.text('Preference Settings'), findsOneWidget);
    expect(find.text('Delete From Disk'), findsOneWidget);
    expect(find.text('Move To Folder'), findsNothing);
    expect(find.text('Hide File'), findsNothing);
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
    expect(find.text('Lyrics'), findsOneWidget);
    expect(find.text('Album Art'), findsOneWidget);
  });

  testWidgets('MusicLibraryPage selection menu shuffle replaces Now Playing', (
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

    await tester.tap(find.text('Red Song'), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Shuffle'));
    await tester.pumpAndSettle();

    expect(repository.replacedNowPlaying.toSet(), {1, 2});
    expect(mediaController.state.track.id, isIn({1, 2}));
    expect(mediaController.state.isPlaying, isTrue);
  });

  testWidgets('MusicLibraryPage normal click collapses Electron selection', (
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

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.tap(find.text('Blue Song'));
    await tester.pump(kDoubleTapTimeout);
    await tester.tap(find.text('Red Song'));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Green Song'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Red Song'), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();

    expect(find.text('Shuffle'), findsNothing);
    expect(find.text('Play'), findsOneWidget);
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
    await tester.pump(const Duration(milliseconds: 100));

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

  testWidgets('MusicLibraryPage favorite cell patches row without reload', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final snapshot = ValueNotifier<LibraryContentData>(_favoriteSnapshot);
    final repository = _ValueListenableLibraryRepository(snapshot);

    await tester.pumpWidget(
      _RepositoryBackedMusicLibraryTestApp(
        i18n: i18n,
        repository: repository,
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.libraryContentLoadCount, 1);
    final favoriteButton = find.ancestor(
      of: find.byTooltip('Favorite').first,
      matching: find.byType(IconButton),
    );
    tester.widget<IconButton>(favoriteButton).onPressed!();
    await tester.pumpAndSettle();

    expect(repository.favoriteSongIds, [1]);
    expect(repository.favoriteValue, isFalse);
    expect(repository.libraryContentLoadCount, 1);
    final actionTooltip = tester.widget<Tooltip>(
      find.descendant(
        of: find.byKey(const ValueKey('MusicLibrary.FavoriteAction.1')),
        matching: find.byType(Tooltip),
      ),
    );
    expect(actionTooltip.message, 'Add Favorite');
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

    await tester.tap(find.text('Red Song'), buttons: kSecondaryMouseButton);
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

    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('MusicLibraryPage Add To My Favorites refreshes favorite state', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final snapshot = ValueNotifier<LibraryContentData>(_snapshot);
    final repository = _ValueListenableLibraryRepository(snapshot);

    await tester.pumpWidget(
      _LibraryContentDataListenableTestApp(
        snapshot: snapshot,
        i18n: i18n,
        repository: repository,
      ),
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
    expect(snapshot.value.songs.first.favorite, isTrue);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('MusicLibrary.Row.1')),
        matching: find.byTooltip('Favorite'),
      ),
      findsOneWidget,
    );

    await tester.pumpWidget(
      _LibraryContentDataListenableTestApp(
        snapshot: snapshot,
        i18n: i18n,
        repository: repository,
        child: const MyFavoritesPage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Blue Song'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
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
    await tester.tap(find.widgetWithText(TextButton, 'Delete').last);
    await tester.pumpAndSettle();

    expect(repository.pendingDeletedSongId, 1);
    expect(find.text('Undo'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
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

double _playingBarHeight(WidgetTester tester, String keyPrefix, int index) {
  return tester.getSize(find.byKey(ValueKey('$keyPrefix.Bar.$index'))).height;
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

  final LibraryContentData snapshot;
  final SmPlayerI18n i18n;
  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        smPlayerI18nProvider.overrideWith((ref) async => i18n),
        libraryContentDataProvider.overrideWith((ref) async => snapshot),
      ],
      child: SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp.router(
          theme: buildSmPlayerTheme(const SettingsSnapshot.defaults()),
          routerConfig: router,
        ),
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
    this.brightness,
  });

  final LibraryContentData snapshot;
  final SmPlayerI18n i18n;
  final LibraryRepository? repository;
  final MediaControlController? mediaController;
  final String searchQuery;
  final Brightness? brightness;

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
          theme: buildSmPlayerTheme(
            const SettingsSnapshot.defaults(),
            brightness: brightness,
          ),
          home: Scaffold(body: MusicLibraryPage(searchQuery: searchQuery)),
        ),
      ),
    );
  }
}

class _LibraryContentDataListenableTestApp extends StatelessWidget {
  const _LibraryContentDataListenableTestApp({
    required this.snapshot,
    required this.i18n,
    required this.repository,
    this.child = const MusicLibraryPage(),
  });

  final ValueNotifier<LibraryContentData> snapshot;
  final SmPlayerI18n i18n;
  final _ValueListenableLibraryRepository repository;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        smPlayerI18nProvider.overrideWith((ref) async => i18n),
        libraryRepositoryProvider.overrideWithValue(repository),
      ],
      child: SmPlayerI18nScope(
        i18n: i18n,
        child: _LibraryContentDataInvalidator(snapshot: snapshot, child: child),
      ),
    );
  }
}

class _RepositoryBackedMusicLibraryTestApp extends StatelessWidget {
  const _RepositoryBackedMusicLibraryTestApp({
    required this.i18n,
    required this.repository,
  });

  final SmPlayerI18n i18n;
  final LibraryRepository repository;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        smPlayerI18nProvider.overrideWith((ref) async => i18n),
        libraryRepositoryProvider.overrideWithValue(repository),
      ],
      child: SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp(
          theme: buildSmPlayerTheme(const SettingsSnapshot.defaults()),
          home: const Scaffold(body: MusicLibraryPage()),
        ),
      ),
    );
  }
}

class _LibraryContentDataInvalidator extends ConsumerStatefulWidget {
  const _LibraryContentDataInvalidator({
    required this.snapshot,
    required this.child,
  });

  final ValueNotifier<LibraryContentData> snapshot;
  final Widget child;

  @override
  ConsumerState<_LibraryContentDataInvalidator> createState() =>
      _LibraryContentDataInvalidatorState();
}

class _LibraryContentDataInvalidatorState
    extends ConsumerState<_LibraryContentDataInvalidator> {
  @override
  void initState() {
    super.initState();
    widget.snapshot.addListener(_invalidateSnapshot);
  }

  @override
  void didUpdateWidget(_LibraryContentDataInvalidator oldWidget) {
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
    return MaterialApp(
      theme: buildSmPlayerTheme(const SettingsSnapshot.defaults()),
      home: Scaffold(body: widget.child),
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
  List<int> favoriteSongIds = [];
  bool? favoriteValue;
  String? preferenceType;
  String? preferenceItemId;
  String? preferenceName;
  String? preferenceLevel;
  MusicLibrarySortCriterion? musicLibrarySort;
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
  Future<void> updateMusicLibrarySort(
    MusicLibrarySortCriterion criterion,
  ) async {
    musicLibrarySort = criterion;
  }

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
    String folderPath, {
    LocalMoveConflictResolver? resolveConflict,
  }) async {
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

class _ValueListenableLibraryRepository extends _FakeLibraryRepository {
  _ValueListenableLibraryRepository(this.snapshot);

  final ValueNotifier<LibraryContentData> snapshot;
  int libraryContentLoadCount = 0;

  @override
  Future<LibraryContentData> getLibraryContentData() async {
    libraryContentLoadCount += 1;
    return snapshot.value;
  }

  @override
  Future<void> setSongsFavorite(List<int> songIds, bool favorite) async {
    await super.setSongsFavorite(songIds, favorite);
    snapshot.value = _setSnapshotSongsFavorite(
      snapshot.value,
      songIds,
      favorite,
    );
  }
}

LibraryContentData _setSnapshotSongsFavorite(
  LibraryContentData snapshot,
  List<int> songIds,
  bool favorite,
) {
  final songIdSet = songIds.toSet();
  final songs =
      snapshot.songs.map((song) {
        if (!songIdSet.contains(song.id)) {
          return song;
        }
        return LibrarySong(
          id: song.id,
          path: song.path,
          title: song.title,
          artist: song.artist,
          artists: song.artists,
          album: song.album,
          duration: song.duration,
          playCount: song.playCount,
          lyricsOffsetMs: song.lyricsOffsetMs,
          dateAdded: song.dateAdded,
          favorite: favorite,
          thumbnailPath: song.thumbnailPath,
        );
      }).toList();
  final playlists =
      snapshot.playlists.map((playlist) {
        if (playlist.id != snapshot.favoritePlaylistId) {
          return playlist;
        }
        final nextSongIds = [
          if (favorite) ...{
            ...playlist.songIds,
            ...songIds,
          } else
            ...playlist.songIds.where((songId) => !songIdSet.contains(songId)),
        ];
        return LibraryPlaylist(
          id: playlist.id,
          name: playlist.name,
          priority: playlist.priority,
          songCount: nextSongIds.length,
          songIds: nextSongIds,
          sortCriterion: playlist.sortCriterion,
          isBuiltIn: playlist.isBuiltIn,
        );
      }).toList();

  return LibraryContentData(
    songs: songs,
    recentSongs: snapshot.recentSongs,
    recentPlaylists: snapshot.recentPlaylists,
    recentAlbums: snapshot.recentAlbums,
    recentArtists: snapshot.recentArtists,
    recentSearches: snapshot.recentSearches,
    playlists: playlists,
    folders: snapshot.folders,
    favoritePlaylistId: snapshot.favoritePlaylistId,
    nowPlaying: snapshot.nowPlaying,
    hasLibrary: snapshot.hasLibrary,
    sortCriterion: snapshot.sortCriterion,
    albumsSort: snapshot.albumsSort,
    showCount: snapshot.showCount,
    hideMultiSelectCommandBarAfterOperation:
        snapshot.hideMultiSelectCommandBarAfterOperation,
    localViewMode: snapshot.localViewMode,
    rootPath: snapshot.rootPath,
    databasePath: snapshot.databasePath,
  );
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

final _snapshotWithoutBlue = LibraryContentData(
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

final _quickJumpSnapshot = LibraryContentData(
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

final _tailQuickJumpSnapshot = LibraryContentData(
  songs: _tailQuickJumpSongs,
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

final _tailQuickJumpSongs = List.generate(10, (index) {
  final letter = String.fromCharCode(
    'T'.codeUnitAt(0) + (index > 6 ? 6 : index),
  );
  return LibrarySong(
    id: 300 + index,
    path:
        r'C:\Music\tail-quick-jump-'
        '$index.mp3',
    title: '$letter Tail Song $index',
    artist: 'Artist $letter',
    artists: ['Artist $letter'],
    album: '$letter Tail Album',
    duration: 120,
    playCount: 0,
    lyricsOffsetMs: 0,
    dateAdded: '2026-05-20T00:00:00',
    favorite: false,
    thumbnailPath: '',
  );
});

final _virtualizedTableSongs = List.generate(500, (index) {
  return LibrarySong(
    id: 5000 + index,
    path:
        r'C:\Music\virtualized-'
        '$index.mp3',
    title: 'Virtualized Song $index',
    artist: 'Virtual Artist $index',
    artists: ['Virtual Artist $index'],
    album: 'Virtual Album',
    duration: 120,
    playCount: 0,
    lyricsOffsetMs: 0,
    dateAdded: '2026-05-20T00:00:00',
    favorite: false,
    thumbnailPath: '',
  );
});

final _virtualizedTableSnapshot = LibraryContentData(
  songs: _virtualizedTableSongs,
  recentSongs: [],
  recentPlaylists: [],
  recentAlbums: [],
  recentArtists: [],
  recentSearches: [],
  playlists: [],
  favoritePlaylistId: 1,
  nowPlaying: const NowPlayingSnapshot(playlistId: 0, songIds: []),
  hasLibrary: true,
  sortCriterion: MusicLibrarySortCriterion.title,
  albumsSort: AlbumSortCriterion.defaultSort,
  showCount: true,
  hideMultiSelectCommandBarAfterOperation: true,
  databasePath: '',
);

const _accentQuickJumpSnapshot = LibraryContentData(
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

const _longDurationSnapshot = LibraryContentData(
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

const _unknownAlbumSortSnapshot = LibraryContentData(
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

final _unknownAlbumTitleSortSnapshot = LibraryContentData(
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

const _interactiveSortSnapshot = LibraryContentData(
  songs: [
    LibrarySong(
      id: 40,
      path: r'C:\Music\alpha-title.mp3',
      title: 'Alpha Title Song',
      artist: 'Zed Artist',
      artists: ['Zed Artist'],
      album: 'Sort Album',
      duration: 120,
      playCount: 0,
      lyricsOffsetMs: 0,
      dateAdded: '2026-05-20T00:00:00',
      favorite: false,
      thumbnailPath: '',
    ),
    LibrarySong(
      id: 41,
      path: r'C:\Music\beta-title.mp3',
      title: 'Beta Title Song',
      artist: 'Aardvark Artist',
      artists: ['Aardvark Artist'],
      album: 'Sort Album',
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

final _foldersSnapshot = LibraryContentData(
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

const _favoriteSnapshot = LibraryContentData(
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

const _emptySearchSnapshot = LibraryContentData(
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

const _artistFallbackSnapshot = LibraryContentData(
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
