import 'package:flutter/material.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/ui/default_album_artwork.dart';
import 'package:smplayer_flutter/src/library/ui/folder_update_result_dialog.dart';
import 'package:smplayer_flutter/src/library/ui/local_folder_model.dart';

void main() {
  final result =
      Uri.base.queryParameters['mode'] == 'artists'
          ? _artistResult
          : _fileResult;
  runApp(
    SmPlayerI18nScope(
      i18n: _i18n,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          extensions: const [DefaultAlbumArtworkThemeColors.light],
        ),
        home: FolderUpdateResultDialog(
          folder: createFolderNode('', '/Users/me/Music'),
          result: result,
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
    ),
  );
}

const _fileResult = LocalFolderRefreshResult(
  filesAdded: ['/Users/me/Music/New Song.mp3'],
  filesRemoved: ['/Users/me/Music/Removed Song.mp3'],
  filesMoved: ['/Users/me/Music/Moved Song.mp3'],
  artistSplitsApplied: [],
  artistSplitSuggestions: [],
  artistMergeSuggestions: [],
);

const _artistResult = LocalFolderRefreshResult(
  filesAdded: [],
  filesRemoved: [],
  filesMoved: [],
  artistSplitsApplied: [
    ArtistSplitResultItem(
      songId: 1,
      title: 'Glass City Lights',
      artist: 'Lena Park / Gray Line',
      artists: ['Lena Park', 'Gray Line'],
    ),
  ],
  artistSplitSuggestions: [
    ArtistSplitResultItem(
      songId: 2,
      title: 'Night Transfer',
      artist: 'Mira, Altair',
      artists: ['Mira', 'Altair'],
    ),
  ],
  artistMergeSuggestions: [
    ArtistSplitResultItem(
      songId: 3,
      title: 'After Rain',
      artist: 'Hana',
      artists: ['Hana', 'HANA'],
    ),
  ],
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
    'common.close': 'Close',
    'common.add': 'Add',
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
