import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/ui/default_album_artwork.dart';
import 'package:smplayer_flutter/src/library/ui/local_folder_model.dart';
import 'package:smplayer_flutter/src/library/ui/local_grid_content.dart';

void main() {
  const i18n = SmPlayerI18n(
    locale: 'en-US',
    messages: {
      'common.folders': 'Folders',
      'context.addToPlaylist': 'Add To',
      'context.pause': 'Pause',
      'context.play': 'Play',
      'local.allSongs': 'All Songs',
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
            extensions: const [DefaultAlbumArtworkThemeColors.light],
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
            extensions: const [DefaultAlbumArtworkThemeColors.light],
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

    final firstHeight = _playingBarHeight(tester, 'LocalGridSong.Playing.1', 0);
    await tester.pump(const Duration(milliseconds: 390));

    expect(
      _playingBarHeight(tester, 'LocalGridSong.Playing.1', 0),
      isNot(firstHeight),
    );
  });
}

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
