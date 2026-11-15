part of 'immersive_mode_page.dart';

extension _ImmersiveModePageActions on _ImmersiveModePageState {
  Future<void> _showMoreMenu(
    BuildContext buttonContext,
    LibrarySong? currentSong,
    LibraryContentData snapshot,
    List<int> queueSongIds, {
    required List<LibrarySong> recentSongs,
    required SmPlayerShellActions? shellActions,
    required bool isCompact,
  }) async {
    final mediaController = ref.read(mediaControlControllerProvider);
    final settings = smPlayerGlobalSettingsSnapshot;
    final songsById = {for (final song in snapshot.songs) song.id: song};
    final queueSongs = [
      for (final songId in queueSongIds)
        if (songsById[songId] case final song?) song,
    ];
    await showMediaControlMoreMenu(
      context: buttonContext,
      i18n: context.smPlayerI18n,
      isMuted: mediaController.state.isMuted,
      volumeValue: mediaController.state.volume,
      desktopLyricsEnabled: settings.desktopLyricsEnabled,
      onToggleDesktopLyrics: shellActions?.onToggleDesktopLyrics,
      alwaysShowQuickPlay: true,
      randomPlayDisabled: queueSongIds.isEmpty && snapshot.songs.isEmpty,
      randomPlaySubmenu: buildShuffleMenuFlyoutItems(
        i18n: context.smPlayerI18n,
        songs: queueSongs,
        librarySongs: snapshot.songs,
        recentSongs: recentSongs,
        playlists: _effectivePlaylists(snapshot.playlists),
        folders: snapshot.folders,
        randomLimit: nowPlayingQuickPlayLimit,
        onPlaySongs: _playSongIds,
      ),
      onVolumeChange: mediaController.onVolumeChange,
      onToggleMute: mediaController.onToggleMute,
      isCompact: isCompact,
      onQuickPlay: () {
        unawaited(_quickPlay(snapshot));
      },
      onToggleFavorite:
          currentSong == null
              ? mediaController.onToggleFavorite
              : () {
                unawaited(
                  _toggleSongsFavorite([currentSong.id], !currentSong.favorite),
                );
              },
      onToggleWindowFullScreen: shellActions?.onToggleWindowFullScreen,
      isWindowFullScreen: shellActions?.isWindowFullScreen ?? false,
      onEnterMiniMode: shellActions?.onEnterMiniMode,
      showFavoriteWhenUnavailable: true,
      currentSong: currentSong,
      nowPlayingSongIds: queueSongIds,
      playlists: _effectivePlaylists(snapshot.playlists),
      onResolvePreferenceLevel:
          currentSong == null
              ? null
              : () => _getSongPreferenceLevel(currentSong.id),
      onAddToNowPlaying:
          currentSong == null
              ? null
              : () => _addSongToNowPlaying(currentSong, queueSongIds),
      onCreatePlaylist:
          currentSong == null
              ? null
              : (name) {
                unawaited(_createPlaylist(name, [currentSong.id]));
              },
      onAddToPlaylist:
          currentSong == null
              ? null
              : (playlistId) {
                unawaited(_addSongsToPlaylist(playlistId, [currentSong.id]));
              },
      onUndoPreference:
          currentSong == null
              ? null
              : () {
                unawaited(_undoSongPreference(currentSong.id));
              },
      onSetPreference:
          currentSong == null
              ? null
              : (level) {
                unawaited(
                  _setSongPreference(currentSong.id, currentSong.title, level),
                );
              },
      onPlayArtist:
          currentSong == null
              ? null
              : () => _playArtist(currentSong, snapshot.songs),
      onPlayAlbum:
          currentSong == null
              ? null
              : () => _playAlbum(currentSong, snapshot.songs),
      onSeeArtist:
          currentSong == null ||
                  shellActions?.onExitImmersiveMode == null ||
                  shellActions?.onNavigate == null
              ? null
              : () {
                final artist = primaryImmersiveModeArtist(
                  currentSong,
                  context.smPlayerI18n,
                );
                shellActions!.onExitImmersiveMode!();
                shellActions.onNavigate!(
                  '/artists?artist=${Uri.encodeQueryComponent(artist)}',
                );
              },
      onSeeAlbum:
          currentSong == null ||
                  shellActions?.onExitImmersiveMode == null ||
                  shellActions?.onNavigate == null
              ? null
              : () {
                final album = displayImmersiveModeAlbum(
                  currentSong,
                  context.smPlayerI18n,
                );
                shellActions!.onExitImmersiveMode!();
                shellActions.onNavigate!(
                  '/albums?album=${Uri.encodeQueryComponent(album)}',
                );
              },
      onSeeMusicInfo:
          currentSong == null
              ? null
              : () => _openMusicDialog(SongDialogMode.properties),
      onSeeLyrics:
          currentSong == null
              ? null
              : () => _openMusicDialog(SongDialogMode.lyrics),
      onSeeAlbumArt:
          currentSong == null
              ? null
              : () => _openMusicDialog(SongDialogMode.albumArt),
      onLocateLocal:
          currentSong == null ||
                  shellActions?.onExitImmersiveMode == null ||
                  shellActions?.onNavigate == null
              ? null
              : () => locateSongInLocal(
                context,
                currentSong.id,
                onNavigate: (location) {
                  shellActions!.onExitImmersiveMode!();
                  shellActions.onNavigate!(location);
                },
              ),
      onSeeLocal:
          currentSong == null ? null : () => _revealPath(currentSong.path),
    );
  }

  void _toggleShufflePlayback() {
    final mediaController = ref.read(mediaControlControllerProvider);
    final enablingShuffle = mediaController.state.mode != PlaybackMode.shuffle;
    int? selectedQueueIndex;
    if (enablingShuffle) {
      final snapshot = ref.read(libraryContentDataProvider).valueOrNull;
      final songIds = snapshot?.nowPlaying.songIds ?? const <int>[];
      if (songIds.isNotEmpty) {
        final nextSongIds = shufflePlaybackQueueForCurrentTrack(
          songIds,
          mediaController.state.track.id,
        );
        _replaceQueue(nextSongIds);
        final nextQueueIndex = currentPlaybackQueueIndex(
          nextSongIds,
          mediaController.state.track.id,
        );
        selectedQueueIndex = nextQueueIndex > -1 ? nextQueueIndex : null;
      }
    }
    mediaController.onToggleShuffle(selectedQueueIndex: selectedQueueIndex);
  }

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
    _playQueueSongIds(songIds.toList()..shuffle());
  }

  void _playQueueSongIds(List<int> songIds) {
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
    final preferences = await ref
        .read(libraryRepositoryProvider)
        .getPreferenceSettings(
          unknownAlbumName: context.smPlayerI18n.t('common.albumUnknown'),
        );
    _playQueueSongIds(
      quickPlaySongIds(
        songs: snapshot.songs,
        playlists: _effectivePlaylists(snapshot.playlists),
        folders: snapshot.folders,
        preferences: preferences,
        randomLimit: nowPlayingQuickPlayLimit,
      ),
    );
  }

  void _playAlbum(LibrarySong currentSong, List<LibrarySong> songs) {
    final targetAlbum = displayImmersiveModeAlbum(
      currentSong,
      context.smPlayerI18n,
    );
    _playSongIds([
      for (final song in songs)
        if (displayImmersiveModeAlbum(song, context.smPlayerI18n) ==
            targetAlbum)
          song.id,
    ]);
  }

  void _playArtist(LibrarySong currentSong, List<LibrarySong> songs) {
    final currentArtists = artists_model.getSongArtists(currentSong);
    final targetArtists =
        currentArtists.isEmpty ? [currentSong.artist] : currentArtists;
    _playSongIds([
      for (final song in songs)
        if ((artists_model.getSongArtists(song).isEmpty
                ? [song.artist]
                : artists_model.getSongArtists(song))
            .any(targetArtists.contains))
          song.id,
    ]);
  }

  bool _playNextFromQueue(List<LibrarySong> queueSongs) {
    return _playQueueDirection(queueSongs, forward: true);
  }

  bool _togglePlayPauseFromQueue(List<LibrarySong> queueSongs) {
    final controller = ref.read(mediaControlControllerProvider);
    if (controller.state.track.id != null) {
      controller.onTogglePlayPause();
      return true;
    }
    if (queueSongs.isEmpty) {
      return false;
    }
    _playQueueTrack(
      queueSongs.first,
      queueSongs.map((song) => song.id).toList(),
      0,
    );
    return true;
  }

  bool _playPreviousFromQueue(
    List<LibrarySong> queueSongs, {
    bool forcePrevious = false,
  }) {
    if (queueSongs.isEmpty) {
      return false;
    }
    final controller = ref.read(mediaControlControllerProvider);
    if (!forcePrevious &&
        shouldRestartCurrentTrackForPrevious(
          progressSeconds: controller.state.progressSeconds,
          queueLength: queueSongs.length,
          restartAfterThresholdEnabled:
              smPlayerGlobalSettingsSnapshot.previousButtonRestartsTrack,
        )) {
      controller.onSeek(0);
      return true;
    }
    return _playQueueDirection(queueSongs, forward: false);
  }

  bool _playQueueDirection(
    List<LibrarySong> queueSongs, {
    required bool forward,
  }) {
    if (queueSongs.isEmpty) {
      return false;
    }

    final controller = ref.read(mediaControlControllerProvider);
    final nextIndex = nextQueueIndexForPlayback(
      queueLength: queueSongs.length,
      currentIndex: _currentQueueIndex(queueSongs, controller.state),
      mode: controller.state.mode,
      forward: forward,
      automatic: false,
    );
    if (nextIndex == null) {
      return false;
    }

    _playQueueTrack(
      queueSongs[nextIndex],
      queueSongs.map((song) => song.id).toList(),
      nextIndex,
    );
    return true;
  }

  int _currentQueueIndex(
    List<LibrarySong> queueSongs,
    MediaControlState mediaControlState,
  ) {
    final selectedQueueIndex = mediaControlState.selectedQueueIndex;
    if (selectedQueueIndex != null &&
        selectedQueueIndex >= 0 &&
        selectedQueueIndex < queueSongs.length) {
      return selectedQueueIndex;
    }

    final trackIndex = queueSongs.indexWhere(
      (song) => song.id == mediaControlState.track.id,
    );
    return trackIndex == -1 ? 0 : trackIndex;
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
    if (currentSongIds != null &&
        _sameImmersiveModeSongIds(currentSongIds, songIds)) {
      return;
    }
    setNowPlayingQueue(ref, songIds);
  }

  List<int> _currentQueueSongIds(List<int> fallback) {
    return ref.read(nowPlayingQueueOverrideProvider) ??
        ref.read(libraryContentDataProvider).valueOrNull?.nowPlaying.songIds ??
        fallback;
  }

  void _moveQueueSong(List<int> queueSongIds, int oldIndex, int newIndex) {
    _replaceQueue(
      reorderImmersiveModeQueueSongIds(queueSongIds, oldIndex, newIndex),
    );
  }

  void _removeQueueIndex(List<int> queueSongIds, int queueIndex) {
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
  }

  void _removeSelectedQueueIndexes(
    List<int> queueSongIds,
    List<int> selectedIndexes,
    List<int> nextQueueSongIds,
  ) {
    final nextPlayingQueueIndex = _nextQueueIndexAfterRemovingCurrentPlaying(
      queueSongIds,
      selectedIndexes.toSet(),
      nextQueueSongIds,
    );
    _replaceQueue(nextQueueSongIds);
    if (nextPlayingQueueIndex != null) {
      _playQueueSongAt(nextQueueSongIds, nextPlayingQueueIndex);
    }
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

  void _playNext(List<int> queueSongIds, int queueIndex) {
    final mediaControlState = ref.read(mediaControlControllerProvider).state;
    _replaceQueue(
      playNextImmersiveModeQueueSongIds(
        queueSongIds,
        queueSongIds[queueIndex],
        mediaControlState.track.id,
        queueIndex,
        mediaControlState.selectedQueueIndex,
      ),
    );
  }

  Future<void> _createPlaylist(String name, List<int> songIds) async {
    await createPlaylistAndSync(
      context: context,
      ref: ref,
      i18n: context.smPlayerI18n,
      name: name,
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
      useSingleSongCall: songIds.length == 1,
    );
  }

  Future<void> _toggleSongsFavorite(List<int> songIds, bool favorite) async {
    await setSongsFavoriteFromControl(ref, songIds, favorite);
  }

  void _addSongToNowPlaying(LibrarySong song, List<int> queueSongIds) {
    final insertedIndex = queueSongIds.length;
    _replaceQueue([...queueSongIds, song.id]);
    _showUndo(
      context.smPlayerI18n.t('notification.songAddedTo', {
        'title': song.title,
        'target': context.smPlayerI18n.t('common.nowPlaying'),
      }),
      () {
        final current =
            ref
                .read(libraryContentDataProvider)
                .valueOrNull
                ?.nowPlaying
                .songIds ??
            queueSongIds;
        _replaceQueue(removePlaybackQueueRange(current, insertedIndex, 1));
      },
    );
  }

  Future<void> _setSongPreference(
    int songId,
    String title,
    String level,
  ) async {
    await ref
        .read(libraryRepositoryProvider)
        .addPreferenceItem('song', '$songId', title, level);
  }

  Future<String?> _getSongPreferenceLevel(int songId) {
    return ref
        .read(libraryRepositoryProvider)
        .getPreferenceLevel('song', '$songId');
  }

  Future<void> _undoSongPreference(int songId) async {
    await ref
        .read(libraryRepositoryProvider)
        .removePreferenceItem('song', '$songId');
  }

  Future<void> _deleteSongFromDisk(LibrarySong song) async {
    await requestDeleteSongFromDisk(
      context: context,
      ref: ref,
      i18n: context.smPlayerI18n,
      song: song,
    );
  }

  Future<void> _moveSongToFolder(LibrarySong song, String folderPath) async {
    await moveSongToFolderWithUndo(
      context: context,
      ref: ref,
      i18n: context.smPlayerI18n,
      song: song,
      folderPath: folderPath,
    );
  }

  void _openMusicDialog(SongDialogMode mode) {
    _updateImmersiveState(() {
      _isPlaylistOpen = false;
      _dialogMode = mode;
    });
  }

  void _showUndo(String message, FutureOr<void> Function() action) {
    showUndoableNotification(
      context: context,
      i18n: context.smPlayerI18n,
      message: message,
      onUndo: action,
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

  Future<void> _revealPath(String targetPath) async {
    await revealItemInFolder(targetPath);
  }
}
