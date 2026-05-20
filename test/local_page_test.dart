import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'dart:io';
import 'package:go_router/go_router.dart';

import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
import 'package:smplayer_flutter/src/library/data/library_repository.dart';
import 'package:smplayer_flutter/src/library/ui/command_bar.dart';
import 'package:smplayer_flutter/src/library/ui/local_page.dart';
import 'package:smplayer_flutter/src/library/ui/local_title_grid.dart';
import 'package:smplayer_flutter/src/playback/media_control_model.dart';
import 'package:smplayer_flutter/src/playback/media_control_provider.dart';

void main() {
  const i18n = SmPlayerI18n(
    locale: 'en-US',
    messages: {
      'albums.clearSelection': 'Clear Selection',
      'albums.addSelectedTo': 'Add selected to',
      'albums.multiSelect': 'Multi Select',
      'albums.playSelected': 'Play selected',
      'albums.reverseSelection': 'Reverse Selection',
      'albums.selectAll': 'Select All',
      'albums.selectedCount': '{count} selected',
      'common.albumUnknown': 'Unknown Album',
      'common.artistUnknown': 'Unknown Artist',
      'common.cancel': 'Cancel',
      'common.folders': 'Folders',
      'common.myFavorites': 'My Favorites',
      'common.nowPlaying': 'Now Playing',
      'common.playlist': 'Playlist',
      'common.search': 'Search',
      'common.sort': 'Sort',
      'context.addFavorite': 'Add Favorite',
      'context.addToPlaylist': 'Add To',
      'context.deleteFromDisk': 'Delete from Disk',
      'context.playNext': 'Play Next',
      'context.removeFavorite': 'Remove Favorite',
      'library.chooseFolder': 'Choose Folder',
      'library.scanHelp': 'Scan music first.',
      'local.allSongs': 'All Songs',
      'local.backToRoot': 'Back to Root',
      'local.currentPath': 'Current Path',
      'local.folderCardStats': '{folders} folders · {songs} songs',
      'local.folderNotFound': 'Folder not found',
      'local.folderNameEmpty': 'Folder name cannot be empty.',
      'local.folderNameTooLong': 'Folder name cannot exceed 50 characters.',
      'local.folderNameUsed': 'A folder with this name already exists.',
      'local.goToSettings': 'Settings',
      'local.hiddenFolders': 'Hidden Folders',
      'local.newFolder': 'New Folder',
      'local.newFolderName': 'New Folder',
      'local.newFolderPrompt': 'Folder name',
      'local.noMusicUnderCurrentFolder': 'No music under current folder.',
      'local.noRoot': 'No root',
      'local.noRootCopy': 'Choose a library folder first.',
      'local.noSongsBranch': 'No songs for {query}',
      'local.noSongsScanned': 'No songs scanned',
      'local.path': 'Path',
      'local.pleaseExitMultiSelectMode': 'Exit multi-select mode first.',
      'local.scanPopulate': 'Scan to populate.',
      'local.scopeCurrent': 'Current folder',
      'local.scopeSubtree': 'Include subfolders',
      'local.searchDirectoryPrompt': 'Search under "{name}"',
      'local.searchHelp': 'Try another search.',
      'local.searchQueryEmpty': 'Search query cannot be empty.',
      'local.sortByAlbum': 'Album',
      'local.sortByArtist': 'Artist',
      'local.sortByTitle': 'Title',
      'local.sortReverseList': 'Reverse',
      'local.updateFolder': 'Update Folder',
      'local.updateFolderShort': 'Update',
      'nowPlaying.randomPlay': 'Shuffle',
      'player.more': 'More',
      'playlists.create': 'Create',
      'playlists.createNew': 'Create Playlist',
      'playlists.nameEmpty': 'Name is required.',
      'playlists.namePlaceholder': 'Playlist name',
      'playlists.nameSpecial': 'Name contains unsupported text.',
      'playlists.nameTooLong': 'Name is too long.',
      'playlists.nameUsed': 'Name already exists.',
      'playlists.newPlaylist': 'New Playlist',
    },
  );

  testWidgets('LocalPage toolbar shuffle matches Electron scope menu', (
    tester,
  ) async {
    _setLargeSurface(tester);
    final repository = _FakeLibraryRepository();
    final mediaController = MediaControlController();

    await tester.pumpWidget(
      _LocalPageTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: repository,
        mediaController: mediaController,
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    await _pressTextButtonByLabel(tester, 'Shuffle');
    await tester.pumpAndSettle();

    expect(find.text('Current folder'), findsOneWidget);
    expect(find.text('Include subfolders'), findsOneWidget);

    await tester.tap(find.text('Current folder'));
    await tester.pumpAndSettle();

    expect(repository.replacedNowPlaying, [1]);
    expect(mediaController.state.track.id, 1);
    expect(mediaController.state.isPlaying, isTrue);
  });

  testWidgets('LocalPage multi-select add to playlist uses selected folders', (
    tester,
  ) async {
    _setLargeSurface(tester);
    final repository = _FakeLibraryRepository();

    await tester.pumpWidget(
      _LocalPageTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: repository,
        mediaController: MediaControlController(),
      ),
    );
    await tester.pumpAndSettle();

    await _pressTextButtonByLabel(tester, 'Multi Select');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sub'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add selected to'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Road Mix'));
    await tester.pumpAndSettle();

    expect(repository.addedPlaylistId, 30);
    expect(repository.addedSongIds, [2]);
  });

  testWidgets('LocalPage song add menu supports now playing and favorites', (
    tester,
  ) async {
    _setLargeSurface(tester);
    final repository = _FakeLibraryRepository();

    await tester.pumpWidget(
      _LocalPageTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: repository,
        mediaController: MediaControlController(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(FluentIcons.add_20_regular).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Now Playing'));
    await tester.pumpAndSettle();

    expect(repository.replacedNowPlaying, [9, 1]);

    await tester.tap(find.byIcon(FluentIcons.add_20_regular).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('My Favorites'));
    await tester.pumpAndSettle();

    expect(repository.favoriteSongIds, [1]);
    expect(repository.favoriteValue, isTrue);
  });

  testWidgets('LocalPage new folder creates directory and shows it', (
    tester,
  ) async {
    _setLargeSurface(tester);
    final root = Directory(
      '${Directory.current.path}${Platform.pathSeparator}build${Platform.pathSeparator}local_page_test_root',
    );
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
    root.createSync(recursive: true);
    addTearDown(() {
      if (root.existsSync()) {
        root.deleteSync(recursive: true);
      }
    });

    await tester.pumpWidget(
      _LocalPageTestApp(
        snapshot: _snapshotWithRoot(root.path),
        i18n: i18n,
        repository: _FakeLibraryRepository(),
        mediaController: MediaControlController(),
      ),
    );
    await tester.pumpAndSettle();

    _pressCommandBarButton(tester, 'New Folder');
    await tester.pump();
    await tester.tap(find.text('Create'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      Directory('${root.path}${Platform.pathSeparator}New Folder').existsSync(),
      isTrue,
    );
    expect(find.text('New Folder'), findsWidgets);
  });

  testWidgets('LocalPage blocks sort changes in multi-select mode', (
    tester,
  ) async {
    _setLargeSurface(tester);
    final repository = _FakeLibraryRepository();

    await tester.pumpWidget(
      _LocalPageTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: repository,
        mediaController: MediaControlController(),
      ),
    );
    await tester.pumpAndSettle();

    _pressCommandBarButton(tester, 'Multi Select');
    await tester.pumpAndSettle();
    _pressCommandBarButton(tester, 'Sort');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Album').last);
    await tester.pumpAndSettle();

    expect(find.text('Exit multi-select mode first.'), findsOneWidget);
    expect(repository.updatedSortFolderPath, isNull);
  });

  testWidgets('LocalPage search folder uses Electron input dialog', (
    tester,
  ) async {
    _setCompactSurface(tester);
    final repository = _FakeLibraryRepository();

    await tester.pumpWidget(
      _LocalPageRouterTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: repository,
        mediaController: MediaControlController(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(FluentIcons.search_20_regular).first);
    await tester.pumpAndSettle();

    expect(find.text('Search under "Sub"'), findsOneWidget);

    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
    expect(find.text('Search query cannot be empty.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'jazz');
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();

    expect(repository.recentSearchQuery, 'jazz');
    expect(repository.recentSearchType, SearchHistoryType.folders);
    expect(find.text('search:jazz:folders:Sub'), findsOneWidget);
  });

  testWidgets('LocalPage multi-select commands ignore filtered-out items', (
    tester,
  ) async {
    _setLargeSurface(tester);
    final repository = _FakeLibraryRepository();
    final mediaController = MediaControlController();
    final searchQuery = ValueNotifier('');
    await tester.pumpWidget(
      _LocalPageSearchQueryTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: repository,
        mediaController: mediaController,
        searchQuery: searchQuery,
      ),
    );
    await tester.pumpAndSettle();
    _pressCommandBarButton(tester, 'Multi Select');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sub'));
    await tester.pumpAndSettle();

    searchQuery.value = 'root';
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsNothing);
    expect(find.text('Add selected to'), findsNothing);
    expect(find.text('Road Mix'), findsNothing);
    expect(repository.addedPlaylistId, isNull);
  });

  testWidgets('FolderChainListView opens Electron child folder flyout', (
    tester,
  ) async {
    _setLargeSurface(tester);
    var openedFolder = '';

    await tester.pumpWidget(
      SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 500,
              child: FolderChainListView(
                songs: _snapshot.songs,
                folders: _snapshot.folders,
                i18n: i18n,
                rootPath: _snapshot.rootPath,
                currentRelativePath: '',
                onOpenFolder: (folderPath) {
                  openedFolder = folderPath;
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('FolderChain.Dropdown.')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('FolderChain.Child.Sub')), findsOneWidget);

    await tester.tap(find.text('Sub').last);
    await tester.pumpAndSettle();

    expect(openedFolder, 'Sub');
  });
}

void _setLargeSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(2000, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

void _setCompactSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(640, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _pressTextButtonByLabel(WidgetTester tester, String label) async {
  _pressCommandBarButton(tester, label);
  await tester.pumpAndSettle();
}

void _pressCommandBarButton(WidgetTester tester, String label) {
  final button = find.byWidgetPredicate(
    (widget) => widget is CommandBarButton && widget.label == label,
  );
  tester.widget<CommandBarButton>(button.first).onPressed!();
}

class _LocalPageTestApp extends StatelessWidget {
  const _LocalPageTestApp({
    required this.snapshot,
    required this.i18n,
    required this.repository,
    required this.mediaController,
  });

  final MusicLibrarySnapshot snapshot;
  final SmPlayerI18n i18n;
  final LibraryRepository repository;
  final MediaControlController mediaController;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        smPlayerI18nProvider.overrideWith((ref) async => i18n),
        musicLibrarySnapshotProvider.overrideWith((ref) async => snapshot),
        libraryRepositoryProvider.overrideWithValue(repository),
        mediaControlControllerProvider.overrideWith((ref) => mediaController),
      ],
      child: SmPlayerI18nScope(
        i18n: i18n,
        child: const MaterialApp(home: Scaffold(body: LocalPage())),
      ),
    );
  }
}

class _LocalPageRouterTestApp extends StatelessWidget {
  const _LocalPageRouterTestApp({
    required this.snapshot,
    required this.i18n,
    required this.repository,
    required this.mediaController,
  });

  final MusicLibrarySnapshot snapshot;
  final SmPlayerI18n i18n;
  final LibraryRepository repository;
  final MediaControlController mediaController;

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      initialLocation: '/local',
      routes: [
        GoRoute(
          path: '/local',
          builder:
              (_, state) => Scaffold(
                body: LocalPage(
                  currentRelativePath: state.uri.queryParameters['path'] ?? '',
                  searchQuery: state.uri.queryParameters['query'] ?? '',
                ),
              ),
        ),
        GoRoute(
          path: '/search',
          builder:
              (_, state) => Scaffold(
                body: Text(
                  'search:${state.uri.queryParameters['query']}:'
                  '${state.uri.queryParameters['type']}:'
                  '${state.uri.queryParameters['folder']}',
                ),
              ),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        smPlayerI18nProvider.overrideWith((ref) async => i18n),
        musicLibrarySnapshotProvider.overrideWith((ref) async => snapshot),
        libraryRepositoryProvider.overrideWithValue(repository),
        mediaControlControllerProvider.overrideWith((ref) => mediaController),
      ],
      child: SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
  }
}

class _LocalPageSearchQueryTestApp extends StatelessWidget {
  const _LocalPageSearchQueryTestApp({
    required this.snapshot,
    required this.i18n,
    required this.repository,
    required this.mediaController,
    required this.searchQuery,
  });

  final MusicLibrarySnapshot snapshot;
  final SmPlayerI18n i18n;
  final LibraryRepository repository;
  final MediaControlController mediaController;
  final ValueNotifier<String> searchQuery;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        smPlayerI18nProvider.overrideWith((ref) async => i18n),
        musicLibrarySnapshotProvider.overrideWith((ref) async => snapshot),
        libraryRepositoryProvider.overrideWithValue(repository),
        mediaControlControllerProvider.overrideWith((ref) => mediaController),
      ],
      child: SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<String>(
              valueListenable: searchQuery,
              builder: (_, query, _) => LocalPage(searchQuery: query),
            ),
          ),
        ),
      ),
    );
  }
}

class _FakeLibraryRepository extends LibraryRepository {
  List<int> replacedNowPlaying = [];
  int? addedPlaylistId;
  List<int> addedSongIds = [];
  List<int> favoriteSongIds = [];
  bool? favoriteValue;
  String? updatedSortFolderPath;
  LocalFolderSortCriterion? updatedSortCriterion;
  String? recentSearchQuery;
  SearchHistoryType? recentSearchType;

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
  Future<void> updateLocalFolderSort(
    String folderPath,
    LocalFolderSortCriterion criterion,
  ) async {
    updatedSortFolderPath = folderPath;
    updatedSortCriterion = criterion;
  }

  @override
  Future<void> addRecentSearch(
    String query, [
    SearchHistoryType type = SearchHistoryType.sidebar,
  ]) async {
    recentSearchQuery = query;
    recentSearchType = type;
  }
}

const _snapshot = MusicLibrarySnapshot(
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
  recentSongs: [],
  recentPlaylists: [],
  recentAlbums: [],
  recentArtists: [],
  recentSearches: [],
  playlists: [
    LibraryPlaylist(
      id: 20,
      name: 'My Favorites',
      priority: 0,
      songCount: 0,
      songIds: [],
      sortCriterion: PlaylistSortCriterion.title,
      isBuiltIn: true,
    ),
    LibraryPlaylist(
      id: 30,
      name: 'Road Mix',
      priority: 1,
      songCount: 0,
      songIds: [],
      sortCriterion: PlaylistSortCriterion.title,
      isBuiltIn: false,
    ),
  ],
  folders: [
    LibraryFolder(id: 10, path: r'C:\Music\Sub', parentId: 0, criterion: 0),
  ],
  favoritePlaylistId: 20,
  nowPlaying: NowPlayingSnapshot(playlistId: 9, songIds: [9]),
  hasLibrary: true,
  sortCriterion: MusicLibrarySortCriterion.title,
  albumsSort: AlbumSortCriterion.defaultSort,
  showCount: true,
  hideMultiSelectCommandBarAfterOperation: true,
  rootPath: r'C:\Music',
  databasePath: '',
);

MusicLibrarySnapshot _snapshotWithRoot(String rootPath) {
  return MusicLibrarySnapshot(
    songs: [
      LibrarySong(
        id: 1,
        path: '$rootPath${Platform.pathSeparator}root.mp3',
        title: 'Root Song',
        artist: 'Artist A',
        artists: const ['Artist A'],
        album: 'Root Album',
        duration: 120,
        playCount: 0,
        lyricsOffsetMs: 0,
        dateAdded: '2026-05-20T00:00:00',
        favorite: false,
        thumbnailPath: '',
      ),
    ],
    recentSongs: const [],
    recentPlaylists: const [],
    recentAlbums: const [],
    recentArtists: const [],
    recentSearches: const [],
    playlists: const [
      LibraryPlaylist(
        id: 20,
        name: 'My Favorites',
        priority: 0,
        songCount: 0,
        songIds: [],
        sortCriterion: PlaylistSortCriterion.title,
        isBuiltIn: true,
      ),
    ],
    folders: const [],
    favoritePlaylistId: 20,
    nowPlaying: const NowPlayingSnapshot(playlistId: 9, songIds: [9]),
    hasLibrary: true,
    sortCriterion: MusicLibrarySortCriterion.title,
    albumsSort: AlbumSortCriterion.defaultSort,
    showCount: true,
    hideMultiSelectCommandBarAfterOperation: true,
    rootPath: rootPath,
    databasePath: '',
  );
}
