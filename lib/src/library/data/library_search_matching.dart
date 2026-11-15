int evaluateString(String value, String normalizedQuery, [int offset = 0]) {
  if (value.isEmpty) {
    return 0;
  }

  final normalizedValue = value.toLowerCase();
  if (value == normalizedQuery) {
    return 100 + offset;
  }
  if (normalizedValue == normalizedQuery) {
    return 95 + offset;
  }
  if (value.startsWith(normalizedQuery)) {
    return 90 + offset;
  }
  if (normalizedValue.startsWith(normalizedQuery)) {
    return 85 + offset;
  }
  if (value.contains(normalizedQuery)) {
    return 80 + offset;
  }
  if (normalizedValue.contains(normalizedQuery)) {
    return 75 + offset;
  }
  if (normalizedQuery.contains(normalizedValue)) {
    return 70 + offset;
  }

  final longest =
      normalizedValue.length > normalizedQuery.length
          ? normalizedValue.length
          : normalizedQuery.length;
  final maxDistance = ((61 * longest) - 1) ~/ 100;
  if ((normalizedValue.length - normalizedQuery.length).abs() > maxDistance)
    return 0;
  final editDistance = _distanceWithin(
    normalizedValue,
    normalizedQuery,
    maxDistance,
  );
  final ratio =
      (editDistance * 100) ~/
      [
        normalizedValue.length,
        normalizedQuery.length,
      ].reduce((left, right) => left > right ? left : right);
  return ratio <= 60 ? 70 - ratio + offset : 0;
}

int getEditDistance(String target, String given) {
  final dp = List.generate(
    target.length + 1,
    (rowIndex) => List.generate(
      given.length + 1,
      (columnIndex) =>
          rowIndex == 0
              ? columnIndex
              : columnIndex == 0
              ? rowIndex
              : 0,
    ),
  );

  for (var rowIndex = 1; rowIndex <= target.length; rowIndex += 1) {
    for (var columnIndex = 1; columnIndex <= given.length; columnIndex += 1) {
      final replaceCost =
          target[rowIndex - 1] == given[columnIndex - 1] ? 0 : 1;
      dp[rowIndex][columnIndex] = [
        dp[rowIndex - 1][columnIndex] + 1,
        dp[rowIndex][columnIndex - 1] + 1,
        dp[rowIndex - 1][columnIndex - 1] + replaceCost,
      ].reduce((left, right) => left < right ? left : right);
    }
  }

  return dp[target.length][given.length];
}

int matchLibraryText(
  String title,
  List<String> artists,
  String album,
  int playCount,
  String query,
) {
  final artistScore = artists
      .map((artist) => evaluateString(artist, query))
      .fold(0, (best, score) => score > best ? score : best);
  final base = [
    evaluateString(title, query),
    artistScore - 10,
    evaluateString(album, query) - 20,
    0,
  ].reduce((a, b) => a > b ? a : b);
  return base == 0 ? 0 : base + (playCount / 10).clamp(0, 10).floor();
}

int _distanceWithin(String target, String given, int limit) {
  var previous = List.generate(given.length + 1, (index) => index);
  for (var row = 1; row <= target.length; row++) {
    final next = List<int>.filled(given.length + 1, limit + 1)..[0] = row;
    var minimum = next[0];
    final from = (row - limit).clamp(1, given.length);
    final through = (row + limit).clamp(1, given.length);
    for (var column = from; column <= through; column++) {
      final substitution =
          previous[column - 1] + (target[row - 1] == given[column - 1] ? 0 : 1);
      final insertion = next[column - 1] + 1, deletion = previous[column] + 1;
      var value = insertion < deletion ? insertion : deletion;
      if (substitution < value) value = substitution;
      next[column] = value;
      if (value < minimum) minimum = value;
    }
    if (minimum > limit) return limit + 1;
    previous = next;
  }
  return previous.last;
}
