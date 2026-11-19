import 'library_sql_functions.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:developer' as developer;

import 'package:path/path.dart' as p;

import 'package:sqlite3/sqlite3.dart';

import 'library_database_service.dart';
import 'library_models.dart';
import 'library_text.dart';

const _activeState = 1;
const _lyricsIndexReadBatchSize = 2;
const _lyricsIndexWriteBatchSize = 32;

typedef LocalLyricsResolver = Future<LyricsSnapshot> Function(String songPath);

class LibraryLyricsSearchService {
  const LibraryLyricsSearchService({
    required LibraryDatabaseService database,
    required LocalLyricsResolver localLyricsResolver,
  }) : _database = database,
       _localLyricsResolver = localLyricsResolver;

  final LibraryDatabaseService _database;
  final LocalLyricsResolver _localLyricsResolver;
  static final _indexBuilds = <String, Future<void>>{};
  static final _indexUpdates = <String, Future<void>>{};
  static final _indexProgress = <String, LocalLyricsIndexProgress>{};
  static final _indexProgressListeners =
      <String, Set<void Function(LocalLyricsIndexProgress)>>{};

  Future<List<LocalLyricsSearchMatch>> searchAvailable(
    File databaseFile,
    String query, {
    String folderPath = '',
  }) async =>
      (await searchPage(databaseFile, query, folderPath: folderPath)).matches;

  Future<LibraryLyricsSearchPage> searchPage(
    File databaseFile,
    String query, {
    String folderPath = '',
    int offset = 0,
    MusicLibrarySortCriterion? order,
  }) => Isolate.run(
    () => _searchPageSync(
      _database,
      databaseFile.path,
      query,
      folderPath: folderPath,
      offset: offset,
      order: order,
    ),
  );

  Future<List<int>> searchSongIds(
    File file,
    String text, {
    String folderPath = '',
    MusicLibrarySortCriterion? order,
  }) async =>
      (await Isolate.run(
        () => _searchPageSync(
          _database,
          file.path,
          text,
          folderPath: folderPath,
          offset: 0,
          order: order,
          idsOnly: true,
        ),
      )).songIds;

  static LibraryLyricsSearchPage _searchPageSync(
    LibraryDatabaseService database,
    String databasePath,
    String query, {
    required String folderPath,
    required int offset,
    required MusicLibrarySortCriterion? order,
    bool idsOnly = false,
  }) {
    final normalizedQuery = _normalizeQuery(query);
    if (normalizedQuery.runes.length < 2)
      return const LibraryLyricsSearchPage(matches: [], totalCount: 0);
    final db = database.openInitializedLibraryDatabase(File(databasePath));
    try {
      db.createFunction(
        functionName: 'lyrics_rank',
        argumentCount: const AllowedArgumentCount(1),
        deterministic: true,
        function: (values) {
          final lines =
              (jsonDecode(values.single as String) as List).cast<Map>();
          var best = 0, count = 0;
          for (final line in lines) {
            final text = line['text'] as String;
            if (_normalizeLine(text).contains(normalizedQuery)) {
              count++;
              final score = _lineRelevance(text, normalizedQuery);
              if (score > best) best = score;
            }
          }
          return best * 100 + count.clamp(0, 99);
        },
      );
      registerLibraryTimeSql(db);
      final keys = <String, ArtistTextSortKey>{};
      db.createCollation(
        name: 'library_text',
        function:
            (a, b) => (keys[a!] ??= buildArtistTextSortKey(a)).compareTo(
              keys[b!] ??= buildArtistTextSortKey(b),
            ),
      );
      final normalizedFolder = _normalizePath(folderPath);
      final prefix = normalizedFolder.isEmpty ? '' : '$normalizedFolder/';
      final useFullText = normalizedQuery.runes.length >= 3;
      final filter =
          useFullText ? 'LocalLyricsSearch MATCH ?' : 'instr(SearchText,?)>0';
      final scope =
          "FROM LocalLyricsSearch INNER JOIN Music ON Music.Id=LocalLyricsSearch.SongId WHERE $filter AND Music.State=1 AND (?='' OR instr(lower(replace(LocalLyricsSearch.Path,char(92),'/')),?)=1)";
      final parameters = [
        useFullText ? _ftsPhrase(normalizedQuery) : normalizedQuery,
        prefix,
        prefix,
      ];
      final total =
          db
                  .select('SELECT COUNT(*) AS count $scope', parameters)
                  .single['count']
              as int;
      final sort = switch (order) {
        MusicLibrarySortCriterion.title => 'Music.Name COLLATE library_text',
        MusicLibrarySortCriterion.artist => 'Music.Artist COLLATE library_text',
        MusicLibrarySortCriterion.album => 'Music.Album COLLATE library_text',
        MusicLibrarySortCriterion.duration => 'Music.Duration',
        MusicLibrarySortCriterion.playCount => 'Music.PlayCount DESC',
        MusicLibrarySortCriterion.dateAdded =>
          'library_time(CAST(Music.DateAdded AS TEXT))',
        null => 'lyrics_rank(LinesJson) DESC',
      };
      if (idsOnly) {
        final rows = db.select(
          'SELECT SongId $scope ORDER BY $sort,SongId',
          parameters,
        );
        return LibraryLyricsSearchPage(
          matches: const [],
          totalCount: total,
          songIds: rows.map((row) => row['SongId'] as int).toList(),
        );
      }
      final rows = db.select(
        'SELECT SongId AS songId,LinesJson AS linesJson $scope ORDER BY $sort,SongId LIMIT 100 OFFSET ?',
        [...parameters, offset],
      );
      return LibraryLyricsSearchPage(
        totalCount: total,
        matches: [
          for (final row in rows)
            _buildMatch(
              songId: row['songId'] as int,
              linesJson: row['linesJson'] as String,
              normalizedQuery: normalizedQuery,
            ),
        ],
      );
    } finally {
      db.dispose();
    }
  }

  Future<void> indexMissingSongs(
    File databaseFile, {
    void Function(LocalLyricsIndexProgress progress)? onProgress,
  }) async {
    try {
      await _ensureMissingSongsIndexed(databaseFile, onProgress: onProgress);
    } on Object catch (error, stackTrace) {
      developer.log(
        'Cannot index missing local lyrics',
        name: 'library.search',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> refreshAll(File databaseFile) async {
    await _waitForIndexBuild(databaseFile.path);
    await _refreshCandidates(databaseFile, await _readCandidates(databaseFile));
  }

  void refreshFolderInBackground(File databaseFile, String folderPath) {
    refreshFolder(databaseFile, folderPath, onlyChanged: true).catchError((
      Object error,
      StackTrace stackTrace,
    ) {
      developer.log(
        'Cannot refresh folder lyrics index: $folderPath',
        name: 'library.scan',
        error: error,
        stackTrace: stackTrace,
      );
    });
  }

  Future<void> refreshFolder(
    File databaseFile,
    String folderPath, {
    bool onlyChanged = false,
  }) async {
    await _waitForIndexBuild(databaseFile.path);
    final normalizedFolder = _normalizePath(folderPath);
    final folderPrefix = '$normalizedFolder/';
    await _refreshCandidates(
      databaseFile,
      await _readCandidates(
        databaseFile,
        where: "instr(lower(replace(Path, char(92), '/')), ?) = 1",
        parameters: [folderPrefix],
      ),
      onlyChanged: onlyChanged,
    );
  }

  void refreshSongIdsInBackground(File databaseFile, List<int> songIds) {
    refreshSongIds(databaseFile, songIds).catchError((
      Object error,
      StackTrace stackTrace,
    ) {
      developer.log(
        'Cannot refresh song lyrics index',
        name: 'library.search',
        error: error,
        stackTrace: stackTrace,
      );
    });
  }

  Future<void> refreshSongIds(File databaseFile, List<int> songIds) async {
    if (songIds.isEmpty) {
      return;
    }
    await _waitForIndexBuild(databaseFile.path);
    final placeholders = List.filled(songIds.length, '?').join(', ');
    await _refreshCandidates(
      databaseFile,
      await _readCandidates(
        databaseFile,
        where: 'Id IN ($placeholders)',
        parameters: songIds,
      ),
    );
  }

  Future<void> refreshPaths(File databaseFile, List<String> songPaths) async {
    if (songPaths.isEmpty) {
      return;
    }
    await _waitForIndexBuild(databaseFile.path);
    final placeholders = List.filled(songPaths.length, '?').join(', ');
    await _refreshCandidates(
      databaseFile,
      await _readCandidates(
        databaseFile,
        where: 'Path IN ($placeholders)',
        parameters: songPaths,
      ),
    );
  }

  Future<void> _indexMissingSongs(
    File databaseFile, {
    void Function(LocalLyricsIndexProgress progress)? onProgress,
  }) async {
    final candidates = await _readCandidates(
      databaseFile,
      where: '''
        Id NOT IN (SELECT SongId FROM LocalLyricsSearch)
      ''',
    );
    await _refreshCandidates(databaseFile, candidates, onProgress: onProgress);
  }

  Future<void> _ensureMissingSongsIndexed(
    File databaseFile, {
    void Function(LocalLyricsIndexProgress progress)? onProgress,
  }) async {
    final databasePath = databaseFile.path;
    final listeners = _indexProgressListeners.putIfAbsent(
      databasePath,
      () => {},
    );
    if (onProgress != null) {
      listeners.add(onProgress);
      final currentProgress = _indexProgress[databasePath];
      if (currentProgress != null) {
        onProgress(currentProgress);
      }
    }

    final build = _indexBuilds[databasePath];
    if (build != null) {
      try {
        await build;
      } finally {
        if (onProgress != null) {
          listeners.remove(onProgress);
        }
        if (listeners.isEmpty) {
          _indexProgressListeners.remove(databasePath);
        }
      }
      return;
    }

    final nextBuild = _indexMissingSongs(
      databaseFile,
      onProgress: (progress) {
        _indexProgress[databasePath] = progress;
        for (final listener in _indexProgressListeners[databasePath]!) {
          listener(progress);
        }
      },
    );
    _indexBuilds[databasePath] = nextBuild;
    try {
      await nextBuild;
    } finally {
      _indexBuilds.remove(databasePath);
      _indexProgress.remove(databasePath);
      if (onProgress != null) {
        listeners.remove(onProgress);
      }
      if (listeners.isEmpty) {
        _indexProgressListeners.remove(databasePath);
      }
    }
  }

  Future<void> _waitForIndexBuild(String databasePath) async {
    final build = _indexBuilds[databasePath];
    if (build != null) {
      await build;
    }
  }

  Future<List<_LyricsIndexCandidate>> _readCandidates(
    File databaseFile, {
    String? where,
    List<Object?> parameters = const [],
  }) {
    return _readCandidatesInBackground(
      _database,
      databaseFile.path,
      where,
      parameters,
    );
  }

  static Future<List<_LyricsIndexCandidate>> _readCandidatesInBackground(
    LibraryDatabaseService database,
    String databasePath,
    String? where,
    List<Object?> parameters,
  ) {
    return Isolate.run(
      () => _readCandidatesSync(database, databasePath, where, parameters),
    );
  }

  static List<_LyricsIndexCandidate> _readCandidatesSync(
    LibraryDatabaseService database,
    String databasePath,
    String? where,
    List<Object?> parameters,
  ) {
    final db = database.openInitializedLibraryDatabase(File(databasePath));
    try {
      _removeInactiveSongs(db);
      final rows = db.select(
        '''
        SELECT Id AS songId, Path AS path
        FROM Music
        WHERE State = ? AND Path NOT LIKE 'smplayer-music://%'
          ${where == null ? '' : 'AND ($where)'}
        ORDER BY Id
      ''',
        [_activeState, ...parameters],
      );
      final signatures = {
        for (final row in db.select(
          'SELECT SongId, FileSignature FROM LocalLyricsSearch',
        ))
          row['SongId'] as int: row['FileSignature'] as String,
      };
      return [
        for (final row in rows)
          _LyricsIndexCandidate(
            songId: row['songId'] as int,
            path: row['path'] as String,
            signature: signatures[row['songId']],
          ),
      ];
    } finally {
      db.dispose();
    }
  }

  Future<void> _refreshCandidates(
    File databaseFile,
    List<_LyricsIndexCandidate> candidates, {
    bool onlyChanged = false,
    void Function(LocalLyricsIndexProgress progress)? onProgress,
  }) {
    final databasePath = databaseFile.path;
    final previous = _indexUpdates[databasePath] ?? Future<void>.value();
    final update = previous.then(
      (_) => _refreshCandidatesNow(
        databaseFile,
        candidates,
        onlyChanged: onlyChanged,
        onProgress: onProgress,
      ),
    );
    final settled = update.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );
    _indexUpdates[databasePath] = settled;
    settled.then((_) {
      if (identical(_indexUpdates[databasePath], settled)) {
        _indexUpdates.remove(databasePath);
      }
    });
    return update;
  }

  Future<void> _refreshCandidatesNow(
    File databaseFile,
    List<_LyricsIndexCandidate> candidates, {
    bool onlyChanged = false,
    void Function(LocalLyricsIndexProgress progress)? onProgress,
  }) async {
    if (candidates.isEmpty) {
      return;
    }
    var current = 0;
    onProgress?.call(
      LocalLyricsIndexProgress(current: current, total: candidates.length),
    );
    for (
      var start = 0;
      start < candidates.length;
      start += _lyricsIndexWriteBatchSize
    ) {
      final end = (start + _lyricsIndexWriteBatchSize).clamp(
        0,
        candidates.length,
      );
      final entries = <_LyricsIndexEntry>[];
      for (
        var offset = start;
        offset < end;
        offset += _lyricsIndexReadBatchSize
      ) {
        final readEnd = (offset + _lyricsIndexReadBatchSize).clamp(0, end);
        entries.addAll(
          (await Future.wait([
            for (var index = offset; index < readEnd; index++)
              _readEntry(candidates[index], onlyChanged: onlyChanged),
          ])).whereType<_LyricsIndexEntry>(),
        );
      }
      if (entries.isNotEmpty) {
        await _writeIndexBatch(databaseFile.path, entries);
      }
      current = end;
      onProgress?.call(
        LocalLyricsIndexProgress(current: current, total: candidates.length),
      );
    }
  }

  static Future<void> _writeIndexBatch(
    String databasePath,
    List<_LyricsIndexEntry> entries,
  ) {
    return Isolate.run(() {
      final rows = _encodeIndexBatch(entries);
      _writeIndexBatchSync(databasePath, rows);
    });
  }

  static List<List<Object?>> _encodeIndexBatch(
    List<_LyricsIndexEntry> entries,
  ) {
    return [
      for (final entry in entries)
        [
          entry.songId,
          entry.path,
          entry.snapshot.source.index,
          entry.snapshot.rawText,
          jsonEncode([
            for (final line in entry.snapshot.lines)
              {'timestampMs': line.timestampMs, 'text': line.text},
          ]),
          _searchableText(entry.snapshot),
          entry.signature,
        ],
    ];
  }

  static void _writeIndexBatchSync(
    String databasePath,
    List<List<Object?>> rows,
  ) {
    final db = LibraryDatabaseService.openDatabase(databasePath);
    try {
      db.execute('BEGIN');
      try {
        final placeholders = List.filled(rows.length, '?').join(', ');
        db.execute(
          'DELETE FROM LocalLyricsSearch WHERE SongId IN ($placeholders)',
          [for (final row in rows) row[0]],
        );
        final insertStatement = db.prepare('''
          INSERT INTO LocalLyricsSearch
            (SongId, Path, Source, RawText, LinesJson, SearchText, FileSignature)
          VALUES (?, ?, ?, ?, ?, ?, ?)
        ''');
        try {
          for (final row in rows) {
            insertStatement.execute(row);
          }
        } finally {
          insertStatement.dispose();
        }
        db.execute('COMMIT');
      } on Object {
        db.execute('ROLLBACK');
        rethrow;
      }
    } finally {
      db.dispose();
    }
  }

  Future<_LyricsIndexEntry?> _readEntry(
    _LyricsIndexCandidate candidate, {
    required bool onlyChanged,
  }) async {
    try {
      final signature = await _fileSignature(candidate.path);
      if (onlyChanged && candidate.signature == signature) return null;
      final snapshot = await _localLyricsResolver(candidate.path);
      // A file changed during the read: leave the previous index for a retry.
      if (signature != await _fileSignature(candidate.path)) return null;
      return _LyricsIndexEntry(
        songId: candidate.songId,
        path: candidate.path,
        snapshot: snapshot,
        signature: signature,
      );
    } on Object catch (error, stackTrace) {
      developer.log(
        'Cannot index lyrics: ${candidate.path}',
        name: 'library.scan',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  static Future<String> _fileSignature(String path) async {
    final stats = await Future.wait([
      File(path).stat(),
      File(p.setExtension(path, '.lrc')).stat(),
      File(p.setExtension(path, '.txt')).stat(),
    ]);
    if (stats.first.type != FileSystemEntityType.file) {
      throw FileSystemException('Audio file is unavailable', path);
    }
    return jsonEncode([
      path,
      for (final stat in stats)
        [stat.type.toString(), stat.size, stat.modified.microsecondsSinceEpoch],
    ]);
  }

  static void _removeInactiveSongs(Database db) {
    db.execute(
      '''
      DELETE FROM LocalLyricsSearch
      WHERE SongId NOT IN (
        SELECT Id
        FROM Music
        WHERE State = ?
      )
    ''',
      [_activeState],
    );
  }

  static LocalLyricsSearchMatch _buildMatch({
    required int songId,
    required String linesJson,
    required String normalizedQuery,
  }) {
    final lines =
        (jsonDecode(linesJson) as List<Object?>)
            .cast<Map<String, Object?>>()
            .indexed
            .map(
              (entry) => LyricsLine(
                id: entry.$1,
                timestampMs: entry.$2['timestampMs'] as int?,
                text: entry.$2['text'] as String,
              ),
            )
            .toList();
    final matchedLines = [
      for (final line in lines)
        if (_normalizeLine(line.text).contains(normalizedQuery)) line,
    ];
    final bestLine = matchedLines.reduce((left, right) {
      final leftScore = _lineRelevance(left.text, normalizedQuery);
      final rightScore = _lineRelevance(right.text, normalizedQuery);
      return rightScore > leftScore ? right : left;
    });
    final nonEmptyLines = [
      for (final line in lines)
        if (line.text.trim().isNotEmpty) line,
    ];
    final bestLineIndex = nonEmptyLines.indexWhere(
      (line) => line.id == bestLine.id,
    );
    final latestStart = (nonEmptyLines.length - 3).clamp(
      0,
      nonEmptyLines.length,
    );
    final contextStart = (bestLineIndex - 1).clamp(0, latestStart);
    final contextEnd = (contextStart + 3).clamp(0, nonEmptyLines.length);
    final ranges = <({int start, int end})>[];
    final matchedIds = matchedLines.map((line) => line.id).toSet();
    for (var index = 0; index < nonEmptyLines.length; index++) {
      if (!matchedIds.contains(nonEmptyLines[index].id)) continue;
      final start = (index - 1).clamp(0, latestStart);
      final end = (start + 3).clamp(0, nonEmptyLines.length);
      if (ranges.isNotEmpty && start <= ranges.last.end) {
        ranges[ranges.length - 1] = (start: ranges.last.start, end: end);
      } else {
        ranges.add((start: start, end: end));
      }
    }
    return LocalLyricsSearchMatch(
      songId: songId,
      snippet: bestLine.text,
      contextLines: [
        for (final line in nonEmptyLines.sublist(contextStart, contextEnd))
          line.text,
      ],
      timestampMs: bestLine.timestampMs,
      matchContexts: [
        for (final range in ranges)
          [
            for (final line in nonEmptyLines.sublist(range.start, range.end))
              line.text,
          ],
      ],
      additionalMatchCount: matchedLines.length - 1,
      relevance:
          _lineRelevance(bestLine.text, normalizedQuery) * 100 +
          matchedLines.length.clamp(0, 99),
    );
  }

  static String _searchableText(LyricsSnapshot snapshot) {
    return snapshot.lines.map((line) => _normalizeLine(line.text)).join('\n');
  }

  static int _lineRelevance(String text, String normalizedQuery) {
    final normalizedLine = _normalizeLine(text);
    if (normalizedLine == normalizedQuery) {
      return 4;
    }
    if (normalizedLine.startsWith(normalizedQuery)) {
      return 3;
    }
    return 2;
  }

  static String _normalizeQuery(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  static String _normalizeLine(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'[ \t]+'), ' ');
  }

  static String _normalizePath(String value) {
    return value.replaceAll('\\', '/').toLowerCase();
  }

  static String _ftsPhrase(String normalizedQuery) {
    return '"${normalizedQuery.replaceAll('"', '""')}"';
  }
}

class _LyricsIndexCandidate {
  const _LyricsIndexCandidate({
    required this.songId,
    required this.path,
    this.signature,
  });

  final int songId;
  final String path;
  final String? signature;
}

class _LyricsIndexEntry {
  const _LyricsIndexEntry({
    required this.songId,
    required this.path,
    required this.snapshot,
    required this.signature,
  });

  final int songId;
  final String path;
  final LyricsSnapshot snapshot;
  final String signature;
}
