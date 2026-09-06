import 'package:sqlite3/sqlite3.dart';

import 'library_audio_metadata_service.dart';
import 'library_models.dart';

const _activeState = 1;
const _inactiveState = 0;

class LibraryLocalScanBatchWriter {
  LibraryLocalScanBatchWriter(Database db)
    : _upsertMusic = db.prepare('''
        INSERT INTO Music (
          Path,
          Name,
          Artist,
          Album,
          ThumbnailPath,
          Duration,
          PlayCount,
          DateAdded,
          FileSize,
          DateModifiedMs,
          State
        )
        VALUES (
          ?, ?, ?, ?, ?,
          ?,
          COALESCE((SELECT PlayCount FROM Music WHERE Path = ?), 0),
          ?, ?, ?,
          ?
        )
        ON CONFLICT(Path) DO UPDATE SET
          Name = excluded.Name,
          Artist = excluded.Artist,
          Album = excluded.Album,
          ThumbnailPath = excluded.ThumbnailPath,
          Duration = excluded.Duration,
          DateAdded = excluded.DateAdded,
          FileSize = excluded.FileSize,
          DateModifiedMs = excluded.DateModifiedMs,
          State = excluded.State
        RETURNING Id AS id
      '''),
      _upsertFile = db.prepare('''
        INSERT INTO File (Path, ParentId, FileId, FileType, State)
        VALUES (?, ?, ?, 0, ?)
        ON CONFLICT(Path) DO UPDATE SET
          ParentId = excluded.ParentId,
          FileId = excluded.FileId,
          State = excluded.State
      '''),
      _deactivateArtists = db.prepare('''
        UPDATE MusicArtist
        SET State = ?
        WHERE MusicId = ?
      '''),
      _upsertArtist = db.prepare('''
        INSERT INTO MusicArtist (MusicId, Name, Priority, State)
        VALUES (?, ?, ?, ?)
        ON CONFLICT DO UPDATE SET
          Name = excluded.Name,
          Priority = excluded.Priority,
          State = excluded.State
      ''') {
    for (final row in db.select('''
      SELECT Id, Path, Name, Artist, Album, ThumbnailPath, Duration,
        CAST(DateAdded AS TEXT) AS DateAdded, FileSize, DateModifiedMs, State
      FROM Music
    ''')) {
      _musicByPath[row['Path'] as String] = row;
    }
    for (final row in db.select(
      'SELECT Path, ParentId, FileId, State FROM File',
    )) {
      _filesByPath[row['Path'] as String] = row;
    }
    for (final row in db.select('''
      SELECT MusicId, Name, Priority FROM MusicArtist
      WHERE State = 1 ORDER BY MusicId, Priority, Id
    ''')) {
      (_artistsBySongId[row['MusicId'] as int] ??= []).add((
        row['Name'] as String,
        row['Priority'] as int,
      ));
    }
  }

  final PreparedStatement _upsertMusic;
  final PreparedStatement _upsertFile;
  final PreparedStatement _deactivateArtists;
  final PreparedStatement _upsertArtist;
  final _musicByPath = <String, Row>{};
  final _filesByPath = <String, Row>{};
  final _artistsBySongId = <int, List<(String, int)>>{};

  int write({
    required String filePath,
    required LibrarySong song,
    required AudioFileMetadata metadata,
    required int parentId,
    required List<String> artists,
  }) {
    final stored = _musicByPath[filePath];
    final artist = artists.join(', ');
    final musicUnchanged =
        stored != null &&
        stored['Name'] == song.title &&
        stored['Artist'] == artist &&
        stored['Album'] == song.album &&
        stored['ThumbnailPath'] == metadata.thumbnailPath &&
        stored['Duration'] == metadata.duration &&
        stored['DateAdded'] == metadata.dateAdded &&
        stored['FileSize'] == metadata.fileSize &&
        stored['DateModifiedMs'] == metadata.dateModifiedMs &&
        stored['State'] == _activeState;
    final songId =
        musicUnchanged
            ? stored['Id'] as int
            : _upsertMusic.select([
                  filePath,
                  song.title,
                  artist,
                  song.album,
                  metadata.thumbnailPath,
                  metadata.duration,
                  filePath,
                  metadata.dateAdded,
                  metadata.fileSize,
                  metadata.dateModifiedMs,
                  _activeState,
                ]).first['id']
                as int;

    final storedArtists = _artistsBySongId[songId] ?? const [];
    final artistsUnchanged =
        storedArtists.length == artists.length &&
        artists.indexed.every(
          (entry) => storedArtists[entry.$1] == (entry.$2, entry.$1),
        );
    if (!artistsUnchanged) {
      _deactivateArtists.execute([_inactiveState, songId]);
      for (final entry in artists.indexed) {
        _upsertArtist.execute([songId, entry.$2, entry.$1, _activeState]);
      }
    }
    final storedFile = _filesByPath[filePath];
    if (storedFile == null ||
        storedFile['ParentId'] != parentId ||
        storedFile['FileId'] != songId ||
        storedFile['State'] != _activeState) {
      _upsertFile.execute([filePath, parentId, songId, _activeState]);
    }
    return songId;
  }

  void dispose() {
    _upsertArtist.dispose();
    _deactivateArtists.dispose();
    _upsertFile.dispose();
    _upsertMusic.dispose();
  }
}
