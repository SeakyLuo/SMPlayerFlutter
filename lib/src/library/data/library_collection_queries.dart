part of 'library_repository.dart';

({
  List<LibraryArtistSummary> artists,
  List<LibraryAlbumSummary> albums,
  int count,
})
_readCollectionSummaries(Database db, LibraryDataQuery query) {
  final local = query.source == 'local';
  final scope = '''WITH Scope AS (
    SELECT Id, Name, Artist, Album, Duration, PlayCount, ThumbnailPath, DateAdded FROM Music
    WHERE State = 1 AND ${local ? "Path NOT LIKE 'smplayer-music://%'" : 'Path LIKE ?'}
      ${query.folder == null ? '' : 'AND substr(Path, 1, ?) = ?'}
      ${query.artists.isEmpty ? '' : 'AND (Artist IN (SELECT value FROM json_each(?)) OR Id IN (SELECT MusicId FROM MusicArtist WHERE State = 1 AND Name IN (SELECT value FROM json_each(?))))'}
  ), ArtistSongs AS (
    SELECT MusicId AS Id, Name AS Artist FROM MusicArtist WHERE State = 1 AND Name <> ''
      AND MusicId IN (SELECT Id FROM Scope)
    UNION SELECT Id, Artist FROM Scope WHERE Id NOT IN (
      SELECT MusicId FROM MusicArtist WHERE State = 1 AND Name <> ''
    )
  )''';
  final arguments = <Object?>[
    if (!local) '$remoteMusicScheme://${query.source}/%',
    if (query.folder != null) ...[
      query.folder!.length + 1,
      '${query.folder!}${Platform.pathSeparator}',
    ],
    if (query.artists.isNotEmpty) ...[
      jsonEncode(query.artists),
      jsonEncode(query.artists),
    ],
  ];
  final count =
      db
              .select('$scope SELECT COUNT(*) AS count FROM Scope', arguments)
              .first['count']
          as int;
  if (query.kind == LibraryQueryKind.artistIndex) {
    final rows = db.select('''$scope, Ranked AS (
      SELECT ArtistSongs.Artist, Scope.Id, Scope.Album, Scope.Duration, Scope.PlayCount, Scope.ThumbnailPath,
        ROW_NUMBER() OVER (PARTITION BY ArtistSongs.Artist ORDER BY (Scope.ThumbnailPath = ''), Scope.Album COLLATE NOCASE, Scope.Name COLLATE NOCASE, Scope.Id) AS position
      FROM ArtistSongs INNER JOIN Scope ON Scope.Id = ArtistSongs.Id
    ) SELECT Artist, COUNT(*) AS songs, COUNT(DISTINCT Album) AS albums, SUM(Duration) AS duration, SUM(PlayCount) AS plays,
      MAX(CASE WHEN position = 1 THEN Id END) AS artworkId,
      MAX(CASE WHEN position = 1 THEN ThumbnailPath END) AS artwork
      FROM Ranked GROUP BY Artist''', arguments);
    return (
      count: count,
      albums: const [],
      artists: [
        for (final row in rows)
          LibraryArtistSummary(
            name: row['Artist'] as String,
            songCount: row['songs'] as int,
            albumCount: row['albums'] as int,
            duration: row['duration'] as int,
            playCount: row['plays'] as int,
            artworkSongId: row['artworkId'] as int,
            artworkPath: row['artwork'] as String,
          ),
      ],
    );
  }
  final rows = db.select('''$scope, Ranked AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY Album ORDER BY (ThumbnailPath = ''), Name COLLATE NOCASE, Id) AS position FROM Scope
  ) SELECT Album, COUNT(*) AS songs, SUM(Duration) AS duration, SUM(PlayCount) AS plays,
    MAX(CASE WHEN position = 1 THEN Id END) AS artworkId,
    MAX(CASE WHEN position = 1 THEN ThumbnailPath END) AS artwork
    FROM Ranked GROUP BY Album''', arguments);
  final artistRows = db.select(
    '''$scope SELECT Scope.Album, ArtistSongs.Artist, COUNT(*) AS count
    FROM ArtistSongs INNER JOIN Scope ON Scope.Id = ArtistSongs.Id
    GROUP BY Scope.Album, ArtistSongs.Artist ORDER BY count DESC, ArtistSongs.Artist COLLATE NOCASE''',
    arguments,
  );
  final artists = <String, List<String>>{};
  for (final row in artistRows) {
    artists
        .putIfAbsent(row['Album'] as String, () => [])
        .add(row['Artist'] as String);
  }
  return (
    count: count,
    artists: const [],
    albums: [
      for (final row in rows)
        LibraryAlbumSummary(
          name: row['Album'] as String,
          songCount: row['songs'] as int,
          duration: row['duration'] as int,
          playCount: row['plays'] as int,
          artists: artists[row['Album']]!,
          artworkSongId: row['artworkId'] as int,
          artworkPath: row['artwork'] as String,
        ),
    ],
  );
}
