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
        openPlayer: () async {
          if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
            await windowManager.restore();
            await windowManager.show();
            await windowManager.focus();
          }
        },
        sharing: () async {
          final share = ref.read(musicShareProvider);
          await share.ready;
          return {
            'enabled': share.sharing,
            'background': share.backgroundSharing,
            'running': share.server.running,
            'port': share.port,
            'name': share.name,
          };
        },
        updateSharing: (update) async {
          final share = ref.read(musicShareProvider);
          await share.startup;
          if (update['enabled'] == false && update['background'] == true) {
            throw const FormatException(
              'Background sharing requires sharing to be enabled',
            );
          }
          if (update['enabled'] == true && !share.sharing)
            await share.setSharing(true);
          if (update.containsKey('background')) {
            if (!share.sharing)
              throw const FormatException(
                'Enable sharing before background sharing',
              );
            if (!await MusicShareBackgroundPlatform.available()) {
              throw const FormatException(
                'Background sharing is not supported on this platform',
              );
            }
            await share.setBackgroundSharing(update['background'] as bool);
          }
          if (update['enabled'] == false && share.sharing)
            await share.setSharing(false);
        },
        settings: () => _settingsController.snapshot,
        updateSettings: _settingsController.updateSettings,
        loadSystemFonts: loadDesktopSystemFonts,
        syncChanges:
            (settings, songIds) =>
                _syncChangesFromAgent(repository, settings, songIds),
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
    await ref.read(musicShareProvider).startup;
    if (!mounted) return;
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

  Future<void> _syncChangesFromAgent(
    LibraryRepository repository,
    List<String> settings,
    List<int> songIds,
  ) async {
    // Read independent sources together; no per-song database requests.
    final (storedSettings, references) =
        await (
          settings.isEmpty
              ? Future<SettingsSnapshot?>.value(null)
              : repository.readSettingsSnapshot(),
          repository.songReferences(songIds),
        ).wait;
    if (references.length != songIds.toSet().length) {
      throw const FormatException(
        'Only existing active songs can be synchronized',
      );
    }
    if (!mounted) return;
    if (settings.isNotEmpty) {
      final values = AiAgentSettingsCodec.read(storedSettings!);
      final update = AiAgentSettingsCodec.decode(
        {for (final key in settings) key: values[key]},
        [storedSettings.desktopLyricsFontFamily],
      );
      _settingsController.restoreSnapshot(
        _settingsController.snapshot.apply(update),
      );
    }
    final visible =
        ref
            .read(libraryLoadedDataProvider)
            .requireValue
            .songs
            .map((song) => song.id)
            .toSet();
    final requested = references.keys.where(visible.contains).toList();
    final songs =
        requested.isEmpty
            ? const <LibrarySong>[]
            : await repository.getLibrarySongs(songIds: requested);
    if (!mounted) return;
    for (final source
        in references.values
            .map((path) => LibrarySource.fromPath(path).deviceId)
            .toSet()) {
      invalidateLibraryQueries(ref.invalidate, source: source);
    }
    if (songs.isEmpty) return;
    patchLibrarySongOverrides(ref, songs);
    final favorites = ref.read(libraryFavoriteOverridesProvider.notifier);
    favorites.state = {
      ...favorites.state,
      for (final song in songs) song.id: song.favorite,
    };
    final current =
        songs
            .where((song) => song.id == _mediaControlController.state.track.id)
            .firstOrNull;
    if (current != null) {
      _mediaControlController.updateTrackMetadata(
        mediaControlTrackForSong(current, context.smPlayerI18n),
      );
    }
  }

  Future<bool> _playAgentQueue(List<int> songIds, int startIndex) async {
    if (songIds.isEmpty || startIndex < 0 || startIndex >= songIds.length)
      return false;
    final repository = ref.read(libraryRepositoryProvider);
    final songs = await repository.getLibrarySongs(songIds: songIds);
    final found = songs.map((song) => song.id).toSet();
    if (songIds.any((id) => !found.contains(id))) return false;
    await ref.read(libraryLoadedDataProvider.notifier).addSongs(songs);
    if (!mounted) return false;
    final snapshot = ref.read(libraryLoadedDataProvider).requireValue;
    await replaceNowPlayingQueueAndPlayIndex(
      ref: ref,
      snapshot: snapshot,
      i18n: context.smPlayerI18n,
      songIds: songIds,
      queueIndex: startIndex,
      mediaController: _mediaControlController,
      showQueueUpdatedNotification: false,
    );
    return true;
  }

  Future<bool> _updateSongFromAgent(
    LibraryRepository repository,
    int songId,
    Map<String, Object?> properties,
  ) async {
    final songs = await repository.getLibrarySongs(songIds: [songId]);
    final song = songs.firstOrNull;
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
    if (!isRemoteMusicPath(updatedSong.path)) {
      patchLibrarySongOverride(ref, updatedSong);
    }
    _mediaControlController.updateTrackMetadata(
      mediaControlTrackForSong(updatedSong, context.smPlayerI18n),
    );
    return true;
  }
}
