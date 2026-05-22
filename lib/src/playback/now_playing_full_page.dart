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
import 'package:smplayer_flutter/src/library/ui/command_bar.dart';
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
import 'package:smplayer_flutter/src/settings/settings_controller.dart';
import 'package:smplayer_flutter/src/settings/settings_model.dart';

class NowPlayingFullPage extends ConsumerStatefulWidget {
  const NowPlayingFullPage({super.key});

  @override
  ConsumerState<NowPlayingFullPage> createState() => _NowPlayingFullPageState();
}

class _NowPlayingFullPageState extends ConsumerState<NowPlayingFullPage> {
  final _selection = PageSelectionController<int>.stored('now-playing-full');
  final _queueController = ScrollController();
  late final SettingsController _settingsController;
  var _isPlaylistOpen = false;
  var _settings = const SettingsSnapshot.defaults();
  LibrarySong? _dialogSong;
  SongDialogMode? _dialogMode;

  @override
  void initState() {
    super.initState();
    _settingsController = SettingsController(
      null,
      ref.read(libraryRepositoryProvider),
    );
    _restoreSettings();
  }

  @override
  void dispose() {
    _queueController.dispose();
    _settingsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snapshotValue = ref.watch(musicLibrarySnapshotProvider);
    final mediaControlState = ref.watch(mediaControlControllerProvider).state;
    final i18n = context.smPlayerI18n;

    return snapshotValue.when(
      loading:
          () => _NowPlayingFullScaffold(
            night: isNowPlayingFullNightMode(_settings),
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
            night: isNowPlayingFullNightMode(_settings),
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
        final night = isNowPlayingFullNightMode(_settings);
        final customPlaylists = _customPlaylists(snapshot.playlists);

        return _NowPlayingFullScaffold(
          night: night,
          artworkPath: currentSong?.thumbnailPath,
          child: SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                    _NowPlayingFullTopBar(
                      i18n: i18n,
                      night: night,
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
                                  night,
                                  i18n,
                                )
                                : _buildWideStage(
                                  currentSong,
                                  mediaControlState,
                                  queueSongs,
                                  queueSongIds,
                                  customPlaylists,
                                  snapshot,
                                  night,
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
                      night: night,
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
    MusicLibrarySnapshot snapshot,
    bool night,
    SmPlayerI18n i18n,
  ) {
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              SizedBox(
                width: 340,
                child: _NowPlayingFullArtwork(song: currentSong, night: night),
              ),
              const SizedBox(width: 44),
              Expanded(
                child: _NowPlayingFullLyricsStage(
                  song: currentSong,
                  night: night,
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
          night: night,
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
          onMoreClick: () {
            _showMoreMenu(currentSong, snapshot, queueSongIds, customPlaylists);
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
    MusicLibrarySnapshot snapshot,
    bool night,
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
                    night: night,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                height: 240,
                child: _NowPlayingFullLyricsStage(
                  song: currentSong,
                  night: night,
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
          night: night,
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
          onMoreClick: () {
            _showMoreMenu(currentSong, snapshot, queueSongIds, customPlaylists);
          },
        ),
      ],
    );
  }

  Future<void> _restoreSettings() async {
    await _settingsController.refresh();
    if (!mounted) {
      return;
    }

    setState(() {
      _settings = _settingsController.snapshot;
    });
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

  void _showMoreMenu(
    LibrarySong? currentSong,
    MusicLibrarySnapshot snapshot,
    List<int> queueSongIds,
    List<MultiSelectCommandBarPlaylist> customPlaylists,
  ) {
    final i18n = context.smPlayerI18n;
    final mediaController = ref.read(mediaControlControllerProvider);
    final addToItem =
        currentSong == null
            ? null
            : buildAddToPlaylistMenuFlyoutItem(
              i18n: i18n,
              songIds: [currentSong.id],
              playlists: customPlaylists,
              includeNowPlaying: true,
              includeFavorites: !currentSong.favorite,
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
      context,
      items: [
        MenuFlyoutItem(
          key: 'quick-play',
          text: i18n.t('nowPlaying.quickPlay'),
          icon: FluentIcons.play_20_regular,
          disabled: snapshot.songs.isEmpty,
          onPressed: () {
            unawaited(_quickPlay(snapshot));
          },
        ),
        MenuFlyoutItem(
          key: 'random-play',
          text: i18n.t('nowPlaying.randomPlay'),
          icon: FluentIcons.arrow_shuffle_20_regular,
          disabled: snapshot.songs.isEmpty,
          onPressed: () {
            final shuffled = snapshot.songs.toList()..shuffle();
            _playSongIds(
              shuffled
                  .take(nowPlayingQuickPlayLimit)
                  .map((song) => song.id)
                  .toList(),
            );
          },
        ),
        MenuFlyoutItem(
          key: 'playback-mode',
          text:
              '${i18n.t('player.playbackMode')}: ${_playbackModeName(i18n, mediaController.state.mode)}',
          icon: FluentIcons.music_note_2_20_regular,
          submenu: [
            MenuFlyoutItem(
              key: 'playback-mode-list',
              text: i18n.t('player.playbackModeList'),
              icon: FluentIcons.apps_list_detail_20_regular,
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
          key: 'player-favorite',
          text:
              currentSong?.favorite == true
                  ? i18n.t('player.unlike')
                  : i18n.t('player.like'),
          icon:
              currentSong?.favorite == true
                  ? FluentIcons.heart_20_filled
                  : FluentIcons.heart_20_regular,
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
        const MenuFlyoutItem.separator(key: 'queue-separator'),
        MenuFlyoutItem(
          key: 'save-playlist',
          text: i18n.t('nowPlaying.savePlaylist'),
          icon: FluentIcons.add_20_regular,
          disabled: queueSongIds.isEmpty,
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
          disabled: queueSongIds.isEmpty,
          onPressed: () {
            _replaceQueue(const []);
          },
        ),
        if (addToItem != null) ...[
          const MenuFlyoutItem.separator(key: 'song-separator'),
          addToItem,
          MenuFlyoutItem(
            key: 'play-artist',
            text: i18n.t('detail.playArtist'),
            icon: FluentIcons.people_20_regular,
            onPressed: () {
              _playArtist(currentSong!, snapshot.songs);
            },
          ),
          MenuFlyoutItem(
            key: 'play-album',
            text: i18n.t('detail.playAlbum'),
            icon: FluentIcons.album_20_regular,
            onPressed: () {
              _playAlbum(currentSong!, snapshot.songs);
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
                onPressed: () {
                  _openMusicDialog(SongDialogMode.properties);
                },
              ),
              MenuFlyoutItem(
                key: 'see-lyrics',
                text: i18n.t('context.seeLyrics'),
                icon: FluentIcons.text_quote_20_regular,
                onPressed: () {
                  _openMusicDialog(SongDialogMode.lyrics);
                },
              ),
              MenuFlyoutItem(
                key: 'see-album-art',
                text: i18n.t('context.seeAlbumArt'),
                icon: FluentIcons.image_20_regular,
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
      final snapshot = ref.read(musicLibrarySnapshotProvider).valueOrNull;
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

    final songs = ref.read(musicLibrarySnapshotProvider).value!.songs;
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

  Future<void> _quickPlay(MusicLibrarySnapshot snapshot) async {
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
    ref.invalidate(musicLibrarySnapshotProvider);
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
    ref.invalidate(musicLibrarySnapshotProvider);
  }

  void _replaceQueue(List<int> songIds) {
    ref.read(libraryRepositoryProvider).replaceNowPlaying(songIds);
    ref.invalidate(musicLibrarySnapshotProvider);
  }

  void _moveQueueSong(List<int> queueSongIds, int oldIndex, int newIndex) {
    final nextSongIds = queueSongIds.toList();
    final insertIndex = newIndex > oldIndex ? newIndex - 1 : newIndex;
    final songId = nextSongIds.removeAt(oldIndex);
    nextSongIds.insert(insertIndex, songId);
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
    ref.invalidate(musicLibrarySnapshotProvider);
  }

  Future<void> _addSongsToPlaylist(int playlistId, List<int> songIds) async {
    await ref
        .read(libraryRepositoryProvider)
        .addSongsToPlaylist(playlistId, songIds);
    ref.invalidate(musicLibrarySnapshotProvider);
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
    ref.invalidate(musicLibrarySnapshotProvider);
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
    ref.invalidate(musicLibrarySnapshotProvider);
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
    ref.invalidate(musicLibrarySnapshotProvider);
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
        ref.invalidate(musicLibrarySnapshotProvider);
        final snapshot =
            await ref.read(libraryRepositoryProvider).getMusicLibrarySnapshot();
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
    required this.night,
    required this.child,
    this.artworkPath,
  });

  final bool night;
  final String? artworkPath;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final artworkFile =
        artworkPath == null || artworkPath!.isEmpty ? null : File(artworkPath!);

    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors:
                  night
                      ? const [
                        _NowPlayingFullColors.nightTop,
                        _NowPlayingFullColors.nightBottom,
                      ]
                      : const [
                        _NowPlayingFullColors.dayTop,
                        _NowPlayingFullColors.dayBottom,
                      ],
            ),
          ),
        ),
        if (artworkFile != null && artworkFile.existsSync())
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 34, sigmaY: 34),
            child: Opacity(
              opacity: night ? 0.28 : 0.22,
              child: Image.file(artworkFile, fit: BoxFit.cover),
            ),
          ),
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: ColoredBox(
            color:
                night
                    ? _NowPlayingFullColors.nightVeil
                    : _NowPlayingFullColors.dayVeil,
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
    required this.night,
    required this.playlistOpen,
    required this.onClose,
    required this.onTogglePlaylist,
  });

  final SmPlayerI18n i18n;
  final bool night;
  final bool playlistOpen;
  final VoidCallback onClose;
  final VoidCallback onTogglePlaylist;

  @override
  Widget build(BuildContext context) {
    final color =
        night ? _NowPlayingFullColors.nightText : _NowPlayingFullColors.dayText;
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
  const _NowPlayingFullArtwork({required this.song, required this.night});

  final LibrarySong? song;
  final bool night;

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
                  color: Colors.black.withValues(alpha: night ? 0.38 : 0.18),
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
                night
                    ? _NowPlayingFullColors.nightText
                    : _NowPlayingFullColors.dayText,
            fontSize: 24,
            fontWeight: FontWeight.w800,
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
                night
                    ? _NowPlayingFullColors.nightMuted
                    : _NowPlayingFullColors.dayMuted,
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
    required this.night,
    required this.i18n,
  });

  final LibrarySong? song;
  final bool night;
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
                  night
                      ? _NowPlayingFullColors.nightText
                      : _NowPlayingFullColors.dayText,
              fontSize: 32,
              fontWeight: FontWeight.w800,
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
                    night
                        ? _NowPlayingFullColors.nightMuted
                        : _NowPlayingFullColors.dayMuted,
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
    required this.night,
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
  final bool night;
  final SmPlayerI18n i18n;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onTogglePlayPause;
  final VoidCallback onToggleShuffle;
  final VoidCallback onMoreClick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(mediaControlControllerProvider);
    return Container(
      constraints: const BoxConstraints(maxWidth: 720),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 18),
      decoration: BoxDecoration(
        color:
            night
                ? _NowPlayingFullColors.nightPanel
                : _NowPlayingFullColors.dayPanel,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color:
              night
                  ? _NowPlayingFullColors.nightBorder
                  : _NowPlayingFullColors.dayBorder,
        ),
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
              onMoreClick: onMoreClick,
            ),
          ),
          Builder(
            builder: (context) {
              return IconButton(
                tooltip: i18n.t('player.more'),
                color:
                    night
                        ? _NowPlayingFullColors.nightText
                        : _NowPlayingFullColors.dayText,
                icon: const Icon(FluentIcons.more_horizontal_24_regular),
                onPressed: onMoreClick,
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
    required this.night,
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
    required this.onSetPreference,
    required this.onDeleteSongFromDisk,
    required this.onHideSongFile,
    required this.onMoveSongToFolder,
    required this.onOpenSongDialog,
    required this.onRevealSong,
  });

  final SmPlayerI18n i18n;
  final bool night;
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
  final Future<void> Function(int, String, String) onSetPreference;
  final Future<void> Function(LibrarySong) onDeleteSongFromDisk;
  final Future<void> Function(LibrarySong) onHideSongFile;
  final Future<void> Function(LibrarySong, String) onMoveSongToFolder;
  final void Function(SongDialogMode, LibrarySong) onOpenSongDialog;
  final ValueChanged<String> onRevealSong;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color:
            night
                ? _NowPlayingFullColors.nightPanel
                : _NowPlayingFullColors.dayPanel,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color:
              night
                  ? _NowPlayingFullColors.nightBorder
                  : _NowPlayingFullColors.dayBorder,
        ),
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
                          color:
                              night
                                  ? _NowPlayingFullColors.nightText
                                  : _NowPlayingFullColors.dayText,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
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
                          ? _QueueEmptyState(i18n: i18n, night: night)
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
                            onReorder: (oldIndex, newIndex) {
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

  void _showQueueContextMenu(
    BuildContext context,
    Offset position,
    LibrarySong song,
    int queueIndex,
  ) {
    void showMessage(String message) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }

    final currentTrackId = mediaControlState.track.id;
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
  const _QueueEmptyState({required this.i18n, required this.night});

  final SmPlayerI18n i18n;
  final bool night;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Text(
          '${i18n.t('nowPlaying.queueEmpty')}\n${i18n.t('nowPlaying.queueEmptyHelp')}',
          textAlign: TextAlign.center,
          style: TextStyle(
            color:
                night
                    ? _NowPlayingFullColors.nightMuted
                    : _NowPlayingFullColors.dayMuted,
            height: 1.5,
          ),
        ),
      ),
    );
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
