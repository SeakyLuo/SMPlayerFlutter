import 'package:go_router/go_router.dart';
import 'package:smplayer_flutter/src/app/shell_page.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
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
import 'package:smplayer_flutter/src/recent/recent_page.dart';
import 'package:smplayer_flutter/src/settings/settings_page.dart';

final smPlayerRouter = createSmPlayerRouter();

GoRouter createSmPlayerRouter() {
  return GoRouter(
    initialLocation: '/songs',
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

          return SmPlayerShellPage(
            currentPath: path,
            canGoBack: canGoBack,
            child: child,
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
          GoRoute(path: '/settings', builder: (_, _) => const SettingsPage()),
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
