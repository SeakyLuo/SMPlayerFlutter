import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:url_launcher/url_launcher.dart';

import 'id3_tag_service.dart';
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
import 'library_snapshot_service.dart';
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

part 'library_repository_platform.dart';
part 'library_repository_local_operations.dart';
part 'library_repository_collections.dart';

typedef _LyricsCacheKey =
    ({
      LibraryRepository repository,
      int songId,
      settings.LyricsRequestMode mode,
    });

class LibraryRepository
    with _LibraryRepositoryLocalOperations, _LibraryRepositoryCollections {
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
  static const _lyricsCacheCapacity = 64;
  static final _lyricsCache = <_LyricsCacheKey, LyricsSnapshot>{};
  static final _lyricsLoads = <_LyricsCacheKey, Future<LyricsSnapshot>>{};
  static final _lyricsCacheEpochs = Expando<int>();
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
  @override
  final TrashPath _trashPath;
  final InternetLyricsResolver? _internetLyricsResolver;
  final ShellThumbnailResolver _shellThumbnailResolver;

  LibraryArtworkService get _artworkService => LibraryArtworkService(
    databaseFileResolver: _resolveDatabaseFile,
    shellThumbnailResolver: _shellThumbnailResolver,
  );

  @override
  LibraryLyricsService get _lyricsService => LibraryLyricsService(
    settingsSnapshotResolver: getSettingsSnapshot,
    internetLyricsResolver: _internetLyricsResolver,
  );

  @override
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
    await LibrarySnapshotService.run(() {
      final db = _database.openInitializedLibraryDatabase(databaseFile);
      db.dispose();
    });
  }

  Future<String> getDatabasePath() async {
    return (await _resolveDatabaseFile()).path;
  }

  Future<settings.SettingsSnapshot?> initializeSettingsSnapshot() async {
    final databaseFile = await _resolveDatabaseFile();
    final result = await LibrarySnapshotService.run(() {
      databaseFile.parent.createSync(recursive: true);
      final db = sqlite3.open(databaseFile.path);
      try {
        final shouldCheck = _hasLegacyStartupArtistSplitCandidates(db);
        _database.initializeLibrarySchema(db);
        _playlistService.cleanupInvalidLastPlaylist(db);
        final rows = db.select(
          'SELECT * FROM Settings ORDER BY Id DESC LIMIT 1',
        );
        return (
          shouldCheck: shouldCheck,
          snapshot:
              rows.isEmpty
                  ? null
                  : _settingsService.settingsSnapshotFromRow(rows.single),
        );
      } finally {
        db.dispose();
      }
    });
    if (result.shouldCheck) {
      _startupArtistSplitPendingDatabasePaths.add(databaseFile.path);
    }
    return result.snapshot;
  }

  Future<RecentPageData> getRecentPageData() async {
    final databaseFile = await _resolveDatabaseFile();
    return const LibrarySnapshotService().readRecent(
      databaseFile.path,
      _resolveNowPlayingFile().path,
    );
  }

  Future<ShellNavigationData> getShellNavigationData() async {
    final databaseFile = await _resolveDatabaseFile();
    return const LibrarySnapshotService().readNavigation(
      databaseFile.path,
      _resolveNowPlayingFile().path,
    );
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
    return const LibrarySnapshotService().readSongCount(databaseFile.path);
  }

  Future<List<LibrarySong>> getLibrarySongs() async {
    final databaseFile = await _resolveDatabaseFile();
    return const LibrarySnapshotService().readSongs(databaseFile.path);
  }

  Future<LibraryContentData> getLibraryContentData() async {
    final databaseFile = await _resolveDatabaseFile();
    return const LibrarySnapshotService().readContent(
      databaseFile.path,
      _resolveNowPlayingFile().path,
    );
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

  Future<List<SongPropertiesSnapshot>> getSongPropertiesBatch(
    List<int> songIds,
  ) async {
    final databaseFile = await _resolveDatabaseFile();
    return _songPropertiesService.getSongPropertiesBatch(databaseFile, songIds);
  }

  Future<BatchSongPropertiesUpdateResult> updateSongPropertiesBatch(
    Map<int, SongPropertiesUpdate> updates,
  ) async {
    final databaseFile = await _resolveDatabaseFile();
    return _songPropertiesService.updateSongPropertiesBatch(
      databaseFile,
      updates,
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
    final key = (repository: this, songId: songId, mode: mode);
    final cached = _lyricsCache.remove(key);
    if (cached != null) {
      _lyricsCache[key] = cached;
      return cached;
    }

    final activeLoad = _lyricsLoads[key];
    if (activeLoad != null) {
      return activeLoad;
    }

    final revision = _lyricsCacheEpochs[this] ?? 0;
    final load = _loadSongLyrics(songId, mode);
    _lyricsLoads[key] = load;
    try {
      final lyrics = await load;
      if ((_lyricsCacheEpochs[this] ?? 0) == revision) {
        _lyricsCache[key] = lyrics;
        if (_lyricsCache.length > _lyricsCacheCapacity) {
          _lyricsCache.remove(_lyricsCache.keys.first);
        }
      }
      return lyrics;
    } finally {
      if (identical(_lyricsLoads[key], load)) {
        _lyricsLoads.remove(key);
      }
    }
  }

  LyricsSnapshot? getCachedSongLyrics(
    int songId, {
    settings.LyricsRequestMode mode = settings.LyricsRequestMode.auto,
  }) {
    final key = (repository: this, songId: songId, mode: mode);
    final cached = _lyricsCache.remove(key);
    if (cached != null) {
      _lyricsCache[key] = cached;
    }
    return cached;
  }

  Future<LyricsSnapshot> _loadSongLyrics(
    int songId,
    settings.LyricsRequestMode mode,
  ) async {
    final databaseFile = await _resolveDatabaseFile();
    return _lyricsService.getSongLyrics(databaseFile, songId, mode: mode);
  }

  Future<String> readLyricsFromFile(String filePath) async {
    return _lyricsService.readLyricsFromFile(filePath);
  }

  Future<void> saveSongLyrics(int songId, String rawLyrics) async {
    final databaseFile = await _resolveDatabaseFile();
    await _lyricsService.saveSongLyrics(databaseFile, songId, rawLyrics);
    _invalidateLyricsCache([songId]);
    await _lyricsSearchService.refreshSongIds(databaseFile, [songId]);
  }

  Future<List<LocalLyricsSearchMatch>> searchLocalLyrics(
    String query, {
    String folderPath = '',
  }) async {
    final databaseFile = await _resolveDatabaseFile();
    return _lyricsSearchService.searchAvailable(
      databaseFile,
      query,
      folderPath: folderPath,
    );
  }

  Future<void> indexMissingLocalLyrics({
    void Function(LocalLyricsIndexProgress progress)? onProgress,
  }) async {
    final databaseFile = await _resolveDatabaseFile();
    await _lyricsSearchService.indexMissingSongs(
      databaseFile,
      onProgress: onProgress,
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

  Future<List<InternetLyricsCandidate>> searchInternetLyricsCandidates(
    int songId,
  ) async {
    final databaseFile = await _resolveDatabaseFile();
    return _lyricsService.searchInternetLyricsCandidates(databaseFile, songId);
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
    void Function(LyricsBatchDetail detail, LyricsBatchProgress progress)?
    onDetailCompleted,
    bool Function()? isCanceled,
    Future<void> Function()? waitIfPaused,
  }) async {
    final databaseFile = await _resolveDatabaseFile();
    final songs = await getLibrarySongs();
    final result = await _lyricsService.batchAddInternetLyrics(
      songs: songs,
      overwrite: overwrite,
      onProgress: onProgress,
      onDetailCompleted: onDetailCompleted,
      isCanceled: isCanceled,
      waitIfPaused: waitIfPaused,
    );
    final changedSongIds = [
      for (final detail in result.details)
        if (detail.result == LyricsBatchDetailResult.saved ||
            detail.result == LyricsBatchDetailResult.overwritten)
          detail.songId,
    ];
    _invalidateLyricsCache(changedSongIds);
    await _lyricsSearchService.refreshSongIds(databaseFile, changedSongIds);
    return result;
  }

  @override
  Future<void> _autoAddInternetLyricsForPaths(List<String> songPaths) async {
    final databaseFile = await _resolveDatabaseFile();
    await _lyricsService.autoAddInternetLyricsForPaths(databaseFile, songPaths);
    _invalidateAllLyricsCache();
    await _lyricsSearchService.refreshPaths(databaseFile, songPaths);
  }

  void _invalidateLyricsCache(Iterable<int> songIds) {
    final ids = songIds.toSet();
    if (ids.isEmpty) {
      return;
    }
    _lyricsCacheEpochs[this] = (_lyricsCacheEpochs[this] ?? 0) + 1;
    _lyricsCache.removeWhere(
      (key, _) => identical(key.repository, this) && ids.contains(key.songId),
    );
    _lyricsLoads.removeWhere(
      (key, _) => identical(key.repository, this) && ids.contains(key.songId),
    );
  }

  void _invalidateAllLyricsCache() {
    final songIds = <int>{
      for (final key in _lyricsCache.keys)
        if (identical(key.repository, this)) key.songId,
      for (final key in _lyricsLoads.keys)
        if (identical(key.repository, this)) key.songId,
    };
    _invalidateLyricsCache(songIds);
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

  @override
  Future<String> _cacheSongArtwork(String filePath, Id3Picture? picture) async {
    return _artworkService.cacheSongArtwork(filePath, picture);
  }

  @override
  Future<void> _pruneArtworkCache(Database db) async {
    await _artworkService.pruneArtworkCache(db);
  }

  File _resolveNowPlayingFile() {
    return _paths.resolveNowPlayingFile();
  }

  @override
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

  @override
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
