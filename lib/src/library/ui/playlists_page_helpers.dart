part of 'playlists_page.dart';

Future<String?> _requestPlaylistName({
  required BuildContext context,
  required SmPlayerI18n i18n,
  required String title,
  required String defaultName,
  required String confirmText,
  required List<LibraryPlaylist> playlists,
  required String currentName,
}) {
  return showSmPlayerInputDialog(
    context: context,
    i18n: i18n,
    title: title,
    defaultValue: defaultName,
    placeholder: i18n.t('playlists.namePlaceholder'),
    confirmText: confirmText,
    validate: (name) {
      return validatePlaylistName(name, playlists, currentName, i18n);
    },
  );
}

bool _idsEqual(List<int> left, List<int> right) {
  return left.length == right.length &&
      left.indexed.every((entry) => entry.$2 == right[entry.$1]);
}

bool _idsContainSameItems(List<int> left, List<int> right) {
  if (left.length != right.length) {
    return false;
  }
  final rightIds = right.toSet();
  return left.every(rightIds.contains);
}

List<int> _addUniqueSongIds(List<int> currentSongIds, List<int> songIds) {
  final nextSongIds = currentSongIds.toList();
  for (final songId in songIds) {
    if (!nextSongIds.contains(songId)) {
      nextSongIds.add(songId);
    }
  }
  return nextSongIds;
}

LibraryPlaylist _copyPlaylistWithName(LibraryPlaylist playlist, String name) {
  return LibraryPlaylist(
    id: playlist.id,
    name: name,
    priority: playlist.priority,
    songCount: playlist.songCount,
    songIds: playlist.songIds,
    sortCriterion: playlist.sortCriterion,
    isBuiltIn: playlist.isBuiltIn,
  );
}

LibraryPlaylist _copyPlaylistWithSongIds(
  LibraryPlaylist playlist,
  List<int> songIds, {
  PlaylistSortCriterion? sortCriterion,
}) {
  return LibraryPlaylist(
    id: playlist.id,
    name: playlist.name,
    priority: playlist.priority,
    songCount: songIds.length,
    songIds: songIds,
    sortCriterion: sortCriterion ?? playlist.sortCriterion,
    isBuiltIn: playlist.isBuiltIn,
  );
}

NowPlayingSnapshot _copyNowPlayingWithSongIds(
  NowPlayingSnapshot snapshot,
  List<int> songIds,
) {
  return NowPlayingSnapshot(playlistId: snapshot.playlistId, songIds: songIds);
}

List<LibraryPlaylist> _insertCustomPlaylistFirst(
  List<LibraryPlaylist> playlists,
  LibraryPlaylist playlist,
) {
  final index = playlists.indexWhere((item) => !item.isBuiltIn);
  final nextPlaylists = playlists.toList();
  nextPlaylists.insert(index == -1 ? nextPlaylists.length : index, playlist);
  return nextPlaylists;
}

LibraryContentData _copySnapshotWithPlaylists(
  LibraryContentData snapshot,
  List<LibraryPlaylist> playlists, {
  required NowPlayingSnapshot nowPlaying,
}) {
  return LibraryContentData(
    songs: snapshot.songs,
    recentSongs: snapshot.recentSongs,
    recentPlaylists: snapshot.recentPlaylists,
    recentAlbums: snapshot.recentAlbums,
    recentArtists: snapshot.recentArtists,
    recentSearches: snapshot.recentSearches,
    playlists: playlists,
    folders: snapshot.folders,
    favoritePlaylistId: snapshot.favoritePlaylistId,
    nowPlaying: nowPlaying,
    hasLibrary: snapshot.hasLibrary,
    sortCriterion: snapshot.sortCriterion,
    albumsSort: snapshot.albumsSort,
    showCount: snapshot.showCount,
    hideMultiSelectCommandBarAfterOperation:
        snapshot.hideMultiSelectCommandBarAfterOperation,
    localViewMode: snapshot.localViewMode,
    rootPath: snapshot.rootPath,
    databasePath: snapshot.databasePath,
  );
}
