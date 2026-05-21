import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smplayer_flutter/src/app/app_appearance_model.dart';
import 'package:smplayer_flutter/src/app/app_route_model.dart';
import 'package:smplayer_flutter/src/app/input_dialog.dart';
import 'package:smplayer_flutter/src/app/main_navigation_view.dart';
import 'package:smplayer_flutter/src/app/undoable_notification.dart';
import 'package:smplayer_flutter/src/app/voice_assistant_model.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
import 'package:smplayer_flutter/src/library/data/library_repository.dart';
import 'package:smplayer_flutter/src/library/ui/headered_playlist_model.dart';
import 'package:smplayer_flutter/src/library/ui/library_page_actions.dart';
import 'package:smplayer_flutter/src/library/ui/music_dialog.dart';
import 'package:smplayer_flutter/src/platform/desktop_features.dart';
import 'package:smplayer_flutter/src/platform/external_open_model.dart';
import 'package:smplayer_flutter/src/playback/media_control.dart';
import 'package:smplayer_flutter/src/playback/media_control_model.dart';
import 'package:smplayer_flutter/src/playback/media_control_provider.dart';
import 'package:smplayer_flutter/src/playback/quick_play_model.dart';
import 'package:smplayer_flutter/src/settings/settings_controller.dart';
import 'package:smplayer_flutter/src/settings/settings_model.dart';
import 'package:smplayer_flutter/src/settings/settings_page.dart'
    show ArtistSplitReviewDialog, ReleaseNotesDialog;
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

class SmPlayerShellMetrics {
  const SmPlayerShellMetrics._();

  static const playerHeight = 120.0;
  static const playerTopRadius = 18.0;
  static const sidebarWidth = 320.0;
  static const collapsedSidebarWidth = 64.0;
  static const navigationMinimalBreakpoint = 720.0;
  static const navigationOverlayBreakpoint = 1200.0;

  static SmPlayerNavigationMode navigationModeForWidth(double width) {
    if (width < navigationMinimalBreakpoint) {
      return SmPlayerNavigationMode.minimal;
    }

    if (width < navigationOverlayBreakpoint) {
      return SmPlayerNavigationMode.overlay;
    }

    return SmPlayerNavigationMode.wide;
  }
}

enum SmPlayerNavigationMode { minimal, overlay, wide }

enum SmPlayerPlaybackShortcut {
  togglePlayPause,
  next,
  previous,
  seekForwardShort,
  seekBackwardShort,
  seekForwardLong,
  seekBackwardLong,
  toggleShuffle,
  toggleRepeat,
  toggleRepeatOne,
}

SmPlayerPlaybackShortcut? playbackShortcutForKey({
  required LogicalKeyboardKey key,
  required bool control,
  required bool alt,
  required bool meta,
  required bool shift,
}) {
  if (key == LogicalKeyboardKey.space) {
    return SmPlayerPlaybackShortcut.togglePlayPause;
  }

  if (alt && !control && !meta) {
    if (key == LogicalKeyboardKey.keyS) {
      return SmPlayerPlaybackShortcut.toggleShuffle;
    }
    if (key == LogicalKeyboardKey.keyR) {
      return SmPlayerPlaybackShortcut.toggleRepeat;
    }
    if (key == LogicalKeyboardKey.digit1) {
      return SmPlayerPlaybackShortcut.toggleRepeatOne;
    }
  }

  if (alt || meta) {
    return null;
  }

  if (control && key == LogicalKeyboardKey.arrowRight) {
    return SmPlayerPlaybackShortcut.next;
  }
  if (control && key == LogicalKeyboardKey.arrowLeft) {
    return SmPlayerPlaybackShortcut.previous;
  }

  if (key == LogicalKeyboardKey.arrowRight) {
    return shift
        ? SmPlayerPlaybackShortcut.seekForwardLong
        : SmPlayerPlaybackShortcut.seekForwardShort;
  }
  if (key == LogicalKeyboardKey.arrowLeft) {
    return shift
        ? SmPlayerPlaybackShortcut.seekBackwardLong
        : SmPlayerPlaybackShortcut.seekBackwardShort;
  }

  return null;
}

int compareAppVersions(String left, String right) {
  final leftParts = left.split('.').map(int.parse).toList();
  final rightParts = right.split('.').map(int.parse).toList();
  final length = max(leftParts.length, rightParts.length);

  for (var index = 0; index < length; index += 1) {
    final leftPart = index < leftParts.length ? leftParts[index] : 0;
    final rightPart = index < rightParts.length ? rightParts[index] : 0;
    if (leftPart != rightPart) {
      return leftPart - rightPart;
    }
  }

  return 0;
}

class SmPlayerShellKeys {
  const SmPlayerShellKeys._();

  static const sidebar = ValueKey('SmPlayerShell.Sidebar');
  static const workspace = ValueKey('SmPlayerShell.Workspace');
  static const reservedPlayer = ValueKey('SmPlayerShell.ReservedPlayer');
}

class SmPlayerShellStorageKeys {
  const SmPlayerShellStorageKeys._();

  static const navigationCollapsed = 'smplayer:navigation-collapsed';
}

class SmPlayerShellPage extends ConsumerStatefulWidget {
  const SmPlayerShellPage({
    super.key,
    this.child,
    this.currentPath,
    this.canGoBack = false,
    this.onNavigate,
    this.onGoBack,
    this.onSearchCommit,
    this.desktopFeatureService,
    this.settingsRepository,
    this.appVersion,
    this.initialExternalFilePaths = const [],
    this.initialExternalCommands = const [],
  });

  final Widget? child;
  final String? currentPath;
  final bool canGoBack;
  final ValueChanged<String>? onNavigate;
  final VoidCallback? onGoBack;
  final MainNavigationSearchCommit? onSearchCommit;
  final DesktopFeatureService? desktopFeatureService;
  final LibraryRepository? settingsRepository;
  final String? appVersion;
  final List<String> initialExternalFilePaths;
  final List<ExternalAppCommand> initialExternalCommands;

  @override
  ConsumerState<SmPlayerShellPage> createState() => _SmPlayerShellPageState();
}

class _SmPlayerShellPageState extends ConsumerState<SmPlayerShellPage> {
  static const _playbackStallCheckInterval = Duration(milliseconds: 500);
  static const _playbackStallTimeout = Duration(seconds: 8);

  late final SettingsController _settingsController;
  late final MediaControlController _mediaControlController;
  late final DesktopFeatureService _desktopFeatureService;
  late final AudioPlayer _audioPlayer;
  late final List<StreamSubscription<Object?>> _audioSubscriptions;
  var _isNavigationPaneOpen = true;
  var _isMinimalNavigationOpen = false;
  var _isMiniMode = false;
  var _isWindowVisible = true;
  var _isWindowFullScreen = false;
  var _syncingAudioPlayer = false;
  var _audioLoadSerial = 0;
  SmPlayerNavigationMode? _navigationMode;
  var _currentPath = '/songs';
  var _searchText = '';
  int? _loadedAudioTrackId;
  String? _loadedAudioPath;
  int? _finishingAudioTrackId;
  final _failedAudioTrackIds = <int>{};
  final _persistedAudioDurations = <int, int>{};
  Timer? _playbackStallTimer;
  double _stalledProgressSeconds = 0;
  DateTime? _stalledProgressStartedAt;
  ({LibrarySong song, SongDialogMode mode})? _playerDialog;
  String? _lastDesktopTraySignature;
  String? _lastDesktopLyricsSignature;
  String? _lastMediaSessionSignature;
  bool? _lastWindowControlsLight;
  int? _desktopLyricsSongId;
  int? _desktopLyricsLoadingSongId;
  LyricsRequestMode? _desktopLyricsMode;
  LyricsSnapshot? _desktopLyrics;
  String? _releaseNotesDialogVersion;
  var _releaseNotesChecked = false;
  ArtistSplitAnalysisResult? _startupArtistSplitResult;
  var _startupArtistSplitChecked = false;
  var _startupArtistSplitApplying = false;
  int? _lastNotifiedSongId;
  String? _lastPersistedPage;
  late final Future<SharedPreferences> _preferencesFuture;

  @override
  void initState() {
    super.initState();
    _settingsController = SettingsController(null, widget.settingsRepository);
    _preferencesFuture = SharedPreferences.getInstance();
    _mediaControlController = MediaControlController(
      null,
      _settingsController.savePlaybackSettingsImmediate,
    );
    _audioPlayer = AudioPlayer();
    _mediaControlController.addListener(_syncAudioPlayerFromController);
    _audioSubscriptions = [
      _audioPlayer.positionStream.listen(_handleAudioPositionChanged),
      _audioPlayer.durationStream.listen(_handleAudioDurationChanged),
      _audioPlayer.playerStateStream.listen(_handleAudioPlayerStateChanged),
    ];
    _desktopFeatureService =
        widget.desktopFeatureService ?? createDesktopFeatureService();
    unawaited(_desktopFeatureService.initialize(_handleDesktopFeatureAction));
    unawaited(_restoreDesktopWindowFullScreenState());
    unawaited(ref.read(libraryRepositoryProvider).commitPendingDeletes());
    _restorePlaybackRuntimeSettings();
    _restoreNavigationPaneState();
    _persistCurrentPage(widget.currentPath ?? _currentPath);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleInitialExternalInputs();
    });
  }

  @override
  void didUpdateWidget(covariant SmPlayerShellPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final currentPath = widget.currentPath ?? _currentPath;
    final previousPath = oldWidget.currentPath ?? _currentPath;
    if (currentPath != previousPath) {
      _persistCurrentPage(currentPath);
      if (currentPath != '/now-playing/full') {
        unawaited(_desktopFeatureService.setWindowFullScreen(false));
      }
    }
  }

  @override
  void dispose() {
    _mediaControlController.removeListener(_syncAudioPlayerFromController);
    for (final subscription in _audioSubscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(_audioPlayer.dispose());
    _stopPlaybackStallTimer();
    _desktopFeatureService.dispose();
    _settingsController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncNavigationMode(MediaQuery.sizeOf(context).width);
  }

  @override
  Widget build(BuildContext context) {
    final currentPath = widget.currentPath ?? _currentPath;
    final isNowPlayingFullRoute = currentPath == '/now-playing/full';
    final navigationMode =
        _navigationMode ??
        SmPlayerShellMetrics.navigationModeForWidth(
          MediaQuery.sizeOf(context).width,
        );
    final isNavigationPaneVisible =
        isNowPlayingFullRoute
            ? false
            : navigationMode == SmPlayerNavigationMode.minimal
            ? _isMinimalNavigationOpen
            : _isNavigationPaneOpen;
    final shellSidebarWidth =
        navigationMode == SmPlayerNavigationMode.overlay
            ? SmPlayerShellMetrics.collapsedSidebarWidth
            : isNavigationPaneVisible
            ? SmPlayerShellMetrics.sidebarWidth
            : SmPlayerShellMetrics.collapsedSidebarWidth;
    final sidebarSurfaceWidth =
        isNavigationPaneVisible && navigationMode != SmPlayerNavigationMode.wide
            ? SmPlayerShellMetrics.sidebarWidth
            : shellSidebarWidth;

    return ProviderScope(
      overrides: [
        mediaControlControllerProvider.overrideWith((ref) {
          return _mediaControlController;
        }),
      ],
      child: Focus(
        autofocus: true,
        onKeyEvent: _handlePlaybackShortcutKey,
        child: Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_ShellColors.bodyHighlight, Colors.transparent],
                stops: [0, 0.36],
              ),
            ),
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [_ShellColors.bodyTop, _ShellColors.bodyBottom],
                ),
              ),
              child: SafeArea(
                top: false,
                bottom: false,
                child:
                    _isMiniMode
                        ? _buildMiniModeHost()
                        : Stack(
                          children: [
                            AnimatedPositioned(
                              duration: const Duration(milliseconds: 180),
                              curve: Curves.easeOutCubic,
                              left:
                                  isNowPlayingFullRoute ? 0 : shellSidebarWidth,
                              top: 0,
                              right: 0,
                              height:
                                  isNowPlayingFullRoute
                                      ? MediaQuery.sizeOf(context).height
                                      : MediaQuery.sizeOf(context).height -
                                          SmPlayerShellMetrics.playerHeight +
                                          SmPlayerShellMetrics.playerTopRadius,
                              child: _Workspace(
                                key: SmPlayerShellKeys.workspace,
                                child: widget.child,
                              ),
                            ),
                            if (!isNowPlayingFullRoute)
                              AnimatedPositioned(
                                duration: const Duration(milliseconds: 180),
                                curve: Curves.easeOutCubic,
                                left: 0,
                                top: 0,
                                bottom: SmPlayerShellMetrics.playerHeight,
                                width: sidebarSurfaceWidth,
                                child: SizedBox.expand(
                                  key: SmPlayerShellKeys.sidebar,
                                  child: Consumer(
                                    builder: (context, ref, _) {
                                      final snapshot =
                                          ref
                                              .watch(
                                                musicLibrarySnapshotProvider,
                                              )
                                              .valueOrNull;
                                      final i18n =
                                          ref
                                              .watch(smPlayerI18nProvider)
                                              .value ??
                                          const SmPlayerI18n(
                                            locale: smPlayerFallbackLocale,
                                            messages: {},
                                          );
                                      return MainNavigationView(
                                        isPaneOpen: isNavigationPaneVisible,
                                        currentPath: currentPath,
                                        searchText: _searchText,
                                        i18n: i18n,
                                        canGoBack: widget.canGoBack,
                                        playlists:
                                            snapshot?.playlists ?? const [],
                                        recentSearches:
                                            snapshot?.recentSearches ??
                                            const [],
                                        onPaneToggle: _toggleNavigationPane,
                                        onGoBack: _goBack,
                                        onSearchTextChanged: (value) {
                                          setState(() {
                                            _searchText = value;
                                          });
                                        },
                                        onSearchCommitted: _commitSearch,
                                        onItemInvoked: _navigateTo,
                                        onRecentSearchRemove: (entryId) {
                                          ref
                                              .read(libraryRepositoryProvider)
                                              .removeRecentSearches([entryId]);
                                          ref.invalidate(
                                            musicLibrarySnapshotProvider,
                                          );
                                        },
                                        onRecentSearchesClear: () {
                                          ref
                                              .read(libraryRepositoryProvider)
                                              .clearRecentSearches();
                                          ref.invalidate(
                                            musicLibrarySnapshotProvider,
                                          );
                                        },
                                        onCreatePlaylist: () {
                                          unawaited(
                                            _createPlaylistFromNavigation(
                                              context: context,
                                              ref: ref,
                                              i18n: i18n,
                                              snapshot: snapshot,
                                            ),
                                          );
                                        },
                                        onDuplicatePlaylist: (playlist) {
                                          unawaited(
                                            _duplicatePlaylistFromNavigation(
                                              ref: ref,
                                              snapshot: snapshot,
                                              playlist: playlist,
                                            ),
                                          );
                                        },
                                        onRenamePlaylist: (playlist) {
                                          unawaited(
                                            _renamePlaylistFromNavigation(
                                              context: context,
                                              ref: ref,
                                              i18n: i18n,
                                              snapshot: snapshot,
                                              playlist: playlist,
                                            ),
                                          );
                                        },
                                        onDeletePlaylist: (playlist) {
                                          unawaited(
                                            _deletePlaylistFromNavigation(
                                              ref: ref,
                                              i18n: i18n,
                                              snapshot: snapshot,
                                              playlist: playlist,
                                            ),
                                          );
                                        },
                                        onReorderPlaylists: (playlistIds) {
                                          unawaited(
                                            ref
                                                .read(libraryRepositoryProvider)
                                                .reorderPlaylists(playlistIds),
                                          );
                                          ref.invalidate(
                                            musicLibrarySnapshotProvider,
                                          );
                                        },
                                        onPlaylistRandomPlay: (playlistId) {
                                          _randomPlayPlaylist(ref, playlistId);
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ),
                            if (!isNowPlayingFullRoute)
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                height: SmPlayerShellMetrics.playerHeight,
                                child: SizedBox.expand(
                                  key: SmPlayerShellKeys.reservedPlayer,
                                  child: AnimatedBuilder(
                                    animation: _mediaControlController,
                                    builder: (context, _) {
                                      final mediaControlState =
                                          _mediaControlController.state;
                                      return Consumer(
                                        builder: (context, ref, _) {
                                          final snapshot =
                                              ref
                                                  .watch(
                                                    musicLibrarySnapshotProvider,
                                                  )
                                                  .valueOrNull;
                                          final currentSong =
                                              _resolvePlayerSong(
                                                mediaControlState,
                                                snapshot,
                                              );
                                          final i18n =
                                              ref
                                                  .watch(smPlayerI18nProvider)
                                                  .valueOrNull ??
                                              const SmPlayerI18n(
                                                locale: smPlayerFallbackLocale,
                                                messages: {},
                                              );
                                          _syncDesktopFeatures(
                                            i18n: i18n,
                                            snapshot: snapshot,
                                            mediaControlState:
                                                mediaControlState,
                                            currentSong: currentSong,
                                          );
                                          return MediaControl(
                                            track: mediaControlState.track,
                                            currentSong: currentSong,
                                            playlists:
                                                snapshot?.playlists ?? const [],
                                            disabled:
                                                mediaControlState.disabled,
                                            isPlaying:
                                                mediaControlState.isPlaying,
                                            volume: mediaControlState.volume,
                                            isMuted: mediaControlState.isMuted,
                                            mode: mediaControlState.mode,
                                            progressSeconds:
                                                mediaControlState
                                                    .progressSeconds,
                                            durationSeconds:
                                                mediaControlState
                                                    .durationSeconds,
                                            playbackNoticeKey:
                                                mediaControlState
                                                    .playbackNoticeKey,
                                            onTogglePlayPause:
                                                _mediaControlController
                                                    .onTogglePlayPause,
                                            onPrevious:
                                                _playPreviousFromCurrentQueue,
                                            onNext: _playNextFromCurrentQueue,
                                            onSeek:
                                                _mediaControlController.onSeek,
                                            onBeginSeek:
                                                _mediaControlController
                                                    .onBeginSeek,
                                            onEndSeek:
                                                _mediaControlController
                                                    .onEndSeek,
                                            onVolumeChange:
                                                _mediaControlController
                                                    .onVolumeChange,
                                            onToggleMute:
                                                _mediaControlController
                                                    .onToggleMute,
                                            onToggleShuffle:
                                                _mediaControlController
                                                    .onToggleShuffle,
                                            onToggleRepeat:
                                                _mediaControlController
                                                    .onToggleRepeat,
                                            onToggleRepeatOne:
                                                _mediaControlController
                                                    .onToggleRepeatOne,
                                            onToggleFavorite:
                                                currentSong == null
                                                    ? _mediaControlController
                                                        .onToggleFavorite
                                                    : () {
                                                      _togglePlayerFavorite(
                                                        ref,
                                                        currentSong,
                                                      );
                                                    },
                                            onQuickPlay: () {
                                              _quickPlayLibrary(ref);
                                            },
                                            onOpenNowPlaying: () {
                                              _navigateTo('/now-playing');
                                            },
                                            onToggleWindowFullScreen: () {
                                              _toggleNativeNowPlayingFullScreen();
                                            },
                                            isWindowFullScreen:
                                                _isWindowFullScreen,
                                            onEnterMiniMode: _enterMiniMode,
                                            onOpenVoiceAssistant:
                                                Platform.isWindows
                                                    ? () {
                                                      _showVoiceAssistantDialog(
                                                        snapshot,
                                                        i18n,
                                                      );
                                                    }
                                                    : null,
                                            onAddToNowPlaying:
                                                currentSong == null
                                                    ? null
                                                    : () {
                                                      _addPlayerSongToNowPlaying(
                                                        ref,
                                                        currentSong,
                                                      );
                                                    },
                                            onCreatePlaylist:
                                                currentSong == null
                                                    ? null
                                                    : () {
                                                      createPlaylistWithSongs(
                                                        context: context,
                                                        ref: ref,
                                                        i18n:
                                                            context
                                                                .smPlayerI18n,
                                                        playlists:
                                                            snapshot
                                                                ?.playlists ??
                                                            const [],
                                                        defaultName:
                                                            currentSong.title,
                                                        songIds: [
                                                          currentSong.id,
                                                        ],
                                                      );
                                                    },
                                            onAddToPlaylist:
                                                currentSong == null
                                                    ? null
                                                    : (playlistId) {
                                                      _addPlayerSongToPlaylist(
                                                        ref,
                                                        currentSong,
                                                        playlistId,
                                                        snapshot?.playlists ??
                                                            const [],
                                                      );
                                                    },
                                            onSetPreference:
                                                currentSong == null
                                                    ? null
                                                    : (level) {
                                                      ref
                                                          .read(
                                                            libraryRepositoryProvider,
                                                          )
                                                          .addPreferenceItem(
                                                            'song',
                                                            '${currentSong.id}',
                                                            currentSong.title,
                                                            level,
                                                          );
                                                    },
                                            onSeeAlbum:
                                                currentSong == null
                                                    ? null
                                                    : () {
                                                      final album =
                                                          currentSong
                                                                  .album
                                                                  .isEmpty
                                                              ? context
                                                                  .smPlayerI18n
                                                                  .t(
                                                                    'common.albumUnknown',
                                                                  )
                                                              : currentSong
                                                                  .album;
                                                      _navigateTo(
                                                        '/albums?album=${Uri.encodeQueryComponent(album)}',
                                                      );
                                                    },
                                            onSeeMusicInfo:
                                                currentSong == null
                                                    ? null
                                                    : () {
                                                      setState(() {
                                                        _playerDialog = (
                                                          song: currentSong,
                                                          mode:
                                                              SongDialogMode
                                                                  .properties,
                                                        );
                                                      });
                                                    },
                                            onSeeLyrics:
                                                currentSong == null
                                                    ? null
                                                    : () {
                                                      setState(() {
                                                        _playerDialog = (
                                                          song: currentSong,
                                                          mode:
                                                              SongDialogMode
                                                                  .lyrics,
                                                        );
                                                      });
                                                    },
                                            onSeeAlbumArt:
                                                currentSong == null
                                                    ? null
                                                    : () {
                                                      setState(() {
                                                        _playerDialog = (
                                                          song: currentSong,
                                                          mode:
                                                              SongDialogMode
                                                                  .albumArt,
                                                        );
                                                      });
                                                    },
                                            onSeeLocal:
                                                currentSong == null
                                                    ? null
                                                    : () {
                                                      _revealPath(
                                                        currentSong.path,
                                                      );
                                                    },
                                          );
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ),
                            Positioned.fill(
                              child: Consumer(
                                builder: (context, ref, _) {
                                  final snapshot =
                                      ref
                                          .watch(musicLibrarySnapshotProvider)
                                          .valueOrNull;
                                  final state = _mediaControlController.state;
                                  final currentSong = _resolvePlayerSong(
                                    state,
                                    snapshot,
                                  );
                                  final settings = _settingsController.snapshot;
                                  if (!settings.desktopLyricsEnabled ||
                                      currentSong == null ||
                                      _usesNativeDesktopLyricsWindow()) {
                                    return const SizedBox.shrink();
                                  }
                                  return Padding(
                                    padding: EdgeInsets.only(
                                      left: shellSidebarWidth + 24,
                                      right: 24,
                                      top: 26,
                                    ),
                                    child: Align(
                                      alignment: Alignment.topCenter,
                                      child: _DesktopLyricsOverlay(
                                        song: currentSong,
                                        settings: settings,
                                        repository: ref.read(
                                          libraryRepositoryProvider,
                                        ),
                                        i18n: context.smPlayerI18n,
                                        progressSeconds: state.progressSeconds,
                                        isPlaying: state.isPlaying,
                                        onPrevious:
                                            _playPreviousFromCurrentQueue,
                                        onNext: _playNextFromCurrentQueue,
                                        onTogglePlayPause:
                                            _mediaControlController
                                                .onTogglePlayPause,
                                        onSeekOffset: (deltaMs) {
                                          _updateDesktopLyricsOffset(
                                            currentSong,
                                            currentSong.lyricsOffsetMs +
                                                deltaMs,
                                          );
                                        },
                                        onResetOffset: () {
                                          _updateDesktopLyricsOffset(
                                            currentSong,
                                            0,
                                          );
                                        },
                                        onToggleLock: _toggleDesktopLyricsLock,
                                        onClose: _disableDesktopLyrics,
                                        onOpenSettings: () {
                                          _navigateTo('/settings');
                                        },
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            if (_playerDialog case final dialog?)
                              MusicDialog(
                                song: dialog.song,
                                initialMode: dialog.mode,
                                canPause:
                                    _mediaControlController.state.isPlaying &&
                                    _mediaControlController.state.track.id ==
                                        dialog.song.id,
                                onPlay:
                                    _mediaControlController.onTogglePlayPause,
                                onReveal: _revealPath,
                                onSaved: () {
                                  setState(() {});
                                },
                                onClose: () {
                                  setState(() {
                                    _playerDialog = null;
                                  });
                                },
                              ),
                            if (_releaseNotesDialogVersion
                                case final String version)
                              ReleaseNotesDialog(
                                version: version,
                                onClose: () {
                                  unawaited(_closeReleaseNotes(version));
                                },
                              ),
                            if (_startupArtistSplitResult
                                case final ArtistSplitAnalysisResult result)
                              ArtistSplitReviewDialog(
                                result: result,
                                applying: _startupArtistSplitApplying,
                                onCancel: () {
                                  setState(() {
                                    _startupArtistSplitResult = null;
                                  });
                                },
                                onApply: () {
                                  unawaited(_applyStartupArtistSplits(result));
                                },
                              ),
                          ],
                        ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  LibrarySong? _resolvePlayerSong(
    MediaControlState mediaControlState,
    MusicLibrarySnapshot? snapshot,
  ) {
    final songs = snapshot?.songs ?? const <LibrarySong>[];
    final songsById = {for (final song in songs) song.id: song};
    final queueSongs =
        snapshot?.nowPlaying.songIds
            .map((songId) => songsById[songId])
            .whereType<LibrarySong>()
            .toList() ??
        const <LibrarySong>[];
    final queueIndex = mediaControlState.selectedQueueIndex;
    if (queueIndex != null &&
        queueIndex >= 0 &&
        queueIndex < queueSongs.length) {
      return queueSongs[queueIndex];
    }
    final trackId = mediaControlState.track.id;
    return trackId == null ? null : songsById[trackId];
  }

  KeyEventResult _handlePlaybackShortcutKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent ||
        _isPlaybackShortcutEditableFocus(FocusManager.instance.primaryFocus)) {
      return KeyEventResult.ignored;
    }

    final keyboard = HardwareKeyboard.instance;
    final shortcut = playbackShortcutForKey(
      key: event.logicalKey,
      control: keyboard.isControlPressed,
      alt: keyboard.isAltPressed,
      meta: keyboard.isMetaPressed,
      shift: keyboard.isShiftPressed,
    );
    if (shortcut == null) {
      return KeyEventResult.ignored;
    }

    _applyPlaybackShortcut(shortcut);
    return KeyEventResult.handled;
  }

  bool _isPlaybackShortcutEditableFocus(FocusNode? focus) {
    final context = focus?.context;
    if (context == null) {
      return false;
    }
    final widget = context.widget;
    return widget is EditableText ||
        context.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  void _applyPlaybackShortcut(SmPlayerPlaybackShortcut shortcut) {
    switch (shortcut) {
      case SmPlayerPlaybackShortcut.togglePlayPause:
        _mediaControlController.onTogglePlayPause();
      case SmPlayerPlaybackShortcut.next:
        _playNextFromCurrentQueue();
      case SmPlayerPlaybackShortcut.previous:
        _playPreviousFromCurrentQueue();
      case SmPlayerPlaybackShortcut.seekForwardShort:
        _seekCurrentTrackBy(5);
      case SmPlayerPlaybackShortcut.seekBackwardShort:
        _seekCurrentTrackBy(-5);
      case SmPlayerPlaybackShortcut.seekForwardLong:
        _seekCurrentTrackBy(30);
      case SmPlayerPlaybackShortcut.seekBackwardLong:
        _seekCurrentTrackBy(-30);
      case SmPlayerPlaybackShortcut.toggleShuffle:
        _mediaControlController.onToggleShuffle();
      case SmPlayerPlaybackShortcut.toggleRepeat:
        _mediaControlController.onToggleRepeat();
      case SmPlayerPlaybackShortcut.toggleRepeatOne:
        _mediaControlController.onToggleRepeatOne();
    }
  }

  void _seekCurrentTrackBy(double deltaSeconds) {
    final state = _mediaControlController.state;
    if (state.disabled) {
      return;
    }
    _mediaControlController.onSeek(state.progressSeconds + deltaSeconds);
  }

  void _syncAudioPlayerFromController() {
    if (_syncingAudioPlayer) {
      return;
    }

    final state = _mediaControlController.state;
    unawaited(_audioPlayer.setVolume(state.isMuted ? 0 : state.volume / 100));
    final trackId = state.track.id;
    if (trackId == null) {
      _loadedAudioTrackId = null;
      _loadedAudioPath = null;
      unawaited(_audioPlayer.stop());
      return;
    }

    final song = _resolvePlayerSong(
      state,
      ref.read(musicLibrarySnapshotProvider).valueOrNull,
    );
    if (song == null) {
      return;
    }

    if (_loadedAudioTrackId != song.id || _loadedAudioPath != song.path) {
      unawaited(_loadAudioSong(song, state));
      return;
    }

    unawaited(_applyAudioPlaybackState(state));
  }

  Future<void> _loadAudioSong(LibrarySong song, MediaControlState state) async {
    final loadSerial = _audioLoadSerial + 1;
    _audioLoadSerial = loadSerial;
    _syncingAudioPlayer = true;
    _mediaControlController.setTrackLoading(true);
    _syncingAudioPlayer = false;
    try {
      final duration = await _audioPlayer.setFilePath(song.path);
      if (!mounted || loadSerial != _audioLoadSerial) {
        return;
      }
      _loadedAudioTrackId = song.id;
      _loadedAudioPath = song.path;
      _failedAudioTrackIds.remove(song.id);
      if (duration != null) {
        _persistResolvedAudioDuration(song.id, duration);
      }
      _syncingAudioPlayer = true;
      _mediaControlController.syncPlaybackProgress(
        state.progressSeconds,
        durationSeconds:
            duration?.inMilliseconds == null
                ? state.durationSeconds
                : duration!.inMilliseconds / 1000,
      );
      _mediaControlController.setTrackLoading(false);
      _syncingAudioPlayer = false;
      await _applyAudioPlaybackState(_mediaControlController.state);
    } on Object {
      if (loadSerial == _audioLoadSerial) {
        _loadedAudioTrackId = null;
        _loadedAudioPath = null;
        _failedAudioTrackIds.add(song.id);
        _syncingAudioPlayer = true;
        _mediaControlController.setPlaybackLoadFailed();
        _syncingAudioPlayer = false;
        if (state.isPlaying) {
          _recoverFromAudioLoadFailure(song.id, state.selectedQueueIndex);
        }
      }
    }
  }

  bool _recoverFromAudioLoadFailure(int failedTrackId, int? activeQueueIndex) {
    final snapshot = ref.read(musicLibrarySnapshotProvider).valueOrNull;
    if (snapshot == null || snapshot.nowPlaying.songIds.isEmpty) {
      return false;
    }
    final nextTrackId = getNextRecoverableTrackId(
      playbackSongIds: snapshot.nowPlaying.songIds,
      activeTrackId: failedTrackId,
      activeQueueIndex: activeQueueIndex ?? -1,
      mode: _mediaControlController.state.mode,
      failedTrackIds: _failedAudioTrackIds,
    );
    if (nextTrackId == null) {
      return false;
    }
    final nextQueueIndex = snapshot.nowPlaying.songIds.indexOf(nextTrackId);
    if (nextQueueIndex < 0) {
      return false;
    }
    _playQueueIndex(snapshot, nextQueueIndex);
    return true;
  }

  Future<void> _applyAudioPlaybackState(MediaControlState state) async {
    final targetPosition = Duration(
      milliseconds: (state.progressSeconds * 1000).round(),
    );
    if (!state.isProgressSeeking &&
        (_audioPlayer.position - targetPosition).abs() >
            const Duration(milliseconds: 850)) {
      await _audioPlayer.seek(targetPosition);
    }
    await _audioPlayer.setVolume(state.isMuted ? 0 : state.volume / 100);
    if (state.isPlaying) {
      await _audioPlayer.play();
      _startPlaybackStallTimer();
    } else {
      await _audioPlayer.pause();
      _stopPlaybackStallTimer();
    }
  }

  void _handleAudioPositionChanged(Duration position) {
    if (_syncingAudioPlayer ||
        _mediaControlController.state.isProgressSeeking) {
      return;
    }

    _syncingAudioPlayer = true;
    _mediaControlController.syncPlaybackProgress(
      position.inMilliseconds / 1000,
      durationSeconds:
          _audioPlayer.duration?.inMilliseconds == null
              ? null
              : _audioPlayer.duration!.inMilliseconds / 1000,
    );
    _syncingAudioPlayer = false;
    _markPlaybackProgressForStallDetection(position);
  }

  void _handleAudioDurationChanged(Duration? duration) {
    if (_syncingAudioPlayer || duration == null) {
      return;
    }

    final trackId = _mediaControlController.state.track.id;
    if (trackId != null) {
      _persistResolvedAudioDuration(trackId, duration);
    }
    _syncingAudioPlayer = true;
    _mediaControlController.syncPlaybackProgress(
      _mediaControlController.state.progressSeconds,
      durationSeconds: duration.inMilliseconds / 1000,
    );
    _syncingAudioPlayer = false;
  }

  void _persistResolvedAudioDuration(int songId, Duration duration) {
    final durationSeconds = (duration.inMilliseconds / 1000).round();
    if (durationSeconds <= 0 ||
        _persistedAudioDurations[songId] == durationSeconds) {
      return;
    }

    _persistedAudioDurations[songId] = durationSeconds;
    unawaited(
      ref
          .read(libraryRepositoryProvider)
          .updateSongDuration(songId, durationSeconds),
    );
  }

  void _handleAudioPlayerStateChanged(PlayerState state) {
    if (_syncingAudioPlayer) {
      return;
    }

    if (state.processingState == ProcessingState.completed) {
      _finishCurrentAudioTrack();
      return;
    }

    if (state.playing) {
      _failedAudioTrackIds.clear();
      _startPlaybackStallTimer();
    } else {
      _stopPlaybackStallTimer();
    }

    _syncingAudioPlayer = true;
    _mediaControlController.setTrackLoading(
      state.processingState == ProcessingState.loading ||
          state.processingState == ProcessingState.buffering,
      buffering: state.processingState == ProcessingState.buffering,
    );
    _mediaControlController.setPlaybackActive(state.playing);
    _syncingAudioPlayer = false;
  }

  void _finishCurrentAudioTrack() {
    unawaited(_finishCurrentAudioTrackAsync());
  }

  Future<void> _finishCurrentAudioTrackAsync() async {
    _stopPlaybackStallTimer();
    final activeTrackId = _mediaControlController.state.track.id;
    if (activeTrackId != null) {
      if (_finishingAudioTrackId == activeTrackId) {
        return;
      }
      _finishingAudioTrackId = activeTrackId;
      try {
        await ref.read(libraryRepositoryProvider).markSongPlayed(activeTrackId);
        if (!mounted) {
          return;
        }
        ref.invalidate(musicLibrarySnapshotProvider);
      } finally {
        if (_finishingAudioTrackId == activeTrackId) {
          _finishingAudioTrackId = null;
        }
      }
    }

    if (_mediaControlController.state.mode == PlaybackMode.repeatOne) {
      unawaited(
        _audioPlayer.seek(Duration.zero).then((_) {
          return _audioPlayer.play();
        }),
      );
      _syncingAudioPlayer = true;
      _mediaControlController.syncPlaybackProgress(0);
      _mediaControlController.setPlaybackActive(true);
      _syncingAudioPlayer = false;
      return;
    }
    final advanced = _playNextFromCurrentQueue(automatic: true);
    if (!advanced) {
      _syncingAudioPlayer = true;
      _mediaControlController.completePlayback();
      _syncingAudioPlayer = false;
    }
  }

  void _startPlaybackStallTimer() {
    if (_playbackStallTimer != null) {
      return;
    }
    _stalledProgressStartedAt = null;
    _stalledProgressSeconds = _audioPlayer.position.inMilliseconds / 1000;
    _playbackStallTimer = Timer.periodic(_playbackStallCheckInterval, (_) {
      _checkPlaybackStall();
    });
  }

  void _stopPlaybackStallTimer() {
    _playbackStallTimer?.cancel();
    _playbackStallTimer = null;
    _stalledProgressStartedAt = null;
    _stalledProgressSeconds = _audioPlayer.position.inMilliseconds / 1000;
  }

  void _markPlaybackProgressForStallDetection(Duration position) {
    final progressSeconds = position.inMilliseconds / 1000;
    if ((progressSeconds - _stalledProgressSeconds).abs() > 0.2) {
      _stalledProgressSeconds = progressSeconds;
      _stalledProgressStartedAt = null;
    }
  }

  void _checkPlaybackStall() {
    final state = _mediaControlController.state;
    final currentProgressSeconds = _audioPlayer.position.inMilliseconds / 1000;
    final startedAt = _stalledProgressStartedAt;
    if ((currentProgressSeconds - _stalledProgressSeconds).abs() > 0.2) {
      _stalledProgressSeconds = currentProgressSeconds;
      _stalledProgressStartedAt = null;
      return;
    }
    final now = DateTime.now();
    _stalledProgressStartedAt ??= now;
    final stalledFor = now.difference(startedAt ?? now);
    final durationSeconds =
        _audioPlayer.duration?.inMilliseconds == null
            ? state.durationSeconds
            : _audioPlayer.duration!.inMilliseconds / 1000;
    final action = stalledPlaybackRecoveryAction(
      isPlaying: state.isPlaying,
      isUserSeeking: state.isProgressSeeking,
      currentProgressSeconds: currentProgressSeconds,
      lastProgressSeconds: _stalledProgressSeconds,
      stalledFor: stalledFor,
      durationSeconds: durationSeconds,
      stallTimeout: _playbackStallTimeout,
    );
    switch (action) {
      case PlaybackStallRecoveryAction.none:
        return;
      case PlaybackStallRecoveryAction.finishTrack:
        _stalledProgressStartedAt = null;
        _finishCurrentAudioTrack();
      case PlaybackStallRecoveryAction.pauseAndRecover:
        _recoverFromStalledPlayback(currentProgressSeconds);
    }
  }

  void _recoverFromStalledPlayback(double progressSeconds) {
    _stopPlaybackStallTimer();
    unawaited(_audioPlayer.pause());
    _syncingAudioPlayer = true;
    _mediaControlController.setTrackLoading(false);
    _mediaControlController.setPlaybackActive(false);
    _mediaControlController.syncPlaybackProgress(progressSeconds);
    _syncingAudioPlayer = false;
    _settingsController.savePlaybackSettingsImmediate(
      PlaybackSettingsUpdate(musicProgress: progressSeconds),
    );
  }

  Widget _buildMiniModeHost() {
    return AnimatedBuilder(
      animation: _mediaControlController,
      builder: (context, _) {
        return Consumer(
          builder: (context, ref, _) {
            final mediaControlState = _mediaControlController.state;
            final snapshot =
                ref.watch(musicLibrarySnapshotProvider).valueOrNull;
            final currentSong = _resolvePlayerSong(mediaControlState, snapshot);
            final settings = _settingsController.snapshot;
            final i18n =
                ref.watch(smPlayerI18nProvider).valueOrNull ??
                const SmPlayerI18n(
                  locale: smPlayerFallbackLocale,
                  messages: {},
                );
            _syncDesktopFeatures(
              i18n: i18n,
              snapshot: snapshot,
              mediaControlState: mediaControlState,
              currentSong: currentSong,
            );
            return _MiniModeSurface(
              state: mediaControlState,
              i18n: i18n,
              currentSong: currentSong,
              repository: ref.read(libraryRepositoryProvider),
              playerLyricsSource: settings.playerLyricsSource,
              onExit: _exitMiniMode,
              onTogglePlayPause: _mediaControlController.onTogglePlayPause,
              onPrevious: _playPreviousFromCurrentQueue,
              onNext: _playNextFromCurrentQueue,
              onSeek: _mediaControlController.onSeek,
              onToggleFavorite:
                  currentSong == null
                      ? _mediaControlController.onToggleFavorite
                      : () {
                        _togglePlayerFavorite(ref, currentSong);
                      },
              onQuickPlay: () {
                _quickPlayLibrary(ref);
              },
              onToggleRepeat: _mediaControlController.onToggleRepeat,
              onToggleMute: _mediaControlController.onToggleMute,
              onVolumeChange: _mediaControlController.onVolumeChange,
              onOpenVoiceAssistant:
                  Platform.isWindows
                      ? () {
                        _showVoiceAssistantDialog(snapshot, i18n);
                      }
                      : null,
            );
          },
        );
      },
    );
  }

  void _quickPlayLibrary(WidgetRef ref) {
    unawaited(_quickPlayLibraryAsync(ref));
  }

  Future<void> _quickPlayLibraryAsync(WidgetRef ref) async {
    final snapshot = ref.read(musicLibrarySnapshotProvider).valueOrNull;
    final songs = snapshot?.songs ?? const <LibrarySong>[];
    if (songs.isEmpty) {
      return;
    }

    final repository = ref.read(libraryRepositoryProvider);
    final preferences = await repository.getPreferenceSettings();
    final songIds = quickPlaySongIds(
      songs: songs,
      playlists: snapshot!.playlists,
      folders: snapshot.folders,
      preferences: preferences,
    );
    if (songIds.isEmpty) {
      return;
    }
    final songsById = {for (final song in songs) song.id: song};
    final firstSong = songsById[songIds.first]!;
    await repository.replaceNowPlaying(songIds);
    ref.invalidate(musicLibrarySnapshotProvider);
    _mediaControlController.playTrack(
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
  }

  void _togglePlayerFavorite(WidgetRef ref, LibrarySong song) {
    final nextFavorite = !song.favorite;
    setSongsFavorite(ref, [song.id], nextFavorite);
    if (_mediaControlController.state.track.id == song.id &&
        _mediaControlController.state.track.favorite != nextFavorite) {
      _mediaControlController.onToggleFavorite();
    }
  }

  void _addPlayerSongToNowPlaying(WidgetRef ref, LibrarySong song) {
    final snapshot = ref.read(musicLibrarySnapshotProvider).valueOrNull;
    final before = snapshot?.nowPlaying.songIds ?? const <int>[];
    ref.read(libraryRepositoryProvider).replaceNowPlaying([...before, song.id]);
    ref.invalidate(musicLibrarySnapshotProvider);
    _showUndo(
      context.smPlayerI18n.t('notification.songAddedTo', {
        'title': song.title,
        'target': context.smPlayerI18n.t('common.nowPlaying'),
      }),
      () {
        ref.read(libraryRepositoryProvider).replaceNowPlaying(before);
        ref.invalidate(musicLibrarySnapshotProvider);
      },
    );
  }

  void _addPlayerSongToPlaylist(
    WidgetRef ref,
    LibrarySong song,
    int playlistId,
    List<LibraryPlaylist> playlists,
  ) {
    final targetPlaylist = playlists.firstWhere(
      (playlist) => playlist.id == playlistId,
    );
    ref.read(libraryRepositoryProvider).addSongsToPlaylist(playlistId, [
      song.id,
    ]);
    ref.invalidate(musicLibrarySnapshotProvider);
    _showUndo(
      context.smPlayerI18n.t('notification.songAddedTo', {
        'title': song.title,
        'target': targetPlaylist.name,
      }),
      () {
        ref
            .read(libraryRepositoryProvider)
            .removeSongFromPlaylist(playlistId, song.id);
        ref.invalidate(musicLibrarySnapshotProvider);
      },
    );
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

  Future<void> _createPlaylistFromNavigation({
    required BuildContext context,
    required WidgetRef ref,
    required SmPlayerI18n i18n,
    required MusicLibrarySnapshot? snapshot,
  }) async {
    final currentSnapshot =
        snapshot ?? await ref.read(musicLibrarySnapshotProvider.future);
    if (!context.mounted || currentSnapshot == null) {
      return;
    }

    final name = await showSmPlayerInputDialog(
      context: context,
      i18n: i18n,
      title: i18n.t('playlists.createNew'),
      defaultValue: getNextPlaylistName(
        i18n.t('common.playlist'),
        currentSnapshot.playlists,
      ),
      placeholder: i18n.t('playlists.namePlaceholder'),
      confirmText: i18n.t('playlists.create'),
      validate: (name) {
        return validatePlaylistName(name, currentSnapshot.playlists, '', i18n);
      },
    );
    if (name == null) {
      return;
    }

    final playlist = await ref
        .read(libraryRepositoryProvider)
        .createPlaylist(name, const []);
    await _settingsController.saveViewState(lastPlaylistId: playlist.id);
    ref.invalidate(musicLibrarySnapshotProvider);
    if (!mounted) {
      return;
    }
    _navigateTo('/playlists/${playlist.id}');
  }

  Future<void> _duplicatePlaylistFromNavigation({
    required WidgetRef ref,
    required MusicLibrarySnapshot? snapshot,
    required LibraryPlaylist playlist,
  }) async {
    final currentSnapshot =
        snapshot ?? await ref.read(musicLibrarySnapshotProvider.future);
    if (currentSnapshot == null) {
      return;
    }
    await ref
        .read(libraryRepositoryProvider)
        .createPlaylist(
          getNextPlaylistName(playlist.name, currentSnapshot.playlists),
          playlist.songIds,
        );
    ref.invalidate(musicLibrarySnapshotProvider);
  }

  Future<void> _renamePlaylistFromNavigation({
    required BuildContext context,
    required WidgetRef ref,
    required SmPlayerI18n i18n,
    required MusicLibrarySnapshot? snapshot,
    required LibraryPlaylist playlist,
  }) async {
    final currentSnapshot =
        snapshot ?? await ref.read(musicLibrarySnapshotProvider.future);
    if (currentSnapshot == null || !context.mounted) {
      return;
    }

    final name = await showSmPlayerInputDialog(
      context: context,
      i18n: i18n,
      title: i18n.t('playlists.rename'),
      defaultValue: playlist.name,
      placeholder: i18n.t('playlists.namePlaceholder'),
      confirmText: i18n.t('playlists.rename'),
      validate: (name) {
        return validatePlaylistName(
          name,
          currentSnapshot.playlists,
          playlist.name,
          i18n,
        );
      },
    );
    if (name == null || name == playlist.name) {
      return;
    }

    await ref.read(libraryRepositoryProvider).renamePlaylist(playlist.id, name);
    ref.invalidate(musicLibrarySnapshotProvider);
  }

  Future<void> _deletePlaylistFromNavigation({
    required WidgetRef ref,
    required SmPlayerI18n i18n,
    required MusicLibrarySnapshot? snapshot,
    required LibraryPlaylist playlist,
  }) async {
    final currentSnapshot =
        snapshot ?? await ref.read(musicLibrarySnapshotProvider.future);
    if (currentSnapshot == null) {
      return;
    }
    final playlistIndex = currentSnapshot.playlists.indexWhere(
      (item) => item.id == playlist.id,
    );
    await ref.read(libraryRepositoryProvider).deletePlaylist(playlist.id);
    ref.invalidate(musicLibrarySnapshotProvider);
    _showUndo(
      i18n.t('notification.playlistRemoved', {'name': playlist.name}),
      () async {
        await ref
            .read(libraryRepositoryProvider)
            .restorePlaylist(playlist, playlistIndex);
        ref.invalidate(musicLibrarySnapshotProvider);
      },
    );
  }

  void _navigateTo(String target) {
    setState(() {
      _currentPath = target;
    });
    _closeNavigationOverlay();
    widget.onNavigate?.call(target);
    if (target != '/now-playing/full') {
      unawaited(_desktopFeatureService.setWindowFullScreen(false));
    }
  }

  void _toggleNativeNowPlayingFullScreen() {
    final currentPath = widget.currentPath ?? _currentPath;
    final nextFullScreen =
        !_isWindowFullScreen && currentPath != '/now-playing/full';
    unawaited(_desktopFeatureService.setWindowFullScreen(nextFullScreen));
    _navigateTo(nextFullScreen ? '/now-playing/full' : '/now-playing');
  }

  void _enterMiniMode() {
    final currentPath = widget.currentPath ?? _currentPath;
    setState(() {
      _isMiniMode = true;
      if (currentPath == '/now-playing/full') {
        _currentPath = '/now-playing';
      }
    });
    if (currentPath == '/now-playing/full') {
      widget.onNavigate?.call('/now-playing');
      unawaited(_desktopFeatureService.setWindowFullScreen(false));
    }
    unawaited(_desktopFeatureService.enterMiniMode());
  }

  void _exitMiniMode() {
    setState(() {
      _isMiniMode = false;
    });
    unawaited(_desktopFeatureService.exitMiniMode());
  }

  void _goBack() {
    _closeNavigationOverlay();
    widget.onGoBack?.call();
  }

  void _syncNavigationMode(double width) {
    final nextNavigationMode = SmPlayerShellMetrics.navigationModeForWidth(
      width,
    );
    final currentNavigationMode = _navigationMode;
    if (currentNavigationMode == null) {
      _navigationMode = nextNavigationMode;
      return;
    }

    if (currentNavigationMode == nextNavigationMode) {
      if (nextNavigationMode != SmPlayerNavigationMode.minimal &&
          _isMinimalNavigationOpen) {
        _isMinimalNavigationOpen = false;
      }
      return;
    }

    _navigationMode = nextNavigationMode;
    _isMinimalNavigationOpen = false;
    _isNavigationPaneOpen = nextNavigationMode == SmPlayerNavigationMode.wide;
    _saveNavigationCollapsed(nextNavigationMode != SmPlayerNavigationMode.wide);
  }

  void _toggleNavigationPane() {
    final navigationMode =
        _navigationMode ??
        SmPlayerShellMetrics.navigationModeForWidth(
          MediaQuery.sizeOf(context).width,
        );

    if (navigationMode == SmPlayerNavigationMode.minimal) {
      setState(() {
        _isMinimalNavigationOpen = !_isMinimalNavigationOpen;
      });
      return;
    }

    final nextIsPaneOpen = !_isNavigationPaneOpen;
    setState(() {
      _isNavigationPaneOpen = nextIsPaneOpen;
    });
    _saveNavigationCollapsed(!nextIsPaneOpen);
  }

  void _closeNavigationOverlay() {
    final navigationMode = _navigationMode;
    if (navigationMode == SmPlayerNavigationMode.minimal &&
        _isMinimalNavigationOpen) {
      setState(() {
        _isMinimalNavigationOpen = false;
      });
      return;
    }

    if (navigationMode == SmPlayerNavigationMode.overlay &&
        _isNavigationPaneOpen) {
      setState(() {
        _isNavigationPaneOpen = false;
      });
      _saveNavigationCollapsed(true);
    }
  }

  Future<void> _restoreNavigationPaneState() async {
    final preferences = await _preferencesFuture;
    final navigationCollapsed =
        preferences.getBool(SmPlayerShellStorageKeys.navigationCollapsed) ??
        false;
    if (!mounted) {
      return;
    }

    setState(() {
      _isNavigationPaneOpen = !navigationCollapsed;
    });
  }

  void _persistCurrentPage(String path) {
    if (!restorableRoutes.contains(path) || _lastPersistedPage == path) {
      return;
    }
    _lastPersistedPage = path;
    unawaited(_saveLastPage(path));
  }

  Future<void> _saveLastPage(String path) async {
    await _settingsController.saveViewState(lastPage: path);
  }

  Future<void> _restorePlaybackRuntimeSettings() async {
    await _settingsController.refresh();
    if (!mounted) {
      return;
    }

    _mediaControlController.applyPlaybackRuntimeSettings(
      _settingsController.getPlaybackSettingsImmediate(),
    );
    unawaited(_checkReleaseNotesVersion());
  }

  Future<void> _restoreDesktopWindowFullScreenState() async {
    final fullScreen = await _desktopFeatureService.getWindowFullScreen();
    if (!mounted) {
      return;
    }
    _setDesktopWindowFullScreen(fullScreen);
  }

  Future<void> _checkReleaseNotesVersion() async {
    if (_releaseNotesChecked) {
      return;
    }
    _releaseNotesChecked = true;
    final lastVersion = _settingsController.snapshot.lastReleaseNotesVersion;
    if (lastVersion.isEmpty) {
      unawaited(_checkStartupArtistSplits());
      return;
    }

    final currentVersion = await _currentAppVersion();
    if (!mounted) {
      return;
    }
    if (compareAppVersions(currentVersion, lastVersion) > 0) {
      setState(() {
        _releaseNotesDialogVersion = currentVersion;
      });
      return;
    }
    unawaited(_checkStartupArtistSplits());
  }

  Future<String> _currentAppVersion() async {
    final providedVersion = widget.appVersion;
    if (providedVersion != null) {
      return providedVersion;
    }

    final packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.version;
  }

  Future<void> _closeReleaseNotes(String version) async {
    await _settingsController.updateSettings(
      AppSettingsUpdate(lastReleaseNotesVersion: version),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _releaseNotesDialogVersion = null;
    });
    unawaited(_checkStartupArtistSplits());
  }

  Future<void> _checkStartupArtistSplits() async {
    if (_startupArtistSplitChecked ||
        _releaseNotesDialogVersion != null ||
        !_settingsController.snapshot.smartMultiArtistRecognition) {
      return;
    }
    _startupArtistSplitChecked = true;
    final repository = ref.read(libraryRepositoryProvider);
    final shouldCheck = await repository.shouldCheckStartupArtistSplits();
    if (!shouldCheck) {
      return;
    }
    final result = await repository.analyzeArtistSplits();
    if (!mounted || !result.hasSuggestions) {
      return;
    }
    setState(() {
      _startupArtistSplitResult = result;
    });
  }

  Future<void> _applyStartupArtistSplits(
    ArtistSplitAnalysisResult result,
  ) async {
    setState(() {
      _startupArtistSplitApplying = true;
    });
    try {
      await ref.read(libraryRepositoryProvider).applyArtistSplits([
        ...result.directSplits,
        ...result.possibleSplits,
        ...result.mergeSuggestions,
      ]);
      ref.invalidate(musicLibrarySnapshotProvider);
      if (!mounted) {
        return;
      }
      setState(() {
        _startupArtistSplitResult = null;
      });
    } finally {
      if (mounted) {
        setState(() {
          _startupArtistSplitApplying = false;
        });
      }
    }
  }

  void _syncDesktopFeatures({
    required SmPlayerI18n i18n,
    required MusicLibrarySnapshot? snapshot,
    required MediaControlState mediaControlState,
    required LibrarySong? currentSong,
  }) {
    final settings = _settingsController.snapshot;
    final windowControlsLight = _isMiniMode || isAppNightMode(settings);
    if (_lastWindowControlsLight != windowControlsLight) {
      _lastWindowControlsLight = windowControlsLight;
      unawaited(
        _desktopFeatureService.setWindowControlsLight(windowControlsLight),
      );
    }

    final trayState = DesktopTrayState(
      appTitle: i18n.t('app.shell'),
      isPlaying: mediaControlState.isPlaying,
      isWindowVisible: _isWindowVisible,
      quitOnClose: settings.quitOnClose,
      labels: DesktopTrayLabels.fromI18n(i18n),
      recentSongs:
          snapshot?.recentSongs
              .take(desktopRecentSongLimit)
              .map(DesktopRecentSong.fromLibrarySong)
              .toList() ??
          const [],
    );
    if (_lastDesktopTraySignature != trayState.signature) {
      _lastDesktopTraySignature = trayState.signature;
      unawaited(_desktopFeatureService.updateTray(trayState));
    }

    final lyricsState = DesktopLyricsDisplayState.fromShell(
      settings: settings,
      currentSong: currentSong,
      lyrics: _desktopLyricsForSong(currentSong),
      lyricsLoading:
          currentSong != null && _desktopLyricsLoadingSongId == currentSong.id,
      isPlaying: mediaControlState.isPlaying,
      progressSeconds: mediaControlState.progressSeconds,
      i18n: i18n,
    );
    _ensureDesktopLyricsLoaded(settings, currentSong);
    if (_lastDesktopLyricsSignature != lyricsState.signature) {
      _lastDesktopLyricsSignature = lyricsState.signature;
      unawaited(_desktopFeatureService.updateDesktopLyricsState(lyricsState));
    }

    final mediaSessionState = MediaSessionDisplayState.fromShell(
      currentSong: currentSong,
      i18n: i18n,
      isPlaying: mediaControlState.isPlaying,
      durationSeconds: mediaControlState.durationSeconds,
      progressSeconds: mediaControlState.progressSeconds,
    );
    if (_lastMediaSessionSignature != mediaSessionState.signature) {
      _lastMediaSessionSignature = mediaSessionState.signature;
      unawaited(_desktopFeatureService.updateMediaSession(mediaSessionState));
    }

    _notifyTrackChanged(
      currentSong,
      settings,
      i18n,
      mediaControlState.progressSeconds,
    );
  }

  LyricsSnapshot? _desktopLyricsForSong(LibrarySong? currentSong) {
    return currentSong != null && _desktopLyricsSongId == currentSong.id
        ? _desktopLyrics
        : null;
  }

  void _ensureDesktopLyricsLoaded(
    SettingsSnapshot settings,
    LibrarySong? currentSong,
  ) {
    final shouldLoadLyrics =
        settings.desktopLyricsEnabled ||
        (settings.showNotifications && settings.showLyricsInNotification);
    if (!shouldLoadLyrics || currentSong == null) {
      _desktopLyricsSongId = null;
      _desktopLyricsLoadingSongId = null;
      _desktopLyricsMode = null;
      _desktopLyrics = null;
      return;
    }

    final mode = settings.playerLyricsSource;
    if ((_desktopLyricsSongId == currentSong.id &&
            _desktopLyricsMode == mode) ||
        (_desktopLyricsLoadingSongId == currentSong.id &&
            _desktopLyricsMode == mode)) {
      return;
    }

    final songId = currentSong.id;
    _desktopLyricsLoadingSongId = songId;
    _desktopLyricsMode = mode;
    unawaited(
      ref
          .read(libraryRepositoryProvider)
          .getSongLyrics(songId, mode: mode)
          .then((lyrics) {
            if (!mounted || _desktopLyricsLoadingSongId != songId) {
              return;
            }
            _desktopLyricsSongId = songId;
            _desktopLyricsLoadingSongId = null;
            _desktopLyrics = lyrics;
            _lastDesktopLyricsSignature = null;
            setState(() {});
          }),
    );
  }

  void _notifyTrackChanged(
    LibrarySong? currentSong,
    SettingsSnapshot settings,
    SmPlayerI18n i18n,
    double progressSeconds,
  ) {
    if (currentSong == null) {
      return;
    }

    if (_lastNotifiedSongId == null) {
      _lastNotifiedSongId = currentSong.id;
      return;
    }

    if (_lastNotifiedSongId == currentSong.id) {
      return;
    }

    _lastNotifiedSongId = currentSong.id;
    if (!settings.showNotifications ||
        settings.notificationSend != NotificationSendMode.musicChanged) {
      return;
    }

    unawaited(
      _showTrackChangedNotification(
        currentSong: currentSong,
        settings: settings,
        i18n: i18n,
        progressSeconds: progressSeconds,
      ),
    );
  }

  Future<void> _showTrackChangedNotification({
    required LibrarySong currentSong,
    required SettingsSnapshot settings,
    required SmPlayerI18n i18n,
    required double progressSeconds,
  }) async {
    var lyricsPreview = '';
    if (settings.showLyricsInNotification) {
      final cachedLyrics =
          settings.notificationLyricsSource == settings.playerLyricsSource
              ? _desktopLyricsForSong(currentSong)
              : null;
      final lyrics =
          cachedLyrics ??
          await ref
              .read(libraryRepositoryProvider)
              .getSongLyrics(
                currentSong.id,
                mode: settings.notificationLyricsSource,
              );
      if (!mounted || _lastNotifiedSongId != currentSong.id) {
        return;
      }
      lyricsPreview = desktopNotificationLyricsPreview(
        lyrics: lyrics,
        song: currentSong,
        progressSeconds: progressSeconds,
      );
    }

    unawaited(
      _desktopFeatureService.showTrackNotification(
        TrackNotificationPayload(
          songId: currentSong.id,
          title: currentSong.title,
          artist: desktopNotificationArtist(currentSong, i18n),
          album: desktopNotificationAlbum(currentSong, i18n),
          lyricsPreview: lyricsPreview,
        ),
      ),
    );
  }

  void _handleDesktopFeatureAction(DesktopFeatureAction action) {
    if (!mounted) {
      return;
    }

    switch (action.command) {
      case DesktopFeatureCommand.toggleWindowVisibility:
        unawaited(_toggleDesktopWindowVisibility());
      case DesktopFeatureCommand.showWindow:
        unawaited(_desktopFeatureService.showWindow());
      case DesktopFeatureCommand.windowVisibilityChanged:
        _setDesktopWindowVisible(action.isWindowVisible ?? true);
      case DesktopFeatureCommand.windowFullScreenChanged:
        _setDesktopWindowFullScreen(action.isWindowFullScreen ?? false);
      case DesktopFeatureCommand.playPause:
        _mediaControlController.onTogglePlayPause();
      case DesktopFeatureCommand.previous:
        _playPreviousFromCurrentQueue();
      case DesktopFeatureCommand.next:
        _playNextFromCurrentQueue();
      case DesktopFeatureCommand.stop:
        _mediaControlController.onStop();
      case DesktopFeatureCommand.quickPlay:
        _quickPlayLibrary(ref);
      case DesktopFeatureCommand.toggleDesktopLyrics:
        _toggleDesktopLyricsFromPlatform();
      case DesktopFeatureCommand.disableDesktopLyrics:
        _disableDesktopLyrics();
      case DesktopFeatureCommand.toggleDesktopLyricsLock:
        _toggleDesktopLyricsLock();
      case DesktopFeatureCommand.desktopLyricsOffsetBackward:
        _updateCurrentDesktopLyricsOffset(-100);
      case DesktopFeatureCommand.desktopLyricsOffsetForward:
        _updateCurrentDesktopLyricsOffset(100);
      case DesktopFeatureCommand.resetDesktopLyricsOffset:
        _resetCurrentDesktopLyricsOffset();
      case DesktopFeatureCommand.openSettings:
        _navigateTo('/settings');
      case DesktopFeatureCommand.quit:
        unawaited(_desktopFeatureService.quit());
      case DesktopFeatureCommand.playRecentSong:
        _playRecentSongFromPlatform(action.songId!);
      case DesktopFeatureCommand.openExternalAudioFiles:
        unawaited(_openExternalAudioFiles(action.filePaths));
      case DesktopFeatureCommand.desktopLyricsBoundsChanged:
        unawaited(
          _settingsController.updateSettings(
            AppSettingsUpdate(desktopLyricsBounds: action.desktopLyricsBounds),
          ),
        );
      case DesktopFeatureCommand.mediaSessionSeekTo:
        _mediaControlController.onSeek(action.seekSeconds!);
      case DesktopFeatureCommand.voiceCommand:
        _executeExternalVoiceCommand(action.voiceCommandText!);
    }
  }

  Future<void> _toggleDesktopWindowVisibility() async {
    await _desktopFeatureService.toggleWindowVisibility();
    final visible = await _desktopFeatureService.getWindowVisible();
    if (!mounted) {
      return;
    }
    _setDesktopWindowVisible(visible);
  }

  void _setDesktopWindowVisible(bool visible) {
    if (_isWindowVisible == visible) {
      return;
    }
    setState(() {
      _isWindowVisible = visible;
      _lastDesktopTraySignature = null;
    });
  }

  void _setDesktopWindowFullScreen(bool fullScreen) {
    final currentPath = widget.currentPath ?? _currentPath;
    final nextPath =
        !fullScreen && currentPath == '/now-playing/full'
            ? '/now-playing'
            : currentPath;
    if (_isWindowFullScreen == fullScreen && nextPath == currentPath) {
      return;
    }
    setState(() {
      _isWindowFullScreen = fullScreen;
      if (nextPath != currentPath) {
        _currentPath = nextPath;
      }
    });
    if (nextPath != currentPath) {
      widget.onNavigate?.call(nextPath);
    }
  }

  void _handleInitialExternalInputs() {
    for (final command in widget.initialExternalCommands) {
      _handleExternalAppCommand(command);
    }
    if (widget.initialExternalFilePaths.isNotEmpty) {
      unawaited(_openExternalAudioFiles(widget.initialExternalFilePaths));
    }
  }

  void _handleExternalAppCommand(ExternalAppCommand command) {
    switch (command.kind) {
      case ExternalAppCommandKind.playPause:
        _mediaControlController.onTogglePlayPause();
      case ExternalAppCommandKind.next:
        _playNextFromCurrentQueue();
      case ExternalAppCommandKind.previous:
        _playPreviousFromCurrentQueue();
      case ExternalAppCommandKind.stop:
        _mediaControlController.onStop();
      case ExternalAppCommandKind.quickPlay:
        _quickPlayLibrary(ref);
      case ExternalAppCommandKind.showWindow:
        unawaited(_desktopFeatureService.showWindow());
      case ExternalAppCommandKind.toggleDesktopLyrics:
        _toggleDesktopLyricsFromPlatform();
      case ExternalAppCommandKind.voiceCommand:
        _executeExternalVoiceCommand(command.text);
    }
  }

  void _executeExternalVoiceCommand(String command) {
    final snapshot = ref.read(musicLibrarySnapshotProvider).valueOrNull;
    final i18n =
        ref.read(smPlayerI18nProvider).valueOrNull ??
        const SmPlayerI18n(locale: smPlayerFallbackLocale, messages: {});
    _executeVoiceAssistantCommand(command, snapshot, i18n);
  }

  Future<void> _openExternalAudioFiles(List<String> filePaths) async {
    final repository = ref.read(libraryRepositoryProvider);
    final openedSongIds = await repository.importExternalAudioFiles(filePaths);
    if (!mounted || openedSongIds.isEmpty) {
      return;
    }

    final snapshot = await repository.getMusicLibrarySnapshot();
    final openedSongIdSet = openedSongIds.toSet();
    final queueWithoutOpened =
        snapshot.nowPlaying.songIds
            .where((songId) => !openedSongIdSet.contains(songId))
            .toList();
    final currentQueueIndex = _mediaControlController.state.selectedQueueIndex;
    final insertIndex =
        min(max(currentQueueIndex ?? -1, -1), queueWithoutOpened.length - 1) +
        1;
    final nextQueue = [
      ...queueWithoutOpened.take(insertIndex),
      ...openedSongIds,
      ...queueWithoutOpened.skip(insertIndex),
    ];
    await repository.replaceNowPlaying(nextQueue);
    if (!mounted) {
      return;
    }

    ref.invalidate(musicLibrarySnapshotProvider);
    _settingsController.savePlaybackSettingsImmediate(
      PlaybackSettingsUpdate(lastMusicIndex: insertIndex, musicProgress: 0),
    );

    final songsById = {for (final song in snapshot.songs) song.id: song};
    final song = songsById[openedSongIds.first]!;
    _mediaControlController.playTrack(
      MediaControlTrack(
        id: song.id,
        title: song.title,
        artist: song.artist,
        artworkUrl: song.thumbnailPath,
        isLoading: false,
        favorite: song.favorite,
      ),
      durationSeconds: song.duration.toDouble(),
      queueIndex: insertIndex,
    );
    _navigateTo('/now-playing');
    await _desktopFeatureService.showWindow();
  }

  void _toggleDesktopLyricsFromPlatform() {
    final nextEnabled = !_settingsController.snapshot.desktopLyricsEnabled;
    unawaited(
      _settingsController
          .updateSettings(AppSettingsUpdate(desktopLyricsEnabled: nextEnabled))
          .then((_) {
            if (mounted) {
              setState(() {});
            }
          }),
    );
  }

  void _playRecentSongFromPlatform(int songId) {
    final snapshot = ref.read(musicLibrarySnapshotProvider).valueOrNull;
    final songsById = {
      for (final song in snapshot?.songs ?? const <LibrarySong>[])
        song.id: song,
    };
    final song = songsById[songId];
    if (song == null) {
      return;
    }

    ref.read(libraryRepositoryProvider).replaceNowPlaying([song.id]);
    ref.invalidate(musicLibrarySnapshotProvider);
    _mediaControlController.playTrack(
      MediaControlTrack(
        id: song.id,
        title: song.title,
        artist: song.artist,
        artworkUrl: song.thumbnailPath,
        isLoading: false,
        favorite: song.favorite,
      ),
      durationSeconds: song.duration.toDouble(),
      queueIndex: 0,
    );
  }

  void _toggleDesktopLyricsLock() {
    final nextLocked = !_settingsController.snapshot.desktopLyricsLocked;
    unawaited(
      _settingsController
          .updateSettings(AppSettingsUpdate(desktopLyricsLocked: nextLocked))
          .then((_) {
            if (mounted) {
              setState(() {});
            }
          }),
    );
  }

  void _disableDesktopLyrics() {
    unawaited(
      _settingsController
          .updateSettings(const AppSettingsUpdate(desktopLyricsEnabled: false))
          .then((_) {
            if (mounted) {
              setState(() {});
            }
          }),
    );
  }

  void _updateCurrentDesktopLyricsOffset(int deltaMs) {
    final song = _currentDesktopLyricsSong();
    if (song == null) {
      return;
    }
    _updateDesktopLyricsOffset(song, song.lyricsOffsetMs + deltaMs);
  }

  void _resetCurrentDesktopLyricsOffset() {
    final song = _currentDesktopLyricsSong();
    if (song == null) {
      return;
    }
    _updateDesktopLyricsOffset(song, 0);
  }

  LibrarySong? _currentDesktopLyricsSong() {
    final snapshot = ref.read(musicLibrarySnapshotProvider).valueOrNull;
    return _resolvePlayerSong(_mediaControlController.state, snapshot);
  }

  void _updateDesktopLyricsOffset(LibrarySong song, int offsetMs) {
    unawaited(
      ref
          .read(libraryRepositoryProvider)
          .updateLyricsOffset(song.id, offsetMs)
          .then((_) {
            ref.invalidate(musicLibrarySnapshotProvider);
            _lastDesktopLyricsSignature = null;
            if (mounted) {
              setState(() {});
            }
          }),
    );
  }

  Future<void> _saveNavigationCollapsed(bool collapsed) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(
      SmPlayerShellStorageKeys.navigationCollapsed,
      collapsed,
    );
  }

  void _commitSearch(
    String value, [
    SearchHistoryType type = SearchHistoryType.sidebar,
  ]) {
    final nextSearchText = value.trim();
    setState(() {
      _searchText = nextSearchText;
      if (nextSearchText.isNotEmpty) {
        _currentPath = '/search';
      }
    });
    if (nextSearchText.isNotEmpty) {
      _closeNavigationOverlay();
      widget.onSearchCommit?.call(nextSearchText, type);
    }
  }

  Future<void> _showVoiceAssistantDialog(
    MusicLibrarySnapshot? snapshot,
    SmPlayerI18n i18n,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return _VoiceAssistantDialog(
          i18n: i18n,
          getHint: () => _getVoiceAssistantHint(snapshot, i18n),
          onExecute: (command) {
            return _executeVoiceAssistantCommand(command, snapshot, i18n);
          },
        );
      },
    );
  }

  String _getVoiceAssistantHint(
    MusicLibrarySnapshot? snapshot,
    SmPlayerI18n i18n,
  ) {
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
    MusicLibrarySnapshot? snapshot,
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

    if (_isVoiceHelpCommand(lower)) {
      return i18n.t('voiceAssistant.help');
    }

    if (_matchesAny(lower, const ['quick play', 'quickplay']) ||
        command == '快速播放') {
      _quickPlayLibrary(ref);
      return i18n.t('voiceAssistant.executed');
    }

    if (_matchesAny(command, const ['下一首', '下首']) ||
        _matchesAny(lower, const ['next', 'next song'])) {
      _playNextFromCurrentQueue();
      return i18n.t('voiceAssistant.executed');
    }

    if (_matchesAny(command, const ['上一首', '上首']) ||
        _matchesAny(lower, const ['previous', 'prev', 'previous song'])) {
      _playPreviousFromCurrentQueue();
      return i18n.t('voiceAssistant.executed');
    }

    if (_matchesAny(command, const ['暂停']) ||
        _matchesAny(lower, const ['pause'])) {
      if (_mediaControlController.state.isPlaying) {
        _mediaControlController.onTogglePlayPause();
      }
      return i18n.t('voiceAssistant.executed');
    }

    if (_matchesAny(command, const ['继续', '恢复']) ||
        _matchesAny(lower, const ['continue', 'resume'])) {
      if (!_mediaControlController.state.isPlaying) {
        _mediaControlController.onTogglePlayPause();
      }
      return i18n.t('voiceAssistant.executed');
    }

    if (_matchesAny(command, const ['静音']) ||
        _matchesAny(lower, const ['mute'])) {
      if (!_mediaControlController.state.isMuted) {
        _mediaControlController.onToggleMute();
      }
      return i18n.t('voiceAssistant.executed');
    }

    if (_matchesAny(command, const ['取消静音']) ||
        _matchesAny(lower, const ['unmute'])) {
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

    final searchQuery = _stripVoicePrefix(command, const ['搜索', 'search']);
    if (searchQuery != null && searchQuery.isNotEmpty) {
      _commitSearch(searchQuery);
      return i18n.t('voiceAssistant.executed');
    }

    final playArtist = _stripVoicePrefix(command, const [
      '播放歌手',
      '播放艺术家',
      'play artist',
      'play music by',
    ]);
    if (playArtist != null && playArtist.isNotEmpty) {
      return _playMatchedSongs(
        snapshot,
        i18n,
        playArtist,
        (song, query) =>
            song.artists.any((artist) => _voiceTextMatches(artist, query)) ||
            _voiceTextMatches(song.artist, query),
      );
    }

    final playAlbum = _stripVoicePrefix(command, const ['播放专辑', 'play album']);
    if (playAlbum != null && playAlbum.isNotEmpty) {
      return _playMatchedSongs(
        snapshot,
        i18n,
        playAlbum,
        (song, query) => _voiceTextMatches(song.album, query),
      );
    }

    final playPlaylist = _stripVoicePrefix(command, const [
      '播放列表',
      '播放歌单',
      'play playlist',
      'play list',
    ]);
    if (playPlaylist != null && playPlaylist.isNotEmpty) {
      return _playPlaylistByName(snapshot, i18n, playPlaylist);
    }

    final playFolder = _stripVoicePrefix(command, const [
      '播放文件夹',
      '播放文件',
      'play folder',
    ]);
    if (playFolder != null && playFolder.isNotEmpty) {
      _commitSearch(playFolder, SearchHistoryType.folders);
      return i18n.t('voiceAssistant.executed');
    }

    final playQuery = _stripVoicePrefix(command, const [
      '播放歌曲',
      '播放音乐',
      '播放',
      'play music',
      'play song',
      'play',
    ]);
    if (playQuery != null) {
      if (playQuery.isEmpty) {
        if (_mediaControlController.state.disabled) {
          _quickPlayLibrary(ref);
        } else if (!_mediaControlController.state.isPlaying) {
          _mediaControlController.onTogglePlayPause();
        }
        return i18n.t('voiceAssistant.executed');
      }
      return _playMatchedSongs(
        snapshot,
        i18n,
        playQuery,
        (song, query) =>
            _voiceTextMatches(song.title, query) ||
            _voiceTextMatches(song.artist, query) ||
            _voiceTextMatches(song.album, query),
      );
    }

    return i18n.t('voiceAssistant.notUnderstood');
  }

  String? _executeVoiceAssistantCommandResult(
    VoiceAssistantCommandResult result,
    MusicLibrarySnapshot? snapshot,
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
        if (_mediaControlController.state.disabled) {
          _quickPlayLibrary(ref);
        } else if (!_mediaControlController.state.isPlaying) {
          _mediaControlController.onTogglePlayPause();
        }
        return i18n.t('voiceAssistant.executed');
      case VoiceAssistantMatchType.pause:
        if (_mediaControlController.state.isPlaying) {
          _mediaControlController.onTogglePlayPause();
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
          (song, query) =>
              song.artists.any((artist) => _voiceTextMatches(artist, query)) ||
              _voiceTextMatches(song.artist, query),
        );
      case VoiceAssistantMatchType.playAlbum:
        return _playMatchedSongs(
          snapshot,
          i18n,
          result.value!,
          (song, query) => _voiceTextMatches(song.album, query),
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
          (song, query) =>
              _voiceTextMatches(song.title, query) ||
              _voiceTextMatches(song.artist, query) ||
              _voiceTextMatches(song.album, query),
        );
      case VoiceAssistantMatchType.playByArtistOrMusic:
        final request = result.request!;
        final artistSongs =
            (snapshot?.songs ?? const <LibrarySong>[])
                .where((song) => _songArtistMatches(song, request.right))
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
          (song, query) =>
              _voiceTextMatches(song.title, query) ||
              _voiceTextMatches(song.artist, query) ||
              _voiceTextMatches(song.album, query),
        );
      case VoiceAssistantMatchType.playByArtist:
      case VoiceAssistantMatchType.playByArtistAndMusic:
        final request = result.request!;
        return _playMatchedSongs(
          snapshot,
          i18n,
          request.left,
          (song, query) =>
              _voiceTextMatches(song.title, query) &&
              _songArtistMatches(song, request.right),
        );
      case VoiceAssistantMatchType.playByArtistAndAlbum:
        final request = result.request!;
        return _playMatchedSongs(
          snapshot,
          i18n,
          request.left,
          (song, query) =>
              _voiceTextMatches(song.album, query) &&
              _songArtistMatches(song, request.right),
        );
      case VoiceAssistantMatchType.playMusicInAlbum:
        final request = result.request!;
        final albumQuery = _stripVoiceTargetType(request.right, 'album');
        return _playMatchedSongs(
          snapshot,
          i18n,
          request.left,
          (song, query) =>
              _voiceTextMatches(song.title, query) &&
              _voiceTextMatches(song.album, albumQuery),
        );
      case VoiceAssistantMatchType.playMusicInPlaylist:
        final request = result.request!;
        return _playMatchingSongsInPlaylist(
          snapshot,
          i18n,
          _stripVoiceTargetType(request.right, 'playlist'),
          request.left,
        );
      case VoiceAssistantMatchType.playMusicInFolder:
        final request = result.request!;
        final folderQuery = _stripVoiceTargetType(request.right, 'folder');
        return _playMatchedSongs(
          snapshot,
          i18n,
          request.left,
          (song, query) =>
              _voiceTextMatches(song.title, query) &&
              _voiceTextMatches(_displayFolderName(song.path), folderQuery),
        );
      case VoiceAssistantMatchType.playMusicIn:
        final request = result.request!;
        return _playMatchedSongs(
          snapshot,
          i18n,
          request.left,
          (song, query) =>
              _voiceTextMatches(song.title, query) &&
              (_voiceTextMatches(song.album, request.right) ||
                  _songArtistMatches(song, request.right) ||
                  _voiceTextMatches(
                    _displayFolderName(song.path),
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
    if (_matchesAny(command, const ['静音']) ||
        _matchesAny(lower, const ['mute'])) {
      if (!_mediaControlController.state.isMuted) {
        _mediaControlController.onToggleMute();
      }
      return i18n.t('voiceAssistant.executed');
    }
    if (_matchesAny(command, const ['取消静音']) ||
        _matchesAny(lower, const ['unmute'])) {
      if (_mediaControlController.state.isMuted) {
        _mediaControlController.onToggleMute();
      }
      return i18n.t('voiceAssistant.executed');
    }

    final amount = _firstVoiceNumber(command) ?? 10;
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
    MusicLibrarySnapshot? snapshot,
    SmPlayerI18n i18n,
    String query,
  ) {
    final playlists = snapshot?.playlists ?? const <LibraryPlaylist>[];
    for (final playlist in playlists) {
      if (_voiceTextMatches(playlist.name, query)) {
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
    MusicLibrarySnapshot? snapshot,
    SmPlayerI18n i18n,
    String playlistQuery,
    String songQuery,
  ) {
    final playlists = snapshot?.playlists ?? const <LibraryPlaylist>[];
    for (final playlist in playlists) {
      if (_voiceTextMatches(playlist.name, playlistQuery)) {
        final playlistSongIds = playlist.songIds.toSet();
        return _playMatchedSongs(
          snapshot,
          i18n,
          songQuery,
          (song, query) =>
              playlistSongIds.contains(song.id) &&
              _voiceTextMatches(song.title, query),
        );
      }
    }
    return i18n.t('voiceAssistant.noResults', {'query': playlistQuery});
  }

  String _playMatchedSongs(
    MusicLibrarySnapshot? snapshot,
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

  void _playSongQueue(List<LibrarySong> songs) {
    final songIds = songs.map((song) => song.id).toList();
    final firstSong = songs.first;
    ref.read(libraryRepositoryProvider).replaceNowPlaying(songIds);
    ref.invalidate(musicLibrarySnapshotProvider);
    _mediaControlController.playTrack(
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
  }

  bool _playNextFromCurrentQueue({bool automatic = false}) {
    return _playQueueDirection(forward: true, automatic: automatic);
  }

  bool _playPreviousFromCurrentQueue() {
    return _playQueueDirection(forward: false, automatic: false);
  }

  bool _playQueueDirection({required bool forward, required bool automatic}) {
    final snapshot = ref.read(musicLibrarySnapshotProvider).valueOrNull;
    if (snapshot == null || snapshot.nowPlaying.songIds.isEmpty) {
      return false;
    }

    final currentIndex = _currentQueueIndex(snapshot);
    if (automatic &&
        forward &&
        _mediaControlController.state.mode == PlaybackMode.shuffle &&
        _settingsController.snapshot.shuffleAfterOneRound &&
        currentIndex >= snapshot.nowPlaying.songIds.length - 1) {
      return _shuffleAndPlayNextRound(snapshot);
    }

    final nextIndex = nextQueueIndexForPlayback(
      queueLength: snapshot.nowPlaying.songIds.length,
      currentIndex: currentIndex,
      mode: _mediaControlController.state.mode,
      forward: forward,
      automatic: automatic,
    );
    if (nextIndex == null) {
      return false;
    }

    _playQueueIndex(snapshot, nextIndex);
    return true;
  }

  bool _shuffleAndPlayNextRound(MusicLibrarySnapshot snapshot) {
    final nextSongIds = shuffleNextRoundSongIds(
      snapshot.nowPlaying.songIds,
      _mediaControlController.state.track.id,
    );
    unawaited(
      ref.read(libraryRepositoryProvider).replaceNowPlaying(nextSongIds),
    );
    ref.invalidate(musicLibrarySnapshotProvider);
    return _playQueueSong(snapshot, nextSongIds.first, 0);
  }

  int _currentQueueIndex(MusicLibrarySnapshot snapshot) {
    final selectedQueueIndex = _mediaControlController.state.selectedQueueIndex;
    if (selectedQueueIndex != null &&
        selectedQueueIndex >= 0 &&
        selectedQueueIndex < snapshot.nowPlaying.songIds.length) {
      return selectedQueueIndex;
    }

    final trackId = _mediaControlController.state.track.id;
    final trackIndex = snapshot.nowPlaying.songIds.indexOf(trackId ?? -1);
    return trackIndex == -1 ? 0 : trackIndex;
  }

  void _playQueueIndex(MusicLibrarySnapshot snapshot, int queueIndex) {
    final played = _playQueueSong(
      snapshot,
      snapshot.nowPlaying.songIds[queueIndex],
      queueIndex,
    );
    if (!played) {
      return;
    }
  }

  bool _playQueueSong(
    MusicLibrarySnapshot snapshot,
    int songId,
    int queueIndex,
  ) {
    final songsById = {for (final song in snapshot.songs) song.id: song};
    final song = songsById[songId];
    if (song == null) {
      return false;
    }

    _mediaControlController.playTrack(
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
    _settingsController.savePlaybackSettingsImmediate(
      PlaybackSettingsUpdate(lastMusicIndex: queueIndex, musicProgress: 0),
    );
    return true;
  }

  void _randomPlayPlaylist(WidgetRef ref, int playlistId) {
    final snapshot = ref.read(musicLibrarySnapshotProvider).value!;
    final playlist = snapshot.playlists.firstWhere(
      (playlist) => playlist.id == playlistId,
    );
    final songIds = playlist.songIds.toList()..shuffle(Random());
    final songsById = {for (final song in snapshot.songs) song.id: song};
    final firstSong = songsById[songIds.first]!;
    ref.read(libraryRepositoryProvider).replaceNowPlaying(songIds);
    _mediaControlController.playTrack(
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
    ref.invalidate(musicLibrarySnapshotProvider);
  }
}

bool _isVoiceHelpCommand(String lowerCommand) {
  return _matchesAny(lowerCommand, const ['help', 'get help']) ||
      lowerCommand == '帮助';
}

bool _matchesAny(String value, List<String> candidates) {
  return candidates.any((candidate) => value.trim() == candidate);
}

String? _stripVoicePrefix(String command, List<String> prefixes) {
  final trimmedCommand = _trimVoiceArgument(command);
  final lower = trimmedCommand.toLowerCase();
  for (final prefix in prefixes) {
    final lowerPrefix = prefix.toLowerCase();
    if (lower == lowerPrefix) {
      return '';
    }
    if (lower.startsWith(lowerPrefix)) {
      return _trimVoiceArgument(trimmedCommand.substring(prefix.length));
    }
  }
  return null;
}

String _trimVoiceArgument(String value) {
  return value
      .trim()
      .replaceAll(RegExp(r'^[\s:：,，。.!！?？"“”‘’《》]+'), '')
      .replaceAll(RegExp(r'[\s"“”‘’《》]+$'), '')
      .trim();
}

bool _voiceTextMatches(String value, String query) {
  return value.toLowerCase().contains(query.toLowerCase());
}

bool _songArtistMatches(LibrarySong song, String query) {
  return song.artists.any((artist) => _voiceTextMatches(artist, query)) ||
      _voiceTextMatches(song.artist, query);
}

String _stripVoiceTargetType(String value, String type) {
  return value
      .replaceFirst(RegExp('^$type\\s+', caseSensitive: false), '')
      .trim();
}

String _displayFolderName(String path) {
  final normalized = path.replaceAll('\\', '/');
  final index = normalized.lastIndexOf('/');
  return index >= 0 ? normalized.substring(index + 1) : normalized;
}

int? _firstVoiceNumber(String value) {
  final match = RegExp(r'\d+').firstMatch(value);
  return match == null ? null : int.parse(match.group(0)!);
}

class _MiniModeSurface extends StatefulWidget {
  const _MiniModeSurface({
    required this.state,
    required this.i18n,
    required this.currentSong,
    required this.repository,
    required this.playerLyricsSource,
    required this.onExit,
    required this.onTogglePlayPause,
    required this.onPrevious,
    required this.onNext,
    required this.onSeek,
    required this.onToggleFavorite,
    required this.onQuickPlay,
    required this.onToggleRepeat,
    required this.onToggleMute,
    required this.onVolumeChange,
    required this.onOpenVoiceAssistant,
  });

  final MediaControlState state;
  final SmPlayerI18n i18n;
  final LibrarySong? currentSong;
  final LibraryRepository repository;
  final LyricsRequestMode playerLyricsSource;
  final VoidCallback onExit;
  final VoidCallback onTogglePlayPause;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<double> onSeek;
  final VoidCallback onToggleFavorite;
  final VoidCallback onQuickPlay;
  final VoidCallback onToggleRepeat;
  final VoidCallback onToggleMute;
  final ValueChanged<int> onVolumeChange;
  final VoidCallback? onOpenVoiceAssistant;

  @override
  State<_MiniModeSurface> createState() => _MiniModeSurfaceState();
}

class _MiniModeSurfaceState extends State<_MiniModeSurface> {
  Timer? _controlsHideTimer;
  var _controlsVisible = false;
  var _volumeOpen = false;

  @override
  void dispose() {
    _controlsHideTimer?.cancel();
    super.dispose();
  }

  void _showControls([PointerEvent? _]) {
    _controlsHideTimer?.cancel();
    if (!_controlsVisible) {
      setState(() {
        _controlsVisible = true;
      });
    }
  }

  void _scheduleControlsHide([PointerEvent? _]) {
    _controlsHideTimer?.cancel();
    _controlsHideTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _controlsVisible = false;
        _volumeOpen = false;
      });
    });
  }

  Widget _visibleControls(Widget child) {
    return IgnorePointer(
      ignoring: !_controlsVisible,
      child: AnimatedOpacity(
        opacity: _controlsVisible ? 1 : 0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final i18n = widget.i18n;
    final currentSong = widget.currentSong;
    final repository = widget.repository;
    final playerLyricsSource = widget.playerLyricsSource;
    final onExit = widget.onExit;
    final onTogglePlayPause = widget.onTogglePlayPause;
    final onPrevious = widget.onPrevious;
    final onNext = widget.onNext;
    final onSeek = widget.onSeek;
    final onToggleFavorite = widget.onToggleFavorite;
    final onQuickPlay = widget.onQuickPlay;
    final onToggleRepeat = widget.onToggleRepeat;
    final onVolumeChange = widget.onVolumeChange;
    final onOpenVoiceAssistant = widget.onOpenVoiceAssistant;
    final artworkPath = currentSong?.thumbnailPath ?? state.track.artworkUrl;
    final title =
        state.track.title.isEmpty
            ? i18n.t('app.chooseSong')
            : state.track.title;
    final artist =
        state.track.artist.isEmpty
            ? i18n.t('common.artistUnknown')
            : state.track.artist;
    final noticeKey = state.playbackNoticeKey;
    final noticeText = noticeKey == null ? null : i18n.t(noticeKey);
    final duration = state.durationSeconds <= 0 ? 1.0 : state.durationSeconds;
    final progress = state.progressSeconds.clamp(0, duration).toDouble();

    return MouseRegion(
      onEnter: _showControls,
      onHover: _showControls,
      onExit: _scheduleControlsHide,
      child: Focus(
        onFocusChange: (focused) {
          if (focused) {
            _showControls();
          }
        },
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xff28394f), Color(0xff162130)],
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _MiniModeArtwork(path: artworkPath),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(
                    alpha: _controlsVisible ? 0.54 : 0.36,
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _visibleControls(
                        Row(
                          children: [
                            IconButton(
                              tooltip: i18n.t('player.exitMiniMode'),
                              onPressed: onExit,
                              color: Colors.white,
                              icon: const Icon(Icons.arrow_back_rounded),
                            ),
                            const Spacer(),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xd9ffffff),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (noticeText != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          noticeText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xff8bc8ff),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      _MiniModeLyricLine(
                        song: currentSong,
                        repository: repository,
                        playerLyricsSource: playerLyricsSource,
                        progressSeconds: state.progressSeconds,
                        durationSeconds: state.durationSeconds,
                      ),
                      const SizedBox(height: 18),
                      _visibleControls(
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _MiniModeButton(
                              tooltip: i18n.t('player.previous'),
                              icon: Icons.skip_previous_rounded,
                              disabled: state.disabled,
                              onPressed: onPrevious,
                            ),
                            const SizedBox(width: 12),
                            _MiniModeButton(
                              primary: true,
                              tooltip:
                                  state.isPlaying
                                      ? i18n.t('player.pause')
                                      : i18n.t('player.play'),
                              icon:
                                  state.isPlaying
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                              loading: state.track.isLoading,
                              disabled: state.disabled,
                              onPressed: onTogglePlayPause,
                            ),
                            const SizedBox(width: 12),
                            _MiniModeButton(
                              tooltip: i18n.t('player.next'),
                              icon: Icons.skip_next_rounded,
                              disabled: state.disabled,
                              onPressed: onNext,
                            ),
                          ],
                        ),
                      ),
                      _visibleControls(
                        Column(
                          children: [
                            const SizedBox(height: 18),
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 3,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 5,
                                ),
                              ),
                              child: Slider(
                                min: 0,
                                max: duration,
                                value: progress,
                                activeColor: Colors.white,
                                inactiveColor: Colors.white24,
                                onChanged: state.disabled ? null : onSeek,
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  tooltip: i18n.t('nowPlaying.quickPlay'),
                                  onPressed:
                                      state.disabled ? null : onQuickPlay,
                                  color: Colors.white,
                                  disabledColor: Colors.white38,
                                  icon: const Icon(Icons.casino_rounded),
                                ),
                                IconButton(
                                  tooltip: i18n.t('player.playbackModeRepeat'),
                                  onPressed:
                                      state.disabled ? null : onToggleRepeat,
                                  color:
                                      state.mode == PlaybackMode.repeat ||
                                              state.mode ==
                                                  PlaybackMode.repeatOne
                                          ? const Color(0xff8bc8ff)
                                          : Colors.white,
                                  disabledColor: Colors.white38,
                                  icon: Icon(
                                    state.mode == PlaybackMode.repeatOne
                                        ? Icons.repeat_one_rounded
                                        : Icons.repeat_rounded,
                                  ),
                                ),
                                IconButton(
                                  tooltip:
                                      state.track.favorite
                                          ? i18n.t('player.unlike')
                                          : i18n.t('player.like'),
                                  onPressed:
                                      state.disabled ? null : onToggleFavorite,
                                  color:
                                      state.track.favorite
                                          ? const Color(0xffff78a6)
                                          : Colors.white,
                                  disabledColor: Colors.white38,
                                  icon: Icon(
                                    state.track.favorite
                                        ? Icons.favorite_rounded
                                        : Icons.favorite_border_rounded,
                                  ),
                                ),
                                if (onOpenVoiceAssistant != null)
                                  IconButton(
                                    tooltip: i18n.t('player.voiceAssistant'),
                                    onPressed:
                                        state.disabled
                                            ? null
                                            : onOpenVoiceAssistant,
                                    color: Colors.white,
                                    disabledColor: Colors.white38,
                                    icon: const Icon(Icons.mic_rounded),
                                  ),
                                SizedBox(
                                  width: 48,
                                  height: 48,
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    alignment: Alignment.center,
                                    children: [
                                      IconButton(
                                        tooltip:
                                            state.isMuted
                                                ? i18n.t('player.unmute')
                                                : i18n.t('player.mute'),
                                        onPressed:
                                            state.disabled
                                                ? null
                                                : () {
                                                  setState(() {
                                                    _volumeOpen = !_volumeOpen;
                                                    _controlsVisible = true;
                                                  });
                                                },
                                        onLongPress:
                                            state.disabled
                                                ? null
                                                : widget.onToggleMute,
                                        color:
                                            _volumeOpen || state.isMuted
                                                ? const Color(0xff8bc8ff)
                                                : Colors.white,
                                        disabledColor: Colors.white38,
                                        icon: Icon(
                                          state.isMuted
                                              ? Icons.volume_off_rounded
                                              : Icons.volume_up_rounded,
                                        ),
                                      ),
                                      if (_volumeOpen)
                                        Positioned(
                                          bottom: 52,
                                          child: DecoratedBox(
                                            decoration: BoxDecoration(
                                              color: const Color(0xcc0d1726),
                                              borderRadius:
                                                  BorderRadius.circular(18),
                                              border: Border.all(
                                                color: Colors.white24,
                                              ),
                                            ),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 12,
                                                  ),
                                              child: VolumeSlider(
                                                value: clampVolumeValue(
                                                  state.volume,
                                                ),
                                                disabled: state.disabled,
                                                orientation:
                                                    VolumeSliderOrientation
                                                        .vertical,
                                                showTooltipOnMount: true,
                                                activeTrackColor: Colors.white,
                                                inactiveTrackColor:
                                                    Colors.white24,
                                                thumbColor: Colors.white,
                                                overlayColor: Colors.white24,
                                                tooltipBackgroundColor:
                                                    const Color(0xcc000000),
                                                tooltipForegroundColor:
                                                    Colors.white,
                                                onChange: onVolumeChange,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniModeLyricLine extends StatefulWidget {
  const _MiniModeLyricLine({
    required this.song,
    required this.repository,
    required this.playerLyricsSource,
    required this.progressSeconds,
    required this.durationSeconds,
  });

  final LibrarySong? song;
  final LibraryRepository repository;
  final LyricsRequestMode playerLyricsSource;
  final double progressSeconds;
  final double durationSeconds;

  @override
  State<_MiniModeLyricLine> createState() => _MiniModeLyricLineState();
}

class _MiniModeLyricLineState extends State<_MiniModeLyricLine> {
  LyricsSnapshot? _lyrics;
  int? _loadingSongId;

  @override
  void initState() {
    super.initState();
    _loadLyricsForSong();
  }

  @override
  void didUpdateWidget(covariant _MiniModeLyricLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.song?.id != widget.song?.id ||
        oldWidget.playerLyricsSource != widget.playerLyricsSource) {
      _lyrics = null;
      _loadLyricsForSong();
    }
  }

  @override
  Widget build(BuildContext context) {
    final lyrics = _lyrics;
    if (lyrics == null || lyrics.lines.isEmpty) {
      return const SizedBox.shrink();
    }

    final progressRatio =
        widget.durationSeconds > 0
            ? widget.progressSeconds / widget.durationSeconds
            : 0.0;
    final text = _resolveMiniModeLyricText(
      lyrics: lyrics,
      progressSeconds: widget.progressSeconds,
      progressRatio: progressRatio,
    );
    if (text.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.24),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.lyrics_rounded,
                color: Color(0xd9ffffff),
                size: 15,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadLyricsForSong() async {
    final song = widget.song;
    if (song == null) {
      _loadingSongId = null;
      return;
    }

    final songId = song.id;
    _loadingSongId = songId;
    final lyrics = await widget.repository.getSongLyrics(
      songId,
      mode: widget.playerLyricsSource,
    );
    if (!mounted || _loadingSongId != songId) {
      return;
    }
    setState(() {
      _lyrics = lyrics;
    });
  }
}

String _resolveMiniModeLyricText({
  required LyricsSnapshot lyrics,
  required double progressSeconds,
  required double progressRatio,
}) {
  final timedLines =
      lyrics.lines.where((line) => line.timestampMs != null).toList();
  if (timedLines.isNotEmpty) {
    final progressMs = max(0, (progressSeconds * 1000).floor());
    var currentText = '';
    for (final line in timedLines) {
      if (line.timestampMs! > progressMs) {
        break;
      }
      currentText = line.text;
    }
    return _toSingleDisplayLyricLine(currentText);
  }

  final lyricIndex = min(
    lyrics.lines.length - 1,
    (lyrics.lines.length * progressRatio.clamp(0, 1)).floor(),
  );
  return _toSingleDisplayLyricLine(lyrics.lines[lyricIndex].text);
}

String _toSingleDisplayLyricLine(String text) {
  final normalizedText = text
      .replaceAll(RegExp(r'\\r\\n|\\n|\\r'), '\n')
      .replaceAll(RegExp(r'\r\n|[\n\r\u2028\u2029]'), '\n');
  for (final segment in normalizedText.split('\n')) {
    final candidate = segment.trim();
    if (candidate.isNotEmpty) {
      return candidate;
    }
  }
  return '';
}

class _MiniModeArtwork extends StatelessWidget {
  const _MiniModeArtwork({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final file = path.isEmpty ? null : File(path);
    if (file != null && file.existsSync()) {
      return Image.file(file, fit: BoxFit.cover);
    }
    return const Center(
      child: Icon(Icons.music_note_rounded, color: Colors.white24, size: 120),
    );
  }
}

class _MiniModeButton extends StatelessWidget {
  const _MiniModeButton({
    required this.tooltip,
    required this.icon,
    required this.disabled,
    required this.onPressed,
    this.primary = false,
    this.loading = false,
  });

  final String tooltip;
  final IconData icon;
  final bool disabled;
  final VoidCallback onPressed;
  final bool primary;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: disabled ? null : onPressed,
      color: primary ? const Color(0xff172130) : Colors.white,
      disabledColor: primary ? const Color(0xff5e6b7a) : Colors.white38,
      style: IconButton.styleFrom(
        fixedSize: Size.square(primary ? 64 : 52),
        backgroundColor: primary ? Colors.white : Colors.white24,
        shape: const CircleBorder(),
      ),
      icon:
          loading
              ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              )
              : Icon(icon, size: primary ? 34 : 30),
    );
  }
}

class _Workspace extends StatelessWidget {
  const _Workspace({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _ShellColors.workspaceSurface,
        boxShadow: const [
          BoxShadow(
            color: _ShellColors.workspaceShadow,
            offset: Offset(0, 22),
            blurRadius: 56,
          ),
        ],
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: SizedBox.expand(child: child),
        ),
      ),
    );
  }
}

class _VoiceAssistantDialog extends StatefulWidget {
  const _VoiceAssistantDialog({
    required this.i18n,
    required this.getHint,
    required this.onExecute,
  });

  final SmPlayerI18n i18n;
  final String Function() getHint;
  final String Function(String command) onExecute;

  @override
  State<_VoiceAssistantDialog> createState() => _VoiceAssistantDialogState();
}

enum _VoiceAssistantCaptureState { idle, capturing, processing }

class _VoiceAssistantDialogState extends State<_VoiceAssistantDialog> {
  late final TextEditingController _controller;
  late final SpeechToText _speechToText;
  late final FlutterTts _tts;
  Timer? _closeTimer;
  Timer? _restartTimer;
  String? _result;
  String _statusText = '';
  var _state = _VoiceAssistantCaptureState.idle;
  var _session = 0;
  var _listening = false;
  var _processing = false;
  var _showHelpLink = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _speechToText = SpeechToText();
    _tts = FlutterTts();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openAssistant();
    });
  }

  @override
  void dispose() {
    _listening = false;
    _session += 1;
    _closeTimer?.cancel();
    _restartTimer?.cancel();
    unawaited(_speechToText.cancel());
    unawaited(_tts.stop());
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final i18n = widget.i18n;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xfafbfcff),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0x80b9c3d2)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x47232d3c),
                blurRadius: 28,
                offset: Offset(0, 16),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.mic_rounded, color: Color(0xff0063b1)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        i18n.t('player.voiceAssistant'),
                        style: const TextStyle(
                          color: Color(0xff111827),
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: i18n.t('common.close'),
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _VoiceAssistantStatus(
                  state: _state,
                  text:
                      _statusText.isEmpty
                          ? i18n.t('voiceAssistant.listening')
                          : _statusText,
                  showHelpLink: _showHelpLink,
                  onOpenHelp: _openHelp,
                  i18n: i18n,
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: i18n.t('voiceAssistant.command.play1'),
                    prefixIcon: const Icon(Icons.keyboard_voice_rounded),
                    filled: true,
                    fillColor: const Color(0xe6ffffff),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0x9ebec8d6)),
                    ),
                  ),
                  onSubmitted: (_) => _execute(),
                ),
                if (_result case final result?) ...[
                  const SizedBox(height: 12),
                  Text(
                    result,
                    style: const TextStyle(
                      color: Color(0xff344054),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                _VoiceCommandHelp(i18n: i18n),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(i18n.t('common.cancel')),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: _openAssistant,
                      icon: const Icon(Icons.mic_rounded),
                      label: Text(i18n.t('voiceAssistant.listening')),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: _execute,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Text(i18n.t('common.start')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openAssistant() async {
    _session += 1;
    final session = _session;
    _listening = true;
    _processing = false;
    _closeTimer?.cancel();
    _restartTimer?.cancel();
    await _tts.stop();
    await _speechToText.cancel();
    if (!mounted) {
      return;
    }
    setState(() {
      _result = null;
      _statusText = widget.getHint();
      _showHelpLink = true;
      _state = _VoiceAssistantCaptureState.idle;
    });
    await _startRecognition(session);
  }

  Future<void> _startRecognition(int session) async {
    _restartTimer?.cancel();
    final initialized = await _speechToText.initialize(
      onStatus: (status) => _handleSpeechStatus(status, session),
      onError: (error) => _handleSpeechError(error, session),
    );
    if (!_isActiveSession(session)) {
      return;
    }
    if (!initialized) {
      _stopListeningWithMessage(widget.i18n.t('voiceAssistant.unavailable'));
      return;
    }

    _controller.clear();
    setState(() {
      _state = _VoiceAssistantCaptureState.idle;
    });
    await _speechToText.listen(
      onResult: (result) => _handleSpeechResult(result, session),
      listenOptions: SpeechListenOptions(
        partialResults: true,
        listenMode: ListenMode.confirmation,
        localeId: widget.i18n.locale,
        pauseFor: const Duration(seconds: 2),
        listenFor: const Duration(seconds: 8),
      ),
    );
  }

  void _handleSpeechStatus(String status, int session) {
    if (!_isActiveSession(session)) {
      return;
    }
    if (status == 'listening') {
      setState(() {
        _state = _VoiceAssistantCaptureState.capturing;
      });
    }
    if ((status == 'done' || status == 'notListening') &&
        !_processing &&
        _controller.text.trim().isEmpty) {
      _scheduleRecognitionRestart(session);
    }
  }

  void _handleSpeechError(SpeechRecognitionError error, int session) {
    if (!_isActiveSession(session)) {
      return;
    }
    final message = error.errorMsg;
    if (message.contains('no_match') ||
        message.contains('no-speech') ||
        message.contains('speech_timeout')) {
      _scheduleRecognitionRestart(session);
      return;
    }
    _stopListeningWithMessage(
      message.contains('permission')
          ? widget.i18n.t('voiceAssistant.privacyRequired')
          : widget.i18n.t('voiceAssistant.recognitionUnavailable'),
    );
  }

  void _handleSpeechResult(SpeechRecognitionResult result, int session) {
    if (!_isActiveSession(session)) {
      return;
    }
    final transcript = result.recognizedWords.trim();
    if (transcript.isNotEmpty) {
      _controller.text = transcript;
      setState(() {
        _statusText = transcript;
        _showHelpLink = false;
        _state = _VoiceAssistantCaptureState.capturing;
      });
    }
    if (result.finalResult && transcript.isNotEmpty) {
      unawaited(_executeRecognizedCommand(transcript, session));
    }
  }

  Future<void> _executeRecognizedCommand(String command, int session) async {
    _processing = true;
    await _speechToText.stop();
    if (!_isActiveSession(session)) {
      return;
    }
    setState(() {
      _state = _VoiceAssistantCaptureState.processing;
      _statusText = widget.i18n.t('voiceAssistant.processing');
    });
    final result = widget.onExecute(command);
    if (!_isActiveSession(session)) {
      return;
    }
    setState(() {
      _result = result;
      _statusText = result;
    });
    if (result == widget.i18n.t('voiceAssistant.notUnderstood')) {
      await _speak(result);
      if (_isActiveSession(session)) {
        _processing = false;
        _scheduleRecognitionRestart(session);
      }
      return;
    }
    _listening = false;
    if (result != widget.i18n.t('voiceAssistant.executed') &&
        result != widget.i18n.t('voiceAssistant.canceled')) {
      await _speak(result);
    }
    _closeTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  Future<void> _speak(String message) async {
    await _tts.stop();
    await _tts.setLanguage(widget.i18n.locale);
    await _tts.awaitSpeakCompletion(true);
    await _tts.speak(message);
  }

  void _scheduleRecognitionRestart(int session) {
    _restartTimer?.cancel();
    _restartTimer = Timer(const Duration(milliseconds: 250), () {
      if (_isActiveSession(session)) {
        unawaited(_startRecognition(session));
      }
    });
  }

  void _stopListeningWithMessage(String message) {
    _listening = false;
    _processing = false;
    setState(() {
      _state = _VoiceAssistantCaptureState.idle;
      _showHelpLink = false;
      _statusText = message;
      _result = message;
    });
  }

  void _openHelp() {
    setState(() {
      _result = widget.i18n.t('voiceAssistant.help');
      _showHelpLink = false;
    });
  }

  bool _isActiveSession(int session) {
    return mounted && _listening && _session == session;
  }

  void _execute() {
    _listening = false;
    _processing = false;
    _session += 1;
    _restartTimer?.cancel();
    _closeTimer?.cancel();
    unawaited(_speechToText.stop());
    final result = widget.onExecute(_controller.text);
    setState(() {
      _result = result;
      _statusText = result;
      _showHelpLink = false;
      _state = _VoiceAssistantCaptureState.idle;
    });
  }
}

class _VoiceAssistantStatus extends StatelessWidget {
  const _VoiceAssistantStatus({
    required this.state,
    required this.text,
    required this.showHelpLink,
    required this.onOpenHelp,
    required this.i18n,
  });

  final _VoiceAssistantCaptureState state;
  final String text;
  final bool showHelpLink;
  final VoidCallback onOpenHelp;
  final SmPlayerI18n i18n;

  @override
  Widget build(BuildContext context) {
    final isProcessing = state == _VoiceAssistantCaptureState.processing;
    final isCapturing = state == _VoiceAssistantCaptureState.capturing;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isCapturing ? const Color(0x1f0063b1) : const Color(0x0f0d1826),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color:
              isCapturing ? const Color(0x660063b1) : const Color(0x1f536379),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            if (isProcessing)
              const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              )
            else
              Icon(
                isCapturing ? Icons.graphic_eq_rounded : Icons.mic_none_rounded,
                color: const Color(0xff0063b1),
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  color: Color(0xff344054),
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
            ),
            if (showHelpLink)
              TextButton(
                onPressed: onOpenHelp,
                child: Text(i18n.t('voiceAssistant.getHelp')),
              ),
          ],
        ),
      ),
    );
  }
}

class _VoiceCommandHelp extends StatelessWidget {
  const _VoiceCommandHelp({required this.i18n});

  final SmPlayerI18n i18n;

  @override
  Widget build(BuildContext context) {
    final commands = [
      ('voiceAssistant.command.play', 'voiceAssistant.command.play1'),
      (
        'voiceAssistant.command.playControl',
        'voiceAssistant.command.playControl1',
      ),
      ('voiceAssistant.command.search', 'voiceAssistant.command.search1'),
      ('voiceAssistant.command.volume', 'voiceAssistant.command.volume1'),
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0x0f0d1826),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x1f536379)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              i18n.t('voiceAssistant.supportedCommands'),
              style: const TextStyle(
                color: Color(0xff111827),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            for (final command in commands)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '${i18n.t(command.$1)}: ${i18n.t(command.$2)}',
                  style: const TextStyle(
                    color: Color(0xff5b697a),
                    height: 1.35,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

bool _usesNativeDesktopLyricsWindow() {
  return Platform.isWindows || Platform.isMacOS;
}

class _DesktopLyricsOverlay extends StatefulWidget {
  const _DesktopLyricsOverlay({
    required this.song,
    required this.settings,
    required this.repository,
    required this.i18n,
    required this.progressSeconds,
    required this.isPlaying,
    required this.onPrevious,
    required this.onNext,
    required this.onTogglePlayPause,
    required this.onSeekOffset,
    required this.onResetOffset,
    required this.onToggleLock,
    required this.onClose,
    required this.onOpenSettings,
  });

  final LibrarySong song;
  final SettingsSnapshot settings;
  final LibraryRepository repository;
  final SmPlayerI18n i18n;
  final double progressSeconds;
  final bool isPlaying;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onTogglePlayPause;
  final ValueChanged<int> onSeekOffset;
  final VoidCallback onResetOffset;
  final VoidCallback onToggleLock;
  final VoidCallback onClose;
  final VoidCallback onOpenSettings;

  @override
  State<_DesktopLyricsOverlay> createState() => _DesktopLyricsOverlayState();
}

class _DesktopLyricsOverlayState extends State<_DesktopLyricsOverlay> {
  LyricsSnapshot? _lyrics;
  var _loadingSongId = 0;

  @override
  void initState() {
    super.initState();
    _loadLyrics();
  }

  @override
  void didUpdateWidget(covariant _DesktopLyricsOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.song.id != widget.song.id ||
        oldWidget.settings.playerLyricsSource !=
            widget.settings.playerLyricsSource) {
      _loadLyrics();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;
    final textColor = _parseShellHexColor(
      settings.desktopLyricsColor,
    ).withValues(alpha: settings.desktopLyricsOpacity / 100);
    final strokeColor = _parseShellHexColor(
      settings.desktopLyricsStrokeColor,
    ).withValues(alpha: settings.desktopLyricsOpacity / 100);
    final lyricText = _resolveDesktopLyricText(
      lyrics: _lyrics,
      song: widget.song,
      progressSeconds: widget.progressSeconds,
    );
    final nextLyricText = _resolveNextDesktopLyricText(
      lyrics: _lyrics,
      progressSeconds: widget.progressSeconds,
      offsetMs: widget.song.lyricsOffsetMs,
    );

    return IgnorePointer(
      ignoring: settings.desktopLyricsLocked,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xcc101820),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0x30ffffff)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 24,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!settings.desktopLyricsLocked)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          _DesktopLyricsIconButton(
                            tooltip: widget.i18n.t('player.previous'),
                            icon: Icons.skip_previous_rounded,
                            onPressed: widget.onPrevious,
                          ),
                          _DesktopLyricsIconButton(
                            tooltip:
                                widget.isPlaying
                                    ? widget.i18n.t('player.pause')
                                    : widget.i18n.t('player.play'),
                            icon:
                                widget.isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                            onPressed: widget.onTogglePlayPause,
                          ),
                          _DesktopLyricsIconButton(
                            tooltip: widget.i18n.t('player.next'),
                            icon: Icons.skip_next_rounded,
                            onPressed: widget.onNext,
                          ),
                          const SizedBox(width: 8),
                          _DesktopLyricsTextButton(
                            label: '-0.1s',
                            onPressed: () => widget.onSeekOffset(-100),
                          ),
                          _DesktopLyricsTextButton(
                            label: '+0.1s',
                            onPressed: () => widget.onSeekOffset(100),
                          ),
                          _DesktopLyricsIconButton(
                            tooltip: widget.i18n.t(
                              'settings.desktopLyricsResetOffset',
                            ),
                            icon: Icons.restart_alt_rounded,
                            onPressed: widget.onResetOffset,
                          ),
                          const Spacer(),
                          _DesktopLyricsIconButton(
                            tooltip: widget.i18n.t(
                              'settings.desktopLyricsLockAction',
                            ),
                            icon: Icons.lock_open_rounded,
                            onPressed: widget.onToggleLock,
                          ),
                          _DesktopLyricsIconButton(
                            tooltip: widget.i18n.t('common.settings'),
                            icon: Icons.settings_rounded,
                            onPressed: widget.onOpenSettings,
                          ),
                          _DesktopLyricsIconButton(
                            tooltip: widget.i18n.t('common.close'),
                            icon: Icons.close_rounded,
                            onPressed: widget.onClose,
                          ),
                        ],
                      ),
                    ),
                  _ScrollingStrokeText(
                    text: lyricText,
                    textColor: textColor,
                    strokeColor: strokeColor,
                    fontFamily:
                        settings.desktopLyricsFontFamily == 'system'
                            ? null
                            : settings.desktopLyricsFontFamily,
                    fontSize: settings.desktopLyricsFontSize.toDouble(),
                    fontWeight: FontWeight.w800,
                  ),
                  if (nextLyricText.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      nextLyricText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: textColor.withValues(alpha: 0.74),
                        fontSize: max(13, settings.desktopLyricsFontSize - 8),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _loadLyrics() async {
    final songId = widget.song.id;
    _loadingSongId = songId;
    final lyrics = await widget.repository.getSongLyrics(
      songId,
      mode: widget.settings.playerLyricsSource,
    );
    if (!mounted || _loadingSongId != songId) {
      return;
    }
    setState(() {
      _lyrics = lyrics;
    });
  }
}

class _StrokeText extends StatelessWidget {
  const _StrokeText({
    required this.text,
    required this.textColor,
    required this.strokeColor,
    required this.fontSize,
    required this.fontWeight,
    this.fontFamily,
    this.overflow = TextOverflow.ellipsis,
    this.textAlign = TextAlign.center,
  });

  final String text;
  final Color textColor;
  final Color strokeColor;
  final double fontSize;
  final FontWeight fontWeight;
  final String? fontFamily;
  final TextOverflow overflow;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final baseStyle = TextStyle(
      fontFamily: fontFamily,
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: 1.15,
    );
    return Stack(
      alignment:
          textAlign == TextAlign.left ? Alignment.centerLeft : Alignment.center,
      children: [
        Text(
          text,
          maxLines: 1,
          overflow: overflow,
          textAlign: textAlign,
          style: baseStyle.copyWith(
            foreground:
                Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 3
                  ..color = strokeColor,
          ),
        ),
        Text(
          text,
          maxLines: 1,
          overflow: overflow,
          textAlign: textAlign,
          style: baseStyle.copyWith(color: textColor),
        ),
      ],
    );
  }
}

class _ScrollingStrokeText extends StatefulWidget {
  const _ScrollingStrokeText({
    required this.text,
    required this.textColor,
    required this.strokeColor,
    required this.fontSize,
    required this.fontWeight,
    this.fontFamily,
  });

  final String text;
  final Color textColor;
  final Color strokeColor;
  final double fontSize;
  final FontWeight fontWeight;
  final String? fontFamily;

  @override
  State<_ScrollingStrokeText> createState() => _ScrollingStrokeTextState();
}

class _ScrollingStrokeTextState extends State<_ScrollingStrokeText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void didUpdateWidget(covariant _ScrollingStrokeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.fontSize != widget.fontSize ||
        oldWidget.fontFamily != widget.fontFamily) {
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: widget.fontFamily,
      fontSize: widget.fontSize,
      fontWeight: widget.fontWeight,
      height: 1.15,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          maxLines: 1,
          textDirection: TextDirection.ltr,
        )..layout();
        final overflowDistance = max(0.0, painter.width - constraints.maxWidth);
        if (overflowDistance <= 0) {
          _controller.stop();
          return _StrokeText(
            text: widget.text,
            textColor: widget.textColor,
            strokeColor: widget.strokeColor,
            fontSize: widget.fontSize,
            fontWeight: widget.fontWeight,
            fontFamily: widget.fontFamily,
          );
        }

        final durationSeconds = min(
          12,
          max(5, (overflowDistance / 28).round() + 4),
        );
        _controller.duration = Duration(seconds: durationSeconds);
        if (!_controller.isAnimating) {
          _controller.repeat(reverse: true);
        }
        return ClipRect(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final value = Curves.easeInOut.transform(_controller.value);
              return Transform.translate(
                offset: Offset(-overflowDistance * value, 0),
                child: child,
              );
            },
            child: Align(
              alignment: Alignment.centerLeft,
              widthFactor: 1,
              child: SizedBox(
                width: painter.width,
                child: _StrokeText(
                  text: widget.text,
                  textColor: widget.textColor,
                  strokeColor: widget.strokeColor,
                  fontSize: widget.fontSize,
                  fontWeight: widget.fontWeight,
                  fontFamily: widget.fontFamily,
                  overflow: TextOverflow.visible,
                  textAlign: TextAlign.left,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DesktopLyricsIconButton extends StatelessWidget {
  const _DesktopLyricsIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      color: Colors.white,
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
    );
  }
}

class _DesktopLyricsTextButton extends StatelessWidget {
  const _DesktopLyricsTextButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: TextButton(
        style: TextButton.styleFrom(
          foregroundColor: Colors.white,
          visualDensity: VisualDensity.compact,
          minimumSize: const Size(46, 34),
        ),
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
}

String _resolveDesktopLyricText({
  required LyricsSnapshot? lyrics,
  required LibrarySong song,
  required double progressSeconds,
}) {
  final snapshot = lyrics;
  if (snapshot == null || snapshot.lines.isEmpty) {
    return song.title;
  }
  if (!snapshot.isSynced) {
    return snapshot.lines.first.text;
  }
  final line = _currentDesktopLyricLine(
    snapshot,
    progressSeconds,
    song.lyricsOffsetMs,
  );
  return line?.text.isEmpty == false ? line!.text : song.title;
}

String _resolveNextDesktopLyricText({
  required LyricsSnapshot? lyrics,
  required double progressSeconds,
  required int offsetMs,
}) {
  final snapshot = lyrics;
  if (snapshot == null || !snapshot.isSynced) {
    return '';
  }
  final index = _currentDesktopLyricIndex(snapshot, progressSeconds, offsetMs);
  final nextIndex = index + 1;
  if (nextIndex < 0 || nextIndex >= snapshot.lines.length) {
    return '';
  }
  return snapshot.lines[nextIndex].text;
}

LyricsLine? _currentDesktopLyricLine(
  LyricsSnapshot lyrics,
  double progressSeconds,
  int offsetMs,
) {
  final index = _currentDesktopLyricIndex(lyrics, progressSeconds, offsetMs);
  if (index < 0 || index >= lyrics.lines.length) {
    return null;
  }
  return lyrics.lines[index];
}

int _currentDesktopLyricIndex(
  LyricsSnapshot lyrics,
  double progressSeconds,
  int offsetMs,
) {
  final targetMs = (progressSeconds * 1000).round() + offsetMs;
  var currentIndex = 0;
  for (var index = 0; index < lyrics.lines.length; index += 1) {
    final timestamp = lyrics.lines[index].timestampMs;
    if (timestamp == null || timestamp > targetMs) {
      break;
    }
    currentIndex = index;
  }
  return currentIndex;
}

Color _parseShellHexColor(String value) {
  return Color(0xff000000 + int.parse(value.substring(1), radix: 16));
}

class _ShellColors {
  const _ShellColors._();

  static const bodyHighlight = Color(0xd1ffffff);
  static const bodyTop = Color(0xfff6f8fb);
  static const bodyBottom = Color(0xffedf2f7);
  static const workspaceSurface = Color(0xbdfafcff);
  static const workspaceShadow = Color(0x2e2f425c);
}
