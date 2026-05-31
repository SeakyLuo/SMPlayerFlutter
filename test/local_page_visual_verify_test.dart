import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smplayer_flutter/src/app/undoable_notification.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
import 'package:smplayer_flutter/src/library/data/library_repository.dart';
import 'package:smplayer_flutter/src/library/ui/default_album_artwork.dart';
import 'package:smplayer_flutter/src/library/ui/hidden_folders_page.dart';
import 'package:smplayer_flutter/src/library/ui/local_page.dart';
import 'package:smplayer_flutter/src/library/ui/local_page_quick_jump.dart';
import 'package:smplayer_flutter/src/library/ui/missing_library_root_content.dart';
import 'package:smplayer_flutter/src/app/workspace_app_bar_portal.dart';
import 'package:smplayer_flutter/src/playback/media_control_model.dart';
import 'package:smplayer_flutter/src/playback/media_control_provider.dart';
import 'package:smplayer_flutter/src/settings/settings_model.dart'
    show LocalViewMode;

void main() {
  testWidgets('writes LocalPage light and night verification screenshots', (
    tester,
  ) async {
    await _writeLocalPageScreenshot(
      tester,
      brightness: Brightness.light,
      path: 'build/smplayer_local_page_light_verify.png',
    );
    await _writeLocalPageScreenshot(
      tester,
      brightness: Brightness.dark,
      path: 'build/smplayer_local_page_dark_verify.png',
    );
  });

  testWidgets('writes LocalPage empty-root night verification screenshot', (
    tester,
  ) async {
    await _writeLocalPageScreenshot(
      tester,
      brightness: Brightness.dark,
      path: 'build/smplayer_local_page_empty_root_dark_verify.png',
      snapshot: _snapshotWithRootPath(''),
      expectedText: 'No root',
    );
  });

  testWidgets('writes compact LocalPage night verification screenshot', (
    tester,
  ) async {
    await _writeLocalPageScreenshot(
      tester,
      brightness: Brightness.dark,
      path: 'build/smplayer_local_page_compact_dark_verify.png',
      physicalSize: const Size(640, 900),
    );
  });

  testWidgets('writes compact LocalPage light verification screenshot', (
    tester,
  ) async {
    await _writeLocalPageScreenshot(
      tester,
      brightness: Brightness.light,
      path: 'build/smplayer_local_page_compact_light_verify.png',
      physicalSize: const Size(640, 900),
    );
  });

  testWidgets('writes compact LocalPage appbar-body light screenshot', (
    tester,
  ) async {
    await _writeLocalPageScreenshot(
      tester,
      brightness: Brightness.light,
      path: 'build/smplayer_local_page_compact_appbar_body_light_verify.png',
      physicalSize: const Size(640, 900),
      workspaceAppBarActive: true,
      expectedText: 'Intro Signal',
    );
  });

  testWidgets('writes compact expanded tree night verification screenshot', (
    tester,
  ) async {
    await _writeLocalPageScreenshot(
      tester,
      brightness: Brightness.dark,
      path: 'build/smplayer_local_page_compact_tree_dark_verify.png',
      currentRelativePath: 'Collections',
      physicalSize: const Size(640, 900),
      exercise: (tester) async {
        await tester.tap(find.byTooltip('Live'));
        await tester.pump(const Duration(milliseconds: 300));
      },
      expectedText: 'Sessions',
    );
  });

  testWidgets('writes deep breadcrumb night verification screenshot', (
    tester,
  ) async {
    await _writeLocalPageScreenshot(
      tester,
      brightness: Brightness.dark,
      path: 'build/smplayer_local_page_deep_breadcrumb_dark_verify.png',
      physicalSize: const Size(760, 760),
      expectedText: 'Archive',
    );
  });

  testWidgets('writes breadcrumb flyout night verification screenshot', (
    tester,
  ) async {
    await _writeLocalPageScreenshot(
      tester,
      brightness: Brightness.dark,
      path: 'build/smplayer_local_page_breadcrumb_flyout_dark_verify.png',
      physicalSize: const Size(760, 760),
      exercise: (tester) async {
        await tester.tap(
          find.byKey(
            const ValueKey('FolderChain.Dropdown.Collections/Live/Sessions'),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(
            const ValueKey(
              'FolderChain.Child.Collections/Live/Sessions/Archive',
            ),
          ),
          findsOneWidget,
        );
      },
      expectedText: 'Archive',
    );
  });

  testWidgets('writes LocalPage table night verification screenshot', (
    tester,
  ) async {
    await _writeLocalPageScreenshot(
      tester,
      brightness: Brightness.dark,
      path: 'build/smplayer_local_page_table_dark_verify.png',
      snapshot: _snapshotWithLocalViewMode(LocalViewMode.list),
      expectedText: 'Name',
    );
  });

  testWidgets('writes compact LocalPage table light verification screenshot', (
    tester,
  ) async {
    await _writeLocalPageScreenshot(
      tester,
      brightness: Brightness.light,
      path: 'build/smplayer_local_page_compact_table_light_verify.png',
      physicalSize: const Size(640, 900),
      snapshot: _snapshotWithLocalViewMode(LocalViewMode.list),
      expectedText: 'Intro Signal',
    );
    expect(find.text('Name'), findsNothing);
    expect(find.text('River North'), findsOneWidget);
    expect(find.text('Archive Night'), findsWidgets);
  });

  testWidgets('writes current song night verification screenshot', (
    tester,
  ) async {
    final mediaController = MediaControlController();
    mediaController.playTrack(
      const MediaControlTrack(
        id: 1,
        title: 'Intro Signal',
        artist: 'River North',
        artworkUrl: '',
        isLoading: false,
      ),
      durationSeconds: 92,
      queueIndex: 0,
    );
    await _writeLocalPageScreenshot(
      tester,
      brightness: Brightness.dark,
      path: 'build/smplayer_local_page_current_song_dark_verify.png',
      mediaController: mediaController,
      expectedText: 'Intro Signal',
    );
  });

  testWidgets('writes HiddenFoldersPage night verification screenshot', (
    tester,
  ) async {
    await _writeHiddenFoldersScreenshot(
      tester,
      path: 'build/smplayer_hidden_folders_dark_verify.png',
    );
  });
}

Future<void> _writeLocalPageScreenshot(
  WidgetTester tester, {
  required Brightness brightness,
  required String path,
  LibraryContentData snapshot = _snapshot,
  String currentRelativePath = 'Collections/Live/Sessions/Archive',
  Size physicalSize = const Size(1280, 820),
  String expectedText = 'Archive',
  Future<void> Function(WidgetTester tester)? exercise,
  MediaControlController? mediaController,
  bool workspaceAppBarActive = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = physicalSize;
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });

  final repaintKey = GlobalKey();
  await tester.pumpWidget(
    RepaintBoundary(
      key: repaintKey,
      child: _VisualVerifyApp(
        brightness: brightness,
        repository: const _VisualRepository(),
        snapshot: snapshot,
        mediaController: mediaController,
        child: ColoredBox(
          color: _shellBackground(brightness),
          child: WorkspaceNavigationAppBarScope(
            active: workspaceAppBarActive,
            child: LocalPage(currentRelativePath: currentRelativePath),
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
  if (exercise != null) {
    await exercise(tester);
  }

  expect(find.text(expectedText), findsWidgets);
  if (snapshot.rootPath.isNotEmpty && physicalSize.width >= 720) {
    expect(find.byTooltip('Hidden Folders'), findsOneWidget);
  }
  await _writeBoundaryPng(tester, repaintKey, path);
  await tester.tapAt(const Offset(4, 4));
  await tester.pump(const Duration(milliseconds: 50));
}

Future<void> _writeHiddenFoldersScreenshot(
  WidgetTester tester, {
  required String path,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(900, 520);
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });

  final repaintKey = GlobalKey();
  await tester.pumpWidget(
    RepaintBoundary(
      key: repaintKey,
      child: _VisualVerifyApp(
        brightness: Brightness.dark,
        repository: const _VisualRepository(),
        snapshot: _snapshot,
        child: ColoredBox(
          color: _shellBackground(Brightness.dark),
          child: const HiddenFoldersPage(),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));

  expect(
    find.text('Hidden items stay out of Local until resumed.'),
    findsOneWidget,
  );
  expect(find.text('Resume'), findsNWidgets(2));
  await _writeBoundaryPng(tester, repaintKey, path);
}

Future<void> _writeBoundaryPng(
  WidgetTester tester,
  GlobalKey key,
  String path,
) async {
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
  });
}

class _VisualVerifyApp extends StatelessWidget {
  const _VisualVerifyApp({
    required this.brightness,
    required this.repository,
    required this.snapshot,
    this.mediaController,
    required this.child,
  });

  final Brightness brightness;
  final LibraryRepository repository;
  final LibraryContentData snapshot;
  final MediaControlController? mediaController;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        smPlayerI18nProvider.overrideWith((ref) async => _i18n),
        libraryContentDataProvider.overrideWith((ref) async => snapshot),
        libraryRepositoryProvider.overrideWithValue(repository),
        mediaControlControllerProvider.overrideWith(
          (ref) => mediaController ?? MediaControlController(),
        ),
      ],
      child: SmPlayerI18nScope(
        i18n: _i18n,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: _theme(Brightness.light),
          darkTheme: _theme(Brightness.dark),
          themeMode:
              brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
          home: Scaffold(
            backgroundColor: _shellBackground(brightness),
            body: child,
          ),
        ),
      ),
    );
  }
}

class _VisualRepository extends LibraryRepository {
  const _VisualRepository();

  @override
  Future<List<HiddenStorageItem>> getHiddenStorageItems() async {
    return const [
      HiddenStorageItem(
        id: 1,
        type: 'folder',
        path: r'C:\Music\Collections\Hidden Imports',
      ),
      HiddenStorageItem(
        id: 2,
        type: 'file',
        path: r'C:\Music\Collections\Live\Sidelined.mp3',
      ),
    ];
  }

  @override
  Future<void> resumeHiddenStorageItem(HiddenStorageItem item) async {}
}

LibraryContentData _snapshotWithRootPath(String rootPath) {
  return LibraryContentData(
    songs: _snapshot.songs,
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
    rootPath: rootPath,
    databasePath: _snapshot.databasePath,
  );
}

LibraryContentData _snapshotWithLocalViewMode(LocalViewMode localViewMode) {
  return LibraryContentData(
    songs: _snapshot.songs,
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
    localViewMode: localViewMode,
    rootPath: _snapshot.rootPath,
    databasePath: _snapshot.databasePath,
  );
}

ThemeData _theme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  return ThemeData(
    brightness: brightness,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xff0078d7),
      brightness: brightness,
    ),
    extensions: [
      dark ? AppNotificationThemeColors.dark : AppNotificationThemeColors.light,
      dark
          ? DefaultAlbumArtworkThemeColors.dark
          : DefaultAlbumArtworkThemeColors.light,
      dark
          ? MissingLibraryRootThemeColors.night
          : MissingLibraryRootThemeColors.day,
      dark ? LocalPageColors.night : LocalPageColors.day,
    ],
  );
}

Color _shellBackground(Brightness brightness) {
  return brightness == Brightness.dark
      ? const Color(0xff0f1318)
      : const Color(0xfff8fbfe);
}

const _snapshot = LibraryContentData(
  songs: [
    LibrarySong(
      id: 1,
      path: r'C:\Music\Collections\Live\Sessions\Archive\Intro.mp3',
      title: 'Intro Signal',
      artist: 'River North',
      artists: ['River North'],
      album: 'Archive Night',
      duration: 92,
      playCount: 0,
      lyricsOffsetMs: 0,
      dateAdded: '2026-05-31T00:00:00',
      favorite: false,
      thumbnailPath: '',
    ),
    LibrarySong(
      id: 2,
      path: r'C:\Music\Collections\Live\Sessions\Archive\Glass Horizon.mp3',
      title: 'Glass Horizon',
      artist: 'Noon Section',
      artists: ['Noon Section'],
      album: 'Archive Night',
      duration: 184,
      playCount: 0,
      lyricsOffsetMs: 0,
      dateAdded: '2026-05-31T00:00:00',
      favorite: true,
      thumbnailPath: '',
    ),
    LibrarySong(
      id: 3,
      path: r'C:\Music\Collections\Live\Sessions\Archive\North Pier.mp3',
      title: 'North Pier',
      artist: 'Noon Section',
      artists: ['Noon Section'],
      album: 'Archive Night',
      duration: 226,
      playCount: 0,
      lyricsOffsetMs: 0,
      dateAdded: '2026-05-31T00:00:00',
      favorite: false,
      thumbnailPath: '',
    ),
    LibrarySong(
      id: 4,
      path: r'C:\Music\Collections\Live\Sessions\Archive\Encore\Afterlight.mp3',
      title: 'Afterlight',
      artist: 'The Harbor',
      artists: ['The Harbor'],
      album: 'Late Set',
      duration: 206,
      playCount: 0,
      lyricsOffsetMs: 0,
      dateAdded: '2026-05-31T00:00:00',
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
      songCount: 3,
      songIds: [1, 2, 3],
      sortCriterion: PlaylistSortCriterion.title,
      isBuiltIn: false,
    ),
  ],
  folders: [
    LibraryFolder(
      id: 1,
      path: r'C:\Music\Collections',
      parentId: 0,
      criterion: 0,
    ),
    LibraryFolder(
      id: 2,
      path: r'C:\Music\Collections\Live',
      parentId: 1,
      criterion: 0,
    ),
    LibraryFolder(
      id: 3,
      path: r'C:\Music\Collections\Live\Sessions',
      parentId: 2,
      criterion: 0,
    ),
    LibraryFolder(
      id: 4,
      path: r'C:\Music\Collections\Live\Sessions\Archive',
      parentId: 3,
      criterion: 0,
    ),
    LibraryFolder(
      id: 5,
      path: r'C:\Music\Collections\Live\Sessions\Archive\Encore',
      parentId: 4,
      criterion: 0,
    ),
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

const _i18n = SmPlayerI18n(
  locale: 'en-US',
  messages: {
    'albums.multiSelect': 'Multi Select',
    'common.album': 'Album',
    'common.albumUnknown': 'Unknown Album',
    'common.artist': 'Artist',
    'common.artistSeparator': ', ',
    'common.artistUnknown': 'Unknown Artist',
    'common.folders': 'Folders',
    'common.name': 'Name',
    'common.sort': 'Sort',
    'context.addFavorite': 'Add Favorite',
    'context.addToPlaylist': 'Add To',
    'context.pause': 'Pause',
    'context.play': 'Play',
    'context.playNext': 'Play Next',
    'context.removeFavorite': 'Remove Favorite',
    'hiddenFolders.empty': 'No hidden items.',
    'hiddenFolders.introduction':
        'Hidden items stay out of Local until resumed.',
    'hiddenFolders.resume': 'Resume',
    'library.chooseFolder': 'Choose Folder',
    'library.openingFolderPicker': 'Opening Folder Picker',
    'local.allSongs': 'All Songs',
    'local.currentPath': 'Current Path',
    'local.folderCardStats': '{folders} folders · {songs} songs',
    'local.hiddenFolders': 'Hidden Folders',
    'local.libraryRoot': 'Library root',
    'local.newFolder': 'New Folder',
    'local.noRoot': 'No root',
    'local.noRootCopy': 'Choose a library folder first.',
    'local.sortByAlbum': 'Album',
    'local.sortByArtist': 'Artist',
    'local.sortByTitle': 'Title',
    'local.updateFolderShort': 'Update',
    'local.sortReverseList': 'Reverse',
    'local.updateFolder': 'Update Folder',
    'local.viewHiddenFolders': 'View Hidden Folders',
    'musicLibrary.titleHeader': 'Title',
    'nowPlaying.randomPlay': 'Shuffle',
    'player.more': 'More',
  },
);
