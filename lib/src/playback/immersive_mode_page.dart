import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smplayer_flutter/src/app/shell_actions.dart';
import 'package:smplayer_flutter/src/app/undoable_notification.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
import 'package:smplayer_flutter/src/library/ui/artists_page_model.dart'
    as artists_model;
import 'package:smplayer_flutter/src/library/ui/menu_flyout_helpers.dart';
import 'package:smplayer_flutter/src/library/ui/library_page_actions.dart';
import 'package:smplayer_flutter/src/library/ui/music_dialog.dart';
import 'package:smplayer_flutter/src/library/ui/page_selection_store.dart';
import 'package:smplayer_flutter/src/library/ui/song_display_helpers.dart'
    as song_display;
import 'package:smplayer_flutter/src/platform/desktop_feature_service.dart';
import 'package:smplayer_flutter/src/playback/media_control.dart';
import 'package:smplayer_flutter/src/playback/media_control_model.dart';
import 'package:smplayer_flutter/src/playback/media_control_provider.dart';
import 'package:smplayer_flutter/src/playback/media_control_track_factory.dart';
import 'package:smplayer_flutter/src/playback/immersive_mode_app_bar.dart';
import 'package:smplayer_flutter/src/playback/immersive_mode_constants.dart';
import 'package:smplayer_flutter/src/playback/immersive_mode_control_panel.dart';
import 'package:smplayer_flutter/src/playback/immersive_mode_model.dart';
import 'package:smplayer_flutter/src/playback/immersive_mode_multi_select_bar.dart';
import 'package:smplayer_flutter/src/playback/immersive_mode_scaffold.dart';
import 'package:smplayer_flutter/src/playback/immersive_mode_stage.dart';
import 'package:smplayer_flutter/src/playback/immersive_mode_queue.dart';
import 'package:smplayer_flutter/src/playback/immersive_mode_theme.dart';
import 'package:smplayer_flutter/src/playback/playback_queue_actions.dart';
import 'package:smplayer_flutter/src/playback/quick_play_model.dart';
import 'package:smplayer_flutter/src/settings/settings_controller.dart';
import 'package:smplayer_flutter/src/settings/settings_model.dart'
    show NightMode;

@visibleForTesting
List<int> reorderImmersiveModeQueueSongIds(
  List<int> queueSongIds,
  int oldIndex,
  int newIndex,
) {
  return moveImmersiveModeQueueSongIds(queueSongIds, oldIndex, newIndex, false);
}

@visibleForTesting
List<int> moveImmersiveModeQueueSongIds(
  List<int> queueSongIds,
  int draggedIndex,
  int targetIndex,
  bool insertAfter,
) {
  if (draggedIndex == targetIndex) {
    return queueSongIds;
  }
  final nextSongIds = queueSongIds.toList();
  final songId = nextSongIds.removeAt(draggedIndex);
  final targetInsertIndex = targetIndex + (insertAfter ? 1 : 0);
  final adjustedTargetIndex =
      draggedIndex < targetInsertIndex
          ? targetInsertIndex - 1
          : targetInsertIndex;
  nextSongIds.insert(adjustedTargetIndex, songId);
  return nextSongIds;
}

@visibleForTesting
List<int> playNextImmersiveModeQueueSongIds(
  List<int> queueSongIds,
  int targetTrackId,
  int? currentTrackId,
  int targetIndex,
  int? currentTrackIndex,
) {
  final activeIndex = _currentPlaybackQueueIndex(
    queueSongIds,
    currentTrackId,
    currentTrackIndex ?? -1,
  );
  if (targetIndex > -1 &&
      targetIndex < queueSongIds.length &&
      queueSongIds[targetIndex] == targetTrackId) {
    return _movePlaybackQueueSong(
      queueSongIds,
      targetIndex,
      activeIndex + (targetIndex < activeIndex ? 0 : 1),
      currentTrackId,
      currentTrackIndex ?? -1,
    );
  }
  return _addPlaybackQueueSong(queueSongIds, targetTrackId, activeIndex + 1);
}

int _currentPlaybackQueueIndex(
  List<int> queueSongIds,
  int? currentTrackId,
  int currentTrackIndex,
) {
  if (currentTrackId == null) {
    return -1;
  }
  if (currentTrackIndex > -1 &&
      currentTrackIndex < queueSongIds.length &&
      queueSongIds[currentTrackIndex] == currentTrackId) {
    return currentTrackIndex;
  }
  return queueSongIds.indexOf(currentTrackId);
}

List<int> _addPlaybackQueueSong(
  List<int> queueSongIds,
  int songId,
  int insertIndex,
) {
  final nextSongIds = queueSongIds.toList();
  nextSongIds.insert(insertIndex, songId);
  return nextSongIds;
}

List<int> _movePlaybackQueueSong(
  List<int> queueSongIds,
  int from,
  int to,
  int? currentTrackId,
  int currentTrackIndex,
) {
  if (from == to) {
    return queueSongIds;
  }

  final nextSongIds = queueSongIds.toList();
  final current = nextSongIds[from];

  if (from ==
      _currentPlaybackQueueIndex(
        nextSongIds,
        currentTrackId,
        currentTrackIndex,
      )) {
    final stepCount = (from - to).abs();
    if (stepCount == 0 || to >= nextSongIds.length) {
      return queueSongIds;
    }
    for (var index = 0; index < stepCount; index += 1) {
      final item = nextSongIds[to];
      nextSongIds.removeAt(to);
      nextSongIds.insert(from, item);
    }
    return nextSongIds;
  }

  nextSongIds.removeAt(from);
  nextSongIds.insert(
    to > nextSongIds.length ? nextSongIds.length : to,
    current,
  );
  return nextSongIds;
}

class ImmersiveModePage extends ConsumerStatefulWidget {
  const ImmersiveModePage({super.key});

  @override
  ConsumerState<ImmersiveModePage> createState() => _ImmersiveModePageState();
}

class _ImmersiveModePageState extends ConsumerState<ImmersiveModePage>
    with SingleTickerProviderStateMixin {
  final _selection = PageSelectionController<int>.stored('now-playing-full');
  final _queueController = ScrollController();
  var _isPlaylistOpen = false;
  SongDialogMode? _dialogMode;
  int? _artworkLookupSongId;
  int? _resolvedArtworkSongId;
  String _resolvedArtworkPath = '';
  String _coverColorArtworkPath = '';
  Color _coverColor = const Color(0xff5b87b6);
  var _lyricsRefreshRevision = 0;
  late int _currentClockMinute;
  Timer? _clockMinuteTimer;
  late final AnimationController _entranceController;
  var _tickerModeEnabled = false;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      reverseDuration: const Duration(milliseconds: 400),
    );
    _currentClockMinute = getCurrentClockMinute();
    _clockMinuteTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _currentClockMinute = getCurrentClockMinute();
      });
    });
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _clockMinuteTimer?.cancel();
    _queueController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tickerModeEnabled = TickerMode.valuesOf(context).enabled;
    if (tickerModeEnabled && !_tickerModeEnabled) {
      _entranceController.value = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _entranceController.forward();
      });
    }
    _tickerModeEnabled = tickerModeEnabled;
  }

  void _exitImmersiveMode(SmPlayerShellActions? shellActions) {
    unawaited(_animateExit(shellActions));
  }

  Future<void> _animateExit(SmPlayerShellActions? shellActions) async {
    await _entranceController.reverse();
    shellActions?.onExitImmersiveMode?.call();
  }

  @override
  Widget build(BuildContext context) {
    final snapshotValue = ref.watch(libraryContentDataProvider);
    final recentSongs =
        ref.watch(recentPageDataProvider).valueOrNull?.recentSongs ??
        const <RecentLibrarySong>[];
    final mediaControlState = ref.watch(mediaControlControllerProvider).state;
    final shellActions = ref.watch(smPlayerShellActionsProvider);
    final i18n = context.smPlayerI18n;

    return snapshotValue.when(
      loading:
          () => ImmersiveModeScaffold(
            coverColor: _coverColor,
            entranceAnimation: _entranceController,
            child: Center(
              child: Text(
                i18n.t('nowPlaying.loading'),
                style: const TextStyle(
                  color: ImmersiveModeColors.nightText,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      error:
          (_, _) => ImmersiveModeScaffold(
            coverColor: _coverColor,
            entranceAnimation: _entranceController,
            child: Center(
              child: Text(
                i18n.t('nowPlaying.noActiveTrack'),
                style: const TextStyle(color: ImmersiveModeColors.nightText),
              ),
            ),
          ),
      data: (snapshot) {
        final songsById = {for (final song in snapshot.songs) song.id: song};
        final queueOverride = ref.watch(nowPlayingQueueOverrideProvider);
        final sourceQueueSongIds = queueOverride ?? snapshot.nowPlaying.songIds;
        final queueSongs =
            sourceQueueSongIds
                .map((songId) => songsById[songId])
                .whereType<LibrarySong>()
                .toList();
        final queueSongIds = queueSongs.map((song) => song.id).toList();
        final currentSong = _resolveCurrentSong(mediaControlState, songsById);
        _ensureResolvedArtwork(currentSong);
        final displayArtworkPath = _displayArtworkPath(currentSong);
        _ensureCoverColor(displayArtworkPath);
        final noticeKey = mediaControlState.playbackNoticeKey;
        final noticeText = noticeKey == null ? null : i18n.t(noticeKey);
        final customPlaylists = _customPlaylists(snapshot.playlists);
        final settings = smPlayerGlobalSettingsSnapshot;
        final immersiveNightActive =
            settings.nightMode == NightMode.onMode ||
            (settings.nightMode == NightMode.auto &&
                isMinuteInNightRange(
                  _currentClockMinute,
                  timeToMinute(settings.nightModeStartTime),
                  timeToMinute(settings.nightModeEndTime),
                ));
        Widget buildQueuePopover(bool fullScreen) {
          return ImmersiveModeQueuePopoverHost(
            open: _isPlaylistOpen,
            fullScreen: fullScreen,
            child: ImmersiveModePlaylist(
              open: _isPlaylistOpen,
              i18n: i18n,
              songs: queueSongs,
              songIds: queueSongIds,
              mediaControlState: mediaControlState,
              loading: mediaControlState.track.isLoading,
              selection: _selection,
              scrollController: _queueController,
              playlists: customPlaylists,
              playlistSnapshots: snapshot.playlists,
              folders: snapshot.folders,
              onClose: () {
                setState(() {
                  _isPlaylistOpen = false;
                });
              },
              onReorder: _moveQueueSong,
              onReplaceQueue: _replaceQueue,
              currentQueueSongIds: () {
                return _currentQueueSongIds(queueSongIds);
              },
              onPlaySongs: _playQueueSongIds,
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
              onClearNowPlaying: () {
                _replaceQueue(const []);
              },
              onQuickPlay: () {
                unawaited(_quickPlay(snapshot));
              },
              onRandomPlay: () {
                _playSongIds(snapshot.songs.map((song) => song.id).toList());
              },
              onAddToNowPlaying: (song) {
                _addSongToNowPlaying(song, queueSongIds);
              },
              onGetPreferenceLevel: _getSongPreferenceLevel,
              onUndoPreference: _undoSongPreference,
              onSetPreference: _setSongPreference,
              onDeleteSongFromDisk: _deleteSongFromDisk,
              onHideSongFile: (song) => _hideSongFile(song, queueSongIds),
              onMoveSongToFolder: _moveSongToFolder,
              onOpenSongDialog: _openMusicDialog,
              onRevealSong: _revealPath,
              fullScreen: fullScreen,
              coverColor: _coverColor,
            ),
          );
        }

        Widget buildQueueLayer(double viewportWidth) {
          if (viewportWidth <= immersiveModeLayoutCompactBreakpoint) {
            return Positioned.fill(
              child: KeyedSubtree(
                key: const ValueKey('ImmersiveMode.QueuePopoverHost'),
                child: buildQueuePopover(true),
              ),
            );
          }
          return Positioned(
            top: 56,
            right: 24,
            bottom: 24,
            width: min(viewportWidth * 0.4, 520),
            child: KeyedSubtree(
              key: const ValueKey('ImmersiveMode.QueuePopoverHost'),
              child: buildQueuePopover(false),
            ),
          );
        }

        Widget buildPlayerBarLayer(double viewportWidth) {
          return Positioned(
            right: 0,
            bottom: 0,
            left: 0,
            height: immersiveModePlayerHeight,
            child: ImmersiveModeControlPanel(
              key: const ValueKey('ImmersiveMode.PlayerBar'),
              song: currentSong,
              state: mediaControlState,
              disabled: currentSong == null,
              i18n: i18n,
              night: immersiveNightActive,
              onPrevious: () {
                _playPreviousFromQueue(queueSongs);
              },
              onNext: () {
                _playNextFromQueue(queueSongs);
              },
              onTogglePlayPause: () {
                _togglePlayPauseFromQueue(queueSongs);
              },
              onQuickPlay: () {
                unawaited(_quickPlay(snapshot));
              },
              onToggleShuffle: _toggleShufflePlayback,
              onToggleFavorite:
                  currentSong == null
                      ? null
                      : () {
                        unawaited(
                          _toggleSongsFavorite([
                            currentSong.id,
                          ], !currentSong.favorite),
                        );
                      },
              desktopLyricsEnabled: settings.desktopLyricsEnabled,
              onToggleDesktopLyrics: shellActions?.onToggleDesktopLyrics,
              onOpenVoiceAssistant: shellActions?.onOpenVoiceAssistant,
              onToggleWindowFullScreen: shellActions?.onToggleWindowFullScreen,
              isWindowFullScreen: shellActions?.isWindowFullScreen ?? false,
              onEnterMiniMode: shellActions?.onEnterMiniMode,
              onClose: () {
                _exitImmersiveMode(shellActions);
              },
              onMoreClick: (buttonContext) {
                unawaited(
                  _showMoreMenu(
                    buttonContext,
                    currentSong,
                    snapshot,
                    queueSongIds,
                    recentSongs: recentSongs,
                    shellActions: shellActions,
                    isCompact:
                        viewportWidth <=
                        immersiveModeImmersiveCompactBreakpoint,
                  ),
                );
              },
            ),
          );
        }

        return ImmersiveModeScaffold(
          artworkPath: displayArtworkPath,
          coverColor: _coverColor,
          night: immersiveNightActive,
          entranceAnimation: _entranceController,
          child: Builder(
            builder: (context) {
              final viewportWidth = MediaQuery.sizeOf(context).width;
              final queueLayer = buildQueueLayer(viewportWidth);
              final playerBarLayer = buildPlayerBarLayer(viewportWidth);
              return Stack(
                children: [
                  Positioned.fill(
                    child: Padding(
                      padding: immersiveModeContentPadding(viewportWidth),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final compact =
                              viewportWidth <=
                              immersiveModeLayoutCompactBreakpoint;
                          return ImmersiveModeStage(
                            song: currentSong,
                            artworkPath: displayArtworkPath,
                            mediaControlState: mediaControlState,
                            i18n: i18n,
                            refreshRevision: _lyricsRefreshRevision,
                            onSeekAndPlay:
                                ref
                                    .read(mediaControlControllerProvider)
                                    .onSeekAndPlay,
                            compact: compact,
                            entranceAnimation: _entranceController,
                          );
                        },
                      ),
                    ),
                  ),
                  ImmersiveModeAppBar(
                    i18n: i18n,
                    playlistOpen: _isPlaylistOpen,
                    onClose: () {
                      _exitImmersiveMode(shellActions);
                    },
                    onTogglePlaylist: () {
                      setState(() {
                        _dialogMode = null;
                        _isPlaylistOpen = !_isPlaylistOpen;
                      });
                    },
                  ),
                  playerBarLayer,
                  queueLayer,
                  ImmersiveModeMultiSelectCommandBar(
                    i18n: i18n,
                    songs: queueSongs,
                    songIds: queueSongIds,
                    playlists: customPlaylists,
                    defaultNewPlaylistName: getDefaultNewPlaylistName(
                      i18n,
                      snapshot.playlists,
                    ),
                    hideMultiSelectCommandBarAfterOperation:
                        snapshot.hideMultiSelectCommandBarAfterOperation,
                    selection: _selection,
                    currentQueueSongIds: () {
                      return _currentQueueSongIds(queueSongIds);
                    },
                    onToggleFavorite: _toggleSongsFavorite,
                    onAddToPlaylist: _addSongsToPlaylist,
                    onPlay: _playQueueSongIds,
                    onReplaceQueue: _replaceQueue,
                    onRemoveSelectedQueueIndexes: (
                      selectedIndexes,
                      nextSongIds,
                    ) {
                      _removeSelectedQueueIndexes(
                        queueSongIds,
                        selectedIndexes,
                        nextSongIds,
                      );
                    },
                    onSelectionChanged: () {
                      setState(() {});
                    },
                  ),
                  if (noticeText != null)
                    Positioned(
                      right: 76,
                      bottom: immersiveModePlayerHeight + 14,
                      left: 76,
                      child: ImmersiveModeErrorBanner(message: noticeText),
                    ),
                  if (currentSong != null && _dialogMode != null)
                    MusicDialog(
                      song: currentSong,
                      initialMode: _dialogMode!,
                      currentTrackId: mediaControlState.track.id,
                      isPlaying: mediaControlState.isPlaying,
                      queueSongIds: queueSongIds,
                      canPause:
                          mediaControlState.isPlaying &&
                          mediaControlState.track.id == currentSong.id,
                      onPlay:
                          ref
                              .read(mediaControlControllerProvider)
                              .onTogglePlayPause,
                      onPlayTrack: (trackId, nextQueueSongIds) {
                        final song = songsById[trackId] ?? currentSong;
                        ref
                            .read(mediaControlControllerProvider)
                            .playTrack(
                              mediaControlTrackForSong(song, i18n),
                              durationSeconds: song.duration.toDouble(),
                              queueIndex: nextQueueSongIds.indexOf(trackId),
                            );
                        _replaceQueue(nextQueueSongIds);
                      },
                      onReveal: _revealPath,
                      onClose: () {
                        setState(() {
                          _dialogMode = null;
                        });
                      },
                      onSaved: () {
                        _handleMusicDialogSaved(currentSong);
                      },
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  LibrarySong? _resolveCurrentSong(
    MediaControlState mediaControlState,
    Map<int, LibrarySong> songsById,
  ) {
    final trackId = mediaControlState.track.id;
    if (trackId == null) {
      return null;
    }
    final librarySong = songsById[trackId];
    if (librarySong != null) {
      return librarySong;
    }
    final track = mediaControlState.track;
    return LibrarySong(
      id: trackId,
      path: '',
      title: track.title,
      artist: track.artist,
      artists: const [],
      album: '',
      duration: mediaControlState.durationSeconds.round(),
      playCount: 0,
      lyricsOffsetMs: 0,
      dateAdded: '',
      favorite: track.favorite,
      thumbnailPath: track.artworkUrl,
    );
  }

  void _ensureResolvedArtwork(LibrarySong? song) {
    if (song == null || song.thumbnailPath.isNotEmpty) {
      return;
    }
    if (_artworkLookupSongId == song.id || _resolvedArtworkSongId == song.id) {
      return;
    }

    _artworkLookupSongId = song.id;
    unawaited(
      ref.read(libraryRepositoryProvider).getSongArtworkSnapshot(song.id).then((
        snapshot,
      ) {
        if (!mounted || _artworkLookupSongId != song.id) {
          return;
        }
        setState(() {
          _resolvedArtworkSongId = song.id;
          _resolvedArtworkPath = snapshot.artworkUrl;
        });
      }),
    );
  }

  String _displayArtworkPath(LibrarySong? song) {
    if (song == null) {
      return '';
    }
    if (song.thumbnailPath.isNotEmpty) {
      return song.thumbnailPath;
    }
    return _resolvedArtworkSongId == song.id ? _resolvedArtworkPath : '';
  }

  void _ensureCoverColor(String artworkPath) {
    if (_coverColorArtworkPath == artworkPath) {
      return;
    }
    _coverColorArtworkPath = artworkPath;
    if (artworkPath.isEmpty) {
      _coverColor = const Color(0xff5b87b6);
      return;
    }
    unawaited(
      extractPlayerArtworkAccentColor(artworkPath).then((color) {
        if (!mounted || _coverColorArtworkPath != artworkPath) {
          return;
        }
        _setCoverColor(color, artworkPath);
      }),
    );
  }

  void _setCoverColor(Color color, String artworkPath) {
    if (_coverColorArtworkPath != artworkPath || _coverColor == color) {
      return;
    }
    setState(() {
      _coverColor = color;
    });
  }

  void _handleMusicDialogSaved(LibrarySong song) {
    if (_resolvedArtworkSongId == song.id || _artworkLookupSongId == song.id) {
      _artworkLookupSongId = null;
      _resolvedArtworkSongId = null;
      _resolvedArtworkPath = '';
      _coverColorArtworkPath = '';
    }
    setState(() {
      _lyricsRefreshRevision += 1;
    });
    notifyLyricsSaved(ref, song.id);
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
    LibraryContentData snapshot,
    List<int> queueSongIds, {
    required List<LibrarySong> recentSongs,
    required SmPlayerShellActions? shellActions,
    required bool isCompact,
  }) async {
    final mediaController = ref.read(mediaControlControllerProvider);
    final settings = smPlayerGlobalSettingsSnapshot;
    final songsById = {for (final song in snapshot.songs) song.id: song};
    final queueSongs = [
      for (final songId in queueSongIds)
        if (songsById[songId] case final song?) song,
    ];
    await showMediaControlMoreMenu(
      context: buttonContext,
      i18n: context.smPlayerI18n,
      isMuted: mediaController.state.isMuted,
      volumeValue: mediaController.state.volume,
      desktopLyricsEnabled: settings.desktopLyricsEnabled,
      onToggleDesktopLyrics: shellActions?.onToggleDesktopLyrics,
      alwaysShowQuickPlay: true,
      randomPlayDisabled: queueSongIds.isEmpty && snapshot.songs.isEmpty,
      randomPlaySubmenu: buildShuffleMenuFlyoutItems(
        i18n: context.smPlayerI18n,
        songs: queueSongs,
        librarySongs: snapshot.songs,
        recentSongs: recentSongs,
        playlists: snapshot.playlists,
        folders: snapshot.folders,
        randomLimit: nowPlayingQuickPlayLimit,
        onPlaySongs: _playSongIds,
        includeQuickPlay: false,
      ),
      onVolumeChange: mediaController.onVolumeChange,
      onToggleMute: mediaController.onToggleMute,
      isCompact: isCompact,
      onQuickPlay: () {
        unawaited(_quickPlay(snapshot));
      },
      onToggleFavorite:
          currentSong == null
              ? mediaController.onToggleFavorite
              : () {
                unawaited(
                  _toggleSongsFavorite([currentSong.id], !currentSong.favorite),
                );
              },
      onToggleWindowFullScreen: shellActions?.onToggleWindowFullScreen,
      isWindowFullScreen: shellActions?.isWindowFullScreen ?? false,
      onEnterMiniMode: shellActions?.onEnterMiniMode,
      showFavoriteWhenUnavailable: true,
      currentSong: currentSong,
      nowPlayingSongIds: queueSongIds,
      playlists: snapshot.playlists,
      onResolvePreferenceLevel:
          currentSong == null
              ? null
              : () => _getSongPreferenceLevel(currentSong.id),
      onAddToNowPlaying:
          currentSong == null
              ? null
              : () => _addSongToNowPlaying(currentSong, queueSongIds),
      onCreatePlaylist:
          currentSong == null
              ? null
              : (name) {
                unawaited(_createPlaylist(name, [currentSong.id]));
              },
      onAddToPlaylist:
          currentSong == null
              ? null
              : (playlistId) {
                unawaited(_addSongsToPlaylist(playlistId, [currentSong.id]));
              },
      onUndoPreference:
          currentSong == null
              ? null
              : () {
                unawaited(_undoSongPreference(currentSong.id));
              },
      onSetPreference:
          currentSong == null
              ? null
              : (level) {
                unawaited(
                  _setSongPreference(currentSong.id, currentSong.title, level),
                );
              },
      onPlayArtist:
          currentSong == null
              ? null
              : () => _playArtist(currentSong, snapshot.songs),
      onPlayAlbum:
          currentSong == null
              ? null
              : () => _playAlbum(currentSong, snapshot.songs),
      onSeeArtist:
          currentSong == null ||
                  shellActions?.onExitImmersiveMode == null ||
                  shellActions?.onNavigate == null
              ? null
              : () {
                final artist = primaryImmersiveModeArtist(
                  currentSong,
                  context.smPlayerI18n,
                );
                shellActions!.onExitImmersiveMode!();
                shellActions.onNavigate!(
                  '/artists?artist=${Uri.encodeQueryComponent(artist)}',
                );
              },
      onSeeAlbum:
          currentSong == null ||
                  shellActions?.onExitImmersiveMode == null ||
                  shellActions?.onNavigate == null
              ? null
              : () {
                final album = displayImmersiveModeAlbum(
                  currentSong,
                  context.smPlayerI18n,
                );
                shellActions!.onExitImmersiveMode!();
                shellActions.onNavigate!(
                  '/albums?album=${Uri.encodeQueryComponent(album)}',
                );
              },
      onSeeMusicInfo:
          currentSong == null
              ? null
              : () => _openMusicDialog(SongDialogMode.properties),
      onSeeLyrics:
          currentSong == null
              ? null
              : () => _openMusicDialog(SongDialogMode.lyrics),
      onSeeAlbumArt:
          currentSong == null
              ? null
              : () => _openMusicDialog(SongDialogMode.albumArt),
      onSeeLocal:
          currentSong == null ? null : () => _revealPath(currentSong.path),
    );
  }

  void _toggleShufflePlayback() {
    final mediaController = ref.read(mediaControlControllerProvider);
    final enablingShuffle = mediaController.state.mode != PlaybackMode.shuffle;
    int? selectedQueueIndex;
    if (enablingShuffle) {
      final snapshot = ref.read(libraryContentDataProvider).valueOrNull;
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
        selectedQueueIndex = nextQueueIndex > -1 ? nextQueueIndex : null;
      }
    }
    mediaController.onToggleShuffle(selectedQueueIndex: selectedQueueIndex);
  }

  void _playQueueTrack(
    LibrarySong song,
    List<int> queueSongIds,
    int queueIndex,
  ) {
    replaceNowPlayingQueueAndPlayIndex(
      ref: ref,
      snapshot: ref.read(libraryContentDataProvider).value!,
      i18n: context.smPlayerI18n,
      songIds: queueSongIds,
      queueIndex: queueIndex,
    );
  }

  void _playSongIds(List<int> songIds) {
    _playQueueSongIds(songIds.toList()..shuffle());
  }

  void _playQueueSongIds(List<int> songIds) {
    if (songIds.isEmpty) {
      return;
    }

    replaceNowPlayingQueueAndPlayIndex(
      ref: ref,
      snapshot: ref.read(libraryContentDataProvider).value!,
      i18n: context.smPlayerI18n,
      songIds: songIds,
      queueIndex: 0,
    );
  }

  Future<void> _quickPlay(LibraryContentData snapshot) async {
    final preferences =
        await ref.read(libraryRepositoryProvider).getPreferenceSettings();
    _playQueueSongIds(
      quickPlaySongIds(
        songs: snapshot.songs,
        playlists: snapshot.playlists,
        folders: snapshot.folders,
        preferences: preferences,
        randomLimit: nowPlayingQuickPlayLimit,
      ),
    );
  }

  void _playAlbum(LibrarySong currentSong, List<LibrarySong> songs) {
    final targetAlbum = displayImmersiveModeAlbum(
      currentSong,
      context.smPlayerI18n,
    );
    _playSongIds([
      for (final song in songs)
        if (displayImmersiveModeAlbum(song, context.smPlayerI18n) ==
            targetAlbum)
          song.id,
    ]);
  }

  void _playArtist(LibrarySong currentSong, List<LibrarySong> songs) {
    final currentArtists = artists_model.getSongArtists(currentSong);
    final targetArtists =
        currentArtists.isEmpty ? [currentSong.artist] : currentArtists;
    _playSongIds([
      for (final song in songs)
        if ((artists_model.getSongArtists(song).isEmpty
                ? [song.artist]
                : artists_model.getSongArtists(song))
            .any(targetArtists.contains))
          song.id,
    ]);
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

  bool _playPreviousFromQueue(
    List<LibrarySong> queueSongs, {
    bool forcePrevious = false,
  }) {
    if (queueSongs.isEmpty) {
      return false;
    }
    final controller = ref.read(mediaControlControllerProvider);
    if (!forcePrevious &&
        shouldRestartCurrentTrackForPrevious(
          progressSeconds: controller.state.progressSeconds,
          queueLength: queueSongs.length,
          restartAfterThresholdEnabled:
              smPlayerGlobalSettingsSnapshot.previousButtonRestartsTrack,
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

  void _replaceQueue(List<int> songIds) {
    final snapshot = ref.read(libraryContentDataProvider).value;
    final queueOverride = ref.read(nowPlayingQueueOverrideProvider);
    final currentSongIds = queueOverride ?? snapshot?.nowPlaying.songIds;
    if (currentSongIds != null) {
      syncMediaControlForQueueChange(
        mediaController: ref.read(mediaControlControllerProvider),
        currentSongIds: currentSongIds,
        nextSongIds: songIds,
      );
    }
    if (currentSongIds != null &&
        _sameImmersiveModeSongIds(currentSongIds, songIds)) {
      return;
    }
    setNowPlayingQueue(ref, songIds);
  }

  List<int> _currentQueueSongIds(List<int> fallback) {
    return ref.read(nowPlayingQueueOverrideProvider) ??
        ref.read(libraryContentDataProvider).valueOrNull?.nowPlaying.songIds ??
        fallback;
  }

  void _moveQueueSong(List<int> queueSongIds, int oldIndex, int newIndex) {
    _replaceQueue(
      reorderImmersiveModeQueueSongIds(queueSongIds, oldIndex, newIndex),
    );
  }

  void _removeQueueIndex(List<int> queueSongIds, int queueIndex) {
    final nextQueueSongIds = [
      for (var index = 0; index < queueSongIds.length; index += 1)
        if (index != queueIndex) queueSongIds[index],
    ];
    final nextPlayingQueueIndex = _nextQueueIndexAfterRemovingCurrentPlaying(
      queueSongIds,
      {queueIndex},
      nextQueueSongIds,
    );
    _replaceQueue(nextQueueSongIds);
    if (nextPlayingQueueIndex != null) {
      _playQueueSongAt(nextQueueSongIds, nextPlayingQueueIndex);
    }
  }

  void _removeSelectedQueueIndexes(
    List<int> queueSongIds,
    List<int> selectedIndexes,
    List<int> nextQueueSongIds,
  ) {
    final nextPlayingQueueIndex = _nextQueueIndexAfterRemovingCurrentPlaying(
      queueSongIds,
      selectedIndexes.toSet(),
      nextQueueSongIds,
    );
    _replaceQueue(nextQueueSongIds);
    if (nextPlayingQueueIndex != null) {
      _playQueueSongAt(nextQueueSongIds, nextPlayingQueueIndex);
    }
  }

  int? _nextQueueIndexAfterRemovingCurrentPlaying(
    List<int> queueSongIds,
    Set<int> removedIndexes,
    List<int> nextQueueSongIds,
  ) {
    final currentQueueIndex = _currentPlayingQueueIndex(queueSongIds);
    if (currentQueueIndex == null ||
        !removedIndexes.contains(currentQueueIndex) ||
        nextQueueSongIds.isEmpty) {
      return null;
    }
    var nextQueueIndex = 0;
    for (var index = 0; index < currentQueueIndex; index += 1) {
      if (!removedIndexes.contains(index)) {
        nextQueueIndex += 1;
      }
    }
    return nextQueueIndex < nextQueueSongIds.length ? nextQueueIndex : 0;
  }

  int? _currentPlayingQueueIndex(List<int> queueSongIds) {
    final mediaState = ref.read(mediaControlControllerProvider).state;
    if (!mediaState.isPlaying) {
      return null;
    }
    final trackId = mediaState.track.id;
    if (trackId == null) {
      return null;
    }
    final queueIndex = mediaState.selectedQueueIndex;
    if (queueIndex != null &&
        queueIndex >= 0 &&
        queueIndex < queueSongIds.length &&
        queueSongIds[queueIndex] == trackId) {
      return queueIndex;
    }
    final trackIndex = queueSongIds.indexOf(trackId);
    return trackIndex == -1 ? null : trackIndex;
  }

  void _playQueueSongAt(List<int> queueSongIds, int queueIndex) {
    playQueueIndex(
      ref: ref,
      snapshot: ref.read(libraryContentDataProvider).value!,
      i18n: context.smPlayerI18n,
      songIds: queueSongIds,
      queueIndex: queueIndex,
    );
  }

  void _playNext(List<int> queueSongIds, int queueIndex) {
    final mediaControlState = ref.read(mediaControlControllerProvider).state;
    _replaceQueue(
      playNextImmersiveModeQueueSongIds(
        queueSongIds,
        queueSongIds[queueIndex],
        mediaControlState.track.id,
        queueIndex,
        mediaControlState.selectedQueueIndex,
      ),
    );
  }

  Future<void> _createPlaylist(String name, List<int> songIds) async {
    await ref.read(libraryRepositoryProvider).createPlaylist(name, songIds);
  }

  Future<void> _addSongsToPlaylist(int playlistId, List<int> songIds) async {
    await addSongsToPlaylistWithUndo(
      context: context,
      ref: ref,
      i18n: context.smPlayerI18n,
      playlistId: playlistId,
      songIds: songIds,
      useSingleSongCall: songIds.length == 1,
    );
  }

  Future<void> _toggleSongsFavorite(List<int> songIds, bool favorite) async {
    await setSongsFavorite(ref, songIds, favorite);
  }

  void _addSongToNowPlaying(LibrarySong song, List<int> queueSongIds) {
    final insertedIndex = queueSongIds.length;
    _replaceQueue([...queueSongIds, song.id]);
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
            queueSongIds;
        _replaceQueue(removePlaybackQueueRange(current, insertedIndex, 1));
      },
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
    final removedEntries = immersiveModeQueueEntriesForSong(
      queueSongIds,
      song.id,
    );
    await ref.read(libraryRepositoryProvider).hideSong(song.id);
    ref.invalidate(libraryContentDataProvider);
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
        ref.invalidate(libraryContentDataProvider);
        final snapshot =
            await ref.read(libraryRepositoryProvider).getLibraryContentData();
        final currentQueueSongIds =
            ref.read(nowPlayingQueueOverrideProvider) ??
            snapshot.nowPlaying.songIds;
        _replaceQueue(
          insertImmersiveModeQueueEntries(currentQueueSongIds, removedEntries),
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

  void _openMusicDialog(SongDialogMode mode) {
    setState(() {
      _isPlaylistOpen = false;
      _dialogMode = mode;
    });
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
}

String primaryImmersiveModeArtist(LibrarySong song, SmPlayerI18n i18n) {
  final artists = artists_model.getSongArtists(song);
  return artists.isEmpty ? i18n.t('common.artistUnknown') : artists.first;
}

String displayImmersiveModeAlbum(LibrarySong song, SmPlayerI18n i18n) {
  return song_display.displayAlbum(song, i18n);
}

bool _sameImmersiveModeSongIds(List<int> left, List<int> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}

@visibleForTesting
String formatImmersiveModeLyricSeekTime(double seconds) {
  return formatDuration(seconds);
}
