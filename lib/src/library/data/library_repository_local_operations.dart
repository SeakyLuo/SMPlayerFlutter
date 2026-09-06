part of 'library_repository.dart';

mixin _LibraryRepositoryLocalOperations {
  Future<File> _resolveDatabaseFile();
  Future<File> _resolvePendingSongDeletesFile();
  TrashPath get _trashPath;
  LibraryLyricsSearchService get _lyricsSearchService;
  LibraryLyricsService get _lyricsService;
  Future<String> _cacheSongArtwork(String filePath, Id3Picture? picture);
  Future<void> _autoAddInternetLyricsForPaths(List<String> songPaths);
  Future<void> _pruneArtworkCache(Database db);

  Future<PendingSongDelete> beginDeleteSongFromDisk(int songId) async {
    final databaseFile = await _resolveDatabaseFile();
    final pendingFile = await _resolvePendingSongDeletesFile();
    return LibraryRepository._localDeleteService.beginDeleteSongFromDisk(
      databaseFile,
      pendingFile,
      songId,
    );
  }

  Future<void> undoDeleteSongFromDisk(String deleteId) async {
    final databaseFile = await _resolveDatabaseFile();
    final pendingFile = await _resolvePendingSongDeletesFile();
    await LibraryRepository._localDeleteService.undoDeleteSongFromDisk(
      databaseFile,
      pendingFile,
      deleteId,
    );
  }

  Future<void> commitDeleteSongFromDisk(String deleteId) async {
    final pendingFile = await _resolvePendingSongDeletesFile();
    await LibraryRepository._pendingDeleteService.commitSongDelete(
      pendingFile,
      deleteId,
      _trashPath,
    );
  }

  Future<void> commitPendingDeletes() async {
    final pendingFile = await _resolvePendingSongDeletesFile();
    await LibraryRepository._pendingDeleteService.commitPendingDeletes(
      pendingFile,
      _trashPath,
    );
  }

  Future<void> hideSong(int songId) async {
    final databaseFile = await _resolveDatabaseFile();
    await LibraryRepository._hiddenStorageService.hideSong(
      databaseFile,
      songId,
    );
  }

  Future<LocalItemsMoveResult> moveSongToFolder(
    int songId,
    String folderPath, {
    LocalMoveConflictResolver? resolveConflict,
  }) async {
    final databaseFile = await _resolveDatabaseFile();
    final result = await LibraryRepository._localMoveService.moveSongToFolder(
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
    final result = await LibraryRepository._localMoveService
        .moveLocalItemsToFolder(
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
    await LibraryRepository._localMoveService.undoMoveLocalItems(
      databaseFile,
      result,
    );
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
    return LibraryRepository._localDeleteService.beginDeleteLocalItems(
      databaseFile,
      pendingFile,
      songIds,
      folderPaths,
    );
  }

  Future<void> undoDeleteLocalItems(String deleteId) async {
    final databaseFile = await _resolveDatabaseFile();
    final pendingFile = await _resolvePendingSongDeletesFile();
    await LibraryRepository._localDeleteService.undoDeleteLocalItems(
      databaseFile,
      pendingFile,
      deleteId,
    );
  }

  Future<void> commitDeleteLocalItems(String deleteId) async {
    final pendingFile = await _resolvePendingSongDeletesFile();
    await LibraryRepository._pendingDeleteService.commitLocalItemsDelete(
      pendingFile,
      deleteId,
      _trashPath,
    );
  }

  Future<void> hideFolder(String folderPath) async {
    final databaseFile = await _resolveDatabaseFile();
    await LibraryRepository._hiddenStorageService.hideFolder(
      databaseFile,
      folderPath,
    );
  }

  Future<void> unhideSong(int songId) async {
    final databaseFile = await _resolveDatabaseFile();
    await LibraryRepository._hiddenStorageService.unhideSong(
      databaseFile,
      songId,
    );
  }

  Future<void> unhideFolder(String folderPath) async {
    final databaseFile = await _resolveDatabaseFile();
    await LibraryRepository._hiddenStorageService.unhideFolder(
      databaseFile,
      folderPath,
    );
  }

  Future<List<HiddenStorageItem>> getHiddenStorageItems() async {
    final databaseFile = await _resolveDatabaseFile();
    return LibraryRepository._hiddenStorageService.getHiddenStorageItems(
      databaseFile,
    );
  }

  Future<void> resumeHiddenStorageItem(HiddenStorageItem item) async {
    final databaseFile = await _resolveDatabaseFile();
    await LibraryRepository._hiddenStorageService.resumeHiddenStorageItem(
      databaseFile,
      item,
    );
  }

  Future<void> renameFolder(String folderPath, String name) async {
    final databaseFile = await _resolveDatabaseFile();
    await LibraryRepository._localRefreshService.renameFolder(
      databaseFile,
      folderPath,
      name,
    );
    await _lyricsSearchService.refreshFolder(
      databaseFile,
      p.join(p.dirname(folderPath), name),
    );
  }

  Future<List<int>> importExternalAudioFiles(List<String> filePaths) async {
    final databaseFile = await _resolveDatabaseFile();
    final songIds = await LibraryRepository._localRefreshService
        .importExternalAudioFiles(
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
    final result = await LibraryRepository._localRefreshService
        .scanAllMusicLibrary(
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
    final result = await LibraryRepository._localRefreshService
        .refreshLocalFolder(
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
    return LibraryRepository._localRefreshService.createLocalFolder(
      rootPath,
      relativePath,
      name,
      refreshLocalFolder: refreshLocalFolder,
      onProgress: onProgress,
      cancellation: cancellation,
    );
  }
}
