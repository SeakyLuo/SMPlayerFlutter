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

part 'immersive_mode_page_actions.dart';

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
  final _songInfoKey = GlobalKey();
  final _lyricsKey = GlobalKey();
  var _isPlaylistOpen = false;
  var _isExiting = false;
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

  void _updateImmersiveState(VoidCallback update) => setState(update);

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
    setState(() {
      _isExiting = true;
    });
    unawaited(_animateExit(shellActions));
  }

  Future<void> _animateExit(SmPlayerShellActions? shellActions) async {
    await _entranceController.reverse();
    shellActions?.onExitImmersiveMode?.call();
  }

  @override
  Widget build(BuildContext context) {
    final snapshotValue = ref.watch(libraryContentDataProvider);
    final recentSongs = ref.watch(recentSongsProvider);
    ref.watch(libraryPlaylistOverridesProvider);
    ref.watch(libraryDeletedPlaylistIdsProvider);
    ref.watch(libraryPlaylistOrderProvider);
    final mediaState = ref.watch(
      mediaControlControllerProvider.select(
        (controller) => (
          track: controller.state.track,
          selectedQueueIndex: controller.state.selectedQueueIndex,
          isPlaying: controller.state.isPlaying,
          playbackNoticeKey: controller.state.playbackNoticeKey,
          durationSeconds: controller.state.durationSeconds,
        ),
      ),
    );
    final shellActions = ref.watch(smPlayerShellActionsProvider);
    final i18n = context.smPlayerI18n;

    return snapshotValue.when(
      skipLoadingOnReload: true,
      skipError: true,
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
        final currentSong = _resolveCurrentSong(
          mediaState.track,
          mediaState.durationSeconds,
          songsById,
        );
        _ensureResolvedArtwork(currentSong);
        final displayArtworkPath = _displayArtworkPath(currentSong);
        _ensureCoverColor(displayArtworkPath);
        final noticeKey = mediaState.playbackNoticeKey;
        final noticeText = noticeKey == null ? null : i18n.t(noticeKey);
        final customPlaylists = _customPlaylists(
          _effectivePlaylists(snapshot.playlists),
        );
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
              currentTrackId: mediaState.track.id,
              selectedQueueIndex: mediaState.selectedQueueIndex,
              isPlaying: mediaState.isPlaying,
              loading: mediaState.track.isLoading,
              selection: _selection,
              scrollController: _queueController,
              playlists: customPlaylists,
              playlistSnapshots: _effectivePlaylists(snapshot.playlists),
              folders: snapshot.folders,
              onClose: () {
                setState(() {
                  _selection.cancel();
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
              onMoveSongToFolder: _moveSongToFolder,
              onOpenSongDialog: _openMusicDialog,
              onRevealSong: _revealPath,
              onLocateSong:
                  shellActions?.onExitImmersiveMode == null ||
                          shellActions?.onNavigate == null
                      ? null
                      : (songId) => locateSongInLocal(
                        context,
                        songId,
                        onNavigate: (location) {
                          shellActions!.onExitImmersiveMode!();
                          shellActions.onNavigate!(location);
                        },
                      ),
              fullScreen: fullScreen,
              coverColor: _coverColor,
              multiSelectCommandBar: ImmersiveModeMultiSelectCommandBar(
                i18n: i18n,
                songs: queueSongs,
                songIds: queueSongIds,
                playlists: customPlaylists,
                defaultNewPlaylistName: getDefaultNewPlaylistName(
                  i18n,
                  _effectivePlaylists(snapshot.playlists),
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
                onRemoveSelectedQueueIndexes: (selectedIndexes, nextSongIds) {
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
            top: immersiveModeQueueEdgeInset,
            right: immersiveModeQueueEdgeInset,
            bottom: immersiveModeQueueEdgeInset,
            width: min(
              immersiveModeQueueMaxWidth,
              viewportWidth - immersiveModeQueueEdgeInset * 2,
            ),
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
                          return Consumer(
                            builder: (context, ref, child) {
                              final mediaControlState =
                                  ref
                                      .watch(mediaControlControllerProvider)
                                      .state;
                              return ImmersiveModeStage(
                                song: currentSong,
                                songInfoKey: _songInfoKey,
                                lyricsKey: _lyricsKey,
                                artworkPath: displayArtworkPath,
                                mediaControlState: mediaControlState,
                                i18n: i18n,
                                refreshRevision: _lyricsRefreshRevision,
                                lyricsRequestMode: settings.playerLyricsSource,
                                onSeekAndPlay:
                                    ref
                                        .read(mediaControlControllerProvider)
                                        .onSeekAndPlay,
                                compact: compact,
                                entranceAnimation: _entranceController,
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                  if (!_isExiting)
                    ImmersiveModeAppBar(
                      i18n: i18n,
                      playlistOpen: _isPlaylistOpen,
                      onClose: () {
                        _exitImmersiveMode(shellActions);
                      },
                      onTogglePlaylist: () {
                        setState(() {
                          _dialogMode = null;
                          if (_isPlaylistOpen) {
                            _selection.cancel();
                          }
                          _isPlaylistOpen = !_isPlaylistOpen;
                        });
                      },
                    ),
                  playerBarLayer,
                  queueLayer,
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
                      currentTrackId: mediaState.track.id,
                      isPlaying: mediaState.isPlaying,
                      queueSongIds: queueSongIds,
                      canPause:
                          mediaState.isPlaying &&
                          mediaState.track.id == currentSong.id,
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
    MediaControlTrack track,
    double durationSeconds,
    Map<int, LibrarySong> songsById,
  ) {
    final trackId = track.id;
    if (trackId == null) {
      return null;
    }
    final librarySong = songsById[trackId];
    if (librarySong != null) {
      return librarySong;
    }
    return LibrarySong(
      id: trackId,
      path: '',
      title: track.title,
      artist: track.artist,
      artists: const [],
      album: '',
      duration: durationSeconds.round(),
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
