import 'dart:async';
import 'dart:math';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smplayer_flutter/src/app/app_route_model.dart';
import 'package:smplayer_flutter/src/app/main_navigation_view.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
import 'package:smplayer_flutter/src/library/data/library_repository.dart';
import 'package:smplayer_flutter/src/library/ui/library_page_actions.dart';
import 'package:smplayer_flutter/src/library/ui/music_dialog.dart';
import 'package:smplayer_flutter/src/platform/desktop_features.dart';
import 'package:smplayer_flutter/src/playback/media_control.dart';
import 'package:smplayer_flutter/src/playback/media_control_model.dart';
import 'package:smplayer_flutter/src/playback/media_control_provider.dart';
import 'package:smplayer_flutter/src/settings/settings_controller.dart';
import 'package:smplayer_flutter/src/settings/settings_model.dart';
import 'package:smplayer_flutter/src/settings/settings_page.dart'
    show ReleaseNotesDialog;

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
    this.appVersion,
  });

  final Widget? child;
  final String? currentPath;
  final bool canGoBack;
  final ValueChanged<String>? onNavigate;
  final VoidCallback? onGoBack;
  final MainNavigationSearchCommit? onSearchCommit;
  final DesktopFeatureService? desktopFeatureService;
  final String? appVersion;

  @override
  ConsumerState<SmPlayerShellPage> createState() => _SmPlayerShellPageState();
}

class _SmPlayerShellPageState extends ConsumerState<SmPlayerShellPage> {
  late final SettingsController _settingsController;
  late final MediaControlController _mediaControlController;
  late final DesktopFeatureService _desktopFeatureService;
  var _isNavigationPaneOpen = true;
  var _isMinimalNavigationOpen = false;
  var _isMiniMode = false;
  SmPlayerNavigationMode? _navigationMode;
  var _currentPath = '/songs';
  var _searchText = '';
  ({LibrarySong song, SongDialogMode mode})? _playerDialog;
  String? _lastDesktopTraySignature;
  String? _lastDesktopLyricsSignature;
  String? _releaseNotesDialogVersion;
  var _releaseNotesChecked = false;
  int? _lastNotifiedSongId;
  String? _lastPersistedPage;
  late final Future<SharedPreferences> _preferencesFuture;

  @override
  void initState() {
    super.initState();
    _settingsController = SettingsController();
    _preferencesFuture = SharedPreferences.getInstance();
    _mediaControlController = MediaControlController(
      null,
      _settingsController.savePlaybackSettingsImmediate,
    );
    _desktopFeatureService =
        widget.desktopFeatureService ?? createDesktopFeatureService();
    unawaited(_desktopFeatureService.initialize(_handleDesktopFeatureAction));
    _restorePlaybackRuntimeSettings();
    _restoreNavigationPaneState();
    _persistCurrentPage(widget.currentPath ?? _currentPath);
  }

  @override
  void didUpdateWidget(covariant SmPlayerShellPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final currentPath = widget.currentPath ?? _currentPath;
    final previousPath = oldWidget.currentPath ?? _currentPath;
    if (currentPath != previousPath) {
      _persistCurrentPage(currentPath);
    }
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
              child:
                  _isMiniMode
                      ? _buildMiniModeHost()
                      : Stack(
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
                                      playlists:
                                          snapshot?.playlists ?? const [],
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
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
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
                                                .watch(
                                                  musicLibrarySnapshotProvider,
                                                )
                                                .valueOrNull;
                                        final currentSong = _resolvePlayerSong(
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
                                          mediaControlState: mediaControlState,
                                          currentSong: currentSong,
                                        );
                                        return MediaControl(
                                          track: mediaControlState.track,
                                          currentSong: currentSong,
                                          playlists:
                                              snapshot?.playlists ?? const [],
                                          disabled: mediaControlState.disabled,
                                          isPlaying:
                                              mediaControlState.isPlaying,
                                          volume: mediaControlState.volume,
                                          isMuted: mediaControlState.isMuted,
                                          mode: mediaControlState.mode,
                                          progressSeconds:
                                              mediaControlState.progressSeconds,
                                          durationSeconds:
                                              mediaControlState.durationSeconds,
                                          onTogglePlayPause:
                                              _mediaControlController
                                                  .onTogglePlayPause,
                                          onPrevious:
                                              _mediaControlController
                                                  .onPrevious,
                                          onNext:
                                              _mediaControlController.onNext,
                                          onSeek:
                                              _mediaControlController.onSeek,
                                          onBeginSeek:
                                              _mediaControlController
                                                  .onBeginSeek,
                                          onEndSeek:
                                              _mediaControlController.onEndSeek,
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
                                            _navigateTo('/now-playing/full');
                                          },
                                          onEnterMiniMode: _enterMiniMode,
                                          onOpenVoiceAssistant: () {
                                            _showVoiceAssistantDialog(
                                              snapshot,
                                              i18n,
                                            );
                                          },
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
                                                          context.smPlayerI18n,
                                                      playlists:
                                                          snapshot?.playlists ??
                                                          const [],
                                                      defaultName:
                                                          currentSong.title,
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
                                    currentSong == null) {
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
                                      i18n: context.smPlayerI18n,
                                      progressSeconds: state.progressSeconds,
                                      isPlaying: state.isPlaying,
                                      onPrevious:
                                          _mediaControlController.onPrevious,
                                      onNext: _mediaControlController.onNext,
                                      onTogglePlayPause:
                                          _mediaControlController
                                              .onTogglePlayPause,
                                      onSeekOffset: (deltaMs) {
                                        _updateDesktopLyricsOffset(
                                          currentSong,
                                          currentSong.lyricsOffsetMs + deltaMs,
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
                          if (_releaseNotesDialogVersion
                              case final String version)
                            ReleaseNotesDialog(
                              version: version,
                              onClose: () {
                                unawaited(_closeReleaseNotes(version));
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
              onExit: _exitMiniMode,
              onTogglePlayPause: _mediaControlController.onTogglePlayPause,
              onPrevious: _mediaControlController.onPrevious,
              onNext: _mediaControlController.onNext,
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
              onVolumeChange: _mediaControlController.onVolumeChange,
            );
          },
        );
      },
    );
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
    final preferences = await _preferencesFuture;
    await preferences.setString(SmPlayerSettingsStorageKeys.lastPage, path);
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

  Future<void> _checkReleaseNotesVersion() async {
    if (_releaseNotesChecked) {
      return;
    }
    _releaseNotesChecked = true;
    final lastVersion = _settingsController.snapshot.lastReleaseNotesVersion;
    if (lastVersion.isEmpty) {
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
    }
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
          onExecute: (command) {
            return _executeVoiceAssistantCommand(command, snapshot, i18n);
          },
        );
      },
    );
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
      _mediaControlController.onNext();
      return i18n.t('voiceAssistant.executed');
    }

    if (_matchesAny(command, const ['上一首', '上首']) ||
        _matchesAny(lower, const ['previous', 'prev', 'previous song'])) {
      _mediaControlController.onPrevious();
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

int? _firstVoiceNumber(String value) {
  final match = RegExp(r'\d+').firstMatch(value);
  return match == null ? null : int.parse(match.group(0)!);
}

class _MiniModeSurface extends StatelessWidget {
  const _MiniModeSurface({
    required this.state,
    required this.i18n,
    required this.currentSong,
    required this.onExit,
    required this.onTogglePlayPause,
    required this.onPrevious,
    required this.onNext,
    required this.onSeek,
    required this.onToggleFavorite,
    required this.onQuickPlay,
    required this.onToggleRepeat,
    required this.onVolumeChange,
  });

  final MediaControlState state;
  final SmPlayerI18n i18n;
  final LibrarySong? currentSong;
  final VoidCallback onExit;
  final VoidCallback onTogglePlayPause;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<double> onSeek;
  final VoidCallback onToggleFavorite;
  final VoidCallback onQuickPlay;
  final VoidCallback onToggleRepeat;
  final ValueChanged<int> onVolumeChange;

  @override
  Widget build(BuildContext context) {
    final artworkPath = currentSong?.thumbnailPath ?? state.track.artworkUrl;
    final title =
        state.track.title.isEmpty
            ? i18n.t('app.chooseSong')
            : state.track.title;
    final artist =
        state.track.artist.isEmpty
            ? i18n.t('common.artistUnknown')
            : state.track.artist;
    final duration = state.durationSeconds <= 0 ? 1.0 : state.durationSeconds;
    final progress = state.progressSeconds.clamp(0, duration).toDouble();

    return DecoratedBox(
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
              color: Colors.black.withValues(alpha: 0.42),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: i18n.t('player.exitMiniMode'),
                        onPressed: onExit,
                        color: Colors.white,
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      Expanded(
                        child: Text(
                          i18n.t('player.miniMode'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
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
                  const SizedBox(height: 18),
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
                        onPressed: state.disabled ? null : onQuickPlay,
                        color: Colors.white,
                        disabledColor: Colors.white38,
                        icon: const Icon(Icons.casino_rounded),
                      ),
                      IconButton(
                        tooltip: i18n.t('player.playbackModeRepeat'),
                        onPressed: state.disabled ? null : onToggleRepeat,
                        color:
                            state.mode == PlaybackMode.repeat ||
                                    state.mode == PlaybackMode.repeatOne
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
                        onPressed: state.disabled ? null : onToggleFavorite,
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
                      SizedBox(
                        width: 96,
                        child: Slider(
                          min: 0,
                          max: 100,
                          value: state.volume.clamp(0, 100).toDouble(),
                          activeColor: Colors.white,
                          inactiveColor: Colors.white24,
                          onChanged:
                              state.disabled
                                  ? null
                                  : (value) {
                                    onVolumeChange(value.round());
                                  },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
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
  });

  final String tooltip;
  final IconData icon;
  final bool disabled;
  final VoidCallback onPressed;
  final bool primary;

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
      icon: Icon(icon, size: primary ? 34 : 30),
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
  const _VoiceAssistantDialog({required this.i18n, required this.onExecute});

  final SmPlayerI18n i18n;
  final String Function(String command) onExecute;

  @override
  State<_VoiceAssistantDialog> createState() => _VoiceAssistantDialogState();
}

class _VoiceAssistantDialogState extends State<_VoiceAssistantDialog> {
  late final TextEditingController _controller;
  String? _result;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
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
                TextField(
                  controller: _controller,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: i18n.t('voiceAssistant.command.play1'),
                    prefixIcon: const Icon(Icons.graphic_eq_rounded),
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

  void _execute() {
    final result = widget.onExecute(_controller.text);
    setState(() {
      _result = result;
    });
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

class _DesktopLyricsOverlay extends StatefulWidget {
  const _DesktopLyricsOverlay({
    required this.song,
    required this.settings,
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
    if (oldWidget.song.id != widget.song.id) {
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
                  _StrokeText(
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
    final lyrics = await const LibraryRepository().getSongLyrics(songId);
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
  });

  final String text;
  final Color textColor;
  final Color strokeColor;
  final double fontSize;
  final FontWeight fontWeight;
  final String? fontFamily;

  @override
  Widget build(BuildContext context) {
    final baseStyle = TextStyle(
      fontFamily: fontFamily,
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: 1.15,
    );
    return Stack(
      alignment: Alignment.center,
      children: [
        Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
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
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: baseStyle.copyWith(color: textColor),
        ),
      ],
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
