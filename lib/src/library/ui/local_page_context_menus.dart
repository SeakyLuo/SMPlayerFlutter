part of 'local_page.dart';

extension _LocalPageContextMenus on _LocalPageState {
  void _showSortMenu(
    BuildContext buttonContext,
    SmPlayerI18n i18n,
    FolderNode currentNode,
  ) {
    showMenuFlyout(
      buttonContext,
      items: _localSortMenuItems(currentNode, i18n),
    );
  }

  List<MenuFlyoutItem> _localSortMenuItems(
    FolderNode currentNode,
    SmPlayerI18n i18n,
  ) {
    return [
      MenuFlyoutItem(
        key: 'toolbar-sort-reverse',
        text: i18n.t('local.sortReverseList'),
        onPressed:
            () => _updateSortMode(currentNode, LocalSortMode.reverse, i18n),
      ),
      const MenuFlyoutItem.separator(key: 'toolbar-sort-separator'),
      MenuFlyoutItem(
        key: 'toolbar-sort-title',
        text: i18n.t('local.sortByTitle'),
        icon:
            _sortMode == LocalSortMode.title
                ? FluentIcons.checkmark_20_regular
                : null,
        onPressed:
            () => _updateSortMode(currentNode, LocalSortMode.title, i18n),
      ),
      MenuFlyoutItem(
        key: 'toolbar-sort-artist',
        text: i18n.t('local.sortByArtist'),
        icon:
            _sortMode == LocalSortMode.artist
                ? FluentIcons.checkmark_20_regular
                : null,
        onPressed:
            () => _updateSortMode(currentNode, LocalSortMode.artist, i18n),
      ),
      MenuFlyoutItem(
        key: 'toolbar-sort-album',
        text: i18n.t('local.sortByAlbum'),
        icon:
            _sortMode == LocalSortMode.album
                ? FluentIcons.checkmark_20_regular
                : null,
        onPressed:
            () => _updateSortMode(currentNode, LocalSortMode.album, i18n),
      ),
    ];
  }

  Future<void> _showFolderMenu({
    required Offset position,
    required FolderNode folder,
    required Map<String, FolderNode> nodes,
    required Map<int, LibrarySong> songsById,
    required List<MultiSelectCommandBarPlaylist> playlists,
    required LibraryContentData snapshot,
    required SmPlayerI18n i18n,
  }) async {
    final preferenceLevel = await ref
        .read(libraryRepositoryProvider)
        .getPreferenceLevel('folder', '${folder.id}');
    if (!mounted) {
      return;
    }
    final addToItem = buildAddToPlaylistMenuFlyoutItem(
      i18n: i18n,
      songIds: folder.subtreeSongIds,
      playlists: playlists,
      includeNowPlaying: true,
      includeFavorites: _hasNotFavoriteSongs(folder.subtreeSongIds, songsById),
      onAddToNowPlaying: () {
        _addSongsToNowPlaying(folder.subtreeSongIds);
      },
      onToggleFavorite: () {
        _toggleSongsFavorite(
          _notFavoriteSongIds(folder.subtreeSongIds, songsById),
          true,
        );
      },
      onCreatePlaylist: () {
        _createPlaylist(folder.name, folder.subtreeSongIds, snapshot, i18n);
      },
      onAddToPlaylist: (playlistId) {
        _addSongsToPlaylist(playlistId, folder.subtreeSongIds);
      },
    );
    final moveToFolderItem = buildLocalMoveToFolderMenuItem(
      nodes: nodes,
      songsById: songsById,
      songIds: const [],
      folderPaths: [folder.path],
      i18n: i18n,
      key: 'move-folder-to-folder',
      onMoveToFolder: (targetFolder) {
        _moveLocalItemsToFolder(
          songIds: const [],
          folderPaths: [folder.path],
          targetFolderPath: targetFolder.path,
        );
      },
    );

    showMenuFlyout(
      context,
      position: position,
      items: [
        MenuFlyoutItem(
          key: 'shuffle-folder',
          text: i18n.t('nowPlaying.randomPlay'),
          icon: FluentIcons.arrow_shuffle_20_regular,
          onPressed: () => _playShuffled(folder),
        ),
        if (addToItem != null) addToItem,
        MenuFlyoutItem(
          key: 'select-folder',
          text: i18n.t('context.select'),
          icon: FluentIcons.multiselect_ltr_20_regular,
          onPressed: () => _selectFolder(folder),
        ),
        if (moveToFolderItem != null) moveToFolderItem,
        _buildFolderPreferenceMenuItem(i18n, folder, preferenceLevel),
        MenuFlyoutItem(
          key: 'show-in-explorer',
          text: i18n.t('context.reveal'),
          pendingText: i18n.t('context.openingLocal'),
          icon: FluentIcons.folder_open_20_regular,
          onPressed: () => _revealFolder(folder),
        ),
        MenuFlyoutItem(
          key: 'new-folder',
          text: i18n.t('local.newFolder'),
          icon: FluentIcons.add_20_regular,
          onPressed:
              () => _createFolder(
                parent: folder,
                nodes: nodes,
                rootPath: snapshot.rootPath,
                i18n: i18n,
              ),
        ),
        MenuFlyoutItem(
          key: 'delete-folder',
          text: i18n.t('local.deleteFolder'),
          icon: FluentIcons.delete_20_regular,
          onPressed: () => _requestDeleteFolder(folder, i18n),
        ),
        MenuFlyoutItem(
          key: 'refresh-folder',
          text: i18n.t('local.updateFolder'),
          icon: FluentIcons.arrow_sync_20_regular,
          onPressed: () => _refreshFolder(folder, i18n),
        ),
        MenuFlyoutItem(
          key: 'rename-folder',
          text: i18n.t('local.renameFolder'),
          icon: FluentIcons.rename_20_regular,
          onPressed:
              () => _renameFolder(
                folder: folder,
                nodes: nodes,
                rootPath: snapshot.rootPath,
                i18n: i18n,
              ),
        ),
        _buildFolderSortMenuItem(i18n, folder),
        MenuFlyoutItem(
          key: 'search-directory',
          text: i18n.t('local.searchDirectory'),
          icon: FluentIcons.search_20_regular,
          onPressed: () => _searchDirectory(folder, i18n),
        ),
        MenuFlyoutItem(
          key: 'hide-folder',
          text: i18n.t('local.hideFolder'),
          icon: FluentIcons.eye_off_20_regular,
          onPressed: () => _hideFolder(folder),
        ),
      ],
    );
  }

  Future<void> _showFolderChainMenu({
    required Offset position,
    required FolderNode folder,
    required Map<String, FolderNode> nodes,
    required Map<int, LibrarySong> songsById,
    required List<MultiSelectCommandBarPlaylist> playlists,
    required LibraryContentData snapshot,
    required SmPlayerI18n i18n,
  }) async {
    final preferenceLevel = await ref
        .read(libraryRepositoryProvider)
        .getPreferenceLevel('folder', '${folder.id}');
    if (!mounted) {
      return;
    }
    final addToItem = buildAddToPlaylistMenuFlyoutItem(
      i18n: i18n,
      songIds: folder.subtreeSongIds,
      playlists: playlists,
      includeNowPlaying: true,
      includeFavorites: _hasNotFavoriteSongs(folder.subtreeSongIds, songsById),
      onAddToNowPlaying: () {
        _addSongsToNowPlaying(folder.subtreeSongIds);
      },
      onToggleFavorite: () {
        _toggleSongsFavorite(
          _notFavoriteSongIds(folder.subtreeSongIds, songsById),
          true,
        );
      },
      onCreatePlaylist: () {
        _createPlaylist(folder.name, folder.subtreeSongIds, snapshot, i18n);
      },
      onAddToPlaylist: (playlistId) {
        _addSongsToPlaylist(playlistId, folder.subtreeSongIds);
      },
    );
    final moveToFolderItem = buildLocalMoveToFolderMenuItem(
      nodes: nodes,
      songsById: songsById,
      songIds: const [],
      folderPaths: [folder.path],
      i18n: i18n,
      key: 'chain-move-to-folder',
      onMoveToFolder: (targetFolder) {
        _moveLocalItemsToFolder(
          songIds: const [],
          folderPaths: [folder.path],
          targetFolderPath: targetFolder.path,
        );
      },
    );

    showMenuFlyout(
      context,
      position: position,
      items: [
        MenuFlyoutItem(
          key: 'chain-shuffle-folder',
          text: i18n.t('nowPlaying.randomPlay'),
          icon: FluentIcons.arrow_shuffle_20_regular,
          onPressed: () => _playShuffled(folder),
        ),
        if (addToItem != null) addToItem,
        if (moveToFolderItem != null) moveToFolderItem,
        _buildFolderPreferenceMenuItem(
          i18n,
          folder,
          preferenceLevel,
          key: 'chain-folder-preference',
        ),
        MenuFlyoutItem(
          key: 'chain-show-in-explorer',
          text: i18n.t('context.reveal'),
          pendingText: i18n.t('context.openingLocal'),
          icon: FluentIcons.folder_open_20_regular,
          onPressed: () => _revealFolder(folder),
        ),
        MenuFlyoutItem(
          key: 'chain-search-directory',
          text: i18n.t('local.searchDirectory'),
          icon: FluentIcons.search_20_regular,
          onPressed: () => _searchDirectory(folder, i18n),
        ),
      ],
    );
  }

  Future<void> _showSongMenu({
    required Offset position,
    required LibrarySong song,
    required List<int> queueSongIds,
    required List<MultiSelectCommandBarPlaylist> playlists,
    required LibraryContentData snapshot,
    required SmPlayerI18n i18n,
  }) async {
    final mediaState = ref.read(mediaControlControllerProvider).state;
    final preferenceLevel = await ref
        .read(libraryRepositoryProvider)
        .getPreferenceLevel('song', '${song.id}');
    if (!mounted) {
      return;
    }

    showMenuFlyout(
      context,
      position: position,
      items: buildMusicMenuFlyoutItems(
        i18n: i18n,
        songId: song.id,
        isFavorite: song.favorite,
        isCurrentTrack: mediaState.track.id == song.id,
        isPlaying: mediaState.isPlaying,
        playlists: playlists,
        folders: buildLocalMenuFolders(snapshot.folders),
        songPath: song.path,
        currentTrackId: mediaState.track.id,
        showMoveToFolder: snapshot.folders.isNotEmpty,
        showHideFile: true,
        onPlay: () => _playTrack(song.id, queueSongIds),
        onPause: ref.read(mediaControlControllerProvider).onTogglePlayPause,
        onPlayNext: () => _playNext(song.id),
        onAddToNowPlaying: () => _addSongsToNowPlaying([song.id]),
        onCreatePlaylist: () {
          _createPlaylist(
            getNextPlaylistName(song.title, snapshot.playlists),
            [song.id],
            snapshot,
            i18n,
          );
        },
        onAddToPlaylist: (playlistId) {
          _addSongsToPlaylist(playlistId, [song.id]);
        },
        onRemove: () => _showMessage(i18n.t('context.removeFromList')),
        onSelect: () => _selectSong(song.id),
        onToggleFavorite: () {
          _toggleSongsFavorite([song.id], !song.favorite);
        },
        onSetPreference: (level) async {
          await ref
              .read(libraryRepositoryProvider)
              .addPreferenceItem('song', '${song.id}', song.title, level);
          ref.invalidate(libraryContentDataProvider);
        },
        preferenceLevel: preferenceLevel,
        onUndoPreference:
            preferenceLevel == null
                ? null
                : () async {
                  await ref
                      .read(libraryRepositoryProvider)
                      .removePreferenceItem('song', '${song.id}');
                  ref.invalidate(libraryContentDataProvider);
                },
        onMoveToFolder: (folderPath) {
          moveSongToFolderWithUndo(
            context: context,
            ref: ref,
            i18n: i18n,
            song: song,
            folderPath: folderPath,
          );
        },
        onDelete: () {
          requestDeleteSongFromDisk(
            context: context,
            ref: ref,
            i18n: i18n,
            song: song,
          );
        },
        onHide: () {
          hideSongFileWithUndo(
            context: context,
            ref: ref,
            i18n: i18n,
            song: song,
          );
        },
        onSeeArtist: () {
          final artists = getSongArtists(song);
          final artist =
              artists.isEmpty ? i18n.t('common.artistUnknown') : artists.first;
          context.go('/artists?artist=${Uri.encodeQueryComponent(artist)}');
        },
        onSeeAlbum: () {
          context.go(
            '/albums?album=${Uri.encodeQueryComponent(displayAlbum(song, i18n))}',
          );
        },
        onSeeMusicInfo: () => _openMusicDialog(song, SongDialogMode.properties),
        onSeeLyrics: () => _openMusicDialog(song, SongDialogMode.lyrics),
        onSeeAlbumArt: () => _openMusicDialog(song, SongDialogMode.albumArt),
        onSeeLocal: () => _revealSong(song),
      ),
    );
  }

  void _openMusicDialog(LibrarySong song, SongDialogMode mode) {
    _updateLocalPageState(() {
      _musicDialog = (song: song, mode: mode);
    });
  }

  MenuFlyoutItem _buildFolderSortMenuItem(
    SmPlayerI18n i18n,
    FolderNode folder,
  ) {
    final folderSortMode = localSortModeFromCriterion(folder.criterion);
    return MenuFlyoutItem(
      key: 'folder-sort',
      text: i18n.t('common.sort'),
      icon: FluentIcons.arrow_sort_20_regular,
      submenu: [
        MenuFlyoutItem(
          key: 'folder-sort-reverse',
          text: i18n.t('local.sortReverseList'),
          onPressed:
              () => _updateFolderSortMode(folder, LocalSortMode.reverse, i18n),
        ),
        const MenuFlyoutItem.separator(key: 'folder-sort-separator'),
        for (final item in [
          (
            key: 'folder-sort-title',
            text: i18n.t('local.sortByTitle'),
            mode: LocalSortMode.title,
          ),
          (
            key: 'folder-sort-artist',
            text: i18n.t('local.sortByArtist'),
            mode: LocalSortMode.artist,
          ),
          (
            key: 'folder-sort-album',
            text: i18n.t('local.sortByAlbum'),
            mode: LocalSortMode.album,
          ),
        ])
          MenuFlyoutItem(
            key: item.key,
            text: item.text,
            icon:
                folderSortMode == item.mode
                    ? FluentIcons.checkmark_20_regular
                    : null,
            onPressed: () => _updateFolderSortMode(folder, item.mode, i18n),
          ),
      ],
    );
  }

  MenuFlyoutItem _buildFolderPreferenceMenuItem(
    SmPlayerI18n i18n,
    FolderNode folder,
    String? preferenceLevel, {
    String key = 'folder-folder-preference',
  }) {
    return buildPreferenceMenuFlyoutItem(
      i18n: i18n,
      key: key,
      preferenceLevel: preferenceLevel,
      onUndoPreference:
          preferenceLevel == null
              ? null
              : () async {
                await ref
                    .read(libraryRepositoryProvider)
                    .removePreferenceItem('folder', '${folder.id}');
                ref.invalidate(libraryContentDataProvider);
              },
      onSetPreference: (level) async {
        await ref
            .read(libraryRepositoryProvider)
            .addPreferenceItem('folder', '${folder.id}', folder.name, level);
        ref.invalidate(libraryContentDataProvider);
      },
    );
  }

  Future<void> _updateSortMode(
    FolderNode folder,
    LocalSortMode sortMode,
    SmPlayerI18n i18n,
  ) async {
    if (_multiSelect) {
      _showMessage(i18n.t('local.pleaseExitMultiSelectMode'));
      return;
    }

    _updateLocalPageState(() {
      _sortMode = sortMode;
    });
    if (sortMode != LocalSortMode.reverse) {
      await ref
          .read(libraryRepositoryProvider)
          .updateLocalFolderSort(folder.path, sortMode);
      ref.invalidate(libraryContentDataProvider);
    }
  }

  Future<void> _updateFolderSortMode(
    FolderNode folder,
    LocalSortMode sortMode,
    SmPlayerI18n i18n,
  ) async {
    if (_multiSelect) {
      _showMessage(i18n.t('local.pleaseExitMultiSelectMode'));
      return;
    }

    if (sortMode != LocalSortMode.reverse) {
      await ref
          .read(libraryRepositoryProvider)
          .updateLocalFolderSort(folder.path, sortMode);
      ref.invalidate(libraryContentDataProvider);
    }
    if (folder.relativePath == widget.currentRelativePath) {
      _updateLocalPageState(() {
        _sortMode = sortMode;
      });
    }
  }
}
