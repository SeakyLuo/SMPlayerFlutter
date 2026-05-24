import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smplayer_flutter/src/app/shell_colors.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
import 'package:smplayer_flutter/src/library/ui/headered_playlist_app_bar_portal.dart';
import 'package:smplayer_flutter/src/library/ui/artists_page_model.dart'
    as artists_model;

class SmPlayerWorkspace extends ConsumerWidget {
  const SmPlayerWorkspace({
    super.key,
    required this.currentPath,
    required this.currentLocation,
    required this.headerHeight,
    this.child,
  });

  final String currentPath;
  final String currentLocation;
  final double headerHeight;
  final Widget? child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shellColors = ShellThemeColors.of(context);
    final i18n =
        ref.watch(smPlayerI18nProvider).valueOrNull ?? context.smPlayerI18n;
    final snapshot = ref.watch(libraryViewDataProvider).valueOrNull;
    final title = _workspaceTitle(
      path: currentPath,
      location: currentLocation,
      snapshot: snapshot,
      i18n: i18n,
    );
    final headeredPlaylistAppBar = ref.watch(
      headeredPlaylistAppBarPortalProvider,
    );
    final routeSurface = shellColors.workspaceSolidSurface;
    final page = _WorkspacePageSurface(
      title: title,
      headerHeight: headerHeight,
      routeSurface: routeSurface,
      headeredPlaylistAppBar: headeredPlaylistAppBar,
      child: KeyedSubtree(
        key: ValueKey(currentLocation),
        child: child ?? const SizedBox.shrink(),
      ),
    );
    final workspace = DecoratedBox(
      decoration: _workspaceDecoration(
        shellColors: shellColors,
        routeSurface: routeSurface,
      ),
      child: ClipRect(child: page),
    );
    return RepaintBoundary(
      child: KeyedSubtree(
        key: ValueKey('SmPlayerWorkspace.$currentLocation'),
        child: workspace,
      ),
    );
  }
}

BoxDecoration _workspaceDecoration({
  required ShellThemeColors shellColors,
  required Color routeSurface,
}) {
  return BoxDecoration(
    color: routeSurface,
    boxShadow: [
      BoxShadow(
        color: shellColors.workspaceShadow,
        offset: const Offset(0, 22),
        blurRadius: 56,
      ),
    ],
  );
}

class _WorkspacePageSurface extends StatelessWidget {
  const _WorkspacePageSurface({
    required this.title,
    required this.headerHeight,
    required this.routeSurface,
    required this.headeredPlaylistAppBar,
    required this.child,
  });

  final String title;
  final double headerHeight;
  final Color routeSurface;
  final HeaderedPlaylistAppBarPortalEntry? headeredPlaylistAppBar;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: routeSurface,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (title.isNotEmpty)
                _WorkspaceHeader(title: title, height: headerHeight),
              Expanded(child: SizedBox.expand(child: child)),
            ],
          ),
          if (headeredPlaylistAppBar != null)
            _HeaderedPlaylistAppBarPortal(entry: headeredPlaylistAppBar!),
        ],
      ),
    );
  }
}

class _HeaderedPlaylistAppBarPortal extends StatelessWidget {
  const _HeaderedPlaylistAppBarPortal({required this.entry});

  final HeaderedPlaylistAppBarPortalEntry entry;

  @override
  Widget build(BuildContext context) {
    final shellColors = ShellThemeColors.of(context);
    return Positioned(
      key: const ValueKey('HeaderedPlaylist.AppBarPortal'),
      top: 8,
      left: 16,
      right: 8,
      height: 44,
      child: Row(
        children: [
          Expanded(
            child: Text(
              entry.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: shellColors.headerText,
                fontSize: 18,
                height: 1.1,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: entry.commandBar,
          ),
        ],
      ),
    );
  }
}

class _WorkspaceHeader extends StatelessWidget {
  const _WorkspaceHeader({required this.title, required this.height});

  final String title;
  final double height;

  @override
  Widget build(BuildContext context) {
    final shellColors = ShellThemeColors.of(context);
    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 142, 16),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: shellColors.headerText,
              fontSize: 40,
              height: 1.1,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

String _workspaceTitle({
  required String path,
  required String location,
  required LibraryViewData? snapshot,
  required SmPlayerI18n i18n,
}) {
  final uri = Uri.parse(location);
  final showCount = snapshot?.showCount ?? false;
  if (path.startsWith('/artists')) {
    if (uri.queryParameters.containsKey('artist')) {
      return '';
    }
    return showCount
        ? i18n.t('library.allArtistsWithCount', {
          'count': _artistCount(snapshot!),
        })
        : i18n.t('library.allArtists');
  }

  if (path.startsWith('/albums')) {
    if (uri.queryParameters.containsKey('album')) {
      return '';
    }
    return showCount
        ? i18n.t('library.allAlbumsWithCount', {
          'count': _albumCount(snapshot!),
        })
        : i18n.t('library.allAlbums');
  }

  if (path.startsWith('/now-playing')) {
    return showCount
        ? i18n.t('nowPlaying.titleWithCount', {
          'count': snapshot!.nowPlaying.songIds.length,
        })
        : i18n.t('common.nowPlaying');
  }

  if (path.startsWith('/hidden-folders')) {
    return i18n.t('local.hiddenFolders');
  }

  if (path.startsWith('/recent')) {
    if (snapshot != null && _hasRecentContent(snapshot)) {
      return '';
    }
    return i18n.t('common.recent');
  }

  if (path.startsWith('/local')) {
    return i18n.t('common.local');
  }

  if (path.startsWith('/playlists')) {
    if (path.startsWith('/playlists/')) {
      return '';
    }
    return showCount
        ? i18n.t('search.playlistsWithCount', {
          'count':
              snapshot!.playlists
                  .where((playlist) => !playlist.isBuiltIn)
                  .length,
        })
        : i18n.t('common.playlists');
  }

  if (path.startsWith('/favorites')) {
    return '';
  }

  if (path.startsWith('/search')) {
    final query = (uri.queryParameters['query'] ?? '').trim();
    final folder = uri.queryParameters['folder'] ?? '';
    if (query.isNotEmpty && folder.isNotEmpty) {
      return i18n.t('search.directoryResultOf', {
        'query': query,
        'folder': folder.split('/').last,
      });
    }
    return query.isNotEmpty
        ? i18n.t('search.resultOf', {'query': query})
        : i18n.t('search.resultTitle');
  }

  if (path.startsWith('/settings')) {
    return i18n.t('common.settings');
  }

  return showCount
      ? i18n.t('library.allSongsWithCount', {'count': snapshot!.songs.length})
      : i18n.t('library.allSongs');
}

bool _hasRecentContent(LibraryViewData snapshot) {
  return snapshot.songs.isNotEmpty ||
      snapshot.recentSongs.isNotEmpty ||
      snapshot.recentPlaylists.isNotEmpty ||
      snapshot.recentAlbums.isNotEmpty ||
      snapshot.recentArtists.isNotEmpty ||
      snapshot.recentSearches.isNotEmpty;
}

int _artistCount(LibraryViewData snapshot) {
  final names = <String>{};
  for (final song in snapshot.songs) {
    names.addAll(artists_model.getSongArtists(song));
  }
  return names.length;
}

int _albumCount(LibraryViewData snapshot) {
  return snapshot.songs
      .map((song) => song.album.trim())
      .where((album) => album.isNotEmpty)
      .toSet()
      .length;
}
