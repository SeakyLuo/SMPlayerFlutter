import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import 'id3_tag_service.dart';
import 'library_models.dart';

const _activeState = 1;
const _id3TagService = Id3TagService();

typedef ShellThumbnailResolver =
    Future<ShellThumbnail?> Function(String filePath);

class ShellThumbnail {
  const ShellThumbnail({required this.data, required this.extension});

  final List<int> data;
  final String extension;
}

class LibraryArtworkService {
  const LibraryArtworkService({
    required Future<File> Function() databaseFileResolver,
    required ShellThumbnailResolver shellThumbnailResolver,
  }) : _databaseFileResolver = databaseFileResolver,
       _shellThumbnailResolver = shellThumbnailResolver;

  final Future<File> Function() _databaseFileResolver;
  final ShellThumbnailResolver _shellThumbnailResolver;

  Future<SongArtworkSnapshot> getSongArtworkSnapshot(
    File databaseFile,
    int songId,
  ) async {
    final db = sqlite3.open(databaseFile.path);
    try {
      final rows = db.select(
        '''
        SELECT Path AS path, ThumbnailPath AS thumbnailPath
        FROM Music
        WHERE Id = ?
          AND State = ?
        LIMIT 1
      ''',
        [songId, _activeState],
      );
      return await _resolveSongArtworkSnapshot(
        db,
        songId,
        rows.first['path'] as String,
        rows.first['thumbnailPath'] as String,
      );
    } finally {
      db.dispose();
    }
  }

  Future<List<SongArtworkSnapshot>> getSongArtworkSnapshots(
    File databaseFile,
    List<int> songIds,
  ) async {
    final uniqueIds = songIds.toSet().toList();
    if (uniqueIds.isEmpty) {
      return [];
    }

    final placeholders = List.filled(uniqueIds.length, '?').join(', ');
    final db = sqlite3.open(databaseFile.path);
    try {
      final rows = db.select(
        '''
        SELECT Id AS id, Path AS path, ThumbnailPath AS thumbnailPath
        FROM Music
        WHERE Id IN ($placeholders)
          AND State = ?
      ''',
        [...uniqueIds, _activeState],
      );
      final rowsById = {for (final row in rows) row['id'] as int: row};
      return [
        for (final songId in uniqueIds)
          if (rowsById[songId] case final row?)
            await _resolveSongArtworkSnapshot(
              db,
              songId,
              row['path'] as String,
              row['thumbnailPath'] as String,
            )
          else
            _createSongArtworkSnapshot(songId, ''),
      ];
    } finally {
      db.dispose();
    }
  }

  Future<String> prepareSongArtworkSource(String sourcePath) async {
    final source = File(sourcePath);
    final cacheDirectory = await _resolveArtworkCacheDirectory();
    final extension = p.extension(source.path);
    if (extension.toLowerCase() == '.mp3') {
      final picture = await _id3TagService.readFirstPicture(source.path);
      if (picture == null) {
        throw StateError('No album art found in the selected music file.');
      }

      final target = File(
        p.join(
          cacheDirectory.path,
          '${DateTime.now().microsecondsSinceEpoch}${_extensionForMimeType(picture.format)}',
        ),
      );
      await target.writeAsBytes(picture.data);
      return target.path;
    }

    final target = File(
      p.join(
        cacheDirectory.path,
        '${DateTime.now().microsecondsSinceEpoch}$extension',
      ),
    );
    await source.copy(target.path);
    return target.path;
  }

  Future<void> saveSongArtwork(
    File databaseFile,
    int songId,
    String sourcePath,
  ) async {
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
      await _id3TagService.writeSongArtwork(
        songPath,
        Id3Picture(
          data: await File(sourcePath).readAsBytes(),
          format: _getArtworkMimeType(sourcePath),
        ),
      );

      db.execute(
        '''
        UPDATE Music
        SET ThumbnailPath = ?
        WHERE Id = ?
          AND State = ?
      ''',
        [sourcePath, songId, _activeState],
      );
    } finally {
      db.dispose();
    }
  }

  Future<void> saveAlbumArtwork(
    File databaseFile,
    String albumName,
    String sourcePath,
  ) async {
    final db = sqlite3.open(databaseFile.path);
    try {
      final songRows = db.select(
        '''
        SELECT Path AS path
        FROM Music
        WHERE Album = ?
          AND State = ?
      ''',
        [albumName, _activeState],
      );
      final picture = Id3Picture(
        data: await File(sourcePath).readAsBytes(),
        format: _getArtworkMimeType(sourcePath),
      );
      for (final row in songRows) {
        await _id3TagService.writeSongArtwork(row['path'] as String, picture);
      }

      db.execute(
        '''
        UPDATE Music
        SET ThumbnailPath = ?
        WHERE Album = ?
          AND State = ?
      ''',
        [sourcePath, albumName, _activeState],
      );
    } finally {
      db.dispose();
    }
  }

  Future<void> deleteSongArtwork(File databaseFile, int songId) async {
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
      await _id3TagService.writeSongArtwork(
        songRows.first['path'] as String,
        null,
      );

      db.execute(
        '''
        UPDATE Music
        SET ThumbnailPath = ''
        WHERE Id = ?
          AND State = ?
      ''',
        [songId, _activeState],
      );
    } finally {
      db.dispose();
    }
  }

  Future<void> deleteAlbumArtwork(File databaseFile, String albumName) async {
    final db = sqlite3.open(databaseFile.path);
    try {
      final songRows = db.select(
        '''
        SELECT Path AS path
        FROM Music
        WHERE Album = ?
          AND State = ?
      ''',
        [albumName, _activeState],
      );
      for (final row in songRows) {
        await _id3TagService.writeSongArtwork(row['path'] as String, null);
      }

      db.execute(
        '''
        UPDATE Music
        SET ThumbnailPath = ''
        WHERE Album = ?
          AND State = ?
      ''',
        [albumName, _activeState],
      );
    } finally {
      db.dispose();
    }
  }

  Future<String> cacheSongArtwork(String filePath) async {
    final picture = await _id3TagService.readFirstPicture(filePath);
    if (picture != null && _isLikelyImage(picture.data)) {
      return _writeArtworkCacheBytes(
        picture.data,
        _extensionForMimeType(picture.format),
      );
    }

    final shellThumbnail = await _shellThumbnailResolver(filePath);
    if (shellThumbnail != null && _isLikelyImage(shellThumbnail.data)) {
      return _writeArtworkCacheBytes(
        shellThumbnail.data,
        shellThumbnail.extension,
      );
    }
    return '';
  }

  Future<void> pruneArtworkCache(Database db) async {
    try {
      final cacheDirectory = await _resolveArtworkCacheDirectory();
      final activeThumbnailPaths =
          db
              .select(
                '''
                SELECT ThumbnailPath AS thumbnailPath
                FROM Music
                WHERE State = ?
                  AND NULLIF(ThumbnailPath, '') IS NOT NULL
              ''',
                [_activeState],
              )
              .map((row) => row['thumbnailPath'] as String)
              .toSet();
      for (final entry in cacheDirectory.listSync()) {
        if (entry is! File) {
          continue;
        }
        if (activeThumbnailPaths.contains(entry.path)) {
          continue;
        }
        try {
          await entry.delete();
        } on Object {
          // Cache cleanup must not fail the library scan.
        }
      }
    } on Object {
      // Cache cleanup must not fail the library scan.
    }
  }

  Future<SongArtworkSnapshot> _resolveSongArtworkSnapshot(
    Database db,
    int songId,
    String songPath,
    String thumbnailPath,
  ) async {
    if (thumbnailPath.isNotEmpty && File(thumbnailPath).existsSync()) {
      return _createSongArtworkSnapshot(songId, thumbnailPath);
    }

    final picture = await _id3TagService.readFirstPicture(songPath);
    if (picture == null) {
      return _createSongArtworkSnapshot(songId, '');
    }

    final cacheDirectory = await _resolveArtworkCacheDirectory();
    final target = File(
      p.join(
        cacheDirectory.path,
        '${DateTime.now().microsecondsSinceEpoch}_$songId${_extensionForMimeType(picture.format)}',
      ),
    );
    await target.writeAsBytes(picture.data);
    db.execute(
      '''
      UPDATE Music
      SET ThumbnailPath = ?
      WHERE Id = ?
        AND State = ?
    ''',
      [target.path, songId, _activeState],
    );
    return SongArtworkSnapshot(
      songId: songId,
      artworkUrl: target.path,
      sourceUrl: target.path,
      sourcePath: target.path,
      source: SongArtworkSource.embedded,
    );
  }

  SongArtworkSnapshot _createSongArtworkSnapshot(
    int songId,
    String thumbnailPath,
  ) {
    if (thumbnailPath.isEmpty || !File(thumbnailPath).existsSync()) {
      return SongArtworkSnapshot(
        songId: songId,
        artworkUrl: '',
        sourceUrl: '',
        sourcePath: '',
        source: SongArtworkSource.none,
      );
    }

    return SongArtworkSnapshot(
      songId: songId,
      artworkUrl: thumbnailPath,
      sourceUrl: thumbnailPath,
      sourcePath: thumbnailPath,
      source: SongArtworkSource.cached,
    );
  }

  Future<String> _writeArtworkCacheBytes(
    List<int> data,
    String extension,
  ) async {
    final cacheDirectory = await _resolveArtworkCacheDirectory();
    final artworkHash = sha1.convert(data).toString();
    final normalizedExtension =
        extension.isEmpty
            ? '.jpg'
            : extension.startsWith('.')
            ? extension
            : '.$extension';
    final target = File(
      p.join(cacheDirectory.path, '$artworkHash$normalizedExtension'),
    );
    if (!target.existsSync()) {
      await target.writeAsBytes(data);
    }
    return target.path;
  }

  Future<Directory> _resolveArtworkCacheDirectory() async {
    final databaseFile = await _databaseFileResolver();
    final directory = Directory(
      p.join(databaseFile.parent.path, 'ArtworkCache'),
    );
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
    return directory;
  }
}

bool _isLikelyImage(List<int> data) {
  if (data.length < 12) {
    return false;
  }
  if (data[0] == 0xff && data[1] == 0xd8 && data[2] == 0xff) {
    return true;
  }
  if (data[0] == 0x89 &&
      data[1] == 0x50 &&
      data[2] == 0x4e &&
      data[3] == 0x47 &&
      data[4] == 0x0d &&
      data[5] == 0x0a &&
      data[6] == 0x1a &&
      data[7] == 0x0a) {
    return true;
  }
  if (data[0] == 0x52 &&
      data[1] == 0x49 &&
      data[2] == 0x46 &&
      data[3] == 0x46 &&
      data[8] == 0x57 &&
      data[9] == 0x45 &&
      data[10] == 0x42 &&
      data[11] == 0x50) {
    return true;
  }
  if (data[0] == 0x47 &&
      data[1] == 0x49 &&
      data[2] == 0x46 &&
      data[3] == 0x38) {
    return true;
  }
  if (data[0] == 0x42 && data[1] == 0x4d) {
    return true;
  }
  return false;
}

String _getArtworkMimeType(String sourcePath) {
  return switch (p.extension(sourcePath).toLowerCase()) {
    '.jpg' || '.jpeg' => 'image/jpeg',
    '.png' => 'image/png',
    '.webp' => 'image/webp',
    '.bmp' => 'image/bmp',
    _ => 'image/jpeg',
  };
}

String _extensionForMimeType(String mimeType) {
  return switch (mimeType.toLowerCase()) {
    'image/jpeg' || 'image/jpg' => '.jpg',
    'image/png' => '.png',
    'image/webp' => '.webp',
    'image/bmp' => '.bmp',
    _ => '.jpg',
  };
}
