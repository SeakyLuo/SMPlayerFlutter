import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:smplayer_flutter/src/app/app_route_model.dart';
import 'package:smplayer_flutter/src/app/shell_page.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
import 'package:smplayer_flutter/src/library/ui/album_detail_page.dart';
import 'package:smplayer_flutter/src/library/ui/albums_page.dart';
import 'package:smplayer_flutter/src/library/ui/artists_page.dart';
import 'package:smplayer_flutter/src/library/ui/hidden_folders_page.dart';
import 'package:smplayer_flutter/src/library/ui/local_page.dart';
import 'package:smplayer_flutter/src/library/ui/music_library_page.dart';
import 'package:smplayer_flutter/src/library/ui/my_favorites_page.dart';
import 'package:smplayer_flutter/src/library/ui/playlists_page.dart';
import 'package:smplayer_flutter/src/library/ui/search_page.dart';
import 'package:smplayer_flutter/src/playback/now_playing_full_page.dart';
import 'package:smplayer_flutter/src/playback/now_playing_page.dart';
import 'package:smplayer_flutter/src/platform/desktop_features.dart';
import 'package:smplayer_flutter/src/platform/external_open_model.dart';
import 'package:smplayer_flutter/src/recent/recent_page.dart';
import 'package:smplayer_flutter/src/settings/settings_page.dart';
import 'package:smplayer_flutter/src/settings/settings_controller.dart';
import 'package:url_launcher/url_launcher.dart';

final smPlayerRouter = createSmPlayerRouter();

GoRouter createSmPlayerRouter({
  String initialLocation = '/songs',
  SettingsController? settingsController,
  List<String> initialExternalFilePaths = const [],
  List<ExternalAppCommand> initialExternalCommands = const [],
}) {
  return GoRouter(
    initialLocation: resolveRestoredPage(initialLocation),
    routes: [
      GoRoute(path: '/', redirect: (_, _) => '/songs'),
      ShellRoute(
        builder: (context, state, child) {
          final path = state.uri.path;
          final isPlaylistDetailRoute = path.startsWith('/playlists/');
          final isAlbumDetailRoute =
              path == '/albums' &&
              state.uri.queryParameters.containsKey('album');
          final isArtistDetailRoute =
              path == '/artists' &&
              state.uri.queryParameters.containsKey('artist');
          final canGoBack =
              isPlaylistDetailRoute ||
              isAlbumDetailRoute ||
              isArtistDetailRoute ||
              path == '/now-playing/full';

          return Consumer(
            builder:
                (context, ref, _) => SmPlayerShellPage(
                  currentPath: path,
                  canGoBack: canGoBack,
                  settingsRepository: ref.read(libraryRepositoryProvider),
                  onNavigate: (target) {
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
                      context.go('/now-playing');
                    }
                  },
                  onSearchCommit: (query, [type = SearchHistoryType.sidebar]) {
                    context.go(_searchRouteFor(query, type));
                  },
                  initialExternalFilePaths: initialExternalFilePaths,
                  initialExternalCommands: initialExternalCommands,
                  child: child,
                ),
          );
        },
        routes: [
          GoRoute(
            path: '/songs',
            builder:
                (_, state) => MusicLibraryPage(
                  searchQuery: state.uri.queryParameters['search'] ?? '',
                ),
          ),
          GoRoute(
            path: '/artists',
            builder:
                (_, state) => ArtistsPage(
                  searchQuery: state.uri.queryParameters['search'] ?? '',
                  targetArtistName: state.uri.queryParameters['artist'],
                ),
          ),
          GoRoute(
            path: '/albums',
            builder:
                (_, state) =>
                    state.uri.queryParameters['album'] == null
                        ? const AlbumsPage()
                        : AlbumDetailPage(
                          albumName: state.uri.queryParameters['album']!,
                        ),
          ),
          GoRoute(
            path: '/local',
            builder:
                (_, state) => LocalPage(
                  currentRelativePath: state.uri.queryParameters['path'] ?? '',
                  searchQuery: state.uri.queryParameters['query'] ?? '',
                ),
          ),
          GoRoute(
            path: '/hidden-folders',
            builder: (_, _) => const HiddenFoldersPage(),
          ),
          GoRoute(path: '/recent', builder: (_, _) => const RecentPage()),
          GoRoute(
            path: '/now-playing',
            builder:
                (_, state) => NowPlayingPage(
                  searchQuery: state.uri.queryParameters['search'] ?? '',
                ),
          ),
          GoRoute(
            path: '/now-playing/full',
            builder: (_, _) => const NowPlayingFullPage(),
          ),
          GoRoute(
            path: '/favorites',
            builder: (_, _) => const MyFavoritesPage(),
          ),
          GoRoute(path: '/playlists', builder: (_, _) => const PlaylistsPage()),
          GoRoute(
            path: '/settings',
            builder:
                (context, _) => Consumer(
                  builder:
                      (context, ref, _) => SettingsPage(
                        controller: settingsController,
                        libraryRepository: ref.read(libraryRepositoryProvider),
                        onScanLibrary: (
                          rootPath, {
                          cancellation,
                          onProgress,
                        }) async {
                          await ref
                              .read(libraryRepositoryProvider)
                              .scanAllMusicLibrary(
                                rootPath,
                                cancellation: cancellation,
                                onProgress: onProgress,
                              );
                          ref.invalidate(musicLibrarySnapshotProvider);
                        },
                        onDataImported: () async {
                          await settingsController?.refresh();
                          ref.invalidate(musicLibrarySnapshotProvider);
                        },
                        onSendFeedbackEmail: () {
                          unawaited(
                            _sendFeedbackEmail(context.smPlayerI18n.locale),
                          );
                        },
                        onOpenFeedbackInBrowser: () {
                          unawaited(launchUrl(Uri.parse(_feedbackIssueUrl)));
                        },
                        onRevealSystemLogs: () {
                          unawaited(_revealSystemLogs());
                        },
                      ),
                ),
          ),
          GoRoute(
            path: '/search',
            builder:
                (_, state) => SearchPage(
                  query: state.uri.queryParameters['query'] ?? '',
                  activeType: state.uri.queryParameters['type'],
                  folderRelativePath: state.uri.queryParameters['folder'],
                ),
          ),
          GoRoute(
            path: '/playlists/:playlistId',
            builder:
                (_, state) => PlaylistsPage(
                  selectedPlaylistId: int.parse(
                    state.pathParameters['playlistId']!,
                  ),
                ),
          ),
        ],
      ),
    ],
  );
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
  final supportDirectory = await getApplicationSupportDirectory();
  final logsDirectory = Directory(p.join(supportDirectory.path, 'Logs'));
  await logsDirectory.create(recursive: true);
  await openFolderInShell(logsDirectory.path);
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
