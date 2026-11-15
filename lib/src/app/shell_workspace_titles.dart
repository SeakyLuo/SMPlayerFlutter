part of 'shell_workspace.dart';

int _albumCount(LibraryContentData snapshot, SmPlayerI18n i18n) {
  return {
    for (final song in snapshot.songs)
      song.album.isEmpty ? i18n.t('common.albumUnknown') : song.album,
  }.length;
}

String _searchWorkspaceTitle(Uri uri, SmPlayerI18n i18n) {
  final query = uri.queryParameters['query']?.trim() ?? '';
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

String _workspaceTitle({
  required String path,
  required LibraryContentData? snapshot,
  required SmPlayerI18n i18n,
}) {
  if (path.startsWith('/artists')) {
    return '';
  }

  if (path.startsWith('/albums')) {
    return '';
  }

  if (path.startsWith('/now-playing')) {
    return '';
  }

  if (path.startsWith('/hidden-folders')) {
    return i18n.t('local.hiddenFolders');
  }

  if (path.startsWith('/recent')) {
    final hasRecentContent =
        snapshot != null &&
        (snapshot.songs.isNotEmpty ||
            snapshot.recentSongs.isNotEmpty ||
            snapshot.recentPlaylists.isNotEmpty ||
            snapshot.recentAlbums.isNotEmpty ||
            snapshot.recentArtists.isNotEmpty ||
            snapshot.recentSearches.isNotEmpty);
    return hasRecentContent ? '' : i18n.t('common.recent');
  }

  if (path.startsWith('/local')) {
    return snapshot != null && snapshot.rootPath.isEmpty
        ? i18n.t('common.local')
        : '';
  }

  if (path.startsWith('/playlists')) {
    return '';
  }

  if (path.startsWith('/favorites')) {
    return '';
  }

  if (path.startsWith('/search')) {
    return '';
  }

  if (path.startsWith('/settings')) {
    return i18n.t('common.settings');
  }

  return '';
}
