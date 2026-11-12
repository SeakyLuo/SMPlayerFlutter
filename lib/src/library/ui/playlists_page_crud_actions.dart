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
      showPlaylistCreatedNotification(
        context: context,
        i18n: i18n,
        playlist: playlist,
      );
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
      title: i18n.t('playlists.deleteTitle'),
      message: i18n.t('headeredPlaylist.deleteConfirm', {
        'name': playlist.name,
      }),
      confirmText: i18n.t('playlists.delete'),
    );
    if (confirmed && context.mounted) {
      await _deletePlaylistWithUndo(context, i18n, playlist);
    }
  }

  Future<void> _deletePlaylistWithUndo(
    BuildContext context,
    SmPlayerI18n i18n,
    LibraryPlaylist playlist,
  ) async {
    final container = ProviderScope.containerOf(context, listen: false);
    final repository = container.read(libraryRepositoryProvider);
    final originalOrder = container.read(libraryPlaylistOrderProvider);
    await repository.deletePlaylist(playlist.id);
    _removeLocalPlaylist(playlist.id);
    unawaited(
      showUndoableAppNotification(
        i18n: i18n,
        message: i18n.t('notification.playlistRemoved', {
          'name': playlist.name,
        }),
        onUndo: () async {
          await repository.restorePlaylist(playlist);
          final deleted = container.read(
            libraryDeletedPlaylistIdsProvider.notifier,
          );
          final overrides = container.read(
            libraryPlaylistOverridesProvider.notifier,
          );
          deleted.state = {...deleted.state}..remove(playlist.id);
          overrides.state = {...overrides.state, playlist.id: playlist};
          if (originalOrder != null) {
            final order = container.read(libraryPlaylistOrderProvider.notifier);
            final restoredOrder = [...order.state!];
            final index = originalOrder.indexOf(playlist.id);
            restoredOrder.insert(
              index < restoredOrder.length ? index : restoredOrder.length,
              playlist.id,
            );
            order.state = restoredOrder;
          }
        },
      ),
    );
  }

  Future<void> _showPlaylistMenu(
    BuildContext context,
    SmPlayerI18n i18n,
    LibraryContentData snapshot,
    LibraryPlaylist playlist,
    Offset position,
  ) async {
    await showMenuFlyout(
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
    if (mounted) {
      showPlaylistCreatedNotification(
        context: context,
        i18n: context.smPlayerI18n,
        playlist: duplicatedPlaylist,
      );
    }
  }
}
