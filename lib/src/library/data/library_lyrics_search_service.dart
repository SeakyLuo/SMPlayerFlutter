import 'dart:convert';
import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

import 'library_database_service.dart';
import 'library_models.dart';

const _activeState = 1;
const _lyricsIndexReadBatchSize = 2;

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
  static final _indexProgress = <String, LocalLyricsIndexProgress>{};
  static final _indexProgressListeners =
      <String, Set<void Function(LocalLyricsIndexProgress)>>{};

  List<LocalLyricsSearchMatch> searchAvailable(
    File databaseFile,
    String query, {
    String folderPath = '',
  }) {
    _ensureSchema(databaseFile);
    final normalizedQuery = _normalizeQuery(query);
    if (normalizedQuery.runes.length < 2) {
      return const [];
    }

    final db = sqlite3.open(databaseFile.path);
    try {
      _removeInactiveSongs(db);
      final normalizedFolder = _normalizePath(folderPath);
      final folderPrefix = normalizedFolder.isEmpty ? '' : '$normalizedFolder/';
      final useFullText = normalizedQuery.runes.length >= 3;
      final rows = db.select(
        useFullText
            ? '''
              SELECT SongId AS songId, LinesJson AS linesJson
              FROM LocalLyricsSearch
              WHERE LocalLyricsSearch MATCH ?
                AND (? = '' OR instr(lower(replace(Path, char(92), '/')), ?) = 1)
            '''
            : '''
              SELECT SongId AS songId, LinesJson AS linesJson
              FROM LocalLyricsSearch
              WHERE instr(SearchText, ?) > 0
                AND (? = '' OR instr(lower(replace(Path, char(92), '/')), ?) = 1)
            ''',
        [
          if (useFullText) _ftsPhrase(normalizedQuery) else normalizedQuery,
          folderPrefix,
          folderPrefix,
        ],
      );
      final matches = [
        for (final row in rows)
          _buildMatch(
            songId: row['songId'] as int,
            linesJson: row['linesJson'] as String,
            normalizedQuery: normalizedQuery,
          ),
      ];
      matches.sort((left, right) {
        final relevance = right.relevance.compareTo(left.relevance);
        return relevance != 0 ? relevance : left.songId.compareTo(right.songId);
      });
      return matches;
    } finally {
      db.dispose();
    }
  }

  Future<void> indexMissingSongs(
    File databaseFile, {
    void Function(LocalLyricsIndexProgress progress)? onProgress,
  }) async {
    _ensureSchema(databaseFile);
    await _ensureMissingSongsIndexed(databaseFile, onProgress: onProgress);
  }

  Future<void> refreshAll(File databaseFile) async {
    _ensureSchema(databaseFile);
    await _waitForIndexBuild(databaseFile.path);
    await _refreshCandidates(databaseFile, _readCandidates(databaseFile));
  }

  Future<void> refreshFolder(File databaseFile, String folderPath) async {
    _ensureSchema(databaseFile);
    await _waitForIndexBuild(databaseFile.path);
    final normalizedFolder = _normalizePath(folderPath);
    final folderPrefix = '$normalizedFolder/';
    await _refreshCandidates(
      databaseFile,
      _readCandidates(
        databaseFile,
        where: "instr(lower(replace(Path, char(92), '/')), ?) = 1",
        parameters: [folderPrefix],
      ),
    );
  }

  Future<void> refreshSongIds(File databaseFile, List<int> songIds) async {
    if (songIds.isEmpty) {
      return;
    }
    _ensureSchema(databaseFile);
    await _waitForIndexBuild(databaseFile.path);
    final placeholders = List.filled(songIds.length, '?').join(', ');
    await _refreshCandidates(
      databaseFile,
      _readCandidates(
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
    _ensureSchema(databaseFile);
    await _waitForIndexBuild(databaseFile.path);
    final placeholders = List.filled(songPaths.length, '?').join(', ');
    await _refreshCandidates(
      databaseFile,
      _readCandidates(
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
    final candidates = _readCandidates(
      databaseFile,
      where: '''
        NOT EXISTS (
          SELECT 1
          FROM LocalLyricsSearch
          WHERE LocalLyricsSearch.SongId = Music.Id
        )
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

  List<_LyricsIndexCandidate> _readCandidates(
    File databaseFile, {
    String? where,
    List<Object?> parameters = const [],
  }) {
    final db = sqlite3.open(databaseFile.path);
    try {
      final rows = db.select(
        '''
        SELECT Id AS songId, Path AS path
        FROM Music
        WHERE State = ?
          ${where == null ? '' : 'AND ($where)'}
        ORDER BY Id
      ''',
        [_activeState, ...parameters],
      );
      return [
        for (final row in rows)
          _LyricsIndexCandidate(
            songId: row['songId'] as int,
            path: row['path'] as String,
          ),
      ];
    } finally {
      db.dispose();
    }
  }

  Future<void> _refreshCandidates(
    File databaseFile,
    List<_LyricsIndexCandidate> candidates, {
    void Function(LocalLyricsIndexProgress progress)? onProgress,
  }) async {
    if (candidates.isEmpty) {
      return;
    }
    final entries = <_LyricsIndexEntry>[];
    var current = 0;
    onProgress?.call(
      LocalLyricsIndexProgress(current: current, total: candidates.length),
    );
    for (
      var start = 0;
      start < candidates.length;
      start += _lyricsIndexReadBatchSize
    ) {
      final end = (start + _lyricsIndexReadBatchSize).clamp(
        0,
        candidates.length,
      );
      final batch = candidates.sublist(start, end);
      entries.addAll(
        await Future.wait([
          for (final candidate in batch) _readEntry(candidate),
        ]),
      );
      current += batch.length;
      onProgress?.call(
        LocalLyricsIndexProgress(current: current, total: candidates.length),
      );
    }

    final db = sqlite3.open(databaseFile.path);
    try {
      db.execute('BEGIN');
      try {
        final deleteStatement = db.prepare(
          'DELETE FROM LocalLyricsSearch WHERE SongId = ?',
        );
        final insertStatement = db.prepare('''
          INSERT INTO LocalLyricsSearch
            (SongId, Path, Source, RawText, LinesJson, SearchText)
          VALUES (?, ?, ?, ?, ?, ?)
        ''');
        try {
          for (final entry in entries) {
            deleteStatement.execute([entry.songId]);
            insertStatement.execute([
              entry.songId,
              entry.path,
              entry.snapshot.source.index,
              entry.snapshot.rawText,
              jsonEncode([
                for (final line in entry.snapshot.lines)
                  {'timestampMs': line.timestampMs, 'text': line.text},
              ]),
              _searchableText(entry.snapshot),
            ]);
          }
        } finally {
          insertStatement.dispose();
          deleteStatement.dispose();
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

  Future<_LyricsIndexEntry> _readEntry(_LyricsIndexCandidate candidate) async {
    return _LyricsIndexEntry(
      songId: candidate.songId,
      path: candidate.path,
      snapshot: await _localLyricsResolver(candidate.path),
    );
  }

  void _removeInactiveSongs(Database db) {
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

  void _ensureSchema(File databaseFile) {
    final db = _database.openInitializedLibraryDatabase(databaseFile);
    db.dispose();
  }

  LocalLyricsSearchMatch _buildMatch({
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
    return LocalLyricsSearchMatch(
      songId: songId,
      snippet: bestLine.text,
      contextLines: [
        for (final line in nonEmptyLines.sublist(contextStart, contextEnd))
          line.text,
      ],
      timestampMs: bestLine.timestampMs,
      additionalMatchCount: matchedLines.length - 1,
      relevance:
          _lineRelevance(bestLine.text, normalizedQuery) * 100 +
          matchedLines.length.clamp(0, 99),
    );
  }

  String _searchableText(LyricsSnapshot snapshot) {
    return snapshot.lines.map((line) => _normalizeLine(line.text)).join('\n');
  }

  int _lineRelevance(String text, String normalizedQuery) {
    final normalizedLine = _normalizeLine(text);
    if (normalizedLine == normalizedQuery) {
      return 4;
    }
    if (normalizedLine.startsWith(normalizedQuery)) {
      return 3;
    }
    return 2;
  }

  String _normalizeQuery(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  String _normalizeLine(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'[ \t]+'), ' ');
  }

  String _normalizePath(String value) {
    return value.replaceAll('\\', '/').toLowerCase();
  }

  String _ftsPhrase(String normalizedQuery) {
    return '"${normalizedQuery.replaceAll('"', '""')}"';
  }
}

class _LyricsIndexCandidate {
  const _LyricsIndexCandidate({required this.songId, required this.path});

  final int songId;
  final String path;
}

class _LyricsIndexEntry {
  const _LyricsIndexEntry({
    required this.songId,
    required this.path,
    required this.snapshot,
  });

  final int songId;
  final String path;
  final LyricsSnapshot snapshot;
}
