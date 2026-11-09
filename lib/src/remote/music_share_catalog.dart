import 'package:sqlite3/sqlite3.dart';

import '../library/data/library_models.dart';
import '../library/data/library_snapshot_service.dart';
import 'music_share_models.dart';

Map<String, dynamic> sharedSongJson(LibrarySong song) => {
  'id': song.id,
  'title': song.title,
  'artist': song.artist,
  'artists': song.artists,
  'album': song.album,
  'duration': song.duration,
  'dateAdded': song.dateAdded,
  'artwork': song.thumbnailPath.isNotEmpty,
  'artworkRevision': shareDigest(song.thumbnailPath),
};

Future<void> importMusicShareCatalog(
  String databasePath,
  String deviceId,
  List<Map<String, dynamic>> songs,
) => LibrarySnapshotService.run(() {
  final db = sqlite3.open(databasePath);
  try {
    db.execute('BEGIN IMMEDIATE');
    final paths = {
      for (final row in db.select(
        'SELECT Id, Path FROM Music WHERE Path LIKE ?',
        ['$remoteMusicScheme://$deviceId/%'],
      ))
        row['Path'] as String: row['Id'] as int,
    };
    db.execute('UPDATE Music SET RemoteAvailable = 0 WHERE Path LIKE ?', [
      '$remoteMusicScheme://$deviceId/%',
    ]);
    final upsert = db.prepare('''
      INSERT INTO Music (Path, Name, Artist, Album, Duration, DateAdded, ThumbnailPath, RemoteAvailable, State)
      VALUES (?, ?, ?, ?, ?, ?, ?, 1, 1)
      ON CONFLICT(Path) DO UPDATE SET Name = excluded.Name,
        Artist = excluded.Artist, Album = excluded.Album,
        Duration = excluded.Duration, ThumbnailPath = excluded.ThumbnailPath, RemoteAvailable = 1, State = 1
    ''');
    final clearArtists = db.prepare(
      'DELETE FROM MusicArtist WHERE MusicId = ?',
    );
    final insertArtist = db.prepare('''
      INSERT INTO MusicArtist (MusicId, Name, Priority, State) VALUES (?, ?, ?, 1)
    ''');
    try {
      for (final song in songs) {
        final path = remoteMusicPath(deviceId, song['id'] as int);
        upsert.execute([
          path,
          song['title'],
          song['artist'],
          song['album'],
          song['duration'],
          song['dateAdded'],
          song['artwork'] == true ? '$path?art=${song['artworkRevision']}' : '',
        ]);
        final id = paths[path] ?? db.lastInsertRowId;
        clearArtists.execute([id]);
        final artists = (song['artists'] as List).cast<String>();
        for (var index = 0; index < artists.length; index++) {
          insertArtist.execute([id, artists[index], index]);
        }
      }
    } finally {
      upsert.dispose();
      clearArtists.dispose();
      insertArtist.dispose();
    }
    db.execute('COMMIT');
  } catch (_) {
    db.execute('ROLLBACK');
    rethrow;
  } finally {
    db.dispose();
  }
});
