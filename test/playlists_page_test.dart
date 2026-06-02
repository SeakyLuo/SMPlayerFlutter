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

    expect(tester.getSize(firstCard).width, 180);
    expect(tester.getSize(firstArtwork), const Size.square(160));

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(firstCard));
    await tester.pump();

    final playAction = find.byTooltip('Play');
    expect(playAction, findsOneWidget);
    expect(tester.getSize(playAction), const Size.square(48));
    expect(tester.getCenter(playAction), tester.getCenter(firstArtwork));
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
    final secondCenter = tester.getCenter(secondCard);

    final gesture = await tester.startGesture(firstCenter);
    await tester.pump();
    await gesture.moveTo(secondCenter + const Offset(80, 0));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(repository.reorderedPlaylistIds, [8, 7]);
  });

  testWidgets('PlaylistsPage drag preview follows card center', (tester) async {
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
    await tester.dragFrom(
      secondRightCenter,
      firstCenter + const Offset(80, 0) - secondRightCenter,
    );
    await tester.pump();

    expect(repository.reorderedPlaylistIds, [8, 7]);
  });

  testWidgets('PlaylistsPage drag preview moves placeholder to target slot', (
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

    await gesture.moveTo(secondCenter + const Offset(80, 0));
    await tester.pump();

    final placeholder = find.byKey(const ValueKey('Playlists.DropPlaceholder'));
    expect(placeholder, findsOneWidget);
    expect(tester.getCenter(placeholder).dx, closeTo(secondCenter.dx, 1));

    await gesture.up();
    await tester.pump();
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

  testWidgets('PlaylistsPage keeps placeholder until card reaches next slot', (
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
    await tester.drag(
      firstCard,
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

    await tester.tap(find.byTooltip('Add To'));
    await tester.pumpAndSettle();

    expect(find.text('Now Playing'), findsOneWidget);
    expect(find.text('My Favorites'), findsOneWidget);
    expect(find.text('New Playlist'), findsOneWidget);
    expect(find.text('Chill'), findsOneWidget);
    expect(find.text('Mix'), findsOneWidget);
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
}

class _PlaylistTestApp extends StatelessWidget {
  const _PlaylistTestApp({required this.child, this.repository});

  final Widget child;
  final LibraryRepository? repository;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        smPlayerI18nProvider.overrideWith((ref) async => _i18n),
        libraryContentDataProvider.overrideWith((ref) async => _snapshot),
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
    'common.duration': 'Duration',
    'common.favorite': 'Favorite',
    'common.myFavorites': 'My Favorites',
    'common.name': 'Name',
    'common.nowPlaying': 'Now Playing',
    'common.playlist': 'Playlist',
    'common.sort': 'Sort',
    'common.undo': 'Undo',
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
    'playlists.nameEmpty': 'Name cannot be empty.',
    'playlists.namePlaceholder': 'Playlist name',
    'playlists.nameSpecial': 'Invalid name.',
    'playlists.nameTooLong': 'Name is too long.',
    'playlists.nameUsed': 'Name is already used.',
    'playlists.newName': 'New Playlist',
    'playlists.newPlaylist': 'New Playlist',
    'playlists.none': 'No playlists',
    'playlists.noneCopy': 'Create playlists to collect songs.',
    'playlists.removeSelected': 'Remove Selected',
    'playlists.rename': 'Rename',
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
