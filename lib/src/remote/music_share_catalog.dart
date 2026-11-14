import 'package:sqlite3/sqlite3.dart';

import '../library/data/library_models.dart';
import '../library/data/library_playlist_service.dart';
import '../library/data/library_snapshot_service.dart';
import 'music_share_models.dart';

Map<String, dynamic> sharedSongJson(LibrarySong song) => {
  'id': song.id,
  'title': song.title,
  'artist': song.artist,
  'artists': song.artists,
  'album': song.album,
  'duration': song.duration,
  'lyricsOffsetMs': song.lyricsOffsetMs,
  'favorite': song.favorite,
  'dateAdded': song.dateAdded,
  'artwork': song.thumbnailPath.isNotEmpty,
  'artworkRevision': shareDigest(song.thumbnailPath),
};

Future<void> importMusicShareCatalog(
  String databasePath,
  String deviceId,
  List<Map<String, dynamic>> songs, {
  bool replace = true,
  List<int> removedSongIds = const [],
}) => LibrarySnapshotService.run(() {
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
    if (replace) {
      db.execute('UPDATE Music SET RemoteAvailable = 0 WHERE Path LIKE ?', [
        '$remoteMusicScheme://$deviceId/%',
      ]);
    }
    final upsert = db.prepare('''
      INSERT INTO Music (Path, Name, Artist, Album, Duration, DateAdded, ThumbnailPath, RemoteAvailable, State)
      VALUES (?, ?, ?, ?, ?, ?, ?, 1, 1)
      ON CONFLICT(Path) DO UPDATE SET Name = excluded.Name,
        Artist = excluded.Artist, Album = excluded.Album,
        Duration = excluded.Duration, ThumbnailPath = excluded.ThumbnailPath, RemoteAvailable = 1, State = 1
    ''');
    final updateOffset = db.prepare(
      'UPDATE Music SET LyricsOffsetMs = ? WHERE Id = ?',
    );
    final clearArtists = db.prepare(
      'DELETE FROM MusicArtist WHERE MusicId = ?',
    );
    final insertArtist = db.prepare('''
      INSERT INTO MusicArtist (MusicId, Name, Priority, State) VALUES (?, ?, ?, 1)
    ''');
    final liked = <int>[];
    final unliked = <int>[];
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
        // Older hosts do not publish the shared offset.
        if (song.containsKey('lyricsOffsetMs')) {
          updateOffset.execute([song['lyricsOffsetMs'], id]);
        }
        if (song.containsKey('favorite')) {
          (song['favorite'] as bool ? liked : unliked).add(id);
        }
        clearArtists.execute([id]);
        final artists = (song['artists'] as List).cast<String>();
        for (var index = 0; index < artists.length; index++) {
          insertArtist.execute([id, artists[index], index]);
        }
      }
    } finally {
      upsert.dispose();
      updateOffset.dispose();
      clearArtists.dispose();
      insertArtist.dispose();
    }
    if (liked.isNotEmpty || unliked.isNotEmpty) {
      const LibraryPlaylistService().applySharedFavorites(db, liked, unliked);
    }
    if (removedSongIds.isNotEmpty) {
      final removedPaths =
          removedSongIds.map((id) => remoteMusicPath(deviceId, id)).toList();
      db.execute(
        'UPDATE Music SET State = 0, RemoteAvailable = 0 WHERE Path IN (${List.filled(removedPaths.length, '?').join(',')})',
        removedPaths,
      );
    }
    db.execute('COMMIT');
  } catch (_) {
    db.execute('ROLLBACK');
    rethrow;
  } finally {
    db.dispose();
  }
});
