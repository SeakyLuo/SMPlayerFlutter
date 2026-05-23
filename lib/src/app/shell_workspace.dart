import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smplayer_flutter/src/app/shell_colors.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
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
    final nightMode = Theme.of(context).brightness == Brightness.dark;
    final i18n =
        ref.watch(smPlayerI18nProvider).valueOrNull ?? context.smPlayerI18n;
    final snapshot = ref.watch(musicLibrarySnapshotProvider).valueOrNull;
    final title = _workspaceTitle(
      path: currentPath,
      location: currentLocation,
      snapshot: snapshot,
      i18n: i18n,
    );
    final page = _WorkspacePageSurface(
      title: title,
      headerHeight: headerHeight,
      child: child ?? const SizedBox.shrink(),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color:
            nightMode
                ? ShellColors.nightWorkspaceSurface
                : ShellColors.workspaceSurface,
        boxShadow: [
          BoxShadow(
            color:
                nightMode
                    ? ShellColors.nightWorkspaceShadow
                    : ShellColors.workspaceShadow,
            offset: const Offset(0, 22),
            blurRadius: 56,
          ),
        ],
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: page,
        ),
      ),
    );
  }
}

class _WorkspacePageSurface extends StatelessWidget {
  const _WorkspacePageSurface({
    required this.title,
    required this.headerHeight,
    required this.child,
  });

  final String title;
  final double headerHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title.isNotEmpty)
          _WorkspaceHeader(title: title, height: headerHeight),
        Expanded(child: SizedBox.expand(child: child)),
      ],
    );
  }
}

class _WorkspaceHeader extends StatelessWidget {
  const _WorkspaceHeader({required this.title, required this.height});

  final String title;
  final double height;

  @override
  Widget build(BuildContext context) {
    final nightMode = Theme.of(context).brightness == Brightness.dark;
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
              color:
                  nightMode
                      ? ShellColors.nightHeaderText
                      : ShellColors.headerText,
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
  required MusicLibrarySnapshot? snapshot,
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

int _artistCount(MusicLibrarySnapshot snapshot) {
  final names = <String>{};
  for (final song in snapshot.songs) {
    names.addAll(artists_model.getSongArtists(song));
  }
  return names.length;
}

int _albumCount(MusicLibrarySnapshot snapshot) {
  return snapshot.songs
      .map((song) => song.album.trim())
      .where((album) => album.isNotEmpty)
      .toSet()
      .length;
}
