import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smplayer_flutter/src/app/main_navigation_view.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
import 'package:smplayer_flutter/src/playback/media_control.dart';
import 'package:smplayer_flutter/src/playback/media_control_model.dart';
import 'package:smplayer_flutter/src/playback/media_control_provider.dart';
import 'package:smplayer_flutter/src/settings/settings_controller.dart';

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

class SmPlayerShellPage extends StatefulWidget {
  const SmPlayerShellPage({
    super.key,
    this.child,
    this.currentPath,
    this.canGoBack = false,
    this.onNavigate,
    this.onGoBack,
    this.onSearchCommit,
  });

  final Widget? child;
  final String? currentPath;
  final bool canGoBack;
  final ValueChanged<String>? onNavigate;
  final VoidCallback? onGoBack;
  final ValueChanged<String>? onSearchCommit;

  @override
  State<SmPlayerShellPage> createState() => _SmPlayerShellPageState();
}

class _SmPlayerShellPageState extends State<SmPlayerShellPage> {
  late final SettingsController _settingsController;
  late final MediaControlController _mediaControlController;
  var _isNavigationPaneOpen = true;
  var _isMinimalNavigationOpen = false;
  SmPlayerNavigationMode? _navigationMode;
  var _currentPath = '/songs';
  var _searchText = '';

  @override
  void initState() {
    super.initState();
    _settingsController = SettingsController();
    _mediaControlController = MediaControlController(
      null,
      _settingsController.savePlaybackSettingsImmediate,
    );
    _restorePlaybackRuntimeSettings();
    _restoreNavigationPaneState();
  }

  @override
  void dispose() {
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
              child: Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    left: isNowPlayingFullRoute ? 0 : shellSidebarWidth,
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
                                    .watch(musicLibrarySnapshotProvider)
                                    .valueOrNull;
                            final i18n =
                                ref.watch(smPlayerI18nProvider).value ??
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
                              playlists: snapshot?.playlists ?? const [],
                              recentSearches:
                                  snapshot?.recentSearches ?? const [],
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
                                ref.invalidate(musicLibrarySnapshotProvider);
                              },
                              onRecentSearchesClear: () {
                                ref
                                    .read(libraryRepositoryProvider)
                                    .clearRecentSearches();
                                ref.invalidate(musicLibrarySnapshotProvider);
                              },
                              onCreatePlaylist: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      i18n.t('playlists.createNew'),
                                    ),
                                  ),
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
                            return MediaControl(
                              track: mediaControlState.track,
                              disabled: mediaControlState.disabled,
                              isPlaying: mediaControlState.isPlaying,
                              volume: mediaControlState.volume,
                              isMuted: mediaControlState.isMuted,
                              mode: mediaControlState.mode,
                              progressSeconds:
                                  mediaControlState.progressSeconds,
                              durationSeconds:
                                  mediaControlState.durationSeconds,
                              onTogglePlayPause:
                                  _mediaControlController.onTogglePlayPause,
                              onPrevious: _mediaControlController.onPrevious,
                              onNext: _mediaControlController.onNext,
                              onSeek: _mediaControlController.onSeek,
                              onBeginSeek: _mediaControlController.onBeginSeek,
                              onEndSeek: _mediaControlController.onEndSeek,
                              onVolumeChange:
                                  _mediaControlController.onVolumeChange,
                              onToggleMute:
                                  _mediaControlController.onToggleMute,
                              onToggleShuffle:
                                  _mediaControlController.onToggleShuffle,
                              onToggleRepeat:
                                  _mediaControlController.onToggleRepeat,
                              onToggleRepeatOne:
                                  _mediaControlController.onToggleRepeatOne,
                              onToggleFavorite:
                                  _mediaControlController.onToggleFavorite,
                              onQuickPlay: () {},
                              onOpenNowPlaying: () {
                                _navigateTo('/now-playing');
                              },
                              onToggleWindowFullScreen: () {
                                _navigateTo('/now-playing/full');
                              },
                              onEnterMiniMode: () {},
                            );
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _navigateTo(String target) {
    setState(() {
      _currentPath = target;
    });
    _closeNavigationOverlay();
    widget.onNavigate?.call(target);
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
    final preferences = await SharedPreferences.getInstance();
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

  Future<void> _restorePlaybackRuntimeSettings() async {
    await _settingsController.refresh();
    if (!mounted) {
      return;
    }

    _mediaControlController.applyPlaybackRuntimeSettings(
      _settingsController.getPlaybackSettingsImmediate(),
    );
  }

  Future<void> _saveNavigationCollapsed(bool collapsed) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(
      SmPlayerShellStorageKeys.navigationCollapsed,
      collapsed,
    );
  }

  void _commitSearch(String value) {
    final nextSearchText = value.trim();
    setState(() {
      _searchText = nextSearchText;
      if (nextSearchText.isNotEmpty) {
        _currentPath = '/search';
      }
    });
    if (nextSearchText.isNotEmpty) {
      _closeNavigationOverlay();
      widget.onSearchCommit?.call(nextSearchText);
    }
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

class _ShellColors {
  const _ShellColors._();

  static const bodyHighlight = Color(0xd1ffffff);
  static const bodyTop = Color(0xfff6f8fb);
  static const bodyBottom = Color(0xffedf2f7);
  static const workspaceSurface = Color(0xbdfafcff);
  static const workspaceShadow = Color(0x2e2f425c);
}
