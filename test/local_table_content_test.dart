import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/ui/default_album_artwork.dart';
import 'package:smplayer_flutter/src/library/ui/local_folder_model.dart';
import 'package:smplayer_flutter/src/library/ui/local_page_quick_jump.dart';
import 'package:smplayer_flutter/src/library/ui/local_table_content.dart';

void main() {
  testWidgets(
    'LocalTableContent folder and song rows expose Electron actions',
    (tester) async {
      final openedFolders = <String>[];
      FolderNode? playedFolder;
      FolderNode? addFolder;
      Offset? addFolderPosition;
      FolderNode? refreshedFolder;
      FolderNode? searchedFolder;
      FolderNode? revealedFolder;
      FolderNode? menuFolder;
      Offset? menuFolderPosition;
      int? playedTrackId;
      List<int>? playedQueue;
      LibrarySong? addSong;
      Offset? addSongPosition;
      int? nextSongId;
      LibrarySong? menuSong;
      Offset? menuSongPosition;

      await tester.pumpWidget(
        _TableHarness(
          onOpenFolder: openedFolders.add,
          onPlayFolder: (folder) {
            playedFolder = folder;
          },
          onAddFolder: (folder, position) {
            addFolder = folder;
            addFolderPosition = position;
          },
          onRefreshFolder: (folder) {
            refreshedFolder = folder;
          },
          onSearchFolder: (folder) {
            searchedFolder = folder;
          },
          onRevealFolder: (folder) {
            revealedFolder = folder;
          },
          onOpenFolderMenu: (folder, position) {
            menuFolder = folder;
            menuFolderPosition = position;
          },
          onPlayTrack: (trackId, queue) {
            playedTrackId = trackId;
            playedQueue = queue;
          },
          onAddSong: (song, position) {
            addSong = song;
            addSongPosition = position;
          },
          onPlayNext: (songId) {
            nextSongId = songId;
          },
          onOpenSongMenu: (song, position) {
            menuSong = song;
            menuSongPosition = position;
          },
        ),
      );

      expect(_assetImage('assets/branding/folder.png'), findsOneWidget);
      expect(_assetImage('assets/branding/colorful_no_bg.png'), findsOneWidget);

      await tester.tap(find.text('Sub'));
      expect(openedFolders, ['Sub']);

      final folderCenter = tester.getCenter(find.text('Sub'));
      await tester.tapAt(folderCenter, buttons: kSecondaryMouseButton);
      expect(menuFolder?.relativePath, 'Sub');
      expect(menuFolderPosition, folderCenter);

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: folderCenter);
      addTearDown(gesture.removePointer);
      await tester.pump(const Duration(milliseconds: 140));

      await tester.tap(find.byTooltip('Shuffle'));
      expect(playedFolder?.relativePath, 'Sub');

      await tester.tap(find.byTooltip('Add To').first);
      expect(addFolder?.relativePath, 'Sub');
      expect(addFolderPosition, isNotNull);

      await tester.tap(find.byTooltip('Update Folder'));
      expect(refreshedFolder?.relativePath, 'Sub');

      await tester.tap(find.byTooltip('Search folder'));
      expect(searchedFolder?.relativePath, 'Sub');

      await tester.tap(find.byTooltip('Open local folder'));
      expect(revealedFolder?.relativePath, 'Sub');

      await tester.tap(find.text('Root Song'));
      expect(playedTrackId, 1);
      expect(playedQueue, [1]);

      await gesture.moveTo(tester.getCenter(find.text('Root Song')));
      await tester.pump(const Duration(milliseconds: 140));

      await tester.tap(find.byTooltip('Add To').last);
      expect(addSong?.id, 1);
      expect(addSongPosition, isNotNull);

      await tester.tap(find.byTooltip('Play Next'));
      expect(nextSongId, 1);

      final songCenter = tester.getCenter(find.text('Root Song'));
      await tester.tapAt(songCenter, buttons: kSecondaryMouseButton);
      expect(menuSong?.id, 1);
      expect(menuSongPosition, songCenter);
    },
  );

  testWidgets(
    'LocalTableContent artist and album cells navigate like Electron',
    (tester) async {
      await tester.pumpWidget(const _NavigationHarness());

      await tester.tap(find.text('Artist A'));
      await tester.pumpAndSettle();
      expect(find.text('artist:Artist A'), findsOneWidget);

      await tester.pumpWidget(const _NavigationHarness());
      await tester.tap(find.text('Root Album'));
      await tester.pumpAndSettle();
      expect(find.text('album:Root Album'), findsOneWidget);
    },
  );

  testWidgets(
    'LocalTableContent compact mode hides desktop header and stacks song text',
    (tester) async {
      FolderNode? playedFolder;
      LibrarySong? addSong;
      int? nextSongId;

      await tester.pumpWidget(
        _TableHarness(
          isCompactLayout: true,
          onOpenFolder: (_) {},
          onPlayFolder: (folder) {
            playedFolder = folder;
          },
          onAddFolder: (_, _) {},
          onRefreshFolder: (_) {},
          onSearchFolder: (_) {},
          onRevealFolder: (_) {},
          onOpenFolderMenu: (_, _) {},
          onPlayTrack: (_, _) {},
          onAddSong: (song, _) {
            addSong = song;
          },
          onPlayNext: (songId) {
            nextSongId = songId;
          },
          onOpenSongMenu: (_, _) {},
        ),
      );

      expect(
        find.byKey(const ValueKey('LocalTableContent.CompactList')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('LocalTableContent.VirtualList')),
        findsNothing,
      );
      expect(find.text('Name'), findsNothing);
      expect(find.text('Sub'), findsOneWidget);
      expect(find.text('Root Song'), findsOneWidget);
      expect(find.text('Artist A'), findsOneWidget);
      expect(find.text('Root Album'), findsOneWidget);
      expect(_assetImage('assets/branding/folder.png'), findsOneWidget);
      expect(_assetImage('assets/branding/colorful_no_bg.png'), findsOneWidget);

      await tester.tap(find.byTooltip('Shuffle'), warnIfMissed: false);
      expect(playedFolder, isNull);

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: tester.getCenter(find.text('Sub')));
      addTearDown(gesture.removePointer);
      await tester.pump(const Duration(milliseconds: 140));

      await tester.tap(find.byTooltip('Shuffle'));
      expect(playedFolder?.relativePath, 'Sub');

      await gesture.moveTo(tester.getCenter(find.text('Root Song')));
      await tester.pump(const Duration(milliseconds: 140));

      await tester.tap(find.byTooltip('Add To').last);
      expect(addSong?.id, 1);

      await tester.tap(find.byTooltip('Play Next'));
      expect(nextSongId, 1);

      final titleTop = tester.getTopLeft(find.text('Root Song')).dy;
      final artistTop = tester.getTopLeft(find.text('Artist A')).dy;
      final albumTop = tester.getTopLeft(find.text('Root Album')).dy;
      expect(titleTop, lessThan(artistTop));
      expect(artistTop, lessThan(albumTop));
    },
  );
}

Finder _assetImage(String assetPath) {
  return find.byWidgetPredicate(
    (widget) =>
        widget is Image &&
        widget.image is AssetImage &&
        (widget.image as AssetImage).assetName == assetPath,
  );
}

class _NavigationHarness extends StatelessWidget {
  const _NavigationHarness();

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder:
                (context, state) => _TableHarness(
                  wrapWithMaterialApp: false,
                  onOpenFolder: (_) {},
                  onPlayFolder: (_) {},
                  onAddFolder: (_, _) {},
                  onRefreshFolder: (_) {},
                  onSearchFolder: (_) {},
                  onRevealFolder: (_) {},
                  onOpenFolderMenu: (_, _) {},
                  onPlayTrack: (_, _) {},
                  onAddSong: (_, _) {},
                  onPlayNext: (_) {},
                  onOpenSongMenu: (_, _) {},
                ),
          ),
          GoRoute(
            path: '/artists',
            builder:
                (context, state) =>
                    Text('artist:${state.uri.queryParameters['artist']}'),
          ),
          GoRoute(
            path: '/albums',
            builder:
                (context, state) =>
                    Text('album:${state.uri.queryParameters['album']}'),
          ),
        ],
      ),
    );
  }
}

class _TableHarness extends StatelessWidget {
  const _TableHarness({
    this.wrapWithMaterialApp = true,
    this.isCompactLayout = false,
    required this.onOpenFolder,
    required this.onPlayFolder,
    required this.onAddFolder,
    required this.onRefreshFolder,
    required this.onSearchFolder,
    required this.onRevealFolder,
    required this.onOpenFolderMenu,
    required this.onPlayTrack,
    required this.onAddSong,
    required this.onPlayNext,
    required this.onOpenSongMenu,
  });

  final bool wrapWithMaterialApp;
  final bool isCompactLayout;
  final ValueChanged<String> onOpenFolder;
  final ValueChanged<FolderNode> onPlayFolder;
  final void Function(FolderNode folder, Offset position) onAddFolder;
  final ValueChanged<FolderNode> onRefreshFolder;
  final ValueChanged<FolderNode> onSearchFolder;
  final ValueChanged<FolderNode> onRevealFolder;
  final void Function(FolderNode folder, Offset position) onOpenFolderMenu;
  final void Function(int trackId, List<int> queue) onPlayTrack;
  final void Function(LibrarySong song, Offset position) onAddSong;
  final ValueChanged<int> onPlayNext;
  final void Function(LibrarySong song, Offset position) onOpenSongMenu;

  @override
  Widget build(BuildContext context) {
    final folderIndex = buildFolderIndex(
      const [_song],
      const [
        LibraryFolder(id: 10, path: r'C:\Music\Sub', parentId: 0, criterion: 0),
      ],
      r'C:\Music',
    );

    final body = SmPlayerI18nScope(
      i18n: _i18n,
      child: Scaffold(
        body: LocalTableContent(
          scrollController: ScrollController(),
          childFolders: [folderIndex.nodes['Sub']!],
          currentSongs: const [_song],
          nodes: folderIndex.nodes,
          songsById: folderIndex.songsById,
          selectedFolderPaths: const {},
          selectedSongIds: const {},
          selectedTrackId: null,
          isPlaying: false,
          multiSelect: false,
          showLocalSectionHeaders: false,
          foldersExpanded: true,
          songsExpanded: true,
          showSongQuickJump: false,
          songQuickJumpBasisName: '',
          songQuickJumpMap: const {},
          queueSongIds: const [1],
          isCompactLayout: isCompactLayout,
          compactTreeRows: const [],
          compactQueueSongIds: const [],
          i18n: _i18n,
          onToggleFoldersExpanded: () {},
          onToggleSongsExpanded: () {},
          onToggleTreeFolderExpanded: (_) {},
          onPlayFolder: onPlayFolder,
          onAddFolder: onAddFolder,
          onRefreshFolder: onRefreshFolder,
          onSearchFolder: onSearchFolder,
          onRevealFolder: onRevealFolder,
          onOpenFolder: onOpenFolder,
          onOpenFolderMenu: onOpenFolderMenu,
          onToggleFolderSelection: (_) {},
          onMoveLocalItemsToFolder:
              ({
                required folderPaths,
                required songIds,
                required targetFolderPath,
              }) {},
          onPlayTrack: onPlayTrack,
          onTogglePlayPause: () {},
          onToggleSongSelection: (_) {},
          onPlayNext: onPlayNext,
          onAddSong: onAddSong,
          onOpenSongMenu: onOpenSongMenu,
          onJumpToSongKey: (_) {},
        ),
      ),
    );
    if (!wrapWithMaterialApp) {
      return Theme(data: _theme(), child: body);
    }
    return MaterialApp(theme: _theme(), home: body);
  }
}

ThemeData _theme() {
  return ThemeData(
    extensions: const [
      DefaultAlbumArtworkThemeColors.light,
      LocalPageColors.day,
    ],
  );
}

const _song = LibrarySong(
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

const _i18n = SmPlayerI18n(
  locale: 'en-US',
  messages: {
    'common.album': 'Album',
    'common.artist': 'Artist',
    'common.artistSeparator': ', ',
    'common.name': 'Name',
    'context.addToPlaylist': 'Add To',
    'context.play': 'Play',
    'context.playNext': 'Play Next',
    'local.allSongs': 'All Songs',
    'local.openLocalButtonTooltip': 'Open local folder',
    'local.playAllButtonTooltip': 'Shuffle',
    'local.searchFolderButtonTooltip': 'Search folder',
    'local.updateFolder': 'Update Folder',
    'playlists.songCount': '{count} songs',
    'player.pause': 'Pause',
  },
);
