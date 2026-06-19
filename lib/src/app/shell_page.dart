import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:smplayer_flutter/src/app/app_appearance_model.dart';
import 'package:smplayer_flutter/src/app/app_route_model.dart';
import 'package:smplayer_flutter/src/app/input_dialog.dart';
import 'package:smplayer_flutter/src/app/main_navigation_view.dart';
import 'package:smplayer_flutter/src/app/shell_desktop_lyrics_host.dart';
import 'package:smplayer_flutter/src/app/shell_actions.dart';
import 'package:smplayer_flutter/src/app/shell_colors.dart';
import 'package:smplayer_flutter/src/app/shell_frame.dart';
import 'package:smplayer_flutter/src/app/shell_layout_state.dart';
import 'package:smplayer_flutter/src/app/shell_models.dart';
import 'package:smplayer_flutter/src/app/shell_navigation_host.dart';
import 'package:smplayer_flutter/src/app/shell_immersive_mode_sync_host.dart';
import 'package:smplayer_flutter/src/app/shell_overlay_host.dart';
import 'package:smplayer_flutter/src/app/shell_player_host.dart';
import 'package:smplayer_flutter/src/app/shell_titlebar_host.dart';
import 'package:smplayer_flutter/src/app/shell_workspace_host.dart';
import 'package:smplayer_flutter/src/app/shell_voice_helpers.dart';
import 'package:smplayer_flutter/src/app/undoable_notification.dart';
import 'package:smplayer_flutter/src/app/voice_assistant_dialog.dart';
import 'package:smplayer_flutter/src/app/voice_assistant_model.dart';
import 'package:smplayer_flutter/src/app/window_drag_provider.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
import 'package:smplayer_flutter/src/library/data/library_repository.dart';
import 'package:smplayer_flutter/src/library/ui/headered_playlist_app_bar_portal.dart';
import 'package:smplayer_flutter/src/library/ui/headered_playlist_model.dart';
import 'package:smplayer_flutter/src/library/ui/headered_playlist_shell_metrics.dart';
import 'package:smplayer_flutter/src/library/ui/library_page_actions.dart';
import 'package:smplayer_flutter/src/library/ui/music_dialog.dart';
import 'package:smplayer_flutter/src/library/ui/popup_dialog.dart';
import 'package:smplayer_flutter/src/platform/desktop_feature_service.dart';
import 'package:smplayer_flutter/src/platform/external_open_model.dart';
import 'package:smplayer_flutter/src/playback/media_control.dart';
import 'package:smplayer_flutter/src/playback/media_control_model.dart';
import 'package:smplayer_flutter/src/playback/media_control_provider.dart';
import 'package:smplayer_flutter/src/playback/media_control_track_factory.dart';
import 'package:smplayer_flutter/src/playback/mini_mode_surface.dart';
import 'package:smplayer_flutter/src/playback/immersive_mode_route.dart';
import 'package:smplayer_flutter/src/playback/playback_queue_actions.dart';
import 'package:smplayer_flutter/src/playback/quick_play_model.dart';
import 'package:smplayer_flutter/src/settings/settings_controller.dart';
import 'package:smplayer_flutter/src/settings/settings_model.dart';

part 'shell_page_playback_methods.dart';
part 'shell_page_player_actions.dart';
part 'shell_page_navigation_methods.dart';
part 'shell_page_desktop_methods.dart';
part 'shell_page_voice_methods.dart';
part 'shell_page_queue_methods.dart';

bool _globalNavigationCollapsed = false;

@visibleForTesting
void resetSmPlayerShellGlobalStateForTest() {
  _globalNavigationCollapsed = false;
}

@visibleForTesting
void setSmPlayerShellNavigationCollapsedForTest(bool collapsed) {
  _globalNavigationCollapsed = collapsed;
}

class SmPlayerShellPage extends ConsumerStatefulWidget {
  const SmPlayerShellPage({
    super.key,
    this.child,
    this.currentPath,
    this.currentLocation,
    this.canGoBack = false,
    this.onNavigate,
    this.onGoBack,
    this.onSearchCommit,
    this.desktopFeatureService,
    this.settingsRepository,
    this.appVersion,
    this.initialExternalFilePaths = const [],
    this.initialExternalCommands = const [],
    this.initialDisplayMode = SmPlayerDisplayMode.normal,
  });

  final Widget? child;
  final String? currentPath;
  final String? currentLocation;
  final bool canGoBack;
  final ValueChanged<String>? onNavigate;
  final VoidCallback? onGoBack;
  final MainNavigationSearchCommit? onSearchCommit;
  final DesktopFeatureService? desktopFeatureService;
  final LibraryRepository? settingsRepository;
  final String? appVersion;
  final List<String> initialExternalFilePaths;
  final List<ExternalAppCommand> initialExternalCommands;
  final SmPlayerDisplayMode initialDisplayMode;

  @override
  ConsumerState<SmPlayerShellPage> createState() => _SmPlayerShellPageState();
}

class _SmPlayerShellPageState extends ConsumerState<SmPlayerShellPage>
    with WidgetsBindingObserver {
  static const _playbackStallCheckInterval = Duration(milliseconds: 500);
  static const _playbackStallTimeout = Duration(seconds: 8);
  static const _playbackProgressEpsilonSeconds = 0.05;
  static const _pendingSeekToleranceSeconds = 0.25;

  late final SettingsController _settingsController;
  late final MediaControlController _mediaControlController;
  late final DesktopFeatureService _desktopFeatureService;
  late final AudioPlayer _audioPlayer;
  late final List<StreamSubscription<Object?>> _audioSubscriptions;
  var _isNavigationPaneOpen = true;
  var _isMinimalNavigationOpen = false;
  var _isNavigationSearchHistoryOpen = false;
  var _navigationSearchDismissEpoch = 0;
  late var _isMiniMode = widget.initialDisplayMode == SmPlayerDisplayMode.mini;
  var _isWindowVisible = true;
  late var _isWindowFullScreen =
      widget.initialDisplayMode == SmPlayerDisplayMode.fullScreen;
  var _isWindowMaximized = false;
  var _syncingAudioPlayer = false;
  var _audioLoadSerial = 0;
  int? _loadingAudioTrackId;
  String? _loadingAudioPath;
  var _pendingAudioAutoplay = false;
  double? _pendingAudioSeekSeconds;
  var _playbackRuntimeSettingsRestored = false;
  var _playbackTrackRestoreScheduled = false;
  var _playbackTrackRestored = false;
  SmPlayerNavigationMode? _navigationMode;
  var _currentPath = '/songs';
  final _routeMemory = <String, String>{};
  final _navigationHistory = <String>[];
  final _pageStorageBucket = PageStorageBucket();
  var _searchText = '';
  int? _loadedAudioTrackId;
  String? _loadedAudioPath;
  int? _finishingAudioTrackId;
  final _persistedAudioDurations = <int, int>{};
  Timer? _playbackStallTimer;
  double _stalledProgressSeconds = 0;
  DateTime? _stalledProgressStartedAt;
  late final ValueNotifier<({LibrarySong song, SongDialogMode mode})?>
  _playerDialogNotifier;
  late final ValueNotifier<int> _playerDialogRefreshNotifier;
  String? _lastDesktopTraySignature;
  String? _lastDesktopLyricsSignature;
  String? _lastMediaSessionSignature;
  bool? _lastWindowControlsLight;
  int? _desktopLyricsSongId;
  int? _desktopLyricsLoadingSongId;
  LyricsRequestMode? _desktopLyricsMode;
  LyricsSnapshot? _desktopLyrics;
  var _playerLyricsRefreshRevision = 0;
  final _playerArtworkResolveAttemptedSongIds = <int>{};
  final _playerArtworkResolvingSongIds = <int>{};
  final _playerArtworkErrorAttemptedKeys = <String>{};
  final _playerArtworkErrorResolvingKeys = <String>{};
  String? _releaseNotesDialogVersion;
  var _releaseNotesChecked = false;
  ArtistSplitAnalysisResult? _startupArtistSplitResult;
  var _startupArtistSplitChecked = false;
  var _startupArtistSplitApplying = false;
  int? _lastNotifiedSongId;
  String? _lastPersistedPage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    HardwareKeyboard.instance.addHandler(_handlePlaybackShortcutKey);
    _settingsController = SettingsController(null, widget.settingsRepository);
    _mediaControlController = MediaControlController(
      null,
      _settingsController.savePlaybackSettingsImmediate,
    );
    _playerDialogNotifier = ValueNotifier(null);
    _playerDialogRefreshNotifier = ValueNotifier(0);
    _audioPlayer = AudioPlayer();
    _mediaControlController.addListener(_syncAudioPlayerFromController);
    _audioSubscriptions = [
      _audioPlayer.positionStream.listen(_handleAudioPositionChanged),
      _audioPlayer.durationStream.listen(_handleAudioDurationChanged),
      _audioPlayer.playerStateStream.listen(_handleAudioPlayerStateChanged),
      _audioPlayer.errorStream.listen(_handleAudioPlaybackError),
    ];
    _desktopFeatureService =
        widget.desktopFeatureService ??
        createDesktopFeatureService(
          settingsRepository: widget.settingsRepository,
        );
    unawaited(_desktopFeatureService.initialize(_handleDesktopFeatureAction));
    if (_isMiniMode) {
      unawaited(_desktopFeatureService.enterMiniMode());
    } else if (widget.initialDisplayMode == SmPlayerDisplayMode.fullScreen) {
      unawaited(_desktopFeatureService.setWindowFullScreen(true));
    } else {
      unawaited(_restoreDesktopWindowFullScreenState());
    }
    unawaited(_restoreDesktopWindowMaximizedState());
    unawaited(ref.read(libraryRepositoryProvider).commitPendingDeletes());
    _restorePlaybackRuntimeSettings();
    _restoreNavigationPaneState();
    _recordNavigationLocation(
      widget.currentLocation ?? widget.currentPath ?? _currentPath,
    );
    _rememberRoute(
      widget.currentLocation ?? widget.currentPath ?? _currentPath,
    );
    _persistCurrentPage(
      widget.currentLocation ?? widget.currentPath ?? _currentPath,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleInitialExternalInputs();
    });
  }

  @override
  void didUpdateWidget(covariant SmPlayerShellPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncNavigationMode(MediaQuery.sizeOf(context).width);
    final currentPath = widget.currentPath ?? _currentPath;
    final currentLocation = widget.currentLocation ?? currentPath;
    final previousLocation =
        oldWidget.currentLocation ?? oldWidget.currentPath ?? _currentPath;
    if (currentLocation != previousLocation) {
      if (_routeSection(_pathFromLocation(currentLocation)) == '/local' &&
          _routeSection(_pathFromLocation(previousLocation)) == '/local') {
        _replaceCurrentNavigationLocation(currentLocation);
      } else {
        _recordNavigationLocation(currentLocation);
      }
      _rememberRoute(currentLocation);
      _persistCurrentPage(currentLocation);
      if (currentPath != '/immersive-mode') {
        unawaited(_desktopFeatureService.setWindowFullScreen(false));
      }
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handlePlaybackShortcutKey);
    WidgetsBinding.instance.removeObserver(this);
    _mediaControlController.removeListener(_syncAudioPlayerFromController);
    for (final subscription in _audioSubscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(_audioPlayer.dispose());
    _stopPlaybackStallTimer();
    _desktopFeatureService.dispose();
    _settingsController.dispose();
    _playerDialogNotifier.dispose();
    _playerDialogRefreshNotifier.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncNavigationMode(MediaQuery.sizeOf(context).width);
  }

  @override
  void didChangeMetrics() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _syncNavigationMode(MediaQuery.sizeOf(context).width);
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentPath = widget.currentPath ?? _currentPath;
    final windowWidth = MediaQuery.sizeOf(context).width;
    _syncNavigationMode(windowWidth);
    final canGoBack = widget.canGoBack || _navigationHistory.length > 1;
    final shellColors = ShellThemeColors.of(context);
    final rawHeaderedPlaylistAppBar = ref.watch(
      headeredPlaylistAppBarPortalProvider,
    );
    ref.listen(lyricsSavedEventProvider, (previous, next) {
      if (next case final event?) {
        _refreshPlayerLyricsAfterSave(event.songId);
      }
    });
    final currentLocation = widget.currentLocation ?? currentPath;
    final layout = ShellLayoutState.resolve(
      currentPath: currentPath,
      currentLocation: currentLocation,
      windowWidth: windowWidth,
      navigationPaneOpen: _isNavigationPaneOpen,
      minimalNavigationOpen: _isMinimalNavigationOpen,
      canGoBack: canGoBack,
      rawHeaderedPlaylistAppBar: rawHeaderedPlaylistAppBar,
    );
    return ProviderScope(
      overrides: [
        mediaControlControllerProvider.overrideWith((ref) {
          return _mediaControlController;
        }),
        smPlayerWindowDragProvider.overrideWithValue(
          SmPlayerWindowDragCallbacks(
            onStart: _startWindowDrag,
            onEnd: _stopWindowDrag,
          ),
        ),
        headeredPlaylistScrollbarBottomProvider.overrideWithValue(
          layout.isImmersiveModeRoute
              ? 10
              : SmPlayerShellMetrics.playerTopRadius + 10,
        ),
        smPlayerShellActionsProvider.overrideWithValue(
          SmPlayerShellActions(
            onOpenVoiceAssistant:
                supportsVoiceAssistant()
                    ? () {
                      final snapshot =
                          ref.read(libraryContentDataProvider).valueOrNull;
                      final i18n =
                          ref.read(smPlayerI18nProvider).value ??
                          context.smPlayerI18n;
                      _showVoiceAssistantDialog(snapshot, i18n);
                    }
                    : null,
            onExitWindowFullScreen: () async {
              await _desktopFeatureService.setWindowFullScreen(false);
              if (mounted && _isWindowFullScreen) {
                setState(() {
                  _isWindowFullScreen = false;
                });
              }
            },
            onExitImmersiveMode: _exitImmersiveMode,
            onNavigate: _navigateTo,
          ),
        ),
      ],
      child: SmPlayerShellFrame(
        colors: shellColors,
        isMiniMode: _isMiniMode,
        miniModeHost: _buildMiniModeHost(),
        children: [
          ShellWorkspaceHost(
            layout: layout,
            pageStorageBucket: _pageStorageBucket,
            navigationMenuLabel: shellNavigationMenuLabel(
              context: context,
              navigationVisible: layout.isNavigationPaneVisible,
            ),
            onNavigationMenuPressed: _toggleNavigationPane,
            child: widget.child ?? const SizedBox.shrink(),
          ),
          ShellImmersiveModeSyncHost(
            visible: layout.isImmersiveModeRoute,
            mediaControlController: _mediaControlController,
            resolvePlayerSong: _resolvePlayerSong,
            scheduleRestorePlaybackTrack: _scheduleRestorePlaybackTrack,
            ensurePlayerArtworkResolved: _ensurePlayerArtworkResolved,
            syncDesktopFeatures: _syncDesktopFeatures,
          ),
          ShellNavigationDismissLayer(
            visible:
                layout.isNavigationOverlaySurface ||
                _isNavigationSearchHistoryOpen,
            leftInset: layout.sidebarSurfaceWidth,
            onDismiss: _dismissNavigationSurface,
          ),
          ShellNavigationHost(
            layout: layout,
            colors: shellColors,
            searchText: _searchText,
            onPaneToggle: _toggleNavigationPane,
            onGoBack: _goBack,
            onSearchTextChanged: (value) {
              setState(() {
                _searchText = value;
              });
            },
            onSearchCommitted: (value, [type = SearchHistoryType.sidebar]) {
              _commitSearchWithRepository(
                value,
                type,
                repository: ref.read(libraryRepositoryProvider),
                onRecentSearchRecorded: _invalidateRecentSearchData,
              );
            },
            onSearchCleared: _clearSearch,
            searchHistoryDismissEpoch: _navigationSearchDismissEpoch,
            onSearchHistoryOpenChanged: (open) {
              if (_isNavigationSearchHistoryOpen == open) {
                return;
              }
              setState(() {
                _isNavigationSearchHistoryOpen = open;
              });
            },
            onItemInvoked: _navigateTo,
            onRecentSearchRemove: (entryId) {
              unawaited(
                ref
                    .read(libraryRepositoryProvider)
                    .removeRecentSearches([entryId])
                    .then((_) {
                      _invalidateRecentSearchData();
                    }),
              );
            },
            onRecentSearchesClear: () {
              unawaited(
                ref.read(libraryRepositoryProvider).clearRecentSearches().then((
                  _,
                ) {
                  _invalidateRecentSearchData();
                }),
              );
            },
            onCreatePlaylist: () {
              final snapshot = ref.read(libraryContentDataProvider).valueOrNull;
              final i18n =
                  ref.read(smPlayerI18nProvider).value ?? context.smPlayerI18n;
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
                  snapshot: ref.read(libraryContentDataProvider).valueOrNull,
                  playlist: playlist,
                ),
              );
            },
            onRenamePlaylist: (playlist) {
              final snapshot = ref.read(libraryContentDataProvider).valueOrNull;
              final i18n =
                  ref.read(smPlayerI18nProvider).value ?? context.smPlayerI18n;
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
              final snapshot = ref.read(libraryContentDataProvider).valueOrNull;
              final i18n =
                  ref.read(smPlayerI18nProvider).value ?? context.smPlayerI18n;
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
            },
            onPlaylistRandomPlay: (playlistId) {
              unawaited(_randomPlayPlaylist(ref, playlistId));
            },
            onWindowDragStart: _startWindowDrag,
            onWindowDragEnd: _stopWindowDrag,
            onTitlebarTap: _dismissNavigationSurface,
          ),
          ShellTitlebarHost(
            layout: layout,
            windowControlsLight: _lastWindowControlsLight,
            isWindowMaximized: _isWindowMaximized,
            onGoBack: _goBack,
            onWindowDragStart: _startWindowDrag,
            onWindowDragEnd: _stopWindowDrag,
            onTitlebarTap: _dismissNavigationSurface,
            onMinimize: _minimizeDesktopWindow,
            onToggleMaximize: _toggleDesktopWindowMaximized,
            onClose: _closeDesktopWindow,
          ),
          ShellNavigationPlayerBackdrop(
            visible: !layout.isImmersiveModeRoute,
            layout: layout,
            colors: shellColors,
          ),
          ShellPlayerHost(
            layout: layout,
            mediaControlController: _mediaControlController,
            settingsController: _settingsController,
            isWindowFullScreen: _isWindowFullScreen,
            playerDialogNotifier: _playerDialogNotifier,
            resolvePlayerSong: _resolvePlayerSong,
            playbackSongIds: _playbackSongIds,
            isPlaybackQueueEmpty: _isPlaybackQueueEmpty,
            scheduleRestorePlaybackTrack: _scheduleRestorePlaybackTrack,
            ensurePlayerArtworkResolved: _ensurePlayerArtworkResolved,
            syncDesktopFeatures: _syncDesktopFeatures,
            desktopLyricsForSong: _desktopLyricsForSong,
            onTogglePlayPause: _togglePlayPauseFromCurrentQueue,
            onPrevious: _playPreviousFromCurrentQueue,
            onForcePrevious: () {
              _playPreviousFromCurrentQueue(forcePrevious: true);
            },
            onNext: _playNextFromCurrentQueue,
            onToggleShuffle: _toggleShufflePlayback,
            onToggleFavorite: _togglePlayerFavorite,
            onQuickPlay: _quickPlayLibrary,
            onOpenNowPlaying: () {
              _navigateTo(immersiveModeRoutePath);
            },
            onArtworkError: _refreshPlayerArtworkAfterError,
            onToggleWindowFullScreen: _toggleDesktopWindowFullScreen,
            onEnterMiniMode: _enterMiniMode,
            onOpenVoiceAssistant:
                supportsVoiceAssistant() ? _showVoiceAssistantDialog : null,
            onAddToNowPlaying: _addPlayerSongToNowPlaying,
            onCreatePlaylist: (ref, song, name) {
              createPlaylistWithSongs(
                context: context,
                ref: ref,
                i18n: context.smPlayerI18n,
                playlists:
                    ref
                        .read(libraryContentDataProvider)
                        .valueOrNull
                        ?.playlists ??
                    const [],
                defaultName: name,
                songIds: [song.id],
              );
            },
            onAddToPlaylist: (ref, song, playlistId) {
              _addPlayerSongToPlaylist(ref, song, playlistId);
            },
            onRevealPath: _revealPath,
            onNavigate: _navigateTo,
          ),
          ShellDesktopLyricsHost(
            layout: layout,
            mediaControlController: _mediaControlController,
            settingsController: _settingsController,
            resolvePlayerSong: _resolvePlayerSong,
            onPrevious: _playPreviousFromCurrentQueue,
            onNext: _playNextFromCurrentQueue,
            onTogglePlayPause: _togglePlayPauseFromCurrentQueue,
            onSeekOffset: (song, deltaMs) {
              _updateDesktopLyricsOffset(song, song.lyricsOffsetMs + deltaMs);
            },
            onResetOffset: (song) {
              _updateDesktopLyricsOffset(song, 0);
            },
            onToggleLock: _toggleDesktopLyricsLock,
            onClose: _disableDesktopLyrics,
            onOpenSettings: () {
              _navigateTo('/settings#desktop-lyrics');
            },
          ),
          ShellOverlayHost(
            playerDialogNotifier: _playerDialogNotifier,
            playerDialogRefreshNotifier: _playerDialogRefreshNotifier,
            mediaControlController: _mediaControlController,
            releaseNotesDialogVersion: _releaseNotesDialogVersion,
            startupArtistSplitResult: _startupArtistSplitResult,
            startupArtistSplitApplying: _startupArtistSplitApplying,
            onTogglePlayPause: _togglePlayPauseFromCurrentQueue,
            onRevealPath: _revealPath,
            onCloseReleaseNotes: _closeReleaseNotes,
            onDismissStartupArtistSplitReview: _dismissStartupArtistSplitReview,
            onApplyStartupArtistSplits: _applyStartupArtistSplits,
          ),
        ],
      ),
    );
  }

  LibrarySong? _resolvePlayerSong(
    MediaControlState mediaControlState,
    LibraryContentData? snapshot,
  ) {
    return resolveShellPlayerSong(snapshot, mediaControlState.track.id);
  }

  bool _handlePlaybackShortcutKey(KeyEvent event) {
    if (event is! KeyDownEvent) {
      return false;
    }
    if (_isWindowFullScreen && event.logicalKey == LogicalKeyboardKey.escape) {
      _exitDesktopWindowFullScreen();
      return true;
    }
    if (_shouldIgnorePlaybackShortcutFocus(
      FocusManager.instance.primaryFocus,
    )) {
      return false;
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
      return false;
    }

    _applyPlaybackShortcut(shortcut);
    return true;
  }
}
