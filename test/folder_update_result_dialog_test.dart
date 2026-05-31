import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/ui/default_album_artwork.dart';
import 'package:smplayer_flutter/src/library/ui/folder_update_result_dialog.dart';
import 'package:smplayer_flutter/src/library/ui/folder_update_result_file_title.dart';
import 'package:smplayer_flutter/src/library/ui/folder_update_result_sections.dart';
import 'package:smplayer_flutter/src/library/ui/local_folder_model.dart';

void main() {
  test('folder update file titles mirror Electron duplicate rules', () {
    final items = getUpdateResultFileItems(const [
      '/Users/me/Music/Intro.mp3',
      '/Users/me/Music/Intro.flac',
      '/Users/me/Music/Live/Outro.mp3',
    ], '/Users/me/Music');

    expect(items[0].title, '/Users/me/Music/Intro.mp3');
    expect(items[1].title, '/Users/me/Music/Intro.flac');
    expect(items[2].title, 'Live/Outro');
  });

  testWidgets('FolderUpdateResultDialog renders file result with popup shell', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    await tester.pumpWidget(
      _TestApp(
        child: FolderUpdateResultDialog(
          folder: createFolderNode('', '/Users/me/Music'),
          result: _fileResult,
          songs: _songs,
          selectedTrackId: 1,
          isPlaying: false,
          onPlay: (_) {},
          onOpenSongMenu: (_, _) {},
          onApplyArtistSplits: (_) {},
          onDismissArtistSplitSuggestions: () {},
          onClose: () {},
        ),
      ),
    );

    expect(find.text('Update result of "Music"'), findsOneWidget);
    expect(find.text('Added'), findsOneWidget);
    expect(find.text('Removed'), findsOneWidget);
    expect(find.text('Moved'), findsOneWidget);
    expect(find.text('New Song'), findsOneWidget);
    expect(find.byType(FolderUpdateResultDialog), findsOneWidget);
  });

  testWidgets('FolderUpdateResultDialog shows all Electron result tabs', (
    tester,
  ) async {
    await tester.pumpWidget(
      _TestApp(
        child: FolderUpdateResultDialog(
          folder: createFolderNode('', '/Users/me/Music'),
          result: const LocalFolderRefreshResult(
            filesAdded: ['/Users/me/Music/New Song.mp3'],
            filesRemoved: ['/Users/me/Music/Removed Song.mp3'],
            filesMoved: ['/Users/me/Music/Moved Song.mp3'],
            artistSplitsApplied: [],
            artistSplitSuggestions: [
              ArtistSplitResultItem(
                songId: 1,
                title: 'New Song',
                artist: 'Artist A / Artist B',
                artists: ['Artist A', 'Artist B'],
              ),
            ],
            artistMergeSuggestions: [],
          ),
          songs: _songs,
          selectedTrackId: null,
          isPlaying: false,
          onPlay: (_) {},
          onOpenSongMenu: (_, _) {},
          onApplyArtistSplits: (_) {},
          onDismissArtistSplitSuggestions: () {},
          onClose: () {},
        ),
      ),
    );

    expect(find.text('Added'), findsOneWidget);
    expect(find.text('Removed'), findsOneWidget);
    expect(find.text('Moved'), findsOneWidget);
    expect(find.text('Artists'), findsOneWidget);
  });

  testWidgets(
    'FolderUpdateResultDialog current song uses shared playing wave',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 900);
      addTearDown(() {
        tester.view.resetDevicePixelRatio();
        tester.view.resetPhysicalSize();
      });

      await tester.pumpWidget(
        _TestApp(
          child: FolderUpdateResultDialog(
            folder: createFolderNode('', '/Users/me/Music'),
            result: _fileResult,
            songs: _songs,
            selectedTrackId: 1,
            isPlaying: true,
            onPlay: (_) {},
            onOpenSongMenu: (_, _) {},
            onApplyArtistSplits: (_) {},
            onDismissArtistSplitSuggestions: () {},
            onClose: () {},
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey('FolderUpdateResult.Playing.1.Wave')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('FolderUpdateResult.Playing.1.Backdrop')),
        findsOneWidget,
      );

      final firstHeight = _playingBarHeight(
        tester,
        'FolderUpdateResult.Playing.1',
        0,
      );
      await tester.pump(const Duration(milliseconds: 390));

      expect(
        _playingBarHeight(tester, 'FolderUpdateResult.Playing.1', 0),
        isNot(firstHeight),
      );
    },
  );

  testWidgets('FolderUpdateResultDialog constrains long file lists', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    final addedPaths = [
      for (var index = 0; index < 24; index++)
        '/Users/me/Music/Folder/Song $index.mp3',
    ];

    await tester.pumpWidget(
      _TestApp(
        child: FolderUpdateResultDialog(
          folder: createFolderNode('', '/Users/me/Music'),
          result: LocalFolderRefreshResult(
            filesAdded: addedPaths,
            filesRemoved: const [],
            filesMoved: const [],
            artistSplitsApplied: const [],
            artistSplitSuggestions: const [],
            artistMergeSuggestions: const [],
          ),
          songs: [
            for (var index = 0; index < addedPaths.length; index++)
              LibrarySong(
                id: index + 1,
                path: addedPaths[index],
                title: 'Song $index',
                artist: 'Artist',
                artists: const ['Artist'],
                album: 'Album',
                duration: 180,
                playCount: 0,
                lyricsOffsetMs: 0,
                dateAdded: '2026-05-24',
                favorite: false,
                thumbnailPath: '',
              ),
          ],
          selectedTrackId: 1,
          isPlaying: false,
          onPlay: (_) {},
          onOpenSongMenu: (_, _) {},
          onApplyArtistSplits: (_) {},
          onDismissArtistSplitSuggestions: () {},
          onClose: () {},
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(ListView)).height, lessThan(700));
    expect(find.text('Song 23'), findsNothing);
  });

  testWidgets('FolderUpdateResultDialog playable rows play and open menu', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });
    final playedSongIds = <int>[];
    LibrarySong? menuSong;
    Offset? menuPosition;

    await tester.pumpWidget(
      _TestApp(
        child: FolderUpdateResultDialog(
          folder: createFolderNode('', '/Users/me/Music'),
          result: _fileResult,
          songs: _songs,
          selectedTrackId: null,
          isPlaying: false,
          onPlay: playedSongIds.add,
          onOpenSongMenu: (song, position) {
            menuSong = song;
            menuPosition = position;
          },
          onApplyArtistSplits: (_) {},
          onDismissArtistSplitSuggestions: () {},
          onClose: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final rowCenter = tester.getCenter(find.text('New Song'));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: rowCenter);
    await tester.pump();
    await tester.tap(find.byType(FolderUpdateResultArtwork).first);
    await tester.pumpAndSettle();

    expect(playedSongIds, [1]);

    await tester.tapAt(rowCenter, buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();

    expect(menuSong?.id, 1);
    expect(menuPosition, rowCenter);

    menuSong = null;
    menuPosition = null;
    await tester.tap(find.text('Removed'));
    await tester.pumpAndSettle();
    final removedRowCenter = tester.getCenter(find.text('Removed Song'));

    await tester.tapAt(removedRowCenter);
    await tester.tapAt(removedRowCenter, buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();

    expect(playedSongIds, [1]);
    expect(menuSong, isNull);
    expect(menuPosition, isNull);
  });
}

double _playingBarHeight(WidgetTester tester, String keyPrefix, int index) {
  return tester.getSize(find.byKey(ValueKey('$keyPrefix.Bar.$index'))).height;
}

class _TestApp extends StatelessWidget {
  const _TestApp({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SmPlayerI18nScope(
      i18n: _i18n,
      child: MaterialApp(
        theme: ThemeData(
          extensions: const [DefaultAlbumArtworkThemeColors.light],
        ),
        home: Material(color: const Color(0xfff3f6fa), child: child),
      ),
    );
  }
}

const _fileResult = LocalFolderRefreshResult(
  filesAdded: ['/Users/me/Music/New Song.mp3'],
  filesRemoved: ['/Users/me/Music/Removed Song.mp3'],
  filesMoved: ['/Users/me/Music/Moved Song.mp3'],
  artistSplitsApplied: [],
  artistSplitSuggestions: [],
  artistMergeSuggestions: [],
);

const _songs = [
  LibrarySong(
    id: 1,
    path: '/Users/me/Music/New Song.mp3',
    title: 'New Song',
    artist: 'Artist',
    artists: ['Artist'],
    album: 'Album',
    duration: 180,
    playCount: 0,
    lyricsOffsetMs: 0,
    dateAdded: '2026-05-24',
    favorite: false,
    thumbnailPath: '',
  ),
  LibrarySong(
    id: 2,
    path: '/Users/me/Music/Moved Song.mp3',
    title: 'Moved Song',
    artist: 'Artist',
    artists: ['Artist'],
    album: 'Album',
    duration: 180,
    playCount: 0,
    lyricsOffsetMs: 0,
    dateAdded: '2026-05-24',
    favorite: false,
    thumbnailPath: '',
  ),
];

const _i18n = SmPlayerI18n(
  locale: 'en-US',
  messages: {
    'common.add': 'Add',
    'common.artistSeparator': ', ',
    'common.close': 'Close',
    'common.edit': 'Edit',
    'context.pause': 'Pause',
    'context.play': 'Play',
    'local.applyingArtistSplits': 'Applying...',
    'local.applySelectedArtistSplits': 'Apply selected ({count})',
    'local.artistMergeAfter': 'After',
    'local.artistMergeSuggestionsTitle': 'Ready to Merge Artists',
    'local.artistSplitAfter': 'After',
    'local.artistSplitOriginal': 'Original',
    'local.clearArtistSplitSelection': 'Clear',
    'local.directArtistSplitsTitle': 'Direct splits',
    'local.keepArtistSplits': 'Keep as is',
    'local.libraryRoot': 'Library root',
    'local.refreshAddedTab': 'Added',
    'local.refreshArtistSplitSuggestionsTitle': 'Possible splits',
    'local.refreshArtistSplitsAppliedTitle': 'Direct splits',
    'local.refreshArtistUpdatesTab': 'Artists',
    'local.refreshMovedTab': 'Moved',
    'local.refreshRemovedTab': 'Removed',
    'local.selectAllArtistSplits': 'Select all',
    'local.updateResultOfFolder': 'Update result of "{name}"',
    'playlists.removeSelected': 'Remove',
    'settings.save': 'Save',
  },
);
