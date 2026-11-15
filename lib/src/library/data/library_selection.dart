import '../../playback/quick_play_model.dart';
import '../../playback/random_play_selection.dart';
import '../../settings/settings_model.dart';
import 'library_models.dart';

enum LibrarySelectionKind {
  quick('quick'),
  library('library'),
  artist('artist'),
  album('album'),
  folder('folder'),
  recentAdded('recent-added'),
  recentPlayed('recent-played'),
  mostPlayed('most-played'),
  leastPlayed('least-played'),
  favorites('my-favorites'),
  playlist('playlist'),
  currentArtist('current-artist'),
  currentAlbum('current-album'),
  savedPlaylist('playlist-id'),
  selection('selection');

  const LibrarySelectionKind(this.wireName);
  final String wireName;
  static LibrarySelectionKind fromWire(String value) =>
      values.firstWhere((kind) => kind.wireName == value);
}

class LibrarySelectionRequest {
  const LibrarySelectionRequest(
    this.kind, {
    this.limit = 100,
    this.album = '',
    this.artists = const [],
    this.songIds = const [],
    this.playlistId,
    this.unknownAlbumName = '',
  });
  final LibrarySelectionKind kind;
  final int limit;
  final String album;
  final List<String> artists;
  final List<int> songIds;
  final int? playlistId;
  final String unknownAlbumName;
}

List<int> selectLibrarySongIds(
  LibrarySelectionRequest request,
  LibraryContentData data, {
  List<RecentLibrarySong> recent = const [],
  PreferenceSettingsSnapshot? preferences,
}) {
  final songs = data.songs;
  if (songs.isEmpty) return const [];
  final byId = {for (final song in songs) song.id: song};
  final lists =
      data.playlists
          .where(
            (list) => !list.isBuiltIn && list.songIds.any(byId.containsKey),
          )
          .toList();
  return switch (request.kind) {
    LibrarySelectionKind.quick => quickPlaySongIds(
      songs: songs,
      playlists: data.playlists,
      folders: data.folders,
      preferences: preferences!,
      randomLimit: request.limit,
    ),
    LibrarySelectionKind.library => randomLibrarySongIds(songs, request.limit),
    LibrarySelectionKind.artist => randomArtistSongIds(songs, request.limit),
    LibrarySelectionKind.album => randomAlbumSongIds(songs, request.limit),
    LibrarySelectionKind.folder => randomFolderSongIds(
      songs,
      data.folders,
      request.limit,
    ),
    LibrarySelectionKind.recentAdded => randomRecentAddedSongIds(
      songs,
      request.limit,
    ),
    LibrarySelectionKind.recentPlayed => shuffleSongIds(recent),
    LibrarySelectionKind.mostPlayed => randomMostPlayedSongIds(
      songs,
      request.limit,
    ),
    LibrarySelectionKind.leastPlayed => randomLeastPlayedSongIds(
      songs,
      request.limit,
    ),
    LibrarySelectionKind.favorites => randomLibrarySongIds(
      songs.where((song) => song.favorite).toList(),
      request.limit,
    ),
    LibrarySelectionKind.playlist => randomPlaylistSongIds(
      songs,
      lists,
      request.limit,
    ),
    LibrarySelectionKind.currentArtist => shuffleSongIds(
      songs
          .where((song) => song.artists.any(request.artists.contains))
          .toList(),
    ),
    LibrarySelectionKind.currentAlbum => shuffleSongIds(
      songs.where((song) => song.album == request.album).toList(),
    ),
    LibrarySelectionKind.savedPlaylist => shuffleSongIds(
      data.playlists
          .firstWhere((list) => list.id == request.playlistId)
          .songIds
          .where(byId.containsKey)
          .map((id) => byId[id]!)
          .toList(),
    ),
    LibrarySelectionKind.selection => shuffleSongIds(
      request.songIds.where(byId.containsKey).map((id) => byId[id]!).toList(),
    ),
  };
}
