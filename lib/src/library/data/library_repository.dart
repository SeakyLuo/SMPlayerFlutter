import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import 'library_audio_metadata_service.dart';
import 'library_artist_split_service.dart';
import 'library_artwork_service.dart';
import 'library_data_transfer_service.dart';
import 'library_database_service.dart';
import 'library_hidden_storage_service.dart';
import 'library_local_move_service.dart';
import 'library_lyrics_service.dart';
import 'library_models.dart';
import 'library_pending_delete_service.dart' hide TrashPath;
import 'library_playback_history_service.dart';
import 'library_playlist_service.dart';
import 'library_preference_service.dart';
import 'library_repository_paths.dart';
import 'library_search_history_service.dart';
import 'library_settings_service.dart';
import 'library_song_properties_service.dart';
import 'package:smplayer_flutter/src/settings/settings_model.dart' as settings;
import 'package:smplayer_flutter/src/settings/settings_model.dart'
    show
        PreferenceEntityType,
        PreferenceLevel,
        PreferenceSectionKey,
        PreferenceSettingsSnapshot;

export 'library_repository_paths.dart' show defaultSmPlayerUserDataPath;
export 'library_data_transfer_service.dart'
    show selectWindowsUwpDatabaseCandidate;
export 'library_artwork_service.dart'
    show ShellThumbnail, ShellThumbnailResolver;
export 'library_local_move_service.dart'
    show
        LocalFolderMove,
        LocalItemsMoveResult,
        LocalMoveConflictResolution,
        LocalMoveConflictResolver,
        LocalSongMove;
export 'library_lyrics_service.dart'
    show
        InternetLyricsResolver,
        LyricsBatchDetail,
        LyricsBatchDetailResult,
        LyricsBatchProgress,
        LyricsBatchResult,
        LyricsBatchSkipReason;

const _activeState = 1;
const _inactiveState = 0;
const _hiddenState = -1;
const _parentHiddenState = -2;

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
const _recentRecordTypeSong = 0;

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

  static final _startupArtistSplitPendingDatabasePaths = <String>{};
  static const _database = LibraryDatabaseService();
  static const _audioMetadataService = LibraryAudioMetadataService();
  static const _songPropertiesService = LibrarySongPropertiesService();
  static const _artistSplitService = LibraryArtistSplitService(
    songPropertiesService: _songPropertiesService,
  );
  static const _dataTransferService = LibraryDataTransferService();
  static const _hiddenStorageService = LibraryHiddenStorageService();
  static const _localMoveService = LibraryLocalMoveService();
  static const _pendingDeleteService = LibraryPendingDeleteService();
  static const _settingsService = LibrarySettingsService(database: _database);
  static const _playbackHistoryService = LibraryPlaybackHistoryService();
  static const _searchHistoryService = LibrarySearchHistoryService(
    database: _database,
  );
  static const _playlistService = LibraryPlaylistService();
  static const _preferenceService = LibraryPreferenceService();

  final Future<File> Function()? _databaseFileResolver;
  final File Function()? _nowPlayingFileResolver;
  final Future<File> Function()? _pendingDeleteFileResolver;
  final TrashPath _trashPath;
  final InternetLyricsResolver? _internetLyricsResolver;
  final ShellThumbnailResolver _shellThumbnailResolver;

  LibraryArtworkService get _artworkService => LibraryArtworkService(
    databaseFileResolver: _resolveDatabaseFile,
    shellThumbnailResolver: _shellThumbnailResolver,
  );

  LibraryLyricsService get _lyricsService => LibraryLyricsService(
    settingsSnapshotResolver: getSettingsSnapshot,
    internetLyricsResolver: _internetLyricsResolver,
  );

  LibraryRepositoryPaths get _paths => LibraryRepositoryPaths(
    databaseFileResolver: _databaseFileResolver,
    nowPlayingFileResolver: _nowPlayingFileResolver,
    pendingDeleteFileResolver: _pendingDeleteFileResolver,
  );

  Future<void> initializeLibraryDatabase() async {
    final databaseFile = await _resolveDatabaseFile();
    final db = _database.openInitializedLibraryDatabase(databaseFile);
    db.dispose();
  }

  Future<settings.SettingsSnapshot?> initializeSettingsSnapshot() async {
    final databaseFile = await _resolveDatabaseFile();
    databaseFile.parent.createSync(recursive: true);
    final db = sqlite3.open(databaseFile.path);
    try {
      final shouldCheckStartupArtistSplits =
          _hasLegacyStartupArtistSplitCandidates(db);
      _database.initializeLibrarySchema(db);
      if (shouldCheckStartupArtistSplits) {
        _startupArtistSplitPendingDatabasePaths.add(databaseFile.path);
      }
      _cleanupInvalidLastPlaylist(db);
      final rows = db.select('SELECT * FROM Settings ORDER BY Id DESC LIMIT 1');
      return rows.isEmpty
          ? null
          : _settingsService.settingsSnapshotFromRow(rows.single);
    } finally {
      db.dispose();
    }
  }

  Future<RecentPageData> getRecentPageData() async {
    final databaseFile = await _resolveDatabaseFile();
    final db = _database.openInitializedLibraryDatabase(databaseFile);
    try {
      _cleanupInvalidPlaylistItems(db);
      _playbackHistoryService.cleanupInvalidRecentPlayed(db);
      final settings = _readLibrarySettings(db);
      final songs = _readSongs(db);
      final playlists = _readPlaylists(db, settings);
      return RecentPageData(
        songs: songs,
        recentSongs: _playbackHistoryService.readRecentSongs(db, songs),
        recentPlaylists: _playbackHistoryService.readRecentPlaylists(db),
        recentAlbums: _playbackHistoryService.readRecentAlbums(db),
        recentArtists: _playbackHistoryService.readRecentArtists(db),
        recentSearches: _searchHistoryService.readRecentSearches(db),
        playlists: playlists,
        favoritePlaylistId: settings.myFavoritesId,
        nowPlaying: _playbackHistoryService.readNowPlaying(
          db,
          _resolveNowPlayingFile(),
          settings.nowPlayingId,
        ),
        showCount: settings.showCount,
        hideMultiSelectCommandBarAfterOperation:
            settings.hideMultiSelectCommandBarAfterOperation,
      );
    } finally {
      db.dispose();
    }
  }

  Future<ShellNavigationData> getShellNavigationData() async {
    final databaseFile = await _resolveDatabaseFile();
    final db = _database.openInitializedLibraryDatabase(databaseFile);
    try {
      _cleanupInvalidPlaylistItems(db);
      final settings = _readLibrarySettings(db);
      final songs = _readSongs(db);
      return ShellNavigationData(
        songs: songs,
        playlists: _readPlaylists(db, settings),
        folders: _readFolders(db),
        recentSearches: _searchHistoryService.readRecentSearches(db),
        nowPlaying: _playbackHistoryService.readNowPlaying(
          db,
          _resolveNowPlayingFile(),
          settings.nowPlayingId,
        ),
        rootPath: settings.rootPath,
      );
    } finally {
      db.dispose();
    }
  }

  Future<List<SearchHistoryEntry>> getRecentSearches() async {
    final databaseFile = await _resolveDatabaseFile();
    return _searchHistoryService.getRecentSearches(databaseFile);
  }

  Future<int> getLibrarySongCount() async {
    final databaseFile = await _resolveDatabaseFile();
    final db = _database.openInitializedLibraryDatabase(databaseFile);
    try {
      final rows = db.select(
        'SELECT COUNT(*) AS count FROM Music WHERE State = ?',
        [_activeState],
      );
      return rows.single['count'] as int;
    } finally {
      db.dispose();
    }
  }

  Future<LibraryViewData> getLibraryViewData() async {
    final databaseFile = await _resolveDatabaseFile();
    final db = _database.openInitializedLibraryDatabase(databaseFile);
    try {
      _cleanupInvalidPlaylistItems(db);
      _playbackHistoryService.cleanupInvalidRecentPlayed(db);
      final settings = _readLibrarySettings(db);
      final songs = _readSongs(db);
      final folders = _readFolders(db);
      final playlists = _readPlaylists(db, settings);
      final recentSongs = _playbackHistoryService.readRecentSongs(db, songs);
      final nowPlaying = _playbackHistoryService.readNowPlaying(
        db,
        _resolveNowPlayingFile(),
        settings.nowPlayingId,
      );
      return LibraryViewData(
        songs: songs,
        recentSongs: recentSongs,
        recentPlaylists: _playbackHistoryService.readRecentPlaylists(db),
        recentAlbums: _playbackHistoryService.readRecentAlbums(db),
        recentArtists: _playbackHistoryService.readRecentArtists(db),
        recentSearches: _searchHistoryService.readRecentSearches(db),
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
          _startupArtistSplitPendingDatabasePaths.remove(databaseFile.path) ||
          _hasLegacyStartupArtistSplitCandidates(db);
      _database.initializeLibrarySchema(db);
      return shouldCheck;
    } finally {
      db.dispose();
    }
  }

  Future<bool> exportDataTo(String targetPath) async {
    final databaseFile = await _resolveDatabaseFile();
    return _dataTransferService.exportDataTo(databaseFile, targetPath);
  }

  Future<bool> importDataFrom(String sourcePath) async {
    final databaseFile = await _resolveDatabaseFile();
    return _dataTransferService.importDataFrom(
      databaseFile,
      sourcePath,
      rescanLibrary: scanAllMusicLibrary,
    );
  }

  Future<settings.SettingsSnapshot?> getSettingsSnapshot() async {
    final databaseFile = await _resolveDatabaseFile();
    return _settingsService.getSettingsSnapshot(
      databaseFile,
      cleanupInvalidLastPlaylist: _cleanupInvalidLastPlaylist,
    );
  }

  Future<void> updateSettings(settings.AppSettingsUpdate update) async {
    final databaseFile = await _resolveDatabaseFile();
    await _settingsService.updateSettings(databaseFile, update);
  }

  Future<void> savePlaybackSettings(
    settings.PlaybackSettingsUpdate update,
  ) async {
    final databaseFile = await _resolveDatabaseFile();
    await _settingsService.savePlaybackSettings(databaseFile, update);
  }

  Future<void> updateSongDuration(int songId, int durationSeconds) async {
    final databaseFile = await _resolveDatabaseFile();
    await _songPropertiesService.updateSongDuration(
      databaseFile,
      songId,
      durationSeconds,
    );
  }

  Future<void> saveViewState({String? lastPage, int? lastPlaylistId}) async {
    final databaseFile = await _resolveDatabaseFile();
    await _settingsService.saveViewState(
      databaseFile,
      lastPage: lastPage,
      lastPlaylistId: lastPlaylistId,
    );
  }

  Future<void> saveMainWindowState({
    required String bounds,
    required bool maximized,
  }) async {
    final databaseFile = await _resolveDatabaseFile();
    await _settingsService.saveMainWindowState(
      databaseFile,
      bounds: bounds,
      maximized: maximized,
    );
  }

  Future<void> replaceNowPlaying(List<int> songIds) async {
    final databaseFile = await _resolveDatabaseFile();
    await _playbackHistoryService.replaceNowPlaying(
      databaseFile,
      _resolveNowPlayingFile(),
      songIds,
    );
  }

  Future<void> clearNowPlaying() async {
    await replaceNowPlaying([]);
  }

  Future<void> removeSongFromNowPlaying(int songId) async {
    final databaseFile = await _resolveDatabaseFile();
    await _playbackHistoryService.removeSongFromNowPlaying(
      databaseFile,
      _resolveNowPlayingFile(),
      songId,
    );
  }

  Future<void> removeRecentPlayed(List<int> songIds) async {
    final databaseFile = await _resolveDatabaseFile();
    await _playbackHistoryService.removeRecentPlayed(databaseFile, songIds);
  }

  Future<void> clearRecentPlayed() async {
    final databaseFile = await _resolveDatabaseFile();
    await _playbackHistoryService.clearRecentPlayed(databaseFile);
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
    final databaseFile = await _resolveDatabaseFile();
    await _searchHistoryService.removeRecentSearches(databaseFile, entryIds);
  }

  Future<void> restoreRecentSearches(List<SearchHistoryEntry> entries) async {
    final databaseFile = await _resolveDatabaseFile();
    await _searchHistoryService.restoreRecentSearches(databaseFile, entries);
  }

  Future<void> restoreRecentPlayed(List<int> songIds) async {
    final databaseFile = await _resolveDatabaseFile();
    await _playbackHistoryService.restoreRecentPlayed(databaseFile, songIds);
  }

  Future<void> clearRecentSearches() async {
    final databaseFile = await _resolveDatabaseFile();
    await _searchHistoryService.clearRecentSearches(databaseFile);
  }

  Future<PendingSongDelete> beginDeleteSongFromDisk(int songId) async {
    final databaseFile = await _resolveDatabaseFile();
    final db = sqlite3.open(databaseFile.path);
    final pendingFile = await _resolvePendingSongDeletesFile();
    try {
      final songPath = _readActiveSongPath(db, songId);
      final record = PendingSongDeleteRecord(
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
      await _pendingDeleteService.prependRecord(pendingFile, record);

      db.execute('BEGIN');
      try {
        _deleteSongsInsideTransaction(db, [songId], [songPath]);
        db.execute('COMMIT');
      } on Object {
        db.execute('ROLLBACK');
        await _pendingDeleteService.removeRecord(pendingFile, record.id);
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
    final records = await _pendingDeleteService.readRecords(pendingFile);
    final record = _pendingDeleteService.findSongDeleteRecord(
      records,
      deleteId,
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
    await _pendingDeleteService.removeRecord(pendingFile, deleteId);
  }

  Future<void> commitDeleteSongFromDisk(String deleteId) async {
    final pendingFile = await _resolvePendingSongDeletesFile();
    await _pendingDeleteService.commitSongDelete(
      pendingFile,
      deleteId,
      _trashPath,
    );
  }

  Future<void> commitPendingDeletes() async {
    final pendingFile = await _resolvePendingSongDeletesFile();
    await _pendingDeleteService.commitPendingDeletes(pendingFile, _trashPath);
  }

  Future<void> hideSong(int songId) async {
    final databaseFile = await _resolveDatabaseFile();
    await _hiddenStorageService.hideSong(databaseFile, songId);
  }

  Future<LocalItemsMoveResult> moveSongToFolder(
    int songId,
    String folderPath, {
    LocalMoveConflictResolver? resolveConflict,
  }) async {
    final databaseFile = await _resolveDatabaseFile();
    return _localMoveService.moveSongToFolder(
      databaseFile,
      songId,
      folderPath,
      resolveConflict: resolveConflict,
    );
  }

  Future<LocalItemsMoveResult> moveLocalItemsToFolder(
    List<int> songIds,
    List<String> folderPaths,
    String targetFolderPath, {
    LocalMoveConflictResolver? resolveConflict,
  }) async {
    final databaseFile = await _resolveDatabaseFile();
    return _localMoveService.moveLocalItemsToFolder(
      databaseFile,
      songIds,
      folderPaths,
      targetFolderPath,
      resolveConflict: resolveConflict,
    );
  }

  Future<void> undoMoveLocalItems(LocalItemsMoveResult result) async {
    final databaseFile = await _resolveDatabaseFile();
    await _localMoveService.undoMoveLocalItems(databaseFile, result);
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
      final record = PendingLocalItemsDeleteRecord(
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
      await _pendingDeleteService.prependRecord(pendingFile, record);

      db.execute('BEGIN');
      try {
        if (songRows.isNotEmpty) {
          _deleteSongsInsideTransaction(
            db,
            effectiveSongIds,
            songRows.map((row) => row.path).toList(),
          );
        }
        _hiddenStorageService.updateFolderPathStateInsideTransaction(
          db,
          folderPaths,
          _inactiveState,
        );
        db.execute('COMMIT');
      } on Object {
        db.execute('ROLLBACK');
        await _pendingDeleteService.removeRecord(pendingFile, record.id);
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
    final records = await _pendingDeleteService.readRecords(pendingFile);
    final record = _pendingDeleteService.findLocalItemsDeleteRecord(
      records,
      deleteId,
    );
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
    await _pendingDeleteService.removeRecord(pendingFile, deleteId);
  }

  Future<void> commitDeleteLocalItems(String deleteId) async {
    final pendingFile = await _resolvePendingSongDeletesFile();
    await _pendingDeleteService.commitLocalItemsDelete(
      pendingFile,
      deleteId,
      _trashPath,
    );
  }

  Future<void> hideFolder(String folderPath) async {
    final databaseFile = await _resolveDatabaseFile();
    await _hiddenStorageService.hideFolder(databaseFile, folderPath);
  }

  Future<void> unhideSong(int songId) async {
    final databaseFile = await _resolveDatabaseFile();
    await _hiddenStorageService.unhideSong(databaseFile, songId);
  }

  Future<void> unhideFolder(String folderPath) async {
    final databaseFile = await _resolveDatabaseFile();
    await _hiddenStorageService.unhideFolder(databaseFile, folderPath);
  }

  Future<List<HiddenStorageItem>> getHiddenStorageItems() async {
    final databaseFile = await _resolveDatabaseFile();
    return _hiddenStorageService.getHiddenStorageItems(databaseFile);
  }

  Future<void> resumeHiddenStorageItem(HiddenStorageItem item) async {
    final databaseFile = await _resolveDatabaseFile();
    await _hiddenStorageService.resumeHiddenStorageItem(databaseFile, item);
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

  Future<SearchHistoryEntry?> addRecentSearch(
    String query, [
    SearchHistoryType type = SearchHistoryType.sidebar,
  ]) async {
    final databaseFile = await _resolveDatabaseFile();
    return _searchHistoryService.addRecentSearch(databaseFile, query, type);
  }

  Future<void> updateMusicLibrarySort(
    MusicLibrarySortCriterion criterion,
  ) async {
    final databaseFile = await _resolveDatabaseFile();
    if (!databaseFile.existsSync()) {
      return;
    }

    final db = _database.openInitializedLibraryDatabase(databaseFile);
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
    return _playlistService.createPlaylist(databaseFile, name, songIds);
  }

  Future<void> deletePlaylist(int playlistId) async {
    final databaseFile = await _resolveDatabaseFile();
    await _playlistService.deletePlaylist(databaseFile, playlistId);
  }

  Future<void> restorePlaylist(LibraryPlaylist playlist) async {
    final databaseFile = await _resolveDatabaseFile();
    await _playlistService.restorePlaylist(databaseFile, playlist);
  }

  Future<void> renamePlaylist(int playlistId, String name) async {
    final databaseFile = await _resolveDatabaseFile();
    await _playlistService.renamePlaylist(databaseFile, playlistId, name);
  }

  Future<void> reorderPlaylists(List<int> playlistIds) async {
    final databaseFile = await _resolveDatabaseFile();
    await _playlistService.reorderPlaylists(databaseFile, playlistIds);
  }

  Future<void> setSongFavorite(int songId, bool favorite) async {
    await setSongsFavorite([songId], favorite);
  }

  Future<ArtistSplitAnalysisResult> analyzeArtistSplits() async {
    final snapshot = await getLibraryViewData();
    return _artistSplitService.analyze(snapshot.songs);
  }

  Future<void> applyArtistSplits(List<ArtistSplitResultItem> splits) async {
    final databaseFile = await _resolveDatabaseFile();
    await _artistSplitService.applySplits(databaseFile, splits);
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
    final metadataByPath = await _audioMetadataService
        .readAudioFileMetadataBatch(
          audioFiles,
          cacheSongArtwork: _cacheSongArtwork,
        );

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
      final hiddenPaths = _hiddenStorageService.readActiveHiddenStoragePaths(
        db,
      );
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
      final metadataByPath = await _audioMetadataService
          .readAudioFileMetadataBatch(
            scannedPaths,
            cacheSongArtwork: _cacheSongArtwork,
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
                ? _artistSplitService.analyze(_readSongs(db))
                : _artistSplitService.emptyAnalysis();
        _artistSplitService.applySplitsInsideTransaction(
          db,
          artistAnalysis.directSplits,
        );
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

        final autoLyricsEnabled = _lyricsService.readAutoLyricsEnabled(db);
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
      final hiddenPaths = _hiddenStorageService.readActiveHiddenStoragePaths(
        db,
      );
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
      final metadataByPath = await _audioMetadataService
          .readAudioFileMetadataBatch(
            addedPaths,
            cacheSongArtwork: _cacheSongArtwork,
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
                ? _artistSplitService.analyze(_readSongs(db))
                : _artistSplitService.emptyAnalysis();
        _artistSplitService.applySplitsInsideTransaction(
          db,
          artistAnalysis.directSplits,
        );
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
        final autoLyricsEnabled = _lyricsService.readAutoLyricsEnabled(db);
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
    await _playlistService.setSongsFavorite(databaseFile, songIds, favorite);
  }

  Future<SongPropertiesSnapshot> getSongProperties(int songId) async {
    final databaseFile = await _resolveDatabaseFile();
    return _songPropertiesService.getSongProperties(databaseFile, songId);
  }

  Future<void> updateSongProperties(
    int songId,
    SongPropertiesUpdate update,
  ) async {
    final databaseFile = await _resolveDatabaseFile();
    await _songPropertiesService.updateSongProperties(
      databaseFile,
      songId,
      update,
    );
  }

  Future<void> updateSongPlayCount(int songId, int playCount) async {
    final databaseFile = await _resolveDatabaseFile();
    await _songPropertiesService.updateSongPlayCount(
      databaseFile,
      songId,
      playCount,
    );
  }

  Future<void> markSongPlayed(int songId) async {
    final databaseFile = await _resolveDatabaseFile();
    await _playbackHistoryService.markSongPlayed(databaseFile, songId);
  }

  Future<LyricsSnapshot> getSongLyrics(
    int songId, {
    settings.LyricsRequestMode mode = settings.LyricsRequestMode.auto,
  }) async {
    final databaseFile = await _resolveDatabaseFile();
    return _lyricsService.getSongLyrics(databaseFile, songId, mode: mode);
  }

  Future<String> readLyricsFromFile(String filePath) async {
    return _lyricsService.readLyricsFromFile(filePath);
  }

  Future<void> saveSongLyrics(int songId, String rawLyrics) async {
    final databaseFile = await _resolveDatabaseFile();
    await _lyricsService.saveSongLyrics(databaseFile, songId, rawLyrics);
  }

  Future<void> updateLyricsOffset(int songId, int offsetMs) async {
    final databaseFile = await _resolveDatabaseFile();
    await _lyricsService.updateLyricsOffset(databaseFile, songId, offsetMs);
  }

  Future<LyricsSnapshot> getInternetLyrics(int songId) async {
    final databaseFile = await _resolveDatabaseFile();
    return _lyricsService.getInternetLyrics(databaseFile, songId);
  }

  Future<LyricsBatchResult> batchAddInternetLyrics({
    bool overwrite = false,
    void Function(LyricsBatchProgress progress)? onProgress,
    bool Function()? isCanceled,
    Future<void> Function()? waitIfPaused,
  }) async {
    final snapshot = await getLibraryViewData();
    return _lyricsService.batchAddInternetLyrics(
      songs: snapshot.songs,
      overwrite: overwrite,
      onProgress: onProgress,
      isCanceled: isCanceled,
      waitIfPaused: waitIfPaused,
    );
  }

  Future<void> _autoAddInternetLyricsForPaths(List<String> songPaths) async {
    final databaseFile = await _resolveDatabaseFile();
    await _lyricsService.autoAddInternetLyricsForPaths(databaseFile, songPaths);
  }

  Future<SongArtworkSnapshot> getSongArtworkSnapshot(int songId) async {
    final databaseFile = await _resolveDatabaseFile();
    return _artworkService.getSongArtworkSnapshot(databaseFile, songId);
  }

  Future<List<SongArtworkSnapshot>> getSongArtworkSnapshots(
    List<int> songIds,
  ) async {
    final uniqueIds = songIds.toSet().toList();
    if (uniqueIds.isEmpty) {
      return [];
    }

    final databaseFile = await _resolveDatabaseFile();
    return _artworkService.getSongArtworkSnapshots(databaseFile, uniqueIds);
  }

  Future<String> prepareSongArtworkSource(String sourcePath) async {
    return _artworkService.prepareSongArtworkSource(sourcePath);
  }

  Future<void> saveSongArtwork(int songId, String sourcePath) async {
    final databaseFile = await _resolveDatabaseFile();
    await _artworkService.saveSongArtwork(databaseFile, songId, sourcePath);
  }

  Future<void> saveAlbumArtwork(String albumName, String sourcePath) async {
    final databaseFile = await _resolveDatabaseFile();
    await _artworkService.saveAlbumArtwork(databaseFile, albumName, sourcePath);
  }

  Future<void> deleteSongArtwork(int songId) async {
    final databaseFile = await _resolveDatabaseFile();
    await _artworkService.deleteSongArtwork(databaseFile, songId);
  }

  Future<void> deleteAlbumArtwork(String albumName) async {
    final databaseFile = await _resolveDatabaseFile();
    await _artworkService.deleteAlbumArtwork(databaseFile, albumName);
  }

  Future<void> addPreferenceItem(
    String type,
    String itemId,
    String name,
    String level,
  ) async {
    final databaseFile = await _resolveDatabaseFile();
    await _preferenceService.addPreferenceItem(
      databaseFile,
      type,
      itemId,
      name,
      level,
    );
  }

  Future<String?> getPreferenceLevel(String type, String itemId) async {
    final databaseFile = await _resolveDatabaseFile();
    return _preferenceService.getPreferenceLevel(databaseFile, type, itemId);
  }

  Future<void> removePreferenceItem(String type, String itemId) async {
    final databaseFile = await _resolveDatabaseFile();
    await _preferenceService.removePreferenceItem(databaseFile, type, itemId);
  }

  Future<PreferenceSettingsSnapshot> getPreferenceSettings() async {
    final databaseFile = await _resolveDatabaseFile();
    return _preferenceService.getPreferenceSettings(databaseFile);
  }

  Future<void> updatePreferenceSettings(
    Map<PreferenceSectionKey, bool> enabled,
  ) async {
    final databaseFile = await _resolveDatabaseFile();
    await _preferenceService.updatePreferenceSettings(databaseFile, enabled);
  }

  Future<void> updatePreferenceItem(
    int itemId, {
    bool? isEnabled,
    PreferenceLevel? level,
  }) async {
    final databaseFile = await _resolveDatabaseFile();
    await _preferenceService.updatePreferenceItem(
      databaseFile,
      itemId,
      isEnabled: isEnabled,
      level: level,
    );
  }

  Future<void> removePreferenceItemById(int itemId) async {
    final databaseFile = await _resolveDatabaseFile();
    await _preferenceService.removePreferenceItemById(databaseFile, itemId);
  }

  Future<void> clearInvalidPreferenceItems(PreferenceEntityType type) async {
    final databaseFile = await _resolveDatabaseFile();
    await _preferenceService.clearInvalidPreferenceItems(databaseFile, type);
  }

  Future<void> addSongToPlaylist(int playlistId, int songId) async {
    await addSongsToPlaylist(playlistId, [songId]);
  }

  Future<void> addSongsToPlaylist(int playlistId, List<int> songIds) async {
    final databaseFile = await _resolveDatabaseFile();
    await _playlistService.addSongsToPlaylist(
      databaseFile,
      playlistId,
      songIds,
    );
  }

  Future<void> removeSongFromPlaylist(int playlistId, int songId) async {
    await removeSongsFromPlaylist(playlistId, [songId]);
  }

  Future<void> removeSongsFromPlaylist(
    int playlistId,
    List<int> songIds,
  ) async {
    final databaseFile = await _resolveDatabaseFile();
    await _playlistService.removeSongsFromPlaylist(
      databaseFile,
      playlistId,
      songIds,
    );
  }

  Future<void> reorderPlaylistSongs(
    int playlistId,
    List<int> songIds, [
    PlaylistSortCriterion? sortCriterion,
  ]) async {
    final databaseFile = await _resolveDatabaseFile();
    await _playlistService.reorderPlaylistSongs(
      databaseFile,
      playlistId,
      songIds,
      sortCriterion,
    );
  }

  Future<void> recordPlaylistPlayed(int playlistId) async {
    final databaseFile = await _resolveDatabaseFile();
    await _playbackHistoryService.recordPlaylistPlayed(
      databaseFile,
      playlistId,
    );
  }

  Future<void> recordAlbumPlayed(String album) async {
    final databaseFile = await _resolveDatabaseFile();
    await _playbackHistoryService.recordAlbumPlayed(databaseFile, album);
  }

  Future<void> recordArtistPlayed(String artist) async {
    final databaseFile = await _resolveDatabaseFile();
    await _playbackHistoryService.recordArtistPlayed(databaseFile, artist);
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
    PendingSongDeleteRecord record,
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
    PendingLocalItemsDeleteRecord record,
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

  int _upsertExternalAudioFile(
    Database db,
    String filePath, {
    required AudioFileMetadata metadata,
    bool useFilenameNotMusicName = false,
  }) {
    final properties = metadata.properties;
    final title =
        useFilenameNotMusicName || properties.title.trim().isEmpty
            ? p.basenameWithoutExtension(filePath)
            : properties.title.trim();
    final artists =
        _songPropertiesService
            .normalizeArtists(
              properties.artists.isNotEmpty
                  ? properties.artists
                  : [properties.artist],
            )
            .take(6)
            .toList();
    final artist = artists.join(', ');
    final album = properties.album.trim();
    final dateAdded = DateTime.now().toIso8601String();
    final rows = db.select(
      '''
      INSERT INTO Music (Path, Name, Artist, Album, ThumbnailPath, Duration, PlayCount, DateAdded, State)
      VALUES (
        ?, ?, ?, ?, ?,
        ?,
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
    _songPropertiesService.syncSongArtists(db, songId, artists);
    return songId;
  }

  Future<String> _cacheSongArtwork(String filePath) async {
    return _artworkService.cacheSongArtwork(filePath);
  }

  int _upsertScannedAudioFile(
    Database db,
    String filePath,
    Map<String, int> folderIds, {
    required AudioFileMetadata metadata,
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

  Future<void> _pruneArtworkCache(Database db) async {
    await _artworkService.pruneArtworkCache(db);
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
    return _playlistService.readPlaylists(
      db,
      myFavoritesId: settings.myFavoritesId,
      nowPlayingId: settings.nowPlayingId,
    );
  }

  File _resolveNowPlayingFile() {
    return _paths.resolveNowPlayingFile();
  }

  Future<File> _resolveDatabaseFile() async {
    return _paths.resolveDatabaseFile(
      windowsUwpDatabaseResolver:
          _dataTransferService.resolveWindowsUwpDatabaseFile,
    );
  }

  Future<File> _resolvePendingSongDeletesFile() async {
    return _paths.resolvePendingSongDeletesFile();
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

bool _hasLegacyStartupArtistSplitCandidates(Database db) {
  return _tableExists(db, 'Music') &&
      _tableHasRows(db, 'Music') &&
      !_tableExists(db, 'MusicArtist');
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

settings.LocalViewMode _localViewModeFromValue(int value) {
  return value == 1 ? settings.LocalViewMode.list : settings.LocalViewMode.grid;
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

String _normalizeTagText(String value) {
  return value.trim();
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
