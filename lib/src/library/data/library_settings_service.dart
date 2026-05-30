import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

import 'library_database_service.dart';
import 'library_models.dart';
import 'library_read_service.dart';
import 'package:smplayer_flutter/src/settings/settings_model.dart' as settings;

typedef SettingsDatabaseCleanup = void Function(Database db);

const _activeState = 1;

class LibrarySettingsService {
  const LibrarySettingsService({required LibraryDatabaseService database})
    : _database = database;

  final LibraryDatabaseService _database;

  Future<settings.SettingsSnapshot?> getSettingsSnapshot(
    File databaseFile, {
    required SettingsDatabaseCleanup cleanupInvalidLastPlaylist,
  }) async {
    if (!databaseFile.existsSync()) {
      return null;
    }

    final db = _database.openInitializedLibraryDatabase(databaseFile);
    try {
      cleanupInvalidLastPlaylist(db);
      final rows = db.select('SELECT * FROM Settings ORDER BY Id DESC LIMIT 1');
      if (rows.isEmpty) {
        return null;
      }
      return settingsSnapshotFromRow(rows.single);
    } finally {
      db.dispose();
    }
  }

  Future<void> updateSettings(
    File databaseFile,
    settings.AppSettingsUpdate update,
  ) async {
    if (!databaseFile.existsSync()) {
      return;
    }

    final db = sqlite3.open(databaseFile.path);
    try {
      final snapshot = settingsSnapshotFromRow(
        db.select('SELECT * FROM Settings ORDER BY Id DESC LIMIT 1').single,
      );
      final next = snapshot.apply(update);
      db.execute(
        '''
        UPDATE Settings
        SET
          RootPath = ?,
          UseFilenameNotMusicName = ?,
          SmartMultiArtistRecognition = ?,
          ShowCount = ?,
          ThemeColor = ?,
          NightMode = ?,
          NightModeStartTime = ?,
          NightModeEndTime = ?,
          NotificationDisplay = ?,
          NotificationSend = ?,
          AutoLyrics = ?,
          ShowLyricsInNotification = ?,
          VoiceAssistantPreferredLanguage = ?,
          NotificationLyricsSource = ?,
          PlayerLyricsSource = ?,
          SaveLyricsImmediately = ?,
          PreserveInternetLyricsTimestamps = ?,
          DesktopLyricsEnabled = ?,
          DesktopLyricsLocked = ?,
          DesktopLyricsColor = ?,
          DesktopLyricsStrokeColor = ?,
          DesktopLyricsFontSize = ?,
          DesktopLyricsFontFamily = ?,
          DesktopLyricsOpacity = ?,
          DesktopLyricsBounds = ?,
          MusicLibraryCriterion = ?,
          AlbumsCriterion = ?,
          SearchArtistsCriterion = ?,
          SearchAlbumsCriterion = ?,
          SearchSongsCriterion = ?,
          SearchPlaylistsCriterion = ?,
          SearchFoldersCriterion = ?,
          AutoPlay = ?,
          ShuffleAfterOneRound = ?,
          PreviousButtonRestartsTrack = ?,
          SaveMusicProgress = ?,
          HideMultiSelectCommandBarAfterOperation = ?,
          QuitOnClose = ?,
          MusicProgress = ?,
          LocalViewMode = ?,
          LastReleaseNotesVersion = ?
        WHERE Id = ?
      ''',
        [
          next.rootPath,
          _boolValue(next.useFilenameNotMusicName),
          _boolValue(next.smartMultiArtistRecognition),
          _boolValue(next.showCount),
          next.themeColor,
          _nightModeValue(next.nightMode),
          next.nightModeStartTime,
          next.nightModeEndTime,
          _notificationDisplayValue(next.notificationDisplay),
          _notificationSendValue(next.notificationSend),
          _boolValue(next.autoLyrics),
          _boolValue(next.showLyricsInNotification),
          _preferredLanguageValue(next.preferredLanguage),
          _lyricsRequestModeValue(next.notificationLyricsSource),
          _lyricsRequestModeValue(next.playerLyricsSource),
          _boolValue(next.saveLyricsImmediately),
          _boolValue(next.preserveInternetLyricsTimestamps),
          _boolValue(next.desktopLyricsEnabled),
          _boolValue(next.desktopLyricsLocked),
          next.desktopLyricsColor,
          next.desktopLyricsStrokeColor,
          next.desktopLyricsFontSize,
          next.desktopLyricsFontFamily,
          next.desktopLyricsOpacity,
          next.desktopLyricsBounds,
          _musicLibrarySortValue(next.musicLibrarySort),
          _albumSortValue(next.albumsSort),
          _searchSortValue(next.searchArtistsCriterion),
          _searchSortValue(next.searchAlbumsCriterion),
          _searchSortValue(next.searchSongsCriterion),
          _searchSortValue(next.searchPlaylistsCriterion),
          _searchSortValue(next.searchFoldersCriterion),
          _boolValue(next.autoPlay),
          _boolValue(next.shuffleAfterOneRound),
          _boolValue(next.previousButtonRestartsTrack),
          _boolValue(next.saveMusicProgress),
          _boolValue(next.hideMultiSelectCommandBarAfterOperation),
          _boolValue(next.quitOnClose),
          next.saveMusicProgress ? snapshot.musicProgress : 0,
          _localViewModeValue(next.localViewMode),
          next.lastReleaseNotesVersion,
          _settingsRowId(db),
        ],
      );
    } finally {
      db.dispose();
    }
  }

  Future<void> savePlaybackSettings(
    File databaseFile,
    settings.PlaybackSettingsUpdate update,
  ) async {
    if (!databaseFile.existsSync()) {
      return;
    }

    final db = sqlite3.open(databaseFile.path);
    try {
      final snapshot = settingsSnapshotFromRow(
        db.select('SELECT * FROM Settings ORDER BY Id DESC LIMIT 1').single,
      );
      final next = snapshot.applyPlaybackSettings(update);
      db.execute(
        '''
        UPDATE Settings
        SET
          LastMusicIndex = ?,
          Volume = ?,
          IsMuted = ?,
          Mode = ?,
          MusicProgress = ?
        WHERE Id = ?
      ''',
        [
          next.lastMusicIndex,
          next.volume,
          _boolValue(next.isMuted),
          _playbackModeValue(next.mode),
          next.musicProgress,
          _settingsRowId(db),
        ],
      );
    } finally {
      db.dispose();
    }
  }

  Future<void> updateMusicLibrarySort(
    File databaseFile,
    MusicLibrarySortCriterion criterion,
  ) async {
    if (!databaseFile.existsSync()) {
      return;
    }

    final db = _database.openInitializedLibraryDatabase(databaseFile);
    try {
      db.execute('UPDATE Settings SET MusicLibraryCriterion = ? WHERE Id = ?', [
        toStoredSortCriterion(criterion),
        1,
      ]);
    } finally {
      db.dispose();
    }
  }

  Future<void> updateAlbumsSort(
    File databaseFile,
    AlbumSortCriterion criterion,
  ) async {
    if (!databaseFile.existsSync()) {
      return;
    }

    final db = sqlite3.open(databaseFile.path);
    try {
      db.execute('UPDATE Settings SET AlbumsCriterion = ? WHERE Id = ?', [
        toStoredAlbumSortCriterion(criterion),
        1,
      ]);
    } finally {
      db.dispose();
    }
  }

  Future<void> updateLocalFolderSort(
    File databaseFile,
    String folderPath,
    LocalFolderSortCriterion criterion,
  ) async {
    if (!databaseFile.existsSync()) {
      return;
    }

    final db = sqlite3.open(databaseFile.path);
    try {
      db.execute(
        '''
        UPDATE Folder
        SET Criterion = ?
        WHERE Path = ?
          AND State = ?
      ''',
        [toStoredLocalFolderSortCriterion(criterion), folderPath, _activeState],
      );
    } finally {
      db.dispose();
    }
  }

  Future<void> saveViewState(
    File databaseFile, {
    String? lastPage,
    int? lastPlaylistId,
  }) async {
    if (!databaseFile.existsSync()) {
      return;
    }

    final db = sqlite3.open(databaseFile.path);
    try {
      final snapshot = settingsSnapshotFromRow(
        db.select('SELECT * FROM Settings ORDER BY Id DESC LIMIT 1').single,
      );
      db.execute(
        '''
        UPDATE Settings
        SET
          LastPage = ?,
          LastPlaylist = ?
        WHERE Id = ?
      ''',
        [
          lastPage ?? snapshot.lastPage,
          lastPlaylistId ?? snapshot.lastPlaylistId,
          _settingsRowId(db),
        ],
      );
    } finally {
      db.dispose();
    }
  }

  Future<void> saveMainWindowState(
    File databaseFile, {
    required String bounds,
    required bool maximized,
  }) async {
    if (!databaseFile.existsSync()) {
      return;
    }

    final db = sqlite3.open(databaseFile.path);
    try {
      db.execute(
        '''
        UPDATE Settings
        SET
          MainWindowBounds = ?,
          MainWindowMaximized = ?
        WHERE Id = (
          SELECT Id
          FROM Settings
          ORDER BY Id DESC
          LIMIT 1
        )
      ''',
        [bounds, _boolValue(maximized)],
      );
    } finally {
      db.dispose();
    }
  }

  settings.SettingsSnapshot settingsSnapshotFromRow(Row row) {
    final notificationSend = _notificationSendFromValue(
      row['NotificationSend'] as int,
    );
    return settings.SettingsSnapshot(
      rootPath: row['RootPath'] as String,
      useFilenameNotMusicName: (row['UseFilenameNotMusicName'] as int) != 0,
      smartMultiArtistRecognition:
          (row['SmartMultiArtistRecognition'] as int) != 0,
      showCount: (row['ShowCount'] as int) != 0,
      themeColor: (row['ThemeColor'] as String?) ?? '#0078D7',
      nightMode: _nightModeFromValue(row['NightMode'] as int),
      nightModeStartTime: row['NightModeStartTime'] as String,
      nightModeEndTime: row['NightModeEndTime'] as String,
      notificationSend: notificationSend,
      notificationDisplay: _notificationDisplayFromValue(
        row['NotificationDisplay'] as int,
      ),
      showNotifications:
          notificationSend != settings.NotificationSendMode.never,
      autoLyrics: (row['AutoLyrics'] as int) != 0,
      showLyricsInNotification: (row['ShowLyricsInNotification'] as int) != 0,
      notificationLyricsSource: _lyricsRequestModeFromValue(
        row['NotificationLyricsSource'] as int,
      ),
      playerLyricsSource: _lyricsRequestModeFromValue(
        row['PlayerLyricsSource'] as int,
      ),
      saveLyricsImmediately: true,
      preserveInternetLyricsTimestamps:
          (row['PreserveInternetLyricsTimestamps'] as int) != 0,
      desktopLyricsEnabled: (row['DesktopLyricsEnabled'] as int) != 0,
      desktopLyricsLocked: (row['DesktopLyricsLocked'] as int) != 0,
      desktopLyricsColor: (row['DesktopLyricsColor'] as String?) ?? '#4aa8ff',
      desktopLyricsStrokeColor:
          (row['DesktopLyricsStrokeColor'] as String?) ?? '',
      desktopLyricsFontSize: row['DesktopLyricsFontSize'] as int,
      desktopLyricsFontFamily: row['DesktopLyricsFontFamily'] as String,
      desktopLyricsOpacity: row['DesktopLyricsOpacity'] as int,
      desktopLyricsBounds: row['DesktopLyricsBounds'] as String,
      mainWindowBounds: row['MainWindowBounds'] as String,
      mainWindowMaximized: (row['MainWindowMaximized'] as int) != 0,
      preferredLanguage: _preferredLanguageFromValue(
        row['VoiceAssistantPreferredLanguage'] as int,
      ),
      musicLibrarySort: _settingsMusicLibrarySortFromValue(
        row['MusicLibraryCriterion'] as int,
      ),
      albumsSort: _settingsAlbumSortFromValue(row['AlbumsCriterion'] as int),
      searchArtistsCriterion: _searchSortFromValue(
        row['SearchArtistsCriterion'] as int,
      ),
      searchAlbumsCriterion: _searchSortFromValue(
        row['SearchAlbumsCriterion'] as int,
      ),
      searchSongsCriterion: _searchSortFromValue(
        row['SearchSongsCriterion'] as int,
      ),
      searchPlaylistsCriterion: _searchSortFromValue(
        row['SearchPlaylistsCriterion'] as int,
      ),
      searchFoldersCriterion: _searchSortFromValue(
        row['SearchFoldersCriterion'] as int,
      ),
      lastMusicIndex: row['LastMusicIndex'] as int,
      volume: (row['Volume'] as num).round(),
      isMuted: (row['IsMuted'] as int) != 0,
      mode: _playbackModeFromValue(row['Mode'] as int),
      musicProgress: (row['MusicProgress'] as num).toDouble(),
      autoPlay: (row['AutoPlay'] as int) != 0,
      shuffleAfterOneRound: (row['ShuffleAfterOneRound'] as int) != 0,
      previousButtonRestartsTrack:
          (row['PreviousButtonRestartsTrack'] as int) != 0,
      saveMusicProgress: (row['SaveMusicProgress'] as int) != 0,
      hideMultiSelectCommandBarAfterOperation:
          (row['HideMultiSelectCommandBarAfterOperation'] as int) != 0,
      localViewMode: _localViewModeFromValue(row['LocalViewMode'] as int),
      quitOnClose: (row['QuitOnClose'] as int) != 0,
      lastPage:
          (row['LastPage'] as String?)?.isEmpty ?? true
              ? '/songs'
              : row['LastPage'] as String,
      lastPlaylistId: row['LastPlaylist'] as int,
      lastReleaseNotesVersion: row['LastReleaseNotesVersion'] as String,
    );
  }

  int _settingsRowId(Database db) {
    return db
            .select('SELECT Id FROM Settings ORDER BY Id DESC LIMIT 1')
            .single['Id']
        as int;
  }
}

settings.NightMode _nightModeFromValue(int value) {
  return switch (value) {
    0 => settings.NightMode.auto,
    1 => settings.NightMode.onMode,
    3 => settings.NightMode.system,
    _ => settings.NightMode.never,
  };
}

int _nightModeValue(settings.NightMode mode) {
  return switch (mode) {
    settings.NightMode.auto => 0,
    settings.NightMode.onMode => 1,
    settings.NightMode.never => 2,
    settings.NightMode.system => 3,
  };
}

settings.NotificationSendMode _notificationSendFromValue(int value) {
  return value == 0
      ? settings.NotificationSendMode.never
      : settings.NotificationSendMode.musicChanged;
}

int _notificationSendValue(settings.NotificationSendMode mode) {
  return switch (mode) {
    settings.NotificationSendMode.never => 0,
    settings.NotificationSendMode.musicChanged => 1,
  };
}

settings.NotificationDisplayMode _notificationDisplayFromValue(int value) {
  return switch (value) {
    0 => settings.NotificationDisplayMode.reminder,
    2 => settings.NotificationDisplayMode.quick,
    _ => settings.NotificationDisplayMode.normal,
  };
}

int _notificationDisplayValue(settings.NotificationDisplayMode mode) {
  return switch (mode) {
    settings.NotificationDisplayMode.reminder => 0,
    settings.NotificationDisplayMode.normal => 1,
    settings.NotificationDisplayMode.quick => 2,
  };
}

settings.LyricsRequestMode _lyricsRequestModeFromValue(int value) {
  return switch (value) {
    1 => settings.LyricsRequestMode.local,
    2 => settings.LyricsRequestMode.embedded,
    3 => settings.LyricsRequestMode.auto,
    _ => settings.LyricsRequestMode.internet,
  };
}

int _lyricsRequestModeValue(settings.LyricsRequestMode mode) {
  return switch (mode) {
    settings.LyricsRequestMode.internet => 0,
    settings.LyricsRequestMode.local => 1,
    settings.LyricsRequestMode.embedded => 2,
    settings.LyricsRequestMode.auto => 3,
  };
}

settings.PreferredLanguage _preferredLanguageFromValue(int value) {
  return switch (value) {
    1 => settings.PreferredLanguage.enUS,
    2 => settings.PreferredLanguage.zhCN,
    3 => settings.PreferredLanguage.fr,
    4 => settings.PreferredLanguage.ru,
    5 => settings.PreferredLanguage.ja,
    6 => settings.PreferredLanguage.de,
    7 => settings.PreferredLanguage.ptBR,
    8 => settings.PreferredLanguage.es,
    9 => settings.PreferredLanguage.it,
    10 => settings.PreferredLanguage.zhHant,
    11 => settings.PreferredLanguage.nl,
    12 => settings.PreferredLanguage.cs,
    13 => settings.PreferredLanguage.uk,
    14 => settings.PreferredLanguage.sv,
    15 => settings.PreferredLanguage.id,
    _ => settings.PreferredLanguage.system,
  };
}

int _preferredLanguageValue(settings.PreferredLanguage language) {
  return switch (language) {
    settings.PreferredLanguage.system => 0,
    settings.PreferredLanguage.enUS => 1,
    settings.PreferredLanguage.zhCN => 2,
    settings.PreferredLanguage.fr => 3,
    settings.PreferredLanguage.ru => 4,
    settings.PreferredLanguage.ja => 5,
    settings.PreferredLanguage.de => 6,
    settings.PreferredLanguage.ptBR => 7,
    settings.PreferredLanguage.es => 8,
    settings.PreferredLanguage.it => 9,
    settings.PreferredLanguage.zhHant => 10,
    settings.PreferredLanguage.nl => 11,
    settings.PreferredLanguage.cs => 12,
    settings.PreferredLanguage.uk => 13,
    settings.PreferredLanguage.sv => 14,
    settings.PreferredLanguage.id => 15,
  };
}

settings.MusicLibrarySortCriterion _settingsMusicLibrarySortFromValue(
  int value,
) {
  return switch (value) {
    1 => settings.MusicLibrarySortCriterion.artist,
    2 => settings.MusicLibrarySortCriterion.album,
    3 => settings.MusicLibrarySortCriterion.duration,
    4 => settings.MusicLibrarySortCriterion.playCount,
    5 => settings.MusicLibrarySortCriterion.dateAdded,
    _ => settings.MusicLibrarySortCriterion.title,
  };
}

int _musicLibrarySortValue(settings.MusicLibrarySortCriterion value) {
  return switch (value) {
    settings.MusicLibrarySortCriterion.artist => 1,
    settings.MusicLibrarySortCriterion.album => 2,
    settings.MusicLibrarySortCriterion.duration => 3,
    settings.MusicLibrarySortCriterion.playCount => 4,
    settings.MusicLibrarySortCriterion.dateAdded => 5,
    settings.MusicLibrarySortCriterion.title => 0,
  };
}

settings.AlbumSortCriterion _settingsAlbumSortFromValue(int value) {
  return switch (value) {
    1 => settings.AlbumSortCriterion.artist,
    6 => settings.AlbumSortCriterion.name,
    _ => settings.AlbumSortCriterion.defaultCriterion,
  };
}

int _albumSortValue(settings.AlbumSortCriterion value) {
  return switch (value) {
    settings.AlbumSortCriterion.artist => 1,
    settings.AlbumSortCriterion.name => 6,
    settings.AlbumSortCriterion.defaultCriterion ||
    settings.AlbumSortCriterion.reverse => -1,
  };
}

settings.SearchSortCriterion _searchSortFromValue(int value) {
  return switch (value) {
    1 => settings.SearchSortCriterion.artist,
    2 => settings.SearchSortCriterion.album,
    3 => settings.SearchSortCriterion.duration,
    4 => settings.SearchSortCriterion.playCount,
    5 => settings.SearchSortCriterion.dateAdded,
    6 => settings.SearchSortCriterion.name,
    7 => settings.SearchSortCriterion.title,
    _ => settings.SearchSortCriterion.defaultCriterion,
  };
}

int _searchSortValue(settings.SearchSortCriterion value) {
  return switch (value) {
    settings.SearchSortCriterion.artist => 1,
    settings.SearchSortCriterion.album => 2,
    settings.SearchSortCriterion.duration => 3,
    settings.SearchSortCriterion.playCount => 4,
    settings.SearchSortCriterion.dateAdded => 5,
    settings.SearchSortCriterion.name => 6,
    settings.SearchSortCriterion.title => 7,
    settings.SearchSortCriterion.defaultCriterion => -1,
  };
}

settings.PlaybackMode _playbackModeFromValue(int value) {
  return switch (value) {
    1 => settings.PlaybackMode.repeat,
    2 => settings.PlaybackMode.repeatOne,
    3 => settings.PlaybackMode.shuffle,
    _ => settings.PlaybackMode.once,
  };
}

int _playbackModeValue(settings.PlaybackMode value) {
  return switch (value) {
    settings.PlaybackMode.repeat => 1,
    settings.PlaybackMode.repeatOne => 2,
    settings.PlaybackMode.shuffle => 3,
    settings.PlaybackMode.once => 0,
  };
}

settings.LocalViewMode _localViewModeFromValue(int value) {
  return value == 1 ? settings.LocalViewMode.list : settings.LocalViewMode.grid;
}

int _localViewModeValue(settings.LocalViewMode value) {
  return value == settings.LocalViewMode.list ? 1 : 0;
}

int _boolValue(bool value) => value ? 1 : 0;
