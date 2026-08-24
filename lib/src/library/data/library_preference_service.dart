import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

import 'package:smplayer_flutter/src/settings/settings_model.dart'
    show
        PreferenceEntityType,
        PreferenceItemSnapshot,
        PreferenceLevel,
        PreferenceSectionKey,
        PreferenceSettingsSnapshot;

const _activeState = 1;
const _inactiveState = 0;

class LibraryPreferenceService {
  const LibraryPreferenceService();

  Future<void> addPreferenceItem(
    File databaseFile,
    String type,
    String itemId,
    String name,
    String level,
  ) async {
    final db = sqlite3.open(databaseFile.path);
    try {
      final entityValue = _toPreferenceEntityValue(type);
      final levelValue = _toPreferenceLevelValue(level);
      db.execute(
        '''
        UPDATE PreferenceItem
        SET ItemName = ?, IsEnabled = 1, Level = ?
        WHERE Type = ?
          AND ItemId = ?
          AND State = ?
      ''',
        [name, levelValue, entityValue, itemId, _activeState],
      );

      final changedRows =
          db.select('SELECT changes() AS count').first['count'] as int;
      if (changedRows == 0) {
        db.execute(
          '''
          INSERT INTO PreferenceItem (Type, ItemId, ItemName, IsEnabled, Level, State)
          VALUES (?, ?, ?, 1, ?, ?)
        ''',
          [entityValue, itemId, name, levelValue, _activeState],
        );
      }
    } finally {
      db.dispose();
    }
  }

  Future<String?> getPreferenceLevel(
    File databaseFile,
    String type,
    String itemId,
  ) async {
    if (!databaseFile.existsSync()) {
      return null;
    }

    final db = sqlite3.open(databaseFile.path);
    try {
      final rows = db.select(
        '''
        SELECT Level AS level
        FROM PreferenceItem
        WHERE Type = ?
          AND ItemId = ?
          AND IsEnabled = 1
          AND State = ?
        LIMIT 1
      ''',
        [_toPreferenceEntityValue(type), itemId, _activeState],
      );
      if (rows.isEmpty) {
        return null;
      }
      return _toPreferenceLevelName(rows.first['level'] as int);
    } finally {
      db.dispose();
    }
  }

  Future<void> removePreferenceItem(
    File databaseFile,
    String type,
    String itemId,
  ) async {
    if (!databaseFile.existsSync()) {
      return;
    }

    final db = sqlite3.open(databaseFile.path);
    try {
      db.execute(
        '''
        UPDATE PreferenceItem
        SET IsEnabled = 0
        WHERE Type = ?
          AND ItemId = ?
          AND State = ?
      ''',
        [_toPreferenceEntityValue(type), itemId, _activeState],
      );
    } finally {
      db.dispose();
    }
  }

  Future<PreferenceSettingsSnapshot> getPreferenceSettings(
    File databaseFile,
  ) async {
    if (!databaseFile.existsSync()) {
      return PreferenceSettingsSnapshot.defaults();
    }

    final db = sqlite3.open(databaseFile.path);
    try {
      final setting = _ensurePreferenceSetting(db);
      final rows = db.select(
        '''
        SELECT
          PreferenceItem.Id AS id,
          PreferenceItem.Type AS type,
          PreferenceItem.ItemId AS itemId,
          PreferenceItem.ItemName AS itemName,
          PreferenceItem.IsEnabled AS isEnabled,
          PreferenceItem.Level AS level,
          Music.Name AS songName,
          Music.Path AS songTooltip,
          EXISTS(
            SELECT 1
            FROM MusicArtist
            WHERE MusicArtist.Name = PreferenceItem.ItemId
              AND MusicArtist.State = ?
          ) AS artistValid,
          EXISTS(
            SELECT 1
            FROM Music
            WHERE Music.Album = PreferenceItem.ItemId
              AND Music.State = ?
          ) AS albumValid,
          Playlist.Name AS playlistName,
          Folder.Path AS folderName,
          Folder.Path AS folderTooltip
        FROM PreferenceItem
        LEFT JOIN Music
          ON PreferenceItem.Type = 0
         AND Music.Id = CAST(PreferenceItem.ItemId AS INTEGER)
         AND Music.State = ?
        LEFT JOIN Playlist
          ON PreferenceItem.Type = 3
         AND Playlist.Id = CAST(PreferenceItem.ItemId AS INTEGER)
         AND Playlist.State = ?
        LEFT JOIN Folder
          ON PreferenceItem.Type = 4
         AND (
           Folder.Id = CAST(PreferenceItem.ItemId AS INTEGER)
           OR Folder.Path = PreferenceItem.ItemId
         )
         AND Folder.State = ?
        WHERE PreferenceItem.State = ?
        ORDER BY PreferenceItem.Id DESC
      ''',
        [
          _activeState,
          _activeState,
          _activeState,
          _activeState,
          _activeState,
          _activeState,
        ],
      );
      final items = rows.map(_toPreferenceItemSnapshot).toList();
      return PreferenceSettingsSnapshot(
        enabled: {
          PreferenceSectionKey.songs: (setting['Songs'] as int) != 0,
          PreferenceSectionKey.artists: (setting['Artists'] as int) != 0,
          PreferenceSectionKey.albums: (setting['Albums'] as int) != 0,
          PreferenceSectionKey.playlists: (setting['Playlists'] as int) != 0,
          PreferenceSectionKey.folders: (setting['Folders'] as int) != 0,
        },
        songs: _preferenceItemsByType(items, PreferenceEntityType.song),
        artists: _preferenceItemsByType(items, PreferenceEntityType.artist),
        albums: _preferenceItemsByType(items, PreferenceEntityType.album),
        playlists: _preferenceItemsByType(items, PreferenceEntityType.playlist),
        folders: _preferenceItemsByType(items, PreferenceEntityType.folder),
        others:
            items
                .where(
                  (item) =>
                      item.type == PreferenceEntityType.recentAdded ||
                      item.type == PreferenceEntityType.myFavorites ||
                      item.type == PreferenceEntityType.mostPlayed ||
                      item.type == PreferenceEntityType.leastPlayed,
                )
                .toList(),
      );
    } finally {
      db.dispose();
    }
  }

  Future<void> updatePreferenceSettings(
    File databaseFile,
    Map<PreferenceSectionKey, bool> enabled,
  ) async {
    if (!databaseFile.existsSync()) {
      return;
    }

    final db = sqlite3.open(databaseFile.path);
    try {
      final setting = _ensurePreferenceSetting(db);
      db.execute(
        '''
        UPDATE PreferenceSetting
        SET Songs = ?, Artists = ?, Albums = ?, Playlists = ?, Folders = ?
        WHERE Id = ?
      ''',
        [
          _preferenceSectionValue(enabled, PreferenceSectionKey.songs, setting),
          _preferenceSectionValue(
            enabled,
            PreferenceSectionKey.artists,
            setting,
          ),
          _preferenceSectionValue(
            enabled,
            PreferenceSectionKey.albums,
            setting,
          ),
          _preferenceSectionValue(
            enabled,
            PreferenceSectionKey.playlists,
            setting,
          ),
          _preferenceSectionValue(
            enabled,
            PreferenceSectionKey.folders,
            setting,
          ),
          setting['Id'] as int,
        ],
      );
    } finally {
      db.dispose();
    }
  }

  Future<void> updatePreferenceItem(
    File databaseFile,
    int itemId, {
    bool? isEnabled,
    PreferenceLevel? level,
  }) async {
    if (!databaseFile.existsSync()) {
      return;
    }

    final db = sqlite3.open(databaseFile.path);
    try {
      final rows = db.select(
        '''
        SELECT IsEnabled AS isEnabled, Level AS level
        FROM PreferenceItem
        WHERE Id = ?
          AND State = ?
        LIMIT 1
      ''',
        [itemId, _activeState],
      );
      if (rows.isEmpty) {
        return;
      }
      final item = rows.first;
      db.execute(
        '''
        UPDATE PreferenceItem
        SET IsEnabled = ?, Level = ?
        WHERE Id = ?
      ''',
        [
          isEnabled == null
              ? item['isEnabled'] as int
              : isEnabled
              ? 1
              : 0,
          level == null
              ? item['level'] as int
              : _toPreferenceLevelValue(_preferenceLevelName(level)),
          itemId,
        ],
      );
    } finally {
      db.dispose();
    }
  }

  Future<void> removePreferenceItemById(File databaseFile, int itemId) async {
    if (!databaseFile.existsSync()) {
      return;
    }

    final db = sqlite3.open(databaseFile.path);
    try {
      db.execute('UPDATE PreferenceItem SET State = ? WHERE Id = ?', [
        _inactiveState,
        itemId,
      ]);
    } finally {
      db.dispose();
    }
  }

  Future<void> clearInvalidPreferenceItems(
    File databaseFile,
    PreferenceEntityType type,
  ) async {
    if (!databaseFile.existsSync()) {
      return;
    }

    final db = sqlite3.open(databaseFile.path);
    try {
      final entityValue = _toPreferenceEntityValue(
        _preferenceEntityTypeName(type),
      );
      switch (type) {
        case PreferenceEntityType.song:
          _clearInvalidPreferenceItemsByExists(db, entityValue, '''
            SELECT 1
            FROM Music
            WHERE Music.Id = CAST(PreferenceItem.ItemId AS INTEGER)
              AND Music.State = ?
          ''');
        case PreferenceEntityType.artist:
          _clearInvalidPreferenceItemsByExists(db, entityValue, '''
            SELECT 1
            FROM MusicArtist
            WHERE MusicArtist.Name = PreferenceItem.ItemId
              AND MusicArtist.State = ?
          ''');
        case PreferenceEntityType.album:
          _clearInvalidPreferenceItemsByExists(db, entityValue, '''
            SELECT 1
            FROM Music
            WHERE Music.Album = PreferenceItem.ItemId
              AND Music.State = ?
          ''');
        case PreferenceEntityType.playlist:
          _clearInvalidPreferenceItemsByExists(db, entityValue, '''
            SELECT 1
            FROM Playlist
            WHERE Playlist.Id = CAST(PreferenceItem.ItemId AS INTEGER)
              AND Playlist.State = ?
          ''');
        case PreferenceEntityType.folder:
          _clearInvalidPreferenceItemsByExists(db, entityValue, '''
            SELECT 1
            FROM Folder
            WHERE (
              Folder.Id = CAST(PreferenceItem.ItemId AS INTEGER)
              OR Folder.Path = PreferenceItem.ItemId
            )
              AND Folder.State = ?
          ''');
        case PreferenceEntityType.recentAdded:
        case PreferenceEntityType.myFavorites:
        case PreferenceEntityType.mostPlayed:
        case PreferenceEntityType.leastPlayed:
          return;
      }
    } finally {
      db.dispose();
    }
  }

  Row _ensurePreferenceSetting(Database db) {
    var rows = db.select('''
      SELECT
        Id,
        Songs,
        Artists,
        Albums,
        Playlists,
        Folders,
        RecentAddedId,
        MyFavoritesId,
        MostPlayedId,
        LeastPlayedId
      FROM PreferenceSetting
      ORDER BY Id DESC
      LIMIT 1
    ''');
    if (rows.isEmpty) {
      db.execute('''
        INSERT INTO PreferenceSetting (Songs, Artists, Albums, Playlists, Folders)
        VALUES (0, 0, 0, 0, 0)
      ''');
      rows = db.select('''
        SELECT
          Id,
          Songs,
          Artists,
          Albums,
          Playlists,
          Folders,
          RecentAddedId,
          MyFavoritesId,
          MostPlayedId,
          LeastPlayedId
        FROM PreferenceSetting
        ORDER BY Id DESC
        LIMIT 1
      ''');
    }

    final setting = rows.first;
    _ensureBuiltinPreferenceItems(db);
    db.execute(
      '''
      UPDATE PreferenceSetting
      SET
        RecentAddedId = (SELECT Id FROM PreferenceItem WHERE Type = 5 AND State = ? ORDER BY Id LIMIT 1),
        MyFavoritesId = (SELECT Id FROM PreferenceItem WHERE Type = 6 AND State = ? ORDER BY Id LIMIT 1),
        MostPlayedId = (SELECT Id FROM PreferenceItem WHERE Type = 7 AND State = ? ORDER BY Id LIMIT 1),
        LeastPlayedId = (SELECT Id FROM PreferenceItem WHERE Type = 8 AND State = ? ORDER BY Id LIMIT 1)
      WHERE Id = ?
    ''',
      [
        _activeState,
        _activeState,
        _activeState,
        _activeState,
        setting['Id'] as int,
      ],
    );
    return db
        .select(
          '''
          SELECT
            Id,
            Songs,
            Artists,
            Albums,
            Playlists,
            Folders,
            RecentAddedId,
            MyFavoritesId,
            MostPlayedId,
            LeastPlayedId
          FROM PreferenceSetting
          WHERE Id = ?
          LIMIT 1
        ''',
          [setting['Id'] as int],
        )
        .first;
  }

  void _ensureBuiltinPreferenceItems(Database db) {
    for (final item in const [
      (type: 5, itemId: '5', itemName: 'Recent Added'),
      (type: 6, itemId: '6', itemName: 'My Favorites'),
      (type: 7, itemId: '7', itemName: 'Most Played'),
      (type: 8, itemId: '8', itemName: 'Least Played'),
    ]) {
      final rows = db.select(
        '''
        SELECT Id
        FROM PreferenceItem
        WHERE Type = ?
          AND State = ?
        LIMIT 1
      ''',
        [item.type, _activeState],
      );
      if (rows.isEmpty) {
        db.execute(
          '''
          INSERT INTO PreferenceItem (Type, ItemId, ItemName, IsEnabled, Level, State)
          VALUES (?, ?, ?, 0, 1, ?)
        ''',
          [item.type, item.itemId, item.itemName, _activeState],
        );
      }
    }
  }

  PreferenceItemSnapshot _toPreferenceItemSnapshot(Row row) {
    final type = _preferenceEntityTypeFromValue(row['type'] as int);
    final itemId = _preferenceItemId(row, type);
    final resolved = _resolvePreferenceItem(row, type, itemId);
    return PreferenceItemSnapshot(
      id: row['id'] as int,
      type: type,
      itemId: itemId,
      name: resolved.name,
      tooltip: resolved.tooltip,
      isEnabled: (row['isEnabled'] as int) != 0,
      level: _preferenceLevelFromValue(row['level'] as int),
      isValid: resolved.isValid,
      canRemove: (row['type'] as int) < 5,
    );
  }

  ({String name, String tooltip, bool isValid}) _resolvePreferenceItem(
    Row row,
    PreferenceEntityType type,
    String itemId,
  ) {
    final itemName = row['itemName'] as String? ?? '';
    switch (type) {
      case PreferenceEntityType.song:
        final songName = row['songName'] as String?;
        final songTooltip = row['songTooltip'] as String?;
        return songName == null
            ? (
              name: itemName.isEmpty ? itemId : itemName,
              tooltip: itemName.isEmpty ? itemId : itemName,
              isValid: false,
            )
            : (name: songName, tooltip: songTooltip!, isValid: true);
      case PreferenceEntityType.artist:
        return (
          name: itemId,
          tooltip: itemId,
          isValid: (row['artistValid'] as int) != 0,
        );
      case PreferenceEntityType.album:
        return (
          name: itemName.isEmpty ? itemId : itemName,
          tooltip: itemId,
          isValid: (row['albumValid'] as int) != 0,
        );
      case PreferenceEntityType.playlist:
        final playlistName = row['playlistName'] as String?;
        return playlistName == null
            ? (
              name: itemName.isEmpty ? itemId : itemName,
              tooltip: itemName.isEmpty ? itemId : itemName,
              isValid: false,
            )
            : (name: playlistName, tooltip: playlistName, isValid: true);
      case PreferenceEntityType.folder:
        final folderName = row['folderName'] as String?;
        final folderTooltip = row['folderTooltip'] as String?;
        return folderName == null
            ? (
              name: itemName.isEmpty ? itemId : itemName,
              tooltip: itemName.isEmpty ? itemId : itemName,
              isValid: false,
            )
            : (
              name: _preferenceFolderName(folderName),
              tooltip: folderTooltip!,
              isValid: true,
            );
      case PreferenceEntityType.recentAdded:
        return (name: 'Recent Added', tooltip: 'Recent Added', isValid: true);
      case PreferenceEntityType.myFavorites:
        return (name: 'My Favorites', tooltip: 'My Favorites', isValid: true);
      case PreferenceEntityType.mostPlayed:
        return (name: 'Most Played', tooltip: 'Most Played', isValid: true);
      case PreferenceEntityType.leastPlayed:
        return (name: 'Least Played', tooltip: 'Least Played', isValid: true);
    }
  }

  String _preferenceItemId(Row row, PreferenceEntityType type) {
    return switch (type) {
      PreferenceEntityType.recentAdded ||
      PreferenceEntityType.myFavorites ||
      PreferenceEntityType.mostPlayed ||
      PreferenceEntityType.leastPlayed => '',
      PreferenceEntityType.song ||
      PreferenceEntityType.artist ||
      PreferenceEntityType.album ||
      PreferenceEntityType.playlist ||
      PreferenceEntityType.folder => row['itemId'] as String,
    };
  }

  List<PreferenceItemSnapshot> _preferenceItemsByType(
    List<PreferenceItemSnapshot> items,
    PreferenceEntityType type,
  ) {
    return items.where((item) => item.type == type).toList();
  }

  int _preferenceSectionValue(
    Map<PreferenceSectionKey, bool> enabled,
    PreferenceSectionKey key,
    Row setting,
  ) {
    final value = enabled[key];
    if (value != null) {
      return value ? 1 : 0;
    }
    return setting[_preferenceSectionColumnName(key)] as int;
  }

  void _clearInvalidPreferenceItemsByExists(
    Database db,
    int entityValue,
    String existsSql,
  ) {
    db.execute(
      '''
      UPDATE PreferenceItem
      SET State = ?
      WHERE Type = ?
        AND State = ?
        AND NOT EXISTS ($existsSql)
    ''',
      [_inactiveState, entityValue, _activeState, _activeState],
    );
  }
}

int _toPreferenceEntityValue(String type) {
  return switch (type) {
    'song' => 0,
    'artist' => 1,
    'album' => 2,
    'playlist' => 3,
    'folder' => 4,
    'recent-added' => 5,
    'my-favorites' => 6,
    'most-played' => 7,
    'least-played' => 8,
    _ => throw ArgumentError.value(type, 'type'),
  };
}

PreferenceEntityType _preferenceEntityTypeFromValue(int type) {
  return switch (type) {
    0 => PreferenceEntityType.song,
    1 => PreferenceEntityType.artist,
    2 => PreferenceEntityType.album,
    3 => PreferenceEntityType.playlist,
    4 => PreferenceEntityType.folder,
    5 => PreferenceEntityType.recentAdded,
    6 => PreferenceEntityType.myFavorites,
    7 => PreferenceEntityType.mostPlayed,
    8 => PreferenceEntityType.leastPlayed,
    _ => throw ArgumentError.value(type, 'type'),
  };
}

String _preferenceEntityTypeName(PreferenceEntityType type) {
  return switch (type) {
    PreferenceEntityType.song => 'song',
    PreferenceEntityType.artist => 'artist',
    PreferenceEntityType.album => 'album',
    PreferenceEntityType.playlist => 'playlist',
    PreferenceEntityType.folder => 'folder',
    PreferenceEntityType.recentAdded => 'recent-added',
    PreferenceEntityType.myFavorites => 'my-favorites',
    PreferenceEntityType.mostPlayed => 'most-played',
    PreferenceEntityType.leastPlayed => 'least-played',
  };
}

int _toPreferenceLevelValue(String level) {
  return switch (level) {
    'do-not-appear' => 0,
    'dislike' => -1,
    'normal' => 1,
    'high' => 2,
    'higher' => 3,
    'very-high' => 4,
    _ => throw ArgumentError.value(level, 'level'),
  };
}

PreferenceLevel _preferenceLevelFromValue(int level) {
  return switch (level) {
    0 => PreferenceLevel.doNotAppear,
    -1 => PreferenceLevel.dislike,
    2 => PreferenceLevel.high,
    3 => PreferenceLevel.higher,
    4 => PreferenceLevel.veryHigh,
    _ => PreferenceLevel.normal,
  };
}

String _preferenceLevelName(PreferenceLevel level) {
  return switch (level) {
    PreferenceLevel.doNotAppear => 'do-not-appear',
    PreferenceLevel.dislike => 'dislike',
    PreferenceLevel.normal => 'normal',
    PreferenceLevel.high => 'high',
    PreferenceLevel.higher => 'higher',
    PreferenceLevel.veryHigh => 'very-high',
  };
}

String _toPreferenceLevelName(int level) {
  return switch (level) {
    0 => 'do-not-appear',
    -1 => 'dislike',
    1 => 'normal',
    2 => 'high',
    3 => 'higher',
    4 => 'very-high',
    _ => 'normal',
  };
}

String _preferenceSectionColumnName(PreferenceSectionKey key) {
  return switch (key) {
    PreferenceSectionKey.songs => 'Songs',
    PreferenceSectionKey.artists => 'Artists',
    PreferenceSectionKey.albums => 'Albums',
    PreferenceSectionKey.playlists => 'Playlists',
    PreferenceSectionKey.folders => 'Folders',
  };
}

String _preferenceFolderName(String folderPath) {
  final separatorIndex = folderPath.lastIndexOf(RegExp(r'[\\/]'));
  return separatorIndex < 0
      ? folderPath
      : folderPath.substring(separatorIndex + 1);
}
