part of 'local_page.dart';

extension _LocalPageAddToActions on _LocalPageState {
  void _addSongsToNowPlaying(List<int> songIds) {
    addSongsToNowPlayingWithUndo(
      context: context,
      ref: ref,
      i18n: context.smPlayerI18n,
      songIds: songIds,
    );
  }

  Future<void> _addSongsToPlaylist(int playlistId, List<int> songIds) async {
    await addSongsToPlaylistWithUndo(
      context: context,
      ref: ref,
      i18n: context.smPlayerI18n,
      playlistId: playlistId,
      songIds: songIds,
    );
  }

  Future<void> _toggleSongsFavorite(List<int> songIds, bool favorite) async {
    await setSongsFavoriteWithUndo(
      context: context,
      ref: ref,
      i18n: context.smPlayerI18n,
      songIds: songIds,
      favorite: favorite,
    );
  }

  void _showAddToMenu({
    required Offset position,
    required List<int> songIds,
    required String defaultPlaylistName,
    required List<MultiSelectCommandBarPlaylist> playlists,
    required LibraryViewData snapshot,
    required SmPlayerI18n i18n,
  }) {
    final songsById = {for (final song in snapshot.songs) song.id: song};
    final addToItem = buildAddToPlaylistMenuFlyoutItem(
      i18n: i18n,
      songIds: songIds,
      playlists: playlists,
      includeNowPlaying: true,
      includeFavorites: _hasNotFavoriteSongs(songIds, songsById),
      onAddToNowPlaying: () {
        _addSongsToNowPlaying(songIds);
      },
      onToggleFavorite: () {
        _toggleSongsFavorite(_notFavoriteSongIds(songIds, songsById), true);
      },
      onCreatePlaylist: () {
        _createPlaylist(defaultPlaylistName, songIds, snapshot, i18n);
      },
      onAddToPlaylist: (playlistId) {
        _addSongsToPlaylist(playlistId, songIds);
      },
    );

    if (addToItem == null) {
      return;
    }

    showMenuFlyout(context, position: position, items: addToItem.submenu);
  }

  Future<void> _createPlaylist(
    String defaultName,
    List<int> songIds,
    LibraryViewData snapshot,
    SmPlayerI18n i18n,
  ) async {
    final name = await _requestPlaylistName(
      i18n: i18n,
      defaultName: defaultName,
      playlists: snapshot.playlists,
    );
    if (name == null) {
      return;
    }

    await ref.read(libraryRepositoryProvider).createPlaylist(name, songIds);
    ref.invalidate(libraryViewDataProvider);
  }

  Future<String?> _requestPlaylistName({
    required SmPlayerI18n i18n,
    required String defaultName,
    required List<LibraryPlaylist> playlists,
  }) async {
    final result = await showSmPlayerInputDialog(
      context: context,
      i18n: i18n,
      title: i18n.t('playlists.createNew'),
      defaultValue: defaultName,
      placeholder: i18n.t('playlists.namePlaceholder'),
      confirmText: i18n.t('playlists.create'),
      validate: (name) {
        return validatePlaylistName(name, playlists, '', i18n);
      },
    );
    return result;
  }

  bool _hasNotFavoriteSongs(
    List<int> songIds,
    Map<int, LibrarySong> songsById,
  ) {
    return songIds.any((songId) => !songsById[songId]!.favorite);
  }

  List<int> _notFavoriteSongIds(
    List<int> songIds,
    Map<int, LibrarySong> songsById,
  ) {
    return songIds.where((songId) => !songsById[songId]!.favorite).toList();
  }
}
