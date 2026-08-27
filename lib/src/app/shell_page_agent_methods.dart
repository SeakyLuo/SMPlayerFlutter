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
        updateSong:
            (songId, properties) =>
                _updateSongFromAgent(repository, songId, properties),
      ),
    );
    if (!_settingsController.snapshot.aiAgentEnabled) {
      return;
    }
    try {
      await aiAgentRemoteController.start(
        port: _settingsController.snapshot.aiAgentPort,
      );
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

  Future<bool> _updateSongFromAgent(
    LibraryRepository repository,
    int songId,
    Map<String, Object?> properties,
  ) async {
    final library = ref.read(libraryContentDataProvider).valueOrNull;
    final song = library?.songs.where((song) => song.id == songId).firstOrNull;
    if (song == null) {
      return false;
    }
    final current = await repository.getSongProperties(songId);
    final artists =
        properties.containsKey('artists')
            ? (properties['artists']! as List).cast<String>()
            : current.artists;
    final updated = current.copyWith(
      title: properties['title'] as String? ?? current.title,
      subtitle: properties['subtitle'] as String? ?? current.subtitle,
      artist: artists.join(', '),
      artists: artists,
      album: properties['album'] as String? ?? current.album,
      albumArtist: properties['albumArtist'] as String? ?? current.albumArtist,
      publisher: properties['publisher'] as String? ?? current.publisher,
      trackNumber: properties['trackNumber'] as int? ?? current.trackNumber,
      year: properties['year'] as int? ?? current.year,
      genre: properties['genre'] as String? ?? current.genre,
      composers: properties['composers'] as String? ?? current.composers,
      playCount: properties['playCount'] as int? ?? current.playCount,
    );
    await repository.updateSongProperties(
      songId,
      SongPropertiesUpdate(
        title: updated.title,
        subtitle: updated.subtitle,
        artist: updated.artist,
        artists: updated.artists,
        album: updated.album,
        albumArtist: updated.albumArtist,
        publisher: updated.publisher,
        trackNumber: updated.trackNumber,
        year: updated.year,
        genre: updated.genre,
        composers: updated.composers,
        playCount: updated.playCount,
      ),
    );
    if (!mounted) {
      return true;
    }
    final updatedSong = song.copyWith(
      title: updated.title,
      artist: updated.artist,
      artists: updated.artists,
      album: updated.album,
      playCount: updated.playCount,
    );
    patchLibrarySongOverride(ref, updatedSong);
    _mediaControlController.updateTrackMetadata(
      mediaControlTrackForSong(updatedSong, context.smPlayerI18n),
    );
    ref.invalidate(libraryContentDataProvider);
    ref.invalidate(recentPageDataProvider);
    return true;
  }
}
