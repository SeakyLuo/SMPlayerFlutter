part of 'shell_page.dart';

extension _SmPlayerShellPlayerActions on _SmPlayerShellPageState {
  Widget _buildMiniModeHost() {
    return Consumer(
      builder: (context, ref, _) {
        ref.watch(
          mediaControlControllerProvider.select(
            (controller) => (
              track: controller.state.track,
              selectedQueueIndex: controller.state.selectedQueueIndex,
              disabled: controller.state.disabled,
              isPlaying: controller.state.isPlaying,
              playbackStatus: controller.state.playbackStatus,
              volume: controller.state.volume,
              isMuted: controller.state.isMuted,
              mode: controller.state.mode,
              durationSeconds: controller.state.durationSeconds,
              isProgressSeeking: controller.state.isProgressSeeking,
              restartThresholdReached:
                  controller.state.progressSeconds >
                  previousTrackRestartThresholdSeconds,
            ),
          ),
        );
        final mediaControlState = _mediaControlController.state;
        final snapshot = ref.watch(libraryContentDataProvider).valueOrNull;
        final recentSongs = ref.watch(recentSongsProvider);
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
            const SmPlayerI18n(locale: smPlayerFallbackLocale, messages: {});
        return Stack(
          fit: StackFit.expand,
          children: [
            MiniModeSurface(
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
                        return _showVoiceAssistantDialog(snapshot, i18n);
                      }
                      : null,
              onWindowDragStart: _startWindowDrag,
              onWindowDragEnd: _stopWindowDrag,
            ),
            Consumer(
              builder: (context, ref, _) {
                ref.watch(
                  mediaControlControllerProvider.select(
                    (controller) => controller.state.progressSeconds.round(),
                  ),
                );
                _syncDesktopFeatures(
                  i18n: i18n,
                  snapshot: snapshot,
                  recentSongs: recentSongs,
                  mediaControlState: _mediaControlController.state,
                  currentSong: currentSong,
                );
                return const SizedBox.shrink();
              },
            ),
          ],
        );
      },
    );
  }

  void _quickPlayLibrary(WidgetRef ref) {
    unawaited(_quickPlayLibraryAsync(ref));
  }

  Future<void> _quickPlayLibraryAsync(WidgetRef ref) async {
    final i18n = context.smPlayerI18n;
    final songIds = await sourceQuickPlaySongIds(
      ref: ref,
      unknownAlbumName: i18n.t('common.albumUnknown'),
    );
    if (!mounted) return;
    if (songIds.isEmpty) {
      return;
    }
    replaceNowPlayingQueueAndPlayIndex(
      ref: ref,
      snapshot: ref.read(libraryContentDataProvider).requireValue,
      i18n: i18n,
      songIds: songIds,
      queueIndex: 0,
      mediaController: _mediaControlController,
    );
  }

  void _togglePlayerFavorite(WidgetRef ref, LibrarySong song) {
    final nextFavorite = !_mediaControlController.state.track.favorite;
    unawaited(() async {
      try {
        await setSongsFavorite(ref, [song.id], nextFavorite);
      } catch (error) {
        if (mounted)
          showAppNotification(
            context: context,
            message: context.smPlayerI18n.t(
              error is MusicShareException
                  ? error.messageKey
                  : 'song.updateFailed',
            ),
          );
      }
    }());
  }

  void _addPlayerSongToNowPlaying(WidgetRef ref, LibrarySong song) {
    final snapshot = ref.read(libraryContentDataProvider).valueOrNull;
    final before =
        ref.read(nowPlayingQueueOverrideProvider) ??
        snapshot?.nowPlaying.songIds ??
        const <int>[];
    final insertedIndex = before.length;
    final nextSongIds = [...before, song.id];
    setNowPlayingQueue(ref, nextSongIds);
    _showUndo(
      context.smPlayerI18n.t('notification.songAddedTo', {
        'title': song.title,
        'target': context.smPlayerI18n.t('common.nowPlaying'),
      }),
      () {
        final current =
            ref.read(nowPlayingQueueOverrideProvider) ?? nextSongIds;
        final restoredSongIds = removePlaybackQueueRange(
          current,
          insertedIndex,
          1,
        );
        setNowPlayingQueue(ref, restoredSongIds);
      },
    );
  }

  void _addPlayerSongToPlaylist(
    WidgetRef ref,
    LibrarySong song,
    int playlistId,
  ) {
    unawaited(
      addSongsToPlaylistWithUndo(
        context: context,
        ref: ref,
        i18n: context.smPlayerI18n,
        playlistId: playlistId,
        songIds: [song.id],
      ),
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
    try {
      if (!canCreateSourcePlaylist()) {
        throw const MusicShareException('share.readOnlyPermission');
      }
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
          currentSnapshot.playlists
              .where(
                (p) => playlistBelongsToSource(
                  p,
                  activeMusicShareAccess!.selectedSource,
                ),
              )
              .toList(),
        ),
        placeholder: i18n.t('playlists.namePlaceholder'),
        confirmText: i18n.t('playlists.create'),
        validate: (name) {
          return validatePlaylistName(
            name,
            currentSnapshot.playlists
                .where(
                  (p) => playlistBelongsToSource(
                    p,
                    activeMusicShareAccess!.selectedSource,
                  ),
                )
                .toList(),
            '',
            i18n,
          );
        },
      );
      if (name == null) {
        return;
      }

      final playlist = await ref
          .read(libraryRepositoryProvider)
          .createPlaylist(
            name,
            const [],
            LibrarySource.fromDevice(activeMusicShareAccess!.selectedSource),
          );
      patchLibraryPlaylistOverride(ref, playlist);
      if (!context.mounted) {
        return;
      }
      showPlaylistCreatedNotification(
        context: context,
        i18n: i18n,
        playlist: playlist,
      );
    } catch (error) {
      if (context.mounted)
        showAppNotification(
          context: context,
          message: context.smPlayerI18n.t(
            error is MusicShareException
                ? error.messageKey
                : 'song.updateFailed',
          ),
        );
    }
  }

  Future<void> _duplicatePlaylistFromNavigation({
    required WidgetRef ref,
    required LibraryContentData? snapshot,
    required LibraryPlaylist playlist,
  }) async {
    try {
      final currentSnapshot =
          snapshot ?? await ref.read(libraryContentDataProvider.future);
      if (currentSnapshot == null) {
        return;
      }
      final duplicate = await ref
          .read(libraryRepositoryProvider)
          .createPlaylist(
            getNextPlaylistName(playlist.name, currentSnapshot.playlists),
            playlist.songIds,
            playlist.source,
          );
      patchLibraryPlaylistOverride(ref, duplicate);
      if (mounted) {
        showPlaylistCreatedNotification(
          context: context,
          i18n: context.smPlayerI18n,
          playlist: duplicate,
        );
      }
    } catch (error) {
      if (context.mounted)
        showAppNotification(
          context: context,
          message: context.smPlayerI18n.t(
            error is MusicShareException
                ? error.messageKey
                : 'song.updateFailed',
          ),
        );
    }
  }

  Future<void> _renamePlaylistFromNavigation({
    required BuildContext context,
    required WidgetRef ref,
    required SmPlayerI18n i18n,
    required LibraryContentData? snapshot,
    required LibraryPlaylist playlist,
  }) async {
    try {
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
            currentSnapshot.playlists
                .where(
                  (p) => playlistBelongsToSource(
                    p,
                    activeMusicShareAccess!.selectedSource,
                  ),
                )
                .toList(),
            playlist.name,
            i18n,
          );
        },
      );
      if (name == null || name == playlist.name) {
        return;
      }

      await ref
          .read(libraryRepositoryProvider)
          .renamePlaylist(playlist.id, name);
      patchLibraryPlaylistOverride(ref, playlist.copyWith(name: name));
    } catch (error) {
      if (context.mounted)
        showAppNotification(
          context: context,
          message: context.smPlayerI18n.t(
            error is MusicShareException
                ? error.messageKey
                : 'song.updateFailed',
          ),
        );
    }
  }

  Future<void> _deletePlaylistFromNavigation({
    required WidgetRef ref,
    required SmPlayerI18n i18n,
    required LibraryContentData? snapshot,
    required LibraryPlaylist playlist,
  }) async {
    try {
      final currentSnapshot =
          snapshot ?? await ref.read(libraryContentDataProvider.future);
      if (currentSnapshot == null) {
        return;
      }
      await ref.read(libraryRepositoryProvider).deletePlaylist(playlist.id);
      removeLibraryPlaylistOverride(ref, playlist.id);
      _showUndo(
        i18n.t('notification.playlistRemoved', {'name': playlist.name}),
        () async {
          await ref.read(libraryRepositoryProvider).restorePlaylist(playlist);
          patchLibraryPlaylistOverride(ref, playlist);
        },
      );
    } catch (error) {
      if (context.mounted)
        showAppNotification(
          context: context,
          message: context.smPlayerI18n.t(
            error is MusicShareException
                ? error.messageKey
                : 'song.updateFailed',
          ),
        );
    }
  }

  Future<void> _reorderPlaylistsFromNavigation({
    required WidgetRef ref,
    required List<int> playlistIds,
  }) async {
    try {
      await ref.read(libraryRepositoryProvider).reorderPlaylists(playlistIds);
      setLibraryPlaylistOrder(ref, playlistIds);
    } catch (error) {
      if (context.mounted)
        showAppNotification(
          context: context,
          message: context.smPlayerI18n.t(
            error is MusicShareException
                ? error.messageKey
                : 'song.updateFailed',
          ),
        );
    }
  }

  void _createPlaylistFromNavigationAction(WidgetRef ref) {
    final snapshot = ref.read(libraryContentDataProvider).valueOrNull;
    final i18n = ref.read(smPlayerI18nProvider).value ?? context.smPlayerI18n;
    unawaited(
      _createPlaylistFromNavigation(
        context: _shellFrameKey.currentContext!,
        ref: ref,
        i18n: i18n,
        snapshot: snapshot,
      ),
    );
  }

  void _renamePlaylistFromNavigationAction(
    WidgetRef ref,
    LibraryPlaylist playlist,
  ) {
    final snapshot = ref.read(libraryContentDataProvider).valueOrNull;
    final i18n = ref.read(smPlayerI18nProvider).value ?? context.smPlayerI18n;
    unawaited(
      _renamePlaylistFromNavigation(
        context: _shellFrameKey.currentContext!,
        ref: ref,
        i18n: i18n,
        snapshot: snapshot,
        playlist: playlist,
      ),
    );
  }
}
