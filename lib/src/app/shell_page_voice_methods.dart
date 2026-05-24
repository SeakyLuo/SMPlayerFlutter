part of 'shell_page.dart';

extension _SmPlayerShellVoiceMethods on _SmPlayerShellPageState {
  String _getVoiceAssistantHint(LibraryViewData? snapshot, SmPlayerI18n i18n) {
    final songs = snapshot?.songs ?? const <LibrarySong>[];
    final song = songs.isEmpty ? null : songs[Random().nextInt(songs.length)];
    final hintType = Random().nextInt(3);
    if (hintType == 0) {
      final artist = song?.artist;
      if (artist != null && artist.isNotEmpty && artist.length <= 30) {
        return i18n.t('voiceAssistant.hintArtist', {'artist': artist});
      }
    }
    if (hintType == 1) {
      final album = song?.album;
      if (album != null && album.isNotEmpty && album.length <= 30) {
        return i18n.t('voiceAssistant.hintAlbum', {'album': album});
      }
    }
    return i18n.t('voiceAssistant.hintQuickPlay');
  }

  String _executeVoiceAssistantCommand(
    String rawCommand,
    LibraryViewData? snapshot,
    SmPlayerI18n i18n,
  ) {
    final command = rawCommand.trim();
    if (command.isEmpty) {
      return i18n.t('voiceAssistant.notUnderstood');
    }

    final lower = command.toLowerCase();
    final parsedResult = _executeVoiceAssistantCommandResult(
      parseVoiceAssistantCommand(command, i18n.locale),
      snapshot,
      i18n,
    );
    if (parsedResult != null) {
      return parsedResult;
    }

    if (isVoiceHelpCommand(lower)) {
      return i18n.t('voiceAssistant.help');
    }

    if (voiceMatchesAny(lower, const ['quick play', 'quickplay']) ||
        command == '快速播放') {
      _quickPlayLibrary(ref);
      return i18n.t('voiceAssistant.executed');
    }

    if (voiceMatchesAny(command, const ['下一首', '下首']) ||
        voiceMatchesAny(lower, const ['next', 'next song'])) {
      _playNextFromCurrentQueue();
      return i18n.t('voiceAssistant.executed');
    }

    if (voiceMatchesAny(command, const ['上一首', '上首']) ||
        voiceMatchesAny(lower, const ['previous', 'prev', 'previous song'])) {
      _playPreviousFromCurrentQueue();
      return i18n.t('voiceAssistant.executed');
    }

    if (voiceMatchesAny(command, const ['暂停']) ||
        voiceMatchesAny(lower, const ['pause'])) {
      if (_mediaControlController.state.isPlaying) {
        _togglePlayPauseFromCurrentQueue();
      }
      return i18n.t('voiceAssistant.executed');
    }

    if (voiceMatchesAny(command, const ['继续', '恢复']) ||
        voiceMatchesAny(lower, const ['continue', 'resume'])) {
      if (!_mediaControlController.state.isPlaying) {
        _togglePlayPauseFromCurrentQueue();
      }
      return i18n.t('voiceAssistant.executed');
    }

    if (voiceMatchesAny(command, const ['静音']) ||
        voiceMatchesAny(lower, const ['mute'])) {
      if (!_mediaControlController.state.isMuted) {
        _mediaControlController.onToggleMute();
      }
      return i18n.t('voiceAssistant.executed');
    }

    if (voiceMatchesAny(command, const ['取消静音']) ||
        voiceMatchesAny(lower, const ['unmute'])) {
      if (_mediaControlController.state.isMuted) {
        _mediaControlController.onToggleMute();
      }
      return i18n.t('voiceAssistant.executed');
    }

    if (command.startsWith('音量') || lower.contains('volume')) {
      final volumeResult = _executeVoiceVolumeCommand(command, lower, i18n);
      if (volumeResult != null) {
        return volumeResult;
      }
    }

    final searchQuery = stripVoicePrefix(command, const ['搜索', 'search']);
    if (searchQuery != null && searchQuery.isNotEmpty) {
      _commitSearch(searchQuery);
      return i18n.t('voiceAssistant.executed');
    }

    final playArtist = stripVoicePrefix(command, const [
      '播放歌手',
      '播放艺术家',
      'play artist',
      'play music by',
    ]);
    if (playArtist != null && playArtist.isNotEmpty) {
      return _playMatchedSongs(snapshot, i18n, playArtist, songArtistMatches);
    }

    final playAlbum = stripVoicePrefix(command, const ['播放专辑', 'play album']);
    if (playAlbum != null && playAlbum.isNotEmpty) {
      return _playMatchedSongs(
        snapshot,
        i18n,
        playAlbum,
        (song, query) => songAlbumMatches(song, query, i18n),
      );
    }

    final playPlaylist = stripVoicePrefix(command, const [
      '播放列表',
      '播放歌单',
      'play playlist',
      'play list',
    ]);
    if (playPlaylist != null && playPlaylist.isNotEmpty) {
      return _playPlaylistByName(snapshot, i18n, playPlaylist);
    }

    final playFolder = stripVoicePrefix(command, const [
      '播放文件夹',
      '播放文件',
      'play folder',
    ]);
    if (playFolder != null && playFolder.isNotEmpty) {
      _commitSearch(playFolder, SearchHistoryType.folders);
      return i18n.t('voiceAssistant.executed');
    }

    final playQuery = stripVoicePrefix(command, const [
      '播放歌曲',
      '播放音乐',
      '播放',
      'play music',
      'play song',
      'play',
    ]);
    if (playQuery != null) {
      if (playQuery.isEmpty) {
        if (!_mediaControlController.state.isPlaying &&
            !_togglePlayPauseFromCurrentQueue()) {
          _quickPlayLibrary(ref);
        }
        return i18n.t('voiceAssistant.executed');
      }
      return _playMatchedSongs(
        snapshot,
        i18n,
        playQuery,
        (song, query) => songTextMatches(song, query, i18n),
      );
    }

    return i18n.t('voiceAssistant.notUnderstood');
  }

  String? _executeVoiceAssistantCommandResult(
    VoiceAssistantCommandResult result,
    LibraryViewData? snapshot,
    SmPlayerI18n i18n,
  ) {
    switch (result.type) {
      case VoiceAssistantMatchType.matchNone:
        return null;
      case VoiceAssistantMatchType.help:
        return i18n.t('voiceAssistant.help');
      case VoiceAssistantMatchType.nothing:
        return i18n.t('voiceAssistant.canceled');
      case VoiceAssistantMatchType.quickPlay:
        _quickPlayLibrary(ref);
        return i18n.t('voiceAssistant.executed');
      case VoiceAssistantMatchType.play:
        if (!_mediaControlController.state.isPlaying &&
            !_togglePlayPauseFromCurrentQueue()) {
          _quickPlayLibrary(ref);
        }
        return i18n.t('voiceAssistant.executed');
      case VoiceAssistantMatchType.pause:
        if (_mediaControlController.state.isPlaying) {
          _togglePlayPauseFromCurrentQueue();
        }
        return i18n.t('voiceAssistant.executed');
      case VoiceAssistantMatchType.previous:
        _playPreviousFromCurrentQueue();
        return i18n.t('voiceAssistant.executed');
      case VoiceAssistantMatchType.next:
        _playNextFromCurrentQueue();
        return i18n.t('voiceAssistant.executed');
      case VoiceAssistantMatchType.changeVolume:
        return _executeVoiceVolumeRequest(result.volumeRequest!, i18n);
      case VoiceAssistantMatchType.mute:
        if (!_mediaControlController.state.isMuted) {
          _mediaControlController.onToggleMute();
        }
        return i18n.t('voiceAssistant.executed');
      case VoiceAssistantMatchType.unMute:
        if (_mediaControlController.state.isMuted) {
          _mediaControlController.onToggleMute();
        }
        return i18n.t('voiceAssistant.executed');
      case VoiceAssistantMatchType.search:
        _commitSearch(result.value!);
        return i18n.t('voiceAssistant.executed');
      case VoiceAssistantMatchType.playArtist:
        return _playMatchedSongs(
          snapshot,
          i18n,
          result.value!,
          songArtistMatches,
        );
      case VoiceAssistantMatchType.playAlbum:
        return _playMatchedSongs(
          snapshot,
          i18n,
          result.value!,
          (song, query) => songAlbumMatches(song, query, i18n),
        );
      case VoiceAssistantMatchType.playPlaylist:
        return _playPlaylistByName(snapshot, i18n, result.value!);
      case VoiceAssistantMatchType.playFolder:
        _commitSearch(result.value!, SearchHistoryType.folders);
        return i18n.t('voiceAssistant.executed');
      case VoiceAssistantMatchType.searchAndPlay:
      case VoiceAssistantMatchType.playMusic:
        return _playMatchedSongs(
          snapshot,
          i18n,
          result.value!,
          (song, query) => songTextMatches(song, query, i18n),
        );
      case VoiceAssistantMatchType.playByArtistOrMusic:
        final request = result.request!;
        final artistSongs =
            (snapshot?.songs ?? const <LibrarySong>[])
                .where((song) => songArtistMatches(song, request.right))
                .take(100)
                .toList();
        if (artistSongs.isNotEmpty) {
          _playSongQueue(artistSongs);
          return i18n.t('voiceAssistant.executed');
        }
        return _playMatchedSongs(
          snapshot,
          i18n,
          request.original,
          (song, query) => songTextMatches(song, query, i18n),
        );
      case VoiceAssistantMatchType.playByArtist:
      case VoiceAssistantMatchType.playByArtistAndMusic:
        final request = result.request!;
        return _playMatchedSongs(
          snapshot,
          i18n,
          request.left,
          (song, query) =>
              voiceTextMatches(song.title, query) &&
              songArtistMatches(song, request.right),
        );
      case VoiceAssistantMatchType.playByArtistAndAlbum:
        final request = result.request!;
        return _playMatchedSongs(
          snapshot,
          i18n,
          request.left,
          (song, query) =>
              songAlbumMatches(song, query, i18n) &&
              songArtistMatches(song, request.right),
        );
      case VoiceAssistantMatchType.playMusicInAlbum:
        final request = result.request!;
        final albumQuery = stripVoiceTargetType(request.right, 'album');
        return _playMatchedSongs(
          snapshot,
          i18n,
          request.left,
          (song, query) =>
              voiceTextMatches(song.title, query) &&
              songAlbumMatches(song, albumQuery, i18n),
        );
      case VoiceAssistantMatchType.playMusicInPlaylist:
        final request = result.request!;
        return _playMatchingSongsInPlaylist(
          snapshot,
          i18n,
          stripVoiceTargetType(request.right, 'playlist'),
          request.left,
        );
      case VoiceAssistantMatchType.playMusicInFolder:
        final request = result.request!;
        final folderQuery = stripVoiceTargetType(request.right, 'folder');
        return _playMatchedSongs(
          snapshot,
          i18n,
          request.left,
          (song, query) =>
              voiceTextMatches(song.title, query) &&
              voiceTextMatches(
                displayFolderNameForVoice(song.path),
                folderQuery,
              ),
        );
      case VoiceAssistantMatchType.playMusicIn:
        final request = result.request!;
        return _playMatchedSongs(
          snapshot,
          i18n,
          request.left,
          (song, query) =>
              voiceTextMatches(song.title, query) &&
              (songAlbumMatches(song, request.right, i18n) ||
                  songArtistMatches(song, request.right) ||
                  voiceTextMatches(
                    displayFolderNameForVoice(song.path),
                    request.right,
                  )),
        );
    }
  }

  String _executeVoiceVolumeRequest(
    VoiceAssistantVolumeRequest request,
    SmPlayerI18n i18n,
  ) {
    final current = _mediaControlController.state.volume;
    final nextVolume =
        request.to
            ? clampVolumeValue(request.value)
            : clampVolumeValue(
              current +
                  (request.turnUp ? 1 : -1) *
                      request.value *
                      (request.percentage ? current / 100 : 1),
            );
    _mediaControlController.onVolumeChange(nextVolume);
    return i18n.t('voiceAssistant.volume', {'volume': '$nextVolume%'});
  }

  String? _executeVoiceVolumeCommand(
    String command,
    String lower,
    SmPlayerI18n i18n,
  ) {
    if (voiceMatchesAny(command, const ['静音']) ||
        voiceMatchesAny(lower, const ['mute'])) {
      if (!_mediaControlController.state.isMuted) {
        _mediaControlController.onToggleMute();
      }
      return i18n.t('voiceAssistant.executed');
    }
    if (voiceMatchesAny(command, const ['取消静音']) ||
        voiceMatchesAny(lower, const ['unmute'])) {
      if (_mediaControlController.state.isMuted) {
        _mediaControlController.onToggleMute();
      }
      return i18n.t('voiceAssistant.executed');
    }

    final amount = firstVoiceNumber(command) ?? 10;
    final current = _mediaControlController.state.volume;
    final isDown =
        command.contains('调低') ||
        command.contains('降低') ||
        lower.contains('down') ||
        lower.contains('decrease');
    final isUp =
        command.contains('调高') ||
        command.contains('提高') ||
        lower.contains('up') ||
        lower.contains('increase');
    final isSet =
        command.contains('到') ||
        lower.contains(' to ') ||
        lower.startsWith('volume ');
    if (!isDown && !isUp && !isSet) {
      return null;
    }

    final nextVolume =
        isDown
            ? current - amount
            : isUp
            ? current + amount
            : amount;
    _mediaControlController.onVolumeChange(nextVolume);
    return i18n.t('voiceAssistant.volume', {
      'volume': '${_mediaControlController.state.volume}%',
    });
  }

  String _playPlaylistByName(
    LibraryViewData? snapshot,
    SmPlayerI18n i18n,
    String query,
  ) {
    final playlists = snapshot?.playlists ?? const <LibraryPlaylist>[];
    for (final playlist in playlists) {
      if (voiceTextMatches(playlist.name, query)) {
        final songsById = {
          for (final song in snapshot?.songs ?? const <LibrarySong>[])
            song.id: song,
        };
        final songs =
            playlist.songIds
                .map((songId) => songsById[songId])
                .whereType<LibrarySong>()
                .toList();
        if (songs.isEmpty) {
          break;
        }
        _playSongQueue(songs);
        return i18n.t('voiceAssistant.executed');
      }
    }
    return i18n.t('voiceAssistant.noResults', {'query': query});
  }

  String _playMatchingSongsInPlaylist(
    LibraryViewData? snapshot,
    SmPlayerI18n i18n,
    String playlistQuery,
    String songQuery,
  ) {
    final playlists = snapshot?.playlists ?? const <LibraryPlaylist>[];
    for (final playlist in playlists) {
      if (voiceTextMatches(playlist.name, playlistQuery)) {
        final playlistSongIds = playlist.songIds.toSet();
        return _playMatchedSongs(
          snapshot,
          i18n,
          songQuery,
          (song, query) =>
              playlistSongIds.contains(song.id) &&
              voiceTextMatches(song.title, query),
        );
      }
    }
    return i18n.t('voiceAssistant.noResults', {'query': playlistQuery});
  }

  String _playMatchedSongs(
    LibraryViewData? snapshot,
    SmPlayerI18n i18n,
    String query,
    bool Function(LibrarySong song, String query) matches,
  ) {
    final songs =
        (snapshot?.songs ?? const <LibrarySong>[])
            .where((song) => matches(song, query))
            .take(100)
            .toList();
    if (songs.isEmpty) {
      return i18n.t('voiceAssistant.noResults', {'query': query});
    }
    _playSongQueue(songs);
    return i18n.t('voiceAssistant.executed');
  }
}
