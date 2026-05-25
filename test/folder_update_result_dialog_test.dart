import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/ui/default_album_artwork.dart';
import 'package:smplayer_flutter/src/library/ui/folder_update_result_dialog.dart';
import 'package:smplayer_flutter/src/library/ui/local_folder_model.dart';

void main() {
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
