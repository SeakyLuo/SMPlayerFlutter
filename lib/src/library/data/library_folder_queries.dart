part of 'library_repository.dart';

const _directoryArtistTexts =
    "ArtistTexts AS MATERIALIZED (SELECT MusicId, group_concat(Name, ' ') AS SearchArtists FROM MusicArtist WHERE State = 1 AND Name <> '' GROUP BY MusicId)";

String _directorySearchFrom(String text) =>
    text.isEmpty
        ? 'FROM Music'
        : 'FROM Music LEFT JOIN ArtistTexts ON ArtistTexts.MusicId = Music.Id';

String _directorySearchFilter(String text) =>
    text.isEmpty
        ? ''
        : "AND library_contains(Music.Name || ' ' || COALESCE(ArtistTexts.SearchArtists, Music.Artist) || ' ' || Music.Album || ' ' || Music.Path, ?) = 1";

void _registerDirectorySearch(Database db) {
  db.createFunction(
    functionName: 'library_contains',
    argumentCount: const AllowedArgumentCount(2),
    deterministic: true,
    function:
        (values) =>
            (values[0] as String).toLowerCase().contains(
                  (values[1] as String).toLowerCase(),
                )
                ? 1
                : 0,
  );
}

List<LibraryFolderSummary> _readFolderSummaries(
  Database db,
  String root, {
  String text = '',
}) {
  db.createFunction(
    functionName: 'song_directory',
    argumentCount: const AllowedArgumentCount(1),
    deterministic: true,
    function: (values) => p.dirname(values.single as String),
  );
  final arguments = <Object?>[
    root.length + 1,
    '$root${Platform.pathSeparator}',
    if (text.isNotEmpty) text.toLowerCase(),
  ];
  _registerDirectorySearch(db);
  final textFilter = _directorySearchFilter(text);
  final from = _directorySearchFrom(text);
  final rows = db.select(
    '''WITH $_directoryArtistTexts SELECT song_directory(Path) AS directory,
    COUNT(*) AS songs, SUM(Duration) AS duration, SUM(PlayCount) AS plays
    $from WHERE Music.State = 1 AND substr(Path,1,?) = ? $textFilter GROUP BY directory''',
    arguments,
  );
  final covers = db.select(
    '''WITH $_directoryArtistTexts, Albums AS (
    SELECT song_directory(Path) AS directory, Album, MIN(ThumbnailPath) AS artwork, MIN(Music.Id) AS artworkId
    $from WHERE Music.State = 1 AND substr(Path,1,?) = ? $textFilter AND ThumbnailPath <> ''
    GROUP BY directory, Album
  ), Ranked AS (SELECT *, ROW_NUMBER() OVER(PARTITION BY directory ORDER BY Album COLLATE NOCASE) AS position FROM Albums)
  SELECT directory, artwork, artworkId FROM Ranked WHERE position <= 4''',
    arguments,
  );
  final artwork = <String, Map<int, String>>{};
  for (final row in covers)
    artwork.putIfAbsent(row['directory'] as String, () => {})[row['artworkId']
            as int] =
        row['artwork'] as String;
  final counts =
      <
        String,
        ({
          int direct,
          int count,
          int duration,
          int plays,
          Map<int, String> covers,
        })
      >{};
  for (final row in rows) {
    final directory = row['directory'] as String;
    var current = directory;
    while (current == root || p.isWithin(root, current)) {
      final previous =
          counts[current] ??
          (direct: 0, count: 0, duration: 0, plays: 0, covers: <int, String>{});
      counts[current] = (
        direct:
            previous.direct + (current == directory ? row['songs'] as int : 0),
        count: previous.count + (row['songs'] as int),
        duration: previous.duration + (row['duration'] as int),
        plays: previous.plays + (row['plays'] as int),
        covers: Map.fromEntries(
          {...previous.covers, ...?artwork[directory]}.entries.take(4),
        ),
      );
      current = p.dirname(current);
    }
  }
  return [
    for (final item in counts.entries)
      LibraryFolderSummary(
        path: item.key,
        directCount: item.value.direct,
        songCount: item.value.count,
        duration: item.value.duration,
        playCount: item.value.plays,
        artworkPaths: item.value.covers.values.toList(),
        artworkSongIds: item.value.covers.keys.toList(),
      ),
  ];
}

Map<String, Map<int, LibrarySong>> _readDirectoryWindows(
  Database db,
  LibraryDataQuery query,
) {
  db.createFunction(
    functionName: 'song_directory',
    argumentCount: const AllowedArgumentCount(1),
    deterministic: true,
    function: (values) => p.dirname(values.single as String),
  );
  final keys = <String, ArtistTextSortKey>{};
  db.createCollation(
    name: 'library_text',
    function:
        (a, b) => (keys[a!] ??= buildArtistTextSortKey(a)).compareTo(
          keys[b!] ??= buildArtistTextSortKey(b),
        ),
  );
  registerLibraryTimeSql(db);
  final column = switch (query.order) {
    MusicLibrarySortCriterion.title => 'Name COLLATE library_text',
    MusicLibrarySortCriterion.artist => 'Artist COLLATE library_text',
    MusicLibrarySortCriterion.album => 'Album COLLATE library_text',
    MusicLibrarySortCriterion.duration => 'Duration',
    MusicLibrarySortCriterion.playCount => 'PlayCount',
    MusicLibrarySortCriterion.dateAdded =>
      'library_time(CAST(DateAdded AS TEXT))',
  };
  _registerDirectorySearch(db);
  final textFilter = _directorySearchFilter(query.text);
  final from = _directorySearchFrom(query.text);
  final direction = query.descending ? 'DESC' : 'ASC';
  final rows = db.select(
    '''WITH $_directoryArtistTexts, Requested AS (
    SELECT key AS directory, value AS start FROM json_each(?)
  ), Ranked AS (
    SELECT Id, song_directory(Path) AS directory, ROW_NUMBER() OVER(
      PARTITION BY song_directory(Path) ORDER BY $column $direction, Name COLLATE library_text $direction, Id $direction) - 1 AS position
    $from WHERE Music.State = 1 AND song_directory(Path) IN (SELECT directory FROM Requested) $textFilter
  ) SELECT Ranked.* FROM Ranked INNER JOIN Requested USING(directory)
    WHERE position >= start AND position < start + 200 ORDER BY directory, position''',
    [
      jsonEncode(query.directWindows),
      if (query.text.isNotEmpty) query.text.toLowerCase(),
    ],
  );
  final songs = LibraryRepository._readService.readSongs(
    db,
    songIds: rows.map((row) => row['Id'] as int).toList(),
  );
  final byId = {for (final song in songs) song.id: song};
  final result = <String, Map<int, LibrarySong>>{};
  for (final row in rows) {
    result.putIfAbsent(row['directory'] as String, () => {})[row['position']
            as int] =
        byId[row['Id']]!;
  }
  return result;
}
