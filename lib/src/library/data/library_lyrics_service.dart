import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import 'id3_tag_service.dart';
import 'library_models.dart';
import 'package:smplayer_flutter/src/settings/settings_model.dart' as settings;

part 'library_lyrics_candidate_search.dart';

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

    return File(filePath).readAsString();
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
        lastRequestStartedAt = DateTime.now();
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

  Future<String> _searchInternetLyrics(_LyricsSongLookup song) async {
    final resolver = _internetLyricsResolver;
    if (resolver != null) {
      final lyrics = await resolver(
        LibrarySong(
          id: song.id,
          path: song.path,
          title: song.title,
          artist: song.artist,
          artists: const [],
          album: song.album,
          duration: 0,
          playCount: 0,
          lyricsOffsetMs: 0,
          dateAdded: '',
          favorite: false,
          thumbnailPath: '',
        ),
      );
      return _isInvalidInternetLyricsResponse(lyrics) ? '' : lyrics;
    }

    final songMid = await _getSongMid(song);
    if (songMid.isEmpty) {
      return '';
    }

    try {
      return await _getRawLyricsBySongMid(songMid);
    } catch (_) {
      return '';
    }
  }

  Future<String> _getRawLyricsBySongMid(String songMid) async {
    final uri = Uri.parse(
      'https://c.y.qq.com/lyric/fcgi-bin/fcg_query_lyric_new.fcg',
    ).replace(
      queryParameters: {'songmid': songMid, 'format': 'json', 'nobase64': '1'},
    );
    final response = await _fetchLyricsJson(uri);
    return _decodeHtmlEntities(response['lyric'] as String? ?? '').trim();
  }

  Future<LyricsSnapshot?> _getSyncedInternetLyrics(
    _LyricsSongLookup song,
  ) async {
    final rawLyrics = await _searchInternetLyrics(song);
    if (rawLyrics.trim().isEmpty) {
      return null;
    }

    final snapshot = _createLyricsSnapshot(rawLyrics, LyricsSource.internet);
    return snapshot.isSynced && snapshot.lines.isNotEmpty ? snapshot : null;
  }

  Future<String> _prepareInternetLyrics(String rawLyrics) async {
    if (_isNoLyricsPlaceholder(rawLyrics)) {
      return '';
    }

    final snapshot = await _settingsSnapshotResolver();
    return _prepareInternetLyricsWithPreference(
      rawLyrics,
      preserveTimestamps:
          snapshot == null || snapshot.preserveInternetLyricsTimestamps,
    );
  }

  String _prepareInternetLyricsWithPreference(
    String rawLyrics, {
    required bool preserveTimestamps,
  }) {
    if (_isNoLyricsPlaceholder(rawLyrics)) {
      return '';
    }
    return preserveTimestamps ? rawLyrics : _stripLyricsTimestamps(rawLyrics);
  }

  String _stripLyricsTimestamps(String rawText) {
    final timestampRegex = RegExp(r'\[\d{1,2}:\d{2}(?:[.:]\d{1,3})?\]');
    final metadataRegex = RegExp(
      r'^\[(ti|ar|al|au|by|offset|re|ve|length):.*\]$',
      caseSensitive: false,
    );
    return rawText
        .split(RegExp(r'\r\n|[\n\r\u2028\u2029]'))
        .map((line) {
          final trimmedLine = line.trim();
          if (metadataRegex.hasMatch(trimmedLine)) {
            return '';
          }
          return line.replaceAll(timestampRegex, '').trimLeft();
        })
        .join('\n')
        .trim();
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

  Future<String> _getSongMid(_LyricsSongLookup song) async {
    for (final attempt in _buildLyricsSearchAttempts(song)) {
      final songMid = await _searchSongMidByKeyword(
        attempt.keyword,
        attempt.title,
        attempt.artist,
      );
      if (songMid.isNotEmpty) {
        return songMid;
      }
    }

    return '';
  }

  List<_LyricsSearchAttempt> _buildLyricsSearchAttempts(
    _LyricsSongLookup song,
  ) {
    final simplifiedTitle = _removeBraces(song.title);
    final simplifiedArtist = _removeBraces(song.artist);
    final attempts = [
      _LyricsSearchAttempt(
        keyword: '${song.title} ${song.artist}'.trim(),
        title: song.title,
        artist: song.artist,
        originalTitle: song.title,
      ),
      _LyricsSearchAttempt(
        keyword: song.title,
        title: song.title,
        artist: song.artist,
        originalTitle: song.title,
      ),
      _LyricsSearchAttempt(
        keyword: '$simplifiedTitle ${song.artist}'.trim(),
        title: simplifiedTitle,
        artist: song.artist,
        originalTitle: song.title,
      ),
      _LyricsSearchAttempt(
        keyword: '${song.title} $simplifiedArtist'.trim(),
        title: song.title,
        artist: simplifiedArtist,
        originalTitle: song.title,
      ),
      _LyricsSearchAttempt(
        keyword: '$simplifiedTitle $simplifiedArtist'.trim(),
        title: simplifiedTitle,
        artist: simplifiedArtist,
        originalTitle: song.title,
      ),
      _LyricsSearchAttempt(
        keyword: simplifiedTitle,
        title: simplifiedTitle,
        artist: simplifiedArtist,
        originalTitle: song.title,
      ),
    ];
    final seen = <String>{};
    return [
      for (final attempt in attempts)
        if (attempt.keyword.isNotEmpty &&
            seen.add('${attempt.keyword}\n${attempt.title}\n${attempt.artist}'))
          attempt,
    ];
  }

  Future<String> _searchSongMidByKeyword(
    String keyword,
    String title,
    String artist,
  ) async {
    final uri = Uri.parse(
      'https://c.y.qq.com/splcloud/fcgi-bin/smartbox_new.fcg',
    ).replace(
      queryParameters: {
        'cv': '4747474',
        'ct': '24',
        'format': 'json',
        'inCharset': 'utf-8',
        'outCharset': 'utf-8',
        'notice': '0',
        'platform': 'yqq.json',
        'needNewCode': '1',
        'key': keyword,
      },
    );
    try {
      final response = await _fetchLyricsJson(uri);
      final data = response['data'] as Map<String, Object?>?;
      final song = data?['song'] as Map<String, Object?>?;
      final items = song?['itemlist'] as List<Object?>? ?? const [];
      Map<String, Object?>? bestMatch;
      var bestScore = -1;

      for (final item in items.whereType<Map<String, Object?>>()) {
        final score =
            _evaluateLyricsMatch(title, item['name'] as String? ?? '') * 2 +
            _evaluateLyricsMatch(artist, item['singer'] as String? ?? '');
        if (score > bestScore) {
          bestScore = score;
          bestMatch = item;
        }
      }

      return bestScore > 0 ? (bestMatch?['mid'] as String? ?? '') : '';
    } catch (_) {
      return '';
    }
  }

  Future<Map<String, Object?>> _fetchLyricsJson(Uri uri) async {
    final response = await http
        .get(
          uri,
          headers: const {
            'accept': 'application/json',
            'accept-language': 'en-US',
            'referer': 'https://y.qq.com/portal/player.html',
            'user-agent': 'Mozilla/5.0',
          },
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('Lyrics request failed: ${response.statusCode}');
    }

    return jsonDecode(response.body) as Map<String, Object?>;
  }

  int _evaluateLyricsMatch(String target, String candidate) {
    final normalizedTarget = _normalizeLyricsLookupText(target);
    final normalizedCandidate = _normalizeLyricsLookupText(candidate);
    if (normalizedTarget.isEmpty) {
      return normalizedCandidate.isNotEmpty ? 20 : 0;
    }
    if (normalizedTarget == normalizedCandidate) {
      return 100;
    }
    if (normalizedCandidate.contains(normalizedTarget) ||
        normalizedTarget.contains(normalizedCandidate)) {
      return 70;
    }

    final targetTokens = normalizedTarget
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty);
    final candidateTokens = normalizedCandidate
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty);
    var score = 0;
    for (final token in targetTokens) {
      if (candidateTokens.any(
        (candidateToken) =>
            candidateToken.contains(token) || token.contains(candidateToken),
      )) {
        score += 20;
      }
    }
    return score;
  }

  int _evaluateLyricsVersionMatch(String target, String candidate) {
    final targetVersions = _lyricsVersionTokens(target);
    final candidateVersions = _lyricsVersionTokens(candidate);
    if (targetVersions.isEmpty) {
      return -30 * candidateVersions.length;
    }
    if (targetVersions.length == candidateVersions.length &&
        targetVersions.containsAll(candidateVersions)) {
      return 60;
    }

    final shared = targetVersions.intersection(candidateVersions).length;
    final missing = targetVersions.difference(candidateVersions).length;
    final extra = candidateVersions.difference(targetVersions).length;
    return shared * 30 - missing * 50 - extra * 15;
  }

  Set<String> _lyricsVersionTokens(String value) {
    final normalized = value.toLowerCase();
    final versions = <String>{};
    if (RegExp(r'(^|[^a-z])live([^a-z]|$)').hasMatch(normalized) ||
        normalized.contains('现场') ||
        normalized.contains('演唱会')) {
      versions.add('live');
    }
    if (normalized.contains('remix') || normalized.contains('混音')) {
      versions.add('remix');
    }
    if (normalized.contains('acoustic') || normalized.contains('不插电')) {
      versions.add('acoustic');
    }
    if (normalized.contains('instrumental') ||
        normalized.contains('off vocal') ||
        normalized.contains('伴奏') ||
        normalized.contains('纯音乐')) {
      versions.add('instrumental');
    }
    if (normalized.contains('demo')) {
      versions.add('demo');
    }
    if (normalized.contains('remaster') || normalized.contains('重制')) {
      versions.add('remaster');
    }
    if (normalized.contains('radio edit') ||
        normalized.contains('extended edit')) {
      versions.add('edit');
    }
    if (normalized.contains('karaoke') || normalized.contains('卡拉ok')) {
      versions.add('karaoke');
    }
    return versions;
  }

  String _normalizeLyricsLookupText(String value) {
    return _removeBraces(value)
        .toLowerCase()
        .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _removeBraces(String value) {
    return value
        .replaceAll(RegExp(r'\([^)]*\)'), ' ')
        .replaceAll(RegExp(r'\[[^\]]*]'), ' ')
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _decodeHtmlEntities(String value) {
    return value
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAllMapped(RegExp(r'&#(\d+);'), (match) {
          return String.fromCharCode(int.parse(match.group(1)!));
        })
        .replaceAll(r'\n', '\n');
  }

  bool _isNoLyricsPlaceholder(String rawLyrics) {
    final normalized =
        rawLyrics
            .replaceAll(
              RegExp(
                r'\[(ti|ar|al|au|by|offset|re|ve|length):[^\]]*\]',
                caseSensitive: false,
              ),
              ' ',
            )
            .replaceAll(RegExp(r'\[\d{1,2}:\d{2}(?:[.:]\d{1,3})?\]'), ' ')
            .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), '')
            .toLowerCase();
    if (normalized.isEmpty) {
      return false;
    }

    return normalized.contains(_qqNoLyricsPlaceholder);
  }

  bool _isInvalidInternetLyricsResponse(String rawLyrics) {
    return rawLyrics.trim().isEmpty ||
        rawLyrics.contains(_qqInvalidLyricsMarker) ||
        _isNoLyricsPlaceholder(rawLyrics);
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
      final lrcText = await lrcFile.readAsString();
      if (lrcText.trim().isNotEmpty) {
        return _createLyricsSnapshot(lrcText, LyricsSource.lrcFile);
      }
    }

    final textFile = File(p.setExtension(songPath, '.txt'));
    if (await textFile.exists()) {
      final text = await textFile.readAsString();
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

  LyricsSnapshot _createLyricsSnapshot(String rawText, LyricsSource source) {
    final normalizedText = rawText.replaceFirst('\uFEFF', '').trim();
    final lines = _parseLyricsLines(normalizedText);
    return LyricsSnapshot(
      source: source,
      isSynced: lines.any((line) => line.timestampMs != null),
      rawText: normalizedText,
      lines: lines,
    );
  }

  List<LyricsLine> _parseLyricsLines(String rawText) {
    if (rawText.isEmpty) {
      return [];
    }

    final metadataRegex = RegExp(
      r'^\[(ti|ar|al|au|by|offset|re|ve|length):',
      caseSensitive: false,
    );
    final offsetRegex = RegExp(
      r'^\[offset:([+-]?\d+)\]$',
      caseSensitive: false,
    );
    final timestampRegex = RegExp(r'\[(\d{1,2}):(\d{2})(?:[.:](\d{1,3}))?\]');
    var offsetMs = 0;
    var lineId = 0;
    final parsedLines = <LyricsLine>[];

    for (final rawLine in rawText.split(RegExp(r'\r\n|[\n\r\u2028\u2029]'))) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        continue;
      }

      final offsetMatch = offsetRegex.firstMatch(line);
      if (offsetMatch != null) {
        offsetMs = int.parse(offsetMatch.group(1)!);
        continue;
      }
      if (metadataRegex.hasMatch(line)) {
        continue;
      }

      final matches = timestampRegex.allMatches(line).toList();
      final text = line.replaceAll(timestampRegex, '').trim();
      if (matches.isEmpty) {
        parsedLines.add(LyricsLine(id: lineId, timestampMs: null, text: line));
        lineId += 1;
        continue;
      }
      if (text.isEmpty) {
        continue;
      }

      for (final match in matches) {
        final minutes = int.parse(match.group(1)!);
        final seconds = int.parse(match.group(2)!);
        final fraction = match.group(3) ?? '0';
        final fractionMs =
            fraction.length == 1
                ? int.parse(fraction) * 100
                : fraction.length == 2
                ? int.parse(fraction) * 10
                : int.parse(fraction.padRight(3, '0').substring(0, 3));
        parsedLines.add(
          LyricsLine(
            id: lineId,
            timestampMs: math.max(
              0,
              minutes * 60000 + seconds * 1000 + fractionMs + offsetMs,
            ),
            text: text,
          ),
        );
        lineId += 1;
      }
    }
    parsedLines.sort((left, right) {
      final leftTimestamp = left.timestampMs;
      final rightTimestamp = right.timestampMs;
      if (leftTimestamp == null && rightTimestamp == null) {
        return left.id.compareTo(right.id);
      }
      if (leftTimestamp == null) {
        return -1;
      }
      if (rightTimestamp == null) {
        return 1;
      }
      final timestampCompare = leftTimestamp.compareTo(rightTimestamp);
      return timestampCompare == 0
          ? left.id.compareTo(right.id)
          : timestampCompare;
    });
    return parsedLines;
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
