part of 'playlists_page.dart';

extension _PlaylistsPageLocalOverrides on _PlaylistsPageState {
  void _patchLocalPlaylist(LibraryPlaylist playlist) {
    setState(() {
      _deletedPlaylistIds.remove(playlist.id);
      _playlistOverrides[playlist.id] = playlist;
    });
  }

  void _addLocalPlaylist(LibraryPlaylist playlist) {
    _patchLocalPlaylist(playlist);
  }

  void _removeLocalPlaylist(int playlistId) {
    setState(() {
      _deletedPlaylistIds.add(playlistId);
      _playlistOverrides.remove(playlistId);
      _committedPlaylistIds =
          _committedPlaylistIds
              ?.where(
                (committedPlaylistId) => committedPlaylistId != playlistId,
              )
              .toList();
    });
  }

  LibraryContentData _applyLocalSnapshotOverrides(LibraryContentData snapshot) {
    if (_playlistOverrides.isEmpty &&
        _deletedPlaylistIds.isEmpty &&
        _nowPlayingSongIdsOverride == null) {
      return snapshot;
    }
    var playlists =
        snapshot.playlists
            .where((playlist) => !_deletedPlaylistIds.contains(playlist.id))
            .map((playlist) => _playlistOverrides[playlist.id] ?? playlist)
            .toList();
    final playlistIds = playlists.map((playlist) => playlist.id).toSet();
    for (final playlist in _playlistOverrides.values) {
      if (playlistIds.contains(playlist.id) ||
          _deletedPlaylistIds.contains(playlist.id)) {
        continue;
      }
      playlists = _insertCustomPlaylistFirst(playlists, playlist);
      playlistIds.add(playlist.id);
    }
    return _copySnapshotWithPlaylists(
      snapshot,
      playlists,
      nowPlaying:
          _nowPlayingSongIdsOverride == null
              ? snapshot.nowPlaying
              : _copyNowPlayingWithSongIds(
                snapshot.nowPlaying,
                _nowPlayingSongIdsOverride!,
              ),
    );
  }
}
