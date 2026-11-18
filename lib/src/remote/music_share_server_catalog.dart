part of 'music_share_server.dart';

extension SharedCatalogQueries on MusicShareServer {
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

  Future<Set<int>> _refreshSharedEntries(
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
    final changed = {
      ...ids,
      if (folder != null)
        for (final song in _songs.values)
          if (song.path == folder || p.isWithin(folder, song.path)) song.id,
    };
    for (final id in changed) {
      _songs.remove(id);
    }
    _sharedSnapshot = metadata
        .withPlaylists(_sharedSnapshot.playlists)
        .withPage(songs: const []);
    _rootPath = metadata.rootPath;
    markCatalogChanged();
    return changed;
  }
}
