part of 'library_repository.dart';

List<int> _selectQuickPlayIds(
  Database db,
  QuickPlayDatabasePlan plan,
  int limit,
) {
  const scope = 'Id IN (SELECT Id FROM SelectionScope)';
  db.execute('CREATE TEMP TABLE QuickCandidates (Id INTEGER PRIMARY KEY)');
  db.execute(
    'INSERT OR IGNORE INTO QuickCandidates SELECT Id FROM Music WHERE $scope ORDER BY RANDOM() LIMIT ?',
    [limit * 2],
  );
  db.execute(
    '''INSERT OR IGNORE INTO QuickCandidates SELECT Id FROM Music WHERE $scope
    AND Id IN (SELECT CAST(json_extract(value, '\$.key') AS INTEGER) FROM json_each(?))''',
    [jsonEncode(plan.choices['songs'])],
  );
  final relations = {
    'artists':
        '''SELECT MusicId AS id, Name AS key FROM MusicArtist WHERE State = 1
      AND MusicId IN (SELECT Id FROM SelectionScope) AND Name IN (SELECT key FROM Choices)
      UNION SELECT Id AS id, Artist AS key FROM Music WHERE $scope
        AND Artist IN (SELECT key FROM Choices) AND Id NOT IN (SELECT MusicId FROM MusicArtist WHERE State = 1)''',
    'albums':
        'SELECT Id AS id, trim(Album) AS key FROM Music WHERE $scope AND trim(Album) IN (SELECT key FROM Choices)',
    'playlists':
        '''SELECT ItemId AS id, CAST(PlaylistId AS TEXT) AS key FROM PlaylistItem
      WHERE State = 1 AND ItemId IN (SELECT Id FROM SelectionScope)
      AND PlaylistId IN (SELECT Id FROM Playlist WHERE State = 1)
      AND CAST(PlaylistId AS TEXT) IN (SELECT key FROM Choices)''',
    'folders':
        '''SELECT Music.Id AS id, CAST(Folder.Id AS TEXT) AS key FROM Music, Folder
      WHERE Music.Id IN (SELECT Id FROM SelectionScope) AND Folder.State = 1
        AND CAST(Folder.Id AS TEXT) IN (SELECT key FROM Choices) AND song_directory(Music.Path) = Folder.Path''',
  };
  // These four independent preference dimensions each use one set query.
  for (final entry in relations.entries) {
    db.execute(
      '''WITH Choices AS (
      SELECT json_extract(value, '\$.key') AS key, json_extract(value, '\$.count') AS amount FROM json_each(?)
    ), Matches AS (${entry.value}), Ranked AS (
      SELECT Matches.id, Choices.amount, ROW_NUMBER() OVER (PARTITION BY Choices.key ORDER BY RANDOM()) AS rank
      FROM Matches INNER JOIN Choices ON Choices.key = Matches.key
    ) INSERT OR IGNORE INTO QuickCandidates SELECT id FROM Ranked WHERE rank <= amount
      ${entry.key == 'playlists' || entry.key == 'folders' ? 'ORDER BY RANDOM() LIMIT 5' : ''}''',
      [jsonEncode(plan.choices[entry.key])],
    );
  }
  final recent = plan.builtins['recentAdded']!;
  final favorites = plan.builtins['myFavorites']!;
  if (recent > 0) {
    db.execute(
      '''INSERT OR IGNORE INTO QuickCandidates SELECT Id FROM (
      SELECT Id FROM Music WHERE $scope ORDER BY library_time(CAST(DateAdded AS TEXT)) DESC LIMIT 500
    ) ORDER BY RANDOM() LIMIT ?''',
      [recent],
    );
  }
  if (favorites > 0) {
    db.execute(
      '''INSERT OR IGNORE INTO QuickCandidates SELECT Id FROM Music WHERE $scope AND Id IN (
      SELECT ItemId FROM PlaylistItem WHERE State = 1 AND PlaylistId = (SELECT MyFavorites FROM Settings ORDER BY Id LIMIT 1)
    ) ORDER BY RANDOM() LIMIT ?''',
      [favorites],
    );
  }
  for (final dimension in [('mostPlayed', 'DESC'), ('leastPlayed', 'ASC')]) {
    if (plan.builtins[dimension.$1]! > 0) {
      db.execute(
        '''INSERT OR IGNORE INTO QuickCandidates SELECT Id FROM Music WHERE $scope AND PlayCount IN (
        SELECT PlayCount FROM Music WHERE $scope ORDER BY PlayCount ${dimension.$2} LIMIT ?
      )''',
        [limit + 1],
      );
    }
  }
  for (final entry in plan.exclusions.entries) {
    if (entry.value.values.every((values) => values.isEmpty)) continue;
    final json = jsonEncode(entry.value);
    db.execute(
      '''DELETE FROM QuickCandidates WHERE ${entry.key == 'dislike' ? '(random() & 1) = 0 AND' : ''} Id IN (
      SELECT Music.Id FROM Music WHERE Music.Id IN (SELECT Id FROM QuickCandidates) AND (
        Music.Id IN (SELECT CAST(value AS INTEGER) FROM json_each(?, '\$.songs'))
        OR Music.Id IN (SELECT MusicId FROM MusicArtist WHERE State = 1 AND Name IN (SELECT value FROM json_each(?, '\$.artists')))
        OR (Artist IN (SELECT value FROM json_each(?, '\$.artists')) AND Music.Id NOT IN (SELECT MusicId FROM MusicArtist WHERE State = 1))
        OR trim(Album) IN (SELECT value FROM json_each(?, '\$.albums'))
        OR Music.Id IN (SELECT ItemId FROM PlaylistItem WHERE State = 1 AND PlaylistId IN (SELECT CAST(value AS INTEGER) FROM json_each(?, '\$.playlists')))
        OR EXISTS(SELECT 1 FROM Folder WHERE State = 1 AND (
          CAST(Folder.Id AS TEXT) IN (SELECT value FROM json_each(?, '\$.folders'))
          OR Folder.Path IN (SELECT value FROM json_each(?, '\$.folders'))
        ) AND (song_directory(Music.Path) = Folder.Path OR substr(Music.Path, 1, length(Folder.Path) + 1) = Folder.Path || ?))
      ))''',
      [for (var index = 0; index < 7; index++) json, Platform.pathSeparator],
    );
  }
  return db
      .select('SELECT Id FROM QuickCandidates ORDER BY RANDOM() LIMIT ?', [
        limit,
      ])
      .map((row) => row['Id'] as int)
      .toList();
}
