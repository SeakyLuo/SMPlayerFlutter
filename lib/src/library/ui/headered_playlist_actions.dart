part of 'headered_playlist_control.dart';

extension _HeaderedPlaylistControlActions on _HeaderedPlaylistControlState {
  void _playSong(LibrarySong song, List<int> queueSongIds) {
    if (widget.onMoveToMusicOrPlay != null) {
      widget.onMoveToMusicOrPlay!(song.id);
      return;
    }

    widget.onPlayTrack(song.id, queueSongIds);
  }

  void _shuffle(List<int> queueSongIds) {
    final shuffledSongIds = shuffleSongIds(queueSongIds);
    widget.onRecordPlay?.call();
    widget.onPlayTrack(shuffledSongIds.first, shuffledSongIds);
  }

  void _addSongsToNowPlaying(List<int> songIds) {
    unawaited(
      addSongsToNowPlayingWithUndo(
        context: context,
        ref: ref,
        i18n: context.smPlayerI18n,
        songIds: songIds,
      ),
    );
  }

  void _playNextSong(int songId) {
    if (widget.onPlayNext != null) {
      widget.onPlayNext!(songId);
      return;
    }
    final snapshot = ref.read(libraryContentDataProvider).value!;
    final nextQueue = snapshot.nowPlaying.songIds.toList();
    final currentIndex =
        widget.selectedTrackId == null
            ? -1
            : nextQueue.indexOf(widget.selectedTrackId!);
    nextQueue.insert(currentIndex < 0 ? 0 : currentIndex + 1, songId);
    widget.onPlayTrack(widget.selectedTrackId ?? songId, nextQueue);
  }

  void _toggleSongFavoriteWithUndo(LibrarySong song) {
    if (widget.type == HeaderedPlaylistType.favorites && song.favorite) {
      unawaited(_removeSongsFromCurrentPlaylist([song.id]));
      return;
    }
    unawaited(
      setSongsFavoriteWithUndo(
        context: context,
        ref: ref,
        i18n: context.smPlayerI18n,
        songIds: [song.id],
        favorite: !song.favorite,
      ),
    );
  }

  void _commitSort(
    PlaylistSortCriterion criterion,
    PlaylistSortCriterion activeSortCriterion,
  ) {
    final sortedSongs =
        criterion == activeSortCriterion
            ? _currentVisibleSongs().reversed.toList()
            : sortSongs(widget.songs, criterion);
    final sortedSongIds = sortedSongs.map((song) => song.id).toList();
    _updateState(() {
      _orderedSongIds = sortedSongIds;
      _selectedSortCriterion = criterion;
    });
    widget.onSortSongs?.call(sortedSongIds, criterion);
  }

  void _reverseSort() {
    final activeSortCriterion =
        _selectedSortCriterion ??
        widget.sortCriterion ??
        inferSortCriterion(widget.songs);
    final reversedSongs = _currentVisibleSongs().reversed.toList();
    final reversedSongIds = reversedSongs.map((song) => song.id).toList();
    _updateState(() {
      _orderedSongIds = reversedSongIds;
      _selectedSortCriterion = activeSortCriterion;
    });
    widget.onSortSongs?.call(reversedSongIds, activeSortCriterion);
  }

  List<LibrarySong> _currentVisibleSongs() {
    return _visibleSongs({for (final song in widget.songs) song.id: song});
  }

  List<int> _effectiveSelectedSongIds(List<int> queueSongIds) {
    final queueSongIdSet = queueSongIds.toSet();
    return _selection.selectedItems
        .where((songId) => queueSongIdSet.contains(songId))
        .toList();
  }

  Future<void> _removeSongsFromCurrentPlaylist(List<int> songIds) async {
    if (widget.type == HeaderedPlaylistType.favorites) {
      _updateState(() {
        _pendingFavoriteSongIds.addAll(songIds);
      });
    }
    try {
      await widget.onRemoveSongs?.call(songIds);
      _showUndoRemoveSongs(songIds);
    } finally {
      if (widget.type == HeaderedPlaylistType.favorites) {
        _updateState(() {
          _pendingFavoriteSongIds.removeAll(songIds);
        });
      }
    }
  }

  void _showUndoRemoveSongs(List<int> songIds) {
    if (songIds.isEmpty) {
      return;
    }
    final i18n = context.smPlayerI18n;
    final songsById = {for (final song in widget.songs) song.id: song};
    if (widget.type == HeaderedPlaylistType.favorites) {
      _showUndoNotification(
        () async {
          await setSongsFavorite(ref, songIds, true);
        },
        songsRemovedUndoMessage(
          i18n: i18n,
          songIds: songIds,
          songsById: songsById,
          target: i18n.t('common.myFavorites'),
        ),
      );
      return;
    }
    if (widget.type == HeaderedPlaylistType.playlist) {
      final playlist = widget.playlists.firstWhere(
        (playlist) => playlist.name == widget.title,
      );
      _showUndoNotification(
        () async {
          final onAddSongsToPlaylist = widget.onAddSongsToPlaylist;
          if (onAddSongsToPlaylist != null) {
            await onAddSongsToPlaylist(playlist.id, songIds);
            return;
          }
          await ref
              .read(libraryRepositoryProvider)
              .addSongsToPlaylist(playlist.id, songIds);
        },
        songsRemovedUndoMessage(
          i18n: i18n,
          songIds: songIds,
          songsById: songsById,
          target: playlist.name,
        ),
      );
    }
  }

  void _showUndoNotification(FutureOr<void> Function() onUndo, String message) {
    final i18n = context.smPlayerI18n;
    showUndoableNotification(
      context: context,
      i18n: i18n,
      message: message,
      onUndo: onUndo,
    );
  }

  void _hideSelectionAfterOperation([
    bool? hideMultiSelectCommandBarAfterOperation,
  ]) {
    final snapshot = ref.read(libraryContentDataProvider).valueOrNull;
    _updateState(() {
      _selection.hideAfterOperation(
        hideMultiSelectCommandBarAfterOperation ??
            snapshot?.hideMultiSelectCommandBarAfterOperation ??
            true,
      );
    });
  }

  Future<void> _createPlaylistFromSongs(
    SmPlayerI18n i18n,
    List<int> songIds, {
    String? defaultSourceName,
  }) async {
    final defaultName = getNextPlaylistName(
      isBadNewPlaylistName(defaultSourceName ?? widget.title, i18n)
          ? ''
          : defaultSourceName ?? widget.title,
      widget.playlists,
    );
    final name = await _requestPlaylistName(
      i18n: i18n,
      title: i18n.t('playlists.createNew'),
      defaultName: defaultName,
      confirmText: i18n.t('playlists.create'),
      currentName: '',
    );
    if (name == null) {
      return;
    }

    final playlist = await ref
        .read(libraryRepositoryProvider)
        .createPlaylist(name, songIds);
    _patchLocalPlaylist(playlist);
  }

  void _openMusicDialog(
    LibrarySong song,
    SongDialogMode mode,
    List<int> queueSongIds,
  ) {
    _updateState(() {
      _musicDialog = (song: song, mode: mode, queueSongIds: queueSongIds);
    });
  }

  Future<void> _revealPath(String targetPath) async {
    await revealItemInFolder(targetPath);
  }

  String _displayArtist(LibrarySong song, SmPlayerI18n i18n) {
    final artists = song_display.songArtists(song);
    return artists.isEmpty ? i18n.t('common.artistUnknown') : artists.first;
  }

  Future<void> _requestRename(SmPlayerI18n i18n) async {
    final name = await _requestPlaylistName(
      i18n: i18n,
      title: i18n.t('playlists.rename'),
      defaultName: widget.title,
      confirmText: i18n.t('playlists.rename'),
      currentName: widget.title,
    );
    if (name != null && name != widget.title) {
      widget.onRename?.call(name);
    }
  }

  Future<String?> _requestPlaylistName({
    required SmPlayerI18n i18n,
    required String title,
    required String defaultName,
    required String confirmText,
    required String currentName,
  }) {
    return showPopupTextDialog(
      context: context,
      title: title,
      initialValue: defaultName,
      confirmLabel: confirmText,
      placeholder: i18n.t('playlists.namePlaceholder'),
      validate:
          (name) =>
              validatePlaylistName(name, widget.playlists, currentName, i18n),
    );
  }

  Future<void> _requestDelete(SmPlayerI18n i18n) async {
    final confirmed = await _requestConfirm(
      title: captionForHeaderedPlaylist(i18n, 'delete'),
      message: i18n.t('headeredPlaylist.deleteConfirm', {'name': widget.title}),
      confirmText: captionForHeaderedPlaylist(i18n, 'delete'),
    );
    if (confirmed) {
      widget.onDelete?.call();
    }
  }

  Future<void> _requestClear(SmPlayerI18n i18n) async {
    final confirmed = await _requestConfirm(
      title: captionForHeaderedPlaylist(i18n, 'clear'),
      message: i18n.t('headeredPlaylist.clearConfirm', {'name': widget.title}),
      confirmText: captionForHeaderedPlaylist(i18n, 'clear'),
    );
    if (confirmed) {
      widget.onClear?.call();
    }
  }

  Future<bool> _requestConfirm({
    required String title,
    required String message,
    required String confirmText,
  }) async {
    return showPopupConfirmDialog(
      context: context,
      title: title,
      message: message,
      confirmLabel: confirmText,
    );
  }
}
