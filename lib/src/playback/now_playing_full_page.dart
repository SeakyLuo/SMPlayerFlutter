import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smplayer_flutter/src/app/undoable_notification.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
import 'package:smplayer_flutter/src/library/ui/menu_flyout.dart';
import 'package:smplayer_flutter/src/library/ui/menu_flyout_helpers.dart';
import 'package:smplayer_flutter/src/library/ui/multi_select_command_bar.dart';
import 'package:smplayer_flutter/src/library/ui/library_page_actions.dart';
import 'package:smplayer_flutter/src/library/ui/music_dialog.dart';
import 'package:smplayer_flutter/src/library/ui/page_selection_store.dart';
import 'package:smplayer_flutter/src/platform/desktop_features.dart';
import 'package:smplayer_flutter/src/playback/media_control.dart';
import 'package:smplayer_flutter/src/playback/media_control_model.dart';
import 'package:smplayer_flutter/src/playback/media_control_provider.dart';
import 'package:smplayer_flutter/src/playback/now_playing_full_model.dart';
import 'package:smplayer_flutter/src/playback/playlist_control_item.dart';
import 'package:smplayer_flutter/src/playback/quick_play_model.dart';

class NowPlayingFullPage extends ConsumerStatefulWidget {
  const NowPlayingFullPage({super.key});

  @override
  ConsumerState<NowPlayingFullPage> createState() => _NowPlayingFullPageState();
}

class _NowPlayingFullPageState extends ConsumerState<NowPlayingFullPage> {
  final _selection = PageSelectionController<int>.stored('now-playing-full');
  final _queueController = ScrollController();
  var _isPlaylistOpen = false;
  LibrarySong? _dialogSong;
  SongDialogMode? _dialogMode;

  @override
  void dispose() {
    _queueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snapshotValue = ref.watch(libraryViewDataProvider);
    final mediaControlState = ref.watch(mediaControlControllerProvider).state;
    final i18n = context.smPlayerI18n;

    return snapshotValue.when(
      loading:
          () => _NowPlayingFullScaffold(
            child: Center(
              child: Text(
                i18n.t('nowPlaying.loading'),
                style: const TextStyle(
                  color: _NowPlayingFullColors.nightText,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      error:
          (_, _) => _NowPlayingFullScaffold(
            child: Center(
              child: Text(
                i18n.t('nowPlaying.noActiveTrack'),
                style: const TextStyle(color: _NowPlayingFullColors.nightText),
              ),
            ),
          ),
      data: (snapshot) {
        final songsById = {for (final song in snapshot.songs) song.id: song};
        final queueSongs =
            snapshot.nowPlaying.songIds
                .map((songId) => songsById[songId])
                .whereType<LibrarySong>()
                .toList();
        final queueSongIds = queueSongs.map((song) => song.id).toList();
        final currentSong = _resolveCurrentSong(
          mediaControlState,
          queueSongs,
          songsById,
        );
        final customPlaylists = _customPlaylists(snapshot.playlists);

        return _NowPlayingFullScaffold(
          artworkPath: currentSong?.thumbnailPath,
          child: SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                    _NowPlayingFullTopBar(
                      i18n: i18n,
                      playlistOpen: _isPlaylistOpen,
                      onClose: () {
                        context.go('/now-playing');
                      },
                      onTogglePlaylist: () {
                        setState(() {
                          _isPlaylistOpen = !_isPlaylistOpen;
                        });
                      },
                    ),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: 48,
                          right: _isPlaylistOpen ? 430 : 48,
                          bottom: 20,
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final compact = constraints.maxWidth < 780;
                            return compact
                                ? _buildCompactStage(
                                  currentSong,
                                  mediaControlState,
                                  queueSongs,
                                  queueSongIds,
                                  customPlaylists,
                                  snapshot,
                                  i18n,
                                )
                                : _buildWideStage(
                                  currentSong,
                                  mediaControlState,
                                  queueSongs,
                                  queueSongIds,
                                  customPlaylists,
                                  snapshot,
                                  i18n,
                                );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                if (_isPlaylistOpen)
                  Positioned(
                    top: 76,
                    right: 28,
                    bottom: 26,
                    width: 390,
                    child: _NowPlayingFullPlaylist(
                      i18n: i18n,
                      songs: queueSongs,
                      songIds: queueSongIds,
                      mediaControlState: mediaControlState,
                      selection: _selection,
                      scrollController: _queueController,
                      playlists: customPlaylists,
                      folders: snapshot.folders,
                      onClose: () {
                        setState(() {
                          _isPlaylistOpen = false;
                        });
                      },
                      onReorder: _moveQueueSong,
                      onReplaceQueue: _replaceQueue,
                      onPlaySongs: _playSongIds,
                      onPlayTrack: _playQueueTrack,
                      onTogglePlayPause: () {
                        _togglePlayPauseFromQueue(queueSongs);
                      },
                      onPlayNext: _playNext,
                      onRemove: _removeQueueIndex,
                      onSelectionChanged: () {
                        setState(() {});
                      },
                      onAddToPlaylist: _addSongsToPlaylist,
                      onToggleFavorite: _toggleSongsFavorite,
                      onCreatePlaylist: _createPlaylist,
                      onAddToNowPlaying: (song) {
                        _addSongToNowPlaying(song, queueSongIds);
                      },
                      onGetPreferenceLevel: _getSongPreferenceLevel,
                      onUndoPreference: _undoSongPreference,
                      onSetPreference: _setSongPreference,
                      onDeleteSongFromDisk: _deleteSongFromDisk,
                      onHideSongFile:
                          (song) => _hideSongFile(song, queueSongIds),
                      onMoveSongToFolder: _moveSongToFolder,
                      onOpenSongDialog: _openMusicDialog,
                      onRevealSong: _revealPath,
                    ),
                  ),
                if ((currentSong != null || _dialogSong != null) &&
                    _dialogMode != null)
                  MusicDialog(
                    song: _dialogSong ?? currentSong!,
                    initialMode: _dialogMode!,
                    canPause:
                        mediaControlState.isPlaying &&
                        mediaControlState.track.id ==
                            (_dialogSong ?? currentSong!).id,
                    onPlay:
                        ref
                            .read(mediaControlControllerProvider)
                            .onTogglePlayPause,
                    onReveal: _revealPath,
                    onClose: () {
                      setState(() {
                        _dialogMode = null;
                      });
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWideStage(
    LibrarySong? currentSong,
    MediaControlState mediaControlState,
    List<LibrarySong> queueSongs,
    List<int> queueSongIds,
    List<MultiSelectCommandBarPlaylist> customPlaylists,
    LibraryViewData snapshot,
    SmPlayerI18n i18n,
  ) {
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              SizedBox(
                width: 340,
                child: _NowPlayingFullArtwork(song: currentSong),
              ),
              const SizedBox(width: 44),
              Expanded(
                child: _NowPlayingFullLyricsStage(
                  song: currentSong,
                  i18n: i18n,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 26),
        _NowPlayingFullControlPanel(
          song: currentSong,
          state: mediaControlState,
          disabled: queueSongs.isEmpty,
          i18n: i18n,
          onPrevious: () {
            _playPreviousFromQueue(queueSongs);
          },
          onNext: () {
            _playNextFromQueue(queueSongs);
          },
          onTogglePlayPause: () {
            _togglePlayPauseFromQueue(queueSongs);
          },
          onToggleShuffle: _toggleShufflePlayback,
          onMoreClick: (buttonContext) {
            unawaited(
              _showMoreMenu(
                buttonContext,
                currentSong,
                snapshot,
                queueSongIds,
                customPlaylists,
                isCompact: false,
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCompactStage(
    LibrarySong? currentSong,
    MediaControlState mediaControlState,
    List<LibrarySong> queueSongs,
    List<int> queueSongIds,
    List<MultiSelectCommandBarPlaylist> customPlaylists,
    LibraryViewData snapshot,
    SmPlayerI18n i18n,
  ) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              Center(
                child: SizedBox(
                  width: 280,
                  child: _NowPlayingFullArtwork(
                    song: currentSong,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                height: 240,
                child: _NowPlayingFullLyricsStage(
                  song: currentSong,
                  i18n: i18n,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _NowPlayingFullControlPanel(
          song: currentSong,
          state: mediaControlState,
          disabled: queueSongs.isEmpty,
          i18n: i18n,
          onPrevious: () {
            _playPreviousFromQueue(queueSongs);
          },
          onNext: () {
            _playNextFromQueue(queueSongs);
          },
          onTogglePlayPause: () {
            _togglePlayPauseFromQueue(queueSongs);
          },
          onToggleShuffle: _toggleShufflePlayback,
          onMoreClick: (buttonContext) {
            unawaited(
              _showMoreMenu(
                buttonContext,
                currentSong,
                snapshot,
                queueSongIds,
                customPlaylists,
                isCompact: true,
              ),
            );
          },
        ),
      ],
    );
  }

  LibrarySong? _resolveCurrentSong(
    MediaControlState mediaControlState,
    List<LibrarySong> queueSongs,
    Map<int, LibrarySong> songsById,
  ) {
    final queueIndex = mediaControlState.selectedQueueIndex;
    if (queueIndex != null &&
        queueIndex >= 0 &&
        queueIndex < queueSongs.length) {
      return queueSongs[queueIndex];
    }

    final trackId = mediaControlState.track.id;
    return trackId == null ? null : songsById[trackId];
  }

  List<MultiSelectCommandBarPlaylist> _customPlaylists(
    List<LibraryPlaylist> playlists,
  ) {
    return playlists
        .where((playlist) => !playlist.isBuiltIn)
        .map(
          (playlist) => MultiSelectCommandBarPlaylist(
            id: playlist.id,
            name: playlist.name,
            songIds: playlist.songIds,
          ),
        )
        .toList();
  }

  Future<void> _showMoreMenu(
    BuildContext buttonContext,
    LibrarySong? currentSong,
    LibraryViewData snapshot,
    List<int> queueSongIds,
    List<MultiSelectCommandBarPlaylist> customPlaylists, {
    required bool isCompact,
  }) async {
    final i18n = context.smPlayerI18n;
    final mediaController = ref.read(mediaControlControllerProvider);
    final preferenceLevel =
        currentSong == null
            ? null
            : await ref
                .read(libraryRepositoryProvider)
                .getPreferenceLevel('song', '${currentSong.id}');
    if (!mounted) {
      return;
    }
    if (!buttonContext.mounted) {
      return;
    }
    final songsById = {for (final song in snapshot.songs) song.id: song};
    final queueSongs =
        queueSongIds
            .map((songId) => songsById[songId])
            .whereType<LibrarySong>()
            .toList();
    final addToItem =
        currentSong == null
            ? null
            : buildAddToPlaylistMenuFlyoutItem(
              i18n: i18n,
              songIds: [currentSong.id],
              playlists: customPlaylists,
              includeNowPlaying: true,
              includeFavorites: !isCompact && !currentSong.favorite,
              onAddToNowPlaying: () {
                _replaceQueue([...queueSongIds, currentSong.id]);
              },
              onToggleFavorite: () {
                _toggleSongsFavorite([currentSong.id], true);
              },
              onCreatePlaylist: () {
                _createPlaylist(currentSong.title, [currentSong.id]);
              },
              onAddToPlaylist: (playlistId) {
                _addSongsToPlaylist(playlistId, [currentSong.id]);
              },
            );

    showMenuFlyout(
      buttonContext,
      avoidPlayerBar: false,
      items: [
        MenuFlyoutItem(
          key: 'quick-play',
          text: i18n.t('nowPlaying.quickPlay'),
          icon: FluentIcons.play_20_regular,
          onPressed: () {
            unawaited(_quickPlay(snapshot));
          },
        ),
        MenuFlyoutItem(
          key: 'random-play',
          text: i18n.t('nowPlaying.randomPlay'),
          icon: FluentIcons.arrow_shuffle_20_regular,
          disabled: queueSongIds.isEmpty && snapshot.songs.isEmpty,
          submenu: buildShuffleMenuFlyoutItems(
            i18n: i18n,
            songs: queueSongs,
            librarySongs: snapshot.songs,
            recentSongs: snapshot.recentSongs,
            playlists: snapshot.playlists,
            folders: snapshot.folders,
            randomLimit: nowPlayingQuickPlayLimit,
            onPlaySongs: _playSongIds,
            onQuickPlay: () => _quickPlay(snapshot),
          ),
        ),
        if (isCompact) ...[
          MenuFlyoutItem(
            key: 'playback-mode',
            text:
                '${i18n.t('player.playbackMode')}: ${_playbackModeName(i18n, mediaController.state.mode)}',
            icon: _playbackModeMenuIcon(mediaController.state.mode),
            submenu: [
              MenuFlyoutItem(
                key: 'playback-mode-list',
                text: i18n.t('player.playbackModeList'),
                icon: FluentIcons.music_note_2_20_regular,
                checked: mediaController.state.mode == PlaybackMode.once,
                onPressed: () {
                  _setPlaybackMode(PlaybackMode.once);
                },
              ),
              MenuFlyoutItem(
                key: 'playback-mode-shuffle',
                text: i18n.t('player.playbackModeShuffle'),
                icon: FluentIcons.arrow_shuffle_20_regular,
                checked: mediaController.state.mode == PlaybackMode.shuffle,
                onPressed: () {
                  _setPlaybackMode(PlaybackMode.shuffle);
                },
              ),
              MenuFlyoutItem(
                key: 'playback-mode-repeat',
                text: i18n.t('player.playbackModeRepeat'),
                icon: FluentIcons.arrow_repeat_all_20_regular,
                checked: mediaController.state.mode == PlaybackMode.repeat,
                onPressed: () {
                  _setPlaybackMode(PlaybackMode.repeat);
                },
              ),
              MenuFlyoutItem(
                key: 'playback-mode-repeat-one',
                text: i18n.t('player.playbackModeRepeatOne'),
                icon: FluentIcons.arrow_repeat_1_20_regular,
                checked: mediaController.state.mode == PlaybackMode.repeatOne,
                onPressed: () {
                  _setPlaybackMode(PlaybackMode.repeatOne);
                },
              ),
            ],
          ),
          MenuFlyoutItem(
            key: 'player-volume',
            text: i18n.t('player.volume'),
            icon: playerVolumeIcon(
              mediaController.state.volume,
              mediaController.state.isMuted,
            ),
            keepOpen: true,
            contentHeight: 42,
            content: PlayerVolumeMenuItem(
              label: i18n.t('player.volume'),
              muted: mediaController.state.isMuted,
              volumeValue: mediaController.state.volume,
              disabled: false,
              onToggleMute: mediaController.onToggleMute,
              onVolumeChange: mediaController.onVolumeChange,
            ),
          ),
          MenuFlyoutItem(
            key: 'player-favorite',
            text:
                currentSong?.favorite == true
                    ? i18n.t('player.unlike')
                    : i18n.t('player.like'),
            icon:
                currentSong?.favorite == true
                    ? FluentIcons.heart_20_filled
                    : FluentIcons.heart_20_regular,
            iconColor:
                currentSong?.favorite == true ? const Color(0xffd13438) : null,
            disabled: currentSong == null,
            onPressed:
                currentSong == null
                    ? null
                    : () {
                      _toggleSongsFavorite([
                        currentSong.id,
                      ], !currentSong.favorite);
                    },
          ),
        ],
        MenuFlyoutItem(
          key: 'save-playlist',
          text: i18n.t('nowPlaying.savePlaylist'),
          icon: FluentIcons.add_20_regular,
          onPressed: () {
            _createPlaylist(
              getDefaultNewPlaylistName(i18n, snapshot.playlists),
              queueSongIds,
            );
          },
        ),
        MenuFlyoutItem(
          key: 'clear-now-playing',
          text: i18n.t('nowPlaying.clearNowPlaying'),
          icon: FluentIcons.dismiss_20_regular,
          onPressed: () {
            context.go('/now-playing');
            _replaceQueue(const []);
          },
        ),
        if (currentSong != null) ...[
          if (addToItem != null) ...[
            const MenuFlyoutItem.separator(key: 'current-song-separator'),
            addToItem,
          ],
          buildPreferenceMenuFlyoutItem(
            i18n: i18n,
            key: 'preference',
            preferenceLevel: preferenceLevel,
            onUndoPreference:
                preferenceLevel == null
                    ? null
                    : () async {
                      await ref
                          .read(libraryRepositoryProvider)
                          .removePreferenceItem('song', '${currentSong.id}');
                      ref.invalidate(libraryViewDataProvider);
                    },
            onSetPreference: (level) {
              _setSongPreference(currentSong.id, currentSong.title, level);
            },
          ),
          MenuFlyoutItem(
            key: 'play-artist',
            text: i18n.t('detail.playArtist'),
            icon: FluentIcons.people_20_regular,
            onPressed: () {
              _playArtist(currentSong, snapshot.songs);
            },
          ),
          MenuFlyoutItem(
            key: 'play-album',
            text: i18n.t('detail.playAlbum'),
            icon: FluentIcons.album_20_regular,
            onPressed: () {
              _playAlbum(currentSong, snapshot.songs);
            },
          ),
          MenuFlyoutItem(
            key: 'view',
            text: i18n.t('context.view'),
            icon: FluentIcons.eye_20_regular,
            submenu: [
              MenuFlyoutItem(
                key: 'see-music-info',
                text: i18n.t('context.seeMusicInfo'),
                icon: FluentIcons.info_20_regular,
                keepOpen: true,
                onPressed: () {
                  _openMusicDialog(SongDialogMode.properties);
                },
              ),
              MenuFlyoutItem(
                key: 'see-lyrics',
                text: i18n.t('context.seeLyrics'),
                icon: FluentIcons.text_quote_20_regular,
                keepOpen: true,
                onPressed: () {
                  _openMusicDialog(SongDialogMode.lyrics);
                },
              ),
              MenuFlyoutItem(
                key: 'see-album-art',
                text: i18n.t('context.seeAlbumArt'),
                icon: FluentIcons.image_20_regular,
                keepOpen: true,
                onPressed: () {
                  _openMusicDialog(SongDialogMode.albumArt);
                },
              ),
            ],
          ),
        ],
      ],
    );
  }

  void _setPlaybackMode(PlaybackMode targetMode) {
    final mediaController = ref.read(mediaControlControllerProvider);
    final mode = mediaController.state.mode;
    if (mode == targetMode) {
      return;
    }

    switch (targetMode) {
      case PlaybackMode.shuffle:
        _toggleShufflePlayback();
      case PlaybackMode.repeat:
        mediaController.onToggleRepeat();
      case PlaybackMode.repeatOne:
        mediaController.onToggleRepeatOne();
      case PlaybackMode.once:
        switch (mode) {
          case PlaybackMode.shuffle:
            mediaController.onToggleShuffle();
          case PlaybackMode.repeat:
            mediaController.onToggleRepeat();
          case PlaybackMode.repeatOne:
            mediaController.onToggleRepeatOne();
          case PlaybackMode.once:
            break;
        }
    }
  }

  void _toggleShufflePlayback() {
    final mediaController = ref.read(mediaControlControllerProvider);
    final enablingShuffle = mediaController.state.mode != PlaybackMode.shuffle;
    if (enablingShuffle) {
      final snapshot = ref.read(libraryViewDataProvider).valueOrNull;
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
        mediaController.setSelectedQueueIndex(
          nextQueueIndex > -1 ? nextQueueIndex : null,
        );
      }
    }
    mediaController.onToggleShuffle();
  }

  String _playbackModeName(SmPlayerI18n i18n, PlaybackMode mode) {
    return switch (mode) {
      PlaybackMode.shuffle => i18n.t('player.playbackModeShuffle'),
      PlaybackMode.repeat => i18n.t('player.playbackModeRepeat'),
      PlaybackMode.repeatOne => i18n.t('player.playbackModeRepeatOne'),
      PlaybackMode.once => i18n.t('player.playbackModeList'),
    };
  }

  IconData _playbackModeMenuIcon(PlaybackMode mode) {
    return switch (mode) {
      PlaybackMode.shuffle => FluentIcons.arrow_shuffle_20_regular,
      PlaybackMode.repeat => FluentIcons.arrow_repeat_all_20_regular,
      PlaybackMode.repeatOne => FluentIcons.arrow_repeat_1_20_regular,
      PlaybackMode.once => FluentIcons.music_note_2_20_regular,
    };
  }

  void _playQueueTrack(
    LibrarySong song,
    List<int> queueSongIds,
    int queueIndex,
  ) {
    ref
        .read(mediaControlControllerProvider)
        .playTrack(
          MediaControlTrack(
            id: song.id,
            title: song.title,
            artist: song.artist,
            artworkUrl: song.thumbnailPath,
            isLoading: false,
            favorite: song.favorite,
          ),
          durationSeconds: song.duration.toDouble(),
          queueIndex: queueIndex,
        );
    _replaceQueue(queueSongIds);
  }

  void _playSongIds(List<int> songIds) {
    if (songIds.isEmpty) {
      return;
    }

    final songs = ref.read(libraryViewDataProvider).value!.songs;
    final songsById = {for (final song in songs) song.id: song};
    final firstSong = songsById[songIds.first]!;
    ref
        .read(mediaControlControllerProvider)
        .playTrack(
          MediaControlTrack(
            id: firstSong.id,
            title: firstSong.title,
            artist: firstSong.artist,
            artworkUrl: firstSong.thumbnailPath,
            isLoading: false,
            favorite: firstSong.favorite,
          ),
          durationSeconds: firstSong.duration.toDouble(),
          queueIndex: 0,
        );
    _replaceQueue(songIds);
  }

  Future<void> _quickPlay(LibraryViewData snapshot) async {
    final preferences =
        await ref.read(libraryRepositoryProvider).getPreferenceSettings();
    _playSongIds(
      quickPlaySongIds(
        songs: snapshot.songs,
        playlists: snapshot.playlists,
        folders: snapshot.folders,
        preferences: preferences,
        randomLimit: nowPlayingQuickPlayLimit,
      ),
    );
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

  bool _playPreviousFromQueue(List<LibrarySong> queueSongs) {
    if (queueSongs.isEmpty) {
      return false;
    }
    final controller = ref.read(mediaControlControllerProvider);
    if (shouldRestartCurrentTrackForPrevious(
      progressSeconds: controller.state.progressSeconds,
      queueLength: queueSongs.length,
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

  void _playAlbum(LibrarySong currentSong, List<LibrarySong> songs) {
    final songIds =
        songs
            .where((song) => song.album == currentSong.album)
            .map((song) => song.id)
            .toList();
    ref.read(libraryRepositoryProvider).recordAlbumPlayed(currentSong.album);
    _playSongIds(songIds);
    ref.invalidate(libraryViewDataProvider);
  }

  void _playArtist(LibrarySong currentSong, List<LibrarySong> songs) {
    final artist = currentSong.artist;
    final songIds =
        songs
            .where(
              (song) =>
                  song.artist == artist ||
                  (song.artists.isNotEmpty && song.artists.contains(artist)),
            )
            .map((song) => song.id)
            .toList();
    ref.read(libraryRepositoryProvider).recordArtistPlayed(artist);
    _playSongIds(songIds);
    ref.invalidate(libraryViewDataProvider);
  }

  void _replaceQueue(List<int> songIds) {
    ref.read(libraryRepositoryProvider).replaceNowPlaying(songIds);
    ref.invalidate(libraryViewDataProvider);
  }

  void _moveQueueSong(List<int> queueSongIds, int oldIndex, int newIndex) {
    final nextSongIds = queueSongIds.toList();
    final songId = nextSongIds.removeAt(oldIndex);
    nextSongIds.insert(newIndex, songId);
    _replaceQueue(nextSongIds);
  }

  void _removeQueueIndex(List<int> queueSongIds, int queueIndex) {
    _replaceQueue([
      for (var index = 0; index < queueSongIds.length; index += 1)
        if (index != queueIndex) queueSongIds[index],
    ]);
  }

  void _playNext(List<int> queueSongIds, int queueIndex) {
    final nextSongIds = queueSongIds.toList();
    final songId = nextSongIds.removeAt(queueIndex);
    final selectedQueueIndex =
        ref.read(mediaControlControllerProvider).state.selectedQueueIndex;
    nextSongIds.insert(
      selectedQueueIndex == null ? 0 : selectedQueueIndex + 1,
      songId,
    );
    _replaceQueue(nextSongIds);
  }

  Future<void> _createPlaylist(String name, List<int> songIds) async {
    await ref.read(libraryRepositoryProvider).createPlaylist(name, songIds);
    ref.invalidate(libraryViewDataProvider);
  }

  Future<void> _addSongsToPlaylist(int playlistId, List<int> songIds) async {
    await ref
        .read(libraryRepositoryProvider)
        .addSongsToPlaylist(playlistId, songIds);
    ref.invalidate(libraryViewDataProvider);
  }

  Future<void> _toggleSongsFavorite(List<int> songIds, bool favorite) async {
    await ref
        .read(libraryRepositoryProvider)
        .setSongsFavorite(songIds, favorite);
    final mediaController = ref.read(mediaControlControllerProvider);
    if (songIds.contains(mediaController.state.track.id) &&
        mediaController.state.track.favorite != favorite) {
      mediaController.onToggleFavorite();
    }
    ref.invalidate(libraryViewDataProvider);
  }

  void _addSongToNowPlaying(LibrarySong song, List<int> queueSongIds) {
    final before = queueSongIds.toList();
    _replaceQueue([...queueSongIds, song.id]);
    _showUndo(
      context.smPlayerI18n.t('notification.songAddedTo', {
        'title': song.title,
        'target': context.smPlayerI18n.t('common.nowPlaying'),
      }),
      () => _replaceQueue(before),
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
    ref.invalidate(libraryViewDataProvider);
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
    ref.invalidate(libraryViewDataProvider);
  }

  Future<void> _deleteSongFromDisk(LibrarySong song) async {
    await requestDeleteSongFromDisk(
      context: context,
      ref: ref,
      i18n: context.smPlayerI18n,
      song: song,
    );
  }

  Future<void> _hideSongFile(LibrarySong song, List<int> queueSongIds) async {
    final removedEntries = _queueEntriesForSong(queueSongIds, song.id);
    await ref.read(libraryRepositoryProvider).hideSong(song.id);
    ref.invalidate(libraryViewDataProvider);
    _replaceQueue([
      for (final songId in queueSongIds)
        if (songId != song.id) songId,
    ]);
    if (!mounted) {
      return;
    }
    _showUndo(
      context.smPlayerI18n.t('notification.hiddenStorageItem', {
        'name': song.title,
      }),
      () async {
        await ref.read(libraryRepositoryProvider).unhideSong(song.id);
        ref.invalidate(libraryViewDataProvider);
        final snapshot =
            await ref.read(libraryRepositoryProvider).getLibraryViewData();
        _replaceQueue(
          _insertQueueEntries(snapshot.nowPlaying.songIds, removedEntries),
        );
      },
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

  void _openMusicDialog(SongDialogMode mode, [LibrarySong? song]) {
    setState(() {
      _isPlaylistOpen = false;
      _dialogSong = song;
      _dialogMode = mode;
    });
  }

  void _showUndo(String message, FutureOr<void> Function() action) {
    showUndoableSnackBar(
      context: context,
      i18n: context.smPlayerI18n,
      message: message,
      onUndo: action,
    );
  }

  Future<void> _revealPath(String targetPath) async {
    await revealItemInFolder(targetPath);
  }
}

class _NowPlayingFullScaffold extends StatelessWidget {
  const _NowPlayingFullScaffold({
    required this.child,
    this.artworkPath,
  });

  final String? artworkPath;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final artworkFile =
        artworkPath == null || artworkPath!.isEmpty ? null : File(artworkPath!);
    final colors = NowPlayingFullThemeColors.of(context);

    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors.backgroundGradient,
            ),
          ),
        ),
        if (artworkFile != null && artworkFile.existsSync())
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 34, sigmaY: 34),
            child: Opacity(
              opacity: colors.artworkBackdropOpacity,
              child: Image.file(artworkFile, fit: BoxFit.cover),
            ),
          ),
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: ColoredBox(
            color: colors.veil,
            child: child,
          ),
        ),
      ],
    );
  }
}

class _NowPlayingFullTopBar extends StatelessWidget {
  const _NowPlayingFullTopBar({
    required this.i18n,
    required this.playlistOpen,
    required this.onClose,
    required this.onTogglePlaylist,
  });

  final SmPlayerI18n i18n;
  final bool playlistOpen;
  final VoidCallback onClose;
  final VoidCallback onTogglePlaylist;

  @override
  Widget build(BuildContext context) {
    final color = NowPlayingFullThemeColors.of(context).text;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
      child: Row(
        children: [
          IconButton(
            tooltip: i18n.t('nowPlaying.exitImmersiveMode'),
            color: color,
            icon: const Icon(FluentIcons.chevron_down_24_regular),
            onPressed: onClose,
          ),
          const Spacer(),
          IconButton(
            tooltip: i18n.t('nowPlaying.playlist'),
            color:
                playlistOpen
                    ? _NowPlayingFullColors.accent
                    : color.withValues(alpha: 0.88),
            icon: const Icon(FluentIcons.list_24_regular),
            onPressed: onTogglePlaylist,
          ),
        ],
      ),
    );
  }
}

class _NowPlayingFullArtwork extends StatelessWidget {
  const _NowPlayingFullArtwork({required this.song});

  final LibrarySong? song;

  @override
  Widget build(BuildContext context) {
    final artworkFile =
        song == null || song!.thumbnailPath.isEmpty
            ? null
            : File(song!.thumbnailPath);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha:
                        NowPlayingFullThemeColors.of(
                          context,
                        ).artworkShadowOpacity,
                  ),
                  blurRadius: 42,
                  offset: const Offset(0, 24),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child:
                  artworkFile != null && artworkFile.existsSync()
                      ? Image.file(artworkFile, fit: BoxFit.cover)
                      : const DecoratedBox(
                        decoration: BoxDecoration(
                          color: _NowPlayingFullColors.artworkFallback,
                        ),
                        child: Icon(
                          FluentIcons.music_note_2_24_regular,
                          color: _NowPlayingFullColors.artworkIcon,
                          size: 78,
                        ),
                      ),
            ),
          ),
        ),
        const SizedBox(height: 28),
        Text(
          song?.title ?? context.smPlayerI18n.t('nowPlaying.noActiveTrack'),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color:
                NowPlayingFullThemeColors.of(context).text,
            fontSize: 24,
            fontWeight: FontWeight.w600,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          song == null ? '' : '${song!.artist}  |  ${song!.album}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color:
                NowPlayingFullThemeColors.of(context).muted,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _NowPlayingFullLyricsStage extends StatelessWidget {
  const _NowPlayingFullLyricsStage({
    required this.song,
    required this.i18n,
  });

  final LibrarySong? song;
  final SmPlayerI18n i18n;

  @override
  Widget build(BuildContext context) {
    final title =
        song == null
            ? i18n.t('nowPlaying.noActiveTrack')
            : i18n.t('nowPlaying.noLyrics');
    final copy =
        song == null
            ? i18n.t('nowPlaying.noActiveTrackCopy')
            : i18n.t('nowPlaying.lyricsCopy');

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color:
                  NowPlayingFullThemeColors.of(context).text,
              fontSize: 32,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Text(
              copy,
              textAlign: TextAlign.center,
              style: TextStyle(
                color:
                    NowPlayingFullThemeColors.of(context).muted,
                fontSize: 15,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NowPlayingFullControlPanel extends ConsumerWidget {
  const _NowPlayingFullControlPanel({
    required this.song,
    required this.state,
    required this.disabled,
    required this.i18n,
    required this.onPrevious,
    required this.onNext,
    required this.onTogglePlayPause,
    required this.onToggleShuffle,
    required this.onMoreClick,
  });

  final LibrarySong? song;
  final MediaControlState state;
  final bool disabled;
  final SmPlayerI18n i18n;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onTogglePlayPause;
  final VoidCallback onToggleShuffle;
  final ValueChanged<BuildContext> onMoreClick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(mediaControlControllerProvider);
    final colors = NowPlayingFullThemeColors.of(context);
    return Container(
      constraints: const BoxConstraints(maxWidth: 720),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 18),
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: MediaControlSurface(
              trackId: state.track.id,
              isLoading: state.track.isLoading,
              favorite: song?.favorite ?? state.track.favorite,
              disabled: disabled,
              isPlaying: state.isPlaying,
              volume: state.volume,
              isMuted: state.isMuted,
              mode: state.mode,
              progressSeconds: state.progressSeconds,
              durationSeconds: state.durationSeconds,
              onTogglePlayPause: onTogglePlayPause,
              onPrevious: onPrevious,
              onNext: onNext,
              onSeek: controller.onSeek,
              onBeginSeek: controller.onBeginSeek,
              onEndSeek: controller.onEndSeek,
              onVolumeChange: controller.onVolumeChange,
              onToggleMute: controller.onToggleMute,
              onToggleShuffle: onToggleShuffle,
              onToggleRepeat: controller.onToggleRepeat,
              onToggleRepeatOne: controller.onToggleRepeatOne,
              onToggleFavorite: controller.onToggleFavorite,
              onMoreClick: () {
                onMoreClick(context);
              },
            ),
          ),
          Builder(
            builder: (context) {
              return IconButton(
                tooltip: i18n.t('player.more'),
                color: colors.text,
                icon: const Icon(FluentIcons.more_horizontal_24_regular),
                onPressed: () {
                  onMoreClick(context);
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _NowPlayingFullPlaylist extends StatelessWidget {
  const _NowPlayingFullPlaylist({
    required this.i18n,
    required this.songs,
    required this.songIds,
    required this.mediaControlState,
    required this.selection,
    required this.scrollController,
    required this.playlists,
    required this.folders,
    required this.onClose,
    required this.onReorder,
    required this.onReplaceQueue,
    required this.onPlaySongs,
    required this.onPlayTrack,
    required this.onTogglePlayPause,
    required this.onPlayNext,
    required this.onRemove,
    required this.onSelectionChanged,
    required this.onAddToPlaylist,
    required this.onToggleFavorite,
    required this.onCreatePlaylist,
    required this.onAddToNowPlaying,
    required this.onGetPreferenceLevel,
    required this.onUndoPreference,
    required this.onSetPreference,
    required this.onDeleteSongFromDisk,
    required this.onHideSongFile,
    required this.onMoveSongToFolder,
    required this.onOpenSongDialog,
    required this.onRevealSong,
  });

  final SmPlayerI18n i18n;
  final List<LibrarySong> songs;
  final List<int> songIds;
  final MediaControlState mediaControlState;
  final PageSelectionController<int> selection;
  final ScrollController scrollController;
  final List<MultiSelectCommandBarPlaylist> playlists;
  final List<LibraryFolder> folders;
  final VoidCallback onClose;
  final void Function(List<int>, int, int) onReorder;
  final ValueChanged<List<int>> onReplaceQueue;
  final ValueChanged<List<int>> onPlaySongs;
  final void Function(LibrarySong, List<int>, int) onPlayTrack;
  final VoidCallback onTogglePlayPause;
  final void Function(List<int>, int) onPlayNext;
  final void Function(List<int>, int) onRemove;
  final VoidCallback onSelectionChanged;
  final Future<void> Function(int, List<int>) onAddToPlaylist;
  final Future<void> Function(List<int>, bool) onToggleFavorite;
  final Future<void> Function(String, List<int>) onCreatePlaylist;
  final ValueChanged<LibrarySong> onAddToNowPlaying;
  final Future<String?> Function(int) onGetPreferenceLevel;
  final Future<void> Function(int) onUndoPreference;
  final Future<void> Function(int, String, String) onSetPreference;
  final Future<void> Function(LibrarySong) onDeleteSongFromDisk;
  final Future<void> Function(LibrarySong) onHideSongFile;
  final Future<void> Function(LibrarySong, String) onMoveSongToFolder;
  final void Function(SongDialogMode, LibrarySong) onOpenSongDialog;
  final ValueChanged<String> onRevealSong;

  @override
  Widget build(BuildContext context) {
    final colors = NowPlayingFullThemeColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2e000000),
            blurRadius: 34,
            offset: Offset(0, 20),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 12, 8),
                  child: Row(
                    children: [
                      Text(
                        i18n.t('nowPlaying.playlist'),
                        style: TextStyle(
                          color: colors.text,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: i18n.t('common.close'),
                        icon: const Icon(FluentIcons.dismiss_20_regular),
                        onPressed: onClose,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child:
                      songs.isEmpty
                          ? _QueueEmptyState(i18n: i18n)
                          : ReorderableListView.builder(
                            scrollController: scrollController,
                            padding: EdgeInsets.fromLTRB(
                              8,
                              0,
                              8,
                              selection.multiSelect
                                  ? multiSelectCommandBarScrollSpacer
                                  : 18,
                            ),
                            buildDefaultDragHandles: false,
                            itemCount: songs.length,
                            onReorderItem: (oldIndex, newIndex) {
                              onReorder(songIds, oldIndex, newIndex);
                            },
                            itemBuilder: (context, index) {
                              final song = songs[index];
                              final current =
                                  mediaControlState.selectedQueueIndex == null
                                      ? song.id == mediaControlState.track.id
                                      : index ==
                                          mediaControlState.selectedQueueIndex;
                              return ReorderableDragStartListener(
                                key: ValueKey(
                                  'now-playing-full-${song.id}-$index',
                                ),
                                index: index,
                                child: PlaylistControlItem(
                                  song: song,
                                  current: current,
                                  playing:
                                      current && mediaControlState.isPlaying,
                                  selected: selection.isSelected(index),
                                  selectionMode: selection.multiSelect,
                                  playNextLabel: i18n.t('context.playNext'),
                                  removeLabel: i18n.t('nowPlaying.remove'),
                                  onPlayTrack: () {
                                    onPlayTrack(song, songIds, index);
                                  },
                                  onTogglePlayPause: onTogglePlayPause,
                                  onToggleSelection: () {
                                    selection.toggle(index);
                                    onSelectionChanged();
                                  },
                                  onPlayNextClick: () {
                                    onPlayNext(songIds, index);
                                  },
                                  onRemoveFromListClick: () {
                                    onRemove(songIds, index);
                                  },
                                  onOpenContextMenu: (position) {
                                    _showQueueContextMenu(
                                      context,
                                      position,
                                      song,
                                      index,
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                ),
              ],
            ),
            MultiSelectCommandBar(
              visible: selection.multiSelect,
              selectedCount: selection.selectedItems.length,
              playlists: playlists,
              removeLabel: i18n.t('nowPlaying.remove'),
              onAddToPlaylist: (playlistId) {
                onAddToPlaylist(playlistId, _selectedSongIds());
                selection.hideAfterOperation(true);
                onSelectionChanged();
              },
              onPlay: () {
                onPlaySongs(_selectedSongIds());
                selection.hideAfterOperation(true);
                onSelectionChanged();
              },
              onRemove: () {
                final selectedIndexes = selection.selectedItems;
                final nextSongIds = [
                  for (var index = 0; index < songIds.length; index += 1)
                    if (!selectedIndexes.contains(index)) songIds[index],
                ];
                onReplaceQueue(nextSongIds);
                selection.hideAfterOperation(true);
                onSelectionChanged();
              },
              onSelectAll: () {
                selection.selectAll(
                  List.generate(songIds.length, (index) => index),
                );
                onSelectionChanged();
              },
              onReverseSelection: () {
                selection.reverseSelection(
                  List.generate(songIds.length, (index) => index),
                );
                onSelectionChanged();
              },
              onClearSelection: () {
                selection.clearSelection();
                onSelectionChanged();
              },
              onCancel: () {
                selection.cancel();
                onSelectionChanged();
              },
            ),
          ],
        ),
      ),
    );
  }

  List<int> _selectedSongIds() {
    return [
      for (final index in selection.selectedItems)
        if (index >= 0 && index < songIds.length) songIds[index],
    ];
  }

  Future<void> _showQueueContextMenu(
    BuildContext context,
    Offset position,
    LibrarySong song,
    int queueIndex,
  ) async {
    void showMessage(String message) {
      showAppNotification(context: context, message: message);
    }

    final currentTrackId = mediaControlState.track.id;
    final preferenceLevel = await onGetPreferenceLevel(song.id);
    if (!context.mounted) {
      return;
    }
    final menuFolders =
        folders
            .map(
              (folder) => MenuFlyoutFolder(
                id: folder.id,
                name: _displayFolderName(folder.path),
                path: folder.path,
                parentId: folder.parentId,
              ),
            )
            .toList();
    showMenuFlyout(
      context,
      position: position,
      avoidPlayerBar: false,
      items: buildMusicMenuFlyoutItems(
        i18n: i18n,
        songId: song.id,
        isFavorite: song.favorite,
        isCurrentTrack: song.id == currentTrackId,
        isPlaying: mediaControlState.isPlaying,
        currentTrackId: currentTrackId,
        currentPlaylistName: i18n.t('common.nowPlaying'),
        songPath: song.path,
        playlists: playlists,
        folders: menuFolders,
        showRemove: true,
        showAlbumArt: false,
        preferenceLevel: preferenceLevel,
        onUndoPreference:
            preferenceLevel == null
                ? null
                : () {
                  onUndoPreference(song.id);
                },
        onPlay: () {
          onPlayTrack(song, songIds, queueIndex);
        },
        onPause: onTogglePlayPause,
        onPlayNext: () {
          onPlayNext(songIds, queueIndex);
        },
        onAddToNowPlaying: () {
          onAddToNowPlaying(song);
        },
        onCreatePlaylist: () {
          onCreatePlaylist(song.title, [song.id]);
        },
        onAddToPlaylist: (playlistId) {
          onAddToPlaylist(playlistId, [song.id]);
        },
        onRemove: () {
          onRemove(songIds, queueIndex);
        },
        onSelect: () {
          selection.enterMultiSelect();
          if (!selection.isSelected(queueIndex)) {
            selection.toggle(queueIndex);
          }
          onSelectionChanged();
        },
        onToggleFavorite: () {
          onToggleFavorite([song.id], true);
        },
        onSetPreference: (level) {
          onSetPreference(song.id, song.title, level);
        },
        onDelete: () {
          onDeleteSongFromDisk(song);
        },
        onHide: () {
          onHideSongFile(song);
        },
        onMoveToFolder: (folderPath) {
          onMoveSongToFolder(song, folderPath);
        },
        onSeeArtist: () {
          showMessage(i18n.t('context.seeArtist'));
        },
        onSeeAlbum: () {
          showMessage(i18n.t('context.seeAlbum'));
        },
        onSeeMusicInfo: () {
          onOpenSongDialog(SongDialogMode.properties, song);
        },
        onSeeLyrics: () {
          onOpenSongDialog(SongDialogMode.lyrics, song);
        },
        onSeeAlbumArt: () {
          onOpenSongDialog(SongDialogMode.albumArt, song);
        },
        onSeeLocal: () {
          onRevealSong(song.path);
        },
      ),
    );
  }
}

String _displayFolderName(String path) {
  final normalized = path.replaceAll('\\', '/');
  final index = normalized.lastIndexOf('/');
  return index >= 0 ? normalized.substring(index + 1) : normalized;
}

List<({int index, int songId})> _queueEntriesForSong(
  List<int> queueSongIds,
  int songId,
) {
  return [
    for (var index = 0; index < queueSongIds.length; index += 1)
      if (queueSongIds[index] == songId) (index: index, songId: songId),
  ];
}

List<int> _insertQueueEntries(
  List<int> queueSongIds,
  List<({int index, int songId})> entries,
) {
  var nextQueueSongIds = queueSongIds.toList();
  for (final entry in entries) {
    final index =
        entry.index < 0
            ? 0
            : entry.index > nextQueueSongIds.length
            ? nextQueueSongIds.length
            : entry.index;
    nextQueueSongIds = [
      ...nextQueueSongIds.take(index),
      entry.songId,
      ...nextQueueSongIds.skip(index),
    ];
  }
  return nextQueueSongIds;
}

class _QueueEmptyState extends StatelessWidget {
  const _QueueEmptyState({required SmPlayerI18n i18n});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

class _NowPlayingFullColors {
  const _NowPlayingFullColors._();

  static const accent = Color(0xff4aa8ff);
  static const dayTop = Color(0xffedf4fb);
  static const dayBottom = Color(0xfff9fbfd);
  static const dayVeil = Color(0xbff8fbff);
  static const dayPanel = Color(0xd9ffffff);
  static const dayBorder = Color(0x3d8aa0b8);
  static const dayText = Color(0xff101828);
  static const dayMuted = Color(0xff667085);
  static const nightTop = Color(0xff111827);
  static const nightBottom = Color(0xff020617);
  static const nightVeil = Color(0xaa020617);
  static const nightPanel = Color(0x5c0f172a);
  static const nightBorder = Color(0x3dffffff);
  static const nightText = Color(0xfff8fafc);
  static const nightMuted = Color(0xffcbd5e1);
  static const artworkFallback = Color(0xffd6e2ef);
  static const artworkIcon = Color(0xff71839a);
}

class NowPlayingFullThemeColors
    extends ThemeExtension<NowPlayingFullThemeColors> {
  const NowPlayingFullThemeColors({
    required this.backgroundGradient,
    required this.veil,
    required this.panel,
    required this.border,
    required this.text,
    required this.muted,
    required this.artworkBackdropOpacity,
    required this.artworkShadowOpacity,
  });

  final List<Color> backgroundGradient;
  final Color veil;
  final Color panel;
  final Color border;
  final Color text;
  final Color muted;
  final double artworkBackdropOpacity;
  final double artworkShadowOpacity;

  static const light = NowPlayingFullThemeColors(
    backgroundGradient: [
      _NowPlayingFullColors.dayTop,
      _NowPlayingFullColors.dayBottom,
    ],
    veil: _NowPlayingFullColors.dayVeil,
    panel: _NowPlayingFullColors.dayPanel,
    border: _NowPlayingFullColors.dayBorder,
    text: _NowPlayingFullColors.dayText,
    muted: _NowPlayingFullColors.dayMuted,
    artworkBackdropOpacity: 0.22,
    artworkShadowOpacity: 0.18,
  );

  static const dark = NowPlayingFullThemeColors(
    backgroundGradient: [
      _NowPlayingFullColors.nightTop,
      _NowPlayingFullColors.nightBottom,
    ],
    veil: _NowPlayingFullColors.nightVeil,
    panel: _NowPlayingFullColors.nightPanel,
    border: _NowPlayingFullColors.nightBorder,
    text: _NowPlayingFullColors.nightText,
    muted: _NowPlayingFullColors.nightMuted,
    artworkBackdropOpacity: 0.28,
    artworkShadowOpacity: 0.38,
  );

  static NowPlayingFullThemeColors of(BuildContext context) {
    return Theme.of(context).extension<NowPlayingFullThemeColors>() ?? light;
  }

  @override
  NowPlayingFullThemeColors copyWith() {
    return this;
  }

  @override
  NowPlayingFullThemeColors lerp(
    covariant ThemeExtension<NowPlayingFullThemeColors>? other,
    double t,
  ) {
    return this;
  }
}
