import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smplayer_flutter/src/app/app_appearance_model.dart';
import 'package:smplayer_flutter/src/app/workspace_app_bar_portal.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
import 'package:smplayer_flutter/src/library/data/library_repository.dart';
import 'package:smplayer_flutter/src/library/ui/command_bar.dart';
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
