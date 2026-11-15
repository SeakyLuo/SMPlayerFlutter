part of 'artists_page_model.dart';

class AlbumGroup {
  const AlbumGroup({
    required this.name,
    required this.songs,
    required this.duration,
    this.sourceName,
    this.summarySongCount,
    this.artworkPath,
  });

  final String? sourceName;
  final int? summarySongCount;
  final String? artworkPath;
  int get songCount => summarySongCount ?? songs.length;
  final String name;
  final List<LibrarySong> songs;
  final int duration;
}
