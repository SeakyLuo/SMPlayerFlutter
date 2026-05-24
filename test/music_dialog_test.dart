import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smplayer_flutter/src/app/app_appearance_model.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
import 'package:smplayer_flutter/src/library/data/library_repository.dart';
import 'package:smplayer_flutter/src/library/ui/music_dialog.dart';
import 'package:smplayer_flutter/src/settings/settings_model.dart'
    show LyricsRequestMode, SettingsSnapshot;

void main() {
  testWidgets('MusicDialog preserves timed lyrics when timestamps are hidden', (
    tester,
  ) async {
    final repository = _FakeMusicDialogRepository();

    await tester.pumpWidget(
      _MusicDialogTestApp(
        repository: repository,
        initialMode: SongDialogMode.lyrics,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('[00:01.00]Original line'), findsOneWidget);

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    expect(find.text('Original line'), findsOneWidget);
    expect(find.text('[00:01.00]Original line'), findsNothing);

    await tester.enterText(find.byType(TextField).last, 'Edited line');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.savedLyrics, '[00:01.00]Edited line');
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('MusicDialog applies recommended library album art', (
    tester,
  ) async {
    final repository = _FakeMusicDialogRepository();

    await tester.pumpWidget(
      _MusicDialogTestApp(
        repository: repository,
        initialMode: SongDialogMode.albumArt,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('"Match Song"'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.savedArtworkPath, repository.recommendedArtworkPath);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets(
    'MusicDialog search loads internet lyrics before browser fallback',
    (tester) async {
      final repository =
          _FakeMusicDialogRepository()
            ..internetLyrics = '[00:02.00]Internet line';

      await tester.pumpWidget(
        _MusicDialogTestApp(
          repository: repository,
          initialMode: SongDialogMode.lyrics,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();

      expect(find.text('[00:02.00]Internet line'), findsOneWidget);
      expect(repository.internetLyricsRequested, isTrue);
      await tester.pump(const Duration(seconds: 3));
    },
  );

  test('musicLyricsSearchUri follows the app locale like Electron settings', () {
    expect(
      musicLyricsSearchUri(
        locale: 'zh-CN',
        title: '标题',
        artist: '歌手',
      ).toString(),
      'https://cn.bing.com/search?q=%E6%AD%8C%E8%AF%8D+%E6%A0%87%E9%A2%98+%E6%AD%8C%E6%89%8B',
    );
    expect(
      musicLyricsSearchUri(
        locale: 'en-US',
        title: 'Title',
        artist: 'Artist',
      ).toString(),
      'https://www.bing.com/search?q=lyrics+Title+Artist',
    );
  });

  testWidgets('MusicDialog shortcuts mirror Electron dialog shortcuts', (
    tester,
  ) async {
    final repository =
        _FakeMusicDialogRepository()
          ..internetLyrics = '[00:02.00]Internet line';

    await tester.pumpWidget(
      _MusicDialogTestApp(
        repository: repository,
        initialMode: SongDialogMode.lyrics,
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, 'Edited line');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(find.text('[00:01.00]Original line'), findsOneWidget);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(repository.internetLyricsRequested, isTrue);
    expect(find.text('[00:02.00]Internet line'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, '[00:03.00]Saved line');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    expect(repository.savedLyrics, '[00:03.00]Saved line');
    await tester.pump(const Duration(seconds: 3));
  });
}

class _MusicDialogTestApp extends StatelessWidget {
  const _MusicDialogTestApp({
    required this.repository,
    required this.initialMode,
  });

  final _FakeMusicDialogRepository repository;
  final SongDialogMode initialMode;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [libraryRepositoryProvider.overrideWithValue(repository)],
      child: SmPlayerI18nScope(
        i18n: _i18n,
        child: MaterialApp(
          theme: buildSmPlayerTheme(const SettingsSnapshot.defaults()),
          home: Scaffold(
            body: MusicDialog(
              song: _currentSong,
              initialMode: initialMode,
              onClose: () {},
            ),
          ),
        ),
      ),
    );
  }
}

class _FakeMusicDialogRepository extends LibraryRepository {
  _FakeMusicDialogRepository() {
    final bytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
    );
    final artworkFile = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}smplayer-dialog-test-art.png',
    )..writeAsBytesSync(bytes);
    recommendedArtworkPath = artworkFile.path;
  }

  late final String recommendedArtworkPath;
  String savedLyrics = '';
  String savedArtworkPath = '';
  String internetLyrics = '';
  bool internetLyricsRequested = false;

  @override
  Future<LibraryViewData> getLibraryViewData() async {
    return LibraryViewData(
      songs: [
        _currentSong,
        LibrarySong(
          id: 2,
          path: 'match.mp3',
          title: 'Match Song',
          artist: 'Artist',
          artists: const ['Artist'],
          album: 'Album',
          duration: 180,
          playCount: 4,
          lyricsOffsetMs: 0,
          dateAdded: '2026-01-01T00:00:00Z',
          favorite: false,
          thumbnailPath: recommendedArtworkPath,
        ),
      ],
      hasLibrary: true,
      sortCriterion: MusicLibrarySortCriterion.title,
      albumsSort: AlbumSortCriterion.defaultSort,
      databasePath: '',
    );
  }

  @override
  Future<SongPropertiesSnapshot> getSongProperties(int songId) async {
    return const SongPropertiesSnapshot(
      songId: 1,
      path: 'song.mp3',
      title: 'Current Song',
      subtitle: '',
      artist: 'Artist',
      artists: ['Artist'],
      album: 'Album',
      albumArtist: '',
      publisher: '',
      trackNumber: 0,
      year: 0,
      genre: '',
      composers: '',
      duration: 180,
      bitrate: 0,
      fileSize: 1024,
      dateCreated: '2026-01-01T00:00:00Z',
      dateModified: '2026-01-01T00:00:00Z',
      fileType: 'MP3',
      playCount: 0,
    );
  }

  @override
  Future<LyricsSnapshot> getSongLyrics(
    int songId, {
    LyricsRequestMode mode = LyricsRequestMode.auto,
  }) async {
    return const LyricsSnapshot(
      source: LyricsSource.lrcFile,
      isSynced: true,
      rawText: '[00:01.00]Original line',
      lines: [LyricsLine(id: 0, timestampMs: 1000, text: 'Original line')],
    );
  }

  @override
  Future<void> saveSongLyrics(int songId, String rawLyrics) async {
    savedLyrics = rawLyrics;
  }

  @override
  Future<LyricsSnapshot> getInternetLyrics(int songId) async {
    internetLyricsRequested = true;
    return LyricsSnapshot(
      source:
          internetLyrics.isEmpty ? LyricsSource.none : LyricsSource.internet,
      isSynced: internetLyrics.contains('[00:02.00]'),
      rawText: internetLyrics,
      lines:
          internetLyrics.isEmpty
              ? const []
              : const [
                LyricsLine(id: 0, timestampMs: 2000, text: 'Internet line'),
              ],
    );
  }

  @override
  Future<SongArtworkSnapshot> getSongArtworkSnapshot(int songId) async {
    return const SongArtworkSnapshot(
      songId: 1,
      artworkUrl: '',
      sourceUrl: '',
      sourcePath: '',
      source: SongArtworkSource.none,
    );
  }

  @override
  Future<List<SongArtworkSnapshot>> getSongArtworkSnapshots(
    List<int> songIds,
  ) async {
    return [
      for (final songId in songIds)
        SongArtworkSnapshot(
          songId: songId,
          artworkUrl: songId == 2 ? recommendedArtworkPath : '',
          sourceUrl: songId == 2 ? recommendedArtworkPath : '',
          sourcePath: songId == 2 ? recommendedArtworkPath : '',
          source:
              songId == 2 ? SongArtworkSource.cached : SongArtworkSource.none,
        ),
    ];
  }

  @override
  Future<String> prepareSongArtworkSource(String sourcePath) async {
    return sourcePath;
  }

  @override
  Future<void> saveSongArtwork(int songId, String sourcePath) async {
    savedArtworkPath = sourcePath;
  }
}

const _currentSong = LibrarySong(
  id: 1,
  path: 'song.mp3',
  title: 'Current Song',
  artist: 'Artist',
  artists: ['Artist'],
  album: 'Album',
  duration: 180,
  playCount: 0,
  lyricsOffsetMs: 0,
  dateAdded: '2026-01-01T00:00:00Z',
  favorite: false,
  thumbnailPath: '',
);

const _i18n = SmPlayerI18n(
  locale: 'en-US',
  messages: {
    'common.add': 'Add',
    'common.album': 'Album',
    'common.albumUnknown': 'Unknown Album',
    'common.artist': 'Artist',
    'common.artistSeparator': ' / ',
    'common.artistUnknown': 'Unknown Artist',
    'common.cancel': 'Cancel',
    'common.close': 'Close',
    'common.confirm': 'Confirm',
    'common.duration': 'Duration',
    'common.playCount': 'Play Count',
    'common.reset': 'Reset',
    'common.search': 'Search',
    'common.yes': 'Yes',
    'context.pause': 'Pause',
    'context.play': 'Play',
    'context.seeAlbumArt': 'See Album Art',
    'context.seeLyrics': 'See Lyrics',
    'context.seeMusicInfo': 'See Music Info',
    'local.path': 'Path',
    'nowPlaying.loading': 'Loading',
    'nowPlaying.noLyrics': 'No Lyrics',
    'player.more': 'More',
    'playlists.delete': 'Delete',
    'playlists.removeSelected': 'Remove',
    'settings.save': 'Save',
    'song.albumArtDeleted': 'Album art deleted',
    'song.albumArtRecommendationPrefix': 'Smart match: use {artist}\'s ',
    'song.albumArtRecommendationSuffix': ' as the cover',
    'song.albumArtRecommendationTitle': '"{title}"',
    'song.albumArtReset': 'Album art reset',
    'song.albumArtSaved': 'New album art has been saved!',
    'song.albumArtist': 'Album Artist',
    'song.bitrate': 'Bitrate',
    'song.changeArtwork': 'Change Artwork',
    'song.chooseArtworkFromLibrary': 'Choose from library',
    'song.chooseArtworkFromLocal': 'Choose local file',
    'song.clearPlayCount': 'Clear',
    'song.composers': 'Composers',
    'song.dateCreated': 'Date Created',
    'song.dateModified': 'Date Modified',
    'song.discardLyricsConfirm': 'Discard unsaved lyrics changes?',
    'song.fileSize': 'File Size',
    'song.fileType': 'File Type',
    'song.genre': 'Genre',
    'song.importLyricsFailed': 'Failed to import lyrics.',
    'song.lyricsReset': 'Lyrics reset',
    'song.lyricsUpdated': 'The lyrics of "{title}" have been updated!',
    'song.noAlbumArt': 'No album art',
    'song.noLibraryArtwork': 'No available album art in the library',
    'song.nothingChanged': 'No changes were detected.',
    'song.openBrowserSuccessful': 'Browser opened.',
    'song.processingRequest': 'Processing',
    'song.propertiesReset': 'Properties reset',
    'song.propertiesUpdated': 'Properties updated',
    'song.publisher': 'Publisher',
    'song.removeAlbumArt': 'Remove {title} art?',
    'song.searchLibraryArtwork': 'Search songs, artists, or albums',
    'song.searchLyricsFailed': 'No matching lyrics found.',
    'song.showInExplorer': 'Show in Explorer',
    'song.showLyricsTimestamps': 'Show timestamps',
    'song.subtitle': 'Subtitle',
    'song.trackNumber': 'Track Number',
    'song.updateFailed': 'Update failed',
    'song.useSelectedArtwork': 'Use this cover',
    'song.year': 'Year',
    'table.title': 'Title',
  },
);
