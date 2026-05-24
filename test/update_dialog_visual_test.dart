import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/ui/default_album_artwork.dart';
import 'package:smplayer_flutter/src/library/ui/folder_update_result_dialog.dart';
import 'package:smplayer_flutter/src/library/ui/local_folder_model.dart';
import 'package:smplayer_flutter/src/library/ui/scan_progress_overlay.dart';

void main() {
  testWidgets('capture update dialogs', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _capture(
      tester,
      'progress',
      const ScanProgressOverlay(
        title: 'Updating local folder',
        progress: LocalFolderRefreshProgress(
          current: 42,
          total: 100,
          currentPath: '/Users/me/Music/Album',
          stage: LocalFolderRefreshStage.checking,
          checkedFolderCount: 42,
          folderCount: 100,
          processedSongCount: 18,
          songCount: 80,
          addedCount: 3,
          updatedCount: 2,
          missingCount: 1,
          canCancel: true,
        ),
        onCancel: _noop,
      ),
    );

    await _capture(
      tester,
      'result',
      FolderUpdateResultDialog(
        folder: createFolderNode('', '/Users/me/Music'),
        result: const LocalFolderRefreshResult(
          filesAdded: ['/Users/me/Music/New Song.mp3'],
          filesRemoved: ['/Users/me/Music/Removed Song.mp3'],
          filesMoved: ['/Users/me/Music/Moved Song.mp3'],
          artistSplitsApplied: [],
          artistSplitSuggestions: [],
          artistMergeSuggestions: [],
        ),
        songs: const [
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
        ],
        selectedTrackId: 1,
        isPlaying: true,
        onPlay: (_) {},
        onClose: _noop,
      ),
    );
  });
}

Future<void> _capture(WidgetTester tester, String name, Widget child) async {
  final key = GlobalKey();
  await tester.pumpWidget(
    SmPlayerI18nScope(
      i18n: _i18n,
      child: MaterialApp(
        theme: ThemeData(
          extensions: const [DefaultAlbumArtworkThemeColors.light],
        ),
        home: RepaintBoundary(
          key: key,
          child: Material(color: const Color(0xfff3f6fa), child: child),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 1);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  await File(
    '/tmp/smplayer_update_dialog_$name.png',
  ).writeAsBytes(bytes!.buffer.asUint8List());
}

void _noop() {}

const _i18n = SmPlayerI18n(
  locale: 'en-US',
  messages: {
    'common.artistSeparator': ', ',
    'common.close': 'Close',
    'local.libraryRoot': 'Library root',
    'local.refreshAddedTab': 'Added',
    'local.refreshArtistUpdatesTab': 'Artists',
    'local.refreshMovedTab': 'Moved',
    'local.refreshNoChange': 'No changes',
    'local.refreshRemovedTab': 'Removed',
    'local.updateFolderProgressActionChecking':
        'Scanning folders and audio files',
    'local.updateFolderProgressActionReading':
        'Reading tags, cover and audio information',
    'local.updateFolderProgressActionUpdating':
        'Writing to music library and syncing index',
    'local.updateFolderProgressAdded': 'Added',
    'local.updateFolderProgressChecked': 'Checked: {count} / {total} folders',
    'local.updateFolderProgressCurrentFolder':
        'Current scanning folder: {name}',
    'local.updateFolderProgressMissing': 'Missing',
    'local.updateFolderProgressPreparing': 'Preparing',
    'local.updateFolderProgressProcessedItems':
        'Processed: {count} / {total} items',
    'local.updateFolderProgressProcessedSongs':
        'Processed: {count} / {total} songs',
    'local.updateFolderProgressSongUnit': 'songs',
    'local.updateFolderProgressStop': 'Stop update',
    'local.updateFolderProgressTitle': 'Updating local folder',
    'local.updateFolderProgressUpdated': 'Updated',
    'local.updateResultOfFolder': 'Update result of "{name}"',
  },
);
