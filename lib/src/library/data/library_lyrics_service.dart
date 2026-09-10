import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import 'id3_tag_service.dart';
import 'library_lyrics_encoding.dart';
import 'library_models.dart';
import 'package:smplayer_flutter/src/settings/settings_model.dart' as settings;

part 'library_lyrics_candidate_search.dart';
part 'library_lyrics_internet.dart';
part 'library_lyrics_parser.dart';

const _activeState = 1;
const _id3TagService = Id3TagService();

const _audioFileExtensions = {
  '.aac',
  '.aiff',
  '.alac',
  '.ape',
  '.flac',
  '.m4a',
  '.mp3',
  '.ogg',
  '.opus',
  '.wav',
  '.wma',
};
const _qqInvalidLyricsMarker = '濮濄倖鐡曢弴韫礋濞屸剝婀佹繅顐ョ槤閻ㄥ嫮鍑介棅鍏呯';
const _qqNoLyricsPlaceholder = '此歌曲为没有填词的纯音乐请您欣赏';

typedef InternetLyricsResolver = Future<String> Function(LibrarySong song);

class LibraryLyricsService {
  const LibraryLyricsService({
    required Future<settings.SettingsSnapshot?> Function()
    settingsSnapshotResolver,
    InternetLyricsResolver? internetLyricsResolver,
  }) : _settingsSnapshotResolver = settingsSnapshotResolver,
       _internetLyricsResolver = internetLyricsResolver;

  final Future<settings.SettingsSnapshot?> Function() _settingsSnapshotResolver;
  final InternetLyricsResolver? _internetLyricsResolver;

  Future<LyricsSnapshot> getSongLyrics(
    File databaseFile,
    int songId, {
    settings.LyricsRequestMode mode = settings.LyricsRequestMode.auto,
  }) async {
    final song = _getLyricsSongLookup(databaseFile, songId);
    final sidecarLyrics = await _getSidecarLyrics(song.path);

    if (mode == settings.LyricsRequestMode.embedded) {
      final embeddedLyrics = await _id3TagService.readEmbeddedLyrics(song.path);
      return _createLyricsSnapshot(
        embeddedLyrics,
        embeddedLyrics.trim().isEmpty
            ? LyricsSource.none
            : LyricsSource.musicFile,
      );
    }

    if (mode == settings.LyricsRequestMode.auto) {
      final embeddedLyrics = await _id3TagService.readEmbeddedLyrics(song.path);
      final localSnapshot =
          sidecarLyrics ??
          _createLyricsSnapshot(
            embeddedLyrics,
            embeddedLyrics.trim().isEmpty
                ? LyricsSource.none
                : LyricsSource.musicFile,
          );
      if (localSnapshot.isSynced) {
        return localSnapshot;
      }

      final internetSnapshot = await _getSyncedInternetLyrics(song);
      if (internetSnapshot != null) {
        return internetSnapshot;
      }

      return localSnapshot;
    }

    if (mode != settings.LyricsRequestMode.internet && sidecarLyrics != null) {
      return sidecarLyrics;
    }

    if (mode == settings.LyricsRequestMode.internet) {
      final rawLyrics = await _searchInternetLyrics(song);
      final internetLyrics = await _prepareInternetLyrics(rawLyrics);
      return _createLyricsSnapshot(
        internetLyrics,
        internetLyrics.trim().isEmpty
            ? LyricsSource.none
            : LyricsSource.internet,
      );
    }

    final embeddedLyrics = await _id3TagService.readEmbeddedLyrics(song.path);
    if (embeddedLyrics.trim().isNotEmpty) {
      return _createLyricsSnapshot(embeddedLyrics, LyricsSource.musicFile);
    }

    return _createLyricsSnapshot('', LyricsSource.none);
  }

  Future<String> readLyricsFromFile(String filePath) async {
    if (_isScannableAudioFile(filePath)) {
      return _id3TagService.readEmbeddedLyrics(filePath);
    }

    return readLocalLyricsText(File(filePath));
  }

  Future<LyricsSnapshot> getLocalLyricsForPath(String songPath) {
    return _getSongLyricsByPath(songPath);
  }

  Future<void> saveSongLyrics(
    File databaseFile,
    int songId,
    String rawLyrics,
  ) async {
    final songPath = _getSongPath(databaseFile, songId);
    await _writeLyricsToSongPath(songPath, rawLyrics);
  }

  Future<void> updateLyricsOffset(
    File databaseFile,
    int songId,
    int offsetMs,
  ) async {
    final db = sqlite3.open(databaseFile.path);
    try {
      db.execute(
        '''
        UPDATE Music
        SET LyricsOffsetMs = ?
        WHERE Id = ?
          AND State = ?
      ''',
        [offsetMs, songId, _activeState],
      );
    } finally {
      db.dispose();
    }
  }

  Future<LyricsSnapshot> getInternetLyrics(
    File databaseFile,
    int songId,
  ) async {
    final song = _getLyricsSongLookup(databaseFile, songId);
    final rawLyrics = await _searchInternetLyrics(song);
    final internetLyrics = await _prepareInternetLyrics(rawLyrics);
    return _createLyricsSnapshot(
      internetLyrics,
      internetLyrics.trim().isEmpty ? LyricsSource.none : LyricsSource.internet,
    );
  }

  Future<Uri> getLyricsSearchUri(File databaseFile, int songId) async {
    final song = _getLyricsSongLookup(databaseFile, songId);
    final settingsSnapshot = await _settingsSnapshotResolver();
    final preferredLanguage =
        settingsSnapshot?.preferredLanguage ??
        settings.PreferredLanguage.system;
    final isChineseLanguage =
        preferredLanguage == settings.PreferredLanguage.zhCN ||
        preferredLanguage == settings.PreferredLanguage.zhHant;
    final keyword = isChineseLanguage ? '歌词' : 'lyrics';
    final host =
        isChineseLanguage
            ? 'https://cn.bing.com/search'
            : 'https://www.bing.com/search';
    final query = [
      keyword,
      song.title,
      song.artist,
    ].where((value) => value.isNotEmpty).join(' ');
    return Uri.parse('$host?q=${Uri.encodeQueryComponent(query)}');
  }

  Future<LyricsBatchResult> batchAddInternetLyrics({
    required List<LibrarySong> songs,
    bool overwrite = false,
    void Function(LyricsBatchProgress progress)? onProgress,
    void Function(LyricsBatchDetail detail, LyricsBatchProgress progress)?
    onDetailCompleted,
    bool Function()? isCanceled,
    Future<void> Function()? waitIfPaused,
  }) async {
    var saved = 0;
    var overwritten = 0;
    var skipped = 0;
    var missing = 0;
    var failed = 0;
    var backedUp = 0;
    var backupBytes = 0;
    var lastRequestStartedAt = DateTime.fromMillisecondsSinceEpoch(0);
    final details = <LyricsBatchDetail>[];

    for (var index = 0; index < songs.length; index += 1) {
      if (isCanceled?.call() == true) {
        break;
      }
      await waitIfPaused?.call();
      if (isCanceled?.call() == true) {
        break;
      }

      final song = songs[index];
      LyricsBatchProgress currentProgress() {
        return LyricsBatchProgress(
          currentIndex: index + 1,
          total: songs.length,
          currentSongTitle: [
            song.title,
            song.artist,
          ].where((part) => part.isNotEmpty).join(' - '),
          saved: saved,
          overwritten: overwritten,
          skipped: skipped,
          missing: missing,
          failed: failed,
          backedUp: backedUp,
          backupBytes: backupBytes,
        );
      }

      void recordDetail(LyricsBatchDetail detail) {
        details.add(detail);
        final progress = currentProgress();
        onProgress?.call(progress);
        onDetailCompleted?.call(detail, progress);
      }

      onProgress?.call(currentProgress());

      try {
        final localLyrics = await _getSongLyricsByPath(song.path);
        final existingRawLyrics = localLyrics.rawText;
        if (!overwrite && existingRawLyrics.trim().isNotEmpty) {
          skipped += 1;
          recordDetail(
            LyricsBatchDetail(
              songId: song.id,
              title: song.title,
              artist: song.artist,
              thumbnailPath: song.thumbnailPath,
              result: LyricsBatchDetailResult.skipped,
              reason: LyricsBatchSkipReason.alreadyExists,
              sourceRawLyrics: existingRawLyrics,
            ),
          );
          continue;
        }

        final elapsed =
            DateTime.now().difference(lastRequestStartedAt).inMilliseconds;
        if (lastRequestStartedAt.millisecondsSinceEpoch > 0 && elapsed < 200) {
          await Future<void>.delayed(Duration(milliseconds: 200 - elapsed));
        }
        if (isCanceled?.call() == true) {
          break;
        }
        if (!overwrite) {
          final latestLocalLyrics = await _getSongLyricsByPath(song.path);
          if (latestLocalLyrics.rawText.trim().isNotEmpty) {
            skipped += 1;
            recordDetail(
              LyricsBatchDetail(
                songId: song.id,
                title: song.title,
                artist: song.artist,
                thumbnailPath: song.thumbnailPath,
                result: LyricsBatchDetailResult.skipped,
                reason: LyricsBatchSkipReason.alreadyExists,
                sourceRawLyrics: latestLocalLyrics.rawText,
              ),
            );
            continue;
          }
        }
        lastRequestStartedAt = DateTime.now();
        final rawInternetLyrics =
            _internetLyricsResolver == null
                ? await _searchInternetLyrics(
                  _LyricsSongLookup(
                    id: song.id,
                    title: song.title,
                    artist: song.artist,
                    album: song.album,
                    path: song.path,
                  ),
                )
                : await _internetLyricsResolver(song);
        final internetLyrics =
            _isInvalidInternetLyricsResponse(rawInternetLyrics)
                ? ''
                : await _prepareInternetLyrics(rawInternetLyrics);
        if (isCanceled?.call() == true) {
          break;
        }

        if (internetLyrics.trim().isEmpty) {
          missing += 1;
          recordDetail(
            LyricsBatchDetail(
              songId: song.id,
              title: song.title,
              artist: song.artist,
              thumbnailPath: song.thumbnailPath,
              result: LyricsBatchDetailResult.missing,
              sourceRawLyrics: existingRawLyrics,
            ),
          );
          continue;
        }

        if (overwrite &&
            _normalizeLyricsForCompare(existingRawLyrics) ==
                _normalizeLyricsForCompare(internetLyrics)) {
          skipped += 1;
          recordDetail(
            LyricsBatchDetail(
              songId: song.id,
              title: song.title,
              artist: song.artist,
              thumbnailPath: song.thumbnailPath,
              result: LyricsBatchDetailResult.skipped,
              reason: LyricsBatchSkipReason.sameContent,
              sourceRawLyrics: existingRawLyrics,
              targetRawLyrics: internetLyrics,
            ),
          );
          continue;
        }

        if (existingRawLyrics.trim().isNotEmpty) {
          backedUp += 1;
          backupBytes += utf8.encode(existingRawLyrics).length;
        }
        await _writeLyricsToSongPath(song.path, internetLyrics);
        if (existingRawLyrics.trim().isEmpty) {
          saved += 1;
          recordDetail(
            LyricsBatchDetail(
              songId: song.id,
              title: song.title,
              artist: song.artist,
              thumbnailPath: song.thumbnailPath,
              result: LyricsBatchDetailResult.saved,
              targetRawLyrics: internetLyrics,
            ),
          );
        } else {
          overwritten += 1;
          recordDetail(
            LyricsBatchDetail(
              songId: song.id,
              title: song.title,
              artist: song.artist,
              thumbnailPath: song.thumbnailPath,
              result: LyricsBatchDetailResult.overwritten,
              sourceRawLyrics: existingRawLyrics,
              targetRawLyrics: internetLyrics,
            ),
          );
        }
      } on Object {
        failed += 1;
        recordDetail(
          LyricsBatchDetail(
            songId: song.id,
            title: song.title,
            artist: song.artist,
            thumbnailPath: song.thumbnailPath,
            result: LyricsBatchDetailResult.failed,
          ),
        );
      }
    }

    return LyricsBatchResult(
      total: songs.length,
      saved: saved,
      overwritten: overwritten,
      skipped: skipped,
      missing: missing,
      failed: failed,
      backedUp: backedUp,
      backupBytes: backupBytes,
      details: details,
    );
  }

  Future<void> autoAddInternetLyricsForPaths(
    File databaseFile,
    List<String> songPaths,
  ) async {
    if (songPaths.isEmpty) {
      return;
    }
    final songPathKeys = songPaths.map(_pathComparisonKey).toSet();
    final db = sqlite3.open(databaseFile.path);
    final songs = <LibrarySong>[];
    try {
      final rows = db.select(
        '''
        SELECT
          Id AS id,
          Path AS path,
          Name AS title,
          Artist AS artist,
          Album AS album
        FROM Music
        WHERE State = ?
      ''',
        [_activeState],
      );
      for (final row in rows) {
        final path = row['path'] as String;
        if (!songPathKeys.contains(_pathComparisonKey(path))) {
          continue;
        }
        songs.add(
          LibrarySong(
            id: row['id'] as int,
            path: path,
            title:
                (row['title'] as String?) ?? p.basenameWithoutExtension(path),
            artist: (row['artist'] as String?) ?? '',
            artists: _normalizeArtists([(row['artist'] as String?) ?? '']),
            album: (row['album'] as String?) ?? '',
            duration: 0,
            playCount: 0,
            lyricsOffsetMs: 0,
            dateAdded: '',
            favorite: false,
            thumbnailPath: '',
          ),
        );
      }
    } finally {
      db.dispose();
    }
    for (final song in songs) {
      final localLyrics = await _getSongLyricsByPath(song.path);
      if (localLyrics.rawText.trim().isNotEmpty) {
        continue;
      }
      final internetLyrics =
          _internetLyricsResolver == null
              ? await _searchInternetLyrics(
                _LyricsSongLookup(
                  id: song.id,
                  title: song.title,
                  artist: song.artist,
                  album: song.album,
                  path: song.path,
                ),
              )
              : await _internetLyricsResolver(song);
      if (internetLyrics.trim().isNotEmpty) {
        await _writeLyricsToSongPath(song.path, internetLyrics);
      }
    }
  }

  bool readAutoLyricsEnabled(Database db) {
    final hasAutoLyricsColumn = db
        .select("PRAGMA table_info('Settings')")
        .any((row) => row['name'] == 'AutoLyrics');
    if (!hasAutoLyricsColumn) {
      return false;
    }
    final rows = db.select('''
      SELECT AutoLyrics AS autoLyrics
      FROM Settings
      ORDER BY Id
      LIMIT 1
    ''');
    return rows.isNotEmpty && (rows.first['autoLyrics'] as int) != 0;
  }

  String _getSongPath(File databaseFile, int songId) {
    final db = sqlite3.open(databaseFile.path);
    try {
      final rows = db.select(
        '''
        SELECT Path AS path
        FROM Music
        WHERE Id = ?
          AND State = ?
        LIMIT 1
      ''',
        [songId, _activeState],
      );
      return rows.first['path'] as String;
    } finally {
      db.dispose();
    }
  }

  _LyricsSongLookup _getLyricsSongLookup(File databaseFile, int songId) {
    final db = sqlite3.open(databaseFile.path);
    try {
      final rows = db.select(
        '''
        SELECT
          Path AS path,
          Name AS title,
          Artist AS artist,
          Album AS album
        FROM Music
        WHERE Id = ?
          AND State = ?
        LIMIT 1
      ''',
        [songId, _activeState],
      );
      final row = rows.first;
      return _LyricsSongLookup(
        id: songId,
        title: row['title'] as String,
        artist: row['artist'] as String,
        album: row['album'] as String,
        path: row['path'] as String,
      );
    } finally {
      db.dispose();
    }
  }

  Future<LyricsSnapshot> _getSongLyricsByPath(String songPath) async {
    final sidecarLyrics = await _getSidecarLyrics(songPath);
    if (sidecarLyrics != null) {
      return sidecarLyrics;
    }

    final embeddedLyrics = await _id3TagService.readEmbeddedLyrics(songPath);
    if (embeddedLyrics.trim().isNotEmpty) {
      return _createLyricsSnapshot(embeddedLyrics, LyricsSource.musicFile);
    }

    return _createLyricsSnapshot('', LyricsSource.none);
  }

  String _normalizeLyricsForCompare(String rawLyrics) {
    final withoutLeadingBom =
        rawLyrics.startsWith('\ufeff') ? rawLyrics.substring(1) : rawLyrics;
    return withoutLeadingBom
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .trim();
  }

  Future<LyricsSnapshot?> _getSidecarLyrics(String songPath) async {
    final lrcFile = File(p.setExtension(songPath, '.lrc'));
    if (await lrcFile.exists()) {
      final lrcText = await readLocalLyricsText(lrcFile);
      if (lrcText.trim().isNotEmpty) {
        return _createLyricsSnapshot(lrcText, LyricsSource.lrcFile);
      }
    }

    final textFile = File(p.setExtension(songPath, '.txt'));
    if (await textFile.exists()) {
      final text = await readLocalLyricsText(textFile);
      if (text.trim().isNotEmpty) {
        return _createLyricsSnapshot(text, LyricsSource.textFile);
      }
    }

    return null;
  }

  Future<void> _writeLyricsToSongPath(String songPath, String rawLyrics) async {
    final lrcFile = File(p.setExtension(songPath, '.lrc'));
    final textFile = File(p.setExtension(songPath, '.txt'));
    if (p.extension(songPath).toLowerCase() == '.mp3') {
      await _id3TagService.writeEmbeddedLyrics(songPath, rawLyrics);
      if (await lrcFile.exists()) {
        await lrcFile.writeAsString(rawLyrics);
      }
      if (await textFile.exists()) {
        await textFile.writeAsString(rawLyrics);
      }
      return;
    }

    if (await lrcFile.exists()) {
      await lrcFile.writeAsString(rawLyrics);
      if (rawLyrics.trim().isNotEmpty) {
        return;
      }
    }

    if (await textFile.exists()) {
      await textFile.writeAsString(rawLyrics);
      if (rawLyrics.trim().isNotEmpty) {
        return;
      }
    }

    await lrcFile.writeAsString(rawLyrics);
  }
}

class _LyricsSongLookup {
  const _LyricsSongLookup({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.path,
  });

  final int id;
  final String title;
  final String artist;
  final String album;
  final String path;
}

class LyricsBatchProgress {
  const LyricsBatchProgress({
    required this.currentIndex,
    required this.total,
    required this.currentSongTitle,
    required this.saved,
    required this.overwritten,
    required this.skipped,
    required this.missing,
    required this.failed,
    required this.backedUp,
    required this.backupBytes,
  });

  final int currentIndex;
  final int total;
  final String currentSongTitle;
  final int saved;
  final int overwritten;
  final int skipped;
  final int missing;
  final int failed;
  final int backedUp;
  final int backupBytes;
}

class LyricsBatchResult {
  const LyricsBatchResult({
    required this.total,
    required this.saved,
    required this.overwritten,
    required this.skipped,
    required this.missing,
    required this.failed,
    required this.backedUp,
    required this.backupBytes,
    required this.details,
  });

  final int total;
  final int saved;
  final int overwritten;
  final int skipped;
  final int missing;
  final int failed;
  final int backedUp;
  final int backupBytes;
  final List<LyricsBatchDetail> details;
}

enum LyricsBatchDetailResult { saved, overwritten, skipped, missing, failed }

enum LyricsBatchSkipReason { alreadyExists, sameContent }

class LyricsBatchDetail {
  const LyricsBatchDetail({
    required this.songId,
    required this.title,
    required this.artist,
    required this.thumbnailPath,
    required this.result,
    this.reason,
    this.sourceRawLyrics = '',
    this.targetRawLyrics = '',
  });

  final int songId;
  final String title;
  final String artist;
  final String thumbnailPath;
  final LyricsBatchDetailResult result;
  final LyricsBatchSkipReason? reason;
  final String sourceRawLyrics;
  final String targetRawLyrics;
}

class _LyricsSearchAttempt {
  const _LyricsSearchAttempt({
    required this.keyword,
    required this.title,
    required this.artist,
    required this.originalTitle,
  });

  final String keyword;
  final String title;
  final String artist;
  final String originalTitle;
}

String _normalizeTagText(String value) {
  return value.trim();
}

List<String> _normalizeArtists(List<String> artists) {
  return artists
      .map(_normalizeTagText)
      .where((artist) => artist.isNotEmpty)
      .toSet()
      .toList();
}

bool _isScannableAudioFile(String filePath) {
  return !p.basename(filePath).startsWith('._') &&
      _audioFileExtensions.contains(p.extension(filePath).toLowerCase());
}

String _pathComparisonKey(String path) {
  return path.replaceAll('\\', '/').toLowerCase();
}
