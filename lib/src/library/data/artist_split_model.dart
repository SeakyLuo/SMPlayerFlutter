import 'dart:convert';
import 'library_models.dart';

class ArtistSplitSource implements ArtistTagSource {
  const ArtistSplitSource(
    this.artist,
    this.artists, [
    this.artistOccurrenceCount = 1,
  ]);
  final String artist;
  final List<String> artists;
  final int artistOccurrenceCount;
}

ArtistSplitAnalysisResult analyzeArtistSplits(
  List<LibrarySong> songs, {
  List<LibrarySong>? analysisSongs,
  List<LibrarySong>? usageSongs,
  bool existingLibraryScan = true,
  bool includeScannedSongsInUsage = false,
  void Function(double progress)? onProgress,
  Set<int>? songIds,
  List<ArtistSplitSource>? recognitionSources,
}) {
  var lastReportedPercent = -1;
  void reportProgress(double progress) {
    final percent = (progress.clamp(0.0, 1.0) * 100).floor();
    if (percent == lastReportedPercent) {
      return;
    }
    lastReportedPercent = percent;
    onProgress?.call(percent / 100);
  }

  reportProgress(0);
  final splitTargetSongs =
      analysisSongs ??
      (existingLibraryScan
          ? songs
              .where(
                (song) =>
                    (songIds == null || songIds.contains(song.id)) &&
                    song.artists.length <= 1 &&
                    song.artist.isNotEmpty,
              )
              .toList()
          : songs);
  final mergeTargetSongs =
      analysisSongs ??
      songs
          .where(
            (song) =>
                (songIds == null || songIds.contains(song.id)) &&
                (song.artist.isNotEmpty || song.artists.isNotEmpty),
          )
          .toList();
  reportProgress(0.04);
  final artistSplitPlan = _buildArtistSplitPlan(
    splitTargetSongs,
    knownArtistSongs: songs,
    recognitionSources: recognitionSources,
    onProgress: (progress) => reportProgress(0.04 + progress * 0.21),
  );
  final artistMergePlan = _buildArtistMergePlan(
    mergeTargetSongs,
    artistSplitPlan,
    usageSongs: usageSongs ?? songs,
    usageAnalysisSongs: songIds == null ? mergeTargetSongs : songs,
    includeScannedSongs: includeScannedSongsInUsage,
    recognitionSources: recognitionSources,
    onProgress: (progress) => reportProgress(0.25 + progress * 0.67),
  );
  final splitTargetSongSet = splitTargetSongs.toSet();
  final directSplits = <ArtistSplitResultItem>[];
  final possibleSplits = <ArtistSplitResultItem>[];
  final mergeSuggestions = <ArtistSplitResultItem>[];

  for (final (index, song) in mergeTargetSongs.indexed) {
    final resultProgress =
        0.92 + ((index + 1) / mergeTargetSongs.length) * 0.08;
    final mergeArtists = artistMergePlan[song];
    if (mergeArtists != null) {
      mergeSuggestions.add(_toArtistSplitResultItem(song, mergeArtists));
      reportProgress(resultProgress);
      continue;
    }
    if (!splitTargetSongSet.contains(song)) {
      reportProgress(resultProgress);
      continue;
    }

    final directArtists = artistSplitPlan.autoSplits[song];
    if (directArtists != null) {
      directSplits.add(_toArtistSplitResultItem(song, directArtists));
      reportProgress(resultProgress);
      continue;
    }

    final possibleArtists = artistSplitPlan.suggestions[song];
    if (possibleArtists != null) {
      possibleSplits.add(_toArtistSplitResultItem(song, possibleArtists));
    }
    reportProgress(resultProgress);
  }

  reportProgress(1);

  return ArtistSplitAnalysisResult(
    directSplits: directSplits,
    possibleSplits: possibleSplits,
    mergeSuggestions: mergeSuggestions,
  );
}

String artistRuleKey(ArtistTagSource source) =>
    jsonEncode([source.artist, source.artists]);

class ArtistSplitRules {
  const ArtistSplitRules(this.direct, this.possible, this.merges);
  final Map<String, List<String>> direct;
  final Map<String, List<String>> possible;
  final Map<String, List<String>> merges;

  ArtistSplitAnalysisResult apply(List<LibrarySong> songs) {
    List<ArtistSplitResultItem> matches(Map<String, List<String>> rules) => [
      for (final song in songs)
        if (rules.containsKey(artistRuleKey(song)))
          _toArtistSplitResultItem(song, rules[artistRuleKey(song)]!),
    ];
    return ArtistSplitAnalysisResult(
      directSplits: matches(direct),
      possibleSplits: matches(possible),
      mergeSuggestions: matches(merges),
    );
  }
}

ArtistSplitRules buildArtistSplitRules(List<ArtistSplitSource> sources) {
  final targets =
      sources
          .where(
            (source) => source.artists.length <= 1 && source.artist.isNotEmpty,
          )
          .toList();
  final plan = _buildArtistSplitPlan(targets, knownArtistSongs: sources);
  final merges = _buildArtistMergePlan(
    sources,
    plan,
    usageSongs: const [],
    usageAnalysisSongs: sources,
    recognitionSources: sources,
  );
  return ArtistSplitRules(
    {
      for (final entry in plan.autoSplits.entries)
        if (!merges.containsKey(entry.key))
          artistRuleKey(entry.key): entry.value,
    },
    {
      for (final entry in plan.suggestions.entries)
        if (!merges.containsKey(entry.key))
          artistRuleKey(entry.key): entry.value,
    },
    {for (final entry in merges.entries) artistRuleKey(entry.key): entry.value},
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
  List<ArtistTagSource> songs, {
  required List<ArtistTagSource> knownArtistSongs,
  List<ArtistSplitSource>? recognitionSources,
  void Function(double progress)? onProgress,
}) {
  final knownArtists =
      recognitionSources == null
          ? _getKnownArtists(knownArtistSongs)
          : {
            for (final source in recognitionSources)
              for (final name in _normalizeArtists(source.artists))
                _normalizeArtistKey(name),
          };
  final autoSplits = <ArtistTagSource, List<String>>{};
  final candidates = <_ArtistSplitCandidate>[];

  for (final (index, song) in songs.indexed) {
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
    onProgress?.call((index + 1) / songs.length);
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

Set<String> _getKnownArtists(List<ArtistTagSource> songs) {
  return {
    for (final song in songs)
      for (final artist in _normalizeArtists(song.artists))
        _normalizeArtistKey(artist),
  };
}

String _normalizeArtistKey(String artist) {
  return artist.trim().toLowerCase();
}

Map<ArtistTagSource, List<String>> _buildArtistMergePlan(
  List<ArtistTagSource> songs,
  _ArtistSplitPlan artistSplitPlan, {
  required List<ArtistTagSource> usageSongs,
  required List<ArtistTagSource> usageAnalysisSongs,
  bool includeScannedSongs = true,
  List<ArtistSplitSource>? recognitionSources,
  void Function(double progress)? onProgress,
}) {
  final artistUsage = _artistUsage(
    usageSongs,
    scannedSongs: usageAnalysisSongs,
    includeScannedSongs: includeScannedSongs,
    recognitionSources: recognitionSources,
  );
  final expandedCandidatesByArtistKey = <String, List<String>>{};
  final mergeSuggestions = <ArtistTagSource, List<String>>{};
  onProgress?.call(0.05);

  for (final (index, song) in songs.indexed) {
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
    onProgress?.call(0.05 + ((index + 1) / songs.length) * 0.95);
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
  List<ArtistTagSource> songs, {
  required List<ArtistTagSource> scannedSongs,
  required bool includeScannedSongs,
  List<ArtistSplitSource>? recognitionSources,
}) {
  final usage = <String, _ArtistUsage>{};
  for (final song in songs) {
    for (final artist in song.artists) {
      if (splitSmartArtistCandidate(artist).length != 1) {
        continue;
      }
      _addArtistUsage(usage, artist, song.artistOccurrenceCount);
    }
  }
  if (includeScannedSongs) {
    final sources =
        recognitionSources ??
        [
          for (final song in scannedSongs)
            ArtistSplitSource(song.artist, song.artists),
        ];
    for (final source in sources) {
      for (final artist in _scannedArtistUnits(source.artist, source.artists)) {
        _addArtistUsage(usage, artist, source.artistOccurrenceCount);
      }
    }
  }
  return usage;
}

void _addArtistUsage(
  Map<String, _ArtistUsage> usage,
  String artist,
  int count,
) {
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
      count: (current?.count ?? 0) + count,
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

List<String> _getScannedSongArtistUnits(ArtistTagSource song) =>
    _scannedArtistUnits(song.artist, song.artists);

List<String> _scannedArtistUnits(String artist, List<String> artists) {
  if (artists.length > 1) return artists;
  final splitArtists = splitSmartArtistCandidate(artist);
  return splitArtists.length > 1
      ? splitArtists
      : (artist.isEmpty ? [] : [artist]);
}

List<String> _getArtistMergeSourceArtists(
  ArtistTagSource song,
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

  final Map<ArtistTagSource, List<String>> autoSplits;
  final Map<ArtistTagSource, List<String>> suggestions;
}

class _ArtistSplitCandidate {
  const _ArtistSplitCandidate({required this.song, required this.artists});

  final ArtistTagSource song;
  final List<String> artists;
}

class _ArtistUsage {
  const _ArtistUsage({required this.name, required this.count});

  final String name;
  final int count;
}
