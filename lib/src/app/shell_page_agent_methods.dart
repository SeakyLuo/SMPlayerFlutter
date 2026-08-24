part of 'shell_page.dart';

extension _SmPlayerShellAgentMethods on _SmPlayerShellPageState {
  Future<void> _initializeAiAgentRemote() async {
    final LibraryRepository repository =
        _settingsController.repository ?? ref.read(libraryRepositoryProvider);
    final databasePath = await repository.getDatabasePath();
    if (!mounted) {
      return;
    }
    aiAgentRemoteController.attach(
      AiAgentControlBindings(
        databasePath: databasePath,
        playerState: _agentPlayerState,
        playSong: (songId) => _playAgentQueue([songId], 0),
        playQueue: _playAgentQueue,
        play: () {
          if (_mediaControlController.state.isPlaying) {
            return true;
          }
          return _togglePlayPauseFromCurrentQueue();
        },
        pause: () {
          if (_mediaControlController.state.disabled) {
            return false;
          }
          _pauseCurrentPlayback();
          return true;
        },
        next: _playNextFromCurrentQueue,
        previous: _playPreviousFromCurrentQueue,
        seek: (seconds) {
          if (_mediaControlController.state.disabled) {
            return false;
          }
          _mediaControlController.onSeek(seconds);
          return true;
        },
        setVolume: (volume) {
          _mediaControlController.onVolumeChange(volume);
          return true;
        },
      ),
    );
    if (!_settingsController.snapshot.aiAgentEnabled) {
      return;
    }
    try {
      await aiAgentRemoteController.start();
    } on Object {
      await _settingsController.updateSettings(
        const AppSettingsUpdate(aiAgentEnabled: false),
      );
      if (mounted) {
        showAppNotification(
          context: context,
          message: context.smPlayerI18n.t('settings.aiAgentUpdateFailed'),
        );
      }
    }
  }

  Map<String, Object?> _agentPlayerState() {
    final mediaState = _mediaControlController.state;
    final snapshot = ref.read(libraryContentDataProvider).valueOrNull;
    final queueSongIds =
        snapshot == null ? const <int>[] : _playbackSongIds(snapshot);
    return {
      'isPlaying': mediaState.isPlaying,
      'status': mediaState.playbackStatus.name,
      'progressSeconds': mediaState.progressSeconds,
      'durationSeconds': mediaState.durationSeconds,
      'volume': mediaState.volume,
      'isMuted': mediaState.isMuted,
      'mode': mediaState.mode.name,
      'track':
          mediaState.track.id == null
              ? null
              : {
                'id': mediaState.track.id,
                'title': mediaState.track.title,
                'artist': mediaState.track.artist,
              },
      'queueSongIds': queueSongIds,
      'queueIndex': mediaState.selectedQueueIndex,
    };
  }

  bool _playAgentQueue(List<int> songIds, int startIndex) {
    final snapshot = ref.read(libraryContentDataProvider).valueOrNull;
    if (snapshot == null ||
        songIds.isEmpty ||
        startIndex < 0 ||
        startIndex >= songIds.length) {
      return false;
    }
    final librarySongIds = snapshot.songs.map((song) => song.id).toSet();
    if (songIds.any((songId) => !librarySongIds.contains(songId))) {
      return false;
    }
    unawaited(
      replaceNowPlayingQueueAndPlayIndex(
        ref: ref,
        snapshot: snapshot,
        i18n: context.smPlayerI18n,
        songIds: songIds,
        queueIndex: startIndex,
        mediaController: _mediaControlController,
        showQueueUpdatedNotification: false,
      ),
    );
    return true;
  }
}
