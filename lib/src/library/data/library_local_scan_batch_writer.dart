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
      ''');

  final PreparedStatement _upsertMusic;
  final PreparedStatement _upsertFile;
  final PreparedStatement _deactivateArtists;
  final PreparedStatement _upsertArtist;

  int write({
    required String filePath,
    required LibrarySong song,
    required AudioFileMetadata metadata,
    required int parentId,
    required List<String> artists,
  }) {
    final rows = _upsertMusic.select([
      filePath,
      song.title,
      artists.join(', '),
      song.album,
      metadata.thumbnailPath,
      metadata.duration,
      filePath,
      metadata.dateAdded,
      metadata.fileSize,
      metadata.dateModifiedMs,
      _activeState,
    ]);
    final songId = rows.first['id'] as int;

    _deactivateArtists.execute([_inactiveState, songId]);
    for (final entry in artists.indexed) {
      _upsertArtist.execute([songId, entry.$2, entry.$1, _activeState]);
    }
    _upsertFile.execute([filePath, parentId, songId, _activeState]);
    return songId;
  }

  void dispose() {
    _upsertArtist.dispose();
    _deactivateArtists.dispose();
    _upsertFile.dispose();
    _upsertMusic.dispose();
  }
}
