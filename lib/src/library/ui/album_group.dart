part of 'artists_page_model.dart';

class AlbumGroup {
  const AlbumGroup({
    required this.name,
    required this.songs,
    required this.duration,
  });

  final String name;
  final List<LibrarySong> songs;
  final int duration;
}
