part of 'library_models.dart';

class LibraryArtistSummary {
  const LibraryArtistSummary({
    required this.name,
    required this.songCount,
    this.playCount = 0,
    required this.albumCount,
    this.duration = 0,
    required this.artworkSongId,
    required this.artworkPath,
  });
  final String name;
  final int songCount;
  final int playCount;
  final int albumCount;
  final int duration;
  final int artworkSongId;
  final String artworkPath;
}

class LibraryAlbumSummary {
  const LibraryAlbumSummary({
    required this.name,
    required this.songCount,
    this.playCount = 0,
    required this.duration,
    required this.artists,
    required this.artworkSongId,
    required this.artworkPath,
  });
  final String name;
  final int songCount;
  final int playCount;
  final int duration;
  final List<String> artists;
  final int artworkSongId;
  final String artworkPath;
}

class LibraryFolderSummary {
  const LibraryFolderSummary({
    required this.path,
    required this.directCount,
    required this.songCount,
    required this.duration,
    required this.playCount,
    required this.artworkPaths,
    this.artworkSongIds = const [],
  });
  final String path;
  final int directCount;
  final int songCount;
  final int duration;
  final int playCount;
  final List<String> artworkPaths;
  final List<int> artworkSongIds;
}

class LibraryLyricsSearchPage {
  const LibraryLyricsSearchPage({
    required this.matches,
    required this.totalCount,
    this.songs = const [],
    this.songIds = const [],
  });
  final List<int> songIds;
  final List<LocalLyricsSearchMatch> matches;
  final int totalCount;
  final List<LibrarySong> songs;
}
