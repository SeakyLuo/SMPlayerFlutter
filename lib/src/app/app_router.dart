import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:smplayer_flutter/src/app/app_route_model.dart';
import 'package:smplayer_flutter/src/app/loading_state.dart';
import 'package:smplayer_flutter/src/app/shell_page.dart';
import 'package:smplayer_flutter/src/app/undoable_notification.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
import 'package:smplayer_flutter/src/library/data/library_repository.dart';
import 'package:smplayer_flutter/src/library/ui/album_detail_page.dart';
import 'package:smplayer_flutter/src/library/ui/albums_page.dart';
import 'package:smplayer_flutter/src/library/ui/artists_page.dart';
import 'package:smplayer_flutter/src/library/ui/hidden_folders_page.dart';
import 'package:smplayer_flutter/src/library/ui/local_page.dart';
import 'package:smplayer_flutter/src/library/ui/missing_library_root_content.dart';
import 'package:smplayer_flutter/src/library/ui/music_library_page.dart';
import 'package:smplayer_flutter/src/library/ui/my_favorites_page.dart';
import 'package:smplayer_flutter/src/library/ui/playlists_page.dart';
import 'package:smplayer_flutter/src/library/ui/search_page.dart';
import 'package:smplayer_flutter/src/playback/now_playing_full_page.dart';
import 'package:smplayer_flutter/src/playback/now_playing_full_route.dart';
import 'package:smplayer_flutter/src/playback/now_playing_page.dart';
import 'package:smplayer_flutter/src/platform/desktop_feature_service.dart';
import 'package:smplayer_flutter/src/platform/external_open_model.dart';
import 'package:smplayer_flutter/src/recent/recent_page.dart';
import 'package:smplayer_flutter/src/settings/settings_page.dart';
import 'package:smplayer_flutter/src/settings/settings_controller.dart';
import 'package:smplayer_flutter/src/settings/settings_model.dart';
import 'package:url_launcher/url_launcher.dart';

final smPlayerRouter = createSmPlayerRouter();

GoRouter createSmPlayerRouter({
  String initialLocation = '/songs',
  SettingsController? settingsController,
  List<String> initialExternalFilePaths = const [],
  List<ExternalAppCommand> initialExternalCommands = const [],
  FutureOr<void> Function()? onDataImported,
}) {
  final rootNavigatorKey = _SmPlayerNavigatorKey('root');
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: resolveRestoredPage(initialLocation),
    routes: [
      GoRoute(path: '/', redirect: (_, _) => '/songs'),
      StatefulShellRoute.indexedStack(
        pageBuilder:
            (context, state, navigationShell) => _smPlayerShellPage(
              state: state,
              settingsController: settingsController,
              initialExternalFilePaths: initialExternalFilePaths,
              initialExternalCommands: initialExternalCommands,
              navigationShell: navigationShell,
            ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/songs',
                pageBuilder:
                    (context, state) => _smPlayerBranchPage(
                      state: state,
                      settingsController: settingsController,
                      child: MusicLibraryPage(
                        searchQuery: state.uri.queryParameters['search'] ?? '',
                      ),
                    ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/artists',
                pageBuilder:
                    (context, state) => _smPlayerBranchPage(
                      state: state,
                      settingsController: settingsController,
                      child: ArtistsPage(
                        searchQuery: state.uri.queryParameters['search'] ?? '',
                        targetArtistName: state.uri.queryParameters['artist'],
                      ),
                    ),
              ),
              GoRoute(
                path: '/artists/:artistName',
                redirect: (context, state) {
                  final artistName = state.pathParameters['artistName']!;
                  return '/artists?artist=${Uri.encodeQueryComponent(artistName)}';
                },
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/albums',
                pageBuilder:
                    (context, state) => _smPlayerBranchPage(
                      state: state,
                      settingsController: settingsController,
                      child:
                          state.uri.queryParameters['album'] == null
                              ? const AlbumsPage()
                              : AlbumDetailPage(
                                albumName: state.uri.queryParameters['album']!,
                              ),
                    ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/local',
                pageBuilder:
                    (context, state) => _smPlayerBranchPage(
                      state: state,
                      settingsController: settingsController,
                      child: LocalPage(
                        currentRelativePath:
                            state.uri.queryParameters['path'] ?? '',
                        searchQuery: state.uri.queryParameters['query'] ?? '',
                      ),
                    ),
              ),
              GoRoute(
                path: '/hidden-folders',
                pageBuilder:
                    (context, state) => _smPlayerBranchPage(
                      state: state,
                      settingsController: settingsController,
                      child: const HiddenFoldersPage(),
                    ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/recent',
                pageBuilder:
                    (context, state) => _smPlayerBranchPage(
                      state: state,
                      settingsController: settingsController,
                      child: const RecentPage(),
                    ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/now-playing',
                pageBuilder:
                    (context, state) => _smPlayerBranchPage(
                      state: state,
                      settingsController: settingsController,
                      child: NowPlayingPage(
                        searchQuery: state.uri.queryParameters['search'] ?? '',
                      ),
                    ),
              ),
              GoRoute(
                path: '/now-playing/full',
                pageBuilder:
                    (context, state) => _smPlayerBranchPage(
                      state: state,
                      settingsController: settingsController,
                      child: const NowPlayingFullPage(),
                    ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/favorites',
                pageBuilder:
                    (context, state) => _smPlayerBranchPage(
                      state: state,
                      settingsController: settingsController,
                      child: const MyFavoritesPage(),
                    ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/playlists',
                pageBuilder:
                    (context, state) => _smPlayerBranchPage(
                      state: state,
                      settingsController: settingsController,
                      child: const PlaylistsPage(),
                    ),
              ),
              GoRoute(
                path: '/playlists/:playlistId',
                pageBuilder:
                    (context, state) => _smPlayerBranchPage(
                      state: state,
                      settingsController: settingsController,
                      child: PlaylistsPage(
                        selectedPlaylistId: int.parse(
                          state.pathParameters['playlistId']!,
                        ),
                      ),
                    ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                pageBuilder:
                    (context, state) => _smPlayerBranchPage(
                      state: state,
                      settingsController: settingsController,
                      child: Consumer(
                        builder:
                            (context, ref, _) => SettingsPage(
                              controller: settingsController,
                              initialFragment: state.uri.fragment,
                              lyricsBatchSongCount:
                                  ref
                                      .watch(librarySongCountProvider)
                                      .valueOrNull,
                              librarySongs:
                                  ref
                                      .watch(libraryContentDataProvider)
                                      .valueOrNull
                                      ?.songs ??
                                  const [],
                              libraryRepository: ref.read(
                                libraryRepositoryProvider,
                              ),
                              onScanLibrary: (
                                rootPath, {
                                cancellation,
                                onProgress,
                              }) async {
                                final result = await ref
                                    .read(libraryRepositoryProvider)
                                    .scanAllMusicLibrary(
                                      rootPath,
                                      cancellation: cancellation,
                                      onProgress: onProgress,
                                    );
                                _invalidateLibraryData(ref);
                                return result;
                              },
                              onDataImported: () async {
                                if (onDataImported != null) {
                                  await onDataImported();
                                } else {
                                  await settingsController?.refresh();
                                  _invalidateLibraryData(ref);
                                }
                              },
                              onSendFeedbackEmail: () {
                                unawaited(
                                  _sendFeedbackEmail(
                                    context.smPlayerI18n.locale,
                                  ),
                                );
                              },
                              onOpenFeedbackInBrowser: () {
                                unawaited(
                                  launchUrl(Uri.parse(_feedbackIssueUrl)),
                                );
                              },
                              onRevealSystemLogs: () {
                                unawaited(_revealSystemLogs());
                              },
                            ),
                      ),
                    ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/search',
                pageBuilder:
                    (context, state) => _smPlayerBranchPage(
                      state: state,
                      settingsController: settingsController,
                      child: SearchPage(
                        query: state.uri.queryParameters['query'] ?? '',
                        activeType: state.uri.queryParameters['type'],
                        folderRelativePath: state.uri.queryParameters['folder'],
                      ),
                    ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

var _nextNavigatorKeyHash = 0x5f0000;

class _SmPlayerNavigatorKey extends GlobalKey<NavigatorState> {
  _SmPlayerNavigatorKey(this._label)
    : _hashCode = _nextNavigatorKeyHash++,
      super.constructor();

  final String _label;
  final int _hashCode;

  @override
  bool operator ==(Object other) {
    return identical(this, other);
  }

  @override
  int get hashCode => _hashCode;

  @override
  String toString() {
    return '[SmPlayerNavigatorKey $_label#$_hashCode]';
  }
}

const _shellRoutePageKey = ValueKey('SmPlayerShell.RoutePage');

Page<void> _smPlayerShellPage({
  required GoRouterState state,
  required SettingsController? settingsController,
  required List<String> initialExternalFilePaths,
  required List<ExternalAppCommand> initialExternalCommands,
  required StatefulNavigationShell navigationShell,
}) {
  return NoTransitionPage<void>(
    key: _shellRoutePageKey,
    child: _SmPlayerRouteShell(
      state: state,
      settingsController: settingsController,
      initialExternalFilePaths: initialExternalFilePaths,
      initialExternalCommands: initialExternalCommands,
      navigationShell: navigationShell,
    ),
  );
}

Page<void> _smPlayerBranchPage({
  required GoRouterState state,
  required SettingsController? settingsController,
  required Widget child,
}) {
  return NoTransitionPage<void>(
    key: state.pageKey,
    child: _LibraryRootGate(
      path: state.uri.path,
      settingsController: settingsController,
      child: child,
    ),
  );
}

class _SmPlayerRouteShell extends ConsumerWidget {
  const _SmPlayerRouteShell({
    required this.state,
    required this.settingsController,
    required this.initialExternalFilePaths,
    required this.initialExternalCommands,
    required this.navigationShell,
  });

  final GoRouterState state;
  final SettingsController? settingsController;
  final List<String> initialExternalFilePaths;
  final List<ExternalAppCommand> initialExternalCommands;
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routeState = GoRouterState.of(context);
    final uri = routeState.uri;
    final path = uri.path;
    final isPlaylistDetailRoute = path.startsWith('/playlists/');
    final isAlbumDetailRoute =
        path == '/albums' && uri.queryParameters.containsKey('album');
    final isArtistDetailRoute =
        path == '/artists' && uri.queryParameters.containsKey('artist');
    final canGoBack =
        isPlaylistDetailRoute ||
        isAlbumDetailRoute ||
        isArtistDetailRoute ||
        path == '/now-playing/full';
    final repository = ref.read(libraryRepositoryProvider);

    return SmPlayerShellPage(
      currentPath: path,
      currentLocation: uri.toString(),
      canGoBack: canGoBack,
      settingsRepository: repository,
      onNavigate: (target) {
        if (_branchRootIndex(target) case final branchIndex?) {
          navigationShell.goBranch(branchIndex, initialLocation: false);
          return;
        }
        context.go(target);
      },
      onGoBack: () {
        if (isPlaylistDetailRoute) {
          context.go('/playlists');
          return;
        }

        if (isAlbumDetailRoute) {
          context.go('/albums');
          return;
        }

        if (isArtistDetailRoute) {
          context.go('/artists');
          return;
        }

        if (path == '/now-playing/full') {
          context.go(nowPlayingFullReturnLocation(context));
        }
      },
      onSearchCommit: (query, [type = SearchHistoryType.sidebar]) {
        context.go(_searchRouteFor(query, type));
      },
      initialExternalFilePaths: initialExternalFilePaths,
      initialExternalCommands: initialExternalCommands,
      initialDisplayMode:
          settingsController?.snapshot.lastDisplayMode ??
          smPlayerGlobalSettingsSnapshot.lastDisplayMode,
      child: navigationShell,
    );
  }
}

int? _branchRootIndex(String location) {
  final uri = Uri.tryParse(location);
  if (uri == null || uri.hasQuery || uri.hasFragment) {
    return null;
  }
  return switch (uri.path) {
    '/songs' => 0,
    '/artists' => 1,
    '/albums' => 2,
    '/local' => 3,
    '/recent' => 4,
    '/now-playing' => 5,
    '/favorites' => 6,
    '/playlists' => 7,
    '/settings' => 8,
    '/search' => 9,
    _ => null,
  };
}

const _feedbackIssueUrl = 'https://github.com/SeakyLuo/SMPlayerEletron/issues';
const _feedbackEmailAddress = 'luokiss9@qq.com';

const _feedbackEmailSubjects = {
  'zh-CN': '简音播放器反馈',
  'zh-Hant': '簡音播放器反饋',
  'en-US': 'Simple Melody Player Feedback',
};

Future<void> _sendFeedbackEmail(String locale) async {
  final subject =
      _feedbackEmailSubjects[locale] ??
      (locale.startsWith('zh')
          ? _feedbackEmailSubjects['zh-CN']!
          : _feedbackEmailSubjects['en-US']!);
  await launchUrl(
    Uri(
      scheme: 'mailto',
      path: _feedbackEmailAddress,
      queryParameters: {'subject': subject},
    ),
  );
}

Future<void> _revealSystemLogs() async {
  final logsDirectory = Directory(
    p.join(defaultSmPlayerUserDataPath(), 'Logs'),
  );
  await logsDirectory.create(recursive: true);
  await openFolderInShell(logsDirectory.path);
}

class _LibraryRootGate extends ConsumerStatefulWidget {
  const _LibraryRootGate({
    required this.path,
    required this.child,
    this.settingsController,
  });

  final String path;
  final Widget child;
  final SettingsController? settingsController;

  @override
  ConsumerState<_LibraryRootGate> createState() => _LibraryRootGateState();
}

class _LibraryRootGateState extends ConsumerState<_LibraryRootGate> {
  var _scanning = false;

  @override
  Widget build(BuildContext context) {
    if (!_isLibraryRootGatedRoute(widget.path)) {
      return widget.child;
    }

    final libraryValue = ref.watch(shellNavigationDataProvider);
    return libraryValue.when(
      data:
          (library) =>
              library.rootPath.isEmpty
                  ? _MissingLibraryRootPage(
                    loading: false,
                    buttonLoading: _scanning,
                    onPickLibraryRoot:
                        _scanning
                            ? null
                            : () {
                              unawaited(_pickLibraryRootAndScan());
                            },
                  )
                  : widget.child,
      loading: () => const _MissingLibraryRootPage(loading: true),
      error:
          (_, _) => _MissingLibraryRootPage(
            loading: false,
            buttonLoading: _scanning,
            onPickLibraryRoot:
                _scanning
                    ? null
                    : () {
                      unawaited(_pickLibraryRootAndScan());
                    },
          ),
    );
  }

  Future<void> _pickLibraryRootAndScan() async {
    final i18n = context.smPlayerI18n;
    setState(() {
      _scanning = true;
    });
    try {
      final rootPath =
          Platform.isMacOS
              ? await pickDirectoryFromDesktopShell(
                title: i18n.t('local.chooseMusicLibraryFolderDialogTitle'),
                buttonLabel: i18n.t(
                  'local.chooseMusicLibraryFolderDialogButton',
                ),
                locale: i18n.locale,
              )
              : await FilePicker.getDirectoryPath();
      if (rootPath == null || rootPath.isEmpty) {
        if (mounted) {
          showAppNotification(
            context: context,
            message: i18n.t('library.folderPickerUnavailable'),
          );
        }
        return;
      }

      await ref.read(libraryRepositoryProvider).scanAllMusicLibrary(rootPath);
      await widget.settingsController?.updateSettings(
        AppSettingsUpdate(rootPath: rootPath),
      );
      _invalidateLibraryData(ref);
    } finally {
      if (mounted) {
        setState(() {
          _scanning = false;
        });
      }
    }
  }
}

class _MissingLibraryRootPage extends StatelessWidget {
  const _MissingLibraryRootPage({
    required this.loading,
    this.buttonLoading = false,
    this.onPickLibraryRoot,
  });

  final bool loading;
  final bool buttonLoading;
  final VoidCallback? onPickLibraryRoot;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const SmPlayerLoadingState();
    }

    return MissingLibraryRootContent(
      buttonLoading: buttonLoading,
      onPickLibraryRoot: onPickLibraryRoot,
    );
  }
}

bool _isLibraryRootGatedRoute(String path) {
  return path == '/songs' ||
      path == '/artists' ||
      path == '/albums' ||
      path == '/local';
}

String _searchRouteFor(String query, SearchHistoryType type) {
  final encodedQuery = Uri.encodeQueryComponent(query);
  return switch (type) {
    SearchHistoryType.sidebar => '/search?query=$encodedQuery',
    SearchHistoryType.artists => '/artists?artist=$encodedQuery',
    SearchHistoryType.albums => '/albums?album=$encodedQuery',
    SearchHistoryType.songs => '/songs?search=$encodedQuery',
    SearchHistoryType.playlists => '/playlists?search=$encodedQuery',
    SearchHistoryType.folders => '/search?query=$encodedQuery&type=folders',
  };
}

void _invalidateLibraryData(WidgetRef ref) {
  ref.invalidate(librarySongCountProvider);
  ref.invalidate(recentPageDataProvider);
  ref.invalidate(shellNavigationDataProvider);
  ref.invalidate(recentSearchesProvider);
}
