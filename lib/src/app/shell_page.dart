import 'dart:async';
import 'dart:math';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smplayer_flutter/src/app/main_navigation_view.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
import 'package:smplayer_flutter/src/library/ui/library_page_actions.dart';
import 'package:smplayer_flutter/src/library/ui/music_dialog.dart';
import 'package:smplayer_flutter/src/platform/desktop_features.dart';
import 'package:smplayer_flutter/src/playback/media_control.dart';
import 'package:smplayer_flutter/src/playback/media_control_model.dart';
import 'package:smplayer_flutter/src/playback/media_control_provider.dart';
import 'package:smplayer_flutter/src/settings/settings_controller.dart';
import 'package:smplayer_flutter/src/settings/settings_model.dart';

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
  });

  final Widget? child;
  final String? currentPath;
  final bool canGoBack;
  final ValueChanged<String>? onNavigate;
  final VoidCallback? onGoBack;
  final MainNavigationSearchCommit? onSearchCommit;
  final DesktopFeatureService? desktopFeatureService;

  @override
  ConsumerState<SmPlayerShellPage> createState() => _SmPlayerShellPageState();
}

class _SmPlayerShellPageState extends ConsumerState<SmPlayerShellPage> {
  late final SettingsController _settingsController;
  late final MediaControlController _mediaControlController;
  late final DesktopFeatureService _desktopFeatureService;
  var _isNavigationPaneOpen = true;
  var _isMinimalNavigationOpen = false;
  SmPlayerNavigationMode? _navigationMode;
  var _currentPath = '/songs';
  var _searchText = '';
  ({LibrarySong song, SongDialogMode mode})? _playerDialog;
  String? _lastDesktopTraySignature;
  String? _lastDesktopLyricsSignature;
  int? _lastNotifiedSongId;

  @override
  void initState() {
    super.initState();
    _settingsController = SettingsController();
    _mediaControlController = MediaControlController(
      null,
      _settingsController.savePlaybackSettingsImmediate,
    );
    _desktopFeatureService =
        widget.desktopFeatureService ?? createDesktopFeatureService();
    unawaited(_desktopFeatureService.initialize(_handleDesktopFeatureAction));
    _restorePlaybackRuntimeSettings();
    _restoreNavigationPaneState();
  }

  @override
  void dispose() {
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
                            return Consumer(
                              builder: (context, ref, _) {
                                final snapshot =
                                    ref
                                        .watch(musicLibrarySnapshotProvider)
                                        .valueOrNull;
                                final currentSong = _resolvePlayerSong(
                                  mediaControlState,
                                  snapshot,
                                );
                                _syncDesktopFeatures(
                                  i18n: context.smPlayerI18n,
                                  snapshot: snapshot,
                                  mediaControlState: mediaControlState,
                                  currentSong: currentSong,
                                );
                                return MediaControl(
                                  track: mediaControlState.track,
                                  currentSong: currentSong,
                                  playlists: snapshot?.playlists ?? const [],
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
                                  onPrevious:
                                      _mediaControlController.onPrevious,
                                  onNext: _mediaControlController.onNext,
                                  onSeek: _mediaControlController.onSeek,
                                  onBeginSeek:
                                      _mediaControlController.onBeginSeek,
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
                                    _navigateTo('/now-playing/full');
                                  },
                                  onEnterMiniMode: () {},
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
                                              i18n: context.smPlayerI18n,
                                              playlists:
                                                  snapshot?.playlists ??
                                                  const [],
                                              defaultName: currentSong.title,
                                              songIds: [currentSong.id],
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
                                              snapshot?.playlists ?? const [],
                                            );
                                          },
                                  onSetPreference:
                                      currentSong == null
                                          ? null
                                          : (level) {
                                            ref
                                                .read(libraryRepositoryProvider)
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
                                                currentSong.album.isEmpty
                                                    ? context.smPlayerI18n.t(
                                                      'common.albumUnknown',
                                                    )
                                                    : currentSong.album;
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
                                                mode: SongDialogMode.properties,
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
                                                mode: SongDialogMode.lyrics,
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
                                                mode: SongDialogMode.albumArt,
                                              );
                                            });
                                          },
                                  onSeeLocal:
                                      currentSong == null
                                          ? null
                                          : () {
                                            _revealPath(currentSong.path);
                                          },
                                );
                              },
                            );
                          },
                        ),
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
                      onPlay: _mediaControlController.onTogglePlayPause,
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
                ],
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

  void _quickPlayLibrary(WidgetRef ref) {
    final snapshot = ref.read(musicLibrarySnapshotProvider).valueOrNull;
    final songs = snapshot?.songs ?? const <LibrarySong>[];
    if (songs.isEmpty) {
      return;
    }

    final shuffled = songs.toList()..shuffle(Random());
    final songIds = shuffled.take(100).map((song) => song.id).toList();
    final firstSong = shuffled.first;
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

  void _showUndo(String message, VoidCallback action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(
          label: context.smPlayerI18n.t('common.undo'),
          onPressed: action,
        ),
      ),
    );
  }

  Future<void> _revealPath(String targetPath) async {
    if (Platform.isWindows) {
      await Process.start('explorer.exe', ['/select,$targetPath']);
      return;
    }
    if (Platform.isMacOS) {
      await Process.start('open', ['-R', targetPath]);
      return;
    }
    await Process.start('xdg-open', [File(targetPath).parent.path]);
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

  void _syncDesktopFeatures({
    required SmPlayerI18n i18n,
    required MusicLibrarySnapshot? snapshot,
    required MediaControlState mediaControlState,
    required LibrarySong? currentSong,
  }) {
    final settings = _settingsController.snapshot;
    final trayState = DesktopTrayState(
      appTitle: i18n.t('app.shell'),
      isPlaying: mediaControlState.isPlaying,
      isWindowVisible: true,
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
      isPlaying: mediaControlState.isPlaying,
      progressSeconds: mediaControlState.progressSeconds,
    );
    if (_lastDesktopLyricsSignature != lyricsState.signature) {
      _lastDesktopLyricsSignature = lyricsState.signature;
      unawaited(_desktopFeatureService.updateDesktopLyricsState(lyricsState));
    }

    _notifyTrackChanged(currentSong, settings, i18n);
  }

  void _notifyTrackChanged(
    LibrarySong? currentSong,
    SettingsSnapshot settings,
    SmPlayerI18n i18n,
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
      _desktopFeatureService.showTrackNotification(
        TrackNotificationPayload(
          title: currentSong.title,
          artist: desktopNotificationArtist(currentSong, i18n),
          album: desktopNotificationAlbum(currentSong, i18n),
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
        unawaited(_desktopFeatureService.toggleWindowVisibility());
      case DesktopFeatureCommand.playPause:
        _mediaControlController.onTogglePlayPause();
      case DesktopFeatureCommand.previous:
        _mediaControlController.onPrevious();
      case DesktopFeatureCommand.next:
        _mediaControlController.onNext();
      case DesktopFeatureCommand.stop:
        _mediaControlController.onStop();
      case DesktopFeatureCommand.quickPlay:
        _quickPlayLibrary(ref);
      case DesktopFeatureCommand.toggleDesktopLyrics:
        _toggleDesktopLyricsFromPlatform();
      case DesktopFeatureCommand.openSettings:
        _navigateTo('/settings');
      case DesktopFeatureCommand.quit:
        unawaited(_desktopFeatureService.quit());
      case DesktopFeatureCommand.playRecentSong:
        _playRecentSongFromPlatform(action.songId!);
    }
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
    final song = snapshot?.songs.firstWhere((item) => item.id == songId);
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
