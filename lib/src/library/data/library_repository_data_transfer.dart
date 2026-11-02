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
    return LibraryRepository._dataTransferService.importDataFrom(
      databaseFile,
      sourcePath,
      rescanLibrary: scanAllMusicLibrary,
      nowPlayingFile: _resolveNowPlayingFile(databaseFile),
      restoreNowPlaying: restoreNowPlaying,
    );
  }
}
