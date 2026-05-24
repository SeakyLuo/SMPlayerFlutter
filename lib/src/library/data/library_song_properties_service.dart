import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import 'id3_tag_service.dart';
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
      final id3Properties = await _id3TagService.readSongTagProperties(
        file.path,
      );
      final title = normalizeTagText(id3Properties.title);
      final artist = normalizeTagText(id3Properties.artist);
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
    if (artists.isEmpty) {
      return;
    }

    final values = List.filled(artists.length, '(?, ?, ?, ?)').join(', ');
    db.execute(
      '''
      INSERT INTO MusicArtist (MusicId, Name, Priority, State)
      VALUES $values
    ''',
      [
        for (final entry in artists.indexed) ...[
          songId,
          entry.$2,
          entry.$1,
          _activeState,
        ],
      ],
    );
  }

  List<String> normalizeArtists(List<String> artists) {
    return artists
        .map(normalizeTagText)
        .where((artist) => artist.isNotEmpty)
        .toSet()
        .toList();
  }

  String normalizeTagText(String value) {
    return value.trim();
  }
}
