import 'library_models.dart';

ArtistSplitAnalysisResult analyzeArtistSplits(
  List<LibrarySong> songs, {
  List<LibrarySong>? analysisSongs,
  List<LibrarySong>? usageSongs,
  bool existingLibraryScan = true,
  bool includeScannedSongsInUsage = false,
}) {
  final targetSongs =
      analysisSongs ??
      (existingLibraryScan
          ? songs
              .where(
                (song) => song.artists.length <= 1 && song.artist.isNotEmpty,
              )
              .toList()
          : songs);
  final artistSplitPlan = _buildArtistSplitPlan(
    targetSongs,
    knownArtistSongs: songs,
  );
  final artistMergePlan = _buildArtistMergePlan(
    targetSongs,
    artistSplitPlan,
    usageSongs: usageSongs ?? songs,
    includeScannedSongs: includeScannedSongsInUsage,
  );
  final directSplits = <ArtistSplitResultItem>[];
  final possibleSplits = <ArtistSplitResultItem>[];
  final mergeSuggestions = <ArtistSplitResultItem>[];

  for (final song in targetSongs) {
    final mergeArtists = artistMergePlan[song];
    if (mergeArtists != null) {
      mergeSuggestions.add(_toArtistSplitResultItem(song, mergeArtists));
      continue;
    }

    final directArtists = artistSplitPlan.autoSplits[song];
    if (directArtists != null) {
      directSplits.add(_toArtistSplitResultItem(song, directArtists));
      continue;
    }

    final possibleArtists = artistSplitPlan.suggestions[song];
    if (possibleArtists != null) {
      possibleSplits.add(_toArtistSplitResultItem(song, possibleArtists));
    }
  }

  return ArtistSplitAnalysisResult(
    directSplits: directSplits,
    possibleSplits: possibleSplits,
    mergeSuggestions: mergeSuggestions,
  );
}

List<String> splitSmartArtistCandidate(String artist) {
  return _normalizeArtists(
    artist.split(_smartArtistSplitPattern).map((part) => part.trim()).toList(),
  );
}

final _smartArtistSplitPattern = RegExp(r'\s*(?:/|／|;|；|,|，|、|\|)\s*');
final _artistValueSplitPattern = RegExp(r'\s*(?:;|；|、|\|)\s*');

_ArtistSplitPlan _buildArtistSplitPlan(
  List<LibrarySong> songs, {
  required List<LibrarySong> knownArtistSongs,
}) {
  final knownArtists = _getKnownArtists(knownArtistSongs);
  final autoSplits = <LibrarySong, List<String>>{};
  final candidates = <_ArtistSplitCandidate>[];

  for (final song in songs) {
    if (song.artists.length > 1) {
      autoSplits[song] = song.artists;
      for (final artist in song.artists) {
        knownArtists.add(_normalizeArtistKey(artist));
      }
      continue;
    }

    final artists = splitSmartArtistCandidate(song.artist);
    if (artists.length > 1) {
      candidates.add(_ArtistSplitCandidate(song: song, artists: artists));
    } else if (song.artist.isNotEmpty) {
      knownArtists.add(_normalizeArtistKey(song.artist));
    }
  }

  final recurringPartKeys = _getRecurringCandidatePartKeys(candidates);
  final unresolvedCandidates = candidates.toSet();
  var changed = true;
  while (changed) {
    changed = false;
    for (final candidate in unresolvedCandidates.toList()) {
      if (!candidate.artists.any((artist) {
        final artistKey = _normalizeArtistKey(artist);
        return knownArtists.contains(artistKey) ||
            recurringPartKeys.contains(artistKey);
      })) {
        continue;
      }

      autoSplits[candidate.song] = candidate.artists;
      for (final artist in candidate.artists) {
        knownArtists.add(_normalizeArtistKey(artist));
      }
      unresolvedCandidates.remove(candidate);
      changed = true;
    }
  }

  return _ArtistSplitPlan(
    autoSplits: autoSplits,
    suggestions: {
      for (final candidate in unresolvedCandidates)
        candidate.song: candidate.artists,
    },
  );
}

Set<String> _getKnownArtists(List<LibrarySong> songs) {
  return {
    for (final song in songs)
      for (final artist in _normalizeArtists(song.artists))
        _normalizeArtistKey(artist),
  };
}

String _normalizeArtistKey(String artist) {
  return artist.trim().toLowerCase();
}

Map<LibrarySong, List<String>> _buildArtistMergePlan(
  List<LibrarySong> songs,
  _ArtistSplitPlan artistSplitPlan, {
  required List<LibrarySong> usageSongs,
  bool includeScannedSongs = true,
}) {
  final artistUsage = _artistUsage(
    usageSongs,
    scannedSongs: songs,
    includeScannedSongs: includeScannedSongs,
  );
  final expandedCandidatesByArtistKey = <String, List<String>>{};
  final mergeSuggestions = <LibrarySong, List<String>>{};

  for (final song in songs) {
    final sourceArtists = _getArtistMergeSourceArtists(song, artistSplitPlan);
    final explodedArtists = _explodeKnownCompositeArtists(
      sourceArtists,
      artistUsage,
    );
    final mergedArtists = _mergedArtists(
      explodedArtists,
      artistUsage,
      expandedCandidatesByArtistKey,
    );

    if (_haveArtistNamesChanged(sourceArtists, mergedArtists)) {
      mergeSuggestions[song] = mergedArtists;
    }
  }

  return mergeSuggestions;
}

List<String> _explodeKnownCompositeArtists(
  List<String> artists,
  Map<String, _ArtistUsage> artistUsage,
) {
  final result = <String>[];
  for (final artist in artists) {
    final parts = splitSmartArtistCandidate(artist);
    if (parts.length > 1 &&
        parts.every(
          (part) => artistUsage.containsKey(
            _normalizeArtistKey(_normalizeArtistMergeName(part)),
          ),
        )) {
      result.addAll(parts);
    } else {
      result.add(artist);
    }
  }
  return _normalizeArtistMergeNames(result);
}

Map<String, _ArtistUsage> _artistUsage(
  List<LibrarySong> songs, {
  required List<LibrarySong> scannedSongs,
  required bool includeScannedSongs,
}) {
  final usage = <String, _ArtistUsage>{};
  for (final song in songs) {
    for (final artist in song.artists) {
      if (splitSmartArtistCandidate(artist).length != 1) {
        continue;
      }
      _addArtistUsage(usage, artist);
    }
  }
  if (includeScannedSongs) {
    for (final song in scannedSongs) {
      for (final artist in _getScannedSongArtistUnits(song)) {
        _addArtistUsage(usage, artist);
      }
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

List<String> _getScannedSongArtistUnits(LibrarySong song) {
  if (song.artists.length > 1) {
    return song.artists;
  }
  final splitArtists = splitSmartArtistCandidate(song.artist);
  return splitArtists.length > 1
      ? splitArtists
      : (song.artist.isEmpty ? [] : [song.artist]);
}

List<String> _getArtistMergeSourceArtists(
  LibrarySong song,
  _ArtistSplitPlan artistSplitPlan,
) {
  return _normalizeArtistMergeNames(
    artistSplitPlan.autoSplits[song] ??
        artistSplitPlan.suggestions[song] ??
        _getScannedSongArtistUnits(song),
  );
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
  for (final value in artists) {
    for (final artist in value.split(_artistValueSplitPattern).map((part) {
      return part.trim();
    })) {
      final key = _normalizeArtistKey(artist);
      if (artist.isEmpty || seen.contains(key)) {
        continue;
      }
      seen.add(key);
      result.add(artist);
    }
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

bool _haveArtistNamesChanged(List<String> left, List<String> right) {
  final leftKeys = _normalizeArtists(left).map(_normalizeArtistKey).toList();
  final rightKeys = _normalizeArtists(right).map(_normalizeArtistKey).toList();
  return leftKeys.length != rightKeys.length ||
      leftKeys.indexed.any((entry) => entry.$2 != rightKeys[entry.$1]);
}

Set<String> _getRecurringCandidatePartKeys(
  List<_ArtistSplitCandidate> candidates,
) {
  final candidateKeysByPartKey = <String, Set<String>>{};
  for (final candidate in candidates) {
    final candidateKey = _normalizeArtistKey(candidate.song.artist);
    for (final artist in candidate.artists) {
      final partKey = _normalizeArtistKey(artist);
      final candidateKeys = candidateKeysByPartKey[partKey] ?? <String>{};
      candidateKeys.add(candidateKey);
      candidateKeysByPartKey[partKey] = candidateKeys;
    }
  }

  return {
    for (final entry in candidateKeysByPartKey.entries)
      if (entry.value.length > 1) entry.key,
  };
}

ArtistSplitResultItem _toArtistSplitResultItem(
  LibrarySong song,
  List<String> artists,
) {
  return ArtistSplitResultItem(
    songId: song.id,
    title: song.title,
    artist: song.artist,
    artists: artists,
  );
}

class _ArtistSplitPlan {
  const _ArtistSplitPlan({required this.autoSplits, required this.suggestions});

  final Map<LibrarySong, List<String>> autoSplits;
  final Map<LibrarySong, List<String>> suggestions;
}

class _ArtistSplitCandidate {
  const _ArtistSplitCandidate({required this.song, required this.artists});

  final LibrarySong song;
  final List<String> artists;
}

class _ArtistUsage {
  const _ArtistUsage({required this.name, required this.count});

  final String name;
  final int count;
}
