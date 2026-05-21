import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:http/http.dart' as http;
import 'package:sqlite3/sqlite3.dart';

import 'id3_tag_service.dart';
import 'artist_split_model.dart' as artist_split_model;
import 'library_models.dart';
import 'package:smplayer_flutter/src/settings/settings_model.dart' as settings;
import 'package:smplayer_flutter/src/settings/settings_model.dart'
    show
        PreferenceEntityType,
        PreferenceItemSnapshot,
        PreferenceLevel,
        PreferenceSectionKey,
        PreferenceSettingsSnapshot;

const _activeState = 1;
const _inactiveState = 0;
const _hiddenState = -1;
const _parentHiddenState = -2;
const _smPlayerDatabaseName = 'SMPlayerSettings.db';
const _nowPlayingJsonName = 'NowPlaying.json';
const _pendingSongDeletesJsonName = 'pending-song-deletes.json';
const _legacyUwpPackageIdentityName = '23778SeakyTheLoner.SMPlayer';
const _recentSongLimit = 500;
const _recentCollectionLimit = 200;
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

class _AudioFileMetadata {
  const _AudioFileMetadata({
    required this.properties,
    required this.duration,
    required this.thumbnailPath,
  });

  final Id3SongTagProperties properties;
  final int duration;
  final String thumbnailPath;
}

const _folderArtworkBaseNames = {
  'cover',
  'folder',
  'front',
  'album',
  'albumart',
  'albumart_{00000000-0000-0000-0000-000000000000}_large',
  'albumart_{00000000-0000-0000-0000-000000000000}_small',
  'albumartlarge',
  'albumartsmall',
};
const _folderArtworkExtensions = {
  '.jpg',
  '.jpeg',
  '.png',
  '.webp',
  '.bmp',
  '.gif',
};

bool _isLikelyArtworkImage(List<int> data) {
  if (data.length < 12) {
    return false;
  }
  if (data[0] == 0xff && data[1] == 0xd8 && data[2] == 0xff) {
    return true;
  }
  if (data[0] == 0x89 &&
      data[1] == 0x50 &&
      data[2] == 0x4e &&
      data[3] == 0x47 &&
      data[4] == 0x0d &&
      data[5] == 0x0a &&
      data[6] == 0x1a &&
      data[7] == 0x0a) {
    return true;
  }
  if (data[0] == 0x52 &&
      data[1] == 0x49 &&
      data[2] == 0x46 &&
      data[3] == 0x46 &&
      data[8] == 0x57 &&
      data[9] == 0x45 &&
      data[10] == 0x42 &&
      data[11] == 0x50) {
    return true;
  }
  if (data[0] == 0x47 &&
      data[1] == 0x49 &&
      data[2] == 0x46 &&
      data[3] == 0x38) {
    return true;
  }
  if (data[0] == 0x42 && data[1] == 0x4d) {
    return true;
  }
  return false;
}

typedef TrashPath = Future<void> Function(String path);
typedef InternetLyricsResolver = Future<String> Function(LibrarySong song);
typedef ShellThumbnailResolver =
    Future<ShellThumbnail?> Function(String filePath);

class ShellThumbnail {
  const ShellThumbnail({required this.data, required this.extension});

  final List<int> data;
  final String extension;
}

const _recentRecordTypeSong = 0;
const _recentRecordTypePlaylist = 3;
const _recentRecordTypeAlbum = 4;
const _recentRecordTypeArtist = 5;
const _nowPlayingPlaylistName = 'Now Playing';
const _id3TagService = Id3TagService();

class LocalSongMove {
  const LocalSongMove({
    required this.id,
    required this.oldPath,
    required this.newPath,
  });

  final int id;
  final String oldPath;
  final String newPath;
}

class LocalFolderMove {
  const LocalFolderMove({required this.oldPath, required this.newPath});

  final String oldPath;
  final String newPath;
}

class _LocalFileMove {
  const _LocalFileMove({
    required this.oldPath,
    required this.newPath,
    this.replacedPath,
  });

  final String oldPath;
  final String newPath;
  final String? replacedPath;
}

class _LocalResolvedFileMoveTarget {
  const _LocalResolvedFileMoveTarget({required this.path, this.replacedPath});

  final String path;
  final String? replacedPath;
}

enum LocalMoveConflictResolution { replace, keepBoth, skip }

typedef LocalMoveConflictResolver =
    Future<LocalMoveConflictResolution> Function(
      String sourcePath,
      String targetPath,
    );

class LocalItemsMoveResult {
  const LocalItemsMoveResult({
    required this.songs,
    required this.folders,
    this.inactiveFolders = const [],
  });

  final List<LocalSongMove> songs;
  final List<LocalFolderMove> folders;
  final List<String> inactiveFolders;

  int get itemCount => songs.length + folders.length;
}

File? selectWindowsUwpDatabaseCandidate(List<File> candidates) {
  if (candidates.isEmpty) {
    return null;
  }

  final scoredCandidates =
      candidates.map(_scoreWindowsUwpDatabaseCandidate).toList();
  scoredCandidates.sort((left, right) {
    final existingSampleComparison = right.existingSampleCount.compareTo(
      left.existingSampleCount,
    );
    if (existingSampleComparison != 0) {
      return existingSampleComparison;
    }

    return right.updatedAt.compareTo(left.updatedAt);
  });
  return scoredCandidates.first.file;
}

Future<void> trashPathIfExists(String targetPath) async {
  final type = FileSystemEntity.typeSync(targetPath);
  if (type == FileSystemEntityType.notFound) {
    return;
  }
  if (Platform.isMacOS) {
    await _runTrashCommand('osascript', [
      '-e',
      'tell application "Finder" to delete POSIX file ${_appleScriptString(targetPath)}',
    ], targetPath: targetPath);
    return;
  }
  if (Platform.isWindows) {
    final command =
        type == FileSystemEntityType.directory
            ? 'Add-Type -AssemblyName Microsoft.VisualBasic; '
                '[Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory(${_powerShellString(targetPath)}, '
                "'OnlyErrorDialogs', 'SendToRecycleBin')"
            : 'Add-Type -AssemblyName Microsoft.VisualBasic; '
                '[Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile(${_powerShellString(targetPath)}, '
                "'OnlyErrorDialogs', 'SendToRecycleBin')";
    await _runTrashCommand('powershell.exe', [
      '-NoProfile',
      '-ExecutionPolicy',
      'Bypass',
      '-Command',
      command,
    ], targetPath: targetPath);
    return;
  }
  if (Platform.isLinux) {
    await _runTrashCommand('gio', [
      'trash',
      targetPath,
    ], targetPath: targetPath);
    return;
  }

  if (type == FileSystemEntityType.directory) {
    await Directory(targetPath).delete(recursive: true);
  } else if (type == FileSystemEntityType.file) {
    await File(targetPath).delete();
  }
}

Future<ShellThumbnail?> resolveShellThumbnail(String filePath) async {
  if (Platform.isMacOS) {
    return _resolveMacQuickLookThumbnail(filePath);
  }
  return null;
}

Future<ShellThumbnail?> _resolveMacQuickLookThumbnail(String filePath) async {
  final thumbnailDirectory = await Directory.systemTemp.createTemp(
    'smplayer-shell-thumbnail-',
  );
  try {
    final result = await Process.run('qlmanage', [
      '-t',
      '-s',
      '512',
      '-o',
      thumbnailDirectory.path,
      filePath,
    ]);
    if (result.exitCode != 0) {
      return null;
    }
    for (final entity in thumbnailDirectory.listSync()) {
      if (entity is! File) {
        continue;
      }
      final data = await entity.readAsBytes();
      if (_isLikelyArtworkImage(data)) {
        return ShellThumbnail(data: data, extension: p.extension(entity.path));
      }
    }
    return null;
  } finally {
    if (thumbnailDirectory.existsSync()) {
      await thumbnailDirectory.delete(recursive: true);
    }
  }
}

Future<void> _runTrashCommand(
  String executable,
  List<String> arguments, {
  required String targetPath,
}) async {
  final result = await Process.run(executable, arguments);
  if (result.exitCode != 0) {
    throw FileSystemException(
      'Failed to move item to system trash',
      targetPath,
      OSError('${result.stderr}', result.exitCode),
    );
  }
}

String _appleScriptString(String value) {
  return '"${value.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';
}

String _powerShellString(String value) {
  return "'${value.replaceAll("'", "''")}'";
}

class LibraryRepository {
  const LibraryRepository({
    Future<File> Function()? databaseFileResolver,
    File Function()? nowPlayingFileResolver,
    Future<File> Function()? pendingDeleteFileResolver,
    TrashPath? trashPath,
    InternetLyricsResolver? internetLyricsResolver,
    ShellThumbnailResolver? shellThumbnailResolver,
  }) : _databaseFileResolver = databaseFileResolver,
       _nowPlayingFileResolver = nowPlayingFileResolver,
       _pendingDeleteFileResolver = pendingDeleteFileResolver,
       _trashPath = trashPath ?? trashPathIfExists,
       _internetLyricsResolver = internetLyricsResolver,
       _shellThumbnailResolver =
           shellThumbnailResolver ?? resolveShellThumbnail;

  final Future<File> Function()? _databaseFileResolver;
  final File Function()? _nowPlayingFileResolver;
  final Future<File> Function()? _pendingDeleteFileResolver;
  final TrashPath _trashPath;
  final InternetLyricsResolver? _internetLyricsResolver;
  final ShellThumbnailResolver _shellThumbnailResolver;

  Future<MusicLibrarySnapshot> getMusicLibrarySnapshot() async {
    final databaseFile = await _resolveDatabaseFile();
    if (!databaseFile.existsSync()) {
      return const MusicLibrarySnapshot(
        songs: [],
        recentSongs: [],
        recentPlaylists: [],
        recentAlbums: [],
        recentArtists: [],
        recentSearches: [],
        playlists: [],
        folders: [],
        favoritePlaylistId: 0,
        nowPlaying: NowPlayingSnapshot(playlistId: 0, songIds: []),
        hasLibrary: false,
        sortCriterion: MusicLibrarySortCriterion.title,
        albumsSort: AlbumSortCriterion.defaultSort,
        showCount: true,
        hideMultiSelectCommandBarAfterOperation: true,
        localViewMode: settings.LocalViewMode.grid,
        rootPath: '',
        databasePath: '',
      );
    }

    final db = sqlite3.open(databaseFile.path);
    try {
      _cleanupInvalidPlaylistItems(db);
      _cleanupInvalidRecentPlayed(db);
      final settings = _readLibrarySettings(db);
      final songs = _readSongs(db);
      final folders = _readFolders(db);
      final playlists = _readPlaylists(db, settings);
      final recentSongs = _readRecentSongs(db, songs);
      final nowPlaying = _readNowPlaying(db, songs, settings.nowPlayingId);
      return MusicLibrarySnapshot(
        songs: songs,
        recentSongs: recentSongs,
        recentPlaylists: _readRecentPlaylists(db),
        recentAlbums: _readRecentAlbums(db),
        recentArtists: _readRecentArtists(db),
        recentSearches: _readRecentSearches(db),
        playlists: playlists,
        folders: folders,
        favoritePlaylistId: settings.myFavoritesId,
        nowPlaying: nowPlaying,
        hasLibrary: songs.isNotEmpty,
        sortCriterion: settings.sortCriterion,
        albumsSort: settings.albumsSort,
        showCount: settings.showCount,
        hideMultiSelectCommandBarAfterOperation:
            settings.hideMultiSelectCommandBarAfterOperation,
        localViewMode: settings.localViewMode,
        rootPath: settings.rootPath,
        databasePath: databaseFile.path,
      );
    } finally {
      db.dispose();
    }
  }

  Future<bool> shouldCheckStartupArtistSplits() async {
    final databaseFile = await _resolveDatabaseFile();
    if (!databaseFile.existsSync()) {
      return false;
    }

    final db = sqlite3.open(databaseFile.path);
    try {
      final shouldCheck =
          _tableExists(db, 'Music') &&
          _tableHasRows(db, 'Music') &&
          !_tableExists(db, 'MusicArtist');
      if (shouldCheck) {
        _createMusicArtistTable(db);
      }
      return shouldCheck;
    } finally {
      db.dispose();
    }
  }

  Future<bool> exportDataTo(String targetPath) async {
    final databaseFile = await _resolveDatabaseFile();
    if (!databaseFile.existsSync()) {
      return false;
    }

    final target = File(targetPath);
    await target.parent.create(recursive: true);
    await databaseFile.copy(target.path);
    return true;
  }

  Future<bool> importDataFrom(String sourcePath) async {
    final source = File(sourcePath);
    if (!source.existsSync()) {
      return false;
    }

    final databaseFile = await _resolveDatabaseFile();
    await databaseFile.parent.create(recursive: true);
    final backupFile = File('${databaseFile.path}.import-backup');
    final hadExistingDatabase = databaseFile.existsSync();
    final currentRootPath =
        hadExistingDatabase ? _readDatabaseRootPath(databaseFile) : '';
    if (hadExistingDatabase) {
      await databaseFile.copy(backupFile.path);
    }

    try {
      await source.copy(databaseFile.path);
      final importedRootPath = _readDatabaseRootPath(databaseFile);
      if (currentRootPath.isNotEmpty &&
          importedRootPath.isNotEmpty &&
          currentRootPath != importedRootPath) {
        _replaceRootPathReferences(
          databaseFile,
          originalPath: importedRootPath,
          nextPath: currentRootPath,
        );
      } else if (importedRootPath.isNotEmpty) {
        await scanAllMusicLibrary(importedRootPath);
      }
      return true;
    } catch (_) {
      if (hadExistingDatabase) {
        await backupFile.copy(databaseFile.path);
      } else if (databaseFile.existsSync()) {
        await databaseFile.delete();
      }
      rethrow;
    } finally {
      if (backupFile.existsSync()) {
        await backupFile.delete();
      }
    }
  }

  Future<settings.SettingsSnapshot?> getSettingsSnapshot() async {
    final databaseFile = await _resolveDatabaseFile();
    if (!databaseFile.existsSync()) {
      return null;
    }

    final db = sqlite3.open(databaseFile.path);
    try {
      _cleanupInvalidLastPlaylist(db);
      final rows = db.select('SELECT * FROM Settings ORDER BY Id DESC LIMIT 1');
      if (rows.isEmpty) {
        return null;
      }
      return _settingsSnapshotFromRow(rows.single);
    } finally {
      db.dispose();
    }
  }

  Future<void> updateSettings(settings.AppSettingsUpdate update) async {
    final databaseFile = await _resolveDatabaseFile();
    if (!databaseFile.existsSync()) {
      return;
    }

    final db = sqlite3.open(databaseFile.path);
    try {
      final snapshot = _settingsSnapshotFromRow(
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
    settings.PlaybackSettingsUpdate update,
  ) async {
    final databaseFile = await _resolveDatabaseFile();
    if (!databaseFile.existsSync()) {
      return;
    }

    final db = sqlite3.open(databaseFile.path);
    try {
      final snapshot = _settingsSnapshotFromRow(
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

  Future<void> updateSongDuration(int songId, int durationSeconds) async {
    final databaseFile = await _resolveDatabaseFile();
    if (!databaseFile.existsSync()) {
      return;
    }

    final db = sqlite3.open(databaseFile.path);
    try {
      db.execute(
        '''
        UPDATE Music
        SET Duration = ?
        WHERE Id = ?
          AND State = ?
      ''',
        [durationSeconds, songId, _activeState],
      );
    } finally {
      db.dispose();
    }
  }

  Future<void> saveViewState({String? lastPage, int? lastPlaylistId}) async {
    final databaseFile = await _resolveDatabaseFile();
    if (!databaseFile.existsSync()) {
      return;
    }

    final db = sqlite3.open(databaseFile.path);
    try {
      final snapshot = _settingsSnapshotFromRow(
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

  Future<void> replaceNowPlaying(List<int> songIds) async {
    final databaseFile = await _resolveDatabaseFile();
    if (!databaseFile.existsSync()) {
      return;
    }

    final db = sqlite3.open(databaseFile.path);
    try {
      _writeNowPlayingSongIds(db, songIds);
    } finally {
      db.dispose();
    }
  }

  Future<void> clearNowPlaying() async {
    await replaceNowPlaying([]);
  }

  Future<void> removeSongFromNowPlaying(int songId) async {
    final databaseFile = await _resolveDatabaseFile();
    if (!databaseFile.existsSync()) {
      return;
    }

    final db = sqlite3.open(databaseFile.path);
    try {
      final nextSongIds =
          _readNowPlayingSongIdsByPath(
            db,
          ).where((queuedSongId) => queuedSongId != songId).toList();
      _writeNowPlayingSongIds(db, nextSongIds);
    } finally {
      db.dispose();
    }
  }

  Future<void> removeRecentPlayed(List<int> songIds) async {
    if (songIds.isEmpty) {
      return;
    }

    final databaseFile = await _resolveDatabaseFile();
    if (!databaseFile.existsSync()) {
      return;
    }

    final placeholders = List.filled(songIds.length, '?').join(', ');
    final db = sqlite3.open(databaseFile.path);
    try {
      db.execute(
        '''
        UPDATE RecentRecord
        SET State = ?
        WHERE Type = $_recentRecordTypeSong
          AND ItemId IN ($placeholders)
      ''',
        [_inactiveState, ...songIds.map((songId) => songId.toString())],
      );
    } finally {
      db.dispose();
    }
  }

  Future<void> clearRecentPlayed() async {
    final databaseFile = await _resolveDatabaseFile();
    if (!databaseFile.existsSync()) {
      return;
    }

    final db = sqlite3.open(databaseFile.path);
    try {
      db.execute(
        '''
        UPDATE RecentRecord
        SET State = ?
        WHERE Type IN (
          $_recentRecordTypeSong,
          $_recentRecordTypePlaylist,
          $_recentRecordTypeAlbum,
          $_recentRecordTypeArtist
        )
      ''',
        [_inactiveState],
      );
    } finally {
      db.dispose();
    }
  }

  void _cleanupInvalidRecentPlayed(Database db) {
    db.execute(
      '''
      UPDATE RecentRecord
      SET State = ?
      WHERE Type = $_recentRecordTypeSong
        AND State = ?
        AND NOT EXISTS (
          SELECT 1
          FROM Music
          WHERE Music.Id = CAST(RecentRecord.ItemId AS INTEGER)
            AND Music.State = ?
        )
    ''',
      [_inactiveState, _activeState, _activeState],
    );
  }

  void _cleanupInvalidPlaylistItems(Database db) {
    db.execute(
      '''
      UPDATE PlaylistItem
      SET State = ?
      WHERE State = ?
        AND (
          NOT EXISTS (
            SELECT 1
            FROM Playlist
            WHERE Playlist.Id = PlaylistItem.PlaylistId
              AND Playlist.State = ?
          )
          OR NOT EXISTS (
            SELECT 1
            FROM Music
            WHERE Music.Id = PlaylistItem.ItemId
              AND Music.State = ?
          )
        )
    ''',
      [_inactiveState, _activeState, _activeState, _activeState],
    );
  }

  void _cleanupInvalidLastPlaylist(Database db) {
    if (!_tableExists(db, 'Playlist')) {
      return;
    }
    db.execute(
      '''
      UPDATE Settings
      SET LastPlaylist = MyFavorites
      WHERE LastPlaylist > 0
        AND NOT EXISTS (
          SELECT 1
          FROM Playlist
          WHERE Playlist.Id = Settings.LastPlaylist
            AND Playlist.State = ?
        )
    ''',
      [_activeState],
    );
  }

  Future<void> removeRecentSearches(List<int> entryIds) async {
    if (entryIds.isEmpty) {
      return;
    }

    final databaseFile = await _resolveDatabaseFile();
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

  Future<void> restoreRecentSearches(List<SearchHistoryEntry> entries) async {
    if (entries.isEmpty) {
      return;
    }

    final databaseFile = await _resolveDatabaseFile();
    if (!databaseFile.existsSync()) {
      return;
    }

    final db = sqlite3.open(databaseFile.path);
    try {
      db.execute('BEGIN');
      try {
        final statement = db.prepare('''
          INSERT INTO SearchHistory (Id, Query, Type, SearchedAt)
          VALUES (?, ?, ?, ?)
        ''');
        try {
          for (final entry in entries) {
            final storedType = _toStoredSearchHistoryType(entry.type);
            db.execute(
              'DELETE FROM SearchHistory WHERE Query = ? AND Type = ?',
              [entry.query, storedType],
            );
            statement.execute([
              entry.id,
              entry.query,
              storedType,
              entry.searchedAt,
            ]);
          }
        } finally {
          statement.dispose();
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

  Future<void> restoreRecentPlayed(List<int> songIds) async {
    if (songIds.isEmpty) {
      return;
    }

    final databaseFile = await _resolveDatabaseFile();
    if (!databaseFile.existsSync()) {
      return;
    }

    final placeholders = List.filled(songIds.length, '?').join(', ');
    final db = sqlite3.open(databaseFile.path);
    try {
      db.execute(
        '''
        UPDATE RecentRecord
        SET State = ?
        WHERE Type = $_recentRecordTypeSong
          AND ItemId IN ($placeholders)
      ''',
        [_activeState, ...songIds.map((songId) => songId.toString())],
      );
    } finally {
      db.dispose();
    }
  }

  Future<void> clearRecentSearches() async {
    final databaseFile = await _resolveDatabaseFile();
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

  Future<PendingSongDelete> beginDeleteSongFromDisk(int songId) async {
    final databaseFile = await _resolveDatabaseFile();
    final db = sqlite3.open(databaseFile.path);
    final pendingFile = await _resolvePendingSongDeletesFile();
    try {
      final songPath = _readActiveSongPath(db, songId);
      final record = _PendingSongDeleteRecord(
        id: 'delete-${DateTime.now().microsecondsSinceEpoch}-$songId',
        songId: songId,
        songPath: songPath,
        musicArtistIds: _readActiveRowIds(db, 'MusicArtist', 'MusicId', songId),
        playlistItemIds: _readActiveRowIds(
          db,
          'PlaylistItem',
          'ItemId',
          songId,
        ),
        recentRecordIds: _readActiveRecentSongRowIds(db, songId),
        hiddenStorageItemIds: _readActiveHiddenFileRowIds(db, songPath),
      );
      final records = await _readPendingDeleteRecords(pendingFile);
      await _writePendingDeleteRecords(pendingFile, [record, ...records]);

      db.execute('BEGIN');
      try {
        _deleteSongsInsideTransaction(db, [songId], [songPath]);
        db.execute('COMMIT');
      } on Object {
        db.execute('ROLLBACK');
        final currentRecords = await _readPendingDeleteRecords(pendingFile);
        await _writePendingDeleteRecords(
          pendingFile,
          currentRecords.where((item) => item.id != record.id).toList(),
        );
        rethrow;
      }
      return PendingSongDelete(id: record.id, songId: songId);
    } finally {
      db.dispose();
    }
  }

  Future<void> undoDeleteSongFromDisk(String deleteId) async {
    final databaseFile = await _resolveDatabaseFile();
    final pendingFile = await _resolvePendingSongDeletesFile();
    final records = await _readPendingDeleteRecords(pendingFile);
    final record = records.whereType<_PendingSongDeleteRecord>().firstWhere(
      (item) => item.id == deleteId,
    );
    final db = sqlite3.open(databaseFile.path);
    try {
      db.execute('BEGIN');
      try {
        _restoreDeletedSongInsideTransaction(db, record);
        db.execute('COMMIT');
      } on Object {
        db.execute('ROLLBACK');
        rethrow;
      }
    } finally {
      db.dispose();
    }
    await _writePendingDeleteRecords(
      pendingFile,
      records.where((item) => item.id != deleteId).toList(),
    );
  }

  Future<void> commitDeleteSongFromDisk(String deleteId) async {
    final pendingFile = await _resolvePendingSongDeletesFile();
    final records = await _readPendingDeleteRecords(pendingFile);
    final record = records.whereType<_PendingSongDeleteRecord>().firstWhere(
      (item) => item.id == deleteId,
    );
    await _trashPath(record.songPath);
    await _writePendingDeleteRecords(
      pendingFile,
      records.where((item) => item.id != deleteId).toList(),
    );
  }

  Future<void> commitPendingDeletes() async {
    final pendingFile = await _resolvePendingSongDeletesFile();
    if (!pendingFile.existsSync()) {
      return;
    }

    final records = await _readPendingDeleteRecords(pendingFile);
    for (final record in records) {
      await _trashPendingDeleteRecord(record);
    }
    await _writePendingDeleteRecords(pendingFile, const []);
  }

  Future<void> hideSong(int songId) async {
    final databaseFile = await _resolveDatabaseFile();
    final db = sqlite3.open(databaseFile.path);
    try {
      final songPath = _readActiveSongPath(db, songId);
      db.execute('BEGIN');
      try {
        db.execute('UPDATE Music SET State = ? WHERE Id = ?', [
          _hiddenState,
          songId,
        ]);
        db.execute('UPDATE File SET State = ? WHERE Path = ?', [
          _hiddenState,
          songPath,
        ]);
        _upsertHiddenStorageItem(db, 'file', songPath);
        db.execute('COMMIT');
      } on Object {
        db.execute('ROLLBACK');
        rethrow;
      }
    } finally {
      db.dispose();
    }
  }

  Future<LocalItemsMoveResult> moveSongToFolder(
    int songId,
    String folderPath, {
    LocalMoveConflictResolver? resolveConflict,
  }) async {
    final databaseFile = await _resolveDatabaseFile();
    final db = sqlite3.open(databaseFile.path);
    try {
      final songPath = _readActiveSongPath(db, songId);
      if (_getFileParentPath(songPath) == folderPath) {
        return const LocalItemsMoveResult(songs: [], folders: []);
      }

      final targetDirectory = Directory(folderPath);
      if (targetDirectory.statSync().type != FileSystemEntityType.directory) {
        throw StateError('Target path is not a folder.');
      }

      final target = await _resolveLocalFileMoveTarget(
        sourcePath: songPath,
        targetFolderPath: folderPath,
        resolveConflict: resolveConflict,
      );
      if (target == null) {
        return const LocalItemsMoveResult(songs: [], folders: []);
      }

      await File(songPath).rename(target.path);
      db.execute('BEGIN');
      try {
        final folderId = _readActiveFolderId(db, folderPath) ?? 0;
        if (target.replacedPath != null) {
          _markLocalFilePathInactiveInsideTransaction(
            db,
            target.replacedPath!,
            exceptSongId: songId,
          );
        }
        db.execute(
          '''
          UPDATE Music
          SET Path = ?
          WHERE Id = ?
            AND State = ?
        ''',
          [target.path, songId, _activeState],
        );
        db.execute(
          '''
          UPDATE File
          SET Path = ?, ParentId = ?
          WHERE Path = ?
        ''',
          [target.path, folderId, songPath],
        );
        db.execute('COMMIT');
      } on Object {
        db.execute('ROLLBACK');
        rethrow;
      }
      return LocalItemsMoveResult(
        songs: [
          LocalSongMove(id: songId, oldPath: songPath, newPath: target.path),
        ],
        folders: const [],
      );
    } finally {
      db.dispose();
    }
  }

  Future<LocalItemsMoveResult> moveLocalItemsToFolder(
    List<int> songIds,
    List<String> folderPaths,
    String targetFolderPath, {
    LocalMoveConflictResolver? resolveConflict,
  }) async {
    if (songIds.isEmpty && folderPaths.isEmpty) {
      return const LocalItemsMoveResult(songs: [], folders: []);
    }

    final databaseFile = await _resolveDatabaseFile();
    final db = sqlite3.open(databaseFile.path);
    try {
      final targetDirectory = Directory(targetFolderPath);
      if (targetDirectory.statSync().type != FileSystemEntityType.directory) {
        throw StateError('Target path is not a folder.');
      }

      final movedSongs = <LocalSongMove>[];
      final movedFiles = <_LocalFileMove>[];
      if (songIds.isNotEmpty) {
        final placeholders = List.filled(songIds.length, '?').join(', ');
        final rows = db.select(
          '''
          SELECT Id AS id, Path AS path
          FROM Music
          WHERE Id IN ($placeholders)
            AND State = ?
        ''',
          [...songIds, _activeState],
        );
        for (final row in rows) {
          final songPath = row['path'] as String;
          if (_getFileParentPath(songPath) == targetFolderPath) {
            continue;
          }
          final target = await _resolveLocalFileMoveTarget(
            sourcePath: songPath,
            targetFolderPath: targetFolderPath,
            resolveConflict: resolveConflict,
          );
          if (target == null) {
            continue;
          }
          await File(songPath).rename(target.path);
          movedFiles.add(
            _LocalFileMove(
              oldPath: songPath,
              newPath: target.path,
              replacedPath: target.replacedPath,
            ),
          );
          movedSongs.add(
            LocalSongMove(
              id: row['id'] as int,
              oldPath: songPath,
              newPath: target.path,
            ),
          );
        }
      }

      final movedFolders = <LocalFolderMove>[];
      final inactiveFolders = <String>[];
      for (final folderPath in folderPaths) {
        if (folderPath == targetFolderPath ||
            targetFolderPath.startsWith('$folderPath/') ||
            targetFolderPath.startsWith('$folderPath\\')) {
          continue;
        }
        var targetPath = p.join(targetFolderPath, p.basename(folderPath));
        if (folderPath == targetPath) {
          continue;
        }
        final targetType = FileSystemEntity.typeSync(targetPath);
        if (targetType == FileSystemEntityType.notFound) {
          await Directory(folderPath).rename(targetPath);
          movedFolders.add(
            LocalFolderMove(oldPath: folderPath, newPath: targetPath),
          );
          continue;
        }

        if (targetType != FileSystemEntityType.directory) {
          throw StateError('Target path already exists and is not a folder.');
        }
        await _mergeLocalFolderIntoExistingTarget(
          sourceFolderPath: folderPath,
          targetFolderPath: targetPath,
          movedFiles: movedFiles,
          movedFolders: movedFolders,
          inactiveFolders: inactiveFolders,
          resolveConflict: resolveConflict,
        );
      }

      db.execute('BEGIN');
      try {
        for (final movedFile in movedFiles) {
          final targetFolderId =
              _readActiveFolderId(db, p.dirname(movedFile.newPath)) ?? 0;
          final sourceSongRows = db.select(
            '''
            SELECT Id AS id
            FROM Music
            WHERE Path = ?
              AND State = ?
            LIMIT 1
          ''',
            [movedFile.oldPath, _activeState],
          );
          final sourceSongId =
              sourceSongRows.isEmpty ? null : sourceSongRows.first['id'] as int;
          if (movedFile.replacedPath != null) {
            _markLocalFilePathInactiveInsideTransaction(
              db,
              movedFile.replacedPath!,
              exceptSongId: sourceSongId,
            );
          }
          if (sourceSongId != null) {
            if (!movedSongs.any((move) => move.id == sourceSongId)) {
              movedSongs.add(
                LocalSongMove(
                  id: sourceSongId,
                  oldPath: movedFile.oldPath,
                  newPath: movedFile.newPath,
                ),
              );
            }
            db.execute(
              '''
              UPDATE Music
              SET Path = ?
              WHERE Id = ?
                AND State = ?
            ''',
              [movedFile.newPath, sourceSongId, _activeState],
            );
          }
          db.execute(
            '''
            UPDATE File
            SET Path = ?, ParentId = ?
            WHERE Path = ?
          ''',
            [movedFile.newPath, targetFolderId, movedFile.oldPath],
          );
        }

        for (final movedFolder in movedFolders) {
          _updatePathPrefixInsideTransaction(
            db,
            table: 'Music',
            oldPath: movedFolder.oldPath,
            newPath: movedFolder.newPath,
          );
          _updatePathPrefixInsideTransaction(
            db,
            table: 'File',
            oldPath: movedFolder.oldPath,
            newPath: movedFolder.newPath,
          );
          _updatePathPrefixInsideTransaction(
            db,
            table: 'Folder',
            oldPath: movedFolder.oldPath,
            newPath: movedFolder.newPath,
          );
          final parentFolderId =
              _readActiveFolderId(db, p.dirname(movedFolder.newPath)) ?? 0;
          db.execute(
            '''
            UPDATE Folder
            SET ParentId = ?
            WHERE Path = ?
              AND State = ?
          ''',
            [parentFolderId, movedFolder.newPath, _activeState],
          );
        }
        for (final inactiveFolder in inactiveFolders) {
          _markLocalFolderInactiveInsideTransaction(db, inactiveFolder);
        }
        db.execute('COMMIT');
      } on Object {
        db.execute('ROLLBACK');
        rethrow;
      }
      return LocalItemsMoveResult(
        songs: movedSongs,
        folders: movedFolders,
        inactiveFolders: inactiveFolders,
      );
    } finally {
      db.dispose();
    }
  }

  Future<void> undoMoveLocalItems(LocalItemsMoveResult result) async {
    final databaseFile = await _resolveDatabaseFile();
    final db = sqlite3.open(databaseFile.path);
    try {
      for (final movedFolder in result.folders.reversed) {
        Directory(p.dirname(movedFolder.oldPath)).createSync(recursive: true);
        await Directory(movedFolder.newPath).rename(movedFolder.oldPath);
      }
      for (final movedSong in result.songs) {
        Directory(p.dirname(movedSong.oldPath)).createSync(recursive: true);
        await File(movedSong.newPath).rename(movedSong.oldPath);
      }

      db.execute('BEGIN');
      try {
        for (final inactiveFolder in result.inactiveFolders) {
          db.execute(
            '''
            UPDATE Folder
            SET State = ?
            WHERE Path = ?
          ''',
            [_activeState, inactiveFolder],
          );
          db.execute(
            '''
            UPDATE HiddenStorageItem
            SET State = ?
            WHERE Type = 'folder'
              AND Path = ?
          ''',
            [_inactiveState, inactiveFolder],
          );
        }
        for (final movedSong in result.songs) {
          final parentFolderId =
              _readActiveFolderId(db, _getFileParentPath(movedSong.oldPath)) ??
              0;
          db.execute(
            '''
            UPDATE Music
            SET Path = ?
            WHERE Id = ?
          ''',
            [movedSong.oldPath, movedSong.id],
          );
          db.execute(
            '''
            UPDATE File
            SET Path = ?, ParentId = ?
            WHERE Path = ?
          ''',
            [movedSong.oldPath, parentFolderId, movedSong.newPath],
          );
        }

        for (final movedFolder in result.folders.reversed) {
          _updatePathPrefixInsideTransaction(
            db,
            table: 'Music',
            oldPath: movedFolder.newPath,
            newPath: movedFolder.oldPath,
          );
          _updatePathPrefixInsideTransaction(
            db,
            table: 'File',
            oldPath: movedFolder.newPath,
            newPath: movedFolder.oldPath,
          );
          _updatePathPrefixInsideTransaction(
            db,
            table: 'Folder',
            oldPath: movedFolder.newPath,
            newPath: movedFolder.oldPath,
          );
          final parentFolderId =
              _readActiveFolderId(
                db,
                _getFileParentPath(movedFolder.oldPath),
              ) ??
              0;
          db.execute(
            '''
            UPDATE Folder
            SET ParentId = ?
            WHERE Path = ?
          ''',
            [parentFolderId, movedFolder.oldPath],
          );
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

  Future<PendingLocalItemsDelete> beginDeleteLocalItems(
    List<int> songIds,
    List<String> folderPaths,
  ) async {
    if (songIds.isEmpty && folderPaths.isEmpty) {
      return const PendingLocalItemsDelete(
        id: '',
        songIds: [],
        folderPaths: [],
      );
    }

    final databaseFile = await _resolveDatabaseFile();
    final pendingFile = await _resolvePendingSongDeletesFile();
    final db = sqlite3.open(databaseFile.path);
    try {
      final songRows = _readActiveSongsForLocalItems(db, songIds, folderPaths);
      final effectiveSongIds = songRows.map((row) => row.id).toList();
      final targetPaths = [
        ...songRows
            .map((row) => row.path)
            .where(
              (songPath) =>
                  !folderPaths.any(
                    (folderPath) => _isPathInsideFolder(songPath, folderPath),
                  ),
            ),
        ...folderPaths,
      ];
      final record = _PendingLocalItemsDeleteRecord(
        id: 'delete-local-${DateTime.now().microsecondsSinceEpoch}',
        songIds: effectiveSongIds,
        folderPaths: folderPaths.toList(),
        targetPaths: targetPaths,
        musicIds: effectiveSongIds,
        musicArtistIds: _readActiveRowsForSongIds(
          db,
          'MusicArtist',
          'MusicId',
          effectiveSongIds,
        ),
        playlistItemIds: _readActiveRowsForSongIds(
          db,
          'PlaylistItem',
          'ItemId',
          effectiveSongIds,
        ),
        recentRecordIds: _readActiveRecentSongRowsForSongIds(
          db,
          effectiveSongIds,
        ),
        hiddenStorageItemIds: [
          ..._readActiveHiddenFileRowsForPaths(
            db,
            songRows.map((row) => row.path).toList(),
          ),
          ..._readActiveHiddenFolderRowsForPaths(db, folderPaths),
        ],
        folderIds: _readActiveFolderRowIdsForPaths(db, folderPaths),
        fileIds: _readActiveFileRowIdsForPaths(
          db,
          songRows.map((row) => row.path).toList(),
          folderPaths,
        ),
      );
      final records = await _readPendingDeleteRecords(pendingFile);
      await _writePendingDeleteRecords(pendingFile, [record, ...records]);

      db.execute('BEGIN');
      try {
        if (songRows.isNotEmpty) {
          _deleteSongsInsideTransaction(
            db,
            effectiveSongIds,
            songRows.map((row) => row.path).toList(),
          );
        }
        _updateFolderPathStateInsideTransaction(
          db,
          folderPaths,
          _inactiveState,
        );
        db.execute('COMMIT');
      } on Object {
        db.execute('ROLLBACK');
        final currentRecords = await _readPendingDeleteRecords(pendingFile);
        await _writePendingDeleteRecords(
          pendingFile,
          currentRecords.where((item) => item.id != record.id).toList(),
        );
        rethrow;
      }

      return PendingLocalItemsDelete(
        id: record.id,
        songIds: record.songIds,
        folderPaths: record.folderPaths,
      );
    } finally {
      db.dispose();
    }
  }

  Future<void> undoDeleteLocalItems(String deleteId) async {
    final databaseFile = await _resolveDatabaseFile();
    final pendingFile = await _resolvePendingSongDeletesFile();
    final records = await _readPendingDeleteRecords(pendingFile);
    final record = records
        .whereType<_PendingLocalItemsDeleteRecord>()
        .firstWhere((item) => item.id == deleteId);
    final db = sqlite3.open(databaseFile.path);
    try {
      db.execute('BEGIN');
      try {
        _restoreDeletedLocalItemsInsideTransaction(db, record);
        db.execute('COMMIT');
      } on Object {
        db.execute('ROLLBACK');
        rethrow;
      }
    } finally {
      db.dispose();
    }
    await _writePendingDeleteRecords(
      pendingFile,
      records.where((item) => item.id != deleteId).toList(),
    );
  }

  Future<void> commitDeleteLocalItems(String deleteId) async {
    final pendingFile = await _resolvePendingSongDeletesFile();
    final records = await _readPendingDeleteRecords(pendingFile);
    final record = records
        .whereType<_PendingLocalItemsDeleteRecord>()
        .firstWhere((item) => item.id == deleteId);
    await _trashPendingDeleteRecord(record);
    await _writePendingDeleteRecords(
      pendingFile,
      records.where((item) => item.id != deleteId).toList(),
    );
  }

  Future<void> hideFolder(String folderPath) async {
    final databaseFile = await _resolveDatabaseFile();
    final db = sqlite3.open(databaseFile.path);
    try {
      db.execute('BEGIN');
      try {
        _hideFolderPathStateInsideTransaction(db, folderPath);
        _upsertHiddenStorageItem(db, 'folder', folderPath);
        db.execute('COMMIT');
      } on Object {
        db.execute('ROLLBACK');
        rethrow;
      }
    } finally {
      db.dispose();
    }
  }

  Future<void> unhideSong(int songId) async {
    final databaseFile = await _resolveDatabaseFile();
    final db = sqlite3.open(databaseFile.path);
    try {
      final songPath = _readSongPath(db, songId);
      db.execute('BEGIN');
      try {
        db.execute('UPDATE Music SET State = ? WHERE Id = ?', [
          _activeState,
          songId,
        ]);
        db.execute('UPDATE File SET State = ? WHERE Path = ?', [
          _activeState,
          songPath,
        ]);
        db.execute(
          '''
          UPDATE HiddenStorageItem
          SET State = ?
          WHERE Type = ?
            AND Path = ?
        ''',
          [_inactiveState, 'file', songPath],
        );
        db.execute('COMMIT');
      } on Object {
        db.execute('ROLLBACK');
        rethrow;
      }
    } finally {
      db.dispose();
    }
  }

  Future<void> unhideFolder(String folderPath) async {
    final databaseFile = await _resolveDatabaseFile();
    final db = sqlite3.open(databaseFile.path);
    try {
      db.execute('BEGIN');
      try {
        _updateFolderPathStateInsideTransaction(db, [folderPath], _activeState);
        db.execute(
          '''
          UPDATE HiddenStorageItem
          SET State = ?
          WHERE Type = ?
            AND Path = ?
        ''',
          [_inactiveState, 'folder', folderPath],
        );
        db.execute('COMMIT');
      } on Object {
        db.execute('ROLLBACK');
        rethrow;
      }
    } finally {
      db.dispose();
    }
  }

  Future<List<HiddenStorageItem>> getHiddenStorageItems() async {
    final databaseFile = await _resolveDatabaseFile();
    if (!databaseFile.existsSync()) {
      return const [];
    }

    final db = sqlite3.open(databaseFile.path);
    try {
      db.execute('BEGIN');
      try {
        _syncStorageStateFromHiddenItems(db);
        _syncHiddenItemsFromStorageState(db);
        db.execute('COMMIT');
      } on Object {
        db.execute('ROLLBACK');
        rethrow;
      }
      final rows = db.select(
        '''
        SELECT Id AS id, Type AS type, Path AS path
        FROM HiddenStorageItem
        WHERE State = ?
        ORDER BY Type, Path
      ''',
        [_activeState],
      );
      return [
        for (final row in rows)
          HiddenStorageItem(
            id: row['id'] as int,
            type: row['type'] as String,
            path: row['path'] as String,
          ),
      ];
    } finally {
      db.dispose();
    }
  }

  Future<void> resumeHiddenStorageItem(HiddenStorageItem item) async {
    final databaseFile = await _resolveDatabaseFile();
    final db = sqlite3.open(databaseFile.path);
    try {
      db.execute('BEGIN');
      try {
        if (item.type == 'folder') {
          _resumeHiddenFolderInsideTransaction(db, item.path);
        } else {
          db.execute('UPDATE Music SET State = ? WHERE Path = ?', [
            _activeState,
            item.path,
          ]);
          db.execute('UPDATE File SET State = ? WHERE Path = ?', [
            _activeState,
            item.path,
          ]);
        }
        db.execute(
          '''
          UPDATE HiddenStorageItem
          SET State = ?
          WHERE Type = ?
            AND Path = ?
        ''',
          [_inactiveState, item.type, item.path],
        );
        db.execute('COMMIT');
      } on Object {
        db.execute('ROLLBACK');
        rethrow;
      }
    } finally {
      db.dispose();
    }
  }

  Future<void> renameFolder(String folderPath, String name) async {
    final targetPath = p.join(p.dirname(folderPath), name);
    await Directory(folderPath).rename(targetPath);

    final databaseFile = await _resolveDatabaseFile();
    final db = sqlite3.open(databaseFile.path);
    try {
      db.execute('BEGIN');
      try {
        _updatePathPrefixInsideTransaction(
          db,
          table: 'Music',
          oldPath: folderPath,
          newPath: targetPath,
        );
        _updatePathPrefixInsideTransaction(
          db,
          table: 'File',
          oldPath: folderPath,
          newPath: targetPath,
        );
        _updatePathPrefixInsideTransaction(
          db,
          table: 'Folder',
          oldPath: folderPath,
          newPath: targetPath,
        );
        db.execute('COMMIT');
      } on Object {
        db.execute('ROLLBACK');
        rethrow;
      }
    } finally {
      db.dispose();
    }
  }

  Future<void> addRecentSearch(
    String query, [
    SearchHistoryType type = SearchHistoryType.sidebar,
  ]) async {
    final nextQuery = query.trim();
    if (nextQuery.isEmpty) {
      return;
    }

    final databaseFile = await _resolveDatabaseFile();
    if (!databaseFile.existsSync()) {
      return;
    }

    final db = sqlite3.open(databaseFile.path);
    try {
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
          [
            nextQuery,
            _toStoredSearchHistoryType(type),
            DateTime.now().toUtc().toIso8601String(),
          ],
        );
        db.execute('COMMIT');
      } on Object {
        db.execute('ROLLBACK');
        rethrow;
      }
    } finally {
      db.dispose();
    }
  }

  Future<void> updateMusicLibrarySort(
    MusicLibrarySortCriterion criterion,
  ) async {
    final databaseFile = await _resolveDatabaseFile();
    if (!databaseFile.existsSync()) {
      return;
    }

    final db = sqlite3.open(databaseFile.path);
    try {
      db.execute('UPDATE Settings SET MusicLibraryCriterion = ? WHERE Id = ?', [
        _toStoredSortCriterion(criterion),
        1,
      ]);
    } finally {
      db.dispose();
    }
  }

  Future<void> updateAlbumsSort(AlbumSortCriterion criterion) async {
    final databaseFile = await _resolveDatabaseFile();
    if (!databaseFile.existsSync()) {
      return;
    }

    final db = sqlite3.open(databaseFile.path);
    try {
      db.execute('UPDATE Settings SET AlbumsCriterion = ? WHERE Id = ?', [
        _toStoredAlbumSortCriterion(criterion),
        1,
      ]);
    } finally {
      db.dispose();
    }
  }

  Future<void> updateLocalFolderSort(
    String folderPath,
    LocalFolderSortCriterion criterion,
  ) async {
    final databaseFile = await _resolveDatabaseFile();
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
        [
          _toStoredLocalFolderSortCriterion(criterion),
          folderPath,
          _activeState,
        ],
      );
    } finally {
      db.dispose();
    }
  }

  Future<LibraryPlaylist> createPlaylist(
    String name, [
    List<int> songIds = const [],
  ]) async {
    final databaseFile = await _resolveDatabaseFile();
    final db = sqlite3.open(databaseFile.path);
    try {
      final settings = _readLibrarySettings(db);
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

  Future<void> deletePlaylist(int playlistId) async {
    final databaseFile = await _resolveDatabaseFile();
    if (!databaseFile.existsSync()) {
      return;
    }

    final db = sqlite3.open(databaseFile.path);
    try {
      final settings = _readLibrarySettings(db);
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

  Future<void> restorePlaylist(LibraryPlaylist playlist) async {
    final databaseFile = await _resolveDatabaseFile();
    if (!databaseFile.existsSync()) {
      return;
    }

    final db = sqlite3.open(databaseFile.path);
    try {
      final settings = _readLibrarySettings(db);
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

  Future<void> renamePlaylist(int playlistId, String name) async {
    final databaseFile = await _resolveDatabaseFile();
    if (!databaseFile.existsSync()) {
      return;
    }

    final db = sqlite3.open(databaseFile.path);
    try {
      final settings = _readLibrarySettings(db);
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

  Future<void> reorderPlaylists(List<int> playlistIds) async {
    final databaseFile = await _resolveDatabaseFile();
    if (!databaseFile.existsSync()) {
      return;
    }

    final db = sqlite3.open(databaseFile.path);
    try {
      final settings = _readLibrarySettings(db);
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

  Future<void> setSongFavorite(int songId, bool favorite) async {
    await setSongsFavorite([songId], favorite);
  }

  Future<ArtistSplitAnalysisResult> analyzeArtistSplits() async {
    final snapshot = await getMusicLibrarySnapshot();
    return artist_split_model.analyzeArtistSplits(snapshot.songs);
  }

  Future<void> applyArtistSplits(List<ArtistSplitResultItem> splits) async {
    if (splits.isEmpty) {
      return;
    }

    final databaseFile = await _resolveDatabaseFile();
    final db = sqlite3.open(databaseFile.path);
    try {
      db.execute('BEGIN');
      try {
        for (final split in splits) {
          final artists = _normalizeArtists(split.artists).take(6).toList();
          db.execute(
            '''
            UPDATE Music
            SET Artist = ?
            WHERE Id = ?
              AND State = ?
          ''',
            [artists.join(', '), split.songId, _activeState],
          );
          _syncSongArtists(db, split.songId, artists);
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

  Future<List<int>> importExternalAudioFiles(List<String> filePaths) async {
    final audioFiles =
        filePaths.where((filePath) {
          return _audioFileExtensions.contains(
                p.extension(filePath).toLowerCase(),
              ) &&
              File(filePath).existsSync();
        }).toList();
    if (audioFiles.isEmpty) {
      return const [];
    }
    final metadataByPath = await _readAudioFileMetadataBatch(audioFiles);

    final databaseFile = await _resolveDatabaseFile();
    final db = sqlite3.open(databaseFile.path);
    final openedSongIds = <int>[];
    try {
      final settings = _readLibrarySettings(db);
      db.execute('BEGIN');
      try {
        for (final filePath in audioFiles) {
          openedSongIds.add(
            _upsertExternalAudioFile(
              db,
              filePath,
              metadata: metadataByPath[filePath]!,
              useFilenameNotMusicName: settings.useFilenameNotMusicName,
            ),
          );
        }
        db.execute('COMMIT');
      } on Object {
        db.execute('ROLLBACK');
        rethrow;
      }
    } finally {
      db.dispose();
    }

    return openedSongIds;
  }

  Future<LocalFolderRefreshResult> scanAllMusicLibrary(
    String rootPath, {
    void Function(LocalFolderRefreshProgress progress)? onProgress,
    LocalFolderScanCancellation? cancellation,
  }) async {
    final rootDirectory = Directory(rootPath);
    if (!rootDirectory.existsSync()) {
      throw StateError('Folder not found: $rootPath');
    }

    final databaseFile = await _resolveDatabaseFile();
    final db = sqlite3.open(databaseFile.path);
    try {
      final settings = _readLibrarySettings(db);
      final hiddenPaths = _readActiveHiddenStoragePaths(db);
      final preparedFolderCount =
          _countScannableFolders(rootPath, hiddenPaths.folderPaths) + 1;
      var checkedFolderCount = 0;
      int folderProgressMax() => max(preparedFolderCount, checkedFolderCount);
      final scannedPaths = findScannableAudioFiles(
        rootPath,
        hiddenFolderPaths: hiddenPaths.folderPaths,
        hiddenFilePaths: hiddenPaths.filePaths,
        cancellation: cancellation,
        onFolder: (folderPath) {
          checkedFolderCount += 1;
          onProgress?.call(
            LocalFolderRefreshProgress(
              stage: LocalFolderRefreshStage.checking,
              current: checkedFolderCount,
              total: max(preparedFolderCount, checkedFolderCount),
              currentPath: folderPath,
              checkedFolderCount: checkedFolderCount,
              folderCount: folderProgressMax(),
              canCancel: true,
            ),
          );
        },
      );
      cancellation?.throwIfCanceled();
      final previousSongPaths = _readActiveSongPaths(db);
      final scannedPathKeys = scannedPaths.map(_pathComparisonKey).toSet();
      final previousPathKeys =
          previousSongPaths.map(_pathComparisonKey).toSet();
      final movedFiles = detectMovedLocalAudioFiles(
        addedPaths:
            scannedPaths.where((filePath) {
              return !previousPathKeys.contains(_pathComparisonKey(filePath));
            }).toList(),
        removedPaths:
            previousSongPaths.where((filePath) {
              return !scannedPathKeys.contains(_pathComparisonKey(filePath));
            }).toList(),
      );
      final movedNewPathKeys =
          movedFiles.map((file) => _pathComparisonKey(file.newPath)).toSet();
      final movedOldPathKeys =
          movedFiles.map((file) => _pathComparisonKey(file.oldPath)).toSet();
      final addedPaths =
          scannedPaths
              .where(
                (filePath) =>
                    !previousPathKeys.contains(_pathComparisonKey(filePath)) &&
                    !movedNewPathKeys.contains(_pathComparisonKey(filePath)),
              )
              .toList();
      final addedPathKeys = addedPaths.map(_pathComparisonKey).toSet();
      final removedPaths =
          previousSongPaths
              .where(
                (filePath) =>
                    !scannedPathKeys.contains(_pathComparisonKey(filePath)) &&
                    !movedOldPathKeys.contains(_pathComparisonKey(filePath)),
              )
              .toList();
      final readTotal = max(scannedPaths.length, 1);
      var readAddedCount = 0;
      onProgress?.call(
        LocalFolderRefreshProgress(
          stage: LocalFolderRefreshStage.reading,
          current: 0,
          total: readTotal,
          currentPath: '',
          checkedFolderCount: checkedFolderCount,
          folderCount: folderProgressMax(),
          songCount: scannedPaths.length,
          updatedCount: movedFiles.length,
          missingCount: removedPaths.length,
          canCancel: true,
        ),
      );
      final metadataByPath = await _readAudioFileMetadataBatch(
        scannedPaths,
        cancellation: cancellation,
        onProgress: (filePath, completedCount) {
          if (addedPathKeys.contains(_pathComparisonKey(filePath))) {
            readAddedCount += 1;
          }
          onProgress?.call(
            LocalFolderRefreshProgress(
              stage: LocalFolderRefreshStage.reading,
              current: completedCount,
              total: readTotal,
              currentPath: filePath,
              checkedFolderCount: checkedFolderCount,
              folderCount: folderProgressMax(),
              processedSongCount: completedCount,
              songCount: scannedPaths.length,
              addedCount: readAddedCount,
              updatedCount: movedFiles.length,
              missingCount: removedPaths.length,
              canCancel: true,
            ),
          );
        },
      );
      final folders = _nonEmptyScannedFolders(rootPath, scannedPaths);
      final writeTotal = max(scannedPaths.length + 1, 1);
      onProgress?.call(
        LocalFolderRefreshProgress(
          stage: LocalFolderRefreshStage.updating,
          current: 0,
          total: writeTotal,
          currentPath: '',
          checkedFolderCount: checkedFolderCount,
          folderCount: folderProgressMax(),
          songCount: scannedPaths.length,
          addedCount: addedPaths.length,
          updatedCount: movedFiles.length,
          missingCount: removedPaths.length,
        ),
      );
      cancellation?.throwIfCanceled();

      db.execute('BEGIN');
      try {
        _markScannedTablesInactive(db);
        final folderIds = _upsertScannedFolders(db, rootPath, folders);
        for (final entry in scannedPaths.indexed) {
          final writtenCount = entry.$1 + 1;
          onProgress?.call(
            LocalFolderRefreshProgress(
              current: writtenCount,
              total: writeTotal,
              currentPath: entry.$2,
              stage: LocalFolderRefreshStage.updating,
              checkedFolderCount: checkedFolderCount,
              folderCount: folderProgressMax(),
              processedSongCount: writtenCount,
              songCount: scannedPaths.length,
              addedCount: addedPaths.length,
              updatedCount: movedFiles.length,
              missingCount: removedPaths.length,
            ),
          );
          _upsertScannedAudioFile(
            db,
            entry.$2,
            folderIds,
            metadata: metadataByPath[entry.$2]!,
            useFilenameNotMusicName: settings.useFilenameNotMusicName,
          );
        }
        _setRootPath(db, rootPath);

        final artistAnalysis =
            settings.smartMultiArtistRecognition
                ? artist_split_model.analyzeArtistSplits(_readSongs(db))
                : const ArtistSplitAnalysisResult(
                  directSplits: [],
                  possibleSplits: [],
                  mergeSuggestions: [],
                );
        for (final split in artistAnalysis.directSplits) {
          final artists = _normalizeArtists(split.artists).take(6).toList();
          db.execute(
            '''
            UPDATE Music
            SET Artist = ?
            WHERE Id = ?
              AND State = ?
          ''',
            [artists.join(', '), split.songId, _activeState],
          );
          _syncSongArtists(db, split.songId, artists);
        }
        onProgress?.call(
          LocalFolderRefreshProgress(
            stage: LocalFolderRefreshStage.updating,
            current: writeTotal,
            total: writeTotal,
            currentPath: '',
            checkedFolderCount: checkedFolderCount,
            folderCount: folderProgressMax(),
            processedSongCount: scannedPaths.length,
            songCount: scannedPaths.length,
            addedCount: addedPaths.length,
            updatedCount: movedFiles.length,
            missingCount: removedPaths.length,
          ),
        );

        final autoLyricsEnabled = _readAutoLyricsEnabled(db);
        final autoLyricsPaths = addedPaths.toList();
        db.execute('COMMIT');
        if (autoLyricsEnabled) {
          unawaited(
            _autoAddInternetLyricsForPaths(autoLyricsPaths).catchError((_) {}),
          );
        }
        await _pruneArtworkCache(db);
        return LocalFolderRefreshResult(
          filesAdded: addedPaths,
          filesRemoved: removedPaths,
          filesMoved: movedFiles.map((file) => file.newPath).toList(),
          artistSplitsApplied: artistAnalysis.directSplits,
          artistSplitSuggestions: artistAnalysis.possibleSplits,
          artistMergeSuggestions: artistAnalysis.mergeSuggestions,
        );
      } on Object {
        db.execute('ROLLBACK');
        rethrow;
      }
    } finally {
      db.dispose();
    }
  }

  Future<LocalFolderRefreshResult> refreshLocalFolder(
    String folderPath, {
    void Function(LocalFolderRefreshProgress progress)? onProgress,
    LocalFolderScanCancellation? cancellation,
  }) async {
    final databaseFile = await _resolveDatabaseFile();
    final db = sqlite3.open(databaseFile.path);
    try {
      final settings = _readLibrarySettings(db);
      final hiddenPaths = _readActiveHiddenStoragePaths(db);
      final preparedFolderCount =
          _countScannableFolders(folderPath, hiddenPaths.folderPaths) + 1;
      var checkedFolderCount = 0;
      int folderProgressMax() => max(preparedFolderCount, checkedFolderCount);
      final scannedPaths = findScannableAudioFiles(
        folderPath,
        hiddenFolderPaths: hiddenPaths.folderPaths,
        hiddenFilePaths: hiddenPaths.filePaths,
        cancellation: cancellation,
        onFolder: (folderPath) {
          checkedFolderCount += 1;
          onProgress?.call(
            LocalFolderRefreshProgress(
              stage: LocalFolderRefreshStage.checking,
              current: checkedFolderCount,
              total: max(preparedFolderCount, checkedFolderCount),
              currentPath: folderPath,
              checkedFolderCount: checkedFolderCount,
              folderCount: folderProgressMax(),
              canCancel: true,
            ),
          );
        },
      );
      cancellation?.throwIfCanceled();
      final scannedPathKeys = scannedPaths.map(_pathComparisonKey).toSet();
      final existingRows = db.select(
        '''
        SELECT Id AS id, Path AS path
        FROM Music
        WHERE State = ?
          AND (Path = ? OR Path LIKE ? OR Path LIKE ?)
      ''',
        [_activeState, folderPath, '$folderPath/%', '$folderPath\\%'],
      );
      final existingPathKeys = {
        for (final row in existingRows)
          _pathComparisonKey(row['path'] as String): row,
      };
      final addedCandidates =
          scannedPaths.where((filePath) {
            return !existingPathKeys.containsKey(_pathComparisonKey(filePath));
          }).toList();
      final removedCandidates =
          existingRows
              .where((row) {
                return !scannedPathKeys.contains(
                  _pathComparisonKey(row['path'] as String),
                );
              })
              .map((row) {
                return _RefreshRemovedSong(
                  id: row['id'] as int,
                  path: row['path'] as String,
                );
              })
              .toList();
      final movedFiles = detectMovedLocalAudioFiles(
        addedPaths: addedCandidates,
        removedPaths: removedCandidates.map((song) => song.path).toList(),
      );
      final movedNewPathKeys =
          movedFiles.map((file) => _pathComparisonKey(file.newPath)).toSet();
      final movedOldPathKeys =
          movedFiles.map((file) => _pathComparisonKey(file.oldPath)).toSet();
      final movedSongs = [
        for (final movedFile in movedFiles)
          _RefreshMovedSong(
            id:
                removedCandidates
                    .firstWhere(
                      (song) =>
                          _pathComparisonKey(song.path) ==
                          _pathComparisonKey(movedFile.oldPath),
                    )
                    .id,
            oldPath: movedFile.oldPath,
            newPath: movedFile.newPath,
          ),
      ];
      final addedPaths =
          addedCandidates
              .where(
                (filePath) =>
                    !movedNewPathKeys.contains(_pathComparisonKey(filePath)),
              )
              .toList();
      final removedSongs =
          removedCandidates
              .where(
                (song) =>
                    !movedOldPathKeys.contains(_pathComparisonKey(song.path)),
              )
              .toList();
      final readTotal = max(addedPaths.length, 1);
      var readAddedCount = 0;
      onProgress?.call(
        LocalFolderRefreshProgress(
          stage: LocalFolderRefreshStage.reading,
          current: 0,
          total: readTotal,
          currentPath: '',
          checkedFolderCount: checkedFolderCount,
          folderCount: folderProgressMax(),
          songCount: addedPaths.length,
          updatedCount: movedFiles.length,
          missingCount: removedSongs.length,
          canCancel: true,
        ),
      );
      final metadataByPath = await _readAudioFileMetadataBatch(
        addedPaths,
        cancellation: cancellation,
        onProgress: (filePath, completedCount) {
          readAddedCount += 1;
          onProgress?.call(
            LocalFolderRefreshProgress(
              stage: LocalFolderRefreshStage.reading,
              current: completedCount,
              total: readTotal,
              currentPath: filePath,
              checkedFolderCount: checkedFolderCount,
              folderCount: folderProgressMax(),
              processedSongCount: completedCount,
              songCount: addedPaths.length,
              addedCount: readAddedCount,
              updatedCount: movedFiles.length,
              missingCount: removedSongs.length,
              canCancel: true,
            ),
          );
        },
      );
      final rootPath =
          settings.rootPath.isEmpty ? folderPath : settings.rootPath;
      final folders = _nonEmptyScannedFolders(rootPath, scannedPaths);
      final writeTotal = max(addedPaths.length + removedSongs.length + 1, 1);
      onProgress?.call(
        LocalFolderRefreshProgress(
          stage: LocalFolderRefreshStage.updating,
          current: 0,
          total: writeTotal,
          currentPath: '',
          checkedFolderCount: checkedFolderCount,
          folderCount: folderProgressMax(),
          songCount: addedPaths.length,
          addedCount: addedPaths.length,
          updatedCount: movedFiles.length,
          missingCount: removedSongs.length,
        ),
      );
      cancellation?.throwIfCanceled();

      db.execute('BEGIN');
      try {
        _markScannedFoldersInactive(db, folderPath);
        for (final movedSong in movedSongs) {
          _updateMovedSongPathInsideTransaction(db, movedSong);
        }
        if (removedSongs.isNotEmpty) {
          _deleteSongsInsideTransaction(
            db,
            removedSongs.map((song) => song.id).toList(),
            removedSongs.map((song) => song.path).toList(),
          );
        }
        final removedProgress = removedSongs.length;
        if (removedProgress > 0) {
          onProgress?.call(
            LocalFolderRefreshProgress(
              stage: LocalFolderRefreshStage.updating,
              current: removedProgress,
              total: writeTotal,
              currentPath: '',
              checkedFolderCount: checkedFolderCount,
              folderCount: folderProgressMax(),
              songCount: addedPaths.length,
              addedCount: addedPaths.length,
              updatedCount: movedFiles.length,
              missingCount: removedSongs.length,
            ),
          );
        }
        final folderIds = _upsertScannedFolders(db, rootPath, folders);
        for (final entry in addedPaths.indexed) {
          final writtenCount = entry.$1 + 1;
          onProgress?.call(
            LocalFolderRefreshProgress(
              current: removedProgress + writtenCount,
              total: writeTotal,
              currentPath: entry.$2,
              stage: LocalFolderRefreshStage.updating,
              checkedFolderCount: checkedFolderCount,
              folderCount: folderProgressMax(),
              processedSongCount: writtenCount,
              songCount: addedPaths.length,
              addedCount: addedPaths.length,
              updatedCount: movedFiles.length,
              missingCount: removedSongs.length,
            ),
          );
          _upsertScannedAudioFile(
            db,
            entry.$2,
            folderIds,
            metadata: metadataByPath[entry.$2]!,
            useFilenameNotMusicName: settings.useFilenameNotMusicName,
          );
        }

        final artistAnalysis =
            settings.smartMultiArtistRecognition
                ? artist_split_model.analyzeArtistSplits(_readSongs(db))
                : const ArtistSplitAnalysisResult(
                  directSplits: [],
                  possibleSplits: [],
                  mergeSuggestions: [],
                );
        for (final split in artistAnalysis.directSplits) {
          final artists = _normalizeArtists(split.artists).take(6).toList();
          db.execute(
            '''
            UPDATE Music
            SET Artist = ?
            WHERE Id = ?
              AND State = ?
          ''',
            [artists.join(', '), split.songId, _activeState],
          );
          _syncSongArtists(db, split.songId, artists);
        }
        onProgress?.call(
          LocalFolderRefreshProgress(
            stage: LocalFolderRefreshStage.updating,
            current: writeTotal,
            total: writeTotal,
            currentPath: '',
            checkedFolderCount: checkedFolderCount,
            folderCount: folderProgressMax(),
            processedSongCount: addedPaths.length,
            songCount: addedPaths.length,
            addedCount: addedPaths.length,
            updatedCount: movedFiles.length,
            missingCount: removedSongs.length,
          ),
        );
        final autoLyricsEnabled = _readAutoLyricsEnabled(db);
        final autoLyricsPaths = addedPaths.toList();
        db.execute('COMMIT');
        if (autoLyricsEnabled) {
          unawaited(
            _autoAddInternetLyricsForPaths(autoLyricsPaths).catchError((_) {}),
          );
        }
        await _pruneArtworkCache(db);

        return LocalFolderRefreshResult(
          filesAdded: addedPaths,
          filesRemoved: removedSongs.map((song) => song.path).toList(),
          filesMoved: movedSongs.map((song) => song.newPath).toList(),
          artistSplitsApplied: artistAnalysis.directSplits,
          artistSplitSuggestions: artistAnalysis.possibleSplits,
          artistMergeSuggestions: artistAnalysis.mergeSuggestions,
        );
      } on Object {
        db.execute('ROLLBACK');
        rethrow;
      }
    } finally {
      db.dispose();
    }
  }

  Future<LocalFolderRefreshResult> createLocalFolder(
    String rootPath,
    String relativePath,
    String name, {
    void Function(LocalFolderRefreshProgress progress)? onProgress,
    LocalFolderScanCancellation? cancellation,
  }) async {
    final parentPath =
        relativePath.isEmpty ? rootPath : p.join(rootPath, relativePath);
    await Directory(p.join(parentPath, name)).create(recursive: true);
    return refreshLocalFolder(
      parentPath,
      onProgress: onProgress,
      cancellation: cancellation,
    );
  }

  Future<void> setSongsFavorite(List<int> songIds, bool favorite) async {
    final databaseFile = await _resolveDatabaseFile();
    if (!databaseFile.existsSync()) {
      return;
    }

    final db = sqlite3.open(databaseFile.path);
    try {
      final settings = _readLibrarySettings(db);
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

  Future<SongPropertiesSnapshot> getSongProperties(int songId) async {
    final databaseFile = await _resolveDatabaseFile();
    final db = sqlite3.open(databaseFile.path);
    try {
      final rows = db.select(
        '''
        SELECT
          Id AS id,
          Path AS path,
          Name AS title,
          Artist AS artist,
          Album AS album,
          Duration AS duration,
          PlayCount AS playCount
        FROM Music
        WHERE Id = ?
          AND State = ?
        LIMIT 1
      ''',
        [songId, _activeState],
      );
      final row = rows.first;
      final artists = _readSongArtists(db, songId, row['artist'] as String);
      final file = File(row['path'] as String);
      final stats = await file.stat();
      final extension = p.extension(file.path).replaceFirst('.', '');
      final id3Properties = await _id3TagService.readSongTagProperties(
        file.path,
      );
      final title = _normalizeTagText(id3Properties.title);
      final artist = _normalizeTagText(id3Properties.artist);
      final album = _normalizeTagText(id3Properties.album);

      return SongPropertiesSnapshot(
        songId: songId,
        path: file.path,
        title:
            title.isEmpty ? _normalizeTagText(row['title'] as String) : title,
        subtitle: id3Properties.subtitle,
        artist:
            artist.isEmpty
                ? _normalizeTagText(row['artist'] as String)
                : artist,
        artists: artists,
        album:
            album.isEmpty ? _normalizeTagText(row['album'] as String) : album,
        albumArtist: id3Properties.albumArtist,
        publisher: id3Properties.publisher,
        trackNumber: id3Properties.trackNumber,
        year: id3Properties.year,
        genre: id3Properties.genre,
        composers: id3Properties.composers,
        duration: row['duration'] as int,
        bitrate: 0,
        fileSize: stats.size,
        dateCreated: stats.changed.toIso8601String(),
        dateModified: stats.modified.toIso8601String(),
        fileType: extension.toUpperCase(),
        playCount: row['playCount'] as int,
      );
    } finally {
      db.dispose();
    }
  }

  Future<void> updateSongProperties(
    int songId,
    SongPropertiesUpdate update,
  ) async {
    final databaseFile = await _resolveDatabaseFile();
    final title = update.title.trim();
    final artists = _normalizeArtists(update.artists).take(6).toList();
    final artist = artists.join(', ');
    final album = update.album.trim();
    final db = sqlite3.open(databaseFile.path);
    try {
      final songRows = db.select(
        '''
        SELECT Path AS path
        FROM Music
        WHERE Id = ?
          AND State = ?
        LIMIT 1
      ''',
        [songId, _activeState],
      );
      final songPath = songRows.first['path'] as String;
      await _id3TagService.writeSongTagProperties(
        songPath,
        Id3SongTagProperties(
          title: title,
          subtitle: update.subtitle.trim(),
          artist: artist,
          album: album,
          albumArtist: update.albumArtist.trim(),
          publisher: update.publisher.trim(),
          trackNumber: update.trackNumber,
          year: update.year,
          genre: update.genre.trim(),
          composers: update.composers.trim(),
        ),
      );

      db.execute('BEGIN');
      try {
        db.execute(
          '''
          UPDATE Music
          SET Name = ?, Artist = ?, Album = ?, PlayCount = ?
          WHERE Id = ?
            AND State = ?
        ''',
          [title, artist, album, update.playCount, songId, _activeState],
        );
        _syncSongArtists(db, songId, artists);
        db.execute('COMMIT');
      } on Object {
        db.execute('ROLLBACK');
        rethrow;
      }
    } finally {
      db.dispose();
    }
  }

  Future<void> updateSongPlayCount(int songId, int playCount) async {
    final databaseFile = await _resolveDatabaseFile();
    final db = sqlite3.open(databaseFile.path);
    try {
      db.execute(
        '''
        UPDATE Music
        SET PlayCount = ?
        WHERE Id = ?
          AND State = ?
      ''',
        [playCount, songId, _activeState],
      );
    } finally {
      db.dispose();
    }
  }

  Future<void> markSongPlayed(int songId) async {
    final databaseFile = await _resolveDatabaseFile();
    if (!databaseFile.existsSync()) {
      return;
    }

    final db = sqlite3.open(databaseFile.path);
    try {
      db.execute('BEGIN');
      try {
        db.execute(
          '''
          UPDATE Music
          SET PlayCount = PlayCount + 1
          WHERE Id = ?
            AND State = ?
        ''',
          [songId, _activeState],
        );
        _recordRecentItemPlayed(db, songId.toString(), _recentRecordTypeSong);
        db.execute('COMMIT');
      } on Object {
        db.execute('ROLLBACK');
        rethrow;
      }
    } finally {
      db.dispose();
    }
  }

  Future<LyricsSnapshot> getSongLyrics(
    int songId, {
    settings.LyricsRequestMode mode = settings.LyricsRequestMode.auto,
  }) async {
    final song = await _getLyricsSongLookup(songId);
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

  Future<void> saveSongLyrics(int songId, String rawLyrics) async {
    final songPath = await _getSongPath(songId);
    await _writeLyricsToSongPath(songPath, rawLyrics);
  }

  Future<void> updateLyricsOffset(int songId, int offsetMs) async {
    final databaseFile = await _resolveDatabaseFile();
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

  Future<LyricsSnapshot> getInternetLyrics(int songId) async {
    final song = await _getLyricsSongLookup(songId);
    final rawLyrics = await _searchInternetLyrics(song);
    final internetLyrics = await _prepareInternetLyrics(rawLyrics);
    return _createLyricsSnapshot(
      internetLyrics,
      internetLyrics.trim().isEmpty ? LyricsSource.none : LyricsSource.internet,
    );
  }

  Future<LyricsBatchResult> batchAddInternetLyrics({
    bool overwrite = false,
    void Function(LyricsBatchProgress progress)? onProgress,
    bool Function()? isCanceled,
    Future<void> Function()? waitIfPaused,
  }) async {
    final snapshot = await getMusicLibrarySnapshot();
    var saved = 0;
    var overwritten = 0;
    var skipped = 0;
    var missing = 0;
    var failed = 0;
    var backedUp = 0;
    var backupBytes = 0;
    var lastRequestStartedAt = DateTime.fromMillisecondsSinceEpoch(0);
    final details = <LyricsBatchDetail>[];

    for (var index = 0; index < snapshot.songs.length; index += 1) {
      if (isCanceled?.call() == true) {
        break;
      }
      await waitIfPaused?.call();
      if (isCanceled?.call() == true) {
        break;
      }

      final song = snapshot.songs[index];
      onProgress?.call(
        LyricsBatchProgress(
          currentIndex: index + 1,
          total: snapshot.songs.length,
          currentSongTitle: song.title,
          saved: saved,
          overwritten: overwritten,
          skipped: skipped,
          missing: missing,
          failed: failed,
          backedUp: backedUp,
          backupBytes: backupBytes,
        ),
      );

      try {
        final localLyrics = await _getSongLyricsByPath(song.path);
        final existingRawLyrics = localLyrics.rawText;
        if (!overwrite && existingRawLyrics.trim().isNotEmpty) {
          skipped += 1;
          details.add(
            LyricsBatchDetail(
              songId: song.id,
              title: song.title,
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
        lastRequestStartedAt = DateTime.now();
        final internetLyrics =
            _internetLyricsResolver == null
                ? await _searchInternetLyrics(
                  _LyricsSongLookup(
                    title: song.title,
                    artist: song.artist,
                    album: song.album,
                    path: song.path,
                  ),
                )
                : await _internetLyricsResolver(song);

        if (internetLyrics.trim().isEmpty) {
          missing += 1;
          details.add(
            LyricsBatchDetail(
              songId: song.id,
              title: song.title,
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
          details.add(
            LyricsBatchDetail(
              songId: song.id,
              title: song.title,
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
          details.add(
            LyricsBatchDetail(
              songId: song.id,
              title: song.title,
              result: LyricsBatchDetailResult.saved,
              targetRawLyrics: internetLyrics,
            ),
          );
        } else {
          overwritten += 1;
          details.add(
            LyricsBatchDetail(
              songId: song.id,
              title: song.title,
              result: LyricsBatchDetailResult.overwritten,
              sourceRawLyrics: existingRawLyrics,
              targetRawLyrics: internetLyrics,
            ),
          );
        }
      } on Object {
        failed += 1;
        details.add(
          LyricsBatchDetail(
            songId: song.id,
            title: song.title,
            result: LyricsBatchDetailResult.failed,
          ),
        );
      }
    }

    return LyricsBatchResult(
      total: snapshot.songs.length,
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

  Future<void> _autoAddInternetLyricsForPaths(List<String> songPaths) async {
    if (songPaths.isEmpty) {
      return;
    }
    final songPathKeys = songPaths.map(_pathComparisonKey).toSet();
    final databaseFile = await _resolveDatabaseFile();
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

  Future<SongArtworkSnapshot> getSongArtworkSnapshot(int songId) async {
    final databaseFile = await _resolveDatabaseFile();
    final db = sqlite3.open(databaseFile.path);
    try {
      final rows = db.select(
        '''
        SELECT Path AS path, ThumbnailPath AS thumbnailPath
        FROM Music
        WHERE Id = ?
          AND State = ?
        LIMIT 1
      ''',
        [songId, _activeState],
      );
      return await _resolveSongArtworkSnapshot(
        db,
        songId,
        rows.first['path'] as String,
        rows.first['thumbnailPath'] as String,
      );
    } finally {
      db.dispose();
    }
  }

  Future<List<SongArtworkSnapshot>> getSongArtworkSnapshots(
    List<int> songIds,
  ) async {
    final uniqueIds = songIds.toSet().toList();
    if (uniqueIds.isEmpty) {
      return [];
    }

    final databaseFile = await _resolveDatabaseFile();
    final placeholders = List.filled(uniqueIds.length, '?').join(', ');
    final db = sqlite3.open(databaseFile.path);
    try {
      final rows = db.select(
        '''
        SELECT Id AS id, Path AS path, ThumbnailPath AS thumbnailPath
        FROM Music
        WHERE Id IN ($placeholders)
          AND State = ?
      ''',
        [...uniqueIds, _activeState],
      );
      final rowsById = {for (final row in rows) row['id'] as int: row};
      return [
        for (final songId in uniqueIds)
          if (rowsById[songId] case final row?)
            await _resolveSongArtworkSnapshot(
              db,
              songId,
              row['path'] as String,
              row['thumbnailPath'] as String,
            )
          else
            _createSongArtworkSnapshot(songId, ''),
      ];
    } finally {
      db.dispose();
    }
  }

  Future<String> prepareSongArtworkSource(String sourcePath) async {
    final source = File(sourcePath);
    final cacheDirectory = await _resolveArtworkCacheDirectory();
    final extension = p.extension(source.path);
    if (extension.toLowerCase() == '.mp3') {
      final picture = await _id3TagService.readFirstPicture(source.path);
      if (picture == null) {
        throw StateError('No album art found in the selected music file.');
      }

      final target = File(
        p.join(
          cacheDirectory.path,
          '${DateTime.now().microsecondsSinceEpoch}${_extensionForMimeType(picture.format)}',
        ),
      );
      await target.writeAsBytes(picture.data);
      return target.path;
    }

    final target = File(
      p.join(
        cacheDirectory.path,
        '${DateTime.now().microsecondsSinceEpoch}$extension',
      ),
    );
    await source.copy(target.path);
    return target.path;
  }

  Future<void> saveSongArtwork(int songId, String sourcePath) async {
    final databaseFile = await _resolveDatabaseFile();
    final db = sqlite3.open(databaseFile.path);
    try {
      final songRows = db.select(
        '''
        SELECT Path AS path
        FROM Music
        WHERE Id = ?
          AND State = ?
        LIMIT 1
      ''',
        [songId, _activeState],
      );
      final songPath = songRows.first['path'] as String;
      await _id3TagService.writeSongArtwork(
        songPath,
        Id3Picture(
          data: await File(sourcePath).readAsBytes(),
          format: _getArtworkMimeType(sourcePath),
        ),
      );

      db.execute(
        '''
        UPDATE Music
        SET ThumbnailPath = ?
        WHERE Id = ?
          AND State = ?
      ''',
        [sourcePath, songId, _activeState],
      );
    } finally {
      db.dispose();
    }
  }

  Future<void> saveAlbumArtwork(String albumName, String sourcePath) async {
    final databaseFile = await _resolveDatabaseFile();
    final db = sqlite3.open(databaseFile.path);
    try {
      final songRows = db.select(
        '''
        SELECT Path AS path
        FROM Music
        WHERE Album = ?
          AND State = ?
      ''',
        [albumName, _activeState],
      );
      final picture = Id3Picture(
        data: await File(sourcePath).readAsBytes(),
        format: _getArtworkMimeType(sourcePath),
      );
      for (final row in songRows) {
        await _id3TagService.writeSongArtwork(row['path'] as String, picture);
      }

      db.execute(
        '''
        UPDATE Music
        SET ThumbnailPath = ?
        WHERE Album = ?
          AND State = ?
      ''',
        [sourcePath, albumName, _activeState],
      );
    } finally {
      db.dispose();
    }
  }

  Future<void> deleteSongArtwork(int songId) async {
    final databaseFile = await _resolveDatabaseFile();
    final db = sqlite3.open(databaseFile.path);
    try {
      final songRows = db.select(
        '''
        SELECT Path AS path
        FROM Music
        WHERE Id = ?
          AND State = ?
        LIMIT 1
      ''',
        [songId, _activeState],
      );
      await _id3TagService.writeSongArtwork(
        songRows.first['path'] as String,
        null,
      );

      db.execute(
        '''
        UPDATE Music
        SET ThumbnailPath = ''
        WHERE Id = ?
          AND State = ?
      ''',
        [songId, _activeState],
      );
    } finally {
      db.dispose();
    }
  }

  Future<void> deleteAlbumArtwork(String albumName) async {
    final databaseFile = await _resolveDatabaseFile();
    final db = sqlite3.open(databaseFile.path);
    try {
      final songRows = db.select(
        '''
        SELECT Path AS path
        FROM Music
        WHERE Album = ?
          AND State = ?
      ''',
        [albumName, _activeState],
      );
      for (final row in songRows) {
        await _id3TagService.writeSongArtwork(row['path'] as String, null);
      }

      db.execute(
        '''
        UPDATE Music
        SET ThumbnailPath = ''
        WHERE Album = ?
          AND State = ?
      ''',
        [albumName, _activeState],
      );
    } finally {
      db.dispose();
    }
  }

  Future<void> addPreferenceItem(
    String type,
    String itemId,
    String name,
    String level,
  ) async {
    final databaseFile = await _resolveDatabaseFile();
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

  Future<String?> getPreferenceLevel(String type, String itemId) async {
    final databaseFile = await _resolveDatabaseFile();
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

  Future<void> removePreferenceItem(String type, String itemId) async {
    final databaseFile = await _resolveDatabaseFile();
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

  Future<PreferenceSettingsSnapshot> getPreferenceSettings() async {
    final databaseFile = await _resolveDatabaseFile();
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
    Map<PreferenceSectionKey, bool> enabled,
  ) async {
    final databaseFile = await _resolveDatabaseFile();
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
    int itemId, {
    bool? isEnabled,
    PreferenceLevel? level,
  }) async {
    final databaseFile = await _resolveDatabaseFile();
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

  Future<void> removePreferenceItemById(int itemId) async {
    final databaseFile = await _resolveDatabaseFile();
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

  Future<void> clearInvalidPreferenceItems(PreferenceEntityType type) async {
    final databaseFile = await _resolveDatabaseFile();
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

  Future<void> addSongToPlaylist(int playlistId, int songId) async {
    await addSongsToPlaylist(playlistId, [songId]);
  }

  Future<void> addSongsToPlaylist(int playlistId, List<int> songIds) async {
    final databaseFile = await _resolveDatabaseFile();
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

  Future<void> removeSongFromPlaylist(int playlistId, int songId) async {
    await removeSongsFromPlaylist(playlistId, [songId]);
  }

  Future<void> removeSongsFromPlaylist(
    int playlistId,
    List<int> songIds,
  ) async {
    final databaseFile = await _resolveDatabaseFile();
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
    int playlistId,
    List<int> songIds, [
    PlaylistSortCriterion? sortCriterion,
  ]) async {
    final databaseFile = await _resolveDatabaseFile();
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

  Future<void> recordPlaylistPlayed(int playlistId) async {
    final databaseFile = await _resolveDatabaseFile();
    if (!databaseFile.existsSync()) {
      return;
    }

    final db = sqlite3.open(databaseFile.path);
    try {
      db.execute('BEGIN');
      try {
        _recordRecentItemPlayed(
          db,
          playlistId.toString(),
          _recentRecordTypePlaylist,
        );
        db.execute('COMMIT');
      } on Object {
        db.execute('ROLLBACK');
        rethrow;
      }
    } finally {
      db.dispose();
    }
  }

  Future<void> recordAlbumPlayed(String album) async {
    await _recordCollectionPlayed(album, _recentRecordTypeAlbum);
  }

  Future<void> recordArtistPlayed(String artist) async {
    await _recordCollectionPlayed(artist, _recentRecordTypeArtist);
  }

  Future<void> _recordCollectionPlayed(String itemId, int type) async {
    final databaseFile = await _resolveDatabaseFile();
    if (!databaseFile.existsSync()) {
      return;
    }

    final db = sqlite3.open(databaseFile.path);
    try {
      db.execute('BEGIN');
      try {
        _recordRecentItemPlayed(db, itemId, type);
        db.execute('COMMIT');
      } on Object {
        db.execute('ROLLBACK');
        rethrow;
      }
    } finally {
      db.dispose();
    }
  }

  void _recordRecentItemPlayed(Database db, String itemId, int type) {
    db.execute(
      '''
      UPDATE RecentRecord
      SET State = ?
      WHERE Type = ?
        AND ItemId = ?
    ''',
      [_inactiveState, type, itemId],
    );
    db.execute(
      '''
      INSERT INTO RecentRecord (Type, ItemId, Time, State)
      VALUES (?, ?, ?, ?)
    ''',
      [type, itemId, DateTime.now().toUtc().toIso8601String(), _activeState],
    );
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
    final resolved = _resolvePreferenceItem(row, type);
    return PreferenceItemSnapshot(
      id: row['id'] as int,
      type: type,
      itemId: row['itemId'] as String,
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
  ) {
    final itemId = row['itemId'] as String;
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

  int _settingsRowId(Database db) {
    return db
            .select('SELECT Id FROM Settings ORDER BY Id DESC LIMIT 1')
            .single['Id']
        as int;
  }

  settings.SettingsSnapshot _settingsSnapshotFromRow(Row row) {
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

  _LibrarySettings _readLibrarySettings(Database db) {
    final rows = db.select('''
      SELECT
        RootPath AS rootPath,
        MusicLibraryCriterion AS musicLibraryCriterion,
        AlbumsCriterion AS albumsCriterion,
        MyFavorites AS myFavorites,
        NowPlaying AS nowPlaying,
        ShowCount AS showCount,
        HideMultiSelectCommandBarAfterOperation
          AS hideMultiSelectCommandBarAfterOperation,
        LocalViewMode AS localViewMode,
        UseFilenameNotMusicName AS useFilenameNotMusicName,
        SmartMultiArtistRecognition AS smartMultiArtistRecognition
      FROM Settings
      ORDER BY Id
      LIMIT 1
    ''');
    final rootPath = rows.isEmpty ? '' : (rows.first['rootPath'] as String);
    final musicLibraryCriterion =
        rows.isEmpty ? 0 : (rows.first['musicLibraryCriterion'] as int);
    final albumsCriterion =
        rows.isEmpty ? -1 : (rows.first['albumsCriterion'] as int);
    final myFavorites = rows.isEmpty ? 0 : (rows.first['myFavorites'] as int);
    final nowPlaying = rows.isEmpty ? 0 : (rows.first['nowPlaying'] as int);
    final showCount = rows.isEmpty || (rows.first['showCount'] as int) != 0;
    final hideMultiSelectCommandBarAfterOperation =
        rows.isEmpty ||
        (rows.first['hideMultiSelectCommandBarAfterOperation'] as int) != 0;
    final localViewMode =
        rows.isEmpty
            ? settings.LocalViewMode.grid
            : _localViewModeFromValue(rows.first['localViewMode'] as int);
    final useFilenameNotMusicName =
        rows.isNotEmpty && (rows.first['useFilenameNotMusicName'] as int) != 0;
    final smartMultiArtistRecognition =
        rows.isEmpty || (rows.first['smartMultiArtistRecognition'] as int) != 0;

    return _LibrarySettings(
      rootPath: rootPath,
      sortCriterion: _fromStoredSortCriterion(musicLibraryCriterion),
      albumsSort: _fromStoredAlbumSortCriterion(albumsCriterion),
      myFavoritesId: myFavorites,
      nowPlayingId: nowPlaying,
      showCount: showCount,
      hideMultiSelectCommandBarAfterOperation:
          hideMultiSelectCommandBarAfterOperation,
      localViewMode: localViewMode,
      useFilenameNotMusicName: useFilenameNotMusicName,
      smartMultiArtistRecognition: smartMultiArtistRecognition,
    );
  }

  bool _readAutoLyricsEnabled(Database db) {
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

  List<LibrarySong> _readSongs(Database db) {
    final rows = db.select(
      '''
      WITH SettingsRow AS (
        SELECT MyFavorites AS favoritePlaylistId
        FROM Settings
        ORDER BY Id
        LIMIT 1
      )
      SELECT
        Music.Id AS id,
        Music.Path AS path,
        Music.ThumbnailPath AS thumbnailPath,
        Music.Name AS title,
        Music.Artist AS artist,
        Music.Album AS album,
        Music.Duration AS duration,
        Music.PlayCount AS playCount,
        Music.LyricsOffsetMs AS lyricsOffsetMs,
        CAST(Music.DateAdded AS TEXT) AS dateAdded,
        EXISTS(
          SELECT 1
          FROM PlaylistItem, SettingsRow
          WHERE PlaylistItem.PlaylistId = SettingsRow.favoritePlaylistId
            AND PlaylistItem.ItemId = Music.Id
            AND PlaylistItem.State = ?
        ) AS favorite,
        COALESCE((
          SELECT group_concat(Name, char(31))
          FROM (
            SELECT MusicArtist.Name AS Name
            FROM MusicArtist
            WHERE MusicArtist.MusicId = Music.Id
              AND MusicArtist.State = ?
            ORDER BY MusicArtist.Priority, MusicArtist.Id
          )
        ), '') AS artistsValue
      FROM Music
      WHERE Music.State = ?
      ORDER BY Music.Name COLLATE NOCASE, Music.Artist COLLATE NOCASE, Music.Id
    ''',
      [_activeState, _activeState, _activeState],
    );

    return rows.map((row) {
      final artist = _normalizeTagText(row['artist'] as String);
      final artistsValue = row['artistsValue'] as String;
      final artists =
          artistsValue.isEmpty
              ? [artist]
              : artistsValue
                  .split(String.fromCharCode(31))
                  .map(_normalizeTagText)
                  .where((value) => value.isNotEmpty)
                  .toSet()
                  .toList();

      return LibrarySong(
        id: row['id'] as int,
        path: row['path'] as String,
        thumbnailPath: row['thumbnailPath'] as String,
        title: _normalizeTagText(row['title'] as String),
        artist: artist,
        artists: artists.isEmpty ? [artist] : artists,
        album: _normalizeTagText(row['album'] as String),
        duration: row['duration'] as int,
        playCount: row['playCount'] as int,
        lyricsOffsetMs: row['lyricsOffsetMs'] as int,
        dateAdded: row['dateAdded'] as String,
        favorite: (row['favorite'] as int) != 0,
      );
    }).toList();
  }

  String _readActiveSongPath(Database db, int songId) {
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
  }

  String _readSongPath(Database db, int songId) {
    final rows = db.select(
      '''
      SELECT Path AS path
      FROM Music
      WHERE Id = ?
      LIMIT 1
    ''',
      [songId],
    );
    return rows.first['path'] as String;
  }

  List<String> _readActiveSongPaths(Database db) {
    return db
        .select(
          '''
          SELECT Path AS path
          FROM Music
          WHERE State = ?
        ''',
          [_activeState],
        )
        .map((row) => row['path'] as String)
        .toList();
  }

  int? _readActiveFolderId(Database db, String folderPath) {
    final rows = db.select(
      '''
      SELECT Id AS id
      FROM Folder
      WHERE Path = ?
        AND State = ?
      LIMIT 1
    ''',
      [folderPath, _activeState],
    );
    return rows.isEmpty ? null : rows.first['id'] as int;
  }

  void _markScannedTablesInactive(Database db) {
    db.execute(
      '''
      UPDATE Music
      SET State = ?
      WHERE State NOT IN (?, ?)
    ''',
      [_inactiveState, _hiddenState, _parentHiddenState],
    );
    db.execute(
      '''
      UPDATE Folder
      SET State = ?
      WHERE State NOT IN (?, ?)
    ''',
      [_inactiveState, _hiddenState, _parentHiddenState],
    );
    db.execute(
      '''
      UPDATE File
      SET State = ?
      WHERE State NOT IN (?, ?)
    ''',
      [_inactiveState, _hiddenState, _parentHiddenState],
    );
  }

  void _markScannedFoldersInactive(Database db, String folderPath) {
    db.execute(
      '''
      UPDATE Folder
      SET State = ?
      WHERE State NOT IN (?, ?)
        AND (Path = ? OR Path LIKE ? OR Path LIKE ?)
    ''',
      [
        _inactiveState,
        _hiddenState,
        _parentHiddenState,
        folderPath,
        '$folderPath/%',
        '$folderPath\\%',
      ],
    );
  }

  List<({int id, String path})> _readActiveSongsForLocalItems(
    Database db,
    List<int> songIds,
    List<String> folderPaths,
  ) {
    final clauses = <String>[];
    final args = <Object?>[];
    if (songIds.isNotEmpty) {
      clauses.add('Id IN (${List.filled(songIds.length, '?').join(', ')})');
      args.addAll(songIds);
    }
    for (final folderPath in folderPaths) {
      clauses.add('(Path LIKE ? OR Path LIKE ?)');
      args
        ..add('$folderPath/%')
        ..add('$folderPath\\%');
    }

    final rows = db.select(
      '''
      SELECT Id AS id, Path AS path
      FROM Music
      WHERE State = ?
        AND (${clauses.join(' OR ')})
    ''',
      [_activeState, ...args],
    );
    return [
      for (final row in rows)
        (id: row['id'] as int, path: row['path'] as String),
    ];
  }

  void _updatePathPrefixInsideTransaction(
    Database db, {
    required String table,
    required String oldPath,
    required String newPath,
  }) {
    db.execute(
      '''
      UPDATE $table
      SET Path = ? || substr(Path, ?)
      WHERE Path = ?
        OR Path LIKE ?
        OR Path LIKE ?
    ''',
      [newPath, oldPath.length + 1, oldPath, '$oldPath/%', '$oldPath\\%'],
    );
  }

  void _updateFolderPathStateInsideTransaction(
    Database db,
    List<String> folderPaths,
    int state,
  ) {
    for (final folderPath in folderPaths) {
      db.execute(
        '''
        UPDATE Folder
        SET State = ?
        WHERE Path = ?
          OR Path LIKE ?
          OR Path LIKE ?
      ''',
        [state, folderPath, '$folderPath/%', '$folderPath\\%'],
      );
      db.execute(
        '''
        UPDATE Music
        SET State = ?
        WHERE Path LIKE ?
          OR Path LIKE ?
      ''',
        [state, '$folderPath/%', '$folderPath\\%'],
      );
      db.execute(
        '''
        UPDATE File
        SET State = ?
        WHERE Path LIKE ?
          OR Path LIKE ?
      ''',
        [state, '$folderPath/%', '$folderPath\\%'],
      );
    }
  }

  void _hideFolderPathStateInsideTransaction(Database db, String folderPath) {
    db.execute(
      '''
      UPDATE Folder
      SET State = ?
      WHERE Path = ?
    ''',
      [_hiddenState, folderPath],
    );
    db.execute(
      '''
      UPDATE Folder
      SET State = ?
      WHERE Path LIKE ?
         OR Path LIKE ?
    ''',
      [_parentHiddenState, '$folderPath/%', '$folderPath\\%'],
    );
    db.execute(
      '''
      UPDATE Music
      SET State = ?
      WHERE Path LIKE ?
         OR Path LIKE ?
    ''',
      [_parentHiddenState, '$folderPath/%', '$folderPath\\%'],
    );
    db.execute(
      '''
      UPDATE File
      SET State = ?
      WHERE Path LIKE ?
         OR Path LIKE ?
    ''',
      [_parentHiddenState, '$folderPath/%', '$folderPath\\%'],
    );
  }

  void _resumeHiddenFolderInsideTransaction(Database db, String folderPath) {
    db.execute(
      '''
      UPDATE HiddenStorageItem
      SET State = ?
      WHERE Path = ?
         OR Path LIKE ?
         OR Path LIKE ?
    ''',
      [_inactiveState, folderPath, '$folderPath/%', '$folderPath\\%'],
    );
    db.execute(
      '''
      UPDATE Folder
      SET State = ?
      WHERE Path = ?
         OR Path LIKE ?
         OR Path LIKE ?
    ''',
      [_activeState, folderPath, '$folderPath/%', '$folderPath\\%'],
    );
    db.execute(
      '''
      UPDATE Music
      SET State = ?
      WHERE Path LIKE ?
         OR Path LIKE ?
    ''',
      [_activeState, '$folderPath/%', '$folderPath\\%'],
    );
    db.execute(
      '''
      UPDATE File
      SET State = ?
      WHERE Path LIKE ?
         OR Path LIKE ?
    ''',
      [_activeState, '$folderPath/%', '$folderPath\\%'],
    );
  }

  void _syncHiddenItemsFromStorageState(Database db) {
    db.execute(
      '''
      UPDATE HiddenStorageItem
      SET State = ?
      WHERE Type = 'folder'
        AND Path IN (SELECT Path FROM Folder WHERE State = ?)
    ''',
      [_activeState, _hiddenState],
    );
    db.execute(
      '''
      INSERT INTO HiddenStorageItem (Type, Path, State)
      SELECT 'folder', Folder.Path, ?
      FROM Folder
      WHERE State = ?
        AND NOT EXISTS (
          SELECT 1
          FROM HiddenStorageItem
          WHERE HiddenStorageItem.Type = 'folder'
            AND HiddenStorageItem.Path = Folder.Path
        )
    ''',
      [_activeState, _hiddenState],
    );
    db.execute(
      '''
      UPDATE HiddenStorageItem
      SET State = ?
      WHERE Type = 'file'
        AND Path IN (SELECT Path FROM File WHERE State = ?)
    ''',
      [_activeState, _hiddenState],
    );
    db.execute(
      '''
      INSERT INTO HiddenStorageItem (Type, Path, State)
      SELECT 'file', File.Path, ?
      FROM File
      WHERE State = ?
        AND NOT EXISTS (
          SELECT 1
          FROM HiddenStorageItem
          WHERE HiddenStorageItem.Type = 'file'
            AND HiddenStorageItem.Path = File.Path
        )
    ''',
      [_activeState, _hiddenState],
    );
  }

  void _syncStorageStateFromHiddenItems(Database db) {
    db.execute(
      '''
      UPDATE Folder
      SET State = ?
      WHERE EXISTS (
        SELECT 1
        FROM HiddenStorageItem
        WHERE HiddenStorageItem.Type = 'folder'
          AND HiddenStorageItem.Path = Folder.Path
          AND HiddenStorageItem.State = ?
      )
    ''',
      [_hiddenState, _activeState],
    );
    db.execute(
      '''
      UPDATE Folder
      SET State = ?
      WHERE State != ?
        AND EXISTS (
          SELECT 1
          FROM HiddenStorageItem
          WHERE HiddenStorageItem.Type = 'folder'
            AND HiddenStorageItem.State = ?
            AND (
              Folder.Path LIKE HiddenStorageItem.Path || '/%'
              OR Folder.Path LIKE HiddenStorageItem.Path || '\\%'
            )
        )
    ''',
      [_parentHiddenState, _hiddenState, _activeState],
    );
    db.execute(
      '''
      UPDATE Music
      SET State = ?
      WHERE EXISTS (
        SELECT 1
        FROM HiddenStorageItem
        WHERE HiddenStorageItem.Type = 'file'
          AND HiddenStorageItem.Path = Music.Path
          AND HiddenStorageItem.State = ?
      )
    ''',
      [_hiddenState, _activeState],
    );
    db.execute(
      '''
      UPDATE File
      SET State = ?
      WHERE EXISTS (
        SELECT 1
        FROM HiddenStorageItem
        WHERE HiddenStorageItem.Type = 'file'
          AND HiddenStorageItem.Path = File.Path
          AND HiddenStorageItem.State = ?
      )
    ''',
      [_hiddenState, _activeState],
    );
    db.execute(
      '''
      UPDATE Music
      SET State = ?
      WHERE State != ?
        AND EXISTS (
          SELECT 1
          FROM HiddenStorageItem
          WHERE HiddenStorageItem.Type = 'folder'
            AND HiddenStorageItem.State = ?
            AND (
              Music.Path LIKE HiddenStorageItem.Path || '/%'
              OR Music.Path LIKE HiddenStorageItem.Path || '\\%'
            )
        )
    ''',
      [_parentHiddenState, _hiddenState, _activeState],
    );
    db.execute(
      '''
      UPDATE File
      SET State = ?
      WHERE State != ?
        AND EXISTS (
          SELECT 1
          FROM HiddenStorageItem
          WHERE HiddenStorageItem.Type = 'folder'
            AND HiddenStorageItem.State = ?
            AND (
              File.Path LIKE HiddenStorageItem.Path || '/%'
              OR File.Path LIKE HiddenStorageItem.Path || '\\%'
            )
        )
    ''',
      [_parentHiddenState, _hiddenState, _activeState],
    );
  }

  void _deleteSongsInsideTransaction(
    Database db,
    List<int> songIds,
    List<String> songPaths,
  ) {
    final songPlaceholders = List.filled(songIds.length, '?').join(', ');
    db.execute(
      '''
      UPDATE Music
      SET State = ?
      WHERE Id IN ($songPlaceholders)
    ''',
      [_inactiveState, ...songIds],
    );
    db.execute(
      '''
      UPDATE MusicArtist
      SET State = ?
      WHERE MusicId IN ($songPlaceholders)
    ''',
      [_inactiveState, ...songIds],
    );
    db.execute(
      '''
      UPDATE PlaylistItem
      SET State = ?
      WHERE ItemId IN ($songPlaceholders)
    ''',
      [_inactiveState, ...songIds],
    );
    db.execute(
      '''
      UPDATE RecentRecord
      SET State = ?
      WHERE Type = $_recentRecordTypeSong
        AND ItemId IN ($songPlaceholders)
    ''',
      [_inactiveState, ...songIds.map((songId) => songId.toString())],
    );

    final pathPlaceholders = List.filled(songPaths.length, '?').join(', ');
    db.execute(
      '''
      UPDATE File
      SET State = ?
      WHERE Path IN ($pathPlaceholders)
    ''',
      [_inactiveState, ...songPaths],
    );
    db.execute(
      '''
      UPDATE HiddenStorageItem
      SET State = ?
      WHERE Type = 'file'
        AND Path IN ($pathPlaceholders)
    ''',
      [_inactiveState, ...songPaths],
    );
  }

  void _updateMovedSongPathInsideTransaction(
    Database db,
    _RefreshMovedSong movedSong,
  ) {
    db.execute(
      '''
      UPDATE Music
      SET Path = ?
      WHERE Id = ?
        AND State = ?
    ''',
      [movedSong.newPath, movedSong.id, _activeState],
    );
    db.execute(
      '''
      UPDATE File
      SET Path = ?
      WHERE Path = ?
        AND State = ?
    ''',
      [movedSong.newPath, movedSong.oldPath, _activeState],
    );
  }

  void _restoreDeletedSongInsideTransaction(
    Database db,
    _PendingSongDeleteRecord record,
  ) {
    db.execute('UPDATE Music SET State = ? WHERE Id = ?', [
      _activeState,
      record.songId,
    ]);
    db.execute('UPDATE File SET State = ? WHERE Path = ?', [
      _activeState,
      record.songPath,
    ]);
    _restoreRowsById(db, 'MusicArtist', record.musicArtistIds);
    _restoreRowsById(db, 'PlaylistItem', record.playlistItemIds);
    _restoreRowsById(db, 'RecentRecord', record.recentRecordIds);
    _restoreRowsById(db, 'HiddenStorageItem', record.hiddenStorageItemIds);
  }

  void _restoreDeletedLocalItemsInsideTransaction(
    Database db,
    _PendingLocalItemsDeleteRecord record,
  ) {
    _restoreRowsById(db, 'Music', record.musicIds);
    _restoreRowsById(db, 'MusicArtist', record.musicArtistIds);
    _restoreRowsById(db, 'PlaylistItem', record.playlistItemIds);
    _restoreRowsById(db, 'RecentRecord', record.recentRecordIds);
    _restoreRowsById(db, 'HiddenStorageItem', record.hiddenStorageItemIds);
    _restoreRowsById(db, 'Folder', record.folderIds);
    _restoreRowsById(db, 'File', record.fileIds);
  }

  void _restoreRowsById(Database db, String table, List<int> rowIds) {
    if (rowIds.isEmpty) {
      return;
    }

    final placeholders = List.filled(rowIds.length, '?').join(', ');
    db.execute(
      '''
      UPDATE $table
      SET State = ?
      WHERE Id IN ($placeholders)
    ''',
      [_activeState, ...rowIds],
    );
  }

  List<int> _readActiveRowIds(
    Database db,
    String table,
    String column,
    int value,
  ) {
    return db
        .select(
          '''
          SELECT Id AS id
          FROM $table
          WHERE $column = ?
            AND State = ?
        ''',
          [value, _activeState],
        )
        .map((row) => row['id'] as int)
        .toList();
  }

  List<int> _readActiveRecentSongRowIds(Database db, int songId) {
    return db
        .select(
          '''
          SELECT Id AS id
          FROM RecentRecord
          WHERE Type = $_recentRecordTypeSong
            AND ItemId = ?
            AND State = ?
        ''',
          [songId.toString(), _activeState],
        )
        .map((row) => row['id'] as int)
        .toList();
  }

  List<int> _readActiveHiddenFileRowIds(Database db, String songPath) {
    return db
        .select(
          '''
          SELECT Id AS id
          FROM HiddenStorageItem
          WHERE Type = 'file'
            AND Path = ?
            AND State = ?
        ''',
          [songPath, _activeState],
        )
        .map((row) => row['id'] as int)
        .toList();
  }

  List<int> _readActiveRowsForSongIds(
    Database db,
    String table,
    String column,
    List<int> songIds,
  ) {
    if (songIds.isEmpty) {
      return const [];
    }

    final placeholders = List.filled(songIds.length, '?').join(', ');
    return db
        .select(
          '''
          SELECT Id AS id
          FROM $table
          WHERE $column IN ($placeholders)
            AND State = ?
        ''',
          [...songIds, _activeState],
        )
        .map((row) => row['id'] as int)
        .toList();
  }

  List<int> _readActiveRecentSongRowsForSongIds(
    Database db,
    List<int> songIds,
  ) {
    if (songIds.isEmpty) {
      return const [];
    }

    final placeholders = List.filled(songIds.length, '?').join(', ');
    return db
        .select(
          '''
          SELECT Id AS id
          FROM RecentRecord
          WHERE Type = $_recentRecordTypeSong
            AND ItemId IN ($placeholders)
            AND State = ?
        ''',
          [...songIds.map((songId) => songId.toString()), _activeState],
        )
        .map((row) => row['id'] as int)
        .toList();
  }

  List<int> _readActiveHiddenFileRowsForPaths(
    Database db,
    List<String> songPaths,
  ) {
    if (songPaths.isEmpty) {
      return const [];
    }

    final placeholders = List.filled(songPaths.length, '?').join(', ');
    return db
        .select(
          '''
          SELECT Id AS id
          FROM HiddenStorageItem
          WHERE Type = 'file'
            AND Path IN ($placeholders)
            AND State = ?
        ''',
          [...songPaths, _activeState],
        )
        .map((row) => row['id'] as int)
        .toList();
  }

  List<int> _readActiveHiddenFolderRowsForPaths(
    Database db,
    List<String> folderPaths,
  ) {
    if (folderPaths.isEmpty) {
      return const [];
    }

    final placeholders = List.filled(folderPaths.length, '?').join(', ');
    return db
        .select(
          '''
          SELECT Id AS id
          FROM HiddenStorageItem
          WHERE Type = 'folder'
            AND Path IN ($placeholders)
            AND State = ?
        ''',
          [...folderPaths, _activeState],
        )
        .map((row) => row['id'] as int)
        .toList();
  }

  ({List<String> folderPaths, List<String> filePaths})
  _readActiveHiddenStoragePaths(Database db) {
    final rows = db.select(
      '''
      SELECT Type AS type, Path AS path
      FROM HiddenStorageItem
      WHERE State = ?
    ''',
      [_activeState],
    );
    return (
      folderPaths: [
        for (final row in rows)
          if (row['type'] == 'folder') row['path'] as String,
      ],
      filePaths: [
        for (final row in rows)
          if (row['type'] == 'file') row['path'] as String,
      ],
    );
  }

  List<int> _readActiveFolderRowIdsForPaths(
    Database db,
    List<String> folderPaths,
  ) {
    if (folderPaths.isEmpty) {
      return const [];
    }

    final clauses = folderPaths
        .map((_) => '(Path = ? OR Path LIKE ? OR Path LIKE ?)')
        .join(' OR ');
    return db
        .select(
          '''
          SELECT Id AS id
          FROM Folder
          WHERE State = ?
            AND ($clauses)
        ''',
          [
            _activeState,
            for (final folderPath in folderPaths) ...[
              folderPath,
              '$folderPath/%',
              '$folderPath\\%',
            ],
          ],
        )
        .map((row) => row['id'] as int)
        .toList();
  }

  List<int> _readActiveFileRowIdsForPaths(
    Database db,
    List<String> songPaths,
    List<String> folderPaths,
  ) {
    final clauses = <String>[];
    final args = <Object?>[];
    if (songPaths.isNotEmpty) {
      clauses.add('Path IN (${List.filled(songPaths.length, '?').join(', ')})');
      args.addAll(songPaths);
    }
    for (final folderPath in folderPaths) {
      clauses.add('(Path LIKE ? OR Path LIKE ?)');
      args
        ..add('$folderPath/%')
        ..add('$folderPath\\%');
    }
    if (clauses.isEmpty) {
      return const [];
    }

    return db
        .select(
          '''
          SELECT Id AS id
          FROM File
          WHERE State = ?
            AND (${clauses.join(' OR ')})
        ''',
          [_activeState, ...args],
        )
        .map((row) => row['id'] as int)
        .toList();
  }

  void _upsertHiddenStorageItem(Database db, String type, String itemPath) {
    db.execute(
      '''
      UPDATE HiddenStorageItem
      SET State = ?
      WHERE Type = ?
        AND Path = ?
    ''',
      [_activeState, type, itemPath],
    );

    final changedRows =
        db.select('SELECT changes() AS count').first['count'] as int;
    if (changedRows == 0) {
      db.execute(
        '''
        INSERT INTO HiddenStorageItem (Type, Path, State)
        VALUES (?, ?, ?)
      ''',
        [type, itemPath, _activeState],
      );
    }
  }

  Future<bool> _mergeLocalFolderIntoExistingTarget({
    required String sourceFolderPath,
    required String targetFolderPath,
    required List<_LocalFileMove> movedFiles,
    required List<LocalFolderMove> movedFolders,
    required List<String> inactiveFolders,
    LocalMoveConflictResolver? resolveConflict,
  }) async {
    var movedAll = true;
    final entries = Directory(sourceFolderPath).listSync(followLinks: false);
    for (final entry in entries) {
      final sourcePath = entry.path;
      final targetPath = p.join(targetFolderPath, p.basename(sourcePath));
      final sourceType = FileSystemEntity.typeSync(
        sourcePath,
        followLinks: false,
      );

      if (sourceType == FileSystemEntityType.directory) {
        final targetType = FileSystemEntity.typeSync(targetPath);
        if (targetType == FileSystemEntityType.notFound) {
          await Directory(sourcePath).rename(targetPath);
          movedFolders.add(
            LocalFolderMove(oldPath: sourcePath, newPath: targetPath),
          );
          continue;
        }
        if (targetType != FileSystemEntityType.directory) {
          throw StateError('Target path already exists and is not a folder.');
        }
        final childMovedAll = await _mergeLocalFolderIntoExistingTarget(
          sourceFolderPath: sourcePath,
          targetFolderPath: targetPath,
          movedFiles: movedFiles,
          movedFolders: movedFolders,
          inactiveFolders: inactiveFolders,
          resolveConflict: resolveConflict,
        );
        movedAll = childMovedAll && movedAll;
        continue;
      }

      if (sourceType == FileSystemEntityType.file) {
        final target = await _resolveLocalFileMoveTarget(
          sourcePath: sourcePath,
          targetFolderPath: targetFolderPath,
          resolveConflict: resolveConflict,
        );
        if (target == null) {
          movedAll = false;
          continue;
        }
        await File(sourcePath).rename(target.path);
        movedFiles.add(
          _LocalFileMove(
            oldPath: sourcePath,
            newPath: target.path,
            replacedPath: target.replacedPath,
          ),
        );
        continue;
      }

      movedAll = false;
    }

    if (Directory(sourceFolderPath).listSync(followLinks: false).isEmpty) {
      await Directory(sourceFolderPath).delete();
      inactiveFolders.add(sourceFolderPath);
      return movedAll;
    }
    return false;
  }

  void _markLocalFilePathInactiveInsideTransaction(
    Database db,
    String filePath, {
    int? exceptSongId,
  }) {
    if (exceptSongId == null) {
      db.execute(
        '''
        UPDATE Music
        SET State = ?
        WHERE Path = ?
          AND State = ?
      ''',
        [_inactiveState, filePath, _activeState],
      );
    } else {
      db.execute(
        '''
        UPDATE Music
        SET State = ?
        WHERE Path = ?
          AND Id <> ?
          AND State = ?
      ''',
        [_inactiveState, filePath, exceptSongId, _activeState],
      );
    }
    db.execute(
      '''
      UPDATE File
      SET State = ?
      WHERE Path = ?
    ''',
      [_inactiveState, filePath],
    );
    db.execute(
      '''
      UPDATE HiddenStorageItem
      SET State = ?
      WHERE Type = 'file'
        AND Path = ?
    ''',
      [_inactiveState, filePath],
    );
  }

  void _markLocalFolderInactiveInsideTransaction(
    Database db,
    String folderPath,
  ) {
    db.execute(
      '''
      UPDATE Folder
      SET State = ?
      WHERE Path = ?
    ''',
      [_inactiveState, folderPath],
    );
    db.execute(
      '''
      UPDATE HiddenStorageItem
      SET State = ?
      WHERE Type = 'folder'
        AND Path = ?
    ''',
      [_inactiveState, folderPath],
    );
  }

  Future<_LocalResolvedFileMoveTarget?> _resolveLocalFileMoveTarget({
    required String sourcePath,
    required String targetFolderPath,
    LocalMoveConflictResolver? resolveConflict,
  }) async {
    var targetPath = p.join(targetFolderPath, p.basename(sourcePath));
    if (FileSystemEntity.typeSync(targetPath) ==
        FileSystemEntityType.notFound) {
      return _LocalResolvedFileMoveTarget(path: targetPath);
    }

    final resolution =
        resolveConflict == null
            ? LocalMoveConflictResolution.keepBoth
            : await resolveConflict(sourcePath, targetPath);
    return switch (resolution) {
      LocalMoveConflictResolution.skip => null,
      LocalMoveConflictResolution.keepBoth => _LocalResolvedFileMoveTarget(
        path: _getAvailableSiblingPath(targetPath),
      ),
      LocalMoveConflictResolution.replace => _LocalResolvedFileMoveTarget(
        path: await _replaceLocalMoveTarget(targetPath),
        replacedPath: targetPath,
      ),
    };
  }

  Future<String> _replaceLocalMoveTarget(String targetPath) async {
    await File(targetPath).delete();
    return targetPath;
  }

  String _getAvailableSiblingPath(String targetPath) {
    final extension = p.extension(targetPath);
    final basePath = targetPath.substring(
      0,
      targetPath.length - extension.length,
    );
    var index = 1;
    var nextPath = '$basePath ($index)$extension';
    while (FileSystemEntity.typeSync(nextPath) !=
        FileSystemEntityType.notFound) {
      index += 1;
      nextPath = '$basePath ($index)$extension';
    }
    return nextPath;
  }

  List<String> _readSongArtists(
    Database db,
    int songId,
    String fallbackArtist,
  ) {
    final rows = db.select(
      '''
      SELECT Name AS name
      FROM MusicArtist
      WHERE MusicId = ?
        AND State = ?
      ORDER BY Priority, Id
    ''',
      [songId, _activeState],
    );
    final artists = _normalizeArtists(
      rows.map((row) => row['name'] as String).toList(),
    );
    if (artists.isNotEmpty) {
      return artists;
    }

    return _normalizeArtists([fallbackArtist]);
  }

  void _syncSongArtists(Database db, int songId, List<String> artists) {
    db.execute('UPDATE MusicArtist SET State = ? WHERE MusicId = ?', [
      _inactiveState,
      songId,
    ]);
    if (artists.isEmpty) {
      return;
    }

    final values = List.filled(artists.length, '(?, ?, ?, ?)').join(', ');
    db.execute(
      '''
      INSERT INTO MusicArtist (MusicId, Name, Priority, State)
      VALUES $values
    ''',
      [
        for (final entry in artists.indexed) ...[
          songId,
          entry.$2,
          entry.$1,
          _activeState,
        ],
      ],
    );
  }

  Future<Map<String, _AudioFileMetadata>> _readAudioFileMetadataBatch(
    List<String> filePaths, {
    LocalFolderScanCancellation? cancellation,
    void Function(String filePath, int completedCount)? onProgress,
  }) async {
    const concurrency = 6;
    final metadataByPath = <String, _AudioFileMetadata>{};
    var nextIndex = 0;
    var completedCount = 0;

    Future<void> worker() async {
      while (nextIndex < filePaths.length) {
        cancellation?.throwIfCanceled();
        final filePath = filePaths[nextIndex];
        nextIndex += 1;
        metadataByPath[filePath] = await _readAudioFileMetadata(filePath);
        completedCount += 1;
        onProgress?.call(filePath, completedCount);
        cancellation?.throwIfCanceled();
      }
    }

    await Future.wait([
      for (
        var workerIndex = 0;
        workerIndex < min(concurrency, filePaths.length);
        workerIndex += 1
      )
        worker(),
    ]);
    return metadataByPath;
  }

  Future<_AudioFileMetadata> _readAudioFileMetadata(String filePath) async {
    final properties = await _id3TagService.readSongTagProperties(filePath);
    final duration = await _id3TagService.readDurationSeconds(filePath);
    final thumbnailPath = await _cacheSongArtwork(filePath);
    return _AudioFileMetadata(
      properties: properties,
      duration: duration,
      thumbnailPath: thumbnailPath,
    );
  }

  int _upsertExternalAudioFile(
    Database db,
    String filePath, {
    required _AudioFileMetadata metadata,
    bool useFilenameNotMusicName = false,
  }) {
    final properties = metadata.properties;
    final title =
        useFilenameNotMusicName || properties.title.trim().isEmpty
            ? p.basenameWithoutExtension(filePath)
            : properties.title.trim();
    final artists =
        _normalizeArtists(
          properties.artists.isNotEmpty
              ? properties.artists
              : [properties.artist],
        ).take(6).toList();
    final artist = artists.join(', ');
    final album = properties.album.trim();
    final dateAdded = DateTime.now().toIso8601String();
    final rows = db.select(
      '''
      INSERT INTO Music (
        Path,
        Name,
        Artist,
        Album,
        ThumbnailPath,
        Duration,
        PlayCount,
        DateAdded,
        State
      )
      VALUES (
        ?, ?, ?, ?, ?, ?,
        COALESCE((SELECT PlayCount FROM Music WHERE Path = ?), 0),
        COALESCE((SELECT DateAdded FROM Music WHERE Path = ?), ?),
        ?
      )
      ON CONFLICT(Path) DO UPDATE SET
        Name = excluded.Name,
        Artist = excluded.Artist,
        Album = excluded.Album,
        ThumbnailPath = excluded.ThumbnailPath,
        Duration = excluded.Duration,
        State = excluded.State
      RETURNING Id AS id
    ''',
      [
        filePath,
        title,
        artist,
        album,
        metadata.thumbnailPath,
        metadata.duration,
        filePath,
        filePath,
        dateAdded,
        _activeState,
      ],
    );
    final songId = rows.first['id'] as int;
    _syncSongArtists(db, songId, artists);
    return songId;
  }

  Future<String> _cacheSongArtwork(String filePath) async {
    final picture = await _id3TagService.readFirstPicture(filePath);
    if (picture != null && _isLikelyImage(picture.data)) {
      return _writeArtworkCacheBytes(
        picture.data,
        _extensionForMimeType(picture.format),
      );
    }

    final siblingArtwork = _findSiblingFolderArtwork(filePath);
    if (siblingArtwork != null) {
      final data = await siblingArtwork.readAsBytes();
      if (_isLikelyImage(data)) {
        return _writeArtworkCacheBytes(data, p.extension(siblingArtwork.path));
      }
    }

    final shellThumbnail = await _shellThumbnailResolver(filePath);
    if (shellThumbnail != null && _isLikelyImage(shellThumbnail.data)) {
      return _writeArtworkCacheBytes(
        shellThumbnail.data,
        shellThumbnail.extension,
      );
    }
    return '';
  }

  Future<String> _writeArtworkCacheBytes(
    List<int> data,
    String extension,
  ) async {
    final cacheDirectory = await _resolveArtworkCacheDirectory();
    final artworkHash = sha1.convert(data).toString();
    final normalizedExtension =
        extension.isEmpty
            ? '.jpg'
            : extension.startsWith('.')
            ? extension
            : '.$extension';
    final target = File(
      p.join(cacheDirectory.path, '$artworkHash$normalizedExtension'),
    );
    if (!target.existsSync()) {
      await target.writeAsBytes(data);
    }
    return target.path;
  }

  File? _findSiblingFolderArtwork(String filePath) {
    final directory = Directory(p.dirname(filePath));
    if (!directory.existsSync()) {
      return null;
    }
    final filesByLowerName = <String, File>{};
    for (final entity in directory.listSync()) {
      if (entity is File) {
        filesByLowerName[p.basename(entity.path).toLowerCase()] = entity;
      }
    }
    for (final baseName in _folderArtworkBaseNames) {
      for (final extension in _folderArtworkExtensions) {
        final file = filesByLowerName['$baseName$extension'];
        if (file != null) {
          return file;
        }
      }
    }
    return null;
  }

  int _upsertScannedAudioFile(
    Database db,
    String filePath,
    Map<String, int> folderIds, {
    required _AudioFileMetadata metadata,
    required bool useFilenameNotMusicName,
  }) {
    final songId = _upsertExternalAudioFile(
      db,
      filePath,
      metadata: metadata,
      useFilenameNotMusicName: useFilenameNotMusicName,
    );
    final parentId = folderIds[_pathComparisonKey(p.dirname(filePath))] ?? 0;
    db.select(
      '''
      INSERT INTO File (Path, ParentId, FileId, FileType, State)
      VALUES (?, ?, ?, 0, ?)
      ON CONFLICT(Path) DO UPDATE SET
        ParentId = excluded.ParentId,
        FileId = excluded.FileId,
        State = excluded.State
      RETURNING Id AS id
    ''',
      [filePath, parentId, songId, _activeState],
    );
    return songId;
  }

  Map<String, int> _upsertScannedFolders(
    Database db,
    String rootPath,
    List<String> folderPaths,
  ) {
    final folderIds = <String, int>{};
    final sortedFolders =
        folderPaths.toList()..sort(
          (left, right) => _pathDepth(left).compareTo(_pathDepth(right)),
        );
    final rootKey = _pathComparisonKey(rootPath);
    for (final folderPath in sortedFolders) {
      final folderKey = _pathComparisonKey(folderPath);
      final parentId =
          folderKey == rootKey
              ? 0
              : folderIds[_pathComparisonKey(p.dirname(folderPath))] ??
                  _readActiveFolderId(db, p.dirname(folderPath)) ??
                  0;
      final rows = db.select(
        '''
        INSERT INTO Folder (Path, Criterion, ParentId, State)
        VALUES (?, 0, ?, ?)
        ON CONFLICT(Path) DO UPDATE SET
          ParentId = excluded.ParentId,
          State = excluded.State
        RETURNING Id AS id
      ''',
        [folderPath, parentId, _activeState],
      );
      folderIds[folderKey] = rows.first['id'] as int;
    }
    return folderIds;
  }

  void _setRootPath(Database db, String rootPath) {
    db.execute('UPDATE Settings SET RootPath = ?', [rootPath]);
    final changedRows =
        db.select('SELECT changes() AS count').first['count'] as int;
    if (changedRows == 0) {
      db.execute('INSERT INTO Settings (RootPath) VALUES (?)', [rootPath]);
    }
  }

  String _readDatabaseRootPath(File databaseFile) {
    final db = sqlite3.open(databaseFile.path);
    try {
      final rows = db.select(
        'SELECT RootPath AS rootPath FROM Settings ORDER BY Id LIMIT 1',
      );
      return rows.isEmpty ? '' : rows.first['rootPath'] as String;
    } finally {
      db.dispose();
    }
  }

  void _replaceRootPathReferences(
    File databaseFile, {
    required String originalPath,
    required String nextPath,
  }) {
    final db = sqlite3.open(databaseFile.path);
    try {
      db.execute('BEGIN');
      try {
        db.execute('UPDATE Settings SET RootPath = replace(RootPath, ?, ?)', [
          originalPath,
          nextPath,
        ]);
        db.execute('UPDATE OR REPLACE Music SET Path = replace(Path, ?, ?)', [
          originalPath,
          nextPath,
        ]);
        db.execute('UPDATE OR REPLACE Folder SET Path = replace(Path, ?, ?)', [
          originalPath,
          nextPath,
        ]);
        db.execute('UPDATE OR REPLACE File SET Path = replace(Path, ?, ?)', [
          originalPath,
          nextPath,
        ]);
        db.execute(
          'UPDATE OR REPLACE HiddenStorageItem SET Path = replace(Path, ?, ?)',
          [originalPath, nextPath],
        );
        db.execute('COMMIT');
      } on Object {
        db.execute('ROLLBACK');
        rethrow;
      }
    } finally {
      db.dispose();
    }
  }

  Future<String> _getSongPath(int songId) async {
    final databaseFile = await _resolveDatabaseFile();
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

  Future<_LyricsSongLookup> _getLyricsSongLookup(int songId) async {
    final databaseFile = await _resolveDatabaseFile();
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
    final songMid = await _getSongMid(song);
    if (songMid.isEmpty) {
      return '';
    }

    final uri = Uri.parse(
      'https://c.y.qq.com/lyric/fcgi-bin/fcg_query_lyric_new.fcg',
    ).replace(
      queryParameters: {'songmid': songMid, 'format': 'json', 'nobase64': '1'},
    );
    try {
      final response = await _fetchLyricsJson(uri);
      final lyrics =
          _decodeHtmlEntities(response['lyric'] as String? ?? '').trim();
      if (lyrics.isEmpty || _isNoLyricsPlaceholder(lyrics)) {
        return '';
      }

      return lyrics;
    } catch (_) {
      return '';
    }
  }

  Future<LyricsSnapshot?> _getSyncedInternetLyrics(
    _LyricsSongLookup song,
  ) async {
    final rawLyrics = await _searchInternetLyrics(song);
    if (rawLyrics.trim().isEmpty) {
      return null;
    }

    final internetLyrics = await _prepareInternetLyrics(rawLyrics);
    final snapshot = _createLyricsSnapshot(
      internetLyrics,
      LyricsSource.internet,
    );
    return snapshot.isSynced && snapshot.lines.isNotEmpty ? snapshot : null;
  }

  Future<String> _prepareInternetLyrics(String rawLyrics) async {
    if (_isNoLyricsPlaceholder(rawLyrics)) {
      return '';
    }

    final snapshot = await getSettingsSnapshot();
    return (snapshot == null || snapshot.preserveInternetLyricsTimestamps)
        ? rawLyrics
        : _stripLyricsTimestamps(rawLyrics);
  }

  String _stripLyricsTimestamps(String rawText) {
    final timestampRegex = RegExp(r'\[\d{1,2}:\d{2}(?:[.:]\d{1,3})?\]');
    final metadataRegex = RegExp(
      r'^\[(ti|ar|al|by|offset):.*\]$',
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
      ),
      _LyricsSearchAttempt(
        keyword: song.title,
        title: song.title,
        artist: song.artist,
      ),
      _LyricsSearchAttempt(
        keyword: '$simplifiedTitle ${song.artist}'.trim(),
        title: simplifiedTitle,
        artist: song.artist,
      ),
      _LyricsSearchAttempt(
        keyword: '${song.title} $simplifiedArtist'.trim(),
        title: song.title,
        artist: simplifiedArtist,
      ),
      _LyricsSearchAttempt(
        keyword: '$simplifiedTitle $simplifiedArtist'.trim(),
        title: simplifiedTitle,
        artist: simplifiedArtist,
      ),
      _LyricsSearchAttempt(
        keyword: simplifiedTitle,
        title: simplifiedTitle,
        artist: simplifiedArtist,
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
              RegExp(r'\[(ti|ar|al|by|offset):[^\]]*\]', caseSensitive: false),
              ' ',
            )
            .replaceAll(RegExp(r'\[\d{1,2}:\d{2}(?:[.:]\d{1,3})?\]'), ' ')
            .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), '')
            .toLowerCase();
    if (normalized.isEmpty) {
      return false;
    }

    return normalized.contains('姝ゆ瓕鏇蹭负娌℃湁濉瘝鐨勭函闊充箰璇锋偍娆ｈ祻');
  }

  String _normalizeLyricsForCompare(String rawLyrics) {
    return rawLyrics
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .join('\n');
  }

  Future<LyricsSnapshot?> _getSidecarLyrics(String songPath) async {
    final lrcFile = File(p.setExtension(songPath, '.lrc'));
    if (await lrcFile.exists()) {
      return _createLyricsSnapshot(
        await lrcFile.readAsString(),
        LyricsSource.lrcFile,
      );
    }

    final textFile = File(p.setExtension(songPath, '.txt'));
    if (await textFile.exists()) {
      return _createLyricsSnapshot(
        await textFile.readAsString(),
        LyricsSource.textFile,
      );
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
      r'^\[(ti|ar|al|by|offset):',
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
        parsedLines.add(LyricsLine(id: lineId, timestampMs: null, text: text));
        lineId += 1;
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
            timestampMs:
                minutes * 60000 + seconds * 1000 + fractionMs + offsetMs,
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
        return 1;
      }
      if (rightTimestamp == null) {
        return -1;
      }
      final timestampCompare = leftTimestamp.compareTo(rightTimestamp);
      return timestampCompare == 0
          ? left.id.compareTo(right.id)
          : timestampCompare;
    });
    return parsedLines;
  }

  Future<SongArtworkSnapshot> _resolveSongArtworkSnapshot(
    Database db,
    int songId,
    String songPath,
    String thumbnailPath,
  ) async {
    if (thumbnailPath.isNotEmpty && File(thumbnailPath).existsSync()) {
      return _createSongArtworkSnapshot(songId, thumbnailPath);
    }

    final picture = await _id3TagService.readFirstPicture(songPath);
    if (picture == null) {
      return _createSongArtworkSnapshot(songId, '');
    }

    final cacheDirectory = await _resolveArtworkCacheDirectory();
    final target = File(
      p.join(
        cacheDirectory.path,
        '${DateTime.now().microsecondsSinceEpoch}_$songId${_extensionForMimeType(picture.format)}',
      ),
    );
    await target.writeAsBytes(picture.data);
    db.execute(
      '''
      UPDATE Music
      SET ThumbnailPath = ?
      WHERE Id = ?
        AND State = ?
    ''',
      [target.path, songId, _activeState],
    );
    return SongArtworkSnapshot(
      songId: songId,
      artworkUrl: target.path,
      sourceUrl: target.path,
      sourcePath: target.path,
      source: SongArtworkSource.embedded,
    );
  }

  SongArtworkSnapshot _createSongArtworkSnapshot(
    int songId,
    String thumbnailPath,
  ) {
    if (thumbnailPath.isEmpty || !File(thumbnailPath).existsSync()) {
      return SongArtworkSnapshot(
        songId: songId,
        artworkUrl: '',
        sourceUrl: '',
        sourcePath: '',
        source: SongArtworkSource.none,
      );
    }

    return SongArtworkSnapshot(
      songId: songId,
      artworkUrl: thumbnailPath,
      sourceUrl: thumbnailPath,
      sourcePath: thumbnailPath,
      source: SongArtworkSource.cached,
    );
  }

  Future<Directory> _resolveArtworkCacheDirectory() async {
    final databaseFile = await _resolveDatabaseFile();
    final directory = Directory(
      p.join(databaseFile.parent.path, 'ArtworkCache'),
    );
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
    return directory;
  }

  bool _isLikelyImage(List<int> data) {
    return _isLikelyArtworkImage(data);
  }

  Future<void> _pruneArtworkCache(Database db) async {
    try {
      final cacheDirectory = await _resolveArtworkCacheDirectory();
      final activeThumbnailPaths =
          db
              .select(
                '''
                SELECT ThumbnailPath AS thumbnailPath
                FROM Music
                WHERE State = ?
                  AND NULLIF(ThumbnailPath, '') IS NOT NULL
              ''',
                [_activeState],
              )
              .map((row) => row['thumbnailPath'] as String)
              .toSet();
      for (final entry in cacheDirectory.listSync()) {
        if (entry is! File) {
          continue;
        }
        if (activeThumbnailPaths.contains(entry.path)) {
          continue;
        }
        try {
          await entry.delete();
        } on Object {
          // Cache cleanup must not fail the library scan.
        }
      }
    } on Object {
      // Cache cleanup must not fail the library scan.
    }
  }

  String _getArtworkMimeType(String sourcePath) {
    return switch (p.extension(sourcePath).toLowerCase()) {
      '.jpg' || '.jpeg' => 'image/jpeg',
      '.png' => 'image/png',
      '.webp' => 'image/webp',
      '.bmp' => 'image/bmp',
      _ => 'image/jpeg',
    };
  }

  String _extensionForMimeType(String mimeType) {
    return switch (mimeType.toLowerCase()) {
      'image/jpeg' || 'image/jpg' => '.jpg',
      'image/png' => '.png',
      'image/webp' => '.webp',
      'image/bmp' => '.bmp',
      _ => '.jpg',
    };
  }

  List<LibraryFolder> _readFolders(Database db) {
    final rows = db.select(
      '''
      SELECT
        Id AS id,
        Path AS path,
        ParentId AS parentId,
        Criterion AS criterion
      FROM Folder
      WHERE State = ?
      ORDER BY Path COLLATE NOCASE
    ''',
      [_activeState],
    );

    return rows.map((row) {
      return LibraryFolder(
        id: row['id'] as int,
        path: row['path'] as String,
        parentId: row['parentId'] as int,
        criterion: row['criterion'] as int,
      );
    }).toList();
  }

  List<LibraryPlaylist> _readPlaylists(Database db, _LibrarySettings settings) {
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
      [
        _activeState,
        _activeState,
        _activeState,
        settings.myFavoritesId,
        settings.nowPlayingId,
      ],
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
        isBuiltIn: id == settings.myFavoritesId,
      );
    }).toList();
  }

  List<RecentLibrarySong> _readRecentSongs(
    Database db,
    List<LibrarySong> songs,
  ) {
    final rows = db.select(
      '''
      SELECT
        RecentRecord.ItemId AS itemId,
        CAST(RecentRecord.Time AS TEXT) AS playedAt
      FROM RecentRecord
      INNER JOIN Music
        ON Music.Id = CAST(RecentRecord.ItemId AS INTEGER)
      WHERE RecentRecord.Type = $_recentRecordTypeSong
        AND RecentRecord.State = ?
        AND Music.State = ?
      ORDER BY RecentRecord.Id DESC
      LIMIT ?
    ''',
      [_activeState, _activeState, _recentSongLimit],
    );
    final songsById = {for (final song in songs) song.id: song};
    return rows.expand((row) {
      final song = songsById[int.parse(row['itemId'] as String)];
      return song == null
          ? const <RecentLibrarySong>[]
          : [
            RecentLibrarySong.fromSong(
              song,
              playedAt: row['playedAt'] as String,
            ),
          ];
    }).toList();
  }

  List<RecentPlaylistPlayback> _readRecentPlaylists(Database db) {
    final rows = db.select(
      '''
      SELECT
        RecentRecord.Id AS id,
        RecentRecord.ItemId AS itemId,
        CAST(RecentRecord.Time AS TEXT) AS playedAt
      FROM RecentRecord
      INNER JOIN Playlist
        ON Playlist.Id = CAST(RecentRecord.ItemId AS INTEGER)
      WHERE RecentRecord.Type = $_recentRecordTypePlaylist
        AND RecentRecord.State = ?
        AND Playlist.State = ?
      ORDER BY RecentRecord.Id DESC
      LIMIT ?
    ''',
      [_activeState, _activeState, _recentCollectionLimit],
    );
    return rows.map((row) {
      return RecentPlaylistPlayback(
        id: row['id'] as int,
        playlistId: int.parse(row['itemId'] as String),
        playedAt: row['playedAt'] as String,
      );
    }).toList();
  }

  List<RecentAlbumPlayback> _readRecentAlbums(Database db) {
    final rows = db.select(
      '''
      SELECT
        Id AS id,
        ItemId AS itemId,
        CAST(Time AS TEXT) AS playedAt
      FROM RecentRecord
      WHERE Type = $_recentRecordTypeAlbum
        AND State = ?
      ORDER BY Id DESC
      LIMIT ?
    ''',
      [_activeState, _recentCollectionLimit],
    );
    return rows.map((row) {
      return RecentAlbumPlayback(
        id: row['id'] as int,
        album: row['itemId'] as String,
        playedAt: row['playedAt'] as String,
      );
    }).toList();
  }

  List<RecentArtistPlayback> _readRecentArtists(Database db) {
    final rows = db.select(
      '''
      SELECT
        RecentRecord.Id AS id,
        RecentRecord.ItemId AS itemId,
        CAST(RecentRecord.Time AS TEXT) AS playedAt
      FROM RecentRecord
      WHERE RecentRecord.Type = $_recentRecordTypeArtist
        AND RecentRecord.State = ?
        AND EXISTS (
          SELECT 1
          FROM MusicArtist
          INNER JOIN Music
            ON Music.Id = MusicArtist.MusicId
          WHERE MusicArtist.Name = RecentRecord.ItemId
            AND MusicArtist.State = ?
            AND Music.State = ?
        )
      ORDER BY RecentRecord.Id DESC
      LIMIT ?
    ''',
      [_activeState, _activeState, _activeState, _recentCollectionLimit],
    );
    return rows.map((row) {
      return RecentArtistPlayback(
        id: row['id'] as int,
        artist: row['itemId'] as String,
        playedAt: row['playedAt'] as String,
      );
    }).toList();
  }

  List<SearchHistoryEntry> _readRecentSearches(Database db) {
    final rows = db.select('''
      SELECT
        Id AS id,
        Query AS query,
        Type AS type,
        SearchedAt AS searchedAt
      FROM SearchHistory
      ORDER BY datetime(SearchedAt) DESC, Id DESC
    ''');
    return rows.map((row) {
      return SearchHistoryEntry(
        id: row['id'] as int,
        query: row['query'] as String,
        type: _fromStoredSearchHistoryType(row['type'] as String),
        searchedAt: row['searchedAt'] as String,
      );
    }).toList();
  }

  NowPlayingSnapshot _readNowPlaying(
    Database db,
    List<LibrarySong> songs,
    int fallbackPlaylistId,
  ) {
    final paths = _readNowPlayingPaths();
    final songIds =
        paths.isEmpty
            ? _readPlaylistSongIds(db, fallbackPlaylistId)
            : _readNowPlayingSongIdsFromPaths(db, paths);

    return NowPlayingSnapshot(playlistId: fallbackPlaylistId, songIds: songIds);
  }

  List<int> _readNowPlayingSongIdsByPath(Database db) {
    final paths = _readNowPlayingPaths();
    return _readNowPlayingSongIdsFromPaths(db, paths);
  }

  List<int> _readNowPlayingSongIdsFromPaths(Database db, List<String> paths) {
    if (paths.isEmpty) {
      return const [];
    }
    final placeholders = List.filled(paths.length, '?').join(', ');
    final rows = db.select(
      '''
      SELECT Id AS id, Path AS path
      FROM Music
      WHERE Path IN ($placeholders)
        AND State = ?
    ''',
      [...paths, _activeState],
    );
    final songIdsByPath = {
      for (final row in rows) row['path'] as String: row['id'] as int,
    };
    return paths.expand((songPath) {
      final songId = songIdsByPath[songPath];
      return songId == null ? const <int>[] : [songId];
    }).toList();
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

  List<String> _readNowPlayingPaths() {
    final file = _resolveNowPlayingFile();
    try {
      final data = jsonDecode(file.readAsStringSync());
      return data is List
          ? data.whereType<String>().where((item) => item.isNotEmpty).toList()
          : const [];
    } on Object {
      return const [];
    }
  }

  void _writeNowPlayingSongIds(Database db, List<int> songIds) {
    final file = _resolveNowPlayingFile();
    if (songIds.isEmpty) {
      file.writeAsStringSync('[]');
      return;
    }

    final placeholders = List.filled(songIds.length, '?').join(', ');
    final rows = db.select(
      '''
      SELECT Id AS id, Path AS path
      FROM Music
      WHERE Id IN ($placeholders)
        AND State = ?
    ''',
      [...songIds, _activeState],
    );
    final pathsById = {
      for (final row in rows) row['id'] as int: row['path'] as String,
    };
    final songPaths =
        songIds.expand((songId) {
          final songPath = pathsById[songId];
          return songPath == null ? const <String>[] : [songPath];
        }).toList();

    file.writeAsStringSync(jsonEncode(songPaths));
  }

  File _resolveNowPlayingFile() {
    final resolver = _nowPlayingFileResolver;
    if (resolver != null) {
      return resolver();
    }
    return File(p.join(_defaultElectronUserDataPath(), _nowPlayingJsonName));
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

  Future<File> _resolveDatabaseFile() async {
    final resolver = _databaseFileResolver;
    if (resolver != null) {
      return resolver();
    }

    if (Platform.isWindows) {
      final uwpDatabase = _resolveWindowsUwpDatabaseFile();
      if (uwpDatabase != null) {
        return uwpDatabase;
      }
    }

    final appDataPath = _defaultElectronUserDataPath();
    return File(p.join(appDataPath, _smPlayerDatabaseName));
  }

  Future<File> _resolvePendingSongDeletesFile() async {
    final resolver = _pendingDeleteFileResolver;
    if (resolver != null) {
      return resolver();
    }
    final appDataPath = _defaultElectronUserDataPath();
    return File(p.join(appDataPath, _pendingSongDeletesJsonName));
  }

  Future<List<_PendingDeleteRecord>> _readPendingDeleteRecords(
    File file,
  ) async {
    if (!file.existsSync()) {
      return const [];
    }

    final content = await file.readAsString();
    final data =
        content.trim().isEmpty
            ? const <Object?>[]
            : jsonDecode(content) as List<dynamic>;
    return data
        .whereType<Map<String, Object?>>()
        .map(_pendingDeleteRecordFromJson)
        .toList();
  }

  Future<void> _writePendingDeleteRecords(
    File file,
    List<_PendingDeleteRecord> records,
  ) async {
    await file.parent.create(recursive: true);
    await file.writeAsString(
      '${jsonEncode(records.map((record) => record.toJson()).toList())}\n',
    );
  }

  Future<void> _trashPendingDeleteRecord(_PendingDeleteRecord record) async {
    if (record is _PendingSongDeleteRecord) {
      await _trashPath(record.songPath);
      return;
    }

    final localItemsRecord = record as _PendingLocalItemsDeleteRecord;
    for (final targetPath in localItemsRecord.targetPaths) {
      await _trashPath(targetPath);
    }
  }

  File? _resolveWindowsUwpDatabaseFile() {
    final localAppDataPath = Platform.environment['LOCALAPPDATA'];
    if (localAppDataPath == null) {
      return null;
    }

    final packagesDirectory = Directory(p.join(localAppDataPath, 'Packages'));
    if (!packagesDirectory.existsSync()) {
      return null;
    }

    final candidates =
        packagesDirectory
            .listSync()
            .whereType<Directory>()
            .where(
              (entry) => p
                  .basename(entry.path)
                  .startsWith('${_legacyUwpPackageIdentityName}_'),
            )
            .map(
              (entry) =>
                  File(p.join(entry.path, 'LocalState', _smPlayerDatabaseName)),
            )
            .where((file) => file.existsSync())
            .toList();

    return selectWindowsUwpDatabaseCandidate(candidates);
  }

  String _defaultElectronUserDataPath() {
    if (Platform.isWindows) {
      return p.join(Platform.environment['APPDATA']!, 'simple-melody-player');
    }

    if (Platform.isMacOS) {
      return p.join(
        Platform.environment['HOME']!,
        'Library',
        'Application Support',
        'simple-melody-player',
      );
    }

    return p.join(
      Platform.environment['HOME']!,
      '.config',
      'simple-melody-player',
    );
  }
}

_WindowsUwpDatabaseCandidateScore _scoreWindowsUwpDatabaseCandidate(File file) {
  return _WindowsUwpDatabaseCandidateScore(
    file: file,
    updatedAt: file.lastModifiedSync().millisecondsSinceEpoch,
    existingSampleCount: _readWindowsUwpDatabaseExistingSampleCount(file),
  );
}

int _readWindowsUwpDatabaseExistingSampleCount(File file) {
  Database? db;
  try {
    db = sqlite3.open(file.path);
    final hasMusicTable =
        db.select('''
          SELECT 1 AS found
          FROM sqlite_master
          WHERE type = 'table'
            AND name = 'Music'
          LIMIT 1
        ''').isNotEmpty;
    if (!hasMusicTable) {
      return 0;
    }

    final rows = db.select(
      '''
      SELECT Path AS path
      FROM Music
      WHERE State = ?
      ORDER BY Id
      LIMIT 96
    ''',
      [_activeState],
    );
    return rows.where((row) => File(row['path'] as String).existsSync()).length;
  } on Object {
    return 0;
  } finally {
    db?.dispose();
  }
}

bool _tableExists(Database db, String tableName) {
  return db
      .select(
        '''
    SELECT 1 AS found
    FROM sqlite_master
    WHERE type = 'table'
      AND name = ?
    LIMIT 1
    ''',
        [tableName],
      )
      .isNotEmpty;
}

bool _tableHasRows(Database db, String tableName) {
  final rows = db.select('SELECT 1 AS found FROM $tableName LIMIT 1');
  return rows.isNotEmpty;
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

class _WindowsUwpDatabaseCandidateScore {
  const _WindowsUwpDatabaseCandidateScore({
    required this.file,
    required this.updatedAt,
    required this.existingSampleCount,
  });

  final File file;
  final int updatedAt;
  final int existingSampleCount;
}

String _getFileParentPath(String filePath) {
  final separatorIndex = filePath.lastIndexOf(RegExp(r'[\\/]'));
  return separatorIndex > -1 ? filePath.substring(0, separatorIndex) : '';
}

bool _isPathInsideFolder(String itemPath, String folderPath) {
  return itemPath.startsWith('$folderPath/') ||
      itemPath.startsWith('$folderPath\\');
}

List<LocalMovedAudioFile> detectMovedLocalAudioFiles({
  required List<String> addedPaths,
  required List<String> removedPaths,
}) {
  final movedFiles = <LocalMovedAudioFile>[];
  for (final addedPath in addedPaths) {
    final fileName = _localRefreshFileName(addedPath).toLowerCase();
    final matchingRemoved =
        removedPaths
            .where(
              (removedPath) =>
                  _localRefreshFileName(removedPath).toLowerCase() == fileName,
            )
            .toList();
    final matchingAdded =
        addedPaths
            .where(
              (candidatePath) =>
                  _localRefreshFileName(candidatePath).toLowerCase() ==
                  fileName,
            )
            .toList();
    if (matchingRemoved.length == 1 && matchingAdded.length == 1) {
      movedFiles.add(
        LocalMovedAudioFile(
          oldPath: matchingRemoved.single,
          newPath: addedPath,
        ),
      );
    }
  }
  return movedFiles;
}

String _localRefreshFileName(String filePath) {
  final separatorIndex = filePath.lastIndexOf(RegExp(r'[\\/]'));
  return separatorIndex < 0 ? filePath : filePath.substring(separatorIndex + 1);
}

class LocalMovedAudioFile {
  const LocalMovedAudioFile({required this.oldPath, required this.newPath});

  final String oldPath;
  final String newPath;
}

class _RefreshRemovedSong {
  const _RefreshRemovedSong({required this.id, required this.path});

  final int id;
  final String path;
}

class _RefreshMovedSong {
  const _RefreshMovedSong({
    required this.id,
    required this.oldPath,
    required this.newPath,
  });

  final int id;
  final String oldPath;
  final String newPath;
}

class _LibrarySettings {
  const _LibrarySettings({
    required this.rootPath,
    required this.sortCriterion,
    required this.albumsSort,
    required this.myFavoritesId,
    required this.nowPlayingId,
    required this.showCount,
    required this.hideMultiSelectCommandBarAfterOperation,
    required this.localViewMode,
    required this.useFilenameNotMusicName,
    required this.smartMultiArtistRecognition,
  });

  final String rootPath;
  final MusicLibrarySortCriterion sortCriterion;
  final AlbumSortCriterion albumsSort;
  final int myFavoritesId;
  final int nowPlayingId;
  final bool showCount;
  final bool hideMultiSelectCommandBarAfterOperation;
  final settings.LocalViewMode localViewMode;
  final bool useFilenameNotMusicName;
  final bool smartMultiArtistRecognition;
}

MusicLibrarySortCriterion _fromStoredSortCriterion(int value) {
  switch (value) {
    case 1:
      return MusicLibrarySortCriterion.artist;
    case 2:
      return MusicLibrarySortCriterion.album;
    case 3:
      return MusicLibrarySortCriterion.duration;
    case 4:
      return MusicLibrarySortCriterion.playCount;
    case 5:
      return MusicLibrarySortCriterion.dateAdded;
    default:
      return MusicLibrarySortCriterion.title;
  }
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

int _toStoredSortCriterion(MusicLibrarySortCriterion value) {
  switch (value) {
    case MusicLibrarySortCriterion.artist:
      return 1;
    case MusicLibrarySortCriterion.album:
      return 2;
    case MusicLibrarySortCriterion.duration:
      return 3;
    case MusicLibrarySortCriterion.playCount:
      return 4;
    case MusicLibrarySortCriterion.dateAdded:
      return 5;
    case MusicLibrarySortCriterion.title:
      return 0;
  }
}

AlbumSortCriterion _fromStoredAlbumSortCriterion(int value) {
  switch (value) {
    case 1:
      return AlbumSortCriterion.artist;
    case 6:
      return AlbumSortCriterion.name;
    default:
      return AlbumSortCriterion.defaultSort;
  }
}

int _toStoredAlbumSortCriterion(AlbumSortCriterion value) {
  switch (value) {
    case AlbumSortCriterion.artist:
      return 1;
    case AlbumSortCriterion.name:
      return 6;
    case AlbumSortCriterion.defaultSort:
    case AlbumSortCriterion.reverse:
      return -1;
  }
}

settings.NightMode _nightModeFromValue(int value) {
  return switch (value) {
    0 => settings.NightMode.auto,
    1 => settings.NightMode.onMode,
    _ => settings.NightMode.never,
  };
}

int _nightModeValue(settings.NightMode mode) {
  return switch (mode) {
    settings.NightMode.auto => 0,
    settings.NightMode.onMode => 1,
    settings.NightMode.never => 2,
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

int _boolValue(bool value) {
  return value ? 1 : 0;
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

int _toStoredLocalFolderSortCriterion(LocalFolderSortCriterion value) {
  switch (value) {
    case LocalFolderSortCriterion.artist:
      return 1;
    case LocalFolderSortCriterion.album:
      return 2;
    case LocalFolderSortCriterion.reverse:
      return 7;
    case LocalFolderSortCriterion.title:
      return 0;
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

List<String> findScannableAudioFiles(
  String folderPath, {
  List<String> hiddenFolderPaths = const [],
  List<String> hiddenFilePaths = const [],
  LocalFolderScanCancellation? cancellation,
  void Function(String folderPath)? onFolder,
}) {
  final audioFiles = <String>[];
  final hiddenFolderKeys = hiddenFolderPaths.map(_pathComparisonKey).toList();
  final hiddenFileKeys = hiddenFilePaths.map(_pathComparisonKey).toSet();

  void walk(Directory directory) {
    cancellation?.throwIfCanceled();
    onFolder?.call(directory.path);
    for (final entry in directory.listSync(followLinks: false)) {
      cancellation?.throwIfCanceled();
      if (entry is Link) {
        continue;
      }
      if (entry is Directory) {
        if (p.basename(entry.path).endsWith('.logicx') ||
            _isHiddenFolderPath(entry.path, hiddenFolderKeys)) {
          continue;
        }
        walk(entry);
        continue;
      }
      if (entry is! File) {
        continue;
      }
      if (!_isScannableAudioFile(entry.path)) {
        continue;
      }
      if (hiddenFileKeys.contains(_pathComparisonKey(entry.path))) {
        continue;
      }
      audioFiles.add(entry.path);
    }
  }

  walk(Directory(folderPath));
  return audioFiles;
}

int _countScannableFolders(String folderPath, List<String> hiddenFolderPaths) {
  final hiddenFolderKeys = hiddenFolderPaths.map(_pathComparisonKey).toList();

  int walk(Directory directory) {
    var count = 0;
    for (final entry in directory.listSync(followLinks: false)) {
      if (entry is Link) {
        continue;
      }
      if (entry is! Directory) {
        continue;
      }
      if (p.basename(entry.path).endsWith('.logicx') ||
          _isHiddenFolderPath(entry.path, hiddenFolderKeys)) {
        continue;
      }
      count += 1 + walk(entry);
    }
    return count;
  }

  return walk(Directory(folderPath));
}

bool _isScannableAudioFile(String filePath) {
  return !p.basename(filePath).startsWith('._') &&
      _audioFileExtensions.contains(p.extension(filePath).toLowerCase());
}

bool _isHiddenFolderPath(String folderPath, List<String> hiddenFolderKeys) {
  final folderKey = _pathComparisonKey(folderPath);
  return hiddenFolderKeys.any((hiddenFolderKey) {
    return folderKey == hiddenFolderKey ||
        folderKey.startsWith('$hiddenFolderKey/');
  });
}

List<String> _nonEmptyScannedFolders(String rootPath, List<String> audioFiles) {
  final rootKey = _pathComparisonKey(rootPath);
  final foldersByKey = <String, String>{rootKey: rootPath};
  for (final audioFile in audioFiles) {
    var folderPath = p.dirname(audioFile);
    while (true) {
      final folderKey = _pathComparisonKey(folderPath);
      foldersByKey.putIfAbsent(folderKey, () => folderPath);
      if (folderKey == rootKey || folderPath == p.dirname(folderPath)) {
        break;
      }
      folderPath = p.dirname(folderPath);
    }
  }
  return foldersByKey.values.toList();
}

int _pathDepth(String path) {
  return _pathComparisonKey(
    path,
  ).split('/').where((part) => part.isNotEmpty).length;
}

String _pathComparisonKey(String path) {
  return path.replaceAll('\\', '/').toLowerCase();
}

class _LyricsSongLookup {
  const _LyricsSongLookup({
    required this.title,
    required this.artist,
    required this.album,
    required this.path,
  });

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
    required this.result,
    this.reason,
    this.sourceRawLyrics = '',
    this.targetRawLyrics = '',
  });

  final int songId;
  final String title;
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
  });

  final String keyword;
  final String title;
  final String artist;
}

abstract class _PendingDeleteRecord {
  const _PendingDeleteRecord();

  String get id;

  Map<String, Object?> toJson();
}

_PendingDeleteRecord _pendingDeleteRecordFromJson(Map<String, Object?> json) {
  return json['type'] == 'local-items'
      ? _PendingLocalItemsDeleteRecord.fromJson(json)
      : _PendingSongDeleteRecord.fromJson(json);
}

class _PendingSongDeleteRecord extends _PendingDeleteRecord {
  const _PendingSongDeleteRecord({
    required this.id,
    required this.songId,
    required this.songPath,
    required this.musicArtistIds,
    required this.playlistItemIds,
    required this.recentRecordIds,
    required this.hiddenStorageItemIds,
  }) : super();

  factory _PendingSongDeleteRecord.fromJson(Map<String, Object?> json) {
    return _PendingSongDeleteRecord(
      id: json['id'] as String,
      songId: json['songId'] as int,
      songPath: json['songPath'] as String,
      musicArtistIds: _intListFromJson(json['musicArtistIds']),
      playlistItemIds: _intListFromJson(json['playlistItemIds']),
      recentRecordIds: _intListFromJson(json['recentRecordIds']),
      hiddenStorageItemIds: _intListFromJson(json['hiddenStorageItemIds']),
    );
  }

  @override
  final String id;
  final int songId;
  final String songPath;
  final List<int> musicArtistIds;
  final List<int> playlistItemIds;
  final List<int> recentRecordIds;
  final List<int> hiddenStorageItemIds;

  @override
  Map<String, Object?> toJson() {
    return {
      'id': id,
      'type': 'song',
      'songId': songId,
      'songPath': songPath,
      'musicArtistIds': musicArtistIds,
      'playlistItemIds': playlistItemIds,
      'recentRecordIds': recentRecordIds,
      'hiddenStorageItemIds': hiddenStorageItemIds,
    };
  }

  static List<int> _intListFromJson(Object? value) {
    return (value as List).map((item) => item as int).toList();
  }
}

class _PendingLocalItemsDeleteRecord extends _PendingDeleteRecord {
  const _PendingLocalItemsDeleteRecord({
    required this.id,
    required this.songIds,
    required this.folderPaths,
    required this.targetPaths,
    required this.musicIds,
    required this.musicArtistIds,
    required this.playlistItemIds,
    required this.recentRecordIds,
    required this.hiddenStorageItemIds,
    required this.folderIds,
    required this.fileIds,
  }) : super();

  factory _PendingLocalItemsDeleteRecord.fromJson(Map<String, Object?> json) {
    return _PendingLocalItemsDeleteRecord(
      id: json['id'] as String,
      songIds: _PendingSongDeleteRecord._intListFromJson(json['songIds']),
      folderPaths: _stringListFromJson(json['folderPaths']),
      targetPaths: _stringListFromJson(json['targetPaths']),
      musicIds: _PendingSongDeleteRecord._intListFromJson(json['musicIds']),
      musicArtistIds: _PendingSongDeleteRecord._intListFromJson(
        json['musicArtistIds'],
      ),
      playlistItemIds: _PendingSongDeleteRecord._intListFromJson(
        json['playlistItemIds'],
      ),
      recentRecordIds: _PendingSongDeleteRecord._intListFromJson(
        json['recentRecordIds'],
      ),
      hiddenStorageItemIds: _PendingSongDeleteRecord._intListFromJson(
        json['hiddenStorageItemIds'],
      ),
      folderIds: _PendingSongDeleteRecord._intListFromJson(json['folderIds']),
      fileIds: _PendingSongDeleteRecord._intListFromJson(json['fileIds']),
    );
  }

  @override
  final String id;
  final List<int> songIds;
  final List<String> folderPaths;
  final List<String> targetPaths;
  final List<int> musicIds;
  final List<int> musicArtistIds;
  final List<int> playlistItemIds;
  final List<int> recentRecordIds;
  final List<int> hiddenStorageItemIds;
  final List<int> folderIds;
  final List<int> fileIds;

  @override
  Map<String, Object?> toJson() {
    return {
      'id': id,
      'type': 'local-items',
      'songIds': songIds,
      'folderPaths': folderPaths,
      'targetPaths': targetPaths,
      'musicIds': musicIds,
      'musicArtistIds': musicArtistIds,
      'playlistItemIds': playlistItemIds,
      'recentRecordIds': recentRecordIds,
      'hiddenStorageItemIds': hiddenStorageItemIds,
      'folderIds': folderIds,
      'fileIds': fileIds,
    };
  }

  static List<String> _stringListFromJson(Object? value) {
    return (value as List).map((item) => item as String).toList();
  }
}
