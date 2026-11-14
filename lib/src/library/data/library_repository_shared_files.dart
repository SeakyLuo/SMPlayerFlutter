part of 'library_repository.dart';

mixin _LibraryRepositorySharedFiles {
  Future<File> _resolveDatabaseFile();
  LibraryLyricsSearchService get _lyricsSearchService;
  void _invalidateLyricsCache(Iterable<int> songIds);

  Future<SongFileRelocation> relocateSharedSong(
    LibrarySong song,
    String target,
    int folderId,
    String root,
  ) async {
    final file = await _resolveDatabaseFile();
    final result = await const LibraryFileRelocationService().relocate(
      file,
      song.id,
      song.path,
      target,
      folderId,
      root,
    );
    _invalidateLyricsCache([song.id]);
    _lyricsSearchService.refreshSongIdsInBackground(file, [song.id]);
    return result;
  }

  Future<void> undoSharedSongRelocation(SongFileRelocation result) async {
    final file = await _resolveDatabaseFile();
    await const LibraryFileRelocationService().undo(file, result);
    _invalidateLyricsCache([result.songId]);
    _lyricsSearchService.refreshSongIdsInBackground(file, [result.songId]);
  }
}
