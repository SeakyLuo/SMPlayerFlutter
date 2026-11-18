import '../../platform/system_log.dart';
import 'library_sql_functions.dart';
import 'artist_split_model.dart' as artist_rules;
import '../../playback/quick_play_model.dart'
    show quickPlayDatabasePlan, QuickPlayDatabasePlan;
import 'library_source.dart';
import 'library_text.dart';
import 'library_queries.dart';
import 'library_selection.dart';
import 'dart:convert';
import 'dart:isolate';
import '../../remote/music_share_access.dart';
import '../../remote/music_share_models.dart';
import '../../remote/music_share_edit_codec.dart';
import '../../remote/music_share_scan_codec.dart';
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
import 'library_file_relocation_service.dart';
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
import 'library_scan_task_coordinator.dart';
import 'library_settings_service.dart';
import 'library_song_properties_service.dart';
import 'package:smplayer_flutter/src/settings/settings_model.dart' as settings;
import 'package:smplayer_flutter/src/settings/settings_model.dart'
    show
        PreferenceEntityType,
        PreferenceItemSnapshot,
        PreferenceLevel,
        PreferenceSectionKey,
        PreferenceSettingsSnapshot;

export 'library_source.dart';

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

part 'library_data_source.dart';
part 'local_library_data_source.dart';
part 'remote_library_data_source.dart';
part 'local_library_storage.dart';
part 'remote_library_storage.dart';

part 'library_repository_song_editing.dart';
part 'library_repository_remote_editing.dart';
part 'library_repository_preferences.dart';
part 'library_repository_shared_files.dart';
part 'library_repository_platform.dart';
part 'library_repository_local_operations.dart';
part 'library_repository_collections.dart';
part 'library_repository_data_transfer.dart';
part 'library_repository_queries.dart';
part 'library_source_reading.dart';
part 'library_selection_queries.dart';
part 'library_database_selection.dart';
part 'library_quick_play_query.dart';
part 'library_task_queries.dart';
part 'library_collection_queries.dart';
part 'library_folder_queries.dart';
part 'library_song_references.dart';
part 'library_scope_ids.dart';

typedef _LyricsCacheKey =
    ({
      LibraryRepository repository,
      int songId,
      settings.LyricsRequestMode mode,
    });

class LibraryRepository
    with
        _LibraryDataSources,
        _LibraryRepositoryLocalOperations,
        _LibraryRepositoryCollections,
        _LibraryRepositorySongEditing,
        _LibraryRepositoryRemoteEditing,
        _LibraryRepositoryPreferences,
        _LibraryRepositorySharedFiles,
        _LibraryRepositoryQueries {
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

  @override
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
        _playlistService.cleanupInvalidPlaylistItems(db);
        _playbackHistoryService.cleanupInvalidRecentPlayed(db);
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

  Future<RecentPageData> getRecentPageData(LibraryContentData content) {
    return const LibrarySnapshotService().readRecent(content);
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

  @override
  Future<List<LibrarySong>> getLibrarySongs({
    required List<int> songIds,
  }) async {
    return resolveSongDetails(songIds);
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

  Future<settings.SettingsSnapshot?> getSettingsSnapshot() async {
    final databaseFile = await _resolveDatabaseFile();
    return _settingsService.getSettingsSnapshot(
      databaseFile,
      cleanupInvalidLastPlaylist: _playlistService.cleanupInvalidLastPlaylist,
    );
  }

  Future<settings.SettingsSnapshot> readSettingsSnapshot() async {
    final databaseFile = await _resolveDatabaseFile();
    return _settingsService.readSettingsSnapshot(databaseFile);
  }

  Future<void> updateSettings(settings.AppSettingsUpdate update) async {
    final databaseFile = await _resolveDatabaseFile();
    final previous =
        update.rootPath == null
            ? null
            : _settingsService.readSettingsSnapshot(databaseFile);
    await _settingsService.updateSettings(databaseFile, update);
    if (update.rootPath != null) {
      try {
        await activeMusicShareAccess?.syncSharingConfiguration();
      } catch (error, stack) {
        await _settingsService.updateSettings(
          databaseFile,
          settings.AppSettingsUpdate(rootPath: previous!.rootPath),
        );
        SystemLog.error(
          'Sharing root update failed; restored previous music folder',
          error,
          stack,
        );
        rethrow;
      }
    }
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

  Future<void> replaceNowPlaying(
    List<int> songIds, {
    bool recordHistory = false,
  }) async {
    final databaseFile = await _resolveDatabaseFile();
    await _playbackHistoryService.replaceNowPlaying(
      databaseFile,
      _resolveNowPlayingFile(databaseFile),
      songIds,
      recordHistory: recordHistory,
    );
  }

  Future<void> clearNowPlaying() async {
    await replaceNowPlaying([]);
  }

  Future<void> removeSongFromNowPlaying(int songId) async {
    final databaseFile = await _resolveDatabaseFile();
    await _playbackHistoryService.removeSongFromNowPlaying(
      databaseFile,
      _resolveNowPlayingFile(databaseFile),
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

  Future<ArtistSplitAnalysisResult> analyzeArtistSplits({
    void Function(double progress)? onProgress,
  }) async {
    final source = LibrarySource.fromDevice(
      activeMusicShareAccess?.selectedSource ?? 'local',
    );
    return dataSource(source).analyzeArtists(onProgress: onProgress);
  }

  Future<void> applyArtistSplits(List<ArtistSplitResultItem> splits) async {
    if (splits.isEmpty) return;
    final references = await songReferences(
      splits.map((split) => split.songId).toList(),
    );
    final byId = {for (final split in splits) split.songId: split};
    final groups = _groupSongReferences(references);
    for (final source in groups.keys) {
      _requireWritable(dataSource(source));
    }
    await Future.wait(
      groups.entries.map(
        (entry) => dataSource(entry.key).applyArtistSplits(
          entry.value,
          entry.value.keys.map((id) => byId[id]!).toList(),
        ),
      ),
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
      if (lyrics.cacheable && (_lyricsCacheEpochs[this] ?? 0) == revision) {
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

  Future<LyricsSnapshot> getLocalLyricsForPath(String songPath) =>
      _lyricsService.getLocalLyricsForPath(songPath);

  Future<String> readLyricsFromFile(String filePath) async {
    return _lyricsService.readLyricsFromFile(filePath);
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

  Future<LibraryLyricsSearchPage> queryLocalLyrics(
    String query, {
    String folderPath = '',
    int offset = 0,
    MusicLibrarySortCriterion? order,
  }) async {
    final file = await _resolveDatabaseFile();
    final page = await _lyricsSearchService.searchPage(
      file,
      query,
      folderPath: folderPath,
      offset: offset,
      order: order,
    );
    final songs =
        page.matches.isEmpty
            ? const <LibrarySong>[]
            : await getLibrarySongs(
              songIds: page.matches.map((match) => match.songId).toList(),
            );
    return LibraryLyricsSearchPage(
      matches: page.matches,
      totalCount: page.totalCount,
      songs: songs,
    );
  }

  Future<void> indexMissingLocalLyrics({
    String folderPath = '',
    void Function(LocalLyricsIndexProgress progress)? onProgress,
  }) async {
    final databaseFile = await _resolveDatabaseFile();
    if (folderPath.isNotEmpty) {
      await _lyricsSearchService.refreshFolder(
        databaseFile,
        folderPath,
        onlyChanged: true,
      );
      return;
    }
    await _lyricsSearchService.indexMissingSongs(
      databaseFile,
      onProgress: onProgress,
    );
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
    return runInternetLyricsBatch(
      overwrite: overwrite,
      onProgress: onProgress,
      onDetailCompleted: onDetailCompleted,
      isCanceled: isCanceled,
      waitIfPaused: waitIfPaused,
    );
  }

  @override
  Future<void> _autoAddInternetLyricsForPaths(List<String> songPaths) async {
    final databaseFile = await _resolveDatabaseFile();
    await _lyricsService.autoAddInternetLyricsForPaths(databaseFile, songPaths);
    _invalidateAllLyricsCache();
    await _lyricsSearchService.refreshPaths(databaseFile, songPaths);
  }

  @override
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

  @override
  Future<String> _cacheSongArtwork(String filePath, Id3Picture? picture) async {
    return _artworkService.cacheSongArtwork(filePath, picture);
  }

  @override
  Future<void> _pruneArtworkCache(Database db) async {
    await _artworkService.pruneArtworkCache(db);
  }

  File _resolveNowPlayingFile(File databaseFile) {
    return _paths.resolveNowPlayingFile(databaseFile);
  }

  @override
  Future<File> _resolveDatabaseFile() async {
    return _paths.resolveDatabaseFile(
      windowsUwpDatabaseResolver:
          _dataTransferService.resolveWindowsUwpDatabaseFile,
    );
  }

  @override
  Future<File> _resolvePendingSongDeletesFile() async {
    final databaseFile = await _resolveDatabaseFile();
    return _paths.resolvePendingSongDeletesFile(databaseFile);
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
