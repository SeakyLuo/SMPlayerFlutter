import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

class LibraryDatabaseService {
  const LibraryDatabaseService();

  Database openInitializedLibraryDatabase(File databaseFile) {
    databaseFile.parent.createSync(recursive: true);
    final db = sqlite3.open(databaseFile.path);
    initializeLibrarySchema(db);
    return db;
  }

  void initializeLibrarySchema(Database db) {
    db.execute('''
      CREATE TABLE IF NOT EXISTS Settings (
        Id INTEGER PRIMARY KEY AUTOINCREMENT,
        RootPath TEXT DEFAULT '',
        LastMusicIndex INTEGER DEFAULT -1,
        Mode INTEGER DEFAULT 0,
        Volume REAL DEFAULT 50,
        IsNavigationCollapsed INTEGER DEFAULT 1,
        ThemeColor TEXT DEFAULT '#0078D7',
        NightMode INTEGER DEFAULT 3,
        NightModeStartTime TEXT DEFAULT '20:00',
        NightModeEndTime TEXT DEFAULT '06:00',
        NotificationSend INTEGER DEFAULT 1,
        NotificationDisplay INTEGER DEFAULT 1,
        LastPage TEXT DEFAULT '',
        LastPlaylist INTEGER DEFAULT 0,
        LocalViewMode INTEGER DEFAULT 0,
        MyFavorites INTEGER DEFAULT 0,
        NowPlaying INTEGER DEFAULT 0,
        MiniModeWithDropdown INTEGER DEFAULT 0,
        IsMuted INTEGER DEFAULT 0,
        AutoPlay INTEGER DEFAULT 0,
        ShuffleAfterOneRound INTEGER DEFAULT 1,
        PreviousButtonRestartsTrack INTEGER DEFAULT 1,
        AutoLyrics INTEGER DEFAULT 1,
        SaveMusicProgress INTEGER DEFAULT 1,
        MusicProgress REAL DEFAULT 0,
        MusicLibraryCriterion INTEGER DEFAULT 0,
        AlbumsCriterion INTEGER DEFAULT -1,
        HideMultiSelectCommandBarAfterOperation INTEGER DEFAULT 1,
        ShowCount INTEGER DEFAULT 1,
        ShowLyricsInNotification INTEGER DEFAULT 0,
        VoiceAssistantPreferredLanguage INTEGER DEFAULT 0,
        SearchArtistsCriterion INTEGER DEFAULT -1,
        SearchAlbumsCriterion INTEGER DEFAULT -1,
        SearchSongsCriterion INTEGER DEFAULT -1,
        SearchPlaylistsCriterion INTEGER DEFAULT -1,
        SearchFoldersCriterion INTEGER DEFAULT -1,
        LastReleaseNotesVersion TEXT DEFAULT '',
        RemotePlayPassword TEXT DEFAULT '',
        UseFilenameNotMusicName INTEGER DEFAULT 0,
        SmartMultiArtistRecognition INTEGER DEFAULT 1,
        NotificationLyricsSource INTEGER DEFAULT 0,
        PlayerLyricsSource INTEGER DEFAULT 3,
        SaveLyricsImmediately INTEGER DEFAULT 0,
        PreserveInternetLyricsTimestamps INTEGER DEFAULT 1,
        DesktopLyricsEnabled INTEGER DEFAULT 0,
        DesktopLyricsLocked INTEGER DEFAULT 0,
        DesktopLyricsColor TEXT DEFAULT '#4aa8ff',
        DesktopLyricsStrokeColor TEXT DEFAULT '#111111',
        DesktopLyricsFontSize INTEGER DEFAULT 28,
        DesktopLyricsFontFamily TEXT DEFAULT 'system',
        DesktopLyricsOpacity INTEGER DEFAULT 88,
        DesktopLyricsBounds TEXT DEFAULT '',
        MainWindowBounds TEXT DEFAULT '',
        MainWindowMaximized INTEGER DEFAULT 0,
        LastDisplayMode INTEGER DEFAULT 0,
        QuitOnClose INTEGER DEFAULT 1
      )
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS Music (
        Id INTEGER PRIMARY KEY AUTOINCREMENT,
        Path TEXT NOT NULL,
        Name TEXT DEFAULT '',
        Artist TEXT DEFAULT '',
        Album TEXT DEFAULT '',
        AlbumId INTEGER DEFAULT 0,
        ThumbnailPath TEXT DEFAULT '',
        Duration INTEGER DEFAULT 0,
        PlayCount INTEGER DEFAULT 0,
        LyricsOffsetMs INTEGER DEFAULT 0,
        DateAdded TEXT DEFAULT '',
        State INTEGER DEFAULT 1
      )
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS Album (
        Id INTEGER PRIMARY KEY AUTOINCREMENT,
        Name TEXT NOT NULL,
        Artist TEXT DEFAULT '',
        ArtworkPath TEXT DEFAULT '',
        State INTEGER DEFAULT 1
      )
    ''');
    _createMusicArtistTable(db);
    db.execute('''
      CREATE TABLE IF NOT EXISTS Folder (
        Id INTEGER PRIMARY KEY AUTOINCREMENT,
        Path TEXT NOT NULL,
        Criterion INTEGER DEFAULT 0,
        ParentId INTEGER DEFAULT 0,
        State INTEGER DEFAULT 1
      )
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS File (
        Id INTEGER PRIMARY KEY AUTOINCREMENT,
        Path TEXT NOT NULL,
        ParentId INTEGER DEFAULT 0,
        FileId INTEGER DEFAULT 0,
        FileType INTEGER DEFAULT 0,
        State INTEGER DEFAULT 1
      )
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS Playlist (
        Id INTEGER PRIMARY KEY AUTOINCREMENT,
        Name TEXT NOT NULL,
        Criterion INTEGER DEFAULT -1,
        Priority INTEGER DEFAULT -1,
        State INTEGER DEFAULT 1
      )
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS PlaylistItem (
        Id INTEGER PRIMARY KEY AUTOINCREMENT,
        PlaylistId INTEGER NOT NULL,
        ItemId INTEGER NOT NULL,
        State INTEGER DEFAULT 1
      )
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS PreferenceSetting (
        Id INTEGER PRIMARY KEY AUTOINCREMENT,
        Songs INTEGER DEFAULT 0,
        Artists INTEGER DEFAULT 0,
        Albums INTEGER DEFAULT 0,
        Playlists INTEGER DEFAULT 0,
        Folders INTEGER DEFAULT 0,
        RecentAddedId INTEGER DEFAULT 0,
        MyFavoritesId INTEGER DEFAULT 0,
        MostPlayedId INTEGER DEFAULT 0,
        LeastPlayedId INTEGER DEFAULT 0
      )
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS PreferenceItem (
        Id INTEGER PRIMARY KEY AUTOINCREMENT,
        Type INTEGER DEFAULT 0,
        ItemId TEXT DEFAULT '',
        ItemName TEXT DEFAULT '',
        IsEnabled INTEGER DEFAULT 0,
        Level INTEGER DEFAULT 0,
        State INTEGER DEFAULT 1
      )
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS RecentRecord (
        Id INTEGER PRIMARY KEY AUTOINCREMENT,
        Type INTEGER DEFAULT 0,
        ItemId TEXT DEFAULT '',
        Time TEXT DEFAULT '',
        State INTEGER DEFAULT 1
      )
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS SearchState (
        Id INTEGER PRIMARY KEY CHECK (Id = 1),
        LastQuery TEXT DEFAULT ''
      )
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS SearchHistory (
        Id INTEGER PRIMARY KEY AUTOINCREMENT,
        Query TEXT NOT NULL,
        Type TEXT DEFAULT 'sidebar',
        SearchedAt TEXT DEFAULT ''
      )
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS HiddenStorageItem (
        Id INTEGER PRIMARY KEY AUTOINCREMENT,
        Type TEXT NOT NULL,
        Path TEXT NOT NULL,
        State INTEGER DEFAULT 1
      )
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS RemoteSetting (
        Id INTEGER PRIMARY KEY CHECK (Id = 1),
        DeviceId TEXT NOT NULL,
        DeviceName TEXT DEFAULT '',
        ShareEnabled INTEGER DEFAULT 0,
        Port INTEGER DEFAULT 8023,
        Password TEXT DEFAULT ''
      )
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS AuthorizedDevice (
        Id INTEGER PRIMARY KEY AUTOINCREMENT,
        DeviceId TEXT DEFAULT '',
        DeviceName TEXT DEFAULT '',
        Platform TEXT DEFAULT '',
        Browser TEXT DEFAULT '',
        Ip TEXT NOT NULL,
        TokenHash TEXT DEFAULT '',
        Auth INTEGER DEFAULT 1,
        State INTEGER DEFAULT 1,
        CreateTime TEXT DEFAULT '',
        UpdateTime TEXT DEFAULT '',
        LastSeenTime TEXT DEFAULT ''
      )
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS RemoteHost (
        Id INTEGER PRIMARY KEY AUTOINCREMENT,
        HostId TEXT NOT NULL,
        Name TEXT DEFAULT '',
        BaseUrl TEXT NOT NULL,
        Platform TEXT DEFAULT '',
        Token TEXT DEFAULT '',
        State INTEGER DEFAULT 1,
        CreateTime TEXT DEFAULT '',
        UpdateTime TEXT DEFAULT '',
        LastConnectedTime TEXT DEFAULT ''
      )
    ''');
    _ensureLibrarySchemaColumns(db);
    if (!_tableHasRows(db, 'Settings')) {
      db.execute('INSERT INTO Settings DEFAULT VALUES');
    }
    db.execute(
      "INSERT OR IGNORE INTO SearchState (Id, LastQuery) VALUES (1, '')",
    );
    db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_music_path ON Music(Path)',
    );
    db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_album_name
        ON Album(Name COLLATE NOCASE)
    ''');
    db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_music_artist_music_name
        ON MusicArtist(MusicId, Name COLLATE NOCASE)
    ''');
    db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_folder_path ON Folder(Path)',
    );
    db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_file_path ON File(Path)');
    db.execute(
      'CREATE INDEX IF NOT EXISTS idx_playlist_name ON Playlist(Name)',
    );
    db.execute('DROP INDEX IF EXISTS idx_search_history_query_nocase');
    db.execute('''
      CREATE INDEX IF NOT EXISTS idx_search_history_query_lookup
        ON SearchHistory(Query COLLATE NOCASE, Type)
    ''');
    db.execute('''
      CREATE INDEX IF NOT EXISTS idx_music_artist_name
        ON MusicArtist(Name COLLATE NOCASE)
    ''');
    db.execute('''
      CREATE INDEX IF NOT EXISTS idx_music_artist_music ON MusicArtist(MusicId)
    ''');
    db.execute(
      'CREATE INDEX IF NOT EXISTS idx_folder_parent ON Folder(ParentId)',
    );
    db.execute('CREATE INDEX IF NOT EXISTS idx_file_parent ON File(ParentId)');
    db.execute('''
      CREATE INDEX IF NOT EXISTS idx_playlist_item_playlist
        ON PlaylistItem(PlaylistId)
    ''');
    db.execute('''
      CREATE INDEX IF NOT EXISTS idx_playlist_item_item ON PlaylistItem(ItemId)
    ''');
    db.execute('''
      CREATE INDEX IF NOT EXISTS idx_recent_record_type ON RecentRecord(Type)
    ''');
    db.execute('''
      CREATE INDEX IF NOT EXISTS idx_preference_item_type_item
        ON PreferenceItem(Type, ItemId)
    ''');
    db.execute('''
      CREATE INDEX IF NOT EXISTS idx_search_history_time
        ON SearchHistory(SearchedAt)
    ''');
    db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_hidden_storage_item_type_path
        ON HiddenStorageItem(Type, Path)
    ''');
  }

  void _ensureLibrarySchemaColumns(Database db) {
    _addColumnsIfMissing(db, 'Settings', {
      'RootPath': "TEXT DEFAULT ''",
      'LastMusicIndex': 'INTEGER DEFAULT -1',
      'Mode': 'INTEGER DEFAULT 0',
      'Volume': 'REAL DEFAULT 50',
      'IsNavigationCollapsed': 'INTEGER DEFAULT 1',
      'ThemeColor': "TEXT DEFAULT '#0078D7'",
      'NightMode': 'INTEGER DEFAULT 3',
      'NightModeStartTime': "TEXT DEFAULT '20:00'",
      'NightModeEndTime': "TEXT DEFAULT '06:00'",
      'NotificationSend': 'INTEGER DEFAULT 1',
      'NotificationDisplay': 'INTEGER DEFAULT 1',
      'LastPage': "TEXT DEFAULT ''",
      'LastPlaylist': 'INTEGER DEFAULT 0',
      'LocalViewMode': 'INTEGER DEFAULT 0',
      'MyFavorites': 'INTEGER DEFAULT 0',
      'NowPlaying': 'INTEGER DEFAULT 0',
      'MiniModeWithDropdown': 'INTEGER DEFAULT 0',
      'IsMuted': 'INTEGER DEFAULT 0',
      'AutoPlay': 'INTEGER DEFAULT 0',
      'ShuffleAfterOneRound': 'INTEGER DEFAULT 1',
      'PreviousButtonRestartsTrack': 'INTEGER DEFAULT 1',
      'AutoLyrics': 'INTEGER DEFAULT 1',
      'SaveMusicProgress': 'INTEGER DEFAULT 1',
      'MusicProgress': 'REAL DEFAULT 0',
      'MusicLibraryCriterion': 'INTEGER DEFAULT 0',
      'AlbumsCriterion': 'INTEGER DEFAULT -1',
      'HideMultiSelectCommandBarAfterOperation': 'INTEGER DEFAULT 1',
      'ShowCount': 'INTEGER DEFAULT 1',
      'ShowLyricsInNotification': 'INTEGER DEFAULT 0',
      'VoiceAssistantPreferredLanguage': 'INTEGER DEFAULT 0',
      'SearchArtistsCriterion': 'INTEGER DEFAULT -1',
      'SearchAlbumsCriterion': 'INTEGER DEFAULT -1',
      'SearchSongsCriterion': 'INTEGER DEFAULT -1',
      'SearchPlaylistsCriterion': 'INTEGER DEFAULT -1',
      'SearchFoldersCriterion': 'INTEGER DEFAULT -1',
      'LastReleaseNotesVersion': "TEXT DEFAULT ''",
      'RemotePlayPassword': "TEXT DEFAULT ''",
      'UseFilenameNotMusicName': 'INTEGER DEFAULT 0',
      'SmartMultiArtistRecognition': 'INTEGER DEFAULT 1',
      'NotificationLyricsSource': 'INTEGER DEFAULT 0',
      'PlayerLyricsSource': 'INTEGER DEFAULT 3',
      'SaveLyricsImmediately': 'INTEGER DEFAULT 0',
      'PreserveInternetLyricsTimestamps': 'INTEGER DEFAULT 1',
      'DesktopLyricsEnabled': 'INTEGER DEFAULT 0',
      'DesktopLyricsLocked': 'INTEGER DEFAULT 0',
      'DesktopLyricsColor': "TEXT DEFAULT '#4aa8ff'",
      'DesktopLyricsStrokeColor': "TEXT DEFAULT '#111111'",
      'DesktopLyricsFontSize': 'INTEGER DEFAULT 28',
      'DesktopLyricsFontFamily': "TEXT DEFAULT 'system'",
      'DesktopLyricsOpacity': 'INTEGER DEFAULT 88',
      'DesktopLyricsBounds': "TEXT DEFAULT ''",
      'MainWindowBounds': "TEXT DEFAULT ''",
      'MainWindowMaximized': 'INTEGER DEFAULT 0',
      'LastDisplayMode': 'INTEGER DEFAULT 0',
      'QuitOnClose': 'INTEGER DEFAULT 1',
    });
    _addColumnsIfMissing(db, 'Music', {
      'Path': "TEXT DEFAULT ''",
      'Name': "TEXT DEFAULT ''",
      'Artist': "TEXT DEFAULT ''",
      'Album': "TEXT DEFAULT ''",
      'AlbumId': 'INTEGER DEFAULT 0',
      'ThumbnailPath': "TEXT DEFAULT ''",
      'Duration': 'INTEGER DEFAULT 0',
      'PlayCount': 'INTEGER DEFAULT 0',
      'LyricsOffsetMs': 'INTEGER DEFAULT 0',
      'DateAdded': "TEXT DEFAULT ''",
      'State': 'INTEGER DEFAULT 1',
    });
    _addColumnsIfMissing(db, 'Album', {
      'Name': "TEXT DEFAULT ''",
      'Artist': "TEXT DEFAULT ''",
      'ArtworkPath': "TEXT DEFAULT ''",
      'State': 'INTEGER DEFAULT 1',
    });
    _addColumnsIfMissing(db, 'MusicArtist', {
      'MusicId': 'INTEGER DEFAULT 0',
      'Name': "TEXT DEFAULT ''",
      'Priority': 'INTEGER DEFAULT 0',
      'State': 'INTEGER DEFAULT 1',
    });
    _addColumnsIfMissing(db, 'Folder', {
      'Path': "TEXT DEFAULT ''",
      'Criterion': 'INTEGER DEFAULT 0',
      'ParentId': 'INTEGER DEFAULT 0',
      'State': 'INTEGER DEFAULT 1',
    });
    _addColumnsIfMissing(db, 'File', {
      'Path': "TEXT DEFAULT ''",
      'ParentId': 'INTEGER DEFAULT 0',
      'FileId': 'INTEGER DEFAULT 0',
      'FileType': 'INTEGER DEFAULT 0',
      'State': 'INTEGER DEFAULT 1',
    });
    _addColumnsIfMissing(db, 'Playlist', {
      'Name': "TEXT DEFAULT ''",
      'Criterion': 'INTEGER DEFAULT -1',
      'Priority': 'INTEGER DEFAULT -1',
      'State': 'INTEGER DEFAULT 1',
    });
    _addColumnsIfMissing(db, 'PlaylistItem', {
      'PlaylistId': 'INTEGER DEFAULT 0',
      'ItemId': 'INTEGER DEFAULT 0',
      'State': 'INTEGER DEFAULT 1',
    });
    _addColumnsIfMissing(db, 'PreferenceSetting', {
      'Songs': 'INTEGER DEFAULT 0',
      'Artists': 'INTEGER DEFAULT 0',
      'Albums': 'INTEGER DEFAULT 0',
      'Playlists': 'INTEGER DEFAULT 0',
      'Folders': 'INTEGER DEFAULT 0',
      'RecentAddedId': 'INTEGER DEFAULT 0',
      'MyFavoritesId': 'INTEGER DEFAULT 0',
      'MostPlayedId': 'INTEGER DEFAULT 0',
      'LeastPlayedId': 'INTEGER DEFAULT 0',
    });
    _addColumnsIfMissing(db, 'PreferenceItem', {
      'Type': 'INTEGER DEFAULT 0',
      'ItemId': "TEXT DEFAULT ''",
      'ItemName': "TEXT DEFAULT ''",
      'IsEnabled': 'INTEGER DEFAULT 0',
      'Level': 'INTEGER DEFAULT 0',
      'State': 'INTEGER DEFAULT 1',
    });
    _addColumnsIfMissing(db, 'RecentRecord', {
      'Type': 'INTEGER DEFAULT 0',
      'ItemId': "TEXT DEFAULT ''",
      'Time': "TEXT DEFAULT ''",
      'State': 'INTEGER DEFAULT 1',
    });
    _addColumnsIfMissing(db, 'SearchState', {'LastQuery': "TEXT DEFAULT ''"});
    _addColumnsIfMissing(db, 'SearchHistory', {
      'Query': "TEXT DEFAULT ''",
      'Type': "TEXT DEFAULT 'sidebar'",
      'SearchedAt': "TEXT DEFAULT ''",
    });
    _addColumnsIfMissing(db, 'HiddenStorageItem', {
      'Type': "TEXT DEFAULT ''",
      'Path': "TEXT DEFAULT ''",
      'State': 'INTEGER DEFAULT 1',
    });
    _addColumnsIfMissing(db, 'RemoteSetting', {
      'DeviceId': "TEXT DEFAULT ''",
      'DeviceName': "TEXT DEFAULT ''",
      'ShareEnabled': 'INTEGER DEFAULT 0',
      'Port': 'INTEGER DEFAULT 8023',
      'Password': "TEXT DEFAULT ''",
    });
    _addColumnsIfMissing(db, 'AuthorizedDevice', {
      'DeviceId': "TEXT DEFAULT ''",
      'DeviceName': "TEXT DEFAULT ''",
      'Platform': "TEXT DEFAULT ''",
      'Browser': "TEXT DEFAULT ''",
      'Ip': "TEXT DEFAULT ''",
      'TokenHash': "TEXT DEFAULT ''",
      'Auth': 'INTEGER DEFAULT 1',
      'State': 'INTEGER DEFAULT 1',
      'CreateTime': "TEXT DEFAULT ''",
      'UpdateTime': "TEXT DEFAULT ''",
      'LastSeenTime': "TEXT DEFAULT ''",
    });
    _addColumnsIfMissing(db, 'RemoteHost', {
      'HostId': "TEXT DEFAULT ''",
      'Name': "TEXT DEFAULT ''",
      'BaseUrl': "TEXT DEFAULT ''",
      'Platform': "TEXT DEFAULT ''",
      'Token': "TEXT DEFAULT ''",
      'State': 'INTEGER DEFAULT 1',
      'CreateTime': "TEXT DEFAULT ''",
      'UpdateTime': "TEXT DEFAULT ''",
      'LastConnectedTime': "TEXT DEFAULT ''",
    });
  }

  void _addColumnsIfMissing(
    Database db,
    String tableName,
    Map<String, String> columns,
  ) {
    final existingColumns =
        db
            .select("PRAGMA table_info('$tableName')")
            .map((row) => row['name'] as String)
            .toSet();
    for (final entry in columns.entries) {
      if (!existingColumns.contains(entry.key)) {
        db.execute(
          'ALTER TABLE $tableName ADD COLUMN ${entry.key} ${entry.value}',
        );
      }
    }
  }

  void _createMusicArtistTable(Database db) {
    db.execute('''
      CREATE TABLE IF NOT EXISTS MusicArtist (
        Id INTEGER PRIMARY KEY AUTOINCREMENT,
        MusicId INTEGER,
        Name TEXT,
        Priority INTEGER DEFAULT 0,
        State INTEGER DEFAULT 1
      )
    ''');
  }

  bool _tableHasRows(Database db, String tableName) {
    final rows = db.select('SELECT 1 AS found FROM $tableName LIMIT 1');
    return rows.isNotEmpty;
  }
}
