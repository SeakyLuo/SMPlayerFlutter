import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
import 'package:smplayer_flutter/src/library/data/library_repository.dart';
import 'package:smplayer_flutter/src/library/ui/default_album_artwork.dart';
import 'package:smplayer_flutter/src/library/ui/local_folder_model.dart';
import 'package:smplayer_flutter/src/library/ui/local_grid_content.dart';
import 'package:smplayer_flutter/src/library/ui/local_page_quick_jump.dart';
import 'package:smplayer_flutter/src/library/ui/playlist_artwork.dart';

void main() {
  const i18n = SmPlayerI18n(
    locale: 'en-US',
    messages: {
      'common.folders': 'Folders',
      'context.addToPlaylist': 'Add To',
      'context.pause': 'Pause',
      'context.play': 'Play',
      'local.allSongs': 'All Songs',
      'local.folderCardStats': '{folders} folders · {songs} songs',
      'local.folderSongsShort': '{count} songs',
      'local.gridFolderPlayInfo': 'Play {name}',
      'local.openLocalButtonTooltip': 'Open local folder',
      'local.searchFolderButtonTooltip': 'Search folder',
      'local.updateFolder': 'Update Folder',
    },
  );

  testWidgets('Local grid song hover mirrors Electron card surface', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp(
          theme: ThemeData(
            extensions: const [
              DefaultAlbumArtworkThemeColors.light,
              LocalPageColors.day,
            ],
          ),
          home: Scaffold(body: _localGridContent(i18n)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final songCard =
        find
            .ancestor(
              of: find.text('Root Song'),
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is Container &&
                    widget.constraints?.minHeight == 232 &&
                    widget.decoration is BoxDecoration,
              ),
            )
            .first;
    final songPlayButton = find.descendant(
      of: songCard,
      matching: find.byTooltip('Play'),
    );
    expect(songPlayButton, findsNothing);

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: tester.getCenter(songCard));
    addTearDown(gesture.removePointer);
    await tester.pump();

    expect(songPlayButton, findsOneWidget);
    final hoveredCard = tester.widget<Container>(songCard);
    final decoration = hoveredCard.decoration! as BoxDecoration;
    expect(decoration.color, const Color(0x140078d7));
    expect(decoration.border, isNull);
    expect(decoration.boxShadow, hasLength(2));
  });

  testWidgets('Local grid current song shows Electron playing wave', (
    tester,
  ) async {
    await tester.pumpWidget(
      SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp(
          theme: ThemeData(
            extensions: const [
              DefaultAlbumArtworkThemeColors.light,
              LocalPageColors.day,
            ],
          ),
          home: Scaffold(
            body: _localGridContent(i18n, selectedTrackId: 1, isPlaying: true),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('LocalGridSong.Playing.1.Wave')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('LocalGridSong.Playing.1.Backdrop')),
      findsOneWidget,
    );
    final waveGlass = tester.widget<GlassContainer>(
      find.byKey(const ValueKey('LocalGridSong.Playing.1.Backdrop')),
    );
    expect(waveGlass.useOwnLayer, isTrue);
    expect(waveGlass.shape, isA<LiquidOval>());

    final firstHeight = _playingBarHeight(tester, 'LocalGridSong.Playing.1', 0);
    await tester.pump(const Duration(milliseconds: 390));

    expect(
      _playingBarHeight(tester, 'LocalGridSong.Playing.1', 0),
      isNot(firstHeight),
    );
  });

  testWidgets('Local grid folder card exposes Electron content and actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    FolderNode? playedFolder;
    FolderNode? addFolder;
    Offset? addPosition;
    final content = _folderGridContent(
      i18n,
      onPlayFolder: (folder) {
        playedFolder = folder;
      },
      onAddFolder: (folder, position) {
        addFolder = folder;
        addPosition = position;
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          libraryRepositoryProvider.overrideWithValue(
            const _NoArtworkLibraryRepository(),
          ),
        ],
        child: SmPlayerI18nScope(
          i18n: i18n,
          child: MaterialApp(
            theme: ThemeData(
              extensions: const [
                DefaultAlbumArtworkThemeColors.light,
                LocalPageColors.day,
              ],
            ),
            home: Scaffold(body: content),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Sub'), findsOneWidget);
    expect(find.text('1 folders · 1 songs'), findsOneWidget);
    expect(find.textContaining('8842'), findsNothing);
    expect(find.textContaining(r'C:\Music\Sub'), findsNothing);

    await tester.tap(find.byTooltip('Play Sub'));
    await tester.pump();
    expect(playedFolder?.relativePath, 'Sub');

    await tester.tap(find.byTooltip('Add To'));
    await tester.pump();
    expect(addFolder?.relativePath, 'Sub');
    expect(addPosition, isNotNull);
  });

  test('Local folder thumbnail resolver keeps resolved artwork path', () async {
    const artworkPath = '/tmp/smplayer-folder-artwork.png';
    const song = LibrarySong(
      id: 101,
      path: r'C:\Music\ArtworkSub\root.mp3',
      title: 'Folder Song',
      artist: 'Artist A',
      artists: ['Artist A'],
      album: 'Root Album',
      duration: 120,
      playCount: 0,
      lyricsOffsetMs: 0,
      dateAdded: '2026-05-20T00:00:00',
      favorite: false,
      thumbnailPath: '',
    );

    final artworkUrls = await resolveOriginalFolderThumbnailUrls(const [
      [song],
    ], const _ArtworkLibraryRepository({101: artworkPath}));

    expect(artworkUrls, [artworkPath]);
  });

  testWidgets('Local grid folder card renders resolved artwork image', (
    tester,
  ) async {
    final tempDir = Directory.systemTemp.createTempSync(
      'smplayer_local_grid_artwork_',
    );
    addTearDown(() {
      tempDir.deleteSync(recursive: true);
    });
    final artworkFile = File('${tempDir.path}/folder-artwork.png');
    artworkFile.writeAsBytesSync(_pngFixtureBytes);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          libraryRepositoryProvider.overrideWithValue(
            _ArtworkLibraryRepository({101: artworkFile.path}),
          ),
        ],
        child: SmPlayerI18nScope(
          i18n: i18n,
          child: MaterialApp(
            theme: ThemeData(
              extensions: const [
                DefaultAlbumArtworkThemeColors.light,
                LocalPageColors.day,
              ],
            ),
            home: Scaffold(
              body: _folderGridContent(
                i18n,
                folderName: 'ArtworkSub',
                rootSongId: 101,
                deepSongId: 102,
                onPlayFolder: (_) {},
                onAddFolder: (_, _) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is FileImage &&
            (widget.image as FileImage).file.path == artworkFile.path,
      ),
      findsOneWidget,
    );
  });
}

final _pngFixtureBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAYAAACqaXHeAAAAa0lEQVR42u3QQQ0AMAgEsJM9ayiZHJBBSPqogSbv96aurIoAAQIECBAgQIAAAQIECBAgQIAAAQIECBAgQIAAAQIECBAgQIAAAQIECBAgQIAAAQIECBAgQIAAAQIECBAgQIAAAQIECBBwP2AAQgwqWRbkoyAAAAAASUVORK5CYII=',
);

Widget _localGridContent(
  SmPlayerI18n i18n, {
  int? selectedTrackId,
  bool isPlaying = false,
}) {
  const song = LibrarySong(
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
  );

  return LocalGridContent(
    childFolders: const [],
    currentSongs: const [song],
    nodes: const {},
    songsById: const {1: song},
    selectedFolderPaths: const {},
    selectedSongIds: const {},
    selectedTrackId: selectedTrackId,
    isPlaying: isPlaying,
    multiSelect: false,
    isCompactLayout: false,
    showLocalSectionHeaders: false,
    foldersExpanded: true,
    songsExpanded: true,
    showSongQuickJump: false,
    songQuickJumpBasisName: '',
    songQuickJumpMap: const {},
    sortMode: LocalSortMode.title,
    currentSortMode: LocalSortMode.title,
    queueSongIds: const [1],
    folderQueueSongIds: const [1],
    compactTreeRows: const [],
    compactQueueSongIds: const [],
    i18n: i18n,
    onToggleFoldersExpanded: () {},
    onToggleSongsExpanded: () {},
    onToggleTreeFolderExpanded: (_) {},
    onPlayFolder: (_) {},
    onAddFolder: (_, _) {},
    onRefreshFolder: (_) {},
    onSearchFolder: (_) {},
    onRevealFolder: (_) {},
    onOpenFolder: (_) {},
    onOpenFolderMenu: (_, _) {},
    onToggleFolderSelection: (_) {},
    onMoveLocalItemsToFolder:
        ({
          required folderPaths,
          required songIds,
          required targetFolderPath,
        }) {},
    onPlayTrack: (_, _) {},
    onTogglePlayPause: () {},
    onToggleSongSelection: (_) {},
    onPlayNext: (_) {},
    onToggleFavorite: (_, _) {},
    onAddSong: (_, _) {},
    onOpenSongMenu: (_, _) {},
    onJumpToSongKey: (_) {},
  );
}

double _playingBarHeight(WidgetTester tester, String keyPrefix, int index) {
  return tester.getSize(find.byKey(ValueKey('$keyPrefix.Bar.$index'))).height;
}

Widget _folderGridContent(
  SmPlayerI18n i18n, {
  required ValueChanged<FolderNode> onPlayFolder,
  required void Function(FolderNode folder, Offset position) onAddFolder,
  String folderName = 'Sub',
  int rootSongId = 1,
  int deepSongId = 2,
}) {
  final rootSong = LibrarySong(
    id: rootSongId,
    path: 'C:\\Music\\$folderName\\root.mp3',
    title: 'Folder Song',
    artist: 'Artist A',
    artists: ['Artist A'],
    album: 'Root Album',
    duration: 120,
    playCount: 0,
    lyricsOffsetMs: 0,
    dateAdded: '2026-05-20T00:00:00',
    favorite: false,
    thumbnailPath: '',
  );
  final deepSong = LibrarySong(
    id: deepSongId,
    path: 'C:\\Music\\$folderName\\Deep\\deep.mp3',
    title: 'Deep Song',
    artist: 'Artist B',
    artists: ['Artist B'],
    album: 'Deep Album',
    duration: 90,
    playCount: 0,
    lyricsOffsetMs: 0,
    dateAdded: '2026-05-20T00:00:00',
    favorite: false,
    thumbnailPath: '',
  );
  final folderIndex = buildFolderIndex(
    [rootSong, deepSong],
    [
      LibraryFolder(
        id: 8842,
        path: 'C:\\Music\\$folderName',
        parentId: 0,
        criterion: 0,
      ),
      LibraryFolder(
        id: 8843,
        path: 'C:\\Music\\$folderName\\Deep',
        parentId: 8842,
        criterion: 0,
      ),
    ],
    r'C:\Music',
  );

  return LocalGridContent(
    childFolders: [folderIndex.nodes[folderName]!],
    currentSongs: const [],
    nodes: folderIndex.nodes,
    songsById: folderIndex.songsById,
    selectedFolderPaths: const {},
    selectedSongIds: const {},
    selectedTrackId: null,
    isPlaying: false,
    multiSelect: false,
    isCompactLayout: false,
    showLocalSectionHeaders: false,
    foldersExpanded: true,
    songsExpanded: true,
    showSongQuickJump: false,
    songQuickJumpBasisName: '',
    songQuickJumpMap: const {},
    sortMode: LocalSortMode.title,
    currentSortMode: LocalSortMode.title,
    queueSongIds: [rootSongId],
    folderQueueSongIds: [rootSongId, deepSongId],
    compactTreeRows: const [],
    compactQueueSongIds: const [],
    i18n: i18n,
    onToggleFoldersExpanded: () {},
    onToggleSongsExpanded: () {},
    onToggleTreeFolderExpanded: (_) {},
    onPlayFolder: onPlayFolder,
    onAddFolder: onAddFolder,
    onRefreshFolder: (_) {},
    onSearchFolder: (_) {},
    onRevealFolder: (_) {},
    onOpenFolder: (_) {},
    onOpenFolderMenu: (_, _) {},
    onToggleFolderSelection: (_) {},
    onMoveLocalItemsToFolder:
        ({
          required folderPaths,
          required songIds,
          required targetFolderPath,
        }) {},
    onPlayTrack: (_, _) {},
    onTogglePlayPause: () {},
    onToggleSongSelection: (_) {},
    onPlayNext: (_) {},
    onToggleFavorite: (_, _) {},
    onAddSong: (_, _) {},
    onOpenSongMenu: (_, _) {},
    onJumpToSongKey: (_) {},
  );
}

class _NoArtworkLibraryRepository extends LibraryRepository {
  const _NoArtworkLibraryRepository();

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

class _ArtworkLibraryRepository extends LibraryRepository {
  const _ArtworkLibraryRepository(this.artworkPathBySongId);

  final Map<int, String> artworkPathBySongId;

  @override
  Future<List<SongArtworkSnapshot>> getSongArtworkSnapshots(
    List<int> songIds,
  ) async {
    return [
      for (final songId in songIds)
        SongArtworkSnapshot(
          songId: songId,
          artworkUrl: artworkPathBySongId[songId] ?? '',
          sourceUrl: '',
          sourcePath: '',
          source:
              artworkPathBySongId.containsKey(songId)
                  ? SongArtworkSource.cached
                  : SongArtworkSource.none,
        ),
    ];
  }
}
