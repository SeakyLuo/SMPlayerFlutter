import 'package:sqlite3/sqlite3.dart';

import 'id3_tag_service.dart';
import 'library_audio_metadata_service.dart';

const _activeState = 1;

Map<String, AudioFileMetadata> readStoredAudioFileMetadata(
  Database db, {
  String? folderPath,
}) {
  final songRows =
      folderPath == null
          ? db.select(
            '''
            SELECT
              Id AS id,
              Path AS path,
              Name AS title,
              Artist AS artist,
              Album AS album,
              ThumbnailPath AS thumbnailPath,
              Duration AS duration,
              CAST(DateAdded AS TEXT) AS dateAdded,
              FileSize AS fileSize,
              DateModifiedMs AS dateModifiedMs
            FROM Music
            WHERE State = ?
          ''',
            [_activeState],
          )
          : db.select(
            '''
            SELECT
              Id AS id,
              Path AS path,
              Name AS title,
              Artist AS artist,
              Album AS album,
              ThumbnailPath AS thumbnailPath,
              Duration AS duration,
              CAST(DateAdded AS TEXT) AS dateAdded,
              FileSize AS fileSize,
              DateModifiedMs AS dateModifiedMs
            FROM Music
            WHERE State = ?
              AND (Path = ? OR Path LIKE ? OR Path LIKE ?)
          ''',
            [_activeState, folderPath, '$folderPath/%', '$folderPath\\%'],
          );
  final selectedSongIds = {for (final row in songRows) row['id'] as int};
  final artistsBySongId = <int, List<String>>{};
  for (final row in db.select(
    '''
    SELECT MusicId AS musicId, Name AS name
    FROM MusicArtist
    WHERE State = ?
    ORDER BY MusicId, Priority, Id
  ''',
    [_activeState],
  )) {
    final songId = row['musicId'] as int;
    if (selectedSongIds.contains(songId)) {
      (artistsBySongId[songId] ??= []).add(row['name'] as String);
    }
  }

  return {
    for (final row in songRows)
      row['path'] as String: AudioFileMetadata(
        properties: Id3SongTagProperties(
          title: row['title'] as String,
          artist: row['artist'] as String,
          artists: artistsBySongId[row['id'] as int] ?? const [],
          album: row['album'] as String,
        ),
        duration: row['duration'] as int,
        thumbnailPath: row['thumbnailPath'] as String,
        dateAdded: row['dateAdded'] as String,
        fileSize: row['fileSize'] as int,
        dateModifiedMs: row['dateModifiedMs'] as int,
      ),
  };
}
