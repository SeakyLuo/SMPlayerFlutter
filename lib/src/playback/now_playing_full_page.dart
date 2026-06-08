import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
import 'package:smplayer_flutter/src/playback/now_playing_full_app_bar.dart';
import 'package:smplayer_flutter/src/playback/now_playing_full_constants.dart';
import 'package:smplayer_flutter/src/playback/now_playing_full_control_panel.dart';
import 'package:smplayer_flutter/src/playback/now_playing_full_model.dart';
import 'package:smplayer_flutter/src/playback/now_playing_full_more_menu.dart';
import 'package:smplayer_flutter/src/playback/now_playing_full_multi_select_bar.dart';
import 'package:smplayer_flutter/src/playback/now_playing_full_route.dart';
import 'package:smplayer_flutter/src/playback/now_playing_full_scaffold.dart';
import 'package:smplayer_flutter/src/playback/now_playing_full_stage.dart';
import 'package:smplayer_flutter/src/playback/now_playing_full_queue.dart';
import 'package:smplayer_flutter/src/playback/now_playing_full_theme.dart';
import 'package:smplayer_flutter/src/playback/quick_play_model.dart';
import 'package:smplayer_flutter/src/settings/settings_controller.dart';
import 'package:smplayer_flutter/src/settings/settings_model.dart'
    show NightMode;

@visibleForTesting
List<int> reorderNowPlayingFullQueueSongIds(
  List<int> queueSongIds,
  int oldIndex,
  int newIndex,
) {
  return moveNowPlayingFullQueueSongIds(
    queueSongIds,
    oldIndex,
    newIndex,
    false,
  );
}

@visibleForTesting
List<int> moveNowPlayingFullQueueSongIds(
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
List<int> playNextNowPlayingFullQueueSongIds(
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
  var _isMoreMenuOpen = false;
  Timer? _playerBarHideTimer;
  SongDialogMode? _dialogMode;
  int? _artworkLookupSongId;
  int? _resolvedArtworkSongId;
  String _resolvedArtworkPath = '';
  String _coverColorArtworkPath = '';
  Color _coverColor = const Color(0xff5b87b6);
  var _lyricsRefreshRevision = 0;
  late int _currentClockMinute;
  Timer? _clockMinuteTimer;

  @override
  void initState() {
    super.initState();
    _currentClockMinute = getCurrentClockMinute();
    _clockMinuteTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _currentClockMinute = getCurrentClockMinute();
      });
    });
    _schedulePlayerBarHide();
  }

  @override
  void dispose() {
    _clockMinuteTimer?.cancel();
    _playerBarHideTimer?.cancel();
    _queueController.dispose();
    super.dispose();
  }

  Future<void> _closeFullPage(SmPlayerShellActions? shellActions) async {
    await shellActions?.onExitWindowFullScreen?.call();
    if (!mounted) {
      return;
    }
    context.go(nowPlayingFullReturnLocation(context));
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
      if (!mounted || _isMoreMenuOpen || _dialogMode != null) {
        return;
      }
      setState(() {
        _isPlayerBarRaised = false;
      });
    });
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
          () => NowPlayingFullScaffold(
            coverColor: _coverColor,
            child: Center(
              child: Text(
                i18n.t('nowPlaying.loading'),
                style: const TextStyle(
                  color: NowPlayingFullColors.nightText,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      error:
          (_, _) => NowPlayingFullScaffold(
            coverColor: _coverColor,
            child: Center(
              child: Text(
                i18n.t('nowPlaying.noActiveTrack'),
                style: const TextStyle(color: NowPlayingFullColors.nightText),
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
          return NowPlayingFullQueuePopoverHost(
            open: _isPlaylistOpen,
            fullScreen: fullScreen,
            child: NowPlayingFullPlaylist(
              open: _isPlaylistOpen,
              i18n: i18n,
              songs: queueSongs,
              songIds: queueSongIds,
              mediaControlState: mediaControlState,
              loading: mediaControlState.track.isLoading,
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
              currentQueueSongIds: () {
                return ref
                        .read(libraryContentDataProvider)
                        .valueOrNull
                        ?.nowPlaying
                        .songIds ??
                    queueSongIds;
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
          if (viewportWidth <= nowPlayingFullLayoutCompactBreakpoint) {
            return Positioned.fill(
              child: KeyedSubtree(
                key: const ValueKey('NowPlayingFull.QueuePopoverHost'),
                child: buildQueuePopover(true),
              ),
            );
          }
          return Positioned(
            top: 56,
            right: 24,
            bottom: 132,
            width: min(viewportWidth * 0.4, 520),
            child: KeyedSubtree(
              key: const ValueKey('NowPlayingFull.QueuePopoverHost'),
              child: buildQueuePopover(false),
            ),
          );
        }

        Widget buildPlayerBarLayer(double viewportWidth) {
          return Positioned(
            right: 0,
            bottom: 0,
            left: 0,
            height: nowPlayingFullPlayerHeight,
            child: AnimatedOpacity(
              key: const ValueKey('NowPlayingFull.PlayerBarOpacity'),
              duration: const Duration(milliseconds: 180),
              curve: Curves.ease,
              opacity: _isPlayerBarRaised ? 1 : 0.24,
              child: AnimatedSlide(
                key: const ValueKey('NowPlayingFull.PlayerBarSlide'),
                duration: const Duration(milliseconds: 260),
                curve: const Cubic(0.2, 0, 0, 1),
                offset:
                    _isPlayerBarRaised
                        ? Offset.zero
                        : const Offset(0, nowPlayingFullPlayerIdleSlideOffset),
                child: NowPlayingFullControlPanel(
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
                  onOpenVoiceAssistant: shellActions?.onOpenVoiceAssistant,
                  onClose: () {
                    unawaited(_closeFullPage(shellActions));
                  },
                  onMoreClick: (buttonContext) {
                    unawaited(
                      _showMoreMenu(
                        buttonContext,
                        currentSong,
                        snapshot,
                        queueSongIds,
                        customPlaylists,
                        recentSongs: recentSongs,
                        shellActions: shellActions,
                        isCompact:
                            viewportWidth <=
                            nowPlayingFullImmersiveCompactBreakpoint,
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        }

        return NowPlayingFullScaffold(
          artworkPath: displayArtworkPath,
          coverColor: _coverColor,
          night: immersiveNightActive,
          child: MouseRegion(
            onEnter: (_) {
              _raisePlayerBar();
            },
            onHover: (_) {
              _raisePlayerBar();
            },
            onExit: (_) {
              _schedulePlayerBarHide();
            },
            child: Builder(
              builder: (context) {
                final viewportWidth = MediaQuery.sizeOf(context).width;
                final queueLayer = buildQueueLayer(viewportWidth);
                final playerBarLayer = buildPlayerBarLayer(viewportWidth);
                final compactPlayerBarUnderQueue =
                    viewportWidth <= nowPlayingFullImmersiveCompactBreakpoint;
                return Stack(
                  children: [
                    Positioned.fill(
                      child: Padding(
                        padding: nowPlayingFullContentPadding(viewportWidth),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final compact =
                                viewportWidth <=
                                nowPlayingFullLayoutCompactBreakpoint;
                            return NowPlayingFullStage(
                              song: currentSong,
                              artworkPath: displayArtworkPath,
                              mediaControlState: mediaControlState,
                              i18n: i18n,
                              refreshRevision: _lyricsRefreshRevision,
                              onSeek:
                                  ref
                                      .read(mediaControlControllerProvider)
                                      .onSeek,
                              onTogglePlayPause:
                                  ref
                                      .read(mediaControlControllerProvider)
                                      .onTogglePlayPause,
                              compact: compact,
                            );
                          },
                        ),
                      ),
                    ),
                    NowPlayingFullAppBar(
                      i18n: i18n,
                      playlistOpen: _isPlaylistOpen,
                      onClose: () {
                        unawaited(_closeFullPage(shellActions));
                      },
                      onTogglePlaylist: () {
                        final dialogWasOpen = _dialogMode != null;
                        setState(() {
                          _dialogMode = null;
                          _isPlaylistOpen = !_isPlaylistOpen;
                        });
                        if (dialogWasOpen) {
                          _schedulePlayerBarHide();
                        }
                      },
                    ),
                    if (compactPlayerBarUnderQueue) playerBarLayer,
                    queueLayer,
                    if (!compactPlayerBarUnderQueue) playerBarLayer,
                    NowPlayingFullMultiSelectCommandBar(
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
                        return ref
                                .read(libraryContentDataProvider)
                                .valueOrNull
                                ?.nowPlaying
                                .songIds ??
                            queueSongIds;
                      },
                      onToggleFavorite: _toggleSongsFavorite,
                      onAddToPlaylist: _addSongsToPlaylist,
                      onPlay: _playQueueSongIds,
                      onReplaceQueue: _replaceQueue,
                      onSelectionChanged: () {
                        setState(() {});
                      },
                    ),
                    if (noticeText != null)
                      Positioned(
                        right: 76,
                        bottom: nowPlayingFullPlayerHeight + 14,
                        left: 76,
                        child: NowPlayingFullErrorBanner(message: noticeText),
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
                          _schedulePlayerBarHide();
                        },
                        onSaved: () {
                          _handleMusicDialogSaved(currentSong);
                        },
                      ),
                  ],
                );
              },
            ),
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
    ref.invalidate(libraryContentDataProvider);
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
    List<int> queueSongIds,
    List<MultiSelectCommandBarPlaylist> customPlaylists, {
    required List<LibrarySong> recentSongs,
    required SmPlayerShellActions? shellActions,
    required bool isCompact,
  }) async {
    await showNowPlayingFullMoreMenu(
      context: context,
      ref: ref,
      buttonContext: buttonContext,
      currentSong: currentSong,
      snapshot: snapshot,
      queueSongIds: queueSongIds,
      customPlaylists: customPlaylists,
      recentSongs: recentSongs,
      shellActions: shellActions,
      isCompact: isCompact,
      onQuickPlay: () {
        unawaited(_quickPlay(snapshot));
      },
      onPlaySongs: _playSongIds,
      onToggleShuffle: _toggleShufflePlayback,
      onCreatePlaylist: _createPlaylist,
      onAddSongsToPlaylist: _addSongsToPlaylist,
      onAddSongToNowPlaying: (song) {
        _addSongToNowPlaying(song, queueSongIds);
      },
      onToggleSongsFavorite: _toggleSongsFavorite,
      onSetSongPreference: _setSongPreference,
      onOpenMusicDialog: _openMusicDialog,
      onPlayArtist: _playArtist,
      onPlayAlbum: _playAlbum,
      onClearNowPlaying: () {
        unawaited(_closeFullPage(shellActions));
        _replaceQueue(const []);
      },
      onMenuOpenChanged: (open) {
        setState(() {
          _isMoreMenuOpen = open;
          if (open) {
            _isPlayerBarRaised = true;
          }
        });
      },
      onSchedulePlayerBarHide: _schedulePlayerBarHide,
      hasDialogOpen: () => _dialogMode != null,
      isMounted: () => mounted,
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
    _playQueueSongIds(songIds.toList()..shuffle());
  }

  void _playQueueSongIds(List<int> songIds) {
    if (songIds.isEmpty) {
      return;
    }

    final songs = ref.read(libraryContentDataProvider).value!.songs;
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

  void _playAlbum(LibrarySong currentSong, List<LibrarySong> songs) {
    final targetAlbum = displayNowPlayingFullAlbum(
      currentSong,
      context.smPlayerI18n,
    );
    final songIds =
        songs
            .where(
              (song) =>
                  displayNowPlayingFullAlbum(song, context.smPlayerI18n) ==
                  targetAlbum,
            )
            .map((song) => song.id)
            .toList();
    _playSongIds(songIds);
  }

  void _playArtist(LibrarySong currentSong, List<LibrarySong> songs) {
    final currentArtists = artists_model.getSongArtists(currentSong);
    final targetArtists =
        currentArtists.isEmpty ? [currentSong.artist] : currentArtists;
    final songIds =
        songs
            .where((song) {
              final songArtists = artists_model.getSongArtists(song);
              final artists = songArtists.isEmpty ? [song.artist] : songArtists;
              return artists.any(targetArtists.contains);
            })
            .map((song) => song.id)
            .toList();
    _playSongIds(songIds);
  }

  void _replaceQueue(List<int> songIds) {
    ref.read(nowPlayingQueueOverrideProvider.notifier).state = songIds;
    ref.read(libraryRepositoryProvider).replaceNowPlaying(songIds);
    ref.invalidate(libraryContentDataProvider);
  }

  void _moveQueueSong(List<int> queueSongIds, int oldIndex, int newIndex) {
    _replaceQueue(
      reorderNowPlayingFullQueueSongIds(queueSongIds, oldIndex, newIndex),
    );
  }

  void _removeQueueIndex(List<int> queueSongIds, int queueIndex) {
    _replaceQueue([
      for (var index = 0; index < queueSongIds.length; index += 1)
        if (index != queueIndex) queueSongIds[index],
    ]);
  }

  void _playNext(List<int> queueSongIds, int queueIndex) {
    final mediaControlState = ref.read(mediaControlControllerProvider).state;
    _replaceQueue(
      playNextNowPlayingFullQueueSongIds(
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
    ref.invalidate(libraryContentDataProvider);
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
    ref.invalidate(libraryContentDataProvider);
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
    ref.invalidate(libraryContentDataProvider);
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
    final removedEntries = nowPlayingFullQueueEntriesForSong(
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
        _replaceQueue(
          insertNowPlayingFullQueueEntries(
            snapshot.nowPlaying.songIds,
            removedEntries,
          ),
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
    _playerBarHideTimer?.cancel();
    setState(() {
      _isPlaylistOpen = false;
      _isMoreMenuOpen = false;
      _isPlayerBarRaised = true;
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

String primaryNowPlayingFullArtist(LibrarySong song, SmPlayerI18n i18n) {
  final artists = artists_model.getSongArtists(song);
  return artists.isEmpty ? i18n.t('common.artistUnknown') : artists.first;
}

String displayNowPlayingFullAlbum(LibrarySong song, SmPlayerI18n i18n) {
  return song_display.displayAlbum(song, i18n);
}

@visibleForTesting
String formatNowPlayingFullLyricSeekTime(double seconds) {
  return formatDuration(seconds);
}
