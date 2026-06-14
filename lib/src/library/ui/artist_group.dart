part of 'artists_page_model.dart';

class ArtistGroup {
  const ArtistGroup({
    required this.name,
    required this.songs,
    required this.albumCount,
    required this.artworkSongId,
  });

  final String name;
  final List<LibrarySong> songs;
  final int albumCount;
  final int artworkSongId;
}
