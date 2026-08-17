part of 'playlists_page.dart';

extension _PlaylistsPageCrudActions on _PlaylistsPageState {
  Future<void> _createPlaylist(
    BuildContext context,
    SmPlayerI18n i18n,
    LibraryContentData snapshot, [
    List<int> songIds = const [],
  ]) async {
    final name = await _requestPlaylistName(
      context: context,
      i18n: i18n,
      title: i18n.t('playlists.createNew'),
      defaultName: getNextPlaylistName(
        i18n.t('common.playlist'),
        snapshot.playlists,
      ),
      confirmText: i18n.t('playlists.create'),
      playlists: snapshot.playlists,
      currentName: '',
    );
    if (name == null) {
      return;
    }

    final playlist = await ref
        .read(libraryRepositoryProvider)
        .createPlaylist(name, songIds);
    _addLocalPlaylist(playlist);
    if (context.mounted) {
      _persistLastPlaylist(playlist.id);
      context.go('/playlists/${playlist.id}');
    }
  }

  void _persistLastPlaylist(int playlistId) {
    if (_lastPersistedPlaylistId == playlistId) {
      return;
    }
    _lastPersistedPlaylistId = playlistId;
    unawaited(_saveLastPlaylist(playlistId));
  }

  Future<void> _saveLastPlaylist(int playlistId) async {
    await ref
        .read(libraryRepositoryProvider)
        .saveViewState(lastPlaylistId: playlistId);
  }

  Future<void> _renamePlaylist(
    BuildContext context,
    SmPlayerI18n i18n,
    LibraryContentData snapshot,
    LibraryPlaylist playlist,
  ) async {
    final name = await _requestPlaylistName(
      context: context,
      i18n: i18n,
      title: i18n.t('playlists.rename'),
      defaultName: playlist.name,
      confirmText: i18n.t('playlists.rename'),
      playlists: snapshot.playlists,
      currentName: playlist.name,
    );
    if (name != null && name != playlist.name) {
      _renamePlaylistWithoutReload(playlist, name);
    }
  }

  void _renamePlaylistWithoutReload(LibraryPlaylist playlist, String name) {
    _patchLocalPlaylist(_copyPlaylistWithName(playlist, name));
    unawaited(_persistPlaylistRename(playlist.id, name));
  }

  Future<void> _persistPlaylistRename(int playlistId, String name) async {
    await ref.read(libraryRepositoryProvider).renamePlaylist(playlistId, name);
    ref.invalidate(recentPageDataProvider);
  }

  Future<void> _addSongsToPlaylistWithoutReload(
    LibraryContentData snapshot,
    int playlistId,
    List<int> songIds,
  ) async {
    if (playlistId == snapshot.favoritePlaylistId) {
      await setSongsFavorite(ref, songIds, true);
      return;
    }
    await ref
        .read(libraryRepositoryProvider)
        .addSongsToPlaylist(playlistId, songIds);
    final playlist = snapshot.playlists.firstWhere(
      (playlist) => playlist.id == playlistId,
    );
    _patchLocalPlaylist(
      _copyPlaylistWithSongIds(
        playlist,
        _addUniqueSongIds(playlist.songIds, songIds),
      ),
    );
  }

  Future<void> _deletePlaylist(
    BuildContext context,
    SmPlayerI18n i18n,
    LibraryPlaylist playlist,
  ) async {
    final confirmed = await showSmPlayerConfirmDialog(
      context: context,
      i18n: i18n,
      title: i18n.t('playlists.delete'),
      message: i18n.t('headeredPlaylist.deleteConfirm', {
        'name': playlist.name,
      }),
      confirmText: i18n.t('playlists.delete'),
    );
    if (confirmed) {
      await ref.read(libraryRepositoryProvider).deletePlaylist(playlist.id);
      _removeLocalPlaylist(playlist.id);
    }
  }

  void _showPlaylistMenu(
    BuildContext context,
    SmPlayerI18n i18n,
    LibraryContentData snapshot,
    LibraryPlaylist playlist,
    Offset position,
  ) {
    showMenuFlyout(
      context,
      position: position,
      items: [
        MenuFlyoutItem(
          key: 'rename-playlist',
          text: i18n.t('playlists.rename'),
          icon: FluentIcons.edit_20_regular,
          onPressed: () {
            unawaited(_renamePlaylist(context, i18n, snapshot, playlist));
          },
        ),
        MenuFlyoutItem(
          key: 'duplicate-playlist',
          text: i18n.t('playlists.duplicate'),
          icon: FluentIcons.copy_20_regular,
          onPressed: () {
            unawaited(_duplicatePlaylist(snapshot, playlist));
          },
        ),
        MenuFlyoutItem(
          key: 'delete-playlist',
          text: i18n.t('playlists.delete'),
          icon: FluentIcons.delete_20_regular,
          onPressed: () {
            unawaited(_deletePlaylist(context, i18n, playlist));
          },
        ),
      ],
    );
  }

  Future<void> _duplicatePlaylist(
    LibraryContentData snapshot,
    LibraryPlaylist playlist,
  ) async {
    final duplicatedPlaylist = await ref
        .read(libraryRepositoryProvider)
        .createPlaylist(
          getNextPlaylistName(playlist.name, snapshot.playlists),
          playlist.songIds,
        );
    _addLocalPlaylist(duplicatedPlaylist);
  }
}
