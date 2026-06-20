import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smplayer_flutter/src/app/app_appearance_model.dart';
import 'package:smplayer_flutter/src/app/workspace_app_bar_portal.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
import 'package:smplayer_flutter/src/library/data/library_repository.dart';
import 'package:smplayer_flutter/src/library/ui/card_corner_badge.dart';
import 'package:smplayer_flutter/src/library/ui/command_bar.dart';
import 'package:smplayer_flutter/src/library/ui/default_album_artwork.dart';
import 'package:smplayer_flutter/src/library/ui/grid_view_holder.dart';
import 'package:smplayer_flutter/src/library/ui/my_favorites_page.dart';
import 'package:smplayer_flutter/src/library/ui/playlists_page.dart';
import 'package:smplayer_flutter/src/settings/settings_controller.dart';
import 'package:smplayer_flutter/src/settings/settings_model.dart'
    show SettingsSnapshot;

void main() {
  setUp(() {
    resetSmPlayerGlobalSettingsSnapshot();
  });

  testWidgets('PlaylistsPage writes Electron playlist preference', (
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
      _PlaylistTestApp(
        repository: repository,
        child: const PlaylistsPage(selectedPlaylistId: 7),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Preference Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('High'));
    await tester.pump();

    expect(repository.preferenceType, 'playlist');
    expect(repository.preferenceItemId, '7');
    expect(repository.preferenceName, 'Mix');
    expect(repository.preferenceLevel, 'high');
  });

  testWidgets('PlaylistsPage persists Electron last selected playlist', (
    tester,
  ) async {
    final repository = _FakeLibraryRepository();

    await tester.pumpWidget(
      _PlaylistTestApp(
        repository: repository,
        child: const PlaylistsPage(selectedPlaylistId: 7),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.lastPlaylistId, 7);
  });

  testWidgets('PlaylistsPage appbar create uses shared appbar action style', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const _PlaylistAppBarPortalTestApp(child: PlaylistsPage()),
    );
    await tester.pumpAndSettle();

    final appBarCreate = find.byKey(const ValueKey('Playlists.AppBar.Create'));
    expect(appBarCreate, findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('Playlists.AppBarHost')),
        matching: find.byType(CommandBar),
      ),
      findsOneWidget,
    );
    expect(tester.getSize(appBarCreate), const Size.square(40));
    final gridView = tester.widget<GridView>(
      find.byKey(const ValueKey('Playlists.GridView')),
    );
    final scrollbar = find.byType(Scrollbar);
    expect(scrollbar, findsOneWidget);
    expect(tester.getRect(scrollbar).right, 1200);
    expect(gridView.padding, const EdgeInsets.fromLTRB(38, 20, 14, 116));
  });

  testWidgets('PlaylistsPage playlist grid mirrors AlbumsPage card geometry', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(_PlaylistTestApp(child: const PlaylistsPage()));
    await tester.pumpAndSettle();

    final firstCard =
        find.byKey(const ValueKey('Playlists.PlaylistCard')).first;
    final firstArtwork =
        find.byKey(const ValueKey('Playlists.ArtworkSurface')).first;
    final gridView = tester.widget<GridView>(
      find.byKey(const ValueKey('Playlists.GridView')),
    );
    final scrollbar = find.byType(Scrollbar);

    expect(scrollbar, findsOneWidget);
    expect(tester.getRect(scrollbar).right, 1200);
    expect(gridView.padding, const EdgeInsets.fromLTRB(38, 8, 14, 116));
    expect(tester.getSize(firstCard).width, 180);
    expect(tester.getSize(firstArtwork), const Size.square(160));
    final artworkShadow =
        tester
                .widget<DecoratedBox>(
                  find
                      .ancestor(
                        of: firstArtwork,
                        matching: find.byType(DecoratedBox),
                      )
                      .first,
                )
                .decoration
            as BoxDecoration;
    expect(artworkShadow.borderRadius, BorderRadius.circular(8));
    expect(artworkShadow.boxShadow, const [
      BoxShadow(color: Color(0x21202d3f), offset: Offset(0, 8), blurRadius: 18),
    ]);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(firstCard));
    await tester.pump();

    final playAction = find.byTooltip('Play');
    expect(playAction, findsOneWidget);
    expect(tester.getSize(playAction), const Size.square(48));
    expect(tester.getCenter(playAction), tester.getCenter(firstArtwork));
  });

  testWidgets('PlaylistsPage grid fits three fixed cards at medium width', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(680, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _PlaylistTestApp(
        snapshot: _playlistGridSnapshot(4),
        child: const PlaylistsPage(),
      ),
    );
    await tester.pumpAndSettle();

    final cards = find.byKey(const ValueKey('Playlists.PlaylistCard'));
    expect(cards, findsNWidgets(4));
    expect(
      tester.getTopLeft(cards.at(0)).dy,
      tester.getTopLeft(cards.at(1)).dy,
    );
    expect(
      tester.getTopLeft(cards.at(1)).dy,
      tester.getTopLeft(cards.at(2)).dy,
    );
    expect(
      tester.getTopLeft(cards.at(2)).dx,
      greaterThan(tester.getTopLeft(cards.at(1)).dx),
    );
    expect(
      tester.getTopLeft(cards.at(3)).dy,
      greaterThan(tester.getTopLeft(cards.at(0)).dy),
    );
  });

  testWidgets('PlaylistsPage search query filters playlist names', (
    tester,
  ) async {
    await tester.pumpWidget(
      _PlaylistTestApp(child: const PlaylistsPage(searchQuery: 'Chill')),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(GridViewHolder),
        matching: find.text('Chill'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(GridViewHolder),
        matching: find.text('Mix'),
      ),
      findsNothing,
    );
  });

  testWidgets('PlaylistsPage search matches songs inside playlists', (
    tester,
  ) async {
    await tester.pumpWidget(
      _PlaylistTestApp(child: const PlaylistsPage(searchQuery: 'Blue Hour')),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(GridViewHolder),
        matching: find.text('Mix'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(GridViewHolder),
        matching: find.text('Chill'),
      ),
      findsNothing,
    );
  });

  testWidgets('PlaylistsPage records playlist search history', (tester) async {
    final repository = _FakeLibraryRepository();

    await tester.pumpWidget(
      _PlaylistTestApp(repository: repository, child: const PlaylistsPage()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Blue Hour');
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();

    expect(repository.recentSearchQuery, 'Blue Hour');
    expect(repository.recentSearchType, SearchHistoryType.playlists);
  });

  testWidgets('PlaylistsPage search dropdown closes on blank tap', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _PlaylistTestApp(
        snapshot: _snapshotWithRecentPlaylistSearch,
        child: const PlaylistsPage(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();

    expect(find.text('Road'), findsOneWidget);

    await tester.tapAt(const Offset(1000, 700));
    await tester.pumpAndSettle();

    expect(find.text('Road'), findsNothing);
  });

  testWidgets('Playlist card selected state uses shared clean card style', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData(
            extensions: const [DefaultAlbumArtworkThemeColors.light],
          ),
          home: Scaffold(
            body: GridViewHolder(
              playlist: const LibraryPlaylist(
                id: 7,
                name: 'Mix',
                priority: 0,
                songCount: 0,
                songIds: [],
                sortCriterion: PlaylistSortCriterion.title,
                isBuiltIn: false,
              ),
              songs: const [],
              subtitle: '0 songs',
              playTooltip: 'Play',
              selected: true,
              showDragHandle: false,
              cardKey: const ValueKey('Playlists.PlaylistCard'),
              artworkKey: const ValueKey('Playlists.ArtworkSurface'),
              onOpen: () {},
              onPlay: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final card = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('Playlists.PlaylistCard')),
    );
    final decoration = card.decoration! as BoxDecoration;
    final foreground = card.foregroundDecoration! as BoxDecoration;
    expect(decoration.color, const Color(0xffd9ecfb));
    expect(decoration.boxShadow, const [
      BoxShadow(color: Color(0x300078d7), offset: Offset(0, 8), blurRadius: 18),
    ]);
    expect(foreground.border!.top.color, const Color(0x260078d7));
    expect(
      tester.widget<Text>(find.text('Mix')).style?.color,
      const Color(0xff0063b1),
    );
    expect(
      tester.widget<Text>(find.text('0 songs')).style?.color,
      const Color(0xff0063b1),
    );
    final artworkShadow =
        tester
                .widget<DecoratedBox>(
                  find
                      .ancestor(
                        of: find.byKey(
                          const ValueKey('Playlists.ArtworkSurface'),
                        ),
                        matching: find.byType(DecoratedBox),
                      )
                      .first,
                )
                .decoration
            as BoxDecoration;
    expect(artworkShadow.boxShadow, const [
      BoxShadow(color: Color(0x21202d3f), offset: Offset(0, 8), blurRadius: 18),
    ]);
  });

  testWidgets('PlaylistsPage drag handle mirrors Electron floating handle', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(_PlaylistTestApp(child: const PlaylistsPage()));
    await tester.pumpAndSettle();

    final firstCard =
        find.byKey(const ValueKey('Playlists.PlaylistCard')).first;

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(firstCard));
    await tester.pump();

    final dragHandle = find.byTooltip('Drag to Sort').first;

    expect(tester.getSize(dragHandle), const Size.square(32));
    expect(
      find.descendant(of: dragHandle, matching: find.byType(CardCornerBadge)),
      findsOneWidget,
    );

    final cardTopRight = tester.getTopRight(firstCard);
    final handleTopRight = tester.getTopRight(dragHandle);
    expect(handleTopRight.dx, closeTo(cardTopRight.dx - 12, 0.01));
    expect(
      handleTopRight.dy,
      closeTo(tester.getTopLeft(firstCard).dy + 12, 0.01),
    );
  });

  testWidgets('PlaylistsPage drag reorder commits Electron custom order', (
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
      _PlaylistTestApp(repository: repository, child: const PlaylistsPage()),
    );
    await tester.pumpAndSettle();

    final cards = find.byKey(const ValueKey('Playlists.PlaylistCard'));
    final firstCard = cards.first;
    final secondCard = cards.at(1);
    final firstCenter = tester.getCenter(firstCard);
    final secondRightCenter =
        tester.getCenter(secondCard) + const Offset(80, 0);
    await tester.dragFrom(firstCenter, secondRightCenter - firstCenter);
    await tester.pump();

    expect(repository.reorderedPlaylistIds, [8, 7]);
  });

  testWidgets('PlaylistsPage drag reorder does not reload library data', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repository = _CountingPlaylistReorderRepository();

    await tester.pumpWidget(
      _RepositoryBackedPlaylistTestApp(
        repository: repository,
        child: const PlaylistsPage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.libraryContentLoadCount, 1);

    final cards = find.byKey(const ValueKey('Playlists.PlaylistCard'));
    final firstCard = cards.first;
    final secondCard = cards.at(1);
    final firstCenter = tester.getCenter(firstCard);
    final secondRightCenter =
        tester.getCenter(secondCard) + const Offset(80, 0);
    await tester.dragFrom(firstCenter, secondRightCenter - firstCenter);
    await tester.pump();

    expect(repository.reorderedPlaylistIds, [8, 7]);
    expect(repository.libraryContentLoadCount, 1);
    expect(
      tester.getTopLeft(find.text('Chill')).dx,
      lessThan(tester.getTopLeft(find.text('Mix')).dx),
    );
  });

  testWidgets('PlaylistsPage keeps order when drag point misses target half', (
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
      _PlaylistTestApp(repository: repository, child: const PlaylistsPage()),
    );
    await tester.pumpAndSettle();

    final cards = find.byKey(const ValueKey('Playlists.PlaylistCard'));
    final firstCard = cards.first;
    final secondCard = cards.at(1);
    final firstCenter = tester.getCenter(firstCard);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(secondCard));
    await tester.pump();
    addTearDown(mouse.removePointer);

    final handleCenter = tester.getCenter(find.byTooltip('Drag to Sort').first);
    await tester.dragFrom(
      handleCenter,
      firstCenter + const Offset(80, 0) - handleCenter,
    );
    await tester.pump();

    expect(repository.reorderedPlaylistIds, isNull);
  });

  testWidgets('PlaylistsPage drag handle pushes touched wrapped target', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repository = _FakeLibraryRepository();
    await tester.pumpWidget(
      _PlaylistTestApp(
        repository: repository,
        snapshot: _wrappedPlaylistSnapshot,
        child: const PlaylistsPage(),
      ),
    );
    await tester.pumpAndSettle();

    final cards = find.byKey(const ValueKey('Playlists.PlaylistCard'));
    final firstCard = cards.first;
    final fifthCenter = tester.getCenter(cards.at(4));
    final fifthRightCenter = fifthCenter + const Offset(80, 0);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(firstCard));
    await tester.pump();
    addTearDown(mouse.removePointer);

    final handleCenter = tester.getCenter(find.byTooltip('Drag to Sort').first);
    await tester.dragFrom(handleCenter, fifthRightCenter - handleCenter);
    await tester.pump();

    expect(repository.reorderedPlaylistIds, [11, 12, 13, 14, 10]);
  });

  testWidgets('PlaylistsPage drag preview reflows cards across wrapped rows', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _PlaylistTestApp(
        snapshot: _wrappedPlaylistSnapshot,
        child: const PlaylistsPage(),
      ),
    );
    await tester.pumpAndSettle();

    final cards = find.byKey(const ValueKey('Playlists.PlaylistCard'));
    final firstCard = cards.first;
    final fifthCardCenter = tester.getCenter(cards.at(4));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(firstCard));
    await tester.pump();
    addTearDown(mouse.removePointer);

    final handleCenter = tester.getCenter(find.byTooltip('Drag to Sort').first);
    await tester.dragFrom(handleCenter, fifthCardCenter - handleCenter);
    await tester.pump();

    expect(
      find.byKey(const ValueKey('Playlists.DropPlaceholder')),
      findsNothing,
    );
  });

  testWidgets('PlaylistsPage hides hover actions while sorting playlists', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(_PlaylistTestApp(child: const PlaylistsPage()));
    await tester.pumpAndSettle();

    final cards = find.byKey(const ValueKey('Playlists.PlaylistCard'));
    final firstCard = cards.first;
    final secondCard = cards.at(1);
    final firstCenter = tester.getCenter(firstCard);
    final secondCenter = tester.getCenter(secondCard);
    final gesture = await tester.startGesture(firstCenter);
    await tester.pump();

    await gesture.moveTo(secondCenter);
    await tester.pump();

    expect(find.byTooltip('Play'), findsNothing);
    final cardContainers = tester.widgetList<AnimatedContainer>(
      find.byKey(const ValueKey('Playlists.PlaylistCard')),
    );
    var inactiveCardCount = 0;
    var activeDragOverlayCount = 0;
    for (final container in cardContainers) {
      final decoration = container.decoration! as BoxDecoration;
      if (decoration.color?.a == 0) {
        inactiveCardCount++;
        expect(decoration.boxShadow, isNull);
      } else {
        activeDragOverlayCount++;
        expect(decoration.boxShadow, isNotNull);
      }
    }
    expect(inactiveCardCount, 1);
    expect(activeDragOverlayCount, 1);

    await gesture.up();
    await tester.pump();
  });

  testWidgets('PlaylistsPage pushes target when drag preview touches it', (
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
      _PlaylistTestApp(repository: repository, child: const PlaylistsPage()),
    );
    await tester.pumpAndSettle();

    final cards = find.byKey(const ValueKey('Playlists.PlaylistCard'));
    final firstCard = cards.first;
    final secondCard = cards.at(1);
    final firstCenter = tester.getCenter(firstCard);
    final secondCenter = tester.getCenter(secondCard);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(firstCard));
    await tester.pump();
    addTearDown(mouse.removePointer);

    final handleCenter = tester.getCenter(find.byTooltip('Drag to Sort').first);
    await tester.dragFrom(
      handleCenter,
      Offset(
        (secondCenter.dx - firstCenter.dx) * 0.35,
        secondCenter.dy - firstCenter.dy,
      ),
    );
    await tester.pump();

    expect(repository.reorderedPlaylistIds, isNull);
  });

  testWidgets('PlaylistsPage Add To excludes the current playlist', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _PlaylistTestApp(child: const PlaylistsPage(selectedPlaylistId: 7)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mix'), findsOneWidget);

    final row = find.byKey(const ValueKey('HeaderedPlaylist.Row.1'));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(row));
    addTearDown(mouse.removePointer);
    await tester.pump();

    await tester.tap(
      find.descendant(
        of: row,
        matching: find.byKey(const ValueKey('PlaylistControlItem.AddToAction')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Now Playing'), findsOneWidget);
    expect(find.text('My Favorites'), findsOneWidget);
    expect(find.text('New Playlist'), findsOneWidget);
    expect(find.text('Chill'), findsOneWidget);
    expect(find.text('Mix'), findsOneWidget);
  });

  testWidgets('PlaylistsPage renames detail playlist without reloading data', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repository = _CountingPlaylistRenameRepository();

    await tester.pumpWidget(
      _RepositoryBackedPlaylistTestApp(
        repository: repository,
        child: const PlaylistsPage(selectedPlaylistId: 7),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.libraryContentLoadCount, 1);
    expect(find.text('Mix'), findsOneWidget);

    final commandBar = find.byKey(
      const ValueKey('HeaderedPlaylist.CommandBar'),
    );
    await tester.tap(
      find.descendant(of: commandBar, matching: find.byTooltip('More')).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Road Trip');
    await tester.tap(find.widgetWithText(TextButton, 'Rename').last);
    await tester.pumpAndSettle();

    expect(repository.renamedPlaylistId, 7);
    expect(repository.renamedPlaylistName, 'Road Trip');
    expect(repository.libraryContentLoadCount, 1);
    expect(find.text('Road Trip'), findsOneWidget);
    expect(find.text('Mix'), findsNothing);
  });

  testWidgets('PlaylistsPage clears detail playlist without reloading data', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repository = _CountingPlaylistMutationRepository();

    await tester.pumpWidget(
      _RepositoryBackedPlaylistTestApp(
        repository: repository,
        child: const PlaylistsPage(selectedPlaylistId: 7),
      ),
    );
    await tester.pumpAndSettle();

    final initialLoadCount = repository.libraryContentLoadCount;
    expect(find.text('Blue Song'), findsOneWidget);

    final commandBar = find.byKey(
      const ValueKey('HeaderedPlaylist.CommandBar'),
    );
    await tester.tap(
      find.descendant(of: commandBar, matching: find.byTooltip('More')).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Clear').last);
    await tester.pumpAndSettle();

    expect(repository.removedSongsPlaylistId, 7);
    expect(repository.removedSongIds, [1]);
    expect(repository.libraryContentLoadCount, initialLoadCount);
    expect(find.text('Blue Song'), findsNothing);
  });

  testWidgets('PlaylistsPage preference update does not reload library data', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repository = _CountingPlaylistMutationRepository();

    await tester.pumpWidget(
      _RepositoryBackedPlaylistTestApp(
        repository: repository,
        child: const PlaylistsPage(selectedPlaylistId: 7),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Preference Settings'));
    await tester.pumpAndSettle();
    final loadCountBeforeUpdate = repository.libraryContentLoadCount;
    await tester.tap(find.text('High'));
    await tester.pumpAndSettle();

    expect(repository.preferenceType, 'playlist');
    expect(repository.preferenceItemId, '7');
    expect(repository.preferenceLevel, 'high');
    expect(repository.libraryContentLoadCount, loadCountBeforeUpdate);
  });

  testWidgets('PlaylistsPage menu duplicate and delete do not reload data', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repository = _CountingPlaylistMutationRepository();

    await tester.pumpWidget(
      _RepositoryBackedPlaylistTestApp(
        repository: repository,
        child: const PlaylistsPage(),
      ),
    );
    await tester.pumpAndSettle();

    final initialLoadCount = repository.libraryContentLoadCount;

    await tester.tapAt(
      tester.getCenter(find.text('Mix')),
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Duplicate').last);
    await tester.pumpAndSettle();

    expect(repository.createdPlaylistName, 'Mix (1)');
    expect(repository.createdPlaylistSongIds, [1]);
    expect(find.text('Mix (1)'), findsOneWidget);
    expect(repository.libraryContentLoadCount, initialLoadCount);

    await tester.tapAt(
      tester.getCenter(find.text('Chill')),
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Delete').last);
    await tester.pumpAndSettle();

    expect(repository.deletedPlaylistId, 8);
    expect(find.text('Chill'), findsNothing);
    expect(repository.libraryContentLoadCount, initialLoadCount);
  });

  testWidgets(
    'PlaylistsPage compact HeaderedPlaylist has no playlist vertical padding',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(700, 760);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        _PlaylistTestApp(child: const PlaylistsPage(selectedPlaylistId: 7)),
      );
      await tester.pumpAndSettle();

      final playlistPadding = tester.widget<SliverPadding>(
        find.byKey(const ValueKey('HeaderedPlaylist.PlaylistPadding')),
      );
      final scrollView = tester.widget<CustomScrollView>(
        find.byKey(const ValueKey('HeaderedPlaylist.ScrollView')),
      );

      expect(
        playlistPadding.padding,
        const EdgeInsets.symmetric(horizontal: 0),
      );
      expect(scrollView.controller!.keepScrollOffset, isFalse);
    },
  );

  testWidgets('HeaderedPlaylist scrollbar hides after scrolling stops', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(700, 760);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _PlaylistTestApp(
        snapshot: _longPlaylistSnapshot(),
        child: const PlaylistsPage(selectedPlaylistId: 7),
      ),
    );
    await tester.pumpAndSettle();

    final opacityFinder = find.descendant(
      of: find.byKey(const ValueKey('HeaderedPlaylist.Scrollbar')),
      matching: find.byType(AnimatedOpacity),
    );
    expect(tester.widget<AnimatedOpacity>(opacityFinder).opacity, 0);

    final scrollView = tester.widget<CustomScrollView>(
      find.byKey(const ValueKey('HeaderedPlaylist.ScrollView')),
    );
    scrollView.controller!.jumpTo(180);
    await tester.pump();

    expect(tester.widget<AnimatedOpacity>(opacityFinder).opacity, 1);

    await tester.pump(const Duration(milliseconds: 701));

    expect(tester.widget<AnimatedOpacity>(opacityFinder).opacity, 0);
  });

  testWidgets('MyFavoritesPage writes Electron built-in preference', (
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
      _PlaylistTestApp(repository: repository, child: const MyFavoritesPage()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Preference Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('High'));
    await tester.pump();

    expect(repository.preferenceType, 'my-favorites');
    expect(repository.preferenceItemId, '6');
    expect(repository.preferenceName, 'My Favorites');
    expect(repository.preferenceLevel, 'high');
  });

  testWidgets(
    'MyFavoritesPage removes favorite without reloading library data',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 800);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repository = _DelayedFavoriteLibraryRepository();

      await tester.pumpWidget(
        _RepositoryBackedPlaylistTestApp(
          repository: repository,
          child: const MyFavoritesPage(),
        ),
      );
      await tester.pumpAndSettle();

      expect(repository.libraryContentLoadCount, 1);
      expect(find.text('Blue Song'), findsOneWidget);

      final row = find.byKey(const ValueKey('HeaderedPlaylist.Row.1'));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: tester.getCenter(row));
      addTearDown(mouse.removePointer);
      await tester.pump(const Duration(milliseconds: 160));

      await tester.tap(
        find.descendant(
          of: row,
          matching: find.byKey(
            const ValueKey('PlaylistControlItem.FavoriteAction'),
          ),
        ),
      );
      await tester.pump();

      expect(repository.favoriteSongIds, [1]);
      expect(repository.favoriteValue, isFalse);
      expect(repository.libraryContentLoadCount, 1);
      expect(
        find.descendant(
          of: row,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );

      repository.completeFavoriteWrite();
      await tester.pumpAndSettle();

      expect(repository.libraryContentLoadCount, 1);
      expect(find.text('Blue Song'), findsNothing);
      await tester.pump(const Duration(seconds: 5));
    },
  );
}

class _PlaylistTestApp extends StatelessWidget {
  const _PlaylistTestApp({
    required this.child,
    this.repository,
    this.snapshot = _snapshot,
  });

  final Widget child;
  final LibraryRepository? repository;
  final LibraryContentData snapshot;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        smPlayerI18nProvider.overrideWith((ref) async => _i18n),
        libraryContentDataProvider.overrideWith((ref) async => snapshot),
        if (repository != null)
          libraryRepositoryProvider.overrideWithValue(repository!),
      ],
      child: MaterialApp(
        theme: _playlistsPageTestTheme(),
        home: Scaffold(body: child),
      ),
    );
  }
}

class _RepositoryBackedPlaylistTestApp extends StatelessWidget {
  const _RepositoryBackedPlaylistTestApp({
    required this.child,
    required this.repository,
  });

  final Widget child;
  final LibraryRepository repository;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        smPlayerI18nProvider.overrideWith((ref) async => _i18n),
        libraryRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        theme: _playlistsPageTestTheme(),
        home: Scaffold(body: child),
      ),
    );
  }
}

class _PlaylistAppBarPortalTestApp extends StatelessWidget {
  const _PlaylistAppBarPortalTestApp({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        smPlayerI18nProvider.overrideWith((ref) async => _i18n),
        libraryContentDataProvider.overrideWith((ref) async => _snapshot),
      ],
      child: MaterialApp(
        theme: _playlistsPageTestTheme(),
        home: Scaffold(
          body: Column(
            children: [
              Consumer(
                builder: (context, ref, _) {
                  final entry = ref.watch(workspaceAppBarPortalProvider);
                  return SizedBox(
                    key: const ValueKey('Playlists.AppBarHost'),
                    height: 40,
                    child: entry?.content,
                  );
                },
              ),
              Expanded(
                child: WorkspaceNavigationAppBarScope(
                  active: true,
                  child: child,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

ThemeData _playlistsPageTestTheme() {
  return buildSmPlayerTheme(const SettingsSnapshot.defaults());
}

class _FakeLibraryRepository extends LibraryRepository {
  String? preferenceType;
  String? preferenceItemId;
  String? preferenceName;
  String? preferenceLevel;
  int? lastPlaylistId;
  List<int>? reorderedPlaylistIds;
  int? renamedPlaylistId;
  String? renamedPlaylistName;
  String? createdPlaylistName;
  List<int>? createdPlaylistSongIds;
  int? deletedPlaylistId;
  int? removedSongsPlaylistId;
  List<int>? removedSongIds;
  int? reorderedSongsPlaylistId;
  List<int>? reorderedSongIds;
  PlaylistSortCriterion? reorderedSongsSortCriterion;
  List<int>? replacedNowPlayingSongIds;
  List<int> favoriteSongIds = [];
  bool? favoriteValue;
  String? recentSearchQuery;
  SearchHistoryType? recentSearchType;

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
  Future<String?> getPreferenceLevel(String type, String itemId) async {
    return null;
  }

  @override
  Future<void> saveViewState({String? lastPage, int? lastPlaylistId}) async {
    this.lastPlaylistId = lastPlaylistId;
  }

  @override
  Future<void> reorderPlaylists(List<int> playlistIds) async {
    reorderedPlaylistIds = playlistIds;
  }

  @override
  Future<void> renamePlaylist(int playlistId, String name) async {
    renamedPlaylistId = playlistId;
    renamedPlaylistName = name;
  }

  @override
  Future<LibraryPlaylist> createPlaylist(
    String name, [
    List<int> songIds = const [],
  ]) async {
    createdPlaylistName = name;
    createdPlaylistSongIds = songIds.toList();
    return LibraryPlaylist(
      id: 90,
      name: name,
      priority: 3,
      songCount: songIds.length,
      songIds: songIds,
      sortCriterion: PlaylistSortCriterion.title,
      isBuiltIn: false,
    );
  }

  @override
  Future<void> deletePlaylist(int playlistId) async {
    deletedPlaylistId = playlistId;
  }

  @override
  Future<void> removeSongsFromPlaylist(
    int playlistId,
    List<int> songIds,
  ) async {
    removedSongsPlaylistId = playlistId;
    removedSongIds = songIds.toList();
  }

  @override
  Future<void> reorderPlaylistSongs(
    int playlistId,
    List<int> songIds, [
    PlaylistSortCriterion? sortCriterion,
  ]) async {
    reorderedSongsPlaylistId = playlistId;
    reorderedSongIds = songIds.toList();
    reorderedSongsSortCriterion = sortCriterion;
  }

  @override
  Future<void> replaceNowPlaying(List<int> songIds) async {
    replacedNowPlayingSongIds = songIds.toList();
  }

  @override
  Future<SearchHistoryEntry?> addRecentSearch(
    String query, [
    SearchHistoryType type = SearchHistoryType.sidebar,
  ]) async {
    recentSearchQuery = query;
    recentSearchType = type;
    return SearchHistoryEntry(
      id: 1,
      query: query,
      type: type,
      searchedAt: '2026-06-15T00:00:00',
    );
  }
}

class _DelayedFavoriteLibraryRepository extends _FakeLibraryRepository {
  final _favoriteWriteCompleter = Completer<void>();
  int libraryContentLoadCount = 0;

  @override
  Future<LibraryContentData> getLibraryContentData() async {
    libraryContentLoadCount += 1;
    return _favoritesSnapshot;
  }

  @override
  Future<void> setSongsFavorite(List<int> songIds, bool favorite) async {
    await super.setSongsFavorite(songIds, favorite);
    await _favoriteWriteCompleter.future;
  }

  void completeFavoriteWrite() {
    _favoriteWriteCompleter.complete();
  }
}

class _CountingPlaylistReorderRepository extends _FakeLibraryRepository {
  int libraryContentLoadCount = 0;

  @override
  Future<LibraryContentData> getLibraryContentData() async {
    libraryContentLoadCount += 1;
    return _snapshot;
  }
}

class _CountingPlaylistRenameRepository extends _FakeLibraryRepository {
  int libraryContentLoadCount = 0;

  @override
  Future<LibraryContentData> getLibraryContentData() async {
    libraryContentLoadCount += 1;
    return _snapshot;
  }
}

class _CountingPlaylistMutationRepository extends _FakeLibraryRepository {
  int libraryContentLoadCount = 0;

  @override
  Future<LibraryContentData> getLibraryContentData() async {
    libraryContentLoadCount += 1;
    return _snapshot;
  }
}

const _i18n = SmPlayerI18n(
  locale: 'en-US',
  messages: {
    'albums.addSelectedTo': 'Add Selected To',
    'albums.clearSelection': 'Clear Selection',
    'albums.editArtwork': 'Edit Artwork',
    'albums.multiSelect': 'Multi Select',
    'albums.playSelected': 'Play Selected',
    'albums.reverseSelection': 'Reverse Selection',
    'albums.selectAll': 'Select All',
    'albums.selectedCount': '{count} selected',
    'albums.sort.reverse': 'Reverse',
    'common.album': 'Album',
    'common.albumUnknown': 'Unknown Album',
    'common.artist': 'Artist',
    'common.artistUnknown': 'Unknown Artist',
    'common.cancel': 'Cancel',
    'common.clear': 'Clear',
    'common.close': 'Close',
    'common.duration': 'Duration',
    'common.favorite': 'Favorite',
    'common.myFavorites': 'My Favorites',
    'common.name': 'Name',
    'common.nowPlaying': 'Now Playing',
    'common.playlist': 'Playlist',
    'common.search': 'Search',
    'common.sort': 'Sort',
    'common.undo': 'Undo',
    'collection.scanFirst': 'Choose a library folder and scan it first.',
    'context.addToPlaylist': 'Add To',
    'context.play': 'Play',
    'context.playNext': 'Play Next',
    'context.removeFavorite': 'Remove Favorite',
    'context.removeFromList': 'Remove From List',
    'headeredPlaylist.clearConfirm': 'Clear "{name}"?',
    'headeredPlaylist.deleteConfirm': 'Delete "{name}"?',
    'headeredPlaylist.songArtist': 'Song/Artist',
    'headeredPlaylist.songsPrefix': 'Songs: ',
    'notification.operationDone': 'Done',
    'nowPlaying.randomPlay': 'Shuffle',
    'player.more': 'More',
    'playlists.create': 'Create',
    'playlists.createNew': 'Create New Playlist',
    'playlists.delete': 'Delete',
    'playlists.dragToSort': 'Drag to Sort',
    'playlists.dropHere': 'Drop Here',
    'playlists.duplicate': 'Duplicate',
    'playlists.nameEmpty': 'Name cannot be empty.',
    'playlists.namePlaceholder': 'Playlist name',
    'playlists.nameSpecial': 'Invalid name.',
    'playlists.nameTooLong': 'Name is too long.',
    'playlists.nameUsed': 'Name is already used.',
    'playlists.newName': 'New Playlist',
    'playlists.newPlaylist': 'New Playlist',
    'playlists.noMatch': 'No playlists match',
    'playlists.noMatchCopy': 'Try a different keyword.',
    'playlists.none': 'No playlists',
    'playlists.noneCopy': 'Create playlists to collect songs.',
    'playlists.removeSelected': 'Remove Selected',
    'playlists.rename': 'Rename',
    'playlists.searchPlaylistPlaceholder': 'Search playlists',
    'playlists.songCount': '{count} songs',
    'preferences.level.dislike': 'Dislike',
    'preferences.level.do-not-appear': 'Do Not Appear',
    'preferences.level.high': 'High',
    'preferences.level.higher': 'Higher',
    'preferences.level.normal': 'Normal',
    'preferences.level.very-high': 'Very High',
    'preferences.undoPrefer': 'Undo Prefer',
    'settings.preferenceSettings': 'Preference Settings',
    'table.album': 'Album',
    'table.artist': 'Artist',
    'table.dateAdded': 'Date Added',
    'table.duration': 'Duration',
    'table.playCount': 'Play Count',
    'table.title': 'Title',
  },
);

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
  hasLibrary: true,
  sortCriterion: MusicLibrarySortCriterion.title,
  albumsSort: AlbumSortCriterion.defaultSort,
  databasePath: r'C:\Music\library.db',
  playlists: [
    LibraryPlaylist(
      id: 3,
      name: 'My Favorites',
      priority: 0,
      songCount: 1,
      songIds: [1],
      sortCriterion: PlaylistSortCriterion.title,
      isBuiltIn: true,
    ),
    LibraryPlaylist(
      id: 7,
      name: 'Mix',
      priority: 1,
      songCount: 1,
      songIds: [1],
      sortCriterion: PlaylistSortCriterion.title,
      isBuiltIn: false,
    ),
    LibraryPlaylist(
      id: 8,
      name: 'Chill',
      priority: 2,
      songCount: 0,
      songIds: [],
      sortCriterion: PlaylistSortCriterion.title,
      isBuiltIn: false,
    ),
  ],
  favoritePlaylistId: 3,
  nowPlaying: NowPlayingSnapshot(playlistId: 0, songIds: []),
);

LibraryContentData _playlistGridSnapshot(int playlistCount) {
  return LibraryContentData(
    songs: _snapshot.songs,
    hasLibrary: true,
    sortCriterion: MusicLibrarySortCriterion.title,
    albumsSort: AlbumSortCriterion.defaultSort,
    databasePath: _snapshot.databasePath,
    playlists: [
      _snapshot.playlists.first,
      for (var index = 0; index < playlistCount; index++)
        LibraryPlaylist(
          id: 20 + index,
          name: 'Grid ${index + 1}',
          priority: index + 1,
          songCount: 0,
          songIds: const [],
          sortCriterion: PlaylistSortCriterion.title,
          isBuiltIn: false,
        ),
    ],
    favoritePlaylistId: _snapshot.favoritePlaylistId,
    nowPlaying: _snapshot.nowPlaying,
  );
}

final _snapshotWithRecentPlaylistSearch = LibraryContentData(
  songs: _snapshot.songs,
  hasLibrary: true,
  sortCriterion: MusicLibrarySortCriterion.title,
  albumsSort: AlbumSortCriterion.defaultSort,
  databasePath: r'C:\Music\library.db',
  playlists: _snapshot.playlists,
  recentSearches: const [
    SearchHistoryEntry(
      id: 40,
      query: 'Road',
      type: SearchHistoryType.playlists,
      searchedAt: '2026-06-15T00:00:00',
    ),
  ],
  favoritePlaylistId: 3,
  nowPlaying: NowPlayingSnapshot(playlistId: 0, songIds: []),
);

LibraryContentData _longPlaylistSnapshot() {
  final songs = List.generate(24, (index) {
    final id = index + 1;
    return LibrarySong(
      id: id,
      path: r'C:\Music\song.mp3',
      title: 'Song $id',
      artist: 'Artist A',
      artists: const ['Artist A'],
      album: 'Blue Hour',
      duration: 120,
      playCount: 0,
      lyricsOffsetMs: 0,
      dateAdded: '2026-05-20T00:00:00',
      favorite: false,
      thumbnailPath: '',
    );
  });
  final songIds = songs.map((song) => song.id).toList();
  return LibraryContentData(
    songs: songs,
    hasLibrary: true,
    sortCriterion: MusicLibrarySortCriterion.title,
    albumsSort: AlbumSortCriterion.defaultSort,
    databasePath: r'C:\Music\library.db',
    playlists: [
      LibraryPlaylist(
        id: 3,
        name: 'My Favorites',
        priority: 0,
        songCount: 0,
        songIds: const [],
        sortCriterion: PlaylistSortCriterion.title,
        isBuiltIn: true,
      ),
      LibraryPlaylist(
        id: 7,
        name: 'Mix',
        priority: 1,
        songCount: songs.length,
        songIds: songIds,
        sortCriterion: PlaylistSortCriterion.title,
        isBuiltIn: false,
      ),
    ],
    favoritePlaylistId: 3,
    nowPlaying: const NowPlayingSnapshot(playlistId: 0, songIds: []),
  );
}

const _favoritesSnapshot = LibraryContentData(
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
  hasLibrary: true,
  sortCriterion: MusicLibrarySortCriterion.title,
  albumsSort: AlbumSortCriterion.defaultSort,
  databasePath: r'C:\Music\library.db',
  playlists: [
    LibraryPlaylist(
      id: 3,
      name: 'My Favorites',
      priority: 0,
      songCount: 1,
      songIds: [1],
      sortCriterion: PlaylistSortCriterion.title,
      isBuiltIn: true,
    ),
  ],
  favoritePlaylistId: 3,
  nowPlaying: NowPlayingSnapshot(playlistId: 0, songIds: []),
);

const _wrappedPlaylistSnapshot = LibraryContentData(
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
  hasLibrary: true,
  sortCriterion: MusicLibrarySortCriterion.title,
  albumsSort: AlbumSortCriterion.defaultSort,
  databasePath: r'C:\Music\library.db',
  playlists: [
    LibraryPlaylist(
      id: 3,
      name: 'My Favorites',
      priority: 0,
      songCount: 1,
      songIds: [1],
      sortCriterion: PlaylistSortCriterion.title,
      isBuiltIn: true,
    ),
    LibraryPlaylist(
      id: 10,
      name: 'Playlist 1',
      priority: 1,
      songCount: 0,
      songIds: [],
      sortCriterion: PlaylistSortCriterion.title,
      isBuiltIn: false,
    ),
    LibraryPlaylist(
      id: 11,
      name: 'Playlist 2',
      priority: 2,
      songCount: 0,
      songIds: [],
      sortCriterion: PlaylistSortCriterion.title,
      isBuiltIn: false,
    ),
    LibraryPlaylist(
      id: 12,
      name: 'Playlist 3',
      priority: 3,
      songCount: 0,
      songIds: [],
      sortCriterion: PlaylistSortCriterion.title,
      isBuiltIn: false,
    ),
    LibraryPlaylist(
      id: 13,
      name: 'Playlist 4',
      priority: 4,
      songCount: 0,
      songIds: [],
      sortCriterion: PlaylistSortCriterion.title,
      isBuiltIn: false,
    ),
    LibraryPlaylist(
      id: 14,
      name: 'Playlist 5',
      priority: 5,
      songCount: 0,
      songIds: [],
      sortCriterion: PlaylistSortCriterion.title,
      isBuiltIn: false,
    ),
  ],
  favoritePlaylistId: 3,
  nowPlaying: NowPlayingSnapshot(playlistId: 0, songIds: []),
);
