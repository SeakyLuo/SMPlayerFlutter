import 'library_models.dart';

ArtistSplitAnalysisResult analyzeArtistSplits(List<LibrarySong> songs) {
  final knownArtists =
      songs
          .expand((song) => song.artists.isEmpty ? [song.artist] : song.artists)
          .map(_normalizeArtistKey)
          .where((artist) => artist.isNotEmpty)
          .toSet();
  final directSplits = <ArtistSplitResultItem>[];
  final possibleSplits = <ArtistSplitResultItem>[];

  for (final song in songs) {
    final splitArtists = splitSmartArtistCandidate(song.artist);
    if (splitArtists.length < 2) {
      continue;
    }
    if (_sameArtists(song.artists, splitArtists)) {
      continue;
    }
    final item = ArtistSplitResultItem(
      songId: song.id,
      title: song.title,
      artist: song.artist,
      artists: splitArtists,
    );
    final allKnown = splitArtists.every(
      (artist) => knownArtists.contains(_normalizeArtistKey(artist)),
    );
    if (allKnown) {
      directSplits.add(item);
    } else {
      possibleSplits.add(item);
    }
  }

  return ArtistSplitAnalysisResult(
    directSplits: directSplits,
    possibleSplits: possibleSplits,
    mergeSuggestions: const [],
  );
}

List<String> splitSmartArtistCandidate(String artist) {
  return artist
      .split(_artistSeparatorPattern)
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toSet()
      .toList();
}

final _artistSeparatorPattern = RegExp(
  r'\s*(?:,|，|、|/|／|;|；|\+|&|\band\b|\bfeat\.?(?=\s|$)|\bft\.?(?=\s|$))\s*',
  caseSensitive: false,
);

String _normalizeArtistKey(String artist) {
  return artist.trim().toLowerCase();
}

bool _sameArtists(List<String> left, List<String> right) {
  if (left.length != right.length) {
    return false;
  }

  for (final (index, artist) in left.indexed) {
    if (_normalizeArtistKey(artist) != _normalizeArtistKey(right[index])) {
      return false;
    }
  }

  return true;
}
