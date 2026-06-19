final _artistMergeSplitPattern = RegExp(r'\s*(?:/|／|;|；|,|，|、|\|)\s*');
final _sharedArtistSplitPattern = RegExp(r'\s*(?:;|；|、|\|)\s*');

String normalizeTagText(String? value) {
  return value?.trim() ?? '';
}

List<String> normalizeArtistTagValues(
  List<String?> artistValues,
  String? artistValue,
) {
  final artist = _normalizeArtistDisplayText(normalizeTagText(artistValue));
  final artists =
      artistValues
          .map((value) => _normalizeArtistDisplayText(normalizeTagText(value)))
          .where((value) => value.isNotEmpty)
          .toList();

  if (artist.isNotEmpty && _isSlashArtistSplit(artist, artists)) {
    return [artist];
  }

  if (artist.isNotEmpty &&
      _isParentheticalAliasCoveredByArtists(artist, artists)) {
    return artists;
  }

  if (artist.isNotEmpty && _isArtistMergedFromArtists(artist, artists)) {
    return artists;
  }

  final expandedFromComposite = _explodeCompositeArtistsContainingArtist(
    artist,
    artists,
  );
  if (expandedFromComposite != null) {
    return expandedFromComposite;
  }

  return [...artists, artist];
}

List<String> normalizeArtists(List<String?> values) {
  final seen = <String>{};
  final artists = <String>[];

  for (final value in values) {
    for (final artist in (value ?? '')
        .split(_sharedArtistSplitPattern)
        .map((artist) => artist.trim())
        .where((artist) => artist.isNotEmpty)) {
      final key = artist.toLowerCase();
      if (seen.add(key)) {
        artists.add(artist);
      }
    }
  }

  return artists;
}

List<String>? _explodeCompositeArtistsContainingArtist(
  String artist,
  List<String> artists,
) {
  if (artist.isEmpty || artists.isEmpty) {
    return null;
  }

  final artistParts =
      artist
          .split(_artistMergeSplitPattern)
          .map((part) => part.trim())
          .where((part) => part.isNotEmpty)
          .toList();
  if (artistParts.length != 1) {
    return null;
  }

  final artistKey = artist.toLowerCase();
  if (artists.any((value) => value.toLowerCase() == artistKey)) {
    return null;
  }

  var mutated = false;
  final result = <String>[];
  final seen = <String>{};
  void pushUnique(String value) {
    final key = value.toLowerCase();
    if (seen.add(key)) {
      result.add(value);
    }
  }

  for (final value in artists) {
    final parts =
        value
            .split(_artistMergeSplitPattern)
            .map((part) => part.trim())
            .where((part) => part.isNotEmpty)
            .toList();
    if (parts.length > 1 &&
        parts.any((part) => part.toLowerCase() == artistKey)) {
      mutated = true;
      for (final part in parts) {
        pushUnique(part);
      }
    } else {
      pushUnique(value);
    }
  }

  if (!mutated) {
    return null;
  }

  pushUnique(artist);
  return result;
}

String _normalizeArtistDisplayText(String value) {
  final parts =
      value
          .split(RegExp(r'\s*(?:,|，)\s*'))
          .map((part) => part.trim())
          .where((part) => part.isNotEmpty)
          .toList();

  if (parts.length < 2) {
    return value;
  }

  for (final part in parts) {
    if (!part.contains('/')) {
      continue;
    }

    final slashParts =
        part
            .split('/')
            .map((item) => item.trim().toLowerCase())
            .where((item) => item.isNotEmpty)
            .toList();
    final slashPartSet = slashParts.toSet();
    final otherParts = parts.where((item) => item != part).toList();

    if (slashParts.length > 1 &&
        otherParts.isNotEmpty &&
        otherParts.every((item) => slashPartSet.contains(item.toLowerCase()))) {
      return part;
    }
  }

  return value;
}

bool _isSlashArtistSplit(String artist, List<String> artists) {
  if (!artist.contains('/') || artists.isEmpty) {
    return false;
  }

  final slashParts =
      artist
          .split('/')
          .map((part) => part.trim().toLowerCase())
          .where((part) => part.isNotEmpty)
          .toList();
  final artistSet = artists.map((value) => value.toLowerCase()).toSet();
  final artistKey = artist.toLowerCase();

  return slashParts.length > 1 &&
      artists.every(
        (value) => value == artist || slashParts.contains(value.toLowerCase()),
      ) &&
      slashParts.every(
        (part) => artistSet.contains(part) || artistSet.contains(artistKey),
      );
}

bool _isParentheticalAliasCoveredByArtists(
  String artist,
  List<String> artists,
) {
  if (artists.isEmpty) {
    return false;
  }

  final baseName = artist.replaceFirst(RegExp(r'\s*\([^)]*\)\s*$'), '').trim();
  if (baseName.isEmpty || baseName == artist) {
    return false;
  }

  return artists.any((value) => value.toLowerCase() == baseName.toLowerCase());
}

bool _isArtistMergedFromArtists(String artist, List<String> artists) {
  if (artists.isEmpty) {
    return false;
  }

  final parts =
      artist
          .split(_artistMergeSplitPattern)
          .map((part) => part.trim())
          .where((part) => part.isNotEmpty)
          .toList();
  if (parts.length < 2) {
    return false;
  }

  final artistKeys = artists.map((value) => value.toLowerCase()).toSet();
  return parts.every((part) => artistKeys.contains(part.toLowerCase()));
}
