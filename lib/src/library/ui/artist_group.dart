part of 'artists_page_model.dart';

class ArtistGroup {
  ArtistGroup({
    required this.name,
    required this.songs,
    required this.albumCount,
    required this.artworkSongId,
    this.artworkPath = '',
    String? sourceName,
    int? songCount,
  }) : songCount = songCount ?? songs.length,
       sourceName = sourceName ?? name;

  final String name;
  final String sourceName;
  final int songCount;
  final String artworkPath;
  ArtistGroup withSongs(List<LibrarySong> values) => ArtistGroup(
    name: name,
    sourceName: sourceName,
    songs: values,
    songCount: songCount,
    albumCount: albumCount,
    artworkSongId: artworkSongId,
    artworkPath: artworkPath,
  );

  final List<LibrarySong> songs;
  final int albumCount;
  final int artworkSongId;
}
