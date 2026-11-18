import '../../remote/music_share_models.dart';
import '../../remote/remote_directory_provider.dart';
import '../data/library_models.dart';

LibraryContentData remoteDirectorySnapshot(
  LibraryContentData source,
  RemoteDirectoryIndex directory,
  String device,
) {
  final root = '$remoteMusicScheme://$device';
  return LibraryContentData(
    songs: source.songs,
    totalSongCount: source.totalSongCount,
    totalDuration: source.totalDuration,
    songRows: source.songRows,
    folderSongRows: source.folderSongRows,
    folderSummaries: source.folderSummaries,
    songFolderPaths: source.songFolderPaths,
    hasLibrary: source.hasLibrary,
    sortCriterion: source.sortCriterion,
    albumsSort: source.albumsSort,
    databasePath: source.databasePath,
    recentSongs: source.recentSongs,
    recentPlaylists: source.recentPlaylists,
    recentAlbums: source.recentAlbums,
    recentArtists: source.recentArtists,
    recentSearches: source.recentSearches,
    playlists: source.playlists,
    folders: [
      for (final entry in directory.folders.indexed)
        LibraryFolder(
          id: directory.folderInfo[entry.$2]['id'] as int,
          path: entry.$2.isEmpty ? root : '$root/${entry.$2}',
          parentId: 0,
          criterion: directory.folderInfo[entry.$2]['criterion'] as int,
        ),
    ],
    favoritePlaylistId: source.favoritePlaylistId,
    nowPlaying: source.nowPlaying,
    showCount: source.showCount,
    hideMultiSelectCommandBarAfterOperation:
        source.hideMultiSelectCommandBarAfterOperation,
    localViewMode: source.localViewMode,
    rootPath: root,
  );
}

class RemoteDirectoryPageDataCache {
  (LibraryContentData, RemoteDirectoryIndex, String)? _key;
  late ({LibraryContentData snapshot, Map<int, String> songFolders}) _value;

  ({LibraryContentData snapshot, Map<int, String> songFolders}) read(
    LibraryContentData source,
    RemoteDirectoryIndex directory,
    String device,
  ) {
    final key = (source, directory, device);
    if (_key != key) {
      _value = (
        snapshot: remoteDirectorySnapshot(source, directory, device),
        songFolders: {
          for (final entry in source.songFolderPaths.entries)
            entry.key:
                entry.value == '$remoteMusicScheme://$device'
                    ? ''
                    : entry.value.substring(
                      '$remoteMusicScheme://$device/'.length,
                    ),
        },
      );
      _key = key;
    }
    return _value;
  }
}

LibraryContentData unavailableRemoteDirectorySnapshot(
  String device,
  String path, {
  String? rootPath,
}) {
  final root = rootPath ?? '$remoteMusicScheme://$device';
  final segments = path.isEmpty ? <String>[] : path.split('/');
  return LibraryContentData(
    songs: const [],
    hasLibrary: false,
    sortCriterion: MusicLibrarySortCriterion.values.first,
    albumsSort: AlbumSortCriterion.defaultSort,
    databasePath: '',
    rootPath: root,
    folders: [
      for (var depth = 0; depth <= segments.length; depth++)
        LibraryFolder(
          id: 0,
          path: depth == 0 ? root : '$root/${segments.take(depth).join('/')}',
          parentId: 0,
          criterion: 0,
        ),
    ],
  );
}
