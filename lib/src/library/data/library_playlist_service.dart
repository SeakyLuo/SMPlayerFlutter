import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

import 'library_models.dart';

const _activeState = 1;
const _inactiveState = 0;
const _nowPlayingPlaylistName = 'Now Playing';

class LibraryPlaylistService {
  const LibraryPlaylistService();

  List<LibraryPlaylist> readPlaylists(
    Database db, {
    required int myFavoritesId,
    required int nowPlayingId,
  }) {
    final playlistRows = db.select(
      '''
      SELECT
        Playlist.Id AS id,
        Playlist.Name AS name,
        Playlist.Criterion AS criterion,
        Playlist.Priority AS priority,
        COUNT(Music.Id) AS songCount
      FROM Playlist
      LEFT JOIN PlaylistItem
        ON PlaylistItem.PlaylistId = Playlist.Id
       AND PlaylistItem.State = ?
      LEFT JOIN Music
        ON Music.Id = PlaylistItem.ItemId
       AND Music.State = ?
      WHERE Playlist.State = ?
      GROUP BY Playlist.Id, Playlist.Name, Playlist.Criterion, Playlist.Priority
      ORDER BY
        CASE
          WHEN Playlist.Id = ? THEN 0
          WHEN Playlist.Id = ? THEN 1
          ELSE 2
        END,
        CASE WHEN Playlist.Priority < 0 THEN 2147483647 ELSE Playlist.Priority END,
        LOWER(Playlist.Name),
        Playlist.Id
    ''',
      [_activeState, _activeState, _activeState, myFavoritesId, nowPlayingId],
    );
    final itemRows = db.select(
      '''
      SELECT
        PlaylistItem.PlaylistId AS playlistId,
        PlaylistItem.ItemId AS songId
      FROM PlaylistItem
      INNER JOIN Playlist
        ON Playlist.Id = PlaylistItem.PlaylistId
      INNER JOIN Music
        ON Music.Id = PlaylistItem.ItemId
      WHERE PlaylistItem.State = ?
        AND Playlist.State = ?
        AND Music.State = ?
      ORDER BY PlaylistItem.Id
    ''',
      [_activeState, _activeState, _activeState],
    );
    final playlistSongIds = <int, List<int>>{};
    for (final row in itemRows) {
      final playlistId = row['playlistId'] as int;
      final songIds = playlistSongIds[playlistId] ?? <int>[];
      songIds.add(row['songId'] as int);
      playlistSongIds[playlistId] = songIds;
    }

    return playlistRows.map((row) {
      final id = row['id'] as int;
      return LibraryPlaylist(
        id: id,
        name: row['name'] as String,
        priority: row['priority'] as int,
        songCount: row['songCount'] as int,
        songIds: playlistSongIds[id] ?? const [],
        sortCriterion: _fromStoredPlaylistSortCriterion(
          row['criterion'] as int,
        ),
        isBuiltIn: id == myFavoritesId,
      );
    }).toList();
  }

  Future<LibraryPlaylist> createPlaylist(
    File databaseFile,
    String name,
    List<int> songIds,
  ) async {
    final db = sqlite3.open(databaseFile.path);
    try {
      final settings = _readPlaylistSettings(db);
      final nextName = _validatePlaylistName(db, name);
      db.execute('BEGIN');
      try {
        db.execute(
          '''
          UPDATE Playlist
          SET Priority = Priority + 1
          WHERE State = ?
            AND Id NOT IN (?, ?)
            AND Name <> ?
        ''',
          [
            _activeState,
            settings.myFavoritesId,
            settings.nowPlayingId,
            _nowPlayingPlaylistName,
          ],
        );
        db.execute(
          '''
          INSERT INTO Playlist (Name, Criterion, Priority, State)
          VALUES (?, -1, ?, ?)
        ''',
          [nextName, 0, _activeState],
        );
        final playlistId = db.lastInsertRowId;
        _setPlaylistSongsState(db, playlistId, songIds, true);
        db.execute('COMMIT');
        final playlistSongIds = _uniqueSongIds(songIds);
        return LibraryPlaylist(
          id: playlistId,
          name: nextName,
          priority: 0,
          songCount: playlistSongIds.length,
          songIds: playlistSongIds,
          sortCriterion: PlaylistSortCriterion.title,
          isBuiltIn: false,
        );
      } on Object {
        db.execute('ROLLBACK');
        rethrow;
      }
    } finally {
      db.dispose();
    }
  }

  Future<void> deletePlaylist(File databaseFile, int playlistId) async {
    if (!databaseFile.existsSync()) {
      return;
    }

    final db = sqlite3.open(databaseFile.path);
    try {
      final settings = _readPlaylistSettings(db);
      if (playlistId == settings.myFavoritesId ||
          playlistId == settings.nowPlayingId) {
        throw StateError('Built-in playlists cannot be deleted.');
      }

      db.execute('BEGIN');
      try {
        db.execute('UPDATE Playlist SET State = ? WHERE Id = ?', [
          _inactiveState,
          playlistId,
        ]);
        db.execute('UPDATE PlaylistItem SET State = ? WHERE PlaylistId = ?', [
          _inactiveState,
          playlistId,
        ]);
        db.execute('COMMIT');
      } on Object {
        db.execute('ROLLBACK');
        rethrow;
      }
    } finally {
      db.dispose();
    }
  }

  Future<void> restorePlaylist(
    File databaseFile,
    LibraryPlaylist playlist,
  ) async {
    if (!databaseFile.existsSync()) {
      return;
    }

    final db = sqlite3.open(databaseFile.path);
    try {
      final settings = _readPlaylistSettings(db);
      if (playlist.id == settings.myFavoritesId ||
          playlist.id == settings.nowPlayingId) {
        throw StateError('Built-in playlists cannot be restored.');
      }

      db.execute('BEGIN');
      try {
        db.execute(
          '''
          UPDATE Playlist
          SET Priority = Priority + 1
          WHERE State = ?
            AND Id NOT IN (?, ?, ?)
            AND Name <> ?
            AND Priority >= ?
        ''',
          [
            _activeState,
            settings.myFavoritesId,
            settings.nowPlayingId,
            playlist.id,
            _nowPlayingPlaylistName,
            playlist.priority,
          ],
        );
        db.execute(
          '''
          UPDATE Playlist
          SET Name = ?,
              Criterion = ?,
              Priority = ?,
              State = ?
          WHERE Id = ?
        ''',
          [
            _validatePlaylistName(
              db,
              playlist.name,
              currentPlaylistId: playlist.id,
            ),
            _toStoredPlaylistSortCriterion(playlist.sortCriterion),
            playlist.priority,
            _activeState,
            playlist.id,
          ],
        );
        db.execute('UPDATE PlaylistItem SET State = ? WHERE PlaylistId = ?', [
          _inactiveState,
          playlist.id,
        ]);
        _setPlaylistSongsState(db, playlist.id, playlist.songIds, true);
        db.execute('COMMIT');
      } on Object {
        db.execute('ROLLBACK');
        rethrow;
      }
    } finally {
      db.dispose();
    }
  }

  Future<void> renamePlaylist(
    File databaseFile,
    int playlistId,
    String name,
  ) async {
    if (!databaseFile.existsSync()) {
      return;
    }

    final db = sqlite3.open(databaseFile.path);
    try {
      final settings = _readPlaylistSettings(db);
      if (playlistId == settings.myFavoritesId ||
          playlistId == settings.nowPlayingId) {
        throw StateError('Built-in playlists cannot be renamed.');
      }

      final nextName = _validatePlaylistName(
        db,
        name,
        currentPlaylistId: playlistId,
      );
      db.execute('UPDATE Playlist SET Name = ? WHERE Id = ?', [
        nextName,
        playlistId,
      ]);
    } finally {
      db.dispose();
    }
  }

  Future<void> reorderPlaylists(
    File databaseFile,
    List<int> playlistIds,
  ) async {
    if (!databaseFile.existsSync()) {
      return;
    }

    final db = sqlite3.open(databaseFile.path);
    try {
      final settings = _readPlaylistSettings(db);
      final rows = db.select(
        '''
        SELECT Playlist.Id AS id
        FROM Playlist
        WHERE Playlist.State = ?
          AND Playlist.Id NOT IN (?, ?)
          AND Playlist.Name <> ?
        ORDER BY
          CASE WHEN Playlist.Priority < 0 THEN 2147483647 ELSE Playlist.Priority END,
          LOWER(Playlist.Name),
          Playlist.Id
      ''',
        [
          _activeState,
          settings.myFavoritesId,
          settings.nowPlayingId,
          _nowPlayingPlaylistName,
        ],
      );
      final currentPlaylistIds = rows.map((row) => row['id'] as int).toList();
      if (currentPlaylistIds.length <= 1) {
        return;
      }

      if (currentPlaylistIds.length != playlistIds.length ||
          currentPlaylistIds.any(
            (playlistId) => !playlistIds.contains(playlistId),
          )) {
        throw StateError(
          'Playlist reorder request is out of sync with the current playlist list.',
        );
      }

      final firstChangedIndex =
          playlistIds.indexed
              .where((entry) => entry.$2 != currentPlaylistIds[entry.$1])
              .map((entry) => entry.$1)
              .firstOrNull;
      if (firstChangedIndex == null) {
        return;
      }

      final reversedChangedIndex =
          playlistIds.reversed.indexed
              .where(
                (entry) =>
                    entry.$2 !=
                    currentPlaylistIds[currentPlaylistIds.length -
                        1 -
                        entry.$1],
              )
              .map((entry) => entry.$1)
              .first;
      final lastChangedIndex = playlistIds.length - 1 - reversedChangedIndex;
      final changedPlaylistIds = playlistIds.sublist(
        firstChangedIndex,
        lastChangedIndex + 1,
      );
      final priorityCases = List.filled(
        changedPlaylistIds.length,
        'WHEN ? THEN ?',
      ).join(' ');
      final playlistIdPlaceholders = List.filled(
        changedPlaylistIds.length,
        '?',
      ).join(', ');
      final priorityCaseValues =
          changedPlaylistIds.indexed
              .expand((entry) => [entry.$2, firstChangedIndex + entry.$1])
              .toList();

      db.execute(
        '''
        UPDATE Playlist
        SET Priority = CASE Id $priorityCases END
        WHERE Id IN ($playlistIdPlaceholders)
      ''',
        [...priorityCaseValues, ...changedPlaylistIds],
      );
    } finally {
      db.dispose();
    }
  }

  Future<void> setSongsFavorite(
    File databaseFile,
    List<int> songIds,
    bool favorite,
  ) async {
    if (!databaseFile.existsSync()) {
      return;
    }

    final db = sqlite3.open(databaseFile.path);
    try {
      final settings = _readPlaylistSettings(db);
      db.execute('BEGIN');
      try {
        _setPlaylistSongsState(db, settings.myFavoritesId, songIds, favorite);
        db.execute('COMMIT');
      } on Object {
        db.execute('ROLLBACK');
        rethrow;
      }
    } finally {
      db.dispose();
    }
  }

  Future<void> addSongsToPlaylist(
    File databaseFile,
    int playlistId,
    List<int> songIds,
  ) async {
    if (!databaseFile.existsSync()) {
      return;
    }

    final db = sqlite3.open(databaseFile.path);
    try {
      db.execute('BEGIN');
      try {
        _setPlaylistSongsState(db, playlistId, songIds, true);
        db.execute('COMMIT');
      } on Object {
        db.execute('ROLLBACK');
        rethrow;
      }
    } finally {
      db.dispose();
    }
  }

  Future<void> removeSongsFromPlaylist(
    File databaseFile,
    int playlistId,
    List<int> songIds,
  ) async {
    if (!databaseFile.existsSync()) {
      return;
    }

    final db = sqlite3.open(databaseFile.path);
    try {
      db.execute('BEGIN');
      try {
        _setPlaylistSongsState(db, playlistId, songIds, false);
        db.execute('COMMIT');
      } on Object {
        db.execute('ROLLBACK');
        rethrow;
      }
    } finally {
      db.dispose();
    }
  }

  Future<void> reorderPlaylistSongs(
    File databaseFile,
    int playlistId,
    List<int> songIds, [
    PlaylistSortCriterion? sortCriterion,
  ]) async {
    if (!databaseFile.existsSync()) {
      return;
    }

    final db = sqlite3.open(databaseFile.path);
    try {
      final nextSongIds = _uniqueSongIds(songIds);
      final currentSongIds = _readPlaylistSongIds(db, playlistId);
      final currentSongIdSet = currentSongIds.toSet();
      if (currentSongIdSet.length <= 1) {
        return;
      }

      if (currentSongIdSet.length != nextSongIds.length ||
          nextSongIds.any((songId) => !currentSongIdSet.contains(songId))) {
        throw StateError(
          'Playlist reorder request is out of sync with the current playlist.',
        );
      }

      db.execute('BEGIN');
      try {
        db.execute('UPDATE PlaylistItem SET State = ? WHERE PlaylistId = ?', [
          _inactiveState,
          playlistId,
        ]);
        _insertPlaylistSongsInOrder(db, playlistId, nextSongIds);
        if (sortCriterion != null) {
          db.execute('UPDATE Playlist SET Criterion = ? WHERE Id = ?', [
            _toStoredPlaylistSortCriterion(sortCriterion),
            playlistId,
          ]);
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

  _PlaylistSettings _readPlaylistSettings(Database db) {
    final rows = db.select('''
      SELECT
        MyFavorites AS myFavorites,
        NowPlaying AS nowPlaying
      FROM Settings
      ORDER BY Id
      LIMIT 1
    ''');
    return _PlaylistSettings(
      myFavoritesId: rows.isEmpty ? 0 : rows.first['myFavorites'] as int,
      nowPlayingId: rows.isEmpty ? 0 : rows.first['nowPlaying'] as int,
    );
  }

  String _validatePlaylistName(
    Database db,
    String name, {
    int? currentPlaylistId,
  }) {
    final nextName = name.trim();
    if (nextName.isEmpty) {
      throw ArgumentError('Playlist name cannot be empty.');
    }

    final rows = db.select(
      '''
      SELECT Id
      FROM Playlist
      WHERE Name = ?
        AND State = ?
      LIMIT 1
    ''',
      [nextName, _activeState],
    );
    if (rows.isNotEmpty && rows.first['Id'] != currentPlaylistId) {
      throw ArgumentError('Playlist "$nextName" already exists.');
    }

    return nextName;
  }

  void _setPlaylistSongsState(
    Database db,
    int playlistId,
    List<int> songIds,
    bool isActive,
  ) {
    final uniqueIds = _uniqueSongIds(songIds);
    if (uniqueIds.isEmpty) {
      return;
    }

    final placeholders = List.filled(uniqueIds.length, '?').join(', ');
    if (isActive) {
      db.execute(
        '''
        UPDATE PlaylistItem
        SET State = ?
        WHERE PlaylistId = ?
          AND ItemId IN ($placeholders)
      ''',
        [_inactiveState, playlistId, ...uniqueIds],
      );
      db.execute(
        '''
        UPDATE PlaylistItem
        SET State = ?
        WHERE Id IN (
          SELECT MAX(Id)
          FROM PlaylistItem
          WHERE PlaylistId = ?
            AND ItemId IN ($placeholders)
          GROUP BY ItemId
        )
      ''',
        [_activeState, playlistId, ...uniqueIds],
      );
      db.execute(
        '''
        INSERT INTO PlaylistItem (PlaylistId, ItemId, State)
        SELECT ?, Music.Id, ?
        FROM Music
        WHERE Music.Id IN ($placeholders)
          AND Music.State = ?
          AND NOT EXISTS (
            SELECT 1
            FROM PlaylistItem
            WHERE PlaylistItem.PlaylistId = ?
              AND PlaylistItem.ItemId = Music.Id
          )
      ''',
        [playlistId, _activeState, ...uniqueIds, _activeState, playlistId],
      );
      return;
    }

    db.execute(
      '''
      UPDATE PlaylistItem
      SET State = ?
      WHERE PlaylistId = ?
        AND ItemId IN ($placeholders)
    ''',
      [_inactiveState, playlistId, ...uniqueIds],
    );
  }

  void _insertPlaylistSongsInOrder(
    Database db,
    int playlistId,
    List<int> songIds,
  ) {
    final rows = List.filled(songIds.length, '(?, ?)').join(', ');
    db.execute(
      '''
      WITH OrderedSongs(SongId, Position) AS (
        VALUES $rows
      )
      INSERT INTO PlaylistItem (PlaylistId, ItemId, State)
      SELECT ?, OrderedSongs.SongId, ?
      FROM OrderedSongs
      JOIN Music
        ON Music.Id = OrderedSongs.SongId
       AND Music.State = ?
      ORDER BY OrderedSongs.Position
    ''',
      [
        ...songIds.indexed.expand((entry) => [entry.$2, entry.$1]),
        playlistId,
        _activeState,
        _activeState,
      ],
    );
  }

  List<int> _readPlaylistSongIds(Database db, int playlistId) {
    if (playlistId <= 0) {
      return const [];
    }

    final rows = db.select(
      '''
      SELECT PlaylistItem.ItemId AS songId
      FROM PlaylistItem
      INNER JOIN Music
        ON Music.Id = PlaylistItem.ItemId
      WHERE PlaylistItem.PlaylistId = ?
        AND PlaylistItem.State = ?
        AND Music.State = ?
      ORDER BY PlaylistItem.Id
    ''',
      [playlistId, _activeState, _activeState],
    );
    return rows.map((row) => row['songId'] as int).toList();
  }
}

class _PlaylistSettings {
  const _PlaylistSettings({
    required this.myFavoritesId,
    required this.nowPlayingId,
  });

  final int myFavoritesId;
  final int nowPlayingId;
}

PlaylistSortCriterion _fromStoredPlaylistSortCriterion(int value) {
  switch (value) {
    case 1:
      return PlaylistSortCriterion.artist;
    case 2:
      return PlaylistSortCriterion.album;
    case 3:
      return PlaylistSortCriterion.duration;
    case 4:
      return PlaylistSortCriterion.playCount;
    case 5:
      return PlaylistSortCriterion.dateAdded;
    default:
      return PlaylistSortCriterion.title;
  }
}

int _toStoredPlaylistSortCriterion(PlaylistSortCriterion value) {
  switch (value) {
    case PlaylistSortCriterion.artist:
      return 1;
    case PlaylistSortCriterion.album:
      return 2;
    case PlaylistSortCriterion.duration:
      return 3;
    case PlaylistSortCriterion.playCount:
      return 4;
    case PlaylistSortCriterion.dateAdded:
      return 5;
    case PlaylistSortCriterion.title:
      return 0;
  }
}

List<int> _uniqueSongIds(List<int> songIds) {
  return songIds.map((songId) => songId).toSet().toList();
}
