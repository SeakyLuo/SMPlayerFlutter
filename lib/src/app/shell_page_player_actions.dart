part of 'shell_page.dart';

extension _SmPlayerShellPlayerActions on _SmPlayerShellPageState {
  Widget _buildMiniModeHost() {
    return AnimatedBuilder(
      animation: _mediaControlController,
      builder: (context, _) {
        return Consumer(
          builder: (context, ref, _) {
            final mediaControlState = _mediaControlController.state;
            final snapshot = ref.watch(libraryContentDataProvider).valueOrNull;
            final recentSongs =
                ref.watch(recentPageDataProvider).valueOrNull?.recentSongs ??
                const <RecentLibrarySong>[];
            _scheduleRestorePlaybackTrack(snapshot);
            final currentSong = _resolvePlayerSong(mediaControlState, snapshot);
            _ensurePlayerArtworkResolved(currentSong, ref);
            final settings = _settingsController.snapshot;
            final playbackSongIds =
                snapshot == null ? const <int>[] : _playbackSongIds(snapshot);
            final previousButtonRestartsTrack =
                playbackSongIds.isNotEmpty &&
                shouldRestartCurrentTrackForPrevious(
                  progressSeconds: mediaControlState.progressSeconds,
                  queueLength: playbackSongIds.length,
                  restartAfterThresholdEnabled:
                      settings.previousButtonRestartsTrack,
                );
            final i18n =
                ref.watch(smPlayerI18nProvider).valueOrNull ??
                const SmPlayerI18n(
                  locale: smPlayerFallbackLocale,
                  messages: {},
                );
            _syncDesktopFeatures(
              i18n: i18n,
              snapshot: snapshot,
              recentSongs: recentSongs,
              mediaControlState: mediaControlState,
              currentSong: currentSong,
            );
            return MiniModeSurface(
              state: mediaControlState,
              i18n: i18n,
              currentSong: currentSong,
              repository: ref.read(libraryRepositoryProvider),
              playerLyricsSource: settings.playerLyricsSource,
              lyricsRefreshRevision: _playerLyricsRefreshRevision,
              previousButtonRestartsTrack: previousButtonRestartsTrack,
              onExit: _exitMiniMode,
              onTogglePlayPause: _togglePlayPauseFromCurrentQueue,
              onPrevious: _playPreviousFromCurrentQueue,
              onForcePrevious: () {
                _playPreviousFromCurrentQueue(forcePrevious: true);
              },
              onNext: _playNextFromCurrentQueue,
              onSeek: _mediaControlController.onSeek,
              onBeginSeek: _mediaControlController.onBeginSeek,
              onEndSeek: _mediaControlController.onEndSeek,
              onToggleFavorite:
                  currentSong == null
                      ? _mediaControlController.onToggleFavorite
                      : () {
                        _togglePlayerFavorite(ref, currentSong);
                      },
              onQuickPlay: () {
                _quickPlayLibrary(ref);
              },
              onCyclePlaybackMode: _mediaControlController.cyclePlaybackMode,
              onToggleShuffle: _toggleShufflePlayback,
              onToggleRepeat: _mediaControlController.onToggleRepeat,
              onToggleRepeatOne: _mediaControlController.onToggleRepeatOne,
              onToggleMute: _mediaControlController.onToggleMute,
              onVolumeChange: _mediaControlController.onVolumeChange,
              onOpenVoiceAssistant:
                  supportsVoiceAssistant()
                      ? () {
                        _showVoiceAssistantDialog(snapshot, i18n);
                      }
                      : null,
              onWindowDragStart: _startWindowDrag,
              onWindowDragEnd: _stopWindowDrag,
            );
          },
        );
      },
    );
  }

  void _quickPlayLibrary(WidgetRef ref) {
    unawaited(_quickPlayLibraryAsync(ref));
  }

  Future<void> _quickPlayLibraryAsync(WidgetRef ref) async {
    final i18n = context.smPlayerI18n;
    final snapshot = ref.read(libraryContentDataProvider).valueOrNull;
    final songs = snapshot?.songs ?? const <LibrarySong>[];
    if (songs.isEmpty) {
      return;
    }

    final repository = ref.read(libraryRepositoryProvider);
    final preferences = await repository.getPreferenceSettings();
    final songIds = quickPlaySongIds(
      songs: songs,
      playlists: snapshot!.playlists,
      folders: snapshot.folders,
      preferences: preferences,
    );
    if (songIds.isEmpty) {
      return;
    }
    final songsById = {for (final song in songs) song.id: song};
    final firstSong = songsById[songIds.first]!;
    await repository.replaceNowPlaying(songIds);
    ref.invalidate(libraryContentDataProvider);
    _mediaControlController.playTrack(
      mediaControlTrackForSong(firstSong, i18n),
      durationSeconds: firstSong.duration.toDouble(),
      queueIndex: 0,
    );
  }

  void _togglePlayerFavorite(WidgetRef ref, LibrarySong song) {
    final nextFavorite = !_mediaControlController.state.track.favorite;
    setSongsFavorite(ref, [song.id], nextFavorite);
    if (_mediaControlController.state.track.id == song.id &&
        _mediaControlController.state.track.favorite != nextFavorite) {
      _mediaControlController.onToggleFavorite();
    }
  }

  void _addPlayerSongToNowPlaying(WidgetRef ref, LibrarySong song) {
    final snapshot = ref.read(libraryContentDataProvider).valueOrNull;
    final before = snapshot?.nowPlaying.songIds ?? const <int>[];
    final insertedIndex = before.length;
    ref.read(libraryRepositoryProvider).replaceNowPlaying([...before, song.id]);
    ref.invalidate(libraryContentDataProvider);
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
            before;
        ref
            .read(libraryRepositoryProvider)
            .replaceNowPlaying(
              removePlaybackQueueRange(current, insertedIndex, 1),
            );
        ref.invalidate(libraryContentDataProvider);
      },
    );
  }

  void _addPlayerSongToPlaylist(
    WidgetRef ref,
    LibrarySong song,
    int playlistId,
    List<LibraryPlaylist> playlists,
  ) {
    final targetPlaylist = playlists.firstWhere(
      (playlist) => playlist.id == playlistId,
    );
    ref.read(libraryRepositoryProvider).addSongsToPlaylist(playlistId, [
      song.id,
    ]);
    ref.invalidate(libraryContentDataProvider);
    _showUndo(
      context.smPlayerI18n.t('notification.songAddedTo', {
        'title': song.title,
        'target': targetPlaylist.name,
      }),
      () {
        ref
            .read(libraryRepositoryProvider)
            .removeSongFromPlaylist(playlistId, song.id);
        ref.invalidate(libraryContentDataProvider);
      },
    );
  }

  void _showUndo(String message, FutureOr<void> Function() action) {
    showUndoableNotification(
      context: context,
      i18n: context.smPlayerI18n,
      message: message,
      onUndo: action,
    );
  }

  Future<void> _revealPath(String targetPath) async {
    await revealItemInFolder(targetPath);
  }

  Future<void> _createPlaylistFromNavigation({
    required BuildContext context,
    required WidgetRef ref,
    required SmPlayerI18n i18n,
    required LibraryContentData? snapshot,
  }) async {
    final currentSnapshot =
        snapshot ?? await ref.read(libraryContentDataProvider.future);
    if (!context.mounted || currentSnapshot == null) {
      return;
    }

    final name = await showSmPlayerInputDialog(
      context: context,
      i18n: i18n,
      title: i18n.t('playlists.createNew'),
      defaultValue: getNextPlaylistName(
        i18n.t('common.playlist'),
        currentSnapshot.playlists,
      ),
      placeholder: i18n.t('playlists.namePlaceholder'),
      confirmText: i18n.t('playlists.create'),
      validate: (name) {
        return validatePlaylistName(name, currentSnapshot.playlists, '', i18n);
      },
    );
    if (name == null) {
      return;
    }

    final playlist = await ref
        .read(libraryRepositoryProvider)
        .createPlaylist(name, const []);
    await _settingsController.saveViewState(lastPlaylistId: playlist.id);
    ref.invalidate(libraryContentDataProvider);
    if (!mounted) {
      return;
    }
    _navigateTo('/playlists/${playlist.id}');
  }

  Future<void> _duplicatePlaylistFromNavigation({
    required WidgetRef ref,
    required LibraryContentData? snapshot,
    required LibraryPlaylist playlist,
  }) async {
    final currentSnapshot =
        snapshot ?? await ref.read(libraryContentDataProvider.future);
    if (currentSnapshot == null) {
      return;
    }
    await ref
        .read(libraryRepositoryProvider)
        .createPlaylist(
          getNextPlaylistName(playlist.name, currentSnapshot.playlists),
          playlist.songIds,
        );
    ref.invalidate(libraryContentDataProvider);
  }

  Future<void> _renamePlaylistFromNavigation({
    required BuildContext context,
    required WidgetRef ref,
    required SmPlayerI18n i18n,
    required LibraryContentData? snapshot,
    required LibraryPlaylist playlist,
  }) async {
    final currentSnapshot =
        snapshot ?? await ref.read(libraryContentDataProvider.future);
    if (currentSnapshot == null || !context.mounted) {
      return;
    }

    final name = await showSmPlayerInputDialog(
      context: context,
      i18n: i18n,
      title: i18n.t('playlists.rename'),
      defaultValue: playlist.name,
      placeholder: i18n.t('playlists.namePlaceholder'),
      confirmText: i18n.t('playlists.rename'),
      validate: (name) {
        return validatePlaylistName(
          name,
          currentSnapshot.playlists,
          playlist.name,
          i18n,
        );
      },
    );
    if (name == null || name == playlist.name) {
      return;
    }

    await ref.read(libraryRepositoryProvider).renamePlaylist(playlist.id, name);
    ref.invalidate(libraryContentDataProvider);
  }

  Future<void> _deletePlaylistFromNavigation({
    required WidgetRef ref,
    required SmPlayerI18n i18n,
    required LibraryContentData? snapshot,
    required LibraryPlaylist playlist,
  }) async {
    final currentSnapshot =
        snapshot ?? await ref.read(libraryContentDataProvider.future);
    if (currentSnapshot == null) {
      return;
    }
    await ref.read(libraryRepositoryProvider).deletePlaylist(playlist.id);
    ref.invalidate(libraryContentDataProvider);
    _showUndo(
      i18n.t('notification.playlistRemoved', {'name': playlist.name}),
      () async {
        await ref.read(libraryRepositoryProvider).restorePlaylist(playlist);
        ref.invalidate(libraryContentDataProvider);
      },
    );
  }
}
