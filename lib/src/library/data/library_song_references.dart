part of 'library_repository.dart';

extension LibrarySongReferences on LibraryRepository {
  Future<Map<int, String>> songReferences(
    List<int> ids, {
    bool includeInactive = false,
  }) async {
    final file = await _resolveDatabaseFile();
    await LibrarySnapshotService.waitForPendingOperations();
    return Isolate.run(() {
      final db = sqlite3.open(file.path, mode: OpenMode.readOnly);
      try {
        return {
          for (final row in db.select(
            'SELECT Id, Path FROM Music WHERE ${includeInactive ? 'State >= 0' : 'State = 1'} AND Id IN (SELECT value FROM json_each(?))',
            [jsonEncode(ids)],
          ))
            row['Id'] as int: row['Path'] as String,
        };
      } finally {
        db.dispose();
      }
    });
  }

  Future<Set<int>> playableQueueReferences(List<int> ids) async {
    final references = await songReferences(ids, includeInactive: true);
    final groups = <LibrarySource, List<int>>{};
    for (final entry in references.entries) {
      final source = LibrarySource.fromPath(entry.value);
      if (source is RemoteLibrarySource &&
          !activeMusicShareAccess!.isOnline(entry.value))
        continue;
      groups.putIfAbsent(source, () => []).add(entry.key);
    }
    final values = await Future.wait(
      groups.entries.map(
        (entry) => dataSource(entry.key).resolveSongIds(
          LibraryDataQuery(LibraryQueryKind.songs, songIds: entry.value),
        ),
      ),
    );
    return values.expand((ids) => ids).toSet();
  }

  Future<List<LibrarySong>> resolveSongDetails(List<int> ids) async {
    final file = await _resolveDatabaseFile();
    await LibrarySnapshotService.waitForPendingOperations();
    final missing = await Isolate.run(() {
      final db = sqlite3.open(file.path, mode: OpenMode.readOnly);
      try {
        return {
          for (final row in db.select(
            "SELECT Id, Path FROM Music WHERE (RemoteDetailsLoaded = 0 OR RemoteAvailable = 0) AND Path LIKE 'smplayer-music://%' AND Id IN (SELECT value FROM json_each(?))",
            [jsonEncode(ids)],
          ))
            row['Id'] as int: row['Path'] as String,
        };
      } finally {
        db.dispose();
      }
    });
    final groups = <String, List<int>>{};
    for (final entry in missing.entries) {
      groups.putIfAbsent(Uri.parse(entry.value).host, () => []).add(entry.key);
    }
    await Future.wait(
      groups.entries.map(
        (entry) => activeMusicShareAccess!.queryLibraryData(
          entry.key,
          LibraryDataQuery(
            LibraryQueryKind.songs,
            source: entry.key,
            songIds: entry.value,
          ),
        ),
      ),
    );
    return const LibrarySnapshotService().readSongs(file.path, songIds: ids);
  }

  Future<void> invalidateRemoteSongDetails(
    String device,
    List<int> hostIds, {
    bool? favorite,
  }) async {
    final file = await _resolveDatabaseFile();
    final paths = jsonEncode(
      hostIds.map((id) => remoteMusicPath(device, id)).toList(),
    );
    await LibrarySnapshotService.run(() {
      final db = sqlite3.open(file.path);
      try {
        db.execute('BEGIN IMMEDIATE');
        if (favorite == null) {
          db.execute(
            'UPDATE Music SET RemoteDetailsLoaded = 0 WHERE Path IN (SELECT value FROM json_each(?))',
            [paths],
          );
        } else {
          final ids =
              db
                  .select(
                    'SELECT Id FROM Music WHERE Path IN (SELECT value FROM json_each(?))',
                    [paths],
                  )
                  .map((row) => row['Id'] as int)
                  .toList();
          LibraryRepository._playlistService.applySharedFavorites(
            db,
            favorite ? ids : const [],
            favorite ? const [] : ids,
          );
        }
        db.execute('COMMIT');
      } finally {
        db.dispose();
      }
    });
  }

  Future<List<int>> cacheRemoteSongReferences(
    String device,
    List<int> hostIds,
  ) async {
    final file = await _resolveDatabaseFile();
    final paths = hostIds.map((id) => remoteMusicPath(device, id)).toList();
    return LibrarySnapshotService.run(() {
      final db = sqlite3.open(file.path);
      try {
        db.execute('BEGIN IMMEDIATE');
        db.execute(
          '''INSERT INTO Music(Path,RemoteAvailable,RemoteDetailsLoaded,State)
          SELECT value,1,0,1 FROM json_each(?) WHERE 1
          ON CONFLICT(Path) DO UPDATE SET RemoteAvailable=1,State=1,
            RemoteDetailsLoaded=CASE WHEN Music.State=0 OR Music.RemoteAvailable=0 THEN 0 ELSE Music.RemoteDetailsLoaded END
          WHERE Music.State<>1 OR Music.RemoteAvailable<>1''',
          [jsonEncode(paths)],
        );
        final ids = {
          for (final row in db.select(
            'SELECT Id, Path FROM Music WHERE Path IN (SELECT value FROM json_each(?))',
            [jsonEncode(paths)],
          ))
            row['Path'] as String: row['Id'] as int,
        };
        db.execute('COMMIT');
        return [for (final path in paths) ids[path]!];
      } finally {
        db.dispose();
      }
    });
  }
}
