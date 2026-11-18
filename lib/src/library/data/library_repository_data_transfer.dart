part of 'library_repository.dart';

extension LibraryRepositoryDataTransfer on LibraryRepository {
  Future<bool> exportDataTo(String targetPath) async {
    final databaseFile = await _resolveDatabaseFile();
    return LibraryRepository._dataTransferService.exportDataTo(
      databaseFile,
      targetPath,
      nowPlayingFile: _resolveNowPlayingFile(databaseFile),
    );
  }

  Future<bool> importDataFrom(
    String sourcePath, {
    bool restoreNowPlaying = true,
  }) async {
    final databaseFile = await _resolveDatabaseFile();
    Future<bool> performImport() =>
        LibraryRepository._dataTransferService.importDataFrom(
          databaseFile,
          sourcePath,
          rescanLibrary: scanAllMusicLibrary,
          nowPlayingFile: _resolveNowPlayingFile(databaseFile),
          restoreNowPlaying: restoreNowPlaying,
        );
    final share = activeMusicShareAccess;
    return share == null
        ? performImport()
        : share.withSharingSuspended(performImport);
  }
}
