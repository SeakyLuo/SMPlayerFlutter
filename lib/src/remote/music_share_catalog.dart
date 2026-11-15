import 'dart:convert';
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
  'playCount': song.playCount,
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
  required bool Function() isCurrent,
}) {
  final operation = _CatalogImport(
    databasePath,
    deviceId,
    songs,
    replace,
    removedSongIds,
  );
  return LibrarySnapshotService.runIfCurrent(operation.run, isCurrent);
}

class _CatalogImport {
  const _CatalogImport(
    this.databasePath,
    this.deviceId,
    this.songs,
    this.replace,
    this.removedSongIds,
  );
  final String databasePath;
  final String deviceId;
  final List<Map<String, dynamic>> songs;
  final bool replace;
  final List<int> removedSongIds;

  void run() {
    final db = sqlite3.open(databasePath);
    try {
      db.execute('BEGIN IMMEDIATE');
      final paths = {
        for (final row in db.select(
          replace
              ? 'SELECT Id, Path FROM Music WHERE Path LIKE ?'
              : 'SELECT Id, Path FROM Music WHERE Path IN (SELECT value FROM json_each(?))',
          [
            replace
                ? '$remoteMusicScheme://$deviceId/%'
                : jsonEncode(
                  songs
                      .map(
                        (song) => remoteMusicPath(deviceId, song['id'] as int),
                      )
                      .toList(),
                ),
          ],
        ))
          row['Path'] as String: row['Id'] as int,
      };
      if (replace) {
        db.execute('UPDATE Music SET RemoteAvailable = 0 WHERE Path LIKE ?', [
          '$remoteMusicScheme://$deviceId/%',
        ]);
      }
      final upsert = db.prepare('''
      INSERT INTO Music (Path, Name, Artist, Album, Duration, DateAdded, ThumbnailPath, RemoteAvailable, RemoteDetailsLoaded, State)
      VALUES (?, ?, ?, ?, ?, ?, ?, 1, 1, 1)
      ON CONFLICT(Path) DO UPDATE SET Name = excluded.Name,
        Artist = excluded.Artist, Album = excluded.Album,
        Duration = excluded.Duration, ThumbnailPath = excluded.ThumbnailPath, RemoteAvailable = 1, RemoteDetailsLoaded = 1, State = 1
    ''');
      final updateOffset = db.prepare(
        'UPDATE Music SET LyricsOffsetMs = ? WHERE Id = ?',
      );
      final updatePlayCount = db.prepare(
        'UPDATE Music SET PlayCount = ? WHERE Id = ?',
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
            song['artwork'] == true
                ? '$path?art=${song['artworkRevision']}'
                : '',
          ]);
          final id = paths[path] ?? db.lastInsertRowId;
          // Older hosts do not publish the shared offset.
          if (song.containsKey('lyricsOffsetMs')) {
            updateOffset.execute([song['lyricsOffsetMs'], id]);
          }
          if (song.containsKey('playCount')) {
            updatePlayCount.execute([song['playCount'], id]);
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
        updatePlayCount.dispose();
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
  }
}

Map<String, dynamic> sharedCatalogChanges(
  Map<int, LibrarySong> before,
  Map<int, LibrarySong> after, {
  Iterable<int> affectedIds = const [],
}) {
  final changed =
      affectedIds.toSet()
        ..addAll(before.keys.where((id) => !after.containsKey(id)));
  for (final song in after.values) {
    if (!before.containsKey(song.id) ||
        jsonEncode(sharedSongJson(song)) !=
            jsonEncode(sharedSongJson(before[song.id]!)))
      changed.add(song.id);
  }
  return {
    'songs': <Map<String, dynamic>>[],
    'removed': <int>[],
    'changed': changed.toList(),
  };
}
