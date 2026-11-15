import '../../remote/music_share_models.dart';
import '../../remote/remote_directory_provider.dart';
import '../data/library_models.dart';

Map<int, String> remoteSongFolders(
  List<LibrarySong> songs,
  RemoteDirectoryIndex directory,
) => {
  for (final song in songs)
    song.id: directory.songFolders[Uri.parse(song.path).pathSegments.single]!,
};

LibraryContentData remoteDirectorySnapshot(
  LibraryContentData source,
  RemoteDirectoryIndex directory,
  String device,
) {
  final root = '$remoteMusicScheme://$device';
  return LibraryContentData(
    songs: source.songs,
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
      for (final path in directory.folders)
        LibraryFolder(
          id: 0,
          path: path.isEmpty ? root : '$root/$path',
          parentId: 0,
          criterion: 0,
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
        songFolders: remoteSongFolders(source.songs, directory),
      );
      _key = key;
    }
    return _value;
  }
}
