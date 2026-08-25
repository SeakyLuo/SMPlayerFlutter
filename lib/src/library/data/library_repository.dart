import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:url_launcher/url_launcher.dart';

import 'library_audio_metadata_service.dart';
import 'library_artist_split_service.dart';
import 'library_artwork_service.dart';
import 'library_browse_history_service.dart';
import 'library_data_transfer_service.dart';
import 'library_database_service.dart';
import 'library_hidden_storage_service.dart';
import 'library_local_delete_service.dart';
import 'library_local_move_service.dart';
import 'library_local_refresh_service.dart';
import 'library_lyrics_service.dart';
import 'library_lyrics_search_service.dart';
import 'library_models.dart';
import 'library_pending_delete_service.dart' hide TrashPath;
import 'library_playback_history_service.dart';
import 'library_playlist_service.dart';
import 'library_preference_service.dart';
import 'library_read_service.dart';
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
export 'library_local_scan_service.dart'
    show
        LocalMovedAudioFile,
        detectMovedLocalAudioFiles,
        findScannableAudioFiles;
export 'library_lyrics_service.dart'
    show
        InternetLyricsResolver,
        LyricsBatchDetail,
        LyricsBatchDetailResult,
        LyricsBatchProgress,
        LyricsBatchResult,
        LyricsBatchSkipReason;

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
  static const _pendingDeleteService = LibraryPendingDeleteService();
  static const _localDeleteService = LibraryLocalDeleteService(
    hiddenStorageService: _hiddenStorageService,
    pendingDeleteService: _pendingDeleteService,
  );
  static const _localMoveService = LibraryLocalMoveService();
  static const _settingsService = LibrarySettingsService(database: _database);
  static const _playbackHistoryService = LibraryPlaybackHistoryService();
  static const _browseHistoryService = LibraryBrowseHistoryService();
  static const _searchHistoryService = LibrarySearchHistoryService(
    database: _database,
  );
  static const _playlistService = LibraryPlaylistService();
  static const _preferenceService = LibraryPreferenceService();
  static const _readService = LibraryReadService();
  static const _localRefreshService = LibraryLocalRefreshService(
    songPropertiesService: _songPropertiesService,
    readService: _readService,
    hiddenStorageService: _hiddenStorageService,
    audioMetadataService: _audioMetadataService,
    artistSplitService: _artistSplitService,
    localDeleteService: _localDeleteService,
  );

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

  LibraryLyricsSearchService get _lyricsSearchService =>
      LibraryLyricsSearchService(
        database: _database,
        localLyricsResolver: _lyricsService.getLocalLyricsForPath,
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

  Future<String> getDatabasePath() async {
    return (await _resolveDatabaseFile()).path;
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
      _playlistService.cleanupInvalidLastPlaylist(db);
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
      _playlistService.cleanupInvalidPlaylistItems(db);
      _playbackHistoryService.cleanupInvalidRecentPlayed(db);
      final settings = _readService.readLibrarySettings(db);
      final songs = _readService.readSongs(db);
      final playlists = _readPlaylists(db, settings);
      return RecentPageData(
        songs: songs,
        recentSongs: _playbackHistoryService.readRecentSongs(db, songs),
        recentPlaylists: _playbackHistoryService.readRecentPlaylists(db),
        recentAlbums: _playbackHistoryService.readRecentAlbums(db),
        recentArtists: _playbackHistoryService.readRecentArtists(db),
        recentSearches: _searchHistoryService.readRecentSearches(db),
        recentBrowses: _browseHistoryService.read(db),
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
      _playlistService.cleanupInvalidPlaylistItems(db);
      final settings = _readService.readLibrarySettings(db);
      final songs = _readService.readSongs(db);
      return ShellNavigationData(
        songs: songs,
        playlists: _readPlaylists(db, settings),
        folders: _readService.readFolders(db),
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

  Future<RecentBrowseEntry> recordRecentBrowse(
    RecentBrowseType type,
    String itemId,
  ) async {
    final databaseFile = await _resolveDatabaseFile();
    return _browseHistoryService.record(databaseFile, type, itemId);
  }

  Future<void> removeRecentBrowses(List<int> entryIds) async {
    final databaseFile = await _resolveDatabaseFile();
    await _browseHistoryService.remove(databaseFile, entryIds);
  }

  Future<void> restoreRecentBrowses(List<int> entryIds) async {
    final databaseFile = await _resolveDatabaseFile();
    await _browseHistoryService.restore(databaseFile, entryIds);
  }

  Future<void> clearRecentBrowses() async {
    final databaseFile = await _resolveDatabaseFile();
    await _browseHistoryService.clear(databaseFile);
  }

  Future<int> getLibrarySongCount() async {
    final databaseFile = await _resolveDatabaseFile();
    final db = _database.openInitializedLibraryDatabase(databaseFile);
    try {
      return _readService.readLibrarySongCount(db);
    } finally {
      db.dispose();
    }
  }

  Future<List<LibrarySong>> getLibrarySongs() async {
    final databaseFile = await _resolveDatabaseFile();
    final db = _database.openInitializedLibraryDatabase(databaseFile);
    try {
      return _readService.readSongs(db);
    } finally {
      db.dispose();
    }
  }

  Future<LibraryContentData> getLibraryContentData() async {
    final databaseFile = await _resolveDatabaseFile();
    final db = _database.openInitializedLibraryDatabase(databaseFile);
    try {
      _playlistService.cleanupInvalidPlaylistItems(db);
      final settings = _readService.readLibrarySettings(db);
      final songs = _readService.readSongs(db);
      final folders = _readService.readFolders(db);
      final playlists = _readPlaylists(db, settings);
      final nowPlaying = _playbackHistoryService.readNowPlaying(
        db,
        _resolveNowPlayingFile(),
        settings.nowPlayingId,
      );
      return LibraryContentData(
        songs: songs,
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
      cleanupInvalidLastPlaylist: _playlistService.cleanupInvalidLastPlaylist,
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

  Future<void> saveDisplayModeState({
    required settings.SmPlayerDisplayMode lastDisplayMode,
  }) async {
    final databaseFile = await _resolveDatabaseFile();
    await _settingsService.saveDisplayModeState(
      databaseFile,
      lastDisplayMode: lastDisplayMode,
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
    final pendingFile = await _resolvePendingSongDeletesFile();
    return _localDeleteService.beginDeleteSongFromDisk(
      databaseFile,
      pendingFile,
      songId,
    );
  }

  Future<void> undoDeleteSongFromDisk(String deleteId) async {
    final databaseFile = await _resolveDatabaseFile();
    final pendingFile = await _resolvePendingSongDeletesFile();
    await _localDeleteService.undoDeleteSongFromDisk(
      databaseFile,
      pendingFile,
      deleteId,
    );
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
    final result = await _localMoveService.moveSongToFolder(
      databaseFile,
      songId,
      folderPath,
      resolveConflict: resolveConflict,
    );
    await _lyricsSearchService.refreshSongIds(
      databaseFile,
      result.songs.map((song) => song.id).toList(),
    );
    return result;
  }

  Future<LocalItemsMoveResult> moveLocalItemsToFolder(
    List<int> songIds,
    List<String> folderPaths,
    String targetFolderPath, {
    LocalMoveConflictResolver? resolveConflict,
  }) async {
    final databaseFile = await _resolveDatabaseFile();
    final result = await _localMoveService.moveLocalItemsToFolder(
      databaseFile,
      songIds,
      folderPaths,
      targetFolderPath,
      resolveConflict: resolveConflict,
    );
    await _lyricsSearchService.refreshSongIds(
      databaseFile,
      result.songs.map((song) => song.id).toList(),
    );
    return result;
  }

  Future<void> undoMoveLocalItems(LocalItemsMoveResult result) async {
    final databaseFile = await _resolveDatabaseFile();
    await _localMoveService.undoMoveLocalItems(databaseFile, result);
    await _lyricsSearchService.refreshSongIds(
      databaseFile,
      result.songs.map((song) => song.id).toList(),
    );
  }

  Future<PendingLocalItemsDelete> beginDeleteLocalItems(
    List<int> songIds,
    List<String> folderPaths,
  ) async {
    final databaseFile = await _resolveDatabaseFile();
    final pendingFile = await _resolvePendingSongDeletesFile();
    return _localDeleteService.beginDeleteLocalItems(
      databaseFile,
      pendingFile,
      songIds,
      folderPaths,
    );
  }

  Future<void> undoDeleteLocalItems(String deleteId) async {
    final databaseFile = await _resolveDatabaseFile();
    final pendingFile = await _resolvePendingSongDeletesFile();
    await _localDeleteService.undoDeleteLocalItems(
      databaseFile,
      pendingFile,
      deleteId,
    );
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
    final databaseFile = await _resolveDatabaseFile();
    await _localRefreshService.renameFolder(databaseFile, folderPath, name);
    await _lyricsSearchService.refreshFolder(
      databaseFile,
      p.join(p.dirname(folderPath), name),
    );
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
    await _settingsService.updateMusicLibrarySort(databaseFile, criterion);
  }

  Future<void> updateAlbumsSort(AlbumSortCriterion criterion) async {
    final databaseFile = await _resolveDatabaseFile();
    await _settingsService.updateAlbumsSort(databaseFile, criterion);
  }

  Future<void> updateLocalFolderSort(
    String folderPath,
    LocalFolderSortCriterion criterion,
  ) async {
    final databaseFile = await _resolveDatabaseFile();
    await _settingsService.updateLocalFolderSort(
      databaseFile,
      folderPath,
      criterion,
    );
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
    final songs = await getLibrarySongs();
    return _artistSplitService.analyzeExistingLibrary(songs);
  }

  Future<void> applyArtistSplits(List<ArtistSplitResultItem> splits) async {
    final databaseFile = await _resolveDatabaseFile();
    await _artistSplitService.applySplits(databaseFile, splits);
  }

  Future<List<int>> importExternalAudioFiles(List<String> filePaths) async {
    final databaseFile = await _resolveDatabaseFile();
    final songIds = await _localRefreshService.importExternalAudioFiles(
      databaseFile,
      filePaths,
      cacheSongArtwork: _cacheSongArtwork,
    );
    await _lyricsSearchService.refreshSongIds(databaseFile, songIds);
    return songIds;
  }

  Future<LocalFolderRefreshResult> scanAllMusicLibrary(
    String rootPath, {
    void Function(LocalFolderRefreshProgress progress)? onProgress,
    LocalFolderScanCancellation? cancellation,
  }) async {
    final databaseFile = await _resolveDatabaseFile();
    final result = await _localRefreshService.scanAllMusicLibrary(
      databaseFile,
      rootPath,
      cacheSongArtwork: _cacheSongArtwork,
      readAutoLyricsEnabled: _lyricsService.readAutoLyricsEnabled,
      autoAddInternetLyricsForPaths: _autoAddInternetLyricsForPaths,
      pruneArtworkCache: _pruneArtworkCache,
      onProgress: onProgress,
      cancellation: cancellation,
    );
    await _lyricsSearchService.refreshFolder(databaseFile, rootPath);
    return result;
  }

  Future<LocalFolderRefreshResult> refreshLocalFolder(
    String folderPath, {
    void Function(LocalFolderRefreshProgress progress)? onProgress,
    LocalFolderScanCancellation? cancellation,
  }) async {
    final databaseFile = await _resolveDatabaseFile();
    final result = await _localRefreshService.refreshLocalFolder(
      databaseFile,
      folderPath,
      cacheSongArtwork: _cacheSongArtwork,
      readAutoLyricsEnabled: _lyricsService.readAutoLyricsEnabled,
      autoAddInternetLyricsForPaths: _autoAddInternetLyricsForPaths,
      pruneArtworkCache: _pruneArtworkCache,
      onProgress: onProgress,
      cancellation: cancellation,
    );
    await _lyricsSearchService.refreshFolder(databaseFile, folderPath);
    return result;
  }

  Future<LocalFolderRefreshResult> createLocalFolder(
    String rootPath,
    String relativePath,
    String name, {
    void Function(LocalFolderRefreshProgress progress)? onProgress,
    LocalFolderScanCancellation? cancellation,
  }) async {
    return _localRefreshService.createLocalFolder(
      rootPath,
      relativePath,
      name,
      refreshLocalFolder: refreshLocalFolder,
      onProgress: onProgress,
      cancellation: cancellation,
    );
  }

  Future<void> setSongsFavorite(List<int> songIds, bool favorite) async {
    final databaseFile = await _resolveDatabaseFile();
    _initializeLibraryDatabaseFile(databaseFile);
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
    await _lyricsSearchService.refreshSongIds(databaseFile, [songId]);
  }

  Future<List<LocalLyricsSearchMatch>> searchLocalLyrics(
    String query, {
    String folderPath = '',
    void Function(LocalLyricsIndexProgress progress)? onIndexProgress,
  }) async {
    final databaseFile = await _resolveDatabaseFile();
    return _lyricsSearchService.search(
      databaseFile,
      query,
      folderPath: folderPath,
      onIndexProgress: onIndexProgress,
    );
  }

  Future<void> updateLyricsOffset(int songId, int offsetMs) async {
    final databaseFile = await _resolveDatabaseFile();
    await _lyricsService.updateLyricsOffset(databaseFile, songId, offsetMs);
  }

  Future<LyricsSnapshot> getInternetLyrics(int songId) async {
    final databaseFile = await _resolveDatabaseFile();
    return _lyricsService.getInternetLyrics(databaseFile, songId);
  }

  Future<void> openLyricsSearchInBrowser(int songId) async {
    final databaseFile = await _resolveDatabaseFile();
    final uri = await _lyricsService.getLyricsSearchUri(databaseFile, songId);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) {
      throw StateError('Failed to open lyrics search in browser.');
    }
  }

  Future<LyricsBatchResult> batchAddInternetLyrics({
    bool overwrite = false,
    void Function(LyricsBatchProgress progress)? onProgress,
    bool Function()? isCanceled,
    Future<void> Function()? waitIfPaused,
  }) async {
    final databaseFile = await _resolveDatabaseFile();
    final songs = await getLibrarySongs();
    final result = await _lyricsService.batchAddInternetLyrics(
      songs: songs,
      overwrite: overwrite,
      onProgress: onProgress,
      isCanceled: isCanceled,
      waitIfPaused: waitIfPaused,
    );
    final changedSongIds = [
      for (final detail in result.details)
        if (detail.result == LyricsBatchDetailResult.saved ||
            detail.result == LyricsBatchDetailResult.overwritten)
          detail.songId,
    ];
    await _lyricsSearchService.refreshSongIds(databaseFile, changedSongIds);
    return result;
  }

  Future<void> _autoAddInternetLyricsForPaths(List<String> songPaths) async {
    final databaseFile = await _resolveDatabaseFile();
    await _lyricsService.autoAddInternetLyricsForPaths(databaseFile, songPaths);
    await _lyricsSearchService.refreshPaths(databaseFile, songPaths);
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

  Future<PreferenceSettingsSnapshot> getPreferenceSettings({
    required String unknownAlbumName,
  }) async {
    final databaseFile = await _resolveDatabaseFile();
    return _preferenceService.getPreferenceSettings(
      databaseFile,
      unknownAlbumName: unknownAlbumName,
    );
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

  Future<RecentPlaylistPlayback> recordPlaylistPlayed(int playlistId) async {
    final databaseFile = await _resolveDatabaseFile();
    return _playbackHistoryService.recordPlaylistPlayed(
      databaseFile,
      playlistId,
    );
  }

  Future<RecentAlbumPlayback> recordAlbumPlayed(String album) async {
    final databaseFile = await _resolveDatabaseFile();
    return _playbackHistoryService.recordAlbumPlayed(databaseFile, album);
  }

  Future<RecentArtistPlayback> recordArtistPlayed(String artist) async {
    final databaseFile = await _resolveDatabaseFile();
    return _playbackHistoryService.recordArtistPlayed(databaseFile, artist);
  }

  Future<String> _cacheSongArtwork(String filePath) async {
    return _artworkService.cacheSongArtwork(filePath);
  }

  Future<void> _pruneArtworkCache(Database db) async {
    await _artworkService.pruneArtworkCache(db);
  }

  List<LibraryPlaylist> _readPlaylists(
    Database db,
    LibraryReadSettings settings,
  ) {
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

  void _initializeLibraryDatabaseFile(File databaseFile) {
    final db = _database.openInitializedLibraryDatabase(databaseFile);
    db.dispose();
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
