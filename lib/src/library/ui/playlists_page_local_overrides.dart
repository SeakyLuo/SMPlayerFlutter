part of 'playlists_page.dart';

extension _PlaylistsPageLocalOverrides on _PlaylistsPageState {
  void _patchLocalPlaylist(LibraryPlaylist playlist) {
    patchLibraryPlaylistOverride(ref, playlist);
  }

  void _addLocalPlaylist(LibraryPlaylist playlist) {
    _patchLocalPlaylist(playlist);
  }

  void _removeLocalPlaylist(int playlistId) {
    setState(() {
      _committedPlaylistIds =
          _committedPlaylistIds
              ?.where(
                (committedPlaylistId) => committedPlaylistId != playlistId,
              )
              .toList();
    });
    removeLibraryPlaylistOverride(ref, playlistId);
  }

  LibraryContentData _applyLocalSnapshotOverrides(
    LibraryContentData snapshot,
    List<int>? nowPlayingSongIdsOverride,
  ) {
    if (nowPlayingSongIdsOverride == null) {
      return snapshot;
    }
    return _copySnapshotWithPlaylists(
      snapshot,
      snapshot.playlists,
      nowPlaying: _copyNowPlayingWithSongIds(
        snapshot.nowPlaying,
        nowPlayingSongIdsOverride,
      ),
    );
  }
}
