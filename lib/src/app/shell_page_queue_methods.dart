part of 'shell_page.dart';

extension _SmPlayerShellQueueMethods on _SmPlayerShellPageState {
  void _playSongQueue(List<LibrarySong> songs) {
    final songIds = songs.map((song) => song.id).toList();
    replaceNowPlayingQueueAndPlayIndex(
      ref: ref,
      snapshot: ref.read(libraryContentDataProvider).value!,
      i18n: context.smPlayerI18n,
      songIds: songIds,
      queueIndex: 0,
      mediaController: _mediaControlController,
    );
  }

  bool _playNextFromCurrentQueue({bool automatic = false}) {
    return _playQueueDirection(forward: true, automatic: automatic);
  }

  bool _playPreviousFromCurrentQueue({bool forcePrevious = false}) {
    final snapshot = ref.read(libraryContentDataProvider).valueOrNull;
    if (snapshot == null) {
      return false;
    }
    final playbackSongIds = _playbackSongIds(snapshot);
    if (playbackSongIds.isEmpty) {
      return false;
    }
    final progressSeconds = _audioPlayer.position.inMilliseconds / 1000;
    final current =
        snapshot.songs
            .where((song) => song.id == _mediaControlController.state.track.id)
            .firstOrNull;
    if (!forcePrevious &&
        current != null &&
        _loadedAudioTrackId == current.id &&
        _loadedAudioPath == current.path &&
        shouldRestartCurrentTrackForPrevious(
          progressSeconds: progressSeconds,
          queueLength: playbackSongIds.length,
          restartAfterThresholdEnabled:
              _settingsController.snapshot.previousButtonRestartsTrack,
        )) {
      unawaited(_audioPlayer.seek(Duration.zero));
      _syncingAudioPlayer = true;
      _mediaControlController.syncPlaybackProgress(0);
      if (!_mediaControlController.state.isPlaying) {
        _mediaControlController.setTrackLoading(false);
      }
      _syncingAudioPlayer = false;
      _settingsController.savePlaybackSettingsImmediate(
        const PlaybackSettingsUpdate(musicProgress: 0),
      );
      return true;
    }
    return _playQueueDirection(forward: false, automatic: false);
  }

  bool _playQueueDirection({required bool forward, required bool automatic}) {
    final snapshot = ref.read(libraryContentDataProvider).valueOrNull;
    if (snapshot == null) {
      return false;
    }
    final playbackSongIds = _playbackSongIds(snapshot);
    if (playbackSongIds.isEmpty) {
      return false;
    }

    var currentIndex = _currentQueueIndex(snapshot, playbackSongIds);
    if (automatic && forward && currentIndex == -1) {
      currentIndex = uniquePlaybackQueueIndex(
        playbackSongIds,
        _mediaControlController.state.track.id,
      );
    }
    if (automatic &&
        forward &&
        _mediaControlController.state.mode == PlaybackMode.shuffle &&
        _settingsController.snapshot.shuffleAfterOneRound &&
        currentIndex >= playbackSongIds.length - 1) {
      return _shuffleAndPlayNextRound(snapshot, playbackSongIds);
    }

    final nextIndex = nextPlayableQueueIndex(
      songIds: playbackSongIds,
      songs: snapshot.songs,
      currentIndex: currentIndex,
      mode: _mediaControlController.state.mode,
      forward: forward,
      automatic: automatic,
    );
    if (nextIndex == null) {
      return false;
    }
    if (automatic && nextIndex == currentIndex) {
      final trackId = _mediaControlController.state.track.id;
      unawaited(
        _audioPlayer.seek(Duration.zero).then((_) {
          final current = _mediaControlController.state;
          if (mounted && current.track.id == trackId && current.isPlaying) {
            unawaited(_audioPlayer.play());
          }
        }),
      );
      _syncingAudioPlayer = true;
      _mediaControlController.syncPlaybackProgress(0);
      _mediaControlController.setPlaybackActive(true);
      _syncingAudioPlayer = false;
      return true;
    }

    return _playQueueIndex(
      snapshot,
      playbackSongIds,
      nextIndex,
      forward: forward,
    );
  }

  bool _shuffleAndPlayNextRound(
    LibraryContentData snapshot,
    List<int> playbackSongIds,
  ) {
    final nextSongIds = shuffleNextRoundSongIds(
      playbackSongIds,
      _mediaControlController.state.track.id,
    );
    final first = nextPlayableQueueIndex(
      songIds: nextSongIds,
      songs: snapshot.songs,
      currentIndex: -1,
      mode: PlaybackMode.once,
      forward: true,
      automatic: false,
    );
    if (first == null) return false;
    setNowPlayingQueue(ref, nextSongIds);
    return _playQueueSong(snapshot, nextSongIds, first);
  }

  List<int> _playbackSongIds(LibraryContentData snapshot) =>
      (ref.read(nowPlayingQueueOverrideProvider) ?? snapshot.nowPlaying.songIds)
          .toList();

  int _currentQueueIndex(
    LibraryContentData snapshot, [
    List<int>? playbackSongIds,
  ]) {
    return currentPlaybackQueueIndex(
      playbackSongIds ?? _playbackSongIds(snapshot),
      _mediaControlController.state.track.id,
      _mediaControlController.state.selectedQueueIndex ?? -1,
    );
  }

  bool _playQueueIndex(
    LibraryContentData snapshot,
    List<int> playbackSongIds,
    int queueIndex, {
    bool forward = true,
  }) {
    final played = _playQueueSong(
      snapshot,
      playbackSongIds,
      queueIndex,
      forward: forward,
    );
    if (!played) {
      return false;
    }
    return true;
  }

  bool _playQueueSong(
    LibraryContentData snapshot,
    List<int> songIds,
    int queueIndex, {
    bool forward = true,
  }) {
    final revision = ++_queueLoadRevision;
    unawaited(
      _resolveQueueTrack(snapshot, songIds, queueIndex, revision, forward),
    );
    return true;
  }

  Future<void> _resolveQueueTrack(
    LibraryContentData snapshot,
    List<int> songIds,
    int queueIndex,
    int revision,
    bool forward,
  ) async {
    try {
      final available = await ref
          .read(libraryRepositoryProvider)
          .playableQueueReferences(songIds);
      if (!mounted || revision != _queueLoadRevision) return;
      var index = queueIndex;
      for (
        var checked = 0;
        checked < songIds.length && !available.contains(songIds[index]);
        checked++
      ) {
        final next = nextQueueIndexForPlayback(
          queueLength: songIds.length,
          currentIndex: index,
          mode:
              _mediaControlController.state.mode == PlaybackMode.repeatOne
                  ? PlaybackMode.once
                  : _mediaControlController.state.mode,
          forward: forward,
          automatic: false,
        );
        if (next == null) return;
        index = next;
      }
      if (!available.contains(songIds[index])) return;
      final startSeconds = resolveQueuePlaybackStartSeconds(
        currentTrackId: _mediaControlController.state.track.id,
        nextTrackId: songIds[index],
        currentQueueIndex: _mediaControlController.state.selectedQueueIndex,
        nextQueueIndex: index,
        currentProgressSeconds: _mediaControlController.state.progressSeconds,
      );
      final result = await playQueueIndex(
        ref: ref,
        snapshot: snapshot,
        i18n: context.smPlayerI18n,
        songIds: songIds,
        queueIndex: index,
        mediaController: _mediaControlController,
        progressSeconds: startSeconds,
      );
      if (!mounted ||
          revision != _queueLoadRevision ||
          result != QueuePlayResult.played)
        return;
      _settingsController.savePlaybackSettingsImmediate(
        PlaybackSettingsUpdate(
          lastMusicIndex: index,
          musicProgress: startSeconds,
        ),
      );
    } catch (error) {
      if (mounted && revision == _queueLoadRevision)
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

  Future<void> _randomPlayPlaylist(WidgetRef ref, int playlistId) async {
    final i18n = context.smPlayerI18n;
    final playlist = ref
        .read(currentLibraryPlaylistsProvider)
        .firstWhere((playlist) => playlist.id == playlistId);
    final adapter = ref
        .read(libraryRepositoryProvider)
        .dataSource(playlist.source);
    final songs = await adapter.selectSongIds(
      LibrarySelectionRequest(
        LibrarySelectionKind.savedPlaylist,
        playlistId: playlistId,
      ),
    );
    if (!mounted || songs.isEmpty) return;
    await recordRecentPlaylistPlayback(ref, playlistId);
    replaceNowPlayingQueueAndPlayIndex(
      ref: ref,
      snapshot: ref.read(libraryContentDataProvider).requireValue,
      i18n: i18n,
      songIds: songs,
      queueIndex: 0,
      mediaController: _mediaControlController,
    );
  }
}
