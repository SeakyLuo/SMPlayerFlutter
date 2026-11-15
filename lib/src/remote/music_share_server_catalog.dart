part of 'music_share_server.dart';

extension SharedCatalogQueries on MusicShareServer {
  void markCatalogChanged() {
    _catalogGeneration++;
    if (running) events.dataChanged('library');
  }

  Future<void> _readSharedSongsOnAccess(List<int> ids) async {
    final (metadata, songs) =
        await (
          repository.queryLibrary(
            const LibraryDataQuery(LibraryQueryKind.context),
          ),
          repository.getLibrarySongs(songIds: ids),
        ).wait;
    _sharedSnapshot = libraryDataWithSongs(
      metadata.withPlaylists(_sharedSnapshot.playlists),
      songs,
    );
    updateLibrary(_sharedSnapshot, notify: false);
  }

  Future<void> _refreshSharedEntries(
    List<int> ids, {
    String? folder,
    bool directoriesChanged = false,
  }) async {
    final metadata =
        directoriesChanged
            ? await repository.queryLibrary(
              const LibraryDataQuery(LibraryQueryKind.context),
            )
            : _sharedSnapshot;
    final changed = ids.toSet();
    final retained =
        _songs.values
            .where(
              (song) =>
                  !changed.contains(song.id) &&
                  (folder == null ||
                      !(song.path == folder || p.isWithin(folder, song.path))),
            )
            .toList();
    _sharedSnapshot = libraryDataWithSongs(
      metadata.withPlaylists(_sharedSnapshot.playlists),
      retained,
    );
    updateLibrary(_sharedSnapshot);
  }
}
