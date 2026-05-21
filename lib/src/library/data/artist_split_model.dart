import 'library_models.dart';

ArtistSplitAnalysisResult analyzeArtistSplits(List<LibrarySong> songs) {
  final knownArtists =
      songs.expand(_sourceArtists).map(_normalizeArtistKey).where((artist) {
        return artist.isNotEmpty;
      }).toSet();
  final directSplits = <ArtistSplitResultItem>[];
  final possibleSplits = <ArtistSplitResultItem>[];
  final splitArtistsBySongId = <int, List<String>>{};

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
      splitArtistsBySongId[song.id] = splitArtists;
    } else {
      possibleSplits.add(item);
    }
  }

  return ArtistSplitAnalysisResult(
    directSplits: directSplits,
    possibleSplits: possibleSplits,
    mergeSuggestions: _analyzeArtistMergeSuggestions(
      songs,
      splitArtistsBySongId,
    ),
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

List<ArtistSplitResultItem> _analyzeArtistMergeSuggestions(
  List<LibrarySong> songs,
  Map<int, List<String>> splitArtistsBySongId,
) {
  final artistUsage = _artistUsage(songs);
  final suggestions = <ArtistSplitResultItem>[];
  final expandedCandidatesByArtistKey = <String, List<String>>{};

  for (final song in songs) {
    final sourceArtists =
        splitArtistsBySongId[song.id] ?? _sourceArtistsForMerge(song);
    final mergedArtists = _mergedArtists(
      sourceArtists,
      artistUsage,
      expandedCandidatesByArtistKey,
    );
    if (_sameArtists(_normalizeArtists(sourceArtists), mergedArtists)) {
      continue;
    }
    suggestions.add(
      ArtistSplitResultItem(
        songId: song.id,
        title: song.title,
        artist: song.artist,
        artists: mergedArtists,
      ),
    );
  }

  return suggestions;
}

Map<String, _ArtistUsage> _artistUsage(List<LibrarySong> songs) {
  final usage = <String, _ArtistUsage>{};
  for (final song in songs) {
    for (final artist in _sourceArtistsForMerge(song)) {
      _addArtistUsage(usage, artist);
    }
  }
  return usage;
}

void _addArtistUsage(Map<String, _ArtistUsage> usage, String artist) {
  for (final normalizedArtist in _normalizeArtists([
    _normalizeArtistMergeName(artist),
  ])) {
    final key = _normalizeArtistKey(normalizedArtist);
    final current = usage[key];
    usage[key] = _ArtistUsage(
      name:
          current != null && current.name.length >= normalizedArtist.length
              ? current.name
              : normalizedArtist,
      count: (current?.count ?? 0) + 1,
    );
  }
}

List<String> _mergedArtists(
  List<String> artists,
  Map<String, _ArtistUsage> artistUsage,
  Map<String, List<String>> expandedCandidatesByArtistKey,
) {
  final sourceArtists = _normalizeArtistMergeNames(artists);
  final artistGroups = <List<String>>[];

  for (final artist in sourceArtists) {
    List<String>? matchingGroup;
    for (final group in artistGroups) {
      if (group.any(
        (groupArtist) => _isContainedArtistPair(groupArtist, artist),
      )) {
        matchingGroup = group;
        break;
      }
    }
    if (matchingGroup != null) {
      matchingGroup.add(artist);
    } else {
      artistGroups.add([artist]);
    }
  }

  return _normalizeArtists(
    artistGroups.map((group) {
      return _pickPreferredArtistName(
        _expandArtistMergeCandidates(
          group,
          artistUsage,
          expandedCandidatesByArtistKey,
        ),
        artistUsage,
      );
    }).toList(),
  );
}

List<String> _expandArtistMergeCandidates(
  List<String> artists,
  Map<String, _ArtistUsage> artistUsage,
  Map<String, List<String>> expandedCandidatesByArtistKey,
) {
  final candidates = <String, String>{};
  for (final artist in artists) {
    final artistName = _normalizeArtistMergeName(artist);
    final artistKey = _normalizeArtistKey(artistName);
    final expandedCandidates =
        expandedCandidatesByArtistKey[artistKey] ??
        _expandSingleArtistMergeCandidates(artistName, artistUsage);
    expandedCandidatesByArtistKey[artistKey] = expandedCandidates;
    for (final candidate in expandedCandidates) {
      candidates[_normalizeArtistKey(candidate)] = candidate;
    }
  }
  return candidates.values.toList();
}

List<String> _expandSingleArtistMergeCandidates(
  String artistName,
  Map<String, _ArtistUsage> artistUsage,
) {
  return [
    artistName,
    ...artistUsage.values
        .map((usage) => usage.name)
        .where((name) => _isContainedArtistPair(artistName, name)),
  ];
}

String _pickPreferredArtistName(
  List<String> artists,
  Map<String, _ArtistUsage> artistUsage,
) {
  final sorted = artists.toList();
  sorted.sort((left, right) {
    final leftUsage = artistUsage[_normalizeArtistKey(left)];
    final rightUsage = artistUsage[_normalizeArtistKey(right)];
    final countDiff = (rightUsage?.count ?? 0) - (leftUsage?.count ?? 0);
    if (countDiff != 0) {
      return countDiff;
    }
    return right.length - left.length;
  });
  return sorted.first;
}

List<String> _sourceArtists(LibrarySong song) {
  return song.artists.isEmpty ? [song.artist] : song.artists;
}

List<String> _sourceArtistsForMerge(LibrarySong song) {
  if (song.artists.length > 1) {
    return song.artists;
  }
  final splitArtists = splitSmartArtistCandidate(song.artist);
  return splitArtists.length > 1
      ? splitArtists
      : (song.artist.isEmpty ? [] : [song.artist]);
}

List<String> _normalizeArtistMergeNames(List<String> artists) {
  return _normalizeArtists(artists.map(_normalizeArtistMergeName).toList());
}

String _normalizeArtistMergeName(String artist) {
  return artist
      .replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

List<String> _normalizeArtists(List<String> artists) {
  final result = <String>[];
  final seen = <String>{};
  for (final artist in artists.map((artist) => artist.trim())) {
    final key = _normalizeArtistKey(artist);
    if (artist.isEmpty || seen.contains(key)) {
      continue;
    }
    seen.add(key);
    result.add(artist);
  }
  return result;
}

bool _isContainedArtistPair(String left, String right) {
  final leftName = _artistContainmentText(left);
  final rightName = _artistContainmentText(right);
  return left.trim() != right.trim() &&
      leftName.isNotEmpty &&
      rightName.isNotEmpty &&
      (leftName == rightName ||
          _containsArtistName(leftName, rightName) ||
          _containsArtistName(rightName, leftName));
}

String _artistContainmentText(String artist) {
  final bracketPairs = {
    '(': ')',
    '（': '）',
    '[': ']',
    '【': '】',
    '{': '}',
    '「': '」',
    '『': '』',
  };
  final expectedClosers = <String>[];
  final buffer = StringBuffer();
  for (final rune in artist.trim().runes) {
    final char = String.fromCharCode(rune);
    final closer = bracketPairs[char];
    if (closer != null) {
      expectedClosers.add(closer);
      continue;
    }
    if (expectedClosers.isNotEmpty) {
      if (char == expectedClosers.last) {
        expectedClosers.removeLast();
      }
      continue;
    }
    buffer.write(char);
  }
  return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

bool _containsArtistName(String containerName, String containedName) {
  var index = containerName.indexOf(containedName);
  while (index >= 0) {
    final before = index > 0 ? containerName[index - 1] : '';
    final afterIndex = index + containedName.length;
    final after =
        afterIndex < containerName.length ? containerName[afterIndex] : '';
    if (_isArtistNameBoundary(containedName[0], before) &&
        _isArtistNameBoundary(containedName[containedName.length - 1], after)) {
      return true;
    }
    index = containerName.indexOf(containedName, index + 1);
  }
  return false;
}

bool _isArtistNameBoundary(String edge, String adjacent) {
  return adjacent.isEmpty ||
      !_isArtistNameWordChar(edge) ||
      !_isArtistNameWordChar(adjacent);
}

bool _isArtistNameWordChar(String value) {
  return RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(value);
}

class _ArtistUsage {
  const _ArtistUsage({required this.name, required this.count});

  final String name;
  final int count;
}
