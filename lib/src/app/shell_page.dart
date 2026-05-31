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
import 'package:smplayer_flutter/src/app/shell_actions.dart';
import 'package:smplayer_flutter/src/app/shell_colors.dart';
import 'package:smplayer_flutter/src/app/shell_models.dart';
import 'package:smplayer_flutter/src/app/shell_workspace.dart';
import 'package:smplayer_flutter/src/app/shell_voice_helpers.dart';
import 'package:smplayer_flutter/src/app/shell_widgets.dart';
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
import 'package:smplayer_flutter/src/lyrics/desktop_lyrics_overlay.dart';
import 'package:smplayer_flutter/src/platform/desktop_features.dart';
import 'package:smplayer_flutter/src/platform/external_open_model.dart';
import 'package:smplayer_flutter/src/playback/media_control.dart';
import 'package:smplayer_flutter/src/playback/media_control_model.dart';
import 'package:smplayer_flutter/src/playback/media_control_provider.dart';
import 'package:smplayer_flutter/src/playback/media_control_track_factory.dart';
import 'package:smplayer_flutter/src/playback/mini_mode_surface.dart';
import 'package:smplayer_flutter/src/playback/now_playing_full_route.dart';
import 'package:smplayer_flutter/src/playback/quick_play_model.dart';
import 'package:smplayer_flutter/src/settings/artist_split_review_dialog.dart';
import 'package:smplayer_flutter/src/settings/release_notes_dialog.dart';
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
  late var _isMiniMode = widget.initialDisplayMode == SmPlayerDisplayMode.mini;
  var _isWindowVisible = true;
  late var _isWindowFullScreen =
      widget.initialDisplayMode == SmPlayerDisplayMode.fullScreen;
  var _isWindowMaximized = false;
  var _syncingAudioPlayer = false;
  var _audioLoadSerial = 0;
  double? _pendingAudioSeekSeconds;
  var _playbackRuntimeSettingsRestored = false;
  var _playbackTrackRestoreScheduled = false;
  var _playbackTrackRestored = false;
  List<int>? _playbackQueueOverride;
  SmPlayerNavigationMode? _navigationMode;
  var _currentPath = '/songs';
  final _routeMemory = <String, String>{};
  final _navigationHistory = <String>[];
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
    _persistCurrentPage(widget.currentPath ?? _currentPath);
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
      _recordNavigationLocation(currentLocation);
      _rememberRoute(currentLocation);
      _persistCurrentPage(currentPath);
      if (currentPath != '/now-playing/full') {
        unawaited(_desktopFeatureService.setWindowFullScreen(false));
      }
    }
  }

  @override
  void dispose() {
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
    final isNowPlayingFullRoute = currentPath == '/now-playing/full';
    final windowWidth = MediaQuery.sizeOf(context).width;
    final navigationMode = SmPlayerShellMetrics.navigationModeForWidth(
      windowWidth,
    );
    _syncNavigationMode(windowWidth);
    final isNavigationPaneVisible =
        isNowPlayingFullRoute
            ? false
            : navigationMode == SmPlayerNavigationMode.minimal
            ? _isMinimalNavigationOpen
            : _isNavigationPaneOpen;
    final canGoBack = widget.canGoBack || _navigationHistory.length > 1;
    final shellSidebarWidth =
        navigationMode == SmPlayerNavigationMode.minimal
            ? 0.0
            : navigationMode != SmPlayerNavigationMode.wide
            ? SmPlayerShellMetrics.collapsedSidebarWidth
            : isNavigationPaneVisible
            ? SmPlayerShellMetrics.sidebarWidth
            : SmPlayerShellMetrics.collapsedSidebarWidth;
    final sidebarSurfaceWidth =
        navigationMode == SmPlayerNavigationMode.minimal
            ? isNavigationPaneVisible
                ? SmPlayerShellMetrics.sidebarWidth
                : 0.0
            : isNavigationPaneVisible &&
                navigationMode != SmPlayerNavigationMode.wide
            ? SmPlayerShellMetrics.sidebarWidth
            : shellSidebarWidth;
    final shellColors = ShellThemeColors.of(context);
    final isNavigationOverlaySurface =
        isNavigationPaneVisible &&
        navigationMode != SmPlayerNavigationMode.wide;
    final rawHeaderedPlaylistAppBar = ref.watch(
      headeredPlaylistAppBarPortalProvider,
    );
    final currentLocation = widget.currentLocation ?? currentPath;
    final headeredPlaylistAppBar =
        rawHeaderedPlaylistAppBar != null &&
                (rawHeaderedPlaylistAppBar.routeLocation == null ||
                    rawHeaderedPlaylistAppBar.routeLocation == currentLocation)
            ? rawHeaderedPlaylistAppBar
            : null;
    final minimalTitlebarHeight =
        !isNowPlayingFullRoute &&
                navigationMode == SmPlayerNavigationMode.minimal
            ? SmPlayerShellMetrics.minimalTitlebarHeight
            : 0.0;
    final immersiveMinimalTitlebar =
        minimalTitlebarHeight > 0 && headeredPlaylistAppBar != null;
    final workspaceTop = immersiveMinimalTitlebar ? 0.0 : minimalTitlebarHeight;
    final navigationSurfaceTop =
        headeredPlaylistAppBar != null &&
                navigationMode == SmPlayerNavigationMode.minimal
            ? 0.0
            : minimalTitlebarHeight;
    final navigationContentTopInset =
        minimalTitlebarHeight - navigationSurfaceTop;
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
          isNowPlayingFullRoute
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
          ),
        ),
      ],
      child: Focus(
        autofocus: true,
        onKeyEvent: _handlePlaybackShortcutKey,
        child: Scaffold(
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [shellColors.bodyTop, shellColors.bodyBottom],
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [shellColors.bodyHighlight, Colors.transparent],
                  stops: const [0, 0.36],
                ),
              ),
              child: SafeArea(
                top: false,
                bottom: false,
                child:
                    _isMiniMode
                        ? _buildMiniModeHost()
                        : Stack(
                          fit: StackFit.expand,
                          children: [
                            AnimatedPositioned(
                              duration: const Duration(milliseconds: 180),
                              curve: Curves.easeOutCubic,
                              left:
                                  isNowPlayingFullRoute ? 0 : shellSidebarWidth,
                              top: workspaceTop,
                              right: 0,
                              height:
                                  isNowPlayingFullRoute
                                      ? MediaQuery.sizeOf(context).height
                                      : MediaQuery.sizeOf(context).height -
                                          SmPlayerShellMetrics.playerHeight +
                                          SmPlayerShellMetrics.playerTopRadius -
                                          workspaceTop,
                              child: SmPlayerWorkspace(
                                key: SmPlayerShellKeys.workspace,
                                currentPath: currentPath,
                                currentLocation:
                                    widget.currentLocation ?? currentPath,
                                headerHeight:
                                    SmPlayerShellMetrics.workspaceHeaderHeight,
                                showNavigationAppBar:
                                    navigationMode ==
                                        SmPlayerNavigationMode.minimal &&
                                    !isNowPlayingFullRoute,
                                navigationMenuLabel:
                                    isNavigationPaneVisible
                                        ? context.smPlayerI18n.t(
                                          'sidebar.collapseNavigation',
                                        )
                                        : context.smPlayerI18n.t(
                                          'sidebar.expandNavigation',
                                        ),
                                onNavigationMenuPressed: _toggleNavigationPane,
                                navigationAppBarTopInset:
                                    immersiveMinimalTitlebar
                                        ? minimalTitlebarHeight
                                        : 0,
                                child: widget.child,
                              ),
                            ),
                            if (isNowPlayingFullRoute)
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: AnimatedBuilder(
                                    animation: _mediaControlController,
                                    builder: (context, _) {
                                      return Consumer(
                                        builder: (context, ref, _) {
                                          final snapshot =
                                              ref
                                                  .watch(
                                                    libraryContentDataProvider,
                                                  )
                                                  .valueOrNull;
                                          _scheduleRestorePlaybackTrack(
                                            snapshot,
                                          );
                                          final mediaControlState =
                                              _mediaControlController.state;
                                          final currentSong =
                                              _resolvePlayerSong(
                                                mediaControlState,
                                                snapshot,
                                              );
                                          _ensurePlayerArtworkResolved(
                                            currentSong,
                                            ref,
                                          );
                                          final recentSongs =
                                              ref
                                                  .watch(recentPageDataProvider)
                                                  .valueOrNull
                                                  ?.recentSongs ??
                                              const <RecentLibrarySong>[];
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
                                            recentSongs: recentSongs,
                                            mediaControlState:
                                                mediaControlState,
                                            currentSong: currentSong,
                                          );
                                          return const SizedBox.shrink();
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ),
                            if (isNavigationOverlaySurface)
                              Positioned.fill(
                                child: GestureDetector(
                                  key: SmPlayerShellKeys.navigationDismissLayer,
                                  behavior: HitTestBehavior.translucent,
                                  onTap: _closeNavigationOverlay,
                                  child: const SizedBox.expand(),
                                ),
                              ),
                            if (!isNowPlayingFullRoute &&
                                (navigationMode !=
                                        SmPlayerNavigationMode.minimal ||
                                    _isMinimalNavigationOpen))
                              AnimatedPositioned(
                                duration: const Duration(milliseconds: 180),
                                curve: Curves.easeOutCubic,
                                left: 0,
                                top: navigationSurfaceTop,
                                bottom: SmPlayerShellMetrics.playerHeight,
                                width: sidebarSurfaceWidth,
                                child: ShellNavigationGlassSurface(
                                  key: SmPlayerShellKeys.sidebar,
                                  surface:
                                      isNavigationOverlaySurface
                                          ? shellColors.navigationOverlaySurface
                                          : shellColors.navigationSurface,
                                  shadowColor:
                                      isNavigationOverlaySurface
                                          ? navigationMode ==
                                                  SmPlayerNavigationMode.minimal
                                              ? shellColors
                                                  .navigationMinimalShadow
                                              : shellColors
                                                  .navigationOverlayShadow
                                          : Colors.transparent,
                                  shadowBlur:
                                      navigationMode ==
                                              SmPlayerNavigationMode.minimal
                                          ? 42
                                          : 48,
                                  child: Padding(
                                    padding: EdgeInsets.only(
                                      top: navigationContentTopInset,
                                    ),
                                    child: Consumer(
                                      builder: (context, ref, _) {
                                        final snapshot =
                                            ref
                                                .watch(
                                                  libraryContentDataProvider,
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
                                        final recentSearches =
                                            snapshot?.recentSearches ??
                                            const <SearchHistoryEntry>[];
                                        return MainNavigationView(
                                          isPaneOpen: isNavigationPaneVisible,
                                          showTitlebar:
                                              navigationMode !=
                                              SmPlayerNavigationMode.minimal,
                                          currentPath: currentPath,
                                          searchText: _searchText,
                                          i18n: i18n,
                                          canGoBack: canGoBack,
                                          playlists:
                                              snapshot?.playlists ?? const [],
                                          recentSearches: recentSearches,
                                          onPaneToggle: _toggleNavigationPane,
                                          onGoBack: _goBack,
                                          onSearchTextChanged: (value) {
                                            _searchText = value;
                                          },
                                          onSearchCommitted: (
                                            value, [
                                            type = SearchHistoryType.sidebar,
                                          ]) {
                                            _commitSearchWithRepository(
                                              value,
                                              type,
                                              repository: ref.read(
                                                libraryRepositoryProvider,
                                              ),
                                              onRecentSearchRecorded: () {
                                                _invalidateRecentSearchData();
                                              },
                                            );
                                          },
                                          onSearchCleared: _clearSearch,
                                          onItemInvoked: _navigateTo,
                                          onRecentSearchRemove: (entryId) {
                                            unawaited(
                                              ref
                                                  .read(
                                                    libraryRepositoryProvider,
                                                  )
                                                  .removeRecentSearches([
                                                    entryId,
                                                  ])
                                                  .then((_) {
                                                    _invalidateRecentSearchData();
                                                  }),
                                            );
                                          },
                                          onRecentSearchesClear: () {
                                            unawaited(
                                              ref
                                                  .read(
                                                    libraryRepositoryProvider,
                                                  )
                                                  .clearRecentSearches()
                                                  .then((_) {
                                                    _invalidateRecentSearchData();
                                                  }),
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
                                                  .read(
                                                    libraryRepositoryProvider,
                                                  )
                                                  .reorderPlaylists(
                                                    playlistIds,
                                                  ),
                                            );
                                            ref.invalidate(
                                              libraryContentDataProvider,
                                            );
                                          },
                                          onPlaylistRandomPlay: (playlistId) {
                                            unawaited(
                                              _randomPlayPlaylist(
                                                ref,
                                                playlistId,
                                              ),
                                            );
                                          },
                                          onWindowDragStart: _startWindowDrag,
                                          onWindowDragEnd: _stopWindowDrag,
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            if (minimalTitlebarHeight > 0)
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                height: minimalTitlebarHeight,
                                child: MinimalTitlebar(
                                  title:
                                      Platform.isMacOS
                                          ? ''
                                          : context.smPlayerI18n.t('app.shell'),
                                  canGoBack: canGoBack,
                                  backLabel: context.smPlayerI18n.t(
                                    'sidebar.back',
                                  ),
                                  onGoBack: _goBack,
                                  onWindowDragStart: _startWindowDrag,
                                  onWindowDragEnd: _stopWindowDrag,
                                  headeredPlaylistAppBar:
                                      headeredPlaylistAppBar,
                                ),
                              ),
                            if (Platform.isWindows &&
                                !isNowPlayingFullRoute &&
                                minimalTitlebarHeight == 0)
                              Positioned(
                                top: 0,
                                left: sidebarSurfaceWidth,
                                right: 0,
                                height:
                                    SmPlayerShellMetrics.minimalTitlebarHeight,
                                child: WindowsAppTitleBar(
                                  isMaximized: _isWindowMaximized,
                                  light:
                                      _lastWindowControlsLight ??
                                      (Theme.of(context).brightness ==
                                          Brightness.dark),
                                  showDragRegion: true,
                                  onWindowDragStart: _startWindowDrag,
                                  onWindowDragEnd: _stopWindowDrag,
                                  onMinimize: _minimizeDesktopWindow,
                                  onToggleMaximize:
                                      _toggleDesktopWindowMaximized,
                                  onClose: _closeDesktopWindow,
                                ),
                              ),
                            if (Platform.isWindows &&
                                !isNowPlayingFullRoute &&
                                minimalTitlebarHeight > 0)
                              Positioned(
                                top: 0,
                                right: 0,
                                width: WindowsAppTitleBar.controlsWidth,
                                height:
                                    SmPlayerShellMetrics.minimalTitlebarHeight,
                                child: WindowsAppTitleBar(
                                  isMaximized: _isWindowMaximized,
                                  light:
                                      _lastWindowControlsLight ??
                                      (Theme.of(context).brightness ==
                                          Brightness.dark),
                                  showDragRegion: false,
                                  onWindowDragStart: _startWindowDrag,
                                  onWindowDragEnd: _stopWindowDrag,
                                  onMinimize: _minimizeDesktopWindow,
                                  onToggleMaximize:
                                      _toggleDesktopWindowMaximized,
                                  onClose: _closeDesktopWindow,
                                ),
                              ),
                            if (!isNowPlayingFullRoute)
                              Positioned(
                                left: 0,
                                bottom: 0,
                                width: sidebarSurfaceWidth,
                                height: SmPlayerShellMetrics.playerHeight,
                                child: ShellNavigationGlassSurface(
                                  surface:
                                      isNavigationOverlaySurface
                                          ? shellColors.navigationOverlaySurface
                                          : shellColors.navigationSurface,
                                  shadowColor: Colors.transparent,
                                  shadowBlur: 0,
                                  child: const SizedBox.expand(),
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
                                                    libraryContentDataProvider,
                                                  )
                                                  .valueOrNull;
                                          _scheduleRestorePlaybackTrack(
                                            snapshot,
                                          );
                                          final currentSong =
                                              _resolvePlayerSong(
                                                mediaControlState,
                                                snapshot,
                                              );
                                          final playbackSongIds =
                                              snapshot == null
                                                  ? const <int>[]
                                                  : _playbackSongIds(snapshot);
                                          final previousButtonRestartsTrack =
                                              playbackSongIds.isNotEmpty &&
                                              shouldRestartCurrentTrackForPrevious(
                                                progressSeconds:
                                                    mediaControlState
                                                        .progressSeconds,
                                                queueLength:
                                                    playbackSongIds.length,
                                                restartAfterThresholdEnabled:
                                                    _settingsController
                                                        .snapshot
                                                        .previousButtonRestartsTrack,
                                              );
                                          _ensurePlayerArtworkResolved(
                                            currentSong,
                                            ref,
                                          );
                                          final i18n =
                                              ref
                                                  .watch(smPlayerI18nProvider)
                                                  .valueOrNull ??
                                              const SmPlayerI18n(
                                                locale: smPlayerFallbackLocale,
                                                messages: {},
                                              );
                                          final recentSongs =
                                              ref
                                                  .watch(recentPageDataProvider)
                                                  .valueOrNull
                                                  ?.recentSongs ??
                                              const <RecentLibrarySong>[];
                                          _syncDesktopFeatures(
                                            i18n: i18n,
                                            snapshot: snapshot,
                                            recentSongs: recentSongs,
                                            mediaControlState:
                                                mediaControlState,
                                            currentSong: currentSong,
                                          );
                                          final playerLyricsLine =
                                              resolvePlayerLyricLine(
                                                lyrics: _desktopLyricsForSong(
                                                  currentSong,
                                                ),
                                                song: currentSong,
                                                progressSeconds:
                                                    mediaControlState
                                                        .progressSeconds,
                                                durationSeconds:
                                                    mediaControlState
                                                        .durationSeconds,
                                              );
                                          return MediaControl(
                                            track: mediaControlState.track,
                                            currentSong: currentSong,
                                            playlists:
                                                snapshot?.playlists ?? const [],
                                            disabled: _isPlaybackQueueEmpty(
                                              snapshot,
                                            ),
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
                                            previousButtonRestartsTrack:
                                                previousButtonRestartsTrack,
                                            playbackNoticeKey:
                                                mediaControlState
                                                    .playbackNoticeKey,
                                            currentLyricsLine: playerLyricsLine,
                                            onTogglePlayPause:
                                                _togglePlayPauseFromCurrentQueue,
                                            onPrevious:
                                                _playPreviousFromCurrentQueue,
                                            onForcePrevious: () {
                                              _playPreviousFromCurrentQueue(
                                                forcePrevious: true,
                                              );
                                            },
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
                                                _toggleShufflePlayback,
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
                                              _navigateTo(
                                                nowPlayingFullRouteFrom(
                                                  widget.currentLocation ??
                                                      currentPath,
                                                ),
                                              );
                                            },
                                            onArtworkError:
                                                currentSong == null
                                                    ? null
                                                    : () {
                                                      _refreshPlayerArtworkAfterError(
                                                        currentSong,
                                                        ref,
                                                      );
                                                    },
                                            onToggleWindowFullScreen: () {
                                              _toggleDesktopWindowFullScreen();
                                            },
                                            isWindowFullScreen:
                                                _isWindowFullScreen,
                                            onEnterMiniMode: _enterMiniMode,
                                            onOpenVoiceAssistant:
                                                supportsVoiceAssistant()
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
                                                    : (name) {
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
                                                        defaultName: name,
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
                                            onResolvePreferenceLevel:
                                                currentSong == null
                                                    ? null
                                                    : () {
                                                      return ref
                                                          .read(
                                                            libraryRepositoryProvider,
                                                          )
                                                          .getPreferenceLevel(
                                                            'song',
                                                            '${currentSong.id}',
                                                          );
                                                    },
                                            onUndoPreference:
                                                currentSong == null
                                                    ? null
                                                    : () {
                                                      unawaited(
                                                        ref
                                                            .read(
                                                              libraryRepositoryProvider,
                                                            )
                                                            .removePreferenceItem(
                                                              'song',
                                                              '${currentSong.id}',
                                                            ),
                                                      );
                                                    },
                                            onSetPreference:
                                                currentSong == null
                                                    ? null
                                                    : (level) {
                                                      unawaited(
                                                        ref
                                                            .read(
                                                              libraryRepositoryProvider,
                                                            )
                                                            .addPreferenceItem(
                                                              'song',
                                                              '${currentSong.id}',
                                                              currentSong.title,
                                                              level,
                                                            ),
                                                      );
                                                    },
                                            onSeeArtist:
                                                currentSong == null
                                                    ? null
                                                    : () {
                                                      final artist =
                                                          resolvePlayerArtistRouteName(
                                                            currentSong,
                                                            context
                                                                .smPlayerI18n,
                                                          );
                                                      _navigateTo(
                                                        '/artists?artist=${Uri.encodeQueryComponent(artist)}',
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
                                                      _playerDialogNotifier
                                                          .value = (
                                                        song: currentSong,
                                                        mode:
                                                            SongDialogMode
                                                                .properties,
                                                      );
                                                    },
                                            onSeeLyrics:
                                                currentSong == null
                                                    ? null
                                                    : () {
                                                      _playerDialogNotifier
                                                          .value = (
                                                        song: currentSong,
                                                        mode:
                                                            SongDialogMode
                                                                .lyrics,
                                                      );
                                                    },
                                            onSeeAlbumArt:
                                                currentSong == null
                                                    ? null
                                                    : () {
                                                      _playerDialogNotifier
                                                          .value = (
                                                        song: currentSong,
                                                        mode:
                                                            SongDialogMode
                                                                .albumArt,
                                                      );
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
                                          .watch(libraryContentDataProvider)
                                          .valueOrNull;
                                  final state = _mediaControlController.state;
                                  final currentSong = _resolvePlayerSong(
                                    state,
                                    snapshot,
                                  );
                                  final settings = _settingsController.snapshot;
                                  if (!settings.desktopLyricsEnabled ||
                                      currentSong == null ||
                                      usesNativeDesktopLyricsWindow()) {
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
                                      child: DesktopLyricsOverlay(
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
                                            _togglePlayPauseFromCurrentQueue,
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
                                          _navigateTo(
                                            '/settings#desktop-lyrics',
                                          );
                                        },
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            ValueListenableBuilder<
                              ({LibrarySong song, SongDialogMode mode})?
                            >(
                              valueListenable: _playerDialogNotifier,
                              builder: (context, dialog, _) {
                                if (dialog == null) {
                                  return const SizedBox.shrink();
                                }
                                return ValueListenableBuilder<int>(
                                  valueListenable: _playerDialogRefreshNotifier,
                                  builder: (context, _, _) {
                                    return MusicDialog(
                                      song: dialog.song,
                                      initialMode: dialog.mode,
                                      canPause:
                                          _mediaControlController
                                              .state
                                              .isPlaying &&
                                          _mediaControlController
                                                  .state
                                                  .track
                                                  .id ==
                                              dialog.song.id,
                                      onPlay: _togglePlayPauseFromCurrentQueue,
                                      onReveal: _revealPath,
                                      onSaved: () {
                                        _playerDialogRefreshNotifier.value += 1;
                                      },
                                      onClose: () {
                                        _playerDialogNotifier.value = null;
                                      },
                                    );
                                  },
                                );
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
                                artworkPathBySongId: {
                                  for (final song
                                      in ref
                                              .watch(libraryContentDataProvider)
                                              .valueOrNull
                                              ?.songs ??
                                          const <LibrarySong>[])
                                    song.id: song.thumbnailPath,
                                },
                                onCancel: () {
                                  _dismissStartupArtistSplitReview();
                                },
                                onApply: (splits) {
                                  return _applyStartupArtistSplits(splits);
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
    LibraryContentData? snapshot,
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
}
