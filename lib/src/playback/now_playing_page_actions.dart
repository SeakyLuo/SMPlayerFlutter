part of 'now_playing_page.dart';

extension _NowPlayingPageActions on _NowPlayingPageState {
  void _playQueueTrack(
    LibrarySong song,
    List<int> queueSongIds,
    int queueIndex,
  ) {
    replaceNowPlayingQueueAndPlayIndex(
      ref: ref,
      snapshot: ref.read(libraryContentDataProvider).value!,
      i18n: context.smPlayerI18n,
      songIds: queueSongIds,
      queueIndex: queueIndex,
    );
  }

  void _playSongIds(List<int> songIds) {
    if (songIds.isEmpty) {
      return;
    }

    replaceNowPlayingQueueAndPlayIndex(
      ref: ref,
      snapshot: ref.read(libraryContentDataProvider).value!,
      i18n: context.smPlayerI18n,
      songIds: songIds,
      queueIndex: 0,
    );
  }

  Future<void> _quickPlay(LibraryContentData snapshot) async {
    final repository = ref.read(libraryRepositoryProvider);
    final preferences = await repository.getPreferenceSettings(
      unknownAlbumName: context.smPlayerI18n.t('common.albumUnknown'),
    );
    if (!mounted) {
      return;
    }
    _playSongIds(
      quickPlaySongIds(
        songs: snapshot.songs,
        playlists: _effectivePlaylists(snapshot.playlists),
        folders: snapshot.folders,
        preferences: preferences,
        randomLimit: _NowPlayingPageState.quickPlayLimit,
      ),
    );
  }

  void _replaceQueue(List<int> songIds) {
    final snapshot = ref.read(libraryContentDataProvider).value;
    final queueOverride = ref.read(nowPlayingQueueOverrideProvider);
    final currentSongIds = queueOverride ?? snapshot?.nowPlaying.songIds;
    if (currentSongIds != null) {
      syncMediaControlForQueueChange(
        mediaController: ref.read(mediaControlControllerProvider),
        currentSongIds: currentSongIds,
        nextSongIds: songIds,
      );
    }
    if (currentSongIds != null && _sameSongIds(currentSongIds, songIds)) {
      return;
    }
    setNowPlayingQueue(ref, songIds);
  }

  void _removeQueueIndex(
    List<int> queueSongIds,
    int queueIndex,
    LibrarySong song,
  ) {
    final before = queueSongIds.toList();
    final nextQueueSongIds = [
      for (var index = 0; index < queueSongIds.length; index += 1)
        if (index != queueIndex) queueSongIds[index],
    ];
    final nextPlayingQueueIndex = _nextQueueIndexAfterRemovingCurrentPlaying(
      queueSongIds,
      {queueIndex},
      nextQueueSongIds,
    );
    _replaceQueue(nextQueueSongIds);
    if (nextPlayingQueueIndex != null) {
      _playQueueSongAt(nextQueueSongIds, nextPlayingQueueIndex);
    }
    _showUndo(
      context.smPlayerI18n.t('notification.removedFrom', {
        'title': song.title,
        'target': context.smPlayerI18n.t('common.nowPlaying'),
      }),
      () => _replaceQueue(before),
    );
  }

  int? _nextQueueIndexAfterRemovingCurrentPlaying(
    List<int> queueSongIds,
    Set<int> removedIndexes,
    List<int> nextQueueSongIds,
  ) {
    final currentQueueIndex = _currentPlayingQueueIndex(queueSongIds);
    if (currentQueueIndex == null ||
        !removedIndexes.contains(currentQueueIndex) ||
        nextQueueSongIds.isEmpty) {
      return null;
    }
    var nextQueueIndex = 0;
    for (var index = 0; index < currentQueueIndex; index += 1) {
      if (!removedIndexes.contains(index)) {
        nextQueueIndex += 1;
      }
    }
    return nextQueueIndex < nextQueueSongIds.length ? nextQueueIndex : 0;
  }

  int? _currentPlayingQueueIndex(List<int> queueSongIds) {
    final mediaState = ref.read(mediaControlControllerProvider).state;
    if (!mediaState.isPlaying) {
      return null;
    }
    final trackId = mediaState.track.id;
    if (trackId == null) {
      return null;
    }
    final queueIndex = mediaState.selectedQueueIndex;
    if (queueIndex != null &&
        queueIndex >= 0 &&
        queueIndex < queueSongIds.length &&
        queueSongIds[queueIndex] == trackId) {
      return queueIndex;
    }
    final trackIndex = queueSongIds.indexOf(trackId);
    return trackIndex == -1 ? null : trackIndex;
  }

  void _playQueueSongAt(List<int> queueSongIds, int queueIndex) {
    playQueueIndex(
      ref: ref,
      snapshot: ref.read(libraryContentDataProvider).value!,
      i18n: context.smPlayerI18n,
      songIds: queueSongIds,
      queueIndex: queueIndex,
    );
  }

  void _moveQueueSongItem(List<int> queueSongIds, int oldIndex, int newIndex) {
    final nextSongIds = queueSongIds.toList();
    final songId = nextSongIds.removeAt(oldIndex);
    nextSongIds.insert(newIndex, songId);
    _replaceQueue(nextSongIds);
  }

  void _moveVisibleQueueSongItem(
    List<int> queueSongIds,
    List<int> visibleQueueIndexes,
    int oldVisibleIndex,
    int newVisibleIndex,
  ) {
    final oldQueueIndex = visibleQueueIndexes[oldVisibleIndex];
    final targetQueueIndex =
        newVisibleIndex >= visibleQueueIndexes.length
            ? queueSongIds.length
            : visibleQueueIndexes[newVisibleIndex];
    _moveQueueSongItem(queueSongIds, oldQueueIndex, targetQueueIndex);
  }

  void _toggleMultiSelect() {
    _updateNowPlayingPageState(() {
      _selection.toggleMultiSelect();
    });
  }

  void _toggleQueueSelection(int queueIndex) {
    _updateNowPlayingPageState(() {
      _selection.toggle(queueIndex);
    });
  }

  void _clearSelection() {
    _updateNowPlayingPageState(() {
      _selection.clearSelection();
    });
  }

  void _removeSelectedQueueIndexes(
    List<int> queueSongIds,
    List<int> selectedIndexes,
    List<int> selectedSongIds,
    Map<int, LibrarySong> songsById,
  ) {
    final before = queueSongIds.toList();
    final selectedIndexSet = selectedIndexes.toSet();
    final nextQueueSongIds = [
      for (var index = 0; index < queueSongIds.length; index += 1)
        if (!selectedIndexSet.contains(index)) queueSongIds[index],
    ];
    final nextPlayingQueueIndex = _nextQueueIndexAfterRemovingCurrentPlaying(
      queueSongIds,
      selectedIndexSet,
      nextQueueSongIds,
    );
    _replaceQueue(nextQueueSongIds);
    if (nextPlayingQueueIndex != null) {
      _playQueueSongAt(nextQueueSongIds, nextPlayingQueueIndex);
    }
    final i18n = context.smPlayerI18n;
    _showUndo(
      selectedSongIds.length == 1
          ? i18n.t('notification.removedFrom', {
            'title': songsById[selectedSongIds.first]!.title,
            'target': i18n.t('common.nowPlaying'),
          })
          : i18n.t('notification.songsRemovedFrom', {
            'count': selectedSongIds.length,
            'target': i18n.t('common.nowPlaying'),
          }),
      () => _replaceQueue(before),
    );
  }

  Future<void> _showQueueContextMenu(
    Offset position,
    LibrarySong song,
    List<int> queueSongIds,
    int queueIndex,
    List<MultiSelectCommandBarPlaylist> playlists,
    List<MenuFlyoutFolder> folders,
    List<LibraryPlaylist> allPlaylists,
    Map<int, LibrarySong> songsById,
  ) async {
    final i18n = context.smPlayerI18n;
    final mediaState = ref.read(mediaControlControllerProvider).state;
    final currentTrackId = mediaState.track.id;
    final preferenceLevel = await ref
        .read(libraryRepositoryProvider)
        .getPreferenceLevel('song', '${song.id}');
    if (!mounted) {
      return;
    }
    await showMenuFlyout(
      context,
      position: position,
      items: buildMusicMenuFlyoutItems(
        i18n: i18n,
        songId: song.id,
        songTitle: song.title,
        isFavorite: song.favorite,
        isCurrentTrack: song.id == currentTrackId,
        isPlaying: mediaState.isPlaying,
        currentTrackId: currentTrackId,
        nowPlayingSongIds: queueSongIds,
        currentPlaylistName: i18n.t('common.nowPlaying'),
        songPath: song.path,
        playlists: playlists,
        folders: folders,
        showRemove: true,
        showDelete: true,
        preferenceLevel: preferenceLevel,
        onUndoPreference:
            preferenceLevel == null
                ? null
                : () {
                  unawaited(
                    ref
                        .read(libraryRepositoryProvider)
                        .removePreferenceItem('song', '${song.id}'),
                  );
                },
        onPlay: () {
          _playQueueTrack(song, queueSongIds, queueIndex);
        },
        onTogglePlayPause:
            ref.read(mediaControlControllerProvider).onTogglePlayPause,
        onPlayNext: null,
        onAddToNowPlaying: () {
          final before = queueSongIds.toList();
          _replaceQueue([...queueSongIds, song.id]);
          _showUndo(
            i18n.t('notification.songAddedTo', {
              'title': song.title,
              'target': i18n.t('common.nowPlaying'),
            }),
            () => _replaceQueue(before),
          );
        },
        onCreatePlaylist: () {
          unawaited(
            createPlaylistWithSongs(
              context: context,
              ref: ref,
              i18n: i18n,
              playlists: allPlaylists,
              defaultName: getNextPlaylistName(song.title, allPlaylists),
              songIds: [song.id],
            ),
          );
        },
        onAddToPlaylist: (playlistId) {
          unawaited(
            _addSongsToPlaylistWithUndo(
              playlistId,
              [song.id],
              allPlaylists,
              songsById,
            ),
          );
        },
        onRemove: () {
          _removeQueueIndex(queueSongIds, queueIndex, song);
        },
        onSelect: () {
          _updateNowPlayingPageState(() {
            _selection.enterMultiSelect();
            if (!_selection.isSelected(queueIndex)) {
              _selection.toggle(queueIndex);
            }
          });
        },
        onToggleFavorite: () {
          _addSongsToFavorites([song.id], songsById);
        },
        onSetPreference: (level) async {
          await ref
              .read(libraryRepositoryProvider)
              .addPreferenceItem('song', '${song.id}', song.title, level);
        },
        onDelete: () {
          requestDeleteSongFromDisk(
            context: context,
            ref: ref,
            i18n: i18n,
            song: song,
          );
        },
        onMoveToFolder: (folderPath) {
          unawaited(
            moveSongToFolderWithUndo(
              context: context,
              ref: ref,
              i18n: i18n,
              song: song,
              folderPath: folderPath,
            ),
          );
        },
        onSeeArtist: () {
          final artist = primaryDisplayArtist(song, i18n);
          context.go('/artists?artist=${Uri.encodeQueryComponent(artist)}');
        },
        onSeeAlbum: () {
          final album = displayAlbum(song, i18n);
          context.go('/albums?album=${Uri.encodeQueryComponent(album)}');
        },
        onSeeMusicInfo: () {
          _updateNowPlayingPageState(() {
            _songDialog = (
              song: song,
              mode: SongDialogMode.properties,
              queueSongIds: queueSongIds,
            );
          });
        },
        onSeeLyrics: () {
          _updateNowPlayingPageState(() {
            _songDialog = (
              song: song,
              mode: SongDialogMode.lyrics,
              queueSongIds: queueSongIds,
            );
          });
        },
        onSeeAlbumArt: () {
          _updateNowPlayingPageState(() {
            _songDialog = (
              song: song,
              mode: SongDialogMode.albumArt,
              queueSongIds: queueSongIds,
            );
          });
        },
        onLocateLocal: () => locateSongInLocal(context, song.id),
        onSeeLocal: () {
          _revealPath(song.path);
        },
      ),
    );
  }

  LibrarySong? _resolveCurrentSong(
    int? trackId,
    int? selectedQueueIndex,
    List<LibrarySong> queueSongs,
  ) {
    final queueIndex = selectedQueueIndex;
    if (queueIndex != null &&
        queueIndex >= 0 &&
        queueIndex < queueSongs.length) {
      return queueSongs[queueIndex];
    }

    if (trackId == null) {
      return null;
    }
    return queueSongs.where((song) => song.id == trackId).firstOrNull;
  }

  void _showShuffleMenu({
    required BuildContext buttonContext,
    required LibraryContentData snapshot,
    required List<LibrarySong> queueSongs,
    required List<LibrarySong> recentSongs,
  }) {
    showMenuFlyout(
      buttonContext,
      items: _buildShuffleMenuItems(
        snapshot: snapshot,
        queueSongs: queueSongs,
        recentSongs: recentSongs,
      ),
    );
  }

  List<MenuFlyoutItem> _buildShuffleMenuItems({
    required LibraryContentData snapshot,
    required List<LibrarySong> queueSongs,
    required List<LibrarySong> recentSongs,
  }) {
    return buildShuffleMenuFlyoutItems(
      i18n: context.smPlayerI18n,
      songs: queueSongs,
      librarySongs: snapshot.songs,
      recentSongs: recentSongs,
      playlists: _effectivePlaylists(snapshot.playlists),
      folders: snapshot.folders,
      randomLimit: _NowPlayingPageState.quickPlayLimit,
      onPlaySongs: _playSongIds,
    );
  }

  void _addSongsToFavorites(
    List<int> songIds,
    Map<int, LibrarySong> songsById,
  ) {
    if (songIds.isEmpty) {
      return;
    }
    unawaited(setSongsFavoriteFromControl(ref, songIds, true));
    final i18n = context.smPlayerI18n;
    _showUndo(
      songIds.length == 1
          ? i18n.t('notification.songAddedTo', {
            'title': songsById[songIds.first]!.title,
            'target': i18n.t('common.myFavorites'),
          })
          : i18n.t('notification.songsAddedTo', {
            'count': songIds.length,
            'target': i18n.t('common.myFavorites'),
          }),
      () => setSongsFavorite(ref, songIds, false),
    );
  }

  Future<void> _addSongsToPlaylistWithUndo(
    int playlistId,
    List<int> songIds,
    List<LibraryPlaylist> playlists,
    Map<int, LibrarySong> songsById,
  ) async {
    await addSongsToPlaylistWithUndo(
      context: context,
      ref: ref,
      i18n: context.smPlayerI18n,
      playlistId: playlistId,
      songIds: songIds,
    );
  }

  void _clearQueue(List<int> queueSongIds) {
    final before = queueSongIds.toList();
    _replaceQueue(const []);
    _showUndo(
      context.smPlayerI18n.t('notification.nowPlayingCleared'),
      () => _replaceQueue(before),
    );
  }

  Future<void> _showQueueAddToPlaylistMenu(
    BuildContext buttonContext,
    LibrarySong song,
    List<MultiSelectCommandBarPlaylist> playlists,
    List<LibraryPlaylist> allPlaylists,
    Map<int, LibrarySong> songsById,
  ) async {
    final box = buttonContext.findRenderObject() as RenderBox;
    final position = box.localToGlobal(Offset(0, box.size.height + 8));
    final i18n = context.smPlayerI18n;
    final addToItem = buildAddToPlaylistMenuFlyoutItem(
      i18n: i18n,
      songIds: [song.id],
      playlists: playlists,
      currentPlaylistName: i18n.t('common.nowPlaying'),
      includeFavorites: !song.favorite,
      onToggleFavorite:
          song.favorite
              ? null
              : () {
                _addSongsToFavorites([song.id], songsById);
              },
      onCreatePlaylist: () {
        unawaited(
          createPlaylistWithSongs(
            context: context,
            ref: ref,
            i18n: i18n,
            playlists: allPlaylists,
            defaultName: getNextPlaylistName(song.title, allPlaylists),
            songIds: [song.id],
          ),
        );
      },
      onAddToPlaylist: (playlistId) {
        unawaited(
          _addSongsToPlaylistWithUndo(
            playlistId,
            [song.id],
            allPlaylists,
            songsById,
          ),
        );
      },
    );
    await showMenuFlyout(
      context,
      position: position,
      items: addToItem!.submenu,
    );
  }

  Future<void> _revealPath(String targetPath) async {
    await revealItemInFolder(targetPath);
  }

  void _showUndo(String message, FutureOr<void> Function() action) {
    showUndoableNotification(
      context: context,
      i18n: context.smPlayerI18n,
      message: message,
      onUndo: () async {
        if (!mounted) {
          return;
        }
        await action();
      },
    );
  }

  List<LibraryPlaylist> _effectivePlaylists(List<LibraryPlaylist> playlists) {
    return applyLibraryPlaylistOverridesToPlaylists(
      playlists,
      ref.read(libraryPlaylistOverridesProvider),
      ref.read(libraryDeletedPlaylistIdsProvider),
      ref.read(libraryPlaylistOrderProvider),
    );
  }

  void _locateCurrent(
    List<LibrarySong> queueSongs,
    int? trackId,
    int? selectedQueueIndex,
  ) {
    final index =
        selectedQueueIndex ??
        queueSongs.indexWhere((song) => song.id == trackId);
    if (index < 0) {
      return;
    }

    _listController.animateTo(
      (index * 82.0).clamp(0, _listController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
    );
  }
}
