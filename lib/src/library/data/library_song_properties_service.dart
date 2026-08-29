import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import 'id3_tag_service.dart';
import 'library_artist_tag_normalizer.dart' as artist_tags;
import 'library_models.dart';

const _activeState = 1;
const _inactiveState = 0;
const _id3TagService = Id3TagService();

class LibrarySongPropertiesService {
  const LibrarySongPropertiesService();

  Future<void> updateSongDuration(
    File databaseFile,
    int songId,
    int durationSeconds,
  ) async {
    if (!databaseFile.existsSync()) {
      return;
    }

    final db = sqlite3.open(databaseFile.path);
    try {
      db.execute(
        '''
        UPDATE Music
        SET Duration = ?
        WHERE Id = ?
          AND State = ?
      ''',
        [durationSeconds, songId, _activeState],
      );
    } finally {
      db.dispose();
    }
  }

  Future<SongPropertiesSnapshot> getSongProperties(
    File databaseFile,
    int songId,
  ) async {
    final db = sqlite3.open(databaseFile.path);
    try {
      final rows = db.select(
        '''
        SELECT
          Id AS id,
          Path AS path,
          Name AS title,
          Artist AS artist,
          Album AS album,
          Duration AS duration,
          PlayCount AS playCount
        FROM Music
        WHERE Id = ?
          AND State = ?
        LIMIT 1
      ''',
        [songId, _activeState],
      );
      final row = rows.first;
      final artists = readSongArtists(db, songId, row['artist'] as String);
      final file = File(row['path'] as String);
      final stats = await file.stat();
      final extension = p.extension(file.path).replaceFirst('.', '');
      final id3Properties = await Isolate.run(
        () => _id3TagService.readSongTagProperties(file.path),
      );
      final title = normalizeTagText(id3Properties.title);
      final artist = normalizeArtists(
        artist_tags.normalizeArtistTagValues(
          id3Properties.artists,
          id3Properties.artist,
        ),
      ).join(', ');
      final album = normalizeTagText(id3Properties.album);

      return SongPropertiesSnapshot(
        songId: songId,
        path: file.path,
        title: title.isEmpty ? normalizeTagText(row['title'] as String) : title,
        subtitle: id3Properties.subtitle,
        artist:
            artist.isEmpty ? normalizeTagText(row['artist'] as String) : artist,
        artists: artists,
        album: album.isEmpty ? normalizeTagText(row['album'] as String) : album,
        albumArtist: id3Properties.albumArtist,
        publisher: id3Properties.publisher,
        trackNumber: id3Properties.trackNumber,
        year: id3Properties.year,
        genre: id3Properties.genre,
        composers: id3Properties.composers,
        duration: row['duration'] as int,
        bitrate: 0,
        fileSize: stats.size,
        dateCreated: stats.changed.toIso8601String(),
        dateModified: stats.modified.toIso8601String(),
        fileType: extension.toUpperCase(),
        playCount: row['playCount'] as int,
      );
    } finally {
      db.dispose();
    }
  }

  Future<List<SongPropertiesSnapshot>> getSongPropertiesBatch(
    File databaseFile,
    List<int> songIds,
  ) async {
    final selectedSongIds = songIds.toSet();
    final db = sqlite3.open(databaseFile.path);
    try {
      final songRows = db.select(
        '''
        SELECT
          Id AS id,
          Path AS path,
          Name AS title,
          Artist AS artist,
          Album AS album,
          Duration AS duration,
          PlayCount AS playCount
        FROM Music
        WHERE State = ?
      ''',
        [_activeState],
      );
      final artistRows = db.select(
        '''
        SELECT MusicId AS musicId, Name AS name
        FROM MusicArtist
        WHERE State = ?
        ORDER BY MusicId, Priority, Id
      ''',
        [_activeState],
      );
      final artistsBySongId = <int, List<String>>{};
      for (final row in artistRows) {
        final songId = row['musicId'] as int;
        if (selectedSongIds.contains(songId)) {
          (artistsBySongId[songId] ??= []).add(row['name'] as String);
        }
      }
      final selectedRows = [
        for (final row in songRows)
          if (selectedSongIds.contains(row['id'] as int)) row,
      ];
      final snapshots = <SongPropertiesSnapshot>[];
      for (final row in selectedRows) {
        final songId = row['id'] as int;
        final file = File(row['path'] as String);
        final stats = await file.stat();
        final extension = p.extension(file.path).replaceFirst('.', '');
        final id3Properties = await _id3TagService.readSongTagProperties(
          file.path,
        );
        final title = normalizeTagText(id3Properties.title);
        final normalizedArtists = normalizeArtists(
          artist_tags.normalizeArtistTagValues(
            id3Properties.artists,
            id3Properties.artist,
          ),
        );
        final artists = normalizeArtists(
          artistsBySongId[songId] ?? [row['artist'] as String],
        );
        final album = normalizeTagText(id3Properties.album);
        snapshots.add(
          SongPropertiesSnapshot(
            songId: songId,
            path: file.path,
            title:
                title.isEmpty
                    ? normalizeTagText(row['title'] as String)
                    : title,
            subtitle: id3Properties.subtitle,
            artist:
                normalizedArtists.isEmpty
                    ? normalizeTagText(row['artist'] as String)
                    : normalizedArtists.join(', '),
            artists: artists,
            album:
                album.isEmpty
                    ? normalizeTagText(row['album'] as String)
                    : album,
            albumArtist: id3Properties.albumArtist,
            publisher: id3Properties.publisher,
            trackNumber: id3Properties.trackNumber,
            year: id3Properties.year,
            genre: id3Properties.genre,
            composers: id3Properties.composers,
            duration: row['duration'] as int,
            bitrate: 0,
            fileSize: stats.size,
            dateCreated: stats.changed.toIso8601String(),
            dateModified: stats.modified.toIso8601String(),
            fileType: extension.toUpperCase(),
            playCount: row['playCount'] as int,
          ),
        );
      }
      final orderBySongId = {
        for (final entry in songIds.indexed) entry.$2: entry.$1,
      };
      snapshots.sort(
        (left, right) =>
            orderBySongId[left.songId]!.compareTo(orderBySongId[right.songId]!),
      );
      return snapshots;
    } finally {
      db.dispose();
    }
  }

  Future<void> updateSongProperties(
    File databaseFile,
    int songId,
    SongPropertiesUpdate update,
  ) async {
    final title = update.title.trim();
    final artists = normalizeArtists(update.artists).take(6).toList();
    final artist = artists.join(', ');
    final album = update.album.trim();
    final db = sqlite3.open(databaseFile.path);
    try {
      final songRows = db.select(
        '''
        SELECT Path AS path
        FROM Music
        WHERE Id = ?
          AND State = ?
        LIMIT 1
      ''',
        [songId, _activeState],
      );
      final songPath = songRows.first['path'] as String;
      await _id3TagService.writeSongTagProperties(
        songPath,
        Id3SongTagProperties(
          title: title,
          subtitle: update.subtitle.trim(),
          artist: artist,
          album: album,
          albumArtist: update.albumArtist.trim(),
          publisher: update.publisher.trim(),
          trackNumber: update.trackNumber,
          year: update.year,
          genre: update.genre.trim(),
          composers: update.composers.trim(),
        ),
      );

      db.execute('BEGIN');
      try {
        db.execute(
          '''
          UPDATE Music
          SET Name = ?, Artist = ?, Album = ?, PlayCount = ?
          WHERE Id = ?
            AND State = ?
        ''',
          [title, artist, album, update.playCount, songId, _activeState],
        );
        syncSongArtists(db, songId, artists);
        db.execute('COMMIT');
      } on Object {
        db.execute('ROLLBACK');
        rethrow;
      }
    } finally {
      db.dispose();
    }
  }

  Future<BatchSongPropertiesUpdateResult> updateSongPropertiesBatch(
    File databaseFile,
    Map<int, SongPropertiesUpdate> updates,
  ) async {
    final db = sqlite3.open(databaseFile.path);
    try {
      final songRows = db.select(
        '''
        SELECT Id AS id, Path AS path
        FROM Music
        WHERE State = ?
      ''',
        [_activeState],
      );
      final pathBySongId = {
        for (final row in songRows)
          if (updates.containsKey(row['id'] as int))
            row['id'] as int: row['path'] as String,
      };
      final existingArtistRows = db.select('''
        SELECT Id AS id, MusicId AS musicId, Name AS name
        FROM MusicArtist
        ORDER BY MusicId, Id
      ''');
      final artistRowsBySongId = <int, List<Row>>{};
      for (final row in existingArtistRows) {
        final songId = row['musicId'] as int;
        if (updates.containsKey(songId)) {
          (artistRowsBySongId[songId] ??= []).add(row);
        }
      }

      final updatedSongIds = <int>[];
      final failedSongIds = <int>[];
      for (final entry in updates.entries) {
        final update = entry.value;
        final artists = normalizeArtists(update.artists).take(6).toList();
        try {
          await _id3TagService.writeSongTagProperties(
            pathBySongId[entry.key]!,
            Id3SongTagProperties(
              title: update.title.trim(),
              subtitle: update.subtitle.trim(),
              artist: artists.join(', '),
              artists: artists,
              album: update.album.trim(),
              albumArtist: update.albumArtist.trim(),
              publisher: update.publisher.trim(),
              trackNumber: update.trackNumber,
              year: update.year,
              genre: update.genre.trim(),
              composers: update.composers.trim(),
            ),
          );
          updatedSongIds.add(entry.key);
        } catch (_) {
          failedSongIds.add(entry.key);
        }
      }

      db.execute('BEGIN');
      try {
        for (final songId in updatedSongIds) {
          final update = updates[songId]!;
          final artists = normalizeArtists(update.artists).take(6).toList();
          db.execute(
            '''
            UPDATE Music
            SET Name = ?, Artist = ?, Album = ?, PlayCount = ?
            WHERE Id = ? AND State = ?
          ''',
            [
              update.title.trim(),
              artists.join(', '),
              update.album.trim(),
              update.playCount,
              songId,
              _activeState,
            ],
          );
          _syncSongArtistsFromRows(
            db,
            songId,
            artists,
            artistRowsBySongId[songId] ?? const [],
          );
        }
        db.execute('COMMIT');
      } on Object {
        db.execute('ROLLBACK');
        rethrow;
      }
      return BatchSongPropertiesUpdateResult(
        updatedSongIds: updatedSongIds,
        failedSongIds: failedSongIds,
      );
    } finally {
      db.dispose();
    }
  }

  void _syncSongArtistsFromRows(
    Database db,
    int songId,
    List<String> artists,
    List<Row> existingRows,
  ) {
    db.execute('UPDATE MusicArtist SET State = ? WHERE MusicId = ?', [
      _inactiveState,
      songId,
    ]);
    final rowsByName = {
      for (final row in existingRows)
        (row['name'] as String).toLowerCase(): row,
    };
    for (final entry in artists.indexed) {
      final artist = entry.$2;
      final existingRow = rowsByName[artist.toLowerCase()];
      if (existingRow == null) {
        db.execute(
          '''
          INSERT INTO MusicArtist (MusicId, Name, Priority, State)
          VALUES (?, ?, ?, ?)
        ''',
          [songId, artist, entry.$1, _activeState],
        );
      } else {
        db.execute(
          '''
          UPDATE MusicArtist
          SET Name = ?, Priority = ?, State = ?
          WHERE Id = ?
        ''',
          [artist, entry.$1, _activeState, existingRow['id'] as int],
        );
      }
    }
  }

  Future<void> updateSongPlayCount(
    File databaseFile,
    int songId,
    int playCount,
  ) async {
    final db = sqlite3.open(databaseFile.path);
    try {
      db.execute(
        '''
        UPDATE Music
        SET PlayCount = ?
        WHERE Id = ?
          AND State = ?
      ''',
        [playCount, songId, _activeState],
      );
    } finally {
      db.dispose();
    }
  }

  List<String> readSongArtists(Database db, int songId, String fallbackArtist) {
    final rows = db.select(
      '''
      SELECT Name AS name
      FROM MusicArtist
      WHERE MusicId = ?
        AND State = ?
      ORDER BY Priority, Id
    ''',
      [songId, _activeState],
    );
    final artists = normalizeArtists(
      rows.map((row) => row['name'] as String).toList(),
    );
    if (artists.isNotEmpty) {
      return artists;
    }

    return normalizeArtists([fallbackArtist]);
  }

  void syncSongArtists(Database db, int songId, List<String> artists) {
    db.execute('UPDATE MusicArtist SET State = ? WHERE MusicId = ?', [
      _inactiveState,
      songId,
    ]);
    for (final entry in artists.indexed) {
      final artist = entry.$2;
      final existingRows = db.select(
        '''
        SELECT Id AS id
        FROM MusicArtist
        WHERE MusicId = ?
          AND Name = ? COLLATE NOCASE
        LIMIT 1
      ''',
        [songId, artist],
      );
      if (existingRows.isEmpty) {
        db.execute(
          '''
          INSERT INTO MusicArtist (MusicId, Name, Priority, State)
          VALUES (?, ?, ?, ?)
        ''',
          [songId, artist, entry.$1, _activeState],
        );
      } else {
        db.execute(
          '''
          UPDATE MusicArtist
          SET Name = ?, Priority = ?, State = ?
          WHERE Id = ?
        ''',
          [artist, entry.$1, _activeState, existingRows.single['id'] as int],
        );
      }
    }
  }

  List<String> normalizeArtists(List<String> artists) {
    return artist_tags.normalizeArtists(artists);
  }

  String normalizeTagText(String value) {
    return artist_tags.normalizeTagText(value);
  }
}
