import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smplayer_flutter/src/app/undoable_notification.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
import 'package:smplayer_flutter/src/library/ui/default_album_artwork.dart';
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
import 'package:smplayer_flutter/src/playback/media_control_track_factory.dart';
import 'package:smplayer_flutter/src/playback/now_playing_full_model.dart';
import 'package:smplayer_flutter/src/playback/playlist_control_item.dart';
import 'package:smplayer_flutter/src/playback/quick_play_model.dart';
import 'package:smplayer_flutter/src/settings/settings_controller.dart';
import 'package:smplayer_flutter/src/settings/settings_model.dart'
    show NightMode;

class NowPlayingFullPage extends ConsumerStatefulWidget {
  const NowPlayingFullPage({super.key});

  @override
  ConsumerState<NowPlayingFullPage> createState() => _NowPlayingFullPageState();
}

class _NowPlayingFullPageState extends ConsumerState<NowPlayingFullPage> {
  final _selection = PageSelectionController<int>.stored('now-playing-full');
  final _queueController = ScrollController();
  var _isPlaylistOpen = false;
  var _isPlayerBarRaised = true;
  Timer? _playerBarHideTimer;
  LibrarySong? _dialogSong;
  SongDialogMode? _dialogMode;

  @override
  void dispose() {
    _playerBarHideTimer?.cancel();
    _queueController.dispose();
    super.dispose();
  }

  void _raisePlayerBar() {
    _playerBarHideTimer?.cancel();
    if (!_isPlayerBarRaised) {
      setState(() {
        _isPlayerBarRaised = true;
      });
    }
  }

  void _schedulePlayerBarHide() {
    _playerBarHideTimer?.cancel();
    _playerBarHideTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted || _isPlaylistOpen || _dialogMode != null) {
        return;
      }
      setState(() {
        _isPlayerBarRaised = false;
      });
    });
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
        final settings = smPlayerGlobalSettingsSnapshot;
        final immersiveNightActive =
            settings.nightMode == NightMode.onMode ||
            (settings.nightMode == NightMode.auto &&
                isMinuteInNightRange(
                  getCurrentClockMinute(),
                  timeToMinute(settings.nightModeStartTime),
                  timeToMinute(settings.nightModeEndTime),
                ));

        return _NowPlayingFullScaffold(
          artworkPath: currentSong?.thumbnailPath,
          night: immersiveNightActive,
          child: MouseRegion(
            onEnter: (_) {
              _raisePlayerBar();
            },
            onHover: (_) {
              _raisePlayerBar();
              _schedulePlayerBarHide();
            },
            onExit: (_) {
              _schedulePlayerBarHide();
            },
            child: Stack(
              children: [
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(76, 82, 76, 128),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final compact = MediaQuery.sizeOf(context).width <= 800;
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
                if (_isPlaylistOpen)
                  Positioned(
                    top: 56,
                    right: 24,
                    bottom: 132,
                    width: min(MediaQuery.sizeOf(context).width * 0.4, 520),
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
                Positioned(
                  right: 76,
                  bottom: 24,
                  left: 76,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    opacity: _isPlayerBarRaised ? 1 : 0.24,
                    child: AnimatedSlide(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                      offset:
                          _isPlayerBarRaised
                              ? Offset.zero
                              : const Offset(0, 0.82),
                      child: _NowPlayingFullControlPanel(
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
                              isCompact:
                                  MediaQuery.sizeOf(context).width <= 800,
                            ),
                          );
                        },
                      ),
                    ),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final pageWidth = MediaQuery.sizeOf(context).width;
        final artworkSize = clampDouble(pageWidth * 0.28, 220, 416);
        final stageHeight = artworkSize + 132;
        final gap = clampDouble(pageWidth * 0.05, 40, 72);
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          child: Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.center,
                  child: Transform.translate(
                    offset: const Offset(0, -10),
                    child: SizedBox(
                      height: stageHeight,
                      child: Center(
                        child: SizedBox(
                          width: artworkSize,
                          child: _NowPlayingFullArtwork(
                            song: currentSong,
                            artworkSize: artworkSize,
                            compact: false,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: gap),
              Expanded(
                child: Align(
                  alignment: Alignment.center,
                  child: SizedBox(
                    height: stageHeight,
                    child: _NowPlayingFullLyricsStage(
                      song: currentSong,
                      progressSeconds: mediaControlState.progressSeconds,
                      durationSeconds: mediaControlState.durationSeconds,
                      isPlaying: mediaControlState.isPlaying,
                      i18n: i18n,
                      onSeek: ref.read(mediaControlControllerProvider).onSeek,
                      onTogglePlayPause:
                          ref
                              .read(mediaControlControllerProvider)
                              .onTogglePlayPause,
                      compact: false,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
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
    final pageWidth = MediaQuery.sizeOf(context).width;
    final artworkSize = min(pageWidth * 0.58, 250.0);
    final lyricStageHeight = min(
      MediaQuery.sizeOf(context).height * 0.44,
      320.0,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      child: Column(
        children: [
          SizedBox(
            width: artworkSize,
            child: _NowPlayingFullArtwork(
              song: currentSong,
              artworkSize: artworkSize,
              compact: true,
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            height: lyricStageHeight,
            child: _NowPlayingFullLyricsStage(
              song: currentSong,
              progressSeconds: mediaControlState.progressSeconds,
              durationSeconds: mediaControlState.durationSeconds,
              isPlaying: mediaControlState.isPlaying,
              i18n: i18n,
              onSeek: ref.read(mediaControlControllerProvider).onSeek,
              onTogglePlayPause:
                  ref.read(mediaControlControllerProvider).onTogglePlayPause,
              compact: true,
            ),
          ),
        ],
      ),
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
              defaultPlaylistName: currentSong.title,
              onAddToNowPlaying: () {
                _replaceQueue([...queueSongIds, currentSong.id]);
              },
              onToggleFavorite: () {
                _toggleSongsFavorite([currentSong.id], true);
              },
              onCreatePlaylistWithName: (name) {
                _createPlaylist(name, [currentSong.id]);
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
          onPressedWithContext: (menuContext) async {
            final name = await requestPlaylistName(
              context: menuContext,
              i18n: i18n,
              playlists: snapshot.playlists,
              defaultName: getDefaultNewPlaylistName(i18n, snapshot.playlists),
            );
            if (name != null) {
              await _createPlaylist(name, queueSongIds);
            }
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
          mediaControlTrackForSong(song, context.smPlayerI18n),
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
          mediaControlTrackForSong(firstSong, context.smPlayerI18n),
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
    final targetAlbum =
        currentSong.album.isEmpty
            ? context.smPlayerI18n.t('common.albumUnknown')
            : currentSong.album;
    final songIds =
        songs
            .where(
              (song) =>
                  _displayAlbum(song, context.smPlayerI18n) == targetAlbum,
            )
            .map((song) => song.id)
            .toList();
    ref.read(libraryRepositoryProvider).recordAlbumPlayed(currentSong.album);
    _playSongIds(songIds);
    ref.invalidate(libraryViewDataProvider);
  }

  void _playArtist(LibrarySong currentSong, List<LibrarySong> songs) {
    final targetArtists =
        currentSong.artists.isEmpty
            ? [currentSong.artist]
            : currentSong.artists;
    final songIds =
        songs
            .where((song) {
              final artists =
                  song.artists.isEmpty ? [song.artist] : song.artists;
              return artists.any(targetArtists.contains);
            })
            .map((song) => song.id)
            .toList();
    ref.read(libraryRepositoryProvider).recordArtistPlayed(targetArtists.first);
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
    this.night = false,
  });

  final String? artworkPath;
  final bool night;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final artworkFile =
        artworkPath == null || artworkPath!.isEmpty ? null : File(artworkPath!);
    final colors = NowPlayingFullThemeColors.of(context, night: night);

    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: colors.pageBackground),
        Positioned.fill(
          top: -40,
          right: -40,
          bottom: -40,
          left: -40,
          child: Transform.scale(
            scale: 1.08,
            child:
                artworkFile != null && artworkFile.existsSync()
                    ? ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 34, sigmaY: 34),
                      child: Opacity(
                        opacity: colors.artworkBackdropOpacity,
                        child: Image.file(artworkFile, fit: BoxFit.cover),
                      ),
                    )
                    : DecoratedBox(decoration: colors.fallbackBackdrop),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: colors.backdropOverlay),
          ),
        ),
        child,
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
    final colors = NowPlayingFullThemeColors.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = MediaQuery.sizeOf(context).width <= 760;
        return SizedBox(
          height: compact ? 92 : 118,
          child: Stack(
            children: [
              if (compact)
                Positioned(
                  top: 42,
                  left: 24,
                  child: IconButton(
                    tooltip: i18n.t('sidebar.back'),
                    color: colors.text,
                    icon: const Icon(FluentIcons.arrow_left_24_regular),
                    onPressed: onClose,
                  ),
                ),
              Positioned(
                top: compact ? 42 : 62,
                right: compact ? 24 : 76,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    foregroundColor:
                        playlistOpen
                            ? _NowPlayingFullColors.accent
                            : colors.text,
                    backgroundColor: colors.panel,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: colors.border),
                    ),
                  ),
                  icon: const Icon(
                    FluentIcons.music_note_2_20_regular,
                    size: 18,
                  ),
                  label: Text(
                    i18n.t('common.nowPlaying'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  onPressed: onTogglePlaylist,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

String _displayArtists(LibrarySong song, SmPlayerI18n i18n) {
  if (song.artists.isNotEmpty) {
    return song.artists.join(', ');
  }
  return song.artist.isEmpty ? i18n.t('common.artistUnknown') : song.artist;
}

String _displayAlbum(LibrarySong song, SmPlayerI18n i18n) {
  return song.album.isEmpty ? i18n.t('common.albumUnknown') : song.album;
}

String _formatLyricSeekTime(double seconds) {
  final duration = Duration(seconds: seconds.round());
  final minutes = duration.inMinutes.remainder(60).toString();
  final remainingSeconds = duration.inSeconds
      .remainder(60)
      .toString()
      .padLeft(2, '0');
  if (duration.inHours > 0) {
    return '${duration.inHours}:$minutes:$remainingSeconds';
  }
  return '$minutes:$remainingSeconds';
}

class _ImmersiveLyricsLine {
  const _ImmersiveLyricsLine({
    required this.id,
    required this.text,
    required this.seekSeconds,
    required this.active,
  });

  final int id;
  final String text;
  final double seekSeconds;
  final bool active;
}

List<_ImmersiveLyricsLine> _getImmersiveLyricsLines({
  required LyricsSnapshot? lyrics,
  required double progressSeconds,
  required double durationSeconds,
}) {
  final snapshot = lyrics;
  if (snapshot == null || snapshot.lines.isEmpty) {
    return const [];
  }

  if (snapshot.isSynced) {
    final progressMs = (progressSeconds * 1000).round();
    final lines =
        snapshot.lines.where((line) => line.text.trim().isNotEmpty).toList();
    if (lines.isEmpty) {
      return const [];
    }
    var activeIndex = 0;
    for (var index = 0; index < lines.length; index += 1) {
      final timestamp = lines[index].timestampMs;
      if (timestamp == null || timestamp > progressMs) {
        break;
      }
      activeIndex = index;
    }
    return [
      for (var index = 0; index < lines.length; index += 1)
        _ImmersiveLyricsLine(
          id: lines[index].id,
          text: lines[index].text.trim(),
          seekSeconds: max(0, (lines[index].timestampMs ?? 0) / 1000),
          active: index == activeIndex,
        ),
    ];
  }

  final lines =
      snapshot.lines.where((line) => line.text.trim().isNotEmpty).toList();
  if (lines.isEmpty) {
    return const [];
  }
  final duration = durationSeconds <= 0 ? 1.0 : durationSeconds;
  final activeIndex = min(
    lines.length - 1,
    (lines.length * (progressSeconds / duration).clamp(0, 1)).floor(),
  );
  return [
    for (var index = 0; index < lines.length; index += 1)
      _ImmersiveLyricsLine(
        id: lines[index].id,
        text: lines[index].text.trim(),
        seekSeconds: duration * (index / max(1, lines.length - 1)),
        active: index == activeIndex,
      ),
  ];
}

class _NowPlayingFullArtwork extends StatelessWidget {
  const _NowPlayingFullArtwork({
    required this.song,
    required this.artworkSize,
    required this.compact,
  });

  final LibrarySong? song;
  final double artworkSize;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final artworkFile =
        song == null || song!.thumbnailPath.isEmpty
            ? null
            : File(song!.thumbnailPath);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox.square(
          dimension: artworkSize,
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
                      : const DefaultAlbumArtwork(logoOpacity: 0.9),
            ),
          ),
        ),
        const SizedBox(height: 28),
        Text(
          song?.title ?? context.smPlayerI18n.t('nowPlaying.noActiveTrack'),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.start,
          style: TextStyle(
            color: NowPlayingFullThemeColors.of(context).text,
            fontSize:
                compact
                    ? 24
                    : clampDouble(
                      MediaQuery.sizeOf(context).width * 0.0215,
                      24.8,
                      40,
                    ),
            fontWeight: FontWeight.w700,
            height: 1.16,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          song == null ? '' : _displayArtists(song!, context.smPlayerI18n),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.start,
          style: TextStyle(
            color: NowPlayingFullThemeColors.of(context).muted,
            fontSize: 18,
            fontWeight: FontWeight.w500,
            height: 1.28,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          song == null ? '' : _displayAlbum(song!, context.smPlayerI18n),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.start,
          style: TextStyle(
            color: NowPlayingFullThemeColors.of(context).subtle,
            fontSize: 18,
            fontWeight: FontWeight.w500,
            height: 1.28,
          ),
        ),
      ],
    );
  }
}

class _NowPlayingFullLyricsStage extends ConsumerStatefulWidget {
  const _NowPlayingFullLyricsStage({
    required this.song,
    required this.progressSeconds,
    required this.durationSeconds,
    required this.isPlaying,
    required this.i18n,
    required this.onSeek,
    required this.onTogglePlayPause,
    required this.compact,
  });

  final LibrarySong? song;
  final double progressSeconds;
  final double durationSeconds;
  final bool isPlaying;
  final SmPlayerI18n i18n;
  final ValueChanged<double> onSeek;
  final VoidCallback onTogglePlayPause;
  final bool compact;

  @override
  ConsumerState<_NowPlayingFullLyricsStage> createState() =>
      _NowPlayingFullLyricsStageState();
}

class _NowPlayingFullLyricsStageState
    extends ConsumerState<_NowPlayingFullLyricsStage> {
  final _scrollController = ScrollController();
  final _lineKeys = <int, GlobalKey>{};
  LyricsSnapshot? _lyrics;
  int? _lyricsSongId;
  var _loading = false;
  var _previewing = false;
  int? _previewIndex;
  Timer? _restoreTimer;

  @override
  void initState() {
    super.initState();
    _loadLyrics();
  }

  @override
  void didUpdateWidget(covariant _NowPlayingFullLyricsStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.song?.id != widget.song?.id) {
      _loadLyrics();
    }
    final lines = _displayLines();
    final activeIndex = lines.indexWhere((line) => line.active);
    if (!_previewing && activeIndex >= 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToIndex(activeIndex);
      });
    }
  }

  @override
  void dispose() {
    _restoreTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadLyrics() async {
    final song = widget.song;
    if (song == null) {
      setState(() {
        _lyricsSongId = null;
        _lyrics = null;
        _loading = false;
      });
      return;
    }

    setState(() {
      _lyricsSongId = song.id;
      _lyrics = null;
      _loading = true;
      _previewing = false;
      _previewIndex = null;
    });
    final lyrics = await ref
        .read(libraryRepositoryProvider)
        .getSongLyrics(song.id);
    if (!mounted || _lyricsSongId != song.id) {
      return;
    }
    setState(() {
      _lyrics = lyrics;
      _loading = false;
    });
  }

  List<_ImmersiveLyricsLine> _displayLines() {
    final song = widget.song;
    final adjustedProgressSeconds = max(
      0.0,
      widget.progressSeconds + (song?.lyricsOffsetMs ?? 0) / 1000,
    );
    final effectiveDuration =
        widget.durationSeconds > 0
            ? widget.durationSeconds
            : song?.duration.toDouble() ?? 0;
    return _getImmersiveLyricsLines(
      lyrics: _lyrics,
      progressSeconds: adjustedProgressSeconds,
      durationSeconds: effectiveDuration,
    );
  }

  void _scrollToIndex(int index) {
    final lineContext = _lineKeys[index]?.currentContext;
    if (lineContext == null) {
      return;
    }
    Scrollable.ensureVisible(
      lineContext,
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
      alignment: 0.5,
    );
  }

  void _previewFromScroll() {
    final lines = _displayLines();
    if (lines.isEmpty || !_scrollController.hasClients) {
      return;
    }
    setState(() {
      _previewing = true;
      _previewIndex = _nearestLineIndex(lines);
    });
    _restoreTimer?.cancel();
    _restoreTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _previewing = false;
        _previewIndex = null;
      });
      final activeIndex = _displayLines().indexWhere((line) => line.active);
      if (activeIndex >= 0) {
        _scrollToIndex(activeIndex);
      }
    });
  }

  int _nearestLineIndex(List<_ImmersiveLyricsLine> lines) {
    var nearestIndex = 0;
    var nearestDistance = double.infinity;
    final viewportHeight = _scrollController.position.viewportDimension;
    final centerOffset = _scrollController.offset + viewportHeight / 2;
    final scrollableBox = context.findRenderObject() as RenderBox;
    final scrollableTop = scrollableBox.localToGlobal(Offset.zero).dy;
    for (var index = 0; index < lines.length; index += 1) {
      final lineBox = _lineKeys[index]?.currentContext?.findRenderObject();
      if (lineBox is! RenderBox) {
        continue;
      }
      final localTop =
          lineBox.localToGlobal(Offset.zero).dy -
          scrollableTop +
          _scrollController.offset;
      final center = localTop + lineBox.size.height / 2;
      final distance = (center - centerOffset).abs();
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestIndex = index;
      }
    }
    return nearestIndex;
  }

  void _seekToLine(_ImmersiveLyricsLine line) {
    _restoreTimer?.cancel();
    widget.onSeek(line.seekSeconds);
    if (!widget.isPlaying) {
      widget.onTogglePlayPause();
    }
    setState(() {
      _previewing = false;
      _previewIndex = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = NowPlayingFullThemeColors.of(context);
    final lines = _displayLines();
    if (widget.song == null || (_loading && lines.isEmpty) || lines.isEmpty) {
      final text =
          widget.song == null
              ? widget.i18n.t('nowPlaying.noActiveTrack')
              : _loading
              ? widget.i18n.t('nowPlaying.loadingLyrics')
              : widget.i18n.t('nowPlaying.noLyrics');

      return Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: colors.muted.withValues(alpha: 0.52),
            fontSize: 20,
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
        ),
      );
    }

    final previewIndex = _previewing ? _previewIndex : null;
    final previewLine =
        previewIndex == null
            ? null
            : lines[min(previewIndex, lines.length - 1)];
    return Stack(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            return NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is ScrollUpdateNotification &&
                    notification.dragDetails != null) {
                  _previewFromScroll();
                }
                return false;
              },
              child: ShaderMask(
                shaderCallback:
                    (rect) => const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black,
                        Colors.black,
                        Colors.transparent,
                      ],
                      stops: [0, 0.17, 0.83, 1],
                    ).createShader(rect),
                blendMode: BlendMode.dstIn,
                child: ListView.separated(
                  controller: _scrollController,
                  padding: EdgeInsets.symmetric(
                    vertical: constraints.maxHeight / 2,
                    horizontal: 20,
                  ),
                  itemCount: lines.length,
                  separatorBuilder:
                      (_, _) => SizedBox(height: widget.compact ? 10 : 18),
                  itemBuilder: (context, index) {
                    final line = lines[index];
                    _lineKeys[index] = _lineKeys[index] ?? GlobalKey();
                    final active = line.active && !_previewing;
                    final preview = index == previewIndex;
                    return ConstrainedBox(
                      key: _lineKeys[index],
                      constraints: BoxConstraints(
                        minHeight: widget.compact ? 0 : 54,
                      ),
                      child: Center(
                        child: GestureDetector(
                          onTap: () {
                            _seekToLine(line);
                          },
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOutCubic,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color:
                                  active || preview
                                      ? colors.text
                                      : colors.muted.withValues(alpha: 0.52),
                              fontSize:
                                  active || preview
                                      ? (widget.compact ? 22 : 26.56)
                                      : (widget.compact ? 18 : 19.84),
                              fontWeight:
                                  active || preview
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                              height: 1.35,
                            ),
                            child: Text(line.text, textAlign: TextAlign.center),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
        if (previewLine != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 34),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                foregroundColor: colors.text,
                backgroundColor: colors.panel,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                  side: BorderSide(color: colors.border),
                ),
              ),
              onPressed: () {
                _seekToLine(previewLine);
              },
              icon: const Icon(FluentIcons.play_16_regular, size: 18),
              label: Text(
                _formatLyricSeekTime(previewLine.seekSeconds),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
      ],
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth <= 520;
        final sideWidth = compact ? 68.0 : 80.0;
        return Container(
          padding: EdgeInsets.fromLTRB(
            compact ? 10 : 18,
            compact ? 10 : 14,
            compact ? 10 : 18,
            compact ? 12 : 16,
          ),
          decoration: BoxDecoration(
            color: colors.panel,
            borderRadius: BorderRadius.circular(0),
            border: Border.all(color: colors.border),
            boxShadow: [
              BoxShadow(
                color:
                    colors.artworkShadowOpacity > 0.3
                        ? const Color(0x66000000)
                        : const Color(0x24685870),
                blurRadius: colors.artworkShadowOpacity > 0.3 ? 72 : 56,
                offset: const Offset(0, -18),
              ),
            ],
          ),
          child: Row(
            children: [
              SizedBox(
                width: sideWidth,
                child: IconButton(
                  tooltip: i18n.t('nowPlaying.exitImmersiveMode'),
                  color: colors.text,
                  icon: const Icon(FluentIcons.arrow_minimize_24_regular),
                  iconSize: compact ? 30 : 36,
                  onPressed: () {
                    GoRouter.of(context).go('/now-playing');
                  },
                ),
              ),
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
                  condensed: compact,
                  onMoreClick: () {
                    onMoreClick(context);
                  },
                ),
              ),
              SizedBox(width: sideWidth),
            ],
          ),
        );
      },
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
                  padding: const EdgeInsets.fromLTRB(30, 26, 20, 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              i18n.t('common.nowPlaying'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.text,
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              i18n.t('playlists.songCount', {
                                'count': songs.length,
                              }),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.muted,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
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
                                  onToggleFavoriteClick: () {
                                    onToggleFavorite([song.id], !song.favorite);
                                  },
                                  onAddToPlaylistClick: (buttonContext) {
                                    _showAddToPlaylistMenu(buttonContext, song);
                                  },
                                  onSeeAlbum: () {
                                    context.go(
                                      '/albums?album=${Uri.encodeComponent(_displayAlbum(song, i18n))}',
                                    );
                                    onClose();
                                  },
                                  onSeeArtist: (artist) {
                                    context.go(
                                      '/artists?artist=${Uri.encodeComponent(artist)}',
                                    );
                                    onClose();
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

  Future<void> _showAddToPlaylistMenu(
    BuildContext buttonContext,
    LibrarySong song,
  ) async {
    final item = buildAddToPlaylistMenuFlyoutItem(
      i18n: i18n,
      songIds: [song.id],
      playlists: playlists,
      currentPlaylistName: i18n.t('common.nowPlaying'),
      includeFavorites: !song.favorite,
      onToggleFavorite: () {
        onToggleFavorite([song.id], true);
      },
      onCreatePlaylist: () {
        onCreatePlaylist(_nextPlaylistName(song.title), [song.id]);
      },
      onAddToPlaylist: (playlistId) {
        onAddToPlaylist(playlistId, [song.id]);
      },
    );
    if (item == null) {
      return;
    }
    await showMenuFlyout(
      buttonContext,
      avoidPlayerBar: false,
      items: item.submenu,
    );
  }

  String _nextPlaylistName(String name) {
    final playlistNames = playlists.map((playlist) => playlist.name).toSet();
    final siblingCount =
        playlists.where((playlist) => playlist.name.startsWith(name)).length;
    for (var index = 1; index <= siblingCount; index += 1) {
      final nextName = '$name ($index)';
      if (!playlistNames.contains(nextName)) {
        return nextName;
      }
    }
    return name;
  }

  Future<void> _showQueueContextMenu(
    BuildContext context,
    Offset position,
    LibrarySong song,
    int queueIndex,
  ) async {
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
          context.go(
            '/artists?artist=${Uri.encodeComponent(_displayArtists(song, i18n).split(', ').first)}',
          );
          onClose();
        },
        onSeeAlbum: () {
          context.go(
            '/albums?album=${Uri.encodeComponent(_displayAlbum(song, i18n))}',
          );
          onClose();
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
  static const dayText = Color(0xff101828);
  static const dayMuted = Color(0xff667085);
  static const nightText = Color(0xfff8fafc);
  static const nightMuted = Color(0xffcbd5e1);
}

class NowPlayingFullThemeColors
    extends ThemeExtension<NowPlayingFullThemeColors> {
  const NowPlayingFullThemeColors({
    required this.pageBackground,
    required this.fallbackBackdrop,
    required this.backdropOverlay,
    required this.panel,
    required this.border,
    required this.text,
    required this.muted,
    required this.subtle,
    required this.artworkBackdropOpacity,
    required this.artworkShadowOpacity,
  });

  final Color pageBackground;
  final Decoration fallbackBackdrop;
  final Gradient backdropOverlay;
  final Color panel;
  final Color border;
  final Color text;
  final Color muted;
  final Color subtle;
  final double artworkBackdropOpacity;
  final double artworkShadowOpacity;

  static const light = NowPlayingFullThemeColors(
    pageBackground: Color(0xfaf6f9fc),
    fallbackBackdrop: BoxDecoration(
      gradient: RadialGradient(
        center: Alignment(-0.6, -0.56),
        radius: 0.78,
        colors: [Color(0x7aabd9ff), Colors.transparent],
      ),
    ),
    backdropOverlay: LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [Color(0xd1f6f9fc), Color(0x75f6f9fc), Color(0xd1f6f9fc)],
      stops: [0, 0.56, 1],
    ),
    panel: Color(0xc7ffffff),
    border: Color(0xb8ccd5e0),
    text: _NowPlayingFullColors.dayText,
    muted: _NowPlayingFullColors.dayMuted,
    subtle: Color(0x945b697a),
    artworkBackdropOpacity: 0.92,
    artworkShadowOpacity: 0.22,
  );

  static const dark = NowPlayingFullThemeColors(
    pageBackground: Color(0xff07111f),
    fallbackBackdrop: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x3d140f0c), Color(0xc7100c08)],
      ),
    ),
    backdropOverlay: LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [Color(0xd6120e0a), Color(0x9419120c), Color(0xd10d0a08)],
      stops: [0, 0.52, 1],
    ),
    panel: Color(0xe612100e),
    border: Color(0x2effffff),
    text: _NowPlayingFullColors.nightText,
    muted: _NowPlayingFullColors.nightMuted,
    subtle: Color(0xb8ffffff),
    artworkBackdropOpacity: 1,
    artworkShadowOpacity: 0.38,
  );

  static NowPlayingFullThemeColors of(BuildContext context, {bool? night}) {
    if (night != null) {
      return night ? dark : light;
    }
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
