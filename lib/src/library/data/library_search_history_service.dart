import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

import 'library_database_service.dart';
import 'library_models.dart';
import 'library_time_codec.dart';

class LibrarySearchHistoryService {
  const LibrarySearchHistoryService({required LibraryDatabaseService database})
    : _database = database;

  final LibraryDatabaseService _database;

  Future<List<SearchHistoryEntry>> getRecentSearches(File databaseFile) async {
    if (!databaseFile.existsSync()) {
      return const [];
    }

    final db = _database.openInitializedLibraryDatabase(databaseFile);
    try {
      return readRecentSearches(db);
    } finally {
      db.dispose();
    }
  }

  Future<void> removeRecentSearches(
    File databaseFile,
    List<int> entryIds,
  ) async {
    if (entryIds.isEmpty) {
      return;
    }
    if (!databaseFile.existsSync()) {
      return;
    }

    final placeholders = List.filled(entryIds.length, '?').join(', ');
    final db = sqlite3.open(databaseFile.path);
    try {
      db.execute('DELETE FROM SearchHistory WHERE Id IN ($placeholders)', [
        ...entryIds,
      ]);
    } finally {
      db.dispose();
    }
  }

  Future<void> restoreRecentSearches(
    File databaseFile,
    List<SearchHistoryEntry> entries,
  ) async {
    if (entries.isEmpty) {
      return;
    }
    if (!databaseFile.existsSync()) {
      return;
    }

    final db = sqlite3.open(databaseFile.path);
    try {
      db.execute('BEGIN');
      try {
        final deleteStatement = db.prepare('''
          DELETE FROM SearchHistory
          WHERE Query = ? COLLATE NOCASE
            AND Type = ?
        ''');
        final insertStatement = db.prepare('''
          INSERT INTO SearchHistory (Id, Query, Type, SearchedAt)
          VALUES (?, ?, ?, ?)
        ''');
        try {
          for (final entry in entries) {
            final storedType = _toStoredSearchHistoryType(entry.type);
            deleteStatement.execute([entry.query, storedType]);
            insertStatement.execute([
              entry.id,
              entry.query,
              storedType,
              entry.searchedAt,
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

  Future<void> clearRecentSearches(File databaseFile) async {
    if (!databaseFile.existsSync()) {
      return;
    }

    final db = sqlite3.open(databaseFile.path);
    try {
      db.execute('DELETE FROM SearchHistory');
    } finally {
      db.dispose();
    }
  }

  Future<SearchHistoryEntry?> addRecentSearch(
    File databaseFile,
    String query, [
    SearchHistoryType type = SearchHistoryType.sidebar,
  ]) async {
    final nextQuery = query.trim();
    if (nextQuery.isEmpty) {
      return null;
    }
    if (!databaseFile.existsSync()) {
      return null;
    }

    final db = _database.openInitializedLibraryDatabase(databaseFile);
    try {
      final searchedAt = LibraryTimeCodec.nowUnixMillisecondsString();
      db.execute('BEGIN');
      try {
        db.execute(
          '''
          DELETE FROM SearchHistory
          WHERE Query = ? COLLATE NOCASE
            AND Type = ?
        ''',
          [nextQuery, _toStoredSearchHistoryType(type)],
        );
        db.execute(
          '''
          INSERT INTO SearchHistory (Query, Type, SearchedAt)
          VALUES (?, ?, ?)
        ''',
          [nextQuery, _toStoredSearchHistoryType(type), searchedAt],
        );
        final rows = db.select('SELECT last_insert_rowid() AS id');
        final id = rows.single['id'] as int;
        db.execute('COMMIT');
        return SearchHistoryEntry(
          id: id,
          query: nextQuery,
          type: type,
          searchedAt: searchedAt,
        );
      } on Object {
        db.execute('ROLLBACK');
        rethrow;
      }
    } finally {
      db.dispose();
    }
  }

  List<SearchHistoryEntry> readRecentSearches(Database db) {
    final rows = db.select('''
      SELECT
        Id AS id,
        Query AS query,
        Type AS type,
        SearchedAt AS searchedAt
      FROM SearchHistory
      ORDER BY Id DESC
    ''');
    final entries = rows.map((row) {
      return SearchHistoryEntry(
        id: row['id'] as int,
        query: row['query'] as String,
        type: _fromStoredSearchHistoryType(row['type'] as String),
        searchedAt: row['searchedAt'] as String,
      );
    }).toList();
    entries.sort((left, right) {
      final timeCompare = LibraryTimeCodec.toSortMilliseconds(
        right.searchedAt,
      ).compareTo(LibraryTimeCodec.toSortMilliseconds(left.searchedAt));
      return timeCompare != 0 ? timeCompare : right.id.compareTo(left.id);
    });
    return entries;
  }
}

SearchHistoryType _fromStoredSearchHistoryType(String value) {
  switch (value) {
    case 'artists':
      return SearchHistoryType.artists;
    case 'albums':
      return SearchHistoryType.albums;
    case 'songs':
      return SearchHistoryType.songs;
    case 'playlists':
      return SearchHistoryType.playlists;
    case 'folders':
      return SearchHistoryType.folders;
    default:
      return SearchHistoryType.sidebar;
  }
}

String _toStoredSearchHistoryType(SearchHistoryType value) {
  switch (value) {
    case SearchHistoryType.artists:
      return 'artists';
    case SearchHistoryType.albums:
      return 'albums';
    case SearchHistoryType.songs:
      return 'songs';
    case SearchHistoryType.playlists:
      return 'playlists';
    case SearchHistoryType.folders:
      return 'folders';
    case SearchHistoryType.sidebar:
      return 'sidebar';
  }
}
