import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:smplayer_flutter/src/app/app_appearance_model.dart';
import 'package:smplayer_flutter/src/app/app_route_model.dart';
import 'package:smplayer_flutter/src/app/app_version.dart';
import 'package:smplayer_flutter/src/app/input_dialog.dart';
import 'package:smplayer_flutter/src/app/main_navigation_view.dart';
import 'package:smplayer_flutter/src/app/shell_colors.dart';
import 'package:smplayer_flutter/src/app/shell_workspace.dart';
import 'package:smplayer_flutter/src/app/smplayer_vector_icons.dart';
import 'package:smplayer_flutter/src/app/undoable_notification.dart';
import 'package:smplayer_flutter/src/app/voice_assistant_model.dart';
import 'package:smplayer_flutter/src/app/window_drag_provider.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
import 'package:smplayer_flutter/src/library/data/library_repository.dart';
import 'package:smplayer_flutter/src/library/ui/artists_page_model.dart'
    as artists_model;
import 'package:smplayer_flutter/src/library/ui/headered_playlist_app_bar_portal.dart';
import 'package:smplayer_flutter/src/library/ui/headered_playlist_model.dart';
import 'package:smplayer_flutter/src/library/ui/headered_playlist_shell_metrics.dart';
import 'package:smplayer_flutter/src/library/ui/library_page_actions.dart';
import 'package:smplayer_flutter/src/library/ui/music_dialog.dart';
import 'package:smplayer_flutter/src/library/ui/song_display_helpers.dart';
import 'package:smplayer_flutter/src/platform/desktop_features.dart';
import 'package:smplayer_flutter/src/platform/external_open_model.dart';
import 'package:smplayer_flutter/src/playback/media_control.dart';
import 'package:smplayer_flutter/src/playback/media_control_model.dart';
import 'package:smplayer_flutter/src/playback/media_control_provider.dart';
import 'package:smplayer_flutter/src/playback/local_audio_file_source.dart';
import 'package:smplayer_flutter/src/playback/media_control_track_factory.dart';
import 'package:smplayer_flutter/src/playback/now_playing_full_route.dart';
import 'package:smplayer_flutter/src/playback/quick_play_model.dart';
import 'package:smplayer_flutter/src/settings/artist_split_review_dialog.dart';
import 'package:smplayer_flutter/src/settings/release_notes_dialog.dart';
import 'package:smplayer_flutter/src/settings/settings_controller.dart';
import 'package:smplayer_flutter/src/settings/settings_model.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

part 'shell_page_voice.dart';
part 'shell_page_mini_mode.dart';
part 'shell_page_shell_widgets.dart';
part 'shell_page_voice_dialog.dart';
part 'shell_page_desktop_lyrics.dart';

class SmPlayerShellMetrics {
  const SmPlayerShellMetrics._();

  static const playerHeight = 120.0;
  static const playerTopRadius = 18.0;
  static const sidebarWidth = 320.0;
  static const collapsedSidebarWidth = 64.0;
  static const minimalTitlebarHeight = 32.0;
  static const macOSTitlebarLeadingInset = 78.0;
  static const workspaceHeaderHeight = 92.0;
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

@visibleForTesting
String resolvePlayerArtistRouteName(LibrarySong song, SmPlayerI18n i18n) {
  final artists = artists_model.getSongArtists(song);
  return artists.isEmpty ? i18n.t('common.artistUnknown') : artists.first;
}

@visibleForTesting
double resolveQueuePlaybackStartSeconds({
  required int? currentTrackId,
  required int nextTrackId,
  required double currentProgressSeconds,
}) {
  return currentTrackId == nextTrackId ? currentProgressSeconds : 0;
}

@visibleForTesting
bool shouldIgnoreAudioPositionForPendingSeek({
  required double positionSeconds,
  required double? pendingSeekSeconds,
  required double toleranceSeconds,
}) {
  return pendingSeekSeconds != null &&
      (positionSeconds - pendingSeekSeconds).abs() > toleranceSeconds;
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
  static const minimalMenuButton = ValueKey('SmPlayerShell.MinimalMenuButton');
  static const navigationDismissLayer = ValueKey(
    'SmPlayerShell.NavigationDismissLayer',
  );
}

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
    @visibleForTesting this.initialMiniMode = false,
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
  final bool initialMiniMode;

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
  late var _isMiniMode = widget.initialMiniMode;
  var _isWindowVisible = true;
  var _isWindowFullScreen = false;
  var _syncingAudioPlayer = false;
  var _audioLoadSerial = 0;
  double? _pendingAudioSeekSeconds;
  var _playbackRuntimeSettingsRestored = false;
  var _playbackTrackRestoreScheduled = false;
  var _playbackTrackRestored = false;
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
  ({LibrarySong song, SongDialogMode mode})? _playerDialog;
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
    unawaited(_restoreDesktopWindowFullScreenState());
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
      setState(() {
        _syncNavigationMode(MediaQuery.sizeOf(context).width);
      });
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
    if (_navigationMode != navigationMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        final latestNavigationMode =
            SmPlayerShellMetrics.navigationModeForWidth(
              MediaQuery.sizeOf(context).width,
            );
        if (_navigationMode == latestNavigationMode) {
          return;
        }
        setState(() {
          _syncNavigationMode(MediaQuery.sizeOf(context).width);
        });
      });
    }
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
                                child: _ShellNavigationGlassSurface(
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
                                                .watch(libraryViewDataProvider)
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
                                            setState(() {
                                              _searchText = value;
                                            });
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
                                              libraryViewDataProvider,
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
                                child: _MinimalTitlebar(
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
                            if (!isNowPlayingFullRoute)
                              Positioned(
                                left: 0,
                                bottom: 0,
                                width: sidebarSurfaceWidth,
                                height: SmPlayerShellMetrics.playerHeight,
                                child: _ShellNavigationGlassSurface(
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
                                                    libraryViewDataProvider,
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
                                          _syncDesktopFeatures(
                                            i18n: i18n,
                                            snapshot: snapshot,
                                            mediaControlState:
                                                mediaControlState,
                                            currentSong: currentSong,
                                          );
                                          final playerLyricsLine =
                                              _resolvePlayerLyricLine(
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
                                            playbackNoticeKey:
                                                mediaControlState
                                                    .playbackNoticeKey,
                                            currentLyricsLine: playerLyricsLine,
                                            onTogglePlayPause:
                                                _togglePlayPauseFromCurrentQueue,
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
                                              _toggleNativeNowPlayingFullScreen();
                                            },
                                            isWindowFullScreen:
                                                _isWindowFullScreen,
                                            onEnterMiniMode: _enterMiniMode,
                                            onOpenVoiceAssistant:
                                                _supportsVoiceAssistant()
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
                                          .watch(libraryViewDataProvider)
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
                                onPlay: _togglePlayPauseFromCurrentQueue,
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
                                onApply: (splits) {
                                  unawaited(_applyStartupArtistSplits(splits));
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
    LibraryViewData? snapshot,
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
        _togglePlayPauseFromCurrentQueue();
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
        _toggleShufflePlayback();
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

  bool _isPlaybackQueueEmpty(LibraryViewData? snapshot) {
    return snapshot == null || _playbackSongIds(snapshot).isEmpty;
  }

  bool _togglePlayPauseFromCurrentQueue() {
    final state = _mediaControlController.state;
    if (state.track.id != null) {
      _mediaControlController.onTogglePlayPause();
      return true;
    }

    final snapshot = ref.read(libraryViewDataProvider).valueOrNull;
    if (_isPlaybackQueueEmpty(snapshot)) {
      return false;
    }
    _playQueueIndex(snapshot!, _playbackSongIds(snapshot), 0);
    return true;
  }

  void _toggleShufflePlayback() {
    final enablingShuffle =
        _mediaControlController.state.mode != PlaybackMode.shuffle;
    if (enablingShuffle) {
      _shuffleCurrentPlaybackQueue();
    }
    _mediaControlController.onToggleShuffle();
  }

  void _shuffleCurrentPlaybackQueue() {
    final snapshot = ref.read(libraryViewDataProvider).valueOrNull;
    if (snapshot == null) {
      return;
    }
    final playbackSongIds = _playbackSongIds(snapshot);
    if (playbackSongIds.isEmpty) {
      return;
    }
    final nextSongIds = shufflePlaybackQueueForCurrentTrack(
      playbackSongIds,
      _mediaControlController.state.track.id,
    );
    unawaited(
      ref.read(libraryRepositoryProvider).replaceNowPlaying(nextSongIds),
    );
    ref.invalidate(libraryViewDataProvider);
    final nextQueueIndex = currentPlaybackQueueIndex(
      nextSongIds,
      _mediaControlController.state.track.id,
    );
    _mediaControlController.setSelectedQueueIndex(
      nextQueueIndex > -1 ? nextQueueIndex : null,
    );
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
      _pendingAudioSeekSeconds = null;
      unawaited(_audioPlayer.stop());
      return;
    }

    final song = _resolvePlayerSong(
      state,
      ref.read(libraryViewDataProvider).valueOrNull,
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
      final duration = await _audioPlayer.setAudioSource(
        LocalAudioFileSource(song.path),
      );
      if (!mounted || loadSerial != _audioLoadSerial) {
        return;
      }
      _loadedAudioTrackId = song.id;
      _loadedAudioPath = song.path;
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
        _syncingAudioPlayer = true;
        _mediaControlController.setPlaybackLoadFailed();
        _syncingAudioPlayer = false;
      }
    }
  }

  Future<void> _applyAudioPlaybackState(MediaControlState state) async {
    final targetPosition = Duration(
      milliseconds: (state.progressSeconds * 1000).round(),
    );
    if (!state.isProgressSeeking &&
        (_audioPlayer.position - targetPosition).abs() >
            const Duration(milliseconds: 850)) {
      _pendingAudioSeekSeconds = state.progressSeconds;
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

    final positionSeconds = position.inMilliseconds / 1000;
    final pendingSeekSeconds = _pendingAudioSeekSeconds;
    if (shouldIgnoreAudioPositionForPendingSeek(
      positionSeconds: positionSeconds,
      pendingSeekSeconds: pendingSeekSeconds,
      toleranceSeconds: _pendingSeekToleranceSeconds,
    )) {
      return;
    }
    if (pendingSeekSeconds != null) {
      _pendingAudioSeekSeconds = null;
    }

    _syncingAudioPlayer = true;
    _mediaControlController.syncPlaybackProgress(
      positionSeconds,
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

  void _handleAudioPlaybackError(PlayerException error) {
    final progressSeconds = _audioPlayer.position.inMilliseconds / 1000;
    _pendingAudioSeekSeconds = null;
    _stopPlaybackStallTimer();
    unawaited(_audioPlayer.pause());
    _syncingAudioPlayer = true;
    _mediaControlController.setPlaybackRuntimeFailed(progressSeconds);
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
      _startPlaybackStallTimer();
    } else {
      _stopPlaybackStallTimer();
    }

    final backendLoading = _isAudioBackendLoading(state.processingState);
    _syncingAudioPlayer = true;
    if (backendLoading) {
      _mediaControlController.setPlaybackActive(state.playing);
      _mediaControlController.setTrackLoading(
        true,
        buffering: state.processingState == ProcessingState.buffering,
      );
    } else {
      _mediaControlController.setPlaybackActive(state.playing);
      _mediaControlController.setTrackLoading(false);
    }
    _syncingAudioPlayer = false;
    if (!state.playing && _loadedAudioTrackId != null && !backendLoading) {
      _settingsController.savePlaybackSettingsImmediate(
        PlaybackSettingsUpdate(
          musicProgress: _audioPlayer.position.inMilliseconds / 1000,
        ),
      );
    }
  }

  bool _isAudioBackendLoading(ProcessingState processingState) {
    return processingState == ProcessingState.loading ||
        processingState == ProcessingState.buffering;
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
        ref.invalidate(libraryViewDataProvider);
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
    if ((progressSeconds - _stalledProgressSeconds).abs() >
        _playbackProgressEpsilonSeconds) {
      _stalledProgressSeconds = progressSeconds;
      _stalledProgressStartedAt = null;
    }
  }

  void _checkPlaybackStall() {
    final state = _mediaControlController.state;
    final currentProgressSeconds = _audioPlayer.position.inMilliseconds / 1000;
    final startedAt = _stalledProgressStartedAt;
    if ((currentProgressSeconds - _stalledProgressSeconds).abs() >
        _playbackProgressEpsilonSeconds) {
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
      progressEpsilonSeconds: _playbackProgressEpsilonSeconds,
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
    _mediaControlController.setPlaybackNotice('notification.playbackStalled');
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
            final snapshot = ref.watch(libraryViewDataProvider).valueOrNull;
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
              onTogglePlayPause: _togglePlayPauseFromCurrentQueue,
              onPrevious: _playPreviousFromCurrentQueue,
              onNext: _playNextFromCurrentQueue,
              onSeek: _mediaControlController.onSeek,
              onBeginSeek: _mediaControlController.onBeginSeek,
              onEndSeek: _mediaControlController.onEndSeek,
              onToggleFavorite:
                  currentSong == null
                      ? _mediaControlController.onToggleFavorite
                      : () {
                        _togglePlayerFavorite(ref, currentSong);
                      },
              onQuickPlay: () {
                _quickPlayLibrary(ref);
              },
              onCycleRepeatMode: _mediaControlController.cycleRepeatMode,
              onToggleMute: _mediaControlController.onToggleMute,
              onVolumeChange: _mediaControlController.onVolumeChange,
              onOpenVoiceAssistant:
                  _supportsVoiceAssistant()
                      ? () {
                        _showVoiceAssistantDialog(snapshot, i18n);
                      }
                      : null,
              onWindowDragStart: _startWindowDrag,
              onWindowDragEnd: _stopWindowDrag,
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
    final i18n = context.smPlayerI18n;
    final snapshot = ref.read(libraryViewDataProvider).valueOrNull;
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
    ref.invalidate(libraryViewDataProvider);
    _mediaControlController.playTrack(
      mediaControlTrackForSong(firstSong, i18n),
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
    final snapshot = ref.read(libraryViewDataProvider).valueOrNull;
    final before = snapshot?.nowPlaying.songIds ?? const <int>[];
    final insertedIndex = before.length;
    ref.read(libraryRepositoryProvider).replaceNowPlaying([...before, song.id]);
    ref.invalidate(libraryViewDataProvider);
    _showUndo(
      context.smPlayerI18n.t('notification.songAddedTo', {
        'title': song.title,
        'target': context.smPlayerI18n.t('common.nowPlaying'),
      }),
      () {
        final current =
            ref.read(libraryViewDataProvider).valueOrNull?.nowPlaying.songIds ??
            before;
        ref
            .read(libraryRepositoryProvider)
            .replaceNowPlaying(
              removePlaybackQueueRange(current, insertedIndex, 1),
            );
        ref.invalidate(libraryViewDataProvider);
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
    ref.invalidate(libraryViewDataProvider);
    _showUndo(
      context.smPlayerI18n.t('notification.songAddedTo', {
        'title': song.title,
        'target': targetPlaylist.name,
      }),
      () {
        ref
            .read(libraryRepositoryProvider)
            .removeSongFromPlaylist(playlistId, song.id);
        ref.invalidate(libraryViewDataProvider);
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
    required LibraryViewData? snapshot,
  }) async {
    final currentSnapshot =
        snapshot ?? await ref.read(libraryViewDataProvider.future);
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
    ref.invalidate(libraryViewDataProvider);
    if (!mounted) {
      return;
    }
    _navigateTo('/playlists/${playlist.id}');
  }

  Future<void> _duplicatePlaylistFromNavigation({
    required WidgetRef ref,
    required LibraryViewData? snapshot,
    required LibraryPlaylist playlist,
  }) async {
    final currentSnapshot =
        snapshot ?? await ref.read(libraryViewDataProvider.future);
    if (currentSnapshot == null) {
      return;
    }
    await ref
        .read(libraryRepositoryProvider)
        .createPlaylist(
          getNextPlaylistName(playlist.name, currentSnapshot.playlists),
          playlist.songIds,
        );
    ref.invalidate(libraryViewDataProvider);
  }

  Future<void> _renamePlaylistFromNavigation({
    required BuildContext context,
    required WidgetRef ref,
    required SmPlayerI18n i18n,
    required LibraryViewData? snapshot,
    required LibraryPlaylist playlist,
  }) async {
    final currentSnapshot =
        snapshot ?? await ref.read(libraryViewDataProvider.future);
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
    ref.invalidate(libraryViewDataProvider);
  }

  Future<void> _deletePlaylistFromNavigation({
    required WidgetRef ref,
    required SmPlayerI18n i18n,
    required LibraryViewData? snapshot,
    required LibraryPlaylist playlist,
  }) async {
    final currentSnapshot =
        snapshot ?? await ref.read(libraryViewDataProvider.future);
    if (currentSnapshot == null) {
      return;
    }
    await ref.read(libraryRepositoryProvider).deletePlaylist(playlist.id);
    ref.invalidate(libraryViewDataProvider);
    _showUndo(
      i18n.t('notification.playlistRemoved', {'name': playlist.name}),
      () async {
        await ref.read(libraryRepositoryProvider).restorePlaylist(playlist);
        ref.invalidate(libraryViewDataProvider);
      },
    );
  }

  void _navigateTo(String target) {
    final restoredTarget = _routeMemory[target] ?? target;
    setState(() {
      _currentPath = restoredTarget;
    });
    _closeNavigationOverlay();
    widget.onNavigate?.call(restoredTarget);
    if (_pathFromLocation(restoredTarget) != '/now-playing/full') {
      unawaited(_desktopFeatureService.setWindowFullScreen(false));
    }
  }

  void _rememberRoute(String path) {
    final uri = Uri.tryParse(path);
    final normalizedPath = uri?.path ?? path;
    final section = _routeSection(normalizedPath);
    if (section == null || section == '/albums' || section == '/playlists') {
      return;
    }
    _routeMemory[section] = section == '/artists' ? path : normalizedPath;
  }

  void _recordNavigationLocation(String location) {
    if (_navigationHistory.isEmpty) {
      _navigationHistory.add(location);
      return;
    }

    if (_navigationHistory.last == location) {
      return;
    }

    if (_navigationHistory.length > 1 &&
        _navigationHistory[_navigationHistory.length - 2] == location) {
      _navigationHistory.removeLast();
      return;
    }

    _navigationHistory.add(location);
  }

  String _pathFromLocation(String location) {
    return Uri.parse(location).path;
  }

  String? _routeSection(String path) {
    if (path.startsWith('/artists')) {
      return '/artists';
    }
    if (path.startsWith('/local')) {
      return '/local';
    }
    if (path.startsWith('/playlists')) {
      return '/playlists';
    }
    if (path.startsWith('/albums')) {
      return '/albums';
    }
    return restorableRoutes.contains(path) ? path : null;
  }

  void _toggleNativeNowPlayingFullScreen() {
    final currentPath = widget.currentPath ?? _currentPath;
    final currentLocation = widget.currentLocation ?? currentPath;
    final nextFullScreen =
        !_isWindowFullScreen && currentPath != '/now-playing/full';
    unawaited(_desktopFeatureService.setWindowFullScreen(nextFullScreen));
    final exitTarget =
        currentPath == '/now-playing/full'
            ? nowPlayingFullReturnLocationFromLocation(currentLocation)
            : nowPlayingRoutePath;
    _navigateTo(
      nextFullScreen ? nowPlayingFullRouteFrom(currentLocation) : exitTarget,
    );
  }

  void _enterMiniMode() {
    final currentPath = widget.currentPath ?? _currentPath;
    final currentLocation = widget.currentLocation ?? currentPath;
    final exitTarget =
        currentPath == '/now-playing/full'
            ? nowPlayingFullReturnLocationFromLocation(currentLocation)
            : nowPlayingRoutePath;
    setState(() {
      _isMiniMode = true;
      if (currentPath == '/now-playing/full') {
        _currentPath = exitTarget;
      }
    });
    if (currentPath == '/now-playing/full') {
      widget.onNavigate?.call(exitTarget);
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

  void _startWindowDrag() {
    unawaited(_desktopFeatureService.startWindowDrag());
  }

  void _stopWindowDrag() {
    unawaited(_desktopFeatureService.stopWindowDrag());
  }

  void _goBack() {
    _closeNavigationOverlay();
    if (_navigationHistory.length > 1) {
      final targetLocation = _navigationHistory[_navigationHistory.length - 2];
      setState(() {
        _currentPath = _pathFromLocation(targetLocation);
      });
      widget.onNavigate?.call(targetLocation);
      return;
    }

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
        if (!_isMinimalNavigationOpen) {
          _searchText = '';
        }
      });
      return;
    }

    final nextIsPaneOpen = !_isNavigationPaneOpen;
    setState(() {
      _isNavigationPaneOpen = nextIsPaneOpen;
      if (!nextIsPaneOpen) {
        _searchText = '';
      }
    });
    _saveNavigationCollapsed(!nextIsPaneOpen);
  }

  void _closeNavigationOverlay({bool preserveSearchText = false}) {
    final navigationMode = _navigationMode;
    if (navigationMode == SmPlayerNavigationMode.minimal &&
        _isMinimalNavigationOpen) {
      setState(() {
        _isMinimalNavigationOpen = false;
        if (!preserveSearchText) {
          _searchText = '';
        }
      });
      return;
    }

    if (navigationMode == SmPlayerNavigationMode.overlay &&
        _isNavigationPaneOpen) {
      setState(() {
        _isNavigationPaneOpen = false;
        if (!preserveSearchText) {
          _searchText = '';
        }
      });
      _saveNavigationCollapsed(true);
    }
  }

  Future<void> _restoreNavigationPaneState() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isNavigationPaneOpen = !_globalNavigationCollapsed;
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
    _playbackRuntimeSettingsRestored = true;
    _scheduleRestorePlaybackTrack(
      ref.read(libraryViewDataProvider).valueOrNull,
    );
    unawaited(_checkReleaseNotesVersion());
  }

  void _scheduleRestorePlaybackTrack(LibraryViewData? snapshot) {
    if (_playbackTrackRestored ||
        _playbackTrackRestoreScheduled ||
        !_playbackRuntimeSettingsRestored ||
        snapshot == null) {
      return;
    }
    _playbackTrackRestoreScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _playbackTrackRestoreScheduled = false;
      if (!mounted || _playbackTrackRestored) {
        return;
      }
      final latestSnapshot = ref.read(libraryViewDataProvider).valueOrNull;
      if (latestSnapshot == null) {
        return;
      }
      _restorePlaybackTrackFromSnapshot(latestSnapshot);
    });
  }

  void _restorePlaybackTrackFromSnapshot(LibraryViewData snapshot) {
    if (_playbackTrackRestored) {
      return;
    }
    if (_mediaControlController.state.track.id != null) {
      _playbackTrackRestored = true;
      return;
    }
    _playbackTrackRestored = true;
    final songIds = _playbackSongIds(snapshot);
    if (snapshot.songs.isEmpty || songIds.isEmpty) {
      return;
    }

    final settings = _settingsController.snapshot;
    final restoredIndex = settings.lastMusicIndex.clamp(0, songIds.length - 1);
    final songsById = {for (final song in snapshot.songs) song.id: song};
    final restoredSong = songsById[songIds[restoredIndex]];
    if (restoredSong == null) {
      return;
    }
    final progressSeconds =
        settings.saveMusicProgress ? settings.musicProgress : 0.0;
    _mediaControlController.playTrack(
      mediaControlTrackForSong(restoredSong, context.smPlayerI18n),
      durationSeconds: restoredSong.duration.toDouble(),
      queueIndex: restoredIndex,
      progressSeconds: progressSeconds,
      autoplay: settings.autoPlay,
    );
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

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return packageInfo.version;
    } catch (_) {
      return smPlayerAppVersion;
    }
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
    List<ArtistSplitResultItem> splits,
  ) async {
    setState(() {
      _startupArtistSplitApplying = true;
    });
    try {
      await ref.read(libraryRepositoryProvider).applyArtistSplits(splits);
      ref.invalidate(libraryViewDataProvider);
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
    required LibraryViewData? snapshot,
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
      durationSeconds: mediaControlState.durationSeconds,
      i18n: i18n,
    );
    _ensureDesktopLyricsLoaded(currentSong, mode: settings.playerLyricsSource);
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

  void _ensurePlayerArtworkResolved(LibrarySong? currentSong, WidgetRef ref) {
    if (currentSong == null) {
      return;
    }
    final artworkPath = currentSong.thumbnailPath;
    if (artworkPath.isNotEmpty && File(artworkPath).existsSync()) {
      return;
    }
    if (_playerArtworkResolveAttemptedSongIds.contains(currentSong.id) ||
        _playerArtworkResolvingSongIds.contains(currentSong.id)) {
      return;
    }

    _playerArtworkResolvingSongIds.add(currentSong.id);
    unawaited(
      ref
          .read(libraryRepositoryProvider)
          .getSongArtworkSnapshot(currentSong.id)
          .then((snapshot) {
            if (mounted && snapshot.artworkUrl.isNotEmpty) {
              ref.invalidate(libraryViewDataProvider);
            }
          })
          .whenComplete(() {
            _playerArtworkResolvingSongIds.remove(currentSong.id);
            _playerArtworkResolveAttemptedSongIds.add(currentSong.id);
          }),
    );
  }

  void _refreshPlayerArtworkAfterError(LibrarySong song, WidgetRef ref) {
    final key = '${song.id}:${song.thumbnailPath}';
    if (_playerArtworkErrorAttemptedKeys.contains(key) ||
        _playerArtworkErrorResolvingKeys.contains(key)) {
      return;
    }

    _playerArtworkErrorResolvingKeys.add(key);
    unawaited(
      ref
          .read(libraryRepositoryProvider)
          .getSongArtworkSnapshot(song.id)
          .then((snapshot) {
            if (mounted && snapshot.artworkUrl.isNotEmpty) {
              ref.invalidate(libraryViewDataProvider);
            }
          })
          .whenComplete(() {
            _playerArtworkErrorResolvingKeys.remove(key);
            _playerArtworkErrorAttemptedKeys.add(key);
          }),
    );
  }

  void _ensureDesktopLyricsLoaded(
    LibrarySong? currentSong, {
    required LyricsRequestMode mode,
  }) {
    if (currentSong == null) {
      _desktopLyricsSongId = null;
      _desktopLyricsLoadingSongId = null;
      _desktopLyricsMode = null;
      _desktopLyrics = null;
      return;
    }

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
        _togglePlayPauseFromCurrentQueue();
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
        _navigateTo('/settings#desktop-lyrics');
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
    final currentLocation = widget.currentLocation ?? currentPath;
    final nextPath =
        !fullScreen && currentPath == '/now-playing/full'
            ? nowPlayingFullReturnLocationFromLocation(currentLocation)
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
        _togglePlayPauseFromCurrentQueue();
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
    final snapshot = ref.read(libraryViewDataProvider).valueOrNull;
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

    final snapshot = await repository.getLibraryViewData();
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

    ref.invalidate(libraryViewDataProvider);
    _settingsController.savePlaybackSettingsImmediate(
      PlaybackSettingsUpdate(lastMusicIndex: insertIndex, musicProgress: 0),
    );

    final songsById = {for (final song in snapshot.songs) song.id: song};
    final song = songsById[openedSongIds.first]!;
    _mediaControlController.playTrack(
      mediaControlTrackForSong(song, context.smPlayerI18n),
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
    final snapshot = ref.read(libraryViewDataProvider).valueOrNull;
    final songsById = {
      for (final song in snapshot?.songs ?? const <LibrarySong>[])
        song.id: song,
    };
    final song = songsById[songId];
    if (song == null) {
      return;
    }

    ref.read(libraryRepositoryProvider).replaceNowPlaying([song.id]);
    ref.invalidate(libraryViewDataProvider);
    _mediaControlController.playTrack(
      mediaControlTrackForSong(song, context.smPlayerI18n),
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
    final snapshot = ref.read(libraryViewDataProvider).valueOrNull;
    return _resolvePlayerSong(_mediaControlController.state, snapshot);
  }

  void _updateDesktopLyricsOffset(LibrarySong song, int offsetMs) {
    unawaited(
      ref
          .read(libraryRepositoryProvider)
          .updateLyricsOffset(song.id, clampedDesktopLyricsOffset(offsetMs))
          .then((_) {
            ref.invalidate(libraryViewDataProvider);
            _lastDesktopLyricsSignature = null;
            if (mounted) {
              setState(() {});
            }
          }),
    );
  }

  void _saveNavigationCollapsed(bool collapsed) {
    _globalNavigationCollapsed = collapsed;
  }

  void _commitSearch(
    String value, [
    SearchHistoryType type = SearchHistoryType.sidebar,
  ]) {
    _commitSearchWithRepository(value, type);
  }

  void _commitSearchWithRepository(
    String value,
    SearchHistoryType type, {
    LibraryRepository? repository,
    VoidCallback? onRecentSearchRecorded,
  }) {
    final nextSearchText = value.trim();
    setState(() {
      _searchText = nextSearchText;
      if (nextSearchText.isNotEmpty) {
        _currentPath = '/search';
      }
    });
    if (nextSearchText.isNotEmpty) {
      final LibraryRepository searchRepository =
          repository ??
          widget.settingsRepository ??
          ref.read(libraryRepositoryProvider);
      unawaited(
        searchRepository.addRecentSearch(nextSearchText, type).then((entry) {
          if (onRecentSearchRecorded != null) {
            onRecentSearchRecorded();
          } else {
            _invalidateRecentSearchData();
          }
        }),
      );
      _closeNavigationOverlay(preserveSearchText: true);
      widget.onSearchCommit?.call(nextSearchText, type);
    }
  }

  void _clearSearch() {
    setState(() {
      _searchText = '';
    });
  }

  void _invalidateRecentSearchData() {
    invalidateRecentSearchData(ref);
  }

  Future<void> _showVoiceAssistantDialog(
    LibraryViewData? snapshot,
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

  String _getVoiceAssistantHint(LibraryViewData? snapshot, SmPlayerI18n i18n) {
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
    LibraryViewData? snapshot,
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
        _togglePlayPauseFromCurrentQueue();
      }
      return i18n.t('voiceAssistant.executed');
    }

    if (_matchesAny(command, const ['继续', '恢复']) ||
        _matchesAny(lower, const ['continue', 'resume'])) {
      if (!_mediaControlController.state.isPlaying) {
        _togglePlayPauseFromCurrentQueue();
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
      return _playMatchedSongs(snapshot, i18n, playArtist, _songArtistMatches);
    }

    final playAlbum = _stripVoicePrefix(command, const ['播放专辑', 'play album']);
    if (playAlbum != null && playAlbum.isNotEmpty) {
      return _playMatchedSongs(
        snapshot,
        i18n,
        playAlbum,
        (song, query) => _songAlbumMatches(song, query, i18n),
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
        if (!_mediaControlController.state.isPlaying &&
            !_togglePlayPauseFromCurrentQueue()) {
          _quickPlayLibrary(ref);
        }
        return i18n.t('voiceAssistant.executed');
      }
      return _playMatchedSongs(
        snapshot,
        i18n,
        playQuery,
        (song, query) => _songTextMatches(song, query, i18n),
      );
    }

    return i18n.t('voiceAssistant.notUnderstood');
  }

  String? _executeVoiceAssistantCommandResult(
    VoiceAssistantCommandResult result,
    LibraryViewData? snapshot,
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
        if (!_mediaControlController.state.isPlaying &&
            !_togglePlayPauseFromCurrentQueue()) {
          _quickPlayLibrary(ref);
        }
        return i18n.t('voiceAssistant.executed');
      case VoiceAssistantMatchType.pause:
        if (_mediaControlController.state.isPlaying) {
          _togglePlayPauseFromCurrentQueue();
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
          _songArtistMatches,
        );
      case VoiceAssistantMatchType.playAlbum:
        return _playMatchedSongs(
          snapshot,
          i18n,
          result.value!,
          (song, query) => _songAlbumMatches(song, query, i18n),
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
          (song, query) => _songTextMatches(song, query, i18n),
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
          (song, query) => _songTextMatches(song, query, i18n),
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
              _songAlbumMatches(song, query, i18n) &&
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
              _songAlbumMatches(song, albumQuery, i18n),
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
              (_songAlbumMatches(song, request.right, i18n) ||
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
    LibraryViewData? snapshot,
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
    LibraryViewData? snapshot,
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
    LibraryViewData? snapshot,
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
    ref.invalidate(libraryViewDataProvider);
    _mediaControlController.playTrack(
      mediaControlTrackForSong(firstSong, context.smPlayerI18n),
      durationSeconds: firstSong.duration.toDouble(),
      queueIndex: 0,
    );
  }

  bool _playNextFromCurrentQueue({bool automatic = false}) {
    return _playQueueDirection(forward: true, automatic: automatic);
  }

  bool _playPreviousFromCurrentQueue() {
    final snapshot = ref.read(libraryViewDataProvider).valueOrNull;
    if (snapshot == null) {
      return false;
    }
    final playbackSongIds = _playbackSongIds(snapshot);
    if (playbackSongIds.isEmpty) {
      return false;
    }
    final progressSeconds = _audioPlayer.position.inMilliseconds / 1000;
    if (shouldRestartCurrentTrackForPrevious(
      progressSeconds: progressSeconds,
      queueLength: playbackSongIds.length,
    )) {
      unawaited(_audioPlayer.seek(Duration.zero));
      _syncingAudioPlayer = true;
      _mediaControlController.syncPlaybackProgress(0);
      if (!_mediaControlController.state.isPlaying) {
        _mediaControlController.setTrackLoading(false);
      }
      _syncingAudioPlayer = false;
      _settingsController.savePlaybackSettingsImmediate(
        const PlaybackSettingsUpdate(musicProgress: 0),
      );
      return true;
    }
    return _playQueueDirection(forward: false, automatic: false);
  }

  bool _playQueueDirection({required bool forward, required bool automatic}) {
    final snapshot = ref.read(libraryViewDataProvider).valueOrNull;
    if (snapshot == null) {
      return false;
    }
    final playbackSongIds = _playbackSongIds(snapshot);
    if (playbackSongIds.isEmpty) {
      return false;
    }

    final currentIndex = _currentQueueIndex(snapshot, playbackSongIds);
    if (automatic &&
        forward &&
        _mediaControlController.state.mode == PlaybackMode.shuffle &&
        _settingsController.snapshot.shuffleAfterOneRound &&
        currentIndex >= playbackSongIds.length - 1) {
      return _shuffleAndPlayNextRound(snapshot, playbackSongIds);
    }

    final nextIndex = nextQueueIndexForPlayback(
      queueLength: playbackSongIds.length,
      currentIndex: currentIndex,
      mode: _mediaControlController.state.mode,
      forward: forward,
      automatic: automatic,
    );
    if (nextIndex == null) {
      return false;
    }

    _playQueueIndex(snapshot, playbackSongIds, nextIndex);
    return true;
  }

  bool _shuffleAndPlayNextRound(
    LibraryViewData snapshot,
    List<int> playbackSongIds,
  ) {
    final nextSongIds = shuffleNextRoundSongIds(
      playbackSongIds,
      _mediaControlController.state.track.id,
    );
    unawaited(
      ref.read(libraryRepositoryProvider).replaceNowPlaying(nextSongIds),
    );
    ref.invalidate(libraryViewDataProvider);
    return _playQueueSong(snapshot, nextSongIds.first, 0);
  }

  List<int> _playbackSongIds(LibraryViewData snapshot) {
    return normalizePlaybackQueueSongIds(
      snapshot.nowPlaying.songIds,
      snapshot.songs.map((song) => song.id),
    );
  }

  int _currentQueueIndex(
    LibraryViewData snapshot, [
    List<int>? playbackSongIds,
  ]) {
    return currentPlaybackQueueIndex(
      playbackSongIds ?? _playbackSongIds(snapshot),
      _mediaControlController.state.track.id,
      _mediaControlController.state.selectedQueueIndex ?? -1,
    );
  }

  void _playQueueIndex(
    LibraryViewData snapshot,
    List<int> playbackSongIds,
    int queueIndex,
  ) {
    final played = _playQueueSong(
      snapshot,
      playbackSongIds[queueIndex],
      queueIndex,
    );
    if (!played) {
      return;
    }
  }

  bool _playQueueSong(LibraryViewData snapshot, int songId, int queueIndex) {
    final songsById = {for (final song in snapshot.songs) song.id: song};
    final song = songsById[songId];
    if (song == null) {
      return false;
    }

    final startSeconds = resolveQueuePlaybackStartSeconds(
      currentTrackId: _mediaControlController.state.track.id,
      nextTrackId: song.id,
      currentProgressSeconds: _mediaControlController.state.progressSeconds,
    );
    _mediaControlController.playTrack(
      mediaControlTrackForSong(song, context.smPlayerI18n),
      durationSeconds: song.duration.toDouble(),
      queueIndex: queueIndex,
      progressSeconds: startSeconds,
    );
    _settingsController.savePlaybackSettingsImmediate(
      PlaybackSettingsUpdate(
        lastMusicIndex: queueIndex,
        musicProgress: startSeconds,
      ),
    );
    return true;
  }

  Future<void> _randomPlayPlaylist(WidgetRef ref, int playlistId) async {
    final i18n = context.smPlayerI18n;
    final snapshot = ref.read(libraryViewDataProvider).value!;
    final playlist = snapshot.playlists.firstWhere(
      (playlist) => playlist.id == playlistId,
    );
    final songIds = playlist.songIds.toList()..shuffle(Random());
    if (songIds.isEmpty) {
      return;
    }
    final songsById = {for (final song in snapshot.songs) song.id: song};
    final firstSong = songsById[songIds.first]!;
    final repository = ref.read(libraryRepositoryProvider);
    await repository.recordPlaylistPlayed(playlistId);
    await repository.replaceNowPlaying(songIds);
    _mediaControlController.playTrack(
      mediaControlTrackForSong(firstSong, i18n),
      durationSeconds: firstSong.duration.toDouble(),
      queueIndex: 0,
    );
    ref.invalidate(libraryViewDataProvider);
  }
}
