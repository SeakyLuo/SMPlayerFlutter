import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:smplayer_flutter/src/app/exit_fullscreen_icon.dart';
import 'package:smplayer_flutter/src/app/loading_state.dart';
import 'package:smplayer_flutter/src/app/shell_actions.dart';
import 'package:smplayer_flutter/src/app/smplayer_vector_icons.dart';
import 'package:smplayer_flutter/src/app/undoable_notification.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
import 'package:smplayer_flutter/src/library/ui/artists_page_model.dart'
    as artists_model;
import 'package:smplayer_flutter/src/library/ui/default_album_artwork.dart';
import 'package:smplayer_flutter/src/library/ui/menu_flyout.dart';
import 'package:smplayer_flutter/src/library/ui/menu_flyout_helpers.dart';
import 'package:smplayer_flutter/src/library/ui/multi_select_command_bar.dart';
import 'package:smplayer_flutter/src/library/ui/library_page_actions.dart';
import 'package:smplayer_flutter/src/library/ui/music_dialog.dart';
import 'package:smplayer_flutter/src/library/ui/page_selection_store.dart';
import 'package:smplayer_flutter/src/library/ui/song_display_helpers.dart'
    as song_display;
import 'package:smplayer_flutter/src/library/ui/song_artwork.dart';
import 'package:smplayer_flutter/src/platform/desktop_features.dart';
import 'package:smplayer_flutter/src/playback/media_control.dart';
import 'package:smplayer_flutter/src/playback/media_control_model.dart';
import 'package:smplayer_flutter/src/playback/media_control_provider.dart';
import 'package:smplayer_flutter/src/playback/media_control_track_factory.dart';
import 'package:smplayer_flutter/src/playback/now_playing_full_model.dart';
import 'package:smplayer_flutter/src/playback/now_playing_full_route.dart';
import 'package:smplayer_flutter/src/playback/playlist_control_item.dart';
import 'package:smplayer_flutter/src/playback/quick_play_model.dart';
import 'package:smplayer_flutter/src/settings/settings_controller.dart';
import 'package:smplayer_flutter/src/settings/settings_model.dart'
    show NightMode;

const _nowPlayingFullPlayerHeight = 120.0;
const _nowPlayingFullPlayerIdleVisibleHeight = 10.0;
const _nowPlayingFullPlayerIdleSlideOffset =
    (_nowPlayingFullPlayerHeight - _nowPlayingFullPlayerIdleVisibleHeight) /
    _nowPlayingFullPlayerHeight;
const _nowPlayingFullPlayerTopRadius = 18.0;
const _nowPlayingFullLayoutCompactBreakpoint = 760.0;
const _nowPlayingFullImmersiveCompactBreakpoint = 800.0;
const _nowPlayingFullQueueRowHeight = 78.0;

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
          () => _NowPlayingFullScaffold(
            coverColor: _coverColor,
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
            coverColor: _coverColor,
            child: Center(
              child: Text(
                i18n.t('nowPlaying.noActiveTrack'),
                style: const TextStyle(color: _NowPlayingFullColors.nightText),
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
          return _NowPlayingFullQueuePopoverHost(
            open: _isPlaylistOpen,
            fullScreen: fullScreen,
            child: _NowPlayingFullPlaylist(
              open: _isPlaylistOpen,
              i18n: i18n,
              songs: queueSongs,
              songIds: queueSongIds,
              mediaControlState: mediaControlState,
              loading: mediaControlState.track.isLoading,
              selection: _selection,
              scrollController: _queueController,
              playlists: customPlaylists,
              defaultNewPlaylistName: getDefaultNewPlaylistName(
                i18n,
                snapshot.playlists,
              ),
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
              hideMultiSelectCommandBarAfterOperation:
                  snapshot.hideMultiSelectCommandBarAfterOperation,
            ),
          );
        }

        Widget buildQueueLayer(double viewportWidth) {
          if (viewportWidth <= _nowPlayingFullLayoutCompactBreakpoint) {
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
            height: _nowPlayingFullPlayerHeight,
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
                        : const Offset(0, _nowPlayingFullPlayerIdleSlideOffset),
                child: _NowPlayingFullControlPanel(
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
                            _nowPlayingFullImmersiveCompactBreakpoint,
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        }

        return _NowPlayingFullScaffold(
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
                    viewportWidth <= _nowPlayingFullImmersiveCompactBreakpoint;
                return Stack(
                  children: [
                    Positioned.fill(
                      child: Padding(
                        padding: _contentPadding(viewportWidth),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final compact =
                                viewportWidth <=
                                _nowPlayingFullLayoutCompactBreakpoint;
                            return compact
                                ? _buildCompactStage(
                                  currentSong,
                                  displayArtworkPath,
                                  mediaControlState,
                                  queueSongs,
                                  queueSongIds,
                                  customPlaylists,
                                  snapshot,
                                  i18n,
                                )
                                : _buildWideStage(
                                  currentSong,
                                  displayArtworkPath,
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
                    if (noticeText != null)
                      Positioned(
                        right: 76,
                        bottom: _nowPlayingFullPlayerHeight + 14,
                        left: 76,
                        child: _NowPlayingFullErrorBanner(message: noticeText),
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

  Widget _buildWideStage(
    LibrarySong? currentSong,
    String displayArtworkPath,
    MediaControlState mediaControlState,
    List<LibrarySong> queueSongs,
    List<int> queueSongIds,
    List<MultiSelectCommandBarPlaylist> customPlaylists,
    LibraryContentData snapshot,
    SmPlayerI18n i18n,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final pageWidth = MediaQuery.sizeOf(context).width;
        final midCompact = pageWidth <= 1100;
        final artworkSize =
            midCompact
                ? clampDouble(pageWidth * 0.28, 168, 250)
                : clampDouble(pageWidth * 0.28, 220, 416);
        final stageHeight = artworkSize + (midCompact ? 128 : 132);
        final gap = midCompact ? 32.0 : clampDouble(pageWidth * 0.05, 40, 72);
        final lyricAnchorOffset =
            pageWidth <= _nowPlayingFullImmersiveCompactBreakpoint
                ? null
                : artworkSize / 2;
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
                      child: OverflowBox(
                        maxHeight: double.infinity,
                        alignment: Alignment.center,
                        child: Center(
                          child: SizedBox(
                            width: artworkSize,
                            child: _NowPlayingFullArtwork(
                              song: currentSong,
                              artworkPath: displayArtworkPath,
                              artworkSize: artworkSize,
                              compact: false,
                            ),
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
                      refreshRevision: _lyricsRefreshRevision,
                      compact: false,
                      midCompact: midCompact,
                      anchorOffset: lyricAnchorOffset,
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
    String displayArtworkPath,
    MediaControlState mediaControlState,
    List<LibrarySong> queueSongs,
    List<int> queueSongIds,
    List<MultiSelectCommandBarPlaylist> customPlaylists,
    LibraryContentData snapshot,
    SmPlayerI18n i18n,
  ) {
    final pageWidth = MediaQuery.sizeOf(context).width;
    final artworkSize = min(pageWidth * 0.58, 250.0);
    final lyricStageHeight = min(
      MediaQuery.sizeOf(context).height * 0.44,
      320.0,
    );
    return SingleChildScrollView(
      clipBehavior: Clip.none,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: artworkSize,
                child: _NowPlayingFullArtwork(
                  song: currentSong,
                  artworkPath: displayArtworkPath,
                  artworkSize: artworkSize,
                  compact: true,
                ),
              ),
              const SizedBox(height: 18),
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
                      ref
                          .read(mediaControlControllerProvider)
                          .onTogglePlayPause,
                  refreshRevision: _lyricsRefreshRevision,
                  compact: true,
                  midCompact: false,
                  anchorOffset: null,
                ),
              ),
            ],
          ),
        ),
      ),
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

  EdgeInsets _contentPadding(double width) {
    if (width <= _nowPlayingFullLayoutCompactBreakpoint) {
      return const EdgeInsets.fromLTRB(18, 88, 18, 172);
    }
    if (width <= 1100) {
      return const EdgeInsets.fromLTRB(28, 72, 28, 128);
    }
    return const EdgeInsets.fromLTRB(76, 82, 76, 128);
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
    final i18n = context.smPlayerI18n;
    final mediaController = ref.read(mediaControlControllerProvider);
    setState(() {
      _isMoreMenuOpen = true;
      _isPlayerBarRaised = true;
    });
    if (!buttonContext.mounted) {
      setState(() {
        _isMoreMenuOpen = false;
      });
      if (_dialogMode == null) {
        _schedulePlayerBarHide();
      }
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
                _addSongToNowPlaying(currentSong, queueSongIds);
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
    final buttonBox = buttonContext.findRenderObject() as RenderBox;
    List<MenuFlyoutItem> buildItems(String? preferenceLevel) {
      return [
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
          useShuffleIcon: true,
          disabled: queueSongIds.isEmpty && snapshot.songs.isEmpty,
          submenu: buildShuffleMenuFlyoutItems(
            i18n: i18n,
            songs: queueSongs,
            librarySongs: snapshot.songs,
            recentSongs: recentSongs,
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
            icon:
                mediaController.state.mode == PlaybackMode.shuffle
                    ? null
                    : _nonShufflePlaybackModeMenuIcon(
                      mediaController.state.mode,
                    ),
            usePlaylistIcon: mediaController.state.mode == PlaybackMode.once,
            useShuffleIcon: mediaController.state.mode == PlaybackMode.shuffle,
            submenu: buildPlaybackModeMenuFlyoutItems(
              i18n: i18n,
              mode: mediaController.state.mode,
              onToggleShuffle: _toggleShufflePlayback,
              onToggleRepeat: mediaController.onToggleRepeat,
              onToggleRepeatOne: mediaController.onToggleRepeatOne,
            ),
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
            unawaited(_closeFullPage(shellActions));
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
                      ref.invalidate(libraryContentDataProvider);
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
            useAlbumIcon: true,
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
                onPressed: () {
                  _openMusicDialog(SongDialogMode.properties);
                },
              ),
              MenuFlyoutItem(
                key: 'see-lyrics',
                text: i18n.t('context.seeLyrics'),
                icon: FluentIcons.comment_text_20_regular,
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
      ];
    }

    final itemsNotifier = ValueNotifier<List<MenuFlyoutItem>>(buildItems(null));
    var menuClosed = false;
    if (currentSong != null) {
      unawaited(
        ref
            .read(libraryRepositoryProvider)
            .getPreferenceLevel('song', '${currentSong.id}')
            .then((preferenceLevel) {
              if (!menuClosed) {
                itemsNotifier.value = buildItems(preferenceLevel);
              }
            }),
      );
    }
    await showMenuFlyout(
      buttonContext,
      position: buttonBox.localToGlobal(Offset.zero),
      avoidPlayerBar: false,
      items: itemsNotifier.value,
      itemsListenable: itemsNotifier,
    );
    menuClosed = true;
    itemsNotifier.dispose();
    if (!mounted) {
      return;
    }
    setState(() {
      _isMoreMenuOpen = false;
    });
    if (_dialogMode == null) {
      _schedulePlayerBarHide();
    }
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

  String _playbackModeName(SmPlayerI18n i18n, PlaybackMode mode) {
    return switch (mode) {
      PlaybackMode.shuffle => i18n.t('player.playbackModeShuffle'),
      PlaybackMode.repeat => i18n.t('player.playbackModeRepeat'),
      PlaybackMode.repeatOne => i18n.t('player.playbackModeRepeatOne'),
      PlaybackMode.once => i18n.t('player.playbackModeList'),
    };
  }

  IconData _nonShufflePlaybackModeMenuIcon(PlaybackMode mode) {
    return switch (mode) {
      PlaybackMode.repeat => FluentIcons.arrow_repeat_all_20_regular,
      PlaybackMode.repeatOne => FluentIcons.arrow_repeat_1_20_regular,
      PlaybackMode.once => FluentIcons.music_note_2_20_regular,
      PlaybackMode.shuffle =>
        throw StateError('shuffle uses SmPlayerShuffleIcon'),
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
    final targetAlbum = _displayAlbum(currentSong, context.smPlayerI18n);
    final songIds =
        songs
            .where(
              (song) =>
                  _displayAlbum(song, context.smPlayerI18n) == targetAlbum,
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
    await ref
        .read(libraryRepositoryProvider)
        .setSongsFavorite(songIds, favorite);
    final mediaController = ref.read(mediaControlControllerProvider);
    if (songIds.contains(mediaController.state.track.id) &&
        mediaController.state.track.favorite != favorite) {
      mediaController.onToggleFavorite();
    }
    ref.invalidate(libraryContentDataProvider);
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
    final removedEntries = _queueEntriesForSong(queueSongIds, song.id);
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
    required this.coverColor,
    this.artworkPath,
    this.night = false,
  });

  final String? artworkPath;
  final Color coverColor;
  final bool night;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final artworkFile =
        artworkPath == null || artworkPath!.isEmpty ? null : File(artworkPath!);
    final colors = NowPlayingFullThemeColors.of(context, night: night);
    final theme = Theme.of(context);
    final mediaControlColors = (night
            ? MediaControlThemeColors.dark
            : MediaControlThemeColors.light)
        .copyWith(
          textMuted:
              night ? const Color(0xa8ffffff) : MediaControlColors.textMuted,
          primaryButtonBorder:
              night ? const Color(0x6b0078d7) : Colors.transparent,
          primaryButtonHover: MediaControlColors.accentStrong,
          disabledPrimaryButtonSurface: MediaControlColors.accent,
          primaryButtonShadow: BoxShadow(
            color:
                night
                    ? const Color(0x52000000)
                    : MediaControlColors.accentShadow,
            offset: const Offset(0, 12),
            blurRadius: 26,
          ),
          buttonForeground:
              night ? const Color(0xf0f6f9fc) : MediaControlColors.textStrong,
          buttonHoverForeground:
              night ? Colors.white : MediaControlColors.accentStrong,
          buttonHoverBackground:
              night ? const Color(0x2e0078d7) : const Color(0x1a0078d7),
          buttonActiveBackground:
              night ? const Color(0x380078d7) : const Color(0x1a0078d7),
          favoriteActiveHoverBackground:
              night ? const Color(0x38ffffff) : const Color(0x1a0078d7),
          volumeTooltipBackground: const Color(0xe014181e),
          volumeTooltipForeground: Colors.white,
          volumeTooltipBorder: const Color(0x2effffff),
          volumeTooltipShadow: const BoxShadow(
            color: Color(0x57000000),
            offset: Offset(0, 10),
            blurRadius: 24,
          ),
          playerBorder:
              night ? const Color(0x1fd6e0ec) : const Color(0xb8ccd5e0),
          compactPlayerBorder:
              night ? const Color(0x1fd6e0ec) : const Color(0xb8ccd5e0),
          playerShadow:
              night ? const Color(0x57000000) : const Color(0x24445870),
          compactPlayerShadow:
              night ? const Color(0x57000000) : const Color(0x24445870),
          wideShadowOffsetY: -18,
          wideShadowBlur: night ? 48 : 56,
          compactShadowOffsetY: night ? -12 : -18,
          compactShadowBlur: night ? 36 : 56,
          glassBlur: night ? 28 : 18,
          glassSaturation: night ? 1 : 1.4,
          compactGlassBlur: night ? 28 : 18,
          compactGlassSaturation: night ? 1.45 : 1.4,
          coverWashAlpha: night ? 0.22 : 0.24,
          compactCoverWashAlpha: night ? 0.2 : 0.24,
          wideSurface:
              night ? const Color(0xe611161c) : const Color(0xc7ffffff),
          compactSurface:
              night ? const Color(0xeb101419) : const Color(0xc7ffffff),
          compactWashEnd: night ? const Color(0xc711161c) : Colors.transparent,
          compactWashStop: night ? 0.56 : 0.42,
          compactBaseGradient:
              night ? const [Color(0xe01d232b), Color(0xe0101419)] : null,
          coverWashMode: night ? null : MediaControlCoverWashMode.radial,
          coverWashAlignment: night ? null : const Alignment(-0.6, -0.56),
          coverWashRadius: night ? null : 0.42,
          wideHighlightGradient:
              night ? const [Color(0x0effffff), Color(0x1f0078d7)] : null,
          wideHighlightStops: null,
          wideInsetHighlight:
              night ? const Color(0x0cffffff) : const Color(0xc7ffffff),
          compactInsetHighlight:
              night ? const Color(0x0cffffff) : const Color(0xc7ffffff),
        );
    final scopedTheme = theme.copyWith(
      extensions: [
        for (final extension in theme.extensions.values)
          if (extension is! NowPlayingFullThemeColors &&
              extension is! MediaControlThemeColors)
            extension,
        colors,
        mediaControlColors,
      ],
    );

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
        if (night)
          const _NowPlayingFullNightArtworkShade()
        else
          _NowPlayingFullDayBackdropTint(coverColor: coverColor),
        if (!night) _NowPlayingFullDayCoverGlow(coverColor: coverColor),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: colors.backdropOverlay),
          ),
        ),
        if (night) const _NowPlayingFullNightWarmOverlay(),
        if (!night) _NowPlayingFullDayWashOverlay(coverColor: coverColor),
        Theme(data: scopedTheme, child: child),
      ],
    );
  }
}

class _NowPlayingFullDayBackdropTint extends StatelessWidget {
  const _NowPlayingFullDayBackdropTint({required this.coverColor});

  final Color coverColor;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      top: -40,
      right: -40,
      bottom: -40,
      left: -40,
      child: Transform.scale(
        scale: 1.08,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _CoverRadial(
              coverColor: coverColor,
              center: const Alignment(-0.6, -0.56),
              radius: 0.8,
              alpha: 0.48,
            ),
            _CoverRadial(
              coverColor: coverColor,
              center: const Alignment(0.44, -0.76),
              radius: 0.96,
              alpha: 0.24,
            ),
          ],
        ),
      ),
    );
  }
}

class _NowPlayingFullNightArtworkShade extends StatelessWidget {
  const _NowPlayingFullNightArtworkShade();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      top: -40,
      right: -40,
      bottom: -40,
      left: -40,
      child: Transform.scale(
        scale: 1.08,
        child: const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x3d140f0c), Color(0xc7100c08)],
            ),
          ),
        ),
      ),
    );
  }
}

class _NowPlayingFullDayCoverGlow extends StatelessWidget {
  const _NowPlayingFullDayCoverGlow({required this.coverColor});

  final Color coverColor;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      top: -120,
      right: -180,
      bottom: 120,
      left: -180,
      child: Transform.scale(
        scale: 1.04,
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 54, sigmaY: 54),
          child: Opacity(
            opacity: 0.98,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _CoverRadial(
                  coverColor: coverColor,
                  center: const Alignment(-0.6, -0.56),
                  radius: 0.72,
                  alpha: 0.6,
                ),
                _CoverRadial(
                  coverColor: coverColor,
                  center: const Alignment(0.2, -0.96),
                  radius: 0.8,
                  alpha: 0.3,
                ),
                _CoverRadial(
                  coverColor: coverColor,
                  center: const Alignment(0.76, -0.84),
                  radius: 0.72,
                  alpha: 0.2,
                ),
                _CoverRadial(
                  coverColor: coverColor,
                  center: const Alignment(-0.44, 0.36),
                  radius: 0.84,
                  alpha: 0.2,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NowPlayingFullDayWashOverlay extends StatelessWidget {
  const _NowPlayingFullDayWashOverlay({required this.coverColor});

  final Color coverColor;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Stack(
        fit: StackFit.expand,
        children: [
          _CoverRadial(
            coverColor: coverColor,
            center: const Alignment(-0.6, -0.56),
            radius: 0.84,
            alpha: 0.36,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x80f6f9fc),
                  Color(0xd1f6f9fc),
                  Color(0xf5f6f9fc),
                ],
                stops: [0, 0.72, 1],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NowPlayingFullNightWarmOverlay extends StatelessWidget {
  const _NowPlayingFullNightWarmOverlay();

  @override
  Widget build(BuildContext context) {
    return const Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.64, -0.72),
            radius: 0.64,
            colors: [Color(0x2effd99c), Colors.transparent],
            stops: [0, 1],
          ),
        ),
      ),
    );
  }
}

class _CoverRadial extends StatelessWidget {
  const _CoverRadial({
    required this.coverColor,
    required this.center,
    required this.radius,
    required this.alpha,
  });

  final Color coverColor;
  final Alignment center;
  final double radius;
  final double alpha;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: center,
          radius: radius,
          colors: [coverColor.withValues(alpha: alpha), Colors.transparent],
          stops: const [0, 1],
        ),
      ),
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
        final compact =
            MediaQuery.sizeOf(context).width <=
            _nowPlayingFullLayoutCompactBreakpoint;
        final night = colors.artworkShadowOpacity > 0.3;
        return SizedBox(
          height: compact ? 92 : 118,
          child: Stack(
            children: [
              if (compact)
                Positioned(
                  top: 42,
                  left: 24,
                  child: _NowPlayingFullCompactTopButton(
                    tooltip: i18n.t('sidebar.back'),
                    padding: EdgeInsets.zero,
                    width: 38,
                    colors: colors,
                    onPressed: onClose,
                    child: const Icon(
                      FluentIcons.arrow_left_24_regular,
                      key: ValueKey('NowPlayingFull.BackIcon'),
                      size: 16,
                    ),
                  ),
                ),
              Positioned(
                top: compact ? 42 : 62,
                right: compact ? 24 : 76,
                child:
                    compact
                        ? _NowPlayingFullCompactTopButton(
                          colors: colors,
                          active: playlistOpen,
                          tooltip: i18n.t('common.nowPlaying'),
                          padding: const EdgeInsets.fromLTRB(14, 0, 18, 0),
                          onPressed: onTogglePlaylist,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                FluentIcons.music_note_2_20_regular,
                                key: ValueKey('NowPlayingFull.QueueIcon'),
                                size: 16,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                key: const ValueKey(
                                  'NowPlayingFull.QueueLabel',
                                ),
                                i18n.t('common.nowPlaying'),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        )
                        : TextButton.icon(
                          style: TextButton.styleFrom(
                            minimumSize: const Size(0, 44),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            foregroundColor:
                                playlistOpen
                                    ? colors.topButtonActiveForeground
                                    : colors.topButtonForeground,
                            backgroundColor:
                                playlistOpen
                                    ? (colors.artworkShadowOpacity > 0.3
                                        ? const Color(0x24ffffff)
                                        : const Color(0xdbffffff))
                                    : colors.topButtonBackground,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color:
                                    night
                                        ? const Color(0x29ffffff)
                                        : const Color(0x337e8b9a),
                              ),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          icon: const Icon(
                            FluentIcons.music_note_2_20_regular,
                            key: ValueKey('NowPlayingFull.QueueIcon'),
                            size: 18,
                          ),
                          label: Text(
                            key: const ValueKey('NowPlayingFull.QueueLabel'),
                            i18n.t('common.nowPlaying'),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
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

class _NowPlayingFullCompactTopButton extends StatelessWidget {
  const _NowPlayingFullCompactTopButton({
    required this.colors,
    required this.tooltip,
    required this.padding,
    required this.onPressed,
    required this.child,
    this.active = false,
    this.width,
  });

  final NowPlayingFullThemeColors colors;
  final String tooltip;
  final EdgeInsetsGeometry padding;
  final VoidCallback onPressed;
  final Widget child;
  final bool active;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final night = colors.artworkShadowOpacity > 0.3;
    final foreground =
        active ? colors.topButtonActiveForeground : colors.topButtonForeground;
    final glassColor =
        night
            ? (active ? const Color(0x30ffffff) : const Color(0x1cffffff))
            : (active ? const Color(0xccffffff) : const Color(0x86ffffff));
    return Tooltip(
      message: tooltip,
      child: GlassContainer(
        key: ValueKey('NowPlayingFull.TopButtonGlass.$tooltip'),
        useOwnLayer: true,
        quality: GlassQuality.standard,
        shape: const LiquidRoundedRectangle(borderRadius: 12),
        settings: LiquidGlassSettings(
          blur: night ? 28 : 34,
          thickness: active ? 28 : 24,
          refractiveIndex: 1.1,
          saturation: night ? 1.2 : 1.34,
          chromaticAberration: 0.016,
          lightIntensity: night ? 0.24 : 0.34,
          ambientStrength: night ? 0.14 : 0.18,
          glowIntensity: active ? 0.3 : 0.22,
          glassColor: glassColor,
          standardOpacityMultiplier: night ? 0.86 : 0.78,
        ),
        clipBehavior: Clip.hardEdge,
        allowElevation: false,
        child: SizedBox(
          width: width,
          height: 38,
          child: TextButton(
            style: TextButton.styleFrom(
              minimumSize: Size.zero,
              padding: padding,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: foreground,
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            onPressed: onPressed,
            child: IconTheme.merge(
              data: IconThemeData(color: foreground, size: 16),
              child: DefaultTextStyle.merge(
                style: TextStyle(color: foreground),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _displayArtists(LibrarySong song, SmPlayerI18n i18n) {
  return song_display.displayArtists(song, i18n);
}

String _primaryArtist(LibrarySong song, SmPlayerI18n i18n) {
  final artists = artists_model.getSongArtists(song);
  return artists.isEmpty ? i18n.t('common.artistUnknown') : artists.first;
}

String _displayAlbum(LibrarySong song, SmPlayerI18n i18n) {
  return song_display.displayAlbum(song, i18n);
}

@visibleForTesting
String formatNowPlayingFullLyricSeekTime(double seconds) {
  return formatDuration(seconds);
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

  final lines =
      snapshot.lines.where((line) => line.text.trim().isNotEmpty).toList();
  if (lines.isEmpty) {
    return const [];
  }
  final lastLineIndex = max(1, lines.length - 1);
  final progressRatio =
      durationSeconds > 0 ? (progressSeconds / durationSeconds).clamp(0, 1) : 0;
  final timedLines = lines.where((line) => line.timestampMs != null).toList();
  if (timedLines.isNotEmpty) {
    final progressMs = (progressSeconds * 1000).floor();
    var activeLineId = timedLines.first.id;
    for (final line in timedLines) {
      if (line.timestampMs! > progressMs) {
        break;
      }
      activeLineId = line.id;
    }
    return [
      for (var index = 0; index < lines.length; index += 1)
        _ImmersiveLyricsLine(
          id: lines[index].id,
          text: lines[index].text.trim(),
          seekSeconds:
              lines[index].timestampMs == null
                  ? durationSeconds * (index / lastLineIndex)
                  : lines[index].timestampMs! / 1000,
          active: lines[index].id == activeLineId,
        ),
    ];
  }

  final activeIndex = min(
    lines.length - 1,
    (lines.length * progressRatio).floor(),
  );
  return [
    for (var index = 0; index < lines.length; index += 1)
      _ImmersiveLyricsLine(
        id: lines[index].id,
        text: lines[index].text.trim(),
        seekSeconds: durationSeconds * (index / lastLineIndex),
        active: index == activeIndex,
      ),
  ];
}

class _NowPlayingFullArtwork extends StatelessWidget {
  const _NowPlayingFullArtwork({
    required this.song,
    required this.artworkPath,
    required this.artworkSize,
    required this.compact,
  });

  final LibrarySong? song;
  final String artworkPath;
  final double artworkSize;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final colors = NowPlayingFullThemeColors.of(context);
    final night = colors.artworkShadowOpacity > 0.3;
    final artworkRadius = compact ? 16.0 : 18.0;
    final artworkShadows =
        compact
            ? [
              BoxShadow(
                color:
                    night ? const Color(0x52000000) : const Color(0x47665870),
                blurRadius: 88,
                offset: const Offset(0, 34),
              ),
              BoxShadow(
                color:
                    night ? const Color(0x2e000000) : const Color(0x29665870),
                blurRadius: 26,
                offset: const Offset(0, 12),
              ),
            ]
            : [
              BoxShadow(
                color:
                    night ? const Color(0x61000000) : const Color(0x38665870),
                blurRadius: night ? 86 : 76,
                offset: const Offset(0, 28),
              ),
            ];

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox.square(
          dimension: artworkSize,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(artworkRadius),
              boxShadow: artworkShadows,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(artworkRadius),
              child: SongArtwork(
                artworkPath: artworkPath,
                fallback: const DefaultAlbumArtwork(logoOpacity: 0.9),
              ),
            ),
          ),
        ),
        SizedBox(height: compact ? 22 : 28),
        Text(
          song?.title ?? i18n.t('nowPlaying.noActiveTrack'),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.start,
          style: TextStyle(
            color: colors.text,
            fontSize:
                compact
                    ? 28.48
                    : clampDouble(
                      MediaQuery.sizeOf(context).width * 0.0215,
                      24.8,
                      40,
                    ),
            fontWeight: const FontWeight(760),
            height: compact ? 1.14 : 1.16,
            shadows:
                night
                    ? const [
                      Shadow(
                        color: Color(0x70000000),
                        offset: Offset(0, 12),
                        blurRadius: 40,
                      ),
                    ]
                    : null,
          ),
        ),
        SizedBox(height: compact ? 7 : 8),
        Text(
          song == null
              ? i18n.t('common.artistUnknown')
              : _displayArtists(song!, i18n),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.start,
          style: TextStyle(
            color: colors.muted,
            fontSize: compact ? 14 : 18,
            fontWeight: const FontWeight(550),
            height: compact ? 1.35 : 1.28,
          ),
        ),
        SizedBox(height: compact ? 7 : 8),
        Text(
          song == null
              ? i18n.t('common.albumUnknown')
              : _displayAlbum(song!, i18n),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.start,
          style: TextStyle(
            color: colors.subtle,
            fontSize: compact ? 14 : 18,
            fontWeight: const FontWeight(550),
            height: compact ? 1.35 : 1.28,
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
    required this.refreshRevision,
    required this.compact,
    required this.midCompact,
    required this.anchorOffset,
  });

  final LibrarySong? song;
  final double progressSeconds;
  final double durationSeconds;
  final bool isPlaying;
  final SmPlayerI18n i18n;
  final ValueChanged<double> onSeek;
  final VoidCallback onTogglePlayPause;
  final int refreshRevision;
  final bool compact;
  final bool midCompact;
  final double? anchorOffset;

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
  var _dragging = false;
  var _lyricsDragMoved = false;
  var _lyricsDragPendingDeltaY = 0.0;
  var _scrollActiveAfterBuild = false;
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
    if (oldWidget.song?.id != widget.song?.id ||
        oldWidget.refreshRevision != widget.refreshRevision) {
      _loadLyrics();
    }
    final lines = _displayLines();
    final activeIndex = lines.indexWhere((line) => line.active);
    if (!_previewing && activeIndex >= 0) {
      _scrollActiveLineIntoView();
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
      _dragging = false;
      _lyricsDragMoved = false;
      _lyricsDragPendingDeltaY = 0;
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
      _scrollActiveAfterBuild = true;
    });
  }

  List<_ImmersiveLyricsLine> _displayLines() {
    final song = widget.song;
    final adjustedProgressSeconds = max(
      0.0,
      widget.progressSeconds + (song?.lyricsOffsetMs ?? 0) / 1000,
    );
    final effectiveDuration = resolvePlayerDurationSeconds(
      widget.durationSeconds,
      song,
    );
    return _getImmersiveLyricsLines(
      lyrics: _lyrics,
      progressSeconds: adjustedProgressSeconds,
      durationSeconds: effectiveDuration,
    );
  }

  bool _scrollToIndex(int index) {
    if (!_scrollController.hasClients) {
      return false;
    }
    final lineContext = _lineKeys[index]?.currentContext;
    if (lineContext == null) {
      return false;
    }
    final lineBox = lineContext.findRenderObject();
    if (lineBox is! RenderBox) {
      return false;
    }
    final position = _scrollController.position;
    final estimatedTargetOffset =
        index * (_lyricMinHeight() + _lyricGap()) +
        _lyricMinHeight() / 2 -
        _anchorOffset(position.viewportDimension);
    final viewport = RenderAbstractViewport.maybeOf(lineBox);
    final targetOffset =
        viewport == null
            ? estimatedTargetOffset
            : max(
              viewport.getOffsetToReveal(lineBox, 0).offset +
                  lineBox.size.height / 2 -
                  _anchorOffset(position.viewportDimension),
              estimatedTargetOffset,
            );
    _scrollController.animateTo(
      targetOffset.clamp(position.minScrollExtent, position.maxScrollExtent),
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
    );
    return true;
  }

  void _scrollActiveLineIntoView([int attempt = 0]) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final activeIndex = _displayLines().indexWhere((line) => line.active);
      if (activeIndex >= 0) {
        final didScroll = _scrollToIndex(activeIndex);
        if (!didScroll && attempt < 3) {
          _scrollActiveLineIntoView(attempt + 1);
        }
      }
    });
  }

  double _anchorOffset(double viewportHeight) {
    return widget.anchorOffset ?? viewportHeight / 2;
  }

  void _previewFromScroll({bool scheduleRestore = true}) {
    final lines = _displayLines();
    if (lines.isEmpty || !_scrollController.hasClients) {
      return;
    }
    setState(() {
      _previewing = true;
      _previewIndex = _nearestLineIndex(lines);
    });
    if (scheduleRestore) {
      _scheduleLyricsRestore();
    }
  }

  void _scheduleLyricsRestore() {
    _restoreTimer?.cancel();
    _restoreTimer = Timer(const Duration(seconds: 5), _restoreLyricsToPlayback);
  }

  void _restoreLyricsToPlayback() {
    if (!mounted) {
      return;
    }
    setState(() {
      _previewing = false;
      _dragging = false;
      _lyricsDragMoved = false;
      _lyricsDragPendingDeltaY = 0;
      _previewIndex = null;
    });
    final activeIndex = _displayLines().indexWhere((line) => line.active);
    if (activeIndex >= 0) {
      _scrollToIndex(activeIndex);
    }
  }

  void _previewFromWheel() {
    final lines = _displayLines();
    if (lines.isEmpty) {
      return;
    }
    _restoreTimer?.cancel();
    setState(() {
      _previewing = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _previewFromScroll(scheduleRestore: true);
    });
  }

  void _scrollLyricsBy(double deltaY, {bool scheduleRestore = false}) {
    if (!_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    _scrollController.jumpTo(
      (position.pixels + deltaY).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _previewFromScroll(scheduleRestore: scheduleRestore);
      }
    });
  }

  void _beginLyricsDrag() {
    _restoreTimer?.cancel();
    _lyricsDragMoved = false;
    _lyricsDragPendingDeltaY = 0;
    if (!_dragging || !_previewing) {
      setState(() {
        _dragging = true;
        _previewing = true;
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _previewFromScroll(scheduleRestore: false);
      }
    });
  }

  void _finishLyricsDrag() {
    if (!_dragging) {
      return;
    }
    if (_lyricsDragMoved) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _previewFromScroll(scheduleRestore: true);
        }
      });
      setState(() {
        _dragging = false;
        _lyricsDragPendingDeltaY = 0;
      });
    } else {
      _restoreTimer?.cancel();
      _restoreLyricsToPlayback();
    }
  }

  int _nearestLineIndex(List<_ImmersiveLyricsLine> lines) {
    var nearestIndex = 0;
    var nearestDistance = double.infinity;
    final scrollableBox = context.findRenderObject() as RenderBox;
    final scrollableTop = scrollableBox.localToGlobal(Offset.zero).dy;
    final anchorOffset =
        _scrollController.offset + _anchorOffset(scrollableBox.size.height);
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
      final distance = (center - anchorOffset).abs();
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
      _dragging = false;
      _lyricsDragMoved = false;
      _lyricsDragPendingDeltaY = 0;
      _previewIndex = null;
    });
  }

  double _lyricGap() {
    if (widget.compact) {
      return 10;
    }
    return widget.midCompact ? 14 : 18;
  }

  double _lyricMinHeight() {
    if (widget.compact) {
      return 0;
    }
    return widget.midCompact ? 48 : 54;
  }

  double _lyricFontSize() {
    if (widget.compact) {
      return 18;
    }
    return widget.midCompact ? 17.92 : 19.84;
  }

  double _activeLyricFontSize() {
    if (widget.compact) {
      return 22;
    }
    return widget.midCompact ? 22.72 : 26.56;
  }

  Color _lyricTextColor(NowPlayingFullThemeColors colors, bool active) {
    final dark = colors.artworkShadowOpacity > 0.3;
    if (active) {
      return dark ? const Color(0xf0ffffff) : _NowPlayingFullColors.dayText;
    }
    if (dark) {
      return widget.compact ? const Color(0x29ffffff) : const Color(0x33ffffff);
    }
    return widget.compact ? const Color(0x425b697a) : const Color(0x525b697a);
  }

  @override
  Widget build(BuildContext context) {
    final colors = NowPlayingFullThemeColors.of(context);
    final lines = _displayLines();
    final hasLyrics = lines.isNotEmpty;
    final displayLines =
        hasLyrics
            ? lines
            : [
              _ImmersiveLyricsLine(
                id: -1,
                text:
                    _loading
                        ? widget.i18n.t('nowPlaying.loadingLyrics')
                        : widget.i18n.t('nowPlaying.noLyrics'),
                seekSeconds: 0,
                active: false,
              ),
            ];
    final previewIndex = hasLyrics && _previewing ? _previewIndex : null;
    final previewLine =
        previewIndex == null
            ? null
            : displayLines[min(previewIndex, displayLines.length - 1)];
    if (_scrollActiveAfterBuild && hasLyrics) {
      _scrollActiveAfterBuild = false;
      _scrollActiveLineIntoView();
    }
    return Stack(
      key: const ValueKey('NowPlayingFull.LyricsStage'),
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final lyricsScroll = MouseRegion(
              cursor:
                  _dragging
                      ? SystemMouseCursors.grabbing
                      : SystemMouseCursors.grab,
              child: Listener(
                onPointerSignal: (event) {
                  if (event is PointerScrollEvent) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        _previewFromWheel();
                      }
                    });
                  }
                },
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(
                    dragDevices: {
                      PointerDeviceKind.touch,
                      PointerDeviceKind.mouse,
                      PointerDeviceKind.trackpad,
                      PointerDeviceKind.stylus,
                      PointerDeviceKind.invertedStylus,
                    },
                  ),
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onVerticalDragStart: (_) {
                      _beginLyricsDrag();
                    },
                    onVerticalDragUpdate: (details) {
                      _lyricsDragPendingDeltaY += details.delta.dy;
                      if (!_lyricsDragMoved &&
                          _lyricsDragPendingDeltaY.abs() < 3) {
                        return;
                      }
                      final dragDelta =
                          _lyricsDragMoved
                              ? details.delta.dy
                              : _lyricsDragPendingDeltaY;
                      _lyricsDragMoved = true;
                      _scrollLyricsBy(dragDelta * -1, scheduleRestore: false);
                    },
                    onVerticalDragEnd: (_) {
                      _finishLyricsDrag();
                    },
                    onVerticalDragCancel: _finishLyricsDrag,
                    child: SingleChildScrollView(
                      key: const ValueKey('NowPlayingFull.LyricsList'),
                      controller: _scrollController,
                      padding: EdgeInsets.fromLTRB(
                        0,
                        constraints.maxHeight / 2,
                        widget.compact ? 0 : 20,
                        constraints.maxHeight / 2,
                      ),
                      child: Column(
                        children: [
                          for (
                            var index = 0;
                            index < displayLines.length;
                            index += 1
                          ) ...[
                            Builder(
                              builder: (context) {
                                final line = displayLines[index];
                                if (hasLyrics) {
                                  _lineKeys[index] =
                                      _lineKeys[index] ?? GlobalKey();
                                }
                                final active = line.active;
                                return ConstrainedBox(
                                  key: hasLyrics ? _lineKeys[index] : null,
                                  constraints: BoxConstraints(
                                    minHeight: _lyricMinHeight(),
                                  ),
                                  child: Center(
                                    child: AnimatedDefaultTextStyle(
                                      duration: const Duration(
                                        milliseconds: 180,
                                      ),
                                      curve: Curves.easeOutCubic,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: _lyricTextColor(colors, active),
                                        fontSize:
                                            active
                                                ? _activeLyricFontSize()
                                                : _lyricFontSize(),
                                        fontWeight:
                                            widget.compact && active
                                                ? const FontWeight(760)
                                                : const FontWeight(620),
                                        height:
                                            widget.compact
                                                ? (active ? 1.34 : 1.44)
                                                : 1.35,
                                      ),
                                      child: AnimatedScale(
                                        duration: const Duration(
                                          milliseconds: 180,
                                        ),
                                        curve: Curves.easeOutCubic,
                                        scale:
                                            active && !widget.compact
                                                ? 1.02
                                                : 1,
                                        child: Text(
                                          line.text,
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                            if (index < displayLines.length - 1)
                              SizedBox(height: _lyricGap()),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
            return NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is ScrollUpdateNotification &&
                    notification.dragDetails != null) {
                  _previewFromScroll(scheduleRestore: !_dragging);
                }
                return false;
              },
              child:
                  widget.compact
                      ? lyricsScroll
                      : ShaderMask(
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
                        child: lyricsScroll,
                      ),
            );
          },
        ),
        if (previewLine != null)
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final viewportWidth = MediaQuery.sizeOf(context).width;
                final seekButtonRight =
                    widget.compact
                        ? (constraints.maxWidth - viewportWidth) / 2 + 10
                        : 0.0;
                final seekButtonIconSize = widget.compact ? 16.0 : 18.0;
                final seekButtonGap = widget.compact ? 6.0 : 8.0;
                final dark = colors.artworkShadowOpacity > 0.3;
                final seekButtonForeground =
                    dark
                        ? const Color(0xebffffff)
                        : _NowPlayingFullColors.accentStrong;
                final seekButtonBackground =
                    dark ? const Color(0x1affffff) : const Color(0xb8ffffff);
                final seekButtonBorder =
                    dark ? const Color(0x29ffffff) : const Color(0x337e8b9a);
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      top: _anchorOffset(constraints.maxHeight),
                      right: seekButtonRight,
                      child: FractionalTranslation(
                        translation: const Offset(0, -0.5),
                        child: TextButton(
                          key: const ValueKey('NowPlayingFull.LyricSeekButton'),
                          style: TextButton.styleFrom(
                            minimumSize: const Size(0, 34),
                            padding: const EdgeInsets.fromLTRB(10, 0, 12, 0),
                            foregroundColor: seekButtonForeground,
                            backgroundColor: seekButtonBackground,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                              side: BorderSide(color: seekButtonBorder),
                            ),
                          ),
                          onPressed: () {
                            _seekToLine(previewLine);
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SmPlayerPlayIcon(
                                key: const ValueKey(
                                  'NowPlayingFull.LyricSeekIcon',
                                ),
                                size: seekButtonIconSize,
                              ),
                              SizedBox(width: seekButtonGap),
                              Text(
                                formatNowPlayingFullLyricSeekTime(
                                  previewLine.seekSeconds,
                                ),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight(750),
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
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
    required this.night,
    required this.onPrevious,
    required this.onNext,
    required this.onTogglePlayPause,
    required this.onToggleShuffle,
    required this.onToggleFavorite,
    required this.onOpenVoiceAssistant,
    required this.onClose,
    required this.onMoreClick,
  });

  final LibrarySong? song;
  final MediaControlState state;
  final bool disabled;
  final SmPlayerI18n i18n;
  final bool night;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onTogglePlayPause;
  final VoidCallback onToggleShuffle;
  final VoidCallback? onToggleFavorite;
  final VoidCallback? onOpenVoiceAssistant;
  final VoidCallback onClose;
  final ValueChanged<BuildContext> onMoreClick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(mediaControlControllerProvider);
    final artworkPath = resolvePlayerArtworkPath(state.track, song);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth <= 520;
        final compactUtility = constraints.maxWidth <= 1200;
        final minimalUtility = constraints.maxWidth <= 800;
        final playerPadding = _nowPlayingFullPlayerPadding(
          constraints.maxWidth,
        );
        final horizontalPadding = playerPadding.horizontal;
        final sideWidth = _nowPlayingFullPlayerSideWidth(
          constraints.maxWidth,
          contentWidth: constraints.maxWidth - horizontalPadding,
        );
        final transportDisabled = disabled || song?.id == null;
        return MediaControlSurfaceBar(
          artworkPath: artworkPath,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(_nowPlayingFullPlayerTopRadius),
          ),
          padding: playerPadding,
          columnGap: _nowPlayingFullPlayerColumnGap(constraints.maxWidth),
          leadingWidth: sideWidth,
          utilityWidth: sideWidth,
          surfaceFlex: 1,
          leading: Align(
            alignment: Alignment.centerLeft,
            child: _NowPlayingFullExitButton(
              minimal: minimalUtility,
              tooltip: i18n.t('nowPlaying.exitImmersiveMode'),
              onPressed: onClose,
            ),
          ),
          trackId: song?.id,
          isLoading: false,
          favorite: song?.favorite ?? state.track.favorite,
          disabled: transportDisabled,
          isPlaying: state.isPlaying,
          volume: state.volume,
          isMuted: state.isMuted,
          mode: state.mode,
          progressSeconds: state.progressSeconds,
          durationSeconds: resolvePlayerDurationSeconds(
            state.durationSeconds,
            song,
          ),
          previousButtonRestartsTrack: false,
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
          onToggleFavorite: onToggleFavorite ?? controller.onToggleFavorite,
          onOpenVoiceAssistant: onOpenVoiceAssistant,
          condensed: compact,
          navMinimal: minimalUtility,
          utilityCondensed: compactUtility,
          utilityMinimal: minimalUtility,
          sliderActiveColor:
              night ? const Color(0xdbffffff) : const Color(0xc25b697a),
          sliderInactiveColor:
              night ? const Color(0x33ffffff) : const Color(0x2e5b697a),
          sliderThumbColor: Colors.white,
          sliderThumbShadow: BoxShadow(
            color: night ? const Color(0x61000000) : const Color(0x52445870),
            offset: const Offset(0, 1),
            blurRadius: 8,
          ),
          sliderOverlayColor: Colors.transparent,
          volumeSliderActiveColor:
              night ? const Color(0xf20078d7) : const Color(0xeb0078d7),
          volumeSliderInactiveColor:
              night ? const Color(0x2ecbd5e1) : const Color(0x2e323e4e),
          volumeSliderThumbColor: MediaControlColors.accent,
          volumeSliderThumbShadow: const BoxShadow(
            color: Color(0x47000000),
            offset: Offset(0, 1),
            blurRadius: 4,
          ),
          volumeSliderOverlayColor: Colors.transparent,
          onMoreClick: onMoreClick,
        );
      },
    );
  }
}

EdgeInsets _nowPlayingFullPlayerPadding(double viewportWidth) {
  if (viewportWidth <= 520) {
    return const EdgeInsets.fromLTRB(12, 9, 12, 11);
  }
  if (viewportWidth <= _nowPlayingFullImmersiveCompactBreakpoint) {
    return const EdgeInsets.fromLTRB(16, 8, 16, 10);
  }
  return const EdgeInsets.symmetric(horizontal: 16, vertical: 10);
}

double _nowPlayingFullPlayerColumnGap(double viewportWidth) {
  if (viewportWidth <= 520) {
    return 8;
  }
  if (viewportWidth <= _nowPlayingFullImmersiveCompactBreakpoint) {
    return 10;
  }
  return 0;
}

double _nowPlayingFullPlayerSideWidth(
  double viewportWidth, {
  required double contentWidth,
}) {
  if (viewportWidth <= 520) {
    return 68;
  }
  if (viewportWidth <= _nowPlayingFullImmersiveCompactBreakpoint) {
    return 80;
  }

  final minSide =
      viewportWidth <= 1200 ? clampDouble(viewportWidth * 0.24, 200, 280) : 280;
  final minCenter =
      viewportWidth <= 1200 ? clampDouble(viewportWidth * 0.40, 280, 420) : 420;
  final extra = max(0.0, contentWidth - minCenter - minSide * 2);
  return minSide + extra * 0.9 / 2.8;
}

class _NowPlayingFullExitButton extends StatefulWidget {
  const _NowPlayingFullExitButton({
    required this.minimal,
    required this.tooltip,
    required this.onPressed,
  });

  final bool minimal;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  State<_NowPlayingFullExitButton> createState() =>
      _NowPlayingFullExitButtonState();
}

class _NowPlayingFullExitButtonState extends State<_NowPlayingFullExitButton> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final colors = NowPlayingFullThemeColors.of(context);
    final dark = colors.artworkShadowOpacity > 0.3;
    final active = _hovered || _focused;
    final size = widget.minimal ? 68.0 : 72.0;
    final shellBorderColor =
        dark
            ? active
                ? const Color(0x2effffff)
                : const Color(0x1fffffff)
            : active
            ? const Color(0x14212b3a)
            : Colors.transparent;
    final iconColor =
        dark
            ? active
                ? Colors.white
                : const Color(0xe6ffffff)
            : const Color(0xe6080c12);
    return Tooltip(
      message: widget.tooltip,
      child: TextButton(
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          backgroundColor: Colors.transparent,
          foregroundColor: iconColor,
        ),
        onHover: (value) {
          setState(() {
            _hovered = value;
          });
        },
        onFocusChange: (value) {
          setState(() {
            _focused = value;
          });
        },
        onPressed: widget.onPressed,
        child: AnimatedContainer(
          key: const ValueKey('NowPlayingFull.ExitArtworkShell'),
          duration: const Duration(milliseconds: 140),
          curve: Curves.ease,
          width: size,
          height: size,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: shellBorderColor),
            color:
                dark
                    ? active
                        ? const Color(0x24ffffff)
                        : const Color(0x14ffffff)
                    : active
                    ? const Color(0x1f212b3a)
                    : Colors.transparent,
            gradient:
                dark && !active
                    ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0x1fffffff), Color(0x0affffff)],
                    )
                    : null,
            boxShadow:
                dark
                    ? [
                      BoxShadow(
                        color:
                            active
                                ? const Color(0x4d000000)
                                : const Color(0x57000000),
                        blurRadius: active ? 30 : 28,
                        offset: const Offset(0, 12),
                      ),
                    ]
                    : null,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (dark)
                const ColoredBox(
                  key: ValueKey('NowPlayingFull.ExitAlbumSwatch'),
                  color: Colors.transparent,
                ),
              if (dark)
                BackdropFilter(
                  key: const ValueKey('NowPlayingFull.ExitArtworkBackdrop'),
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: _NowPlayingFullExitOverlay(
                    color: const Color(0x6b080c12),
                    iconColor: iconColor,
                    shadows: const [
                      Shadow(
                        color: Color(0x57000000),
                        offset: Offset(0, 2),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                )
              else
                _NowPlayingFullExitOverlay(
                  color: Colors.transparent,
                  iconColor: iconColor,
                  shadows: const [],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NowPlayingFullExitOverlay extends StatelessWidget {
  const _NowPlayingFullExitOverlay({
    required this.color,
    required this.iconColor,
    required this.shadows,
  });

  final Color color;
  final Color iconColor;
  final List<Shadow> shadows;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const ValueKey('NowPlayingFull.ExitArtworkOverlay'),
      decoration: BoxDecoration(color: color),
      child: Center(
        child: ExitFullscreenIcon(
          key: const ValueKey('NowPlayingFull.ExitIcon'),
          size: 36,
          color: iconColor,
          strokeWidth: 2,
          shadows: shadows,
        ),
      ),
    );
  }
}

class _NowPlayingFullErrorBanner extends StatelessWidget {
  const _NowPlayingFullErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(minHeight: 38),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0x6b5c0c14),
          border: Border.all(color: const Color(0x47ff7373)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          message,
          style: const TextStyle(
            color: Color(0xf0ffebeb),
            fontSize: 14,
            fontWeight: FontWeight.w600,
            height: 1.28,
          ),
        ),
      ),
    );
  }
}

class _NowPlayingFullCurrentQueueAnchor extends StatefulWidget {
  const _NowPlayingFullCurrentQueueAnchor({
    required this.currentIndex,
    required this.child,
  });

  final int currentIndex;
  final Widget child;

  @override
  State<_NowPlayingFullCurrentQueueAnchor> createState() =>
      _NowPlayingFullCurrentQueueAnchorState();
}

class _NowPlayingFullCurrentQueueAnchorState
    extends State<_NowPlayingFullCurrentQueueAnchor> {
  @override
  void initState() {
    super.initState();
    _scrollIntoView();
  }

  @override
  void didUpdateWidget(_NowPlayingFullCurrentQueueAnchor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _scrollIntoView();
    }
  }

  void _scrollIntoView() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Scrollable.ensureVisible(
          context,
          alignment: 0.5,
          duration: Duration.zero,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class _NowPlayingFullQueuePopoverHost extends StatefulWidget {
  const _NowPlayingFullQueuePopoverHost({
    required this.open,
    required this.fullScreen,
    required this.child,
  });

  final bool open;
  final bool fullScreen;
  final Widget child;

  @override
  State<_NowPlayingFullQueuePopoverHost> createState() =>
      _NowPlayingFullQueuePopoverHostState();
}

class _NowPlayingFullQueuePopoverHostState
    extends State<_NowPlayingFullQueuePopoverHost> {
  var _mountedForAnimation = false;

  @override
  void initState() {
    super.initState();
    _mountedForAnimation = widget.open;
  }

  @override
  void didUpdateWidget(_NowPlayingFullQueuePopoverHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.open && !_mountedForAnimation) {
      setState(() {
        _mountedForAnimation = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_mountedForAnimation) {
      return const SizedBox.shrink();
    }

    return IgnorePointer(
      ignoring: !widget.open,
      child: ExcludeSemantics(
        excluding: !widget.open,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: widget.open ? 1 : 0,
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 260),
            curve: const Cubic(0.22, 1, 0.36, 1),
            offset:
                widget.open
                    ? Offset.zero
                    : widget.fullScreen
                    ? const Offset(0, 1)
                    : const Offset(1.08, 0),
            onEnd: () {
              if (!widget.open && mounted) {
                setState(() {
                  _mountedForAnimation = false;
                });
              }
            },
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class _NowPlayingFullPlaylist extends StatefulWidget {
  const _NowPlayingFullPlaylist({
    required this.open,
    required this.i18n,
    required this.songs,
    required this.songIds,
    required this.mediaControlState,
    required this.loading,
    required this.selection,
    required this.scrollController,
    required this.playlists,
    required this.defaultNewPlaylistName,
    required this.folders,
    required this.onClose,
    required this.onReorder,
    required this.onReplaceQueue,
    required this.currentQueueSongIds,
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
    required this.fullScreen,
    required this.coverColor,
    required this.hideMultiSelectCommandBarAfterOperation,
  });

  final bool open;
  final SmPlayerI18n i18n;
  final List<LibrarySong> songs;
  final List<int> songIds;
  final MediaControlState mediaControlState;
  final bool loading;
  final PageSelectionController<int> selection;
  final ScrollController scrollController;
  final List<MultiSelectCommandBarPlaylist> playlists;
  final String defaultNewPlaylistName;
  final List<LibraryFolder> folders;
  final VoidCallback onClose;
  final void Function(List<int>, int, int) onReorder;
  final ValueChanged<List<int>> onReplaceQueue;
  final List<int> Function() currentQueueSongIds;
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
  final ValueChanged<SongDialogMode> onOpenSongDialog;
  final ValueChanged<String> onRevealSong;
  final bool fullScreen;
  final Color coverColor;
  final bool hideMultiSelectCommandBarAfterOperation;

  @override
  State<_NowPlayingFullPlaylist> createState() =>
      _NowPlayingFullPlaylistState();
}

class _NowPlayingFullPlaylistState extends State<_NowPlayingFullPlaylist> {
  ({int queueIndex, PlaylistControlDropPosition position})? _dropIndicator;
  int? _draggedQueueIndex;

  SmPlayerI18n get i18n => widget.i18n;
  List<LibrarySong> get songs => widget.songs;
  List<int> get songIds => widget.songIds;
  MediaControlState get mediaControlState => widget.mediaControlState;
  bool get loading => widget.loading;
  PageSelectionController<int> get selection => widget.selection;
  ScrollController get scrollController => widget.scrollController;
  List<MultiSelectCommandBarPlaylist> get playlists => widget.playlists;
  String get defaultNewPlaylistName => widget.defaultNewPlaylistName;
  List<LibraryFolder> get folders => widget.folders;
  VoidCallback get onClose => widget.onClose;
  void Function(List<int>, int, int) get onReorder => widget.onReorder;
  ValueChanged<List<int>> get onReplaceQueue => widget.onReplaceQueue;
  List<int> Function() get currentQueueSongIds => widget.currentQueueSongIds;
  ValueChanged<List<int>> get onPlaySongs => widget.onPlaySongs;
  void Function(LibrarySong, List<int>, int) get onPlayTrack =>
      widget.onPlayTrack;
  VoidCallback get onTogglePlayPause => widget.onTogglePlayPause;
  void Function(List<int>, int) get onPlayNext => widget.onPlayNext;
  void Function(List<int>, int) get onRemove => widget.onRemove;
  VoidCallback get onSelectionChanged => widget.onSelectionChanged;
  Future<void> Function(int, List<int>) get onAddToPlaylist =>
      widget.onAddToPlaylist;
  Future<void> Function(List<int>, bool) get onToggleFavorite =>
      widget.onToggleFavorite;
  Future<void> Function(String, List<int>) get onCreatePlaylist =>
      widget.onCreatePlaylist;
  ValueChanged<LibrarySong> get onAddToNowPlaying => widget.onAddToNowPlaying;
  Future<String?> Function(int) get onGetPreferenceLevel =>
      widget.onGetPreferenceLevel;
  Future<void> Function(int) get onUndoPreference => widget.onUndoPreference;
  Future<void> Function(int, String, String) get onSetPreference =>
      widget.onSetPreference;
  Future<void> Function(LibrarySong) get onDeleteSongFromDisk =>
      widget.onDeleteSongFromDisk;
  Future<void> Function(LibrarySong) get onHideSongFile =>
      widget.onHideSongFile;
  Future<void> Function(LibrarySong, String) get onMoveSongToFolder =>
      widget.onMoveSongToFolder;
  ValueChanged<SongDialogMode> get onOpenSongDialog => widget.onOpenSongDialog;
  ValueChanged<String> get onRevealSong => widget.onRevealSong;
  bool get fullScreen => widget.fullScreen;
  Color get coverColor => widget.coverColor;
  bool get hideMultiSelectCommandBarAfterOperation =>
      widget.hideMultiSelectCommandBarAfterOperation;

  @override
  void initState() {
    super.initState();
    _pruneSelection();
    _scrollCurrentRowIntoView();
  }

  @override
  void didUpdateWidget(_NowPlayingFullPlaylist oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.songs.length != widget.songs.length) {
      _pruneSelection();
    }
    if ((widget.open && !oldWidget.open) ||
        (widget.open &&
            (oldWidget.mediaControlState.selectedQueueIndex !=
                    widget.mediaControlState.selectedQueueIndex ||
                oldWidget.mediaControlState.track.id !=
                    widget.mediaControlState.track.id ||
                oldWidget.songs.length != widget.songs.length))) {
      _scrollCurrentRowIntoView();
    }
  }

  int? _currentQueueIndex() {
    final selectedQueueIndex = mediaControlState.selectedQueueIndex;
    if (selectedQueueIndex != null &&
        selectedQueueIndex >= 0 &&
        selectedQueueIndex < songs.length) {
      return selectedQueueIndex;
    }
    final trackId = mediaControlState.track.id;
    final trackIndex = songs.indexWhere((song) => song.id == trackId);
    return trackIndex == -1 ? null : trackIndex;
  }

  void _scrollCurrentRowIntoView([int attempt = 0]) {
    if (!widget.open) {
      return;
    }
    final currentIndex = _currentQueueIndex();
    if (currentIndex == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (!scrollController.hasClients) {
        if (attempt < 3) {
          _scrollCurrentRowIntoView(attempt + 1);
        }
        return;
      }
      final position = scrollController.position;
      if (position.maxScrollExtent == position.minScrollExtent &&
          songs.length * _nowPlayingFullQueueRowHeight >
              position.viewportDimension) {
        if (attempt < 3) {
          _scrollCurrentRowIntoView(attempt + 1);
        }
        return;
      }
      final topPadding = _listPadding().top;
      final target =
          topPadding +
          currentIndex * _nowPlayingFullQueueRowHeight +
          _nowPlayingFullQueueRowHeight / 2 -
          position.viewportDimension / 2;
      scrollController.jumpTo(
        target
            .clamp(position.minScrollExtent, position.maxScrollExtent)
            .toDouble(),
      );
    });
  }

  void _pruneSelection() {
    final nextSelected = {
      for (final index in widget.selection.selectedItems)
        if (index >= 0 && index < widget.songs.length) index,
    };
    if (nextSelected.length == widget.selection.selectedItems.length) {
      return;
    }
    widget.selection.replaceSelection(nextSelected);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.onSelectionChanged();
      }
    });
  }

  void _moveQueueSongToDropTarget(
    List<int> queueSongIds,
    int draggedIndex,
    int targetIndex,
    PlaylistControlDropPosition position,
  ) {
    onReplaceQueue(
      moveNowPlayingFullQueueSongIds(
        queueSongIds,
        draggedIndex,
        targetIndex,
        position == PlaylistControlDropPosition.after,
      ),
    );
  }

  PlaylistControlDropPosition _dropPositionFor(
    BuildContext context,
    Offset globalPosition,
  ) {
    final box = context.findRenderObject() as RenderBox;
    final local = box.globalToLocal(globalPosition);
    return local.dy > box.size.height / 2
        ? PlaylistControlDropPosition.after
        : PlaylistControlDropPosition.before;
  }

  void _clearQueueDrop() {
    setState(() {
      _dropIndicator = null;
      _draggedQueueIndex = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = NowPlayingFullThemeColors.of(context);
    final night = colors.artworkShadowOpacity > 0.3;
    final panelColor =
        night ? const Color(0xdb12100e) : const Color(0xd1ffffff);
    final borderColor =
        night ? const Color(0x2effffff) : const Color(0xc2ccd5e0);
    final decoration = BoxDecoration(
      color: panelColor,
      gradient:
          night
              ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0x70775b20),
                  Color(0x2e14120e),
                  Colors.transparent,
                ],
                stops: [0, 0.38, 0.64],
              )
              : RadialGradient(
                center: const Alignment(-0.6, -0.56),
                radius: 0.84,
                colors: [
                  coverColor.withValues(alpha: 0.24),
                  Colors.transparent,
                ],
                stops: const [0, 1],
              ),
      borderRadius: BorderRadius.circular(fullScreen ? 0 : 18),
      border: Border.all(color: borderColor),
      boxShadow: [
        BoxShadow(
          color: night ? const Color(0x61000000) : const Color(0x2e445870),
          blurRadius: 76,
          offset: const Offset(0, 28),
        ),
      ],
    );
    final backgroundDecoration = BoxDecoration(
      color: panelColor,
      gradient:
          night
              ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0x70775b20),
                  Color(0x2e14120e),
                  Colors.transparent,
                ],
                stops: [0, 0.38, 0.64],
              )
              : RadialGradient(
                center: const Alignment(-0.6, -0.56),
                radius: 0.84,
                colors: [
                  coverColor.withValues(alpha: 0.24),
                  Colors.transparent,
                ],
                stops: const [0, 1],
              ),
    );
    if (songs.isEmpty) {
      return DecoratedBox(
        decoration: decoration,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(fullScreen ? 0 : 18),
          child: GlassContainer(
            key: const ValueKey('NowPlayingFull.QueuePanelGlass'),
            useOwnLayer: true,
            quality: GlassQuality.standard,
            shape: LiquidRoundedRectangle(borderRadius: fullScreen ? 0 : 18),
            settings: LiquidGlassSettings(
              blur: 42,
              thickness: 30,
              refractiveIndex: 1.08,
              saturation: 1.34,
              chromaticAberration: 0.018,
              lightIntensity: night ? 0.24 : 0.34,
              ambientStrength: 0.16,
              glowIntensity: night ? 0.18 : 0.28,
              glassColor: panelColor,
              standardOpacityMultiplier: 0.82,
            ),
            clipBehavior: Clip.hardEdge,
            allowElevation: false,
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    key: const ValueKey('NowPlayingFull.QueuePanelBackground'),
                    decoration: backgroundDecoration,
                  ),
                ),
                _QueueEmptyState(loading: loading),
              ],
            ),
          ),
        ),
      );
    }
    return DecoratedBox(
      decoration: decoration,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(fullScreen ? 0 : 18),
        child: GlassContainer(
          key: const ValueKey('NowPlayingFull.QueuePanelGlass'),
          useOwnLayer: true,
          quality: GlassQuality.standard,
          shape: LiquidRoundedRectangle(borderRadius: fullScreen ? 0 : 18),
          settings: LiquidGlassSettings(
            blur: 42,
            thickness: 30,
            refractiveIndex: 1.08,
            saturation: 1.34,
            chromaticAberration: 0.018,
            lightIntensity: night ? 0.24 : 0.34,
            ambientStrength: 0.16,
            glowIntensity: night ? 0.18 : 0.28,
            glassColor: panelColor,
            standardOpacityMultiplier: 0.82,
          ),
          clipBehavior: Clip.hardEdge,
          allowElevation: false,
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  key: const ValueKey('NowPlayingFull.QueuePanelBackground'),
                  decoration: backgroundDecoration,
                ),
              ),
              Column(
                children: [
                  Padding(
                    padding:
                        fullScreen
                            ? const EdgeInsets.fromLTRB(20, 26, 20, 14)
                            : const EdgeInsets.fromLTRB(30, 26, 20, 14),
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
                                  fontWeight: FontWeight.w800,
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
                                  color:
                                      night
                                          ? const Color(0xb8ffffff)
                                          : colors.muted,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _NowPlayingFullQueueCloseButton(
                          tooltip: i18n.t('common.close'),
                          onPressed: onClose,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child:
                        songs.isEmpty
                            ? _QueueEmptyState(loading: loading)
                            : _buildQueueList(context),
                  ),
                ],
              ),
              MultiSelectCommandBar(
                visible: selection.multiSelect,
                selectedCount: selection.selectedItems.length,
                playlists: playlists,
                addToSongIds: _selectedSongIds(),
                defaultPlaylistName: defaultNewPlaylistName,
                currentPlaylistName: i18n.t('common.nowPlaying'),
                includeFavoritesInAddTo: _selectedSongsHaveUnfavorited(),
                removeLabel: i18n.t('nowPlaying.remove'),
                hideAfterOperation: hideMultiSelectCommandBarAfterOperation,
                onToggleFavorite: () {
                  final songIds = _selectedUnfavoritedSongIds();
                  onToggleFavorite(songIds, true);
                  final songsById = {for (final song in songs) song.id: song};
                  showUndoableSnackBar(
                    context: context,
                    i18n: i18n,
                    message: songsAddedUndoMessage(
                      i18n: i18n,
                      songIds: songIds,
                      songsById: songsById,
                      target: i18n.t('common.myFavorites'),
                    ),
                    onUndo: () => onToggleFavorite(songIds, false),
                  );
                },
                onAddToPlaylist: (playlistId) {
                  onAddToPlaylist(playlistId, _selectedSongIds());
                  selection.hideAfterOperation(
                    hideMultiSelectCommandBarAfterOperation,
                  );
                  onSelectionChanged();
                },
                onPlay: () {
                  onPlaySongs(_selectedSongIds());
                  selection.hideAfterOperation(
                    hideMultiSelectCommandBarAfterOperation,
                  );
                  onSelectionChanged();
                },
                onRemove: () {
                  final selectedIndexes =
                      selection.selectedItems.toList()..sort();
                  final selectedSongIds = _selectedSongIds();
                  final insertIndex = selectedIndexes.first;
                  final songsById = {for (final song in songs) song.id: song};
                  final nextSongIds = [
                    for (var index = 0; index < songIds.length; index += 1)
                      if (!selectedIndexes.contains(index)) songIds[index],
                  ];
                  onReplaceQueue(nextSongIds);
                  showUndoableSnackBar(
                    context: context,
                    i18n: i18n,
                    message: songsRemovedUndoMessage(
                      i18n: i18n,
                      songIds: selectedSongIds,
                      songsById: songsById,
                      target: i18n.t('common.nowPlaying'),
                    ),
                    onUndo:
                        () => onReplaceQueue(
                          _insertQueueSongs(
                            currentQueueSongIds(),
                            insertIndex,
                            selectedSongIds,
                          ),
                        ),
                  );
                  selection.clearSelection();
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
      ),
    );
  }

  Widget _buildQueueList(BuildContext context) {
    return ListView.builder(
      key: const ValueKey('NowPlayingFull.QueueList'),
      controller: scrollController,
      padding: _listPadding(),
      itemCount: songs.length,
      itemBuilder: (context, index) {
        final song = songs[index];
        final current =
            mediaControlState.selectedQueueIndex == null
                ? song.id == mediaControlState.track.id
                : index == mediaControlState.selectedQueueIndex;
        final dropPosition =
            _dropIndicator?.queueIndex == index
                ? _dropIndicator?.position
                : null;
        final item = PlaylistControlItem(
          key: ValueKey('now-playing-full-row-${song.id}-$index'),
          song: song,
          current: current,
          playing: current && mediaControlState.isPlaying,
          selected: selection.isSelected(index),
          selectionMode: selection.multiSelect,
          dropPosition: dropPosition,
          variant: PlaylistControlItemVariant.compact,
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
          onRemoveFromListClick: () {
            onRemove(songIds, index);
            showUndoableSnackBar(
              context: context,
              i18n: i18n,
              message: i18n.t('notification.removedFrom', {
                'title': song.title,
                'target': i18n.t('common.nowPlaying'),
              }),
              onUndo:
                  () => onReplaceQueue(
                    _insertQueueSongs(currentQueueSongIds(), index, [song.id]),
                  ),
            );
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
            context.go('/artists?artist=${Uri.encodeComponent(artist)}');
            onClose();
          },
          onOpenContextMenu: (position) {
            _showQueueContextMenu(context, position, song, index);
          },
        );
        final anchoredItem =
            current
                ? _NowPlayingFullCurrentQueueAnchor(
                  currentIndex: index,
                  child: item,
                )
                : item;
        final rowItem =
            fullScreen
                ? Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: anchoredItem,
                )
                : anchoredItem;
        return DragTarget<int>(
          key: ValueKey('now-playing-full-target-${song.id}-$index'),
          onMove: (details) {
            final position = _dropPositionFor(context, details.offset);
            setState(() {
              _dropIndicator = (queueIndex: index, position: position);
            });
          },
          onLeave: (_) {
            if (_dropIndicator?.queueIndex == index) {
              setState(() {
                _dropIndicator = null;
              });
            }
          },
          onAcceptWithDetails: (details) {
            final draggedIndex = _draggedQueueIndex ?? details.data;
            final position =
                _dropIndicator?.queueIndex == index
                    ? _dropIndicator!.position
                    : _dropPositionFor(context, details.offset);
            _clearQueueDrop();
            _moveQueueSongToDropTarget(songIds, draggedIndex, index, position);
          },
          builder: (context, _, _) {
            return LayoutBuilder(
              builder: (context, constraints) {
                return Draggable<int>(
                  data: index,
                  axis: Axis.vertical,
                  affinity: Axis.vertical,
                  feedback: SizedBox(
                    width: constraints.maxWidth,
                    child: Material(
                      color: Colors.transparent,
                      child: Opacity(opacity: 0.92, child: rowItem),
                    ),
                  ),
                  childWhenDragging: Opacity(opacity: 0.42, child: rowItem),
                  onDragStarted: () {
                    setState(() {
                      _draggedQueueIndex = index;
                      _dropIndicator = null;
                    });
                  },
                  onDraggableCanceled: (_, _) {
                    _clearQueueDrop();
                  },
                  onDragEnd: (_) {
                    _clearQueueDrop();
                  },
                  child: rowItem,
                );
              },
            );
          },
        );
      },
    );
  }

  List<int> _selectedSongIds() {
    return [
      for (var index = 0; index < songIds.length; index += 1)
        if (selection.selectedItems.contains(index)) songIds[index],
    ];
  }

  EdgeInsets _listPadding() {
    if (selection.multiSelect) {
      return EdgeInsets.fromLTRB(
        fullScreen ? 10 : 16,
        fullScreen ? 0 : 4,
        fullScreen ? 0 : 8,
        multiSelectCommandBarScrollSpacer,
      );
    }
    return fullScreen
        ? const EdgeInsets.fromLTRB(10, 0, 0, 2)
        : const EdgeInsets.fromLTRB(16, 4, 8, 22);
  }

  List<int> _selectedUnfavoritedSongIds() {
    return [
      for (var index = 0; index < songs.length; index += 1)
        if (selection.selectedItems.contains(index) && !songs[index].favorite)
          songs[index].id,
    ];
  }

  bool _selectedSongsHaveUnfavorited() {
    for (var index = 0; index < songs.length; index += 1) {
      if (selection.selectedItems.contains(index) && !songs[index].favorite) {
        return true;
      }
    }
    return false;
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
      defaultPlaylistName: _nextPlaylistName(song.title),
      onToggleFavorite: () {
        onToggleFavorite([song.id], true);
        showUndoableSnackBar(
          context: buttonContext,
          i18n: i18n,
          message: i18n.t('notification.songAddedTo', {
            'title': song.title,
            'target': i18n.t('common.myFavorites'),
          }),
          onUndo: () => onToggleFavorite([song.id], false),
        );
      },
      onCreatePlaylistWithName: (name) {
        onCreatePlaylist(name, [song.id]);
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
    List<MenuFlyoutItem> buildItems(String? preferenceLevel) {
      return buildMusicMenuFlyoutItems(
        i18n: i18n,
        songId: song.id,
        isFavorite: song.favorite,
        isCurrentTrack: song.id == currentTrackId,
        isPlaying: mediaControlState.isPlaying,
        currentTrackId: currentTrackId,
        currentPlaylistName: i18n.t('common.nowPlaying'),
        excludePlaylistName: '',
        defaultPlaylistName: song.title,
        songPath: song.path,
        playlists: playlists,
        folders: menuFolders,
        showRemove: true,
        showAlbumArt: false,
        keepViewActionsOpen: false,
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
          onCreatePlaylist(_nextPlaylistName(song.title), [song.id]);
        },
        onCreatePlaylistWithName: (name) {
          onCreatePlaylist(name, [song.id]);
        },
        onAddToPlaylist: (playlistId) {
          onAddToPlaylist(playlistId, [song.id]);
        },
        onRemove: () {
          onRemove(songIds, queueIndex);
          showUndoableSnackBar(
            context: context,
            i18n: i18n,
            message: i18n.t('notification.removedFrom', {
              'title': song.title,
              'target': i18n.t('common.nowPlaying'),
            }),
            onUndo:
                () => onReplaceQueue(
                  _insertQueueSongs(currentQueueSongIds(), queueIndex, [
                    song.id,
                  ]),
                ),
          );
        },
        onSelect: () {
          selection.replaceSelection({queueIndex});
          onSelectionChanged();
        },
        onToggleFavorite: () {
          final nextFavorite = !song.favorite;
          onToggleFavorite([song.id], nextFavorite);
          showUndoableSnackBar(
            context: context,
            i18n: i18n,
            message: i18n.t(
              nextFavorite
                  ? 'notification.songAddedTo'
                  : 'notification.removedFrom',
              {'title': song.title, 'target': i18n.t('common.myFavorites')},
            ),
            onUndo: () => onToggleFavorite([song.id], song.favorite),
          );
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
            '/artists?artist=${Uri.encodeComponent(_primaryArtist(song, i18n))}',
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
          onOpenSongDialog(SongDialogMode.properties);
        },
        onSeeLyrics: () {
          onOpenSongDialog(SongDialogMode.lyrics);
        },
        onSeeAlbumArt: () {
          onOpenSongDialog(SongDialogMode.albumArt);
        },
        onSeeLocal: () {
          onRevealSong(song.path);
        },
      );
    }

    final itemsNotifier = ValueNotifier<List<MenuFlyoutItem>>(buildItems(null));
    var menuClosed = false;
    unawaited(
      onGetPreferenceLevel(song.id).then((preferenceLevel) {
        if (!menuClosed) {
          itemsNotifier.value = buildItems(preferenceLevel);
        }
      }),
    );
    await showMenuFlyout(
      context,
      position: position,
      avoidPlayerBar: false,
      items: itemsNotifier.value,
      itemsListenable: itemsNotifier,
    );
    menuClosed = true;
    itemsNotifier.dispose();
  }
}

class _NowPlayingFullQueueCloseButton extends StatelessWidget {
  const _NowPlayingFullQueueCloseButton({
    required this.tooltip,
    required this.onPressed,
  });

  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = NowPlayingFullThemeColors.of(context);
    final night = colors.artworkShadowOpacity > 0.3;
    final glassColor =
        night ? const Color(0x1cffffff) : const Color(0x86ffffff);
    final foregroundColor =
        night ? const Color(0xd6ffffff) : _NowPlayingFullColors.dayText;
    return Tooltip(
      message: tooltip,
      child: GlassContainer(
        key: const ValueKey('NowPlayingFull.QueueCloseButton'),
        width: 42,
        height: 42,
        useOwnLayer: true,
        quality: GlassQuality.standard,
        shape: const LiquidRoundedRectangle(borderRadius: 10),
        settings: LiquidGlassSettings(
          blur: night ? 28 : 34,
          thickness: 24,
          refractiveIndex: 1.1,
          saturation: night ? 1.2 : 1.34,
          chromaticAberration: 0.016,
          lightIntensity: night ? 0.24 : 0.34,
          ambientStrength: night ? 0.14 : 0.18,
          glowIntensity: 0.22,
          glassColor: glassColor,
          standardOpacityMultiplier: night ? 0.86 : 0.78,
        ),
        clipBehavior: Clip.hardEdge,
        allowElevation: false,
        child: TextButton(
          style: TextButton.styleFrom(
            fixedSize: const Size.square(42),
            minimumSize: const Size.square(42),
            maximumSize: const Size.square(42),
            padding: EdgeInsets.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            foregroundColor: foregroundColor,
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: onPressed,
          child: const Icon(FluentIcons.dismiss_20_regular, size: 18),
        ),
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

List<int> _insertQueueSongs(
  List<int> queueSongIds,
  int insertIndex,
  List<int> insertedSongIds,
) {
  final index =
      insertIndex < 0
          ? 0
          : insertIndex > queueSongIds.length
          ? queueSongIds.length
          : insertIndex;
  return [
    ...queueSongIds.take(index),
    ...insertedSongIds,
    ...queueSongIds.skip(index),
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
  const _QueueEmptyState({required this.loading});

  final bool loading;

  @override
  Widget build(BuildContext context) {
    return loading
        ? const SmPlayerLoadingState(compact: true)
        : const SizedBox.shrink();
  }
}

class _NowPlayingFullColors {
  const _NowPlayingFullColors._();

  static const accentStrong = Color(0xff0063b1);
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
    required this.topButtonBackground,
    required this.topButtonForeground,
    required this.topButtonActiveForeground,
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
  final Color topButtonBackground;
  final Color topButtonForeground;
  final Color topButtonActiveForeground;
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
    topButtonBackground: Color(0xa8ffffff),
    topButtonForeground: _NowPlayingFullColors.dayText,
    topButtonActiveForeground: _NowPlayingFullColors.accentStrong,
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
    topButtonBackground: Color(0x14ffffff),
    topButtonForeground: Color(0xe0ffffff),
    topButtonActiveForeground: Colors.white,
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
