import 'dart:io';

import 'dart:isolate';

import 'package:sqlite3/sqlite3.dart';

import 'artist_split_model.dart' as artist_split_model;
import 'library_models.dart';
import 'library_local_scan_service.dart';
import 'library_song_properties_service.dart';

const _activeState = 1;

class LibraryArtistSplitService {
  const LibraryArtistSplitService({
    required LibrarySongPropertiesService songPropertiesService,
  }) : _songPropertiesService = songPropertiesService;

  final LibrarySongPropertiesService _songPropertiesService;

  Future<ArtistSplitAnalysisResult> analyzeExistingLibrary(
    List<LibrarySong> songs, {
    void Function(double progress)? onProgress,
    Set<int>? songIds,
  }) async {
    if (onProgress == null) {
      return Isolate.run(
        _AnalyzeExistingLibraryTask(songs: songs, songIds: songIds).call,
      );
    }

    final progressPort = ReceivePort();
    final subscription = progressPort.listen((progress) {
      onProgress(progress as double);
    });
    try {
      return await Isolate.run(
        _AnalyzeExistingLibraryTask(
          songs: songs,
          songIds: songIds,
          progressPort: progressPort.sendPort,
        ).call,
      );
    } finally {
      await subscription.cancel();
      progressPort.close();
    }
  }

  Future<ArtistSplitAnalysisResult> analyzeScannedLibrary(
    List<LibrarySong> existingSongs, {
    required List<LibrarySong> scannedSongs,
  }) {
    return Isolate.run(
      _AnalyzeScannedLibraryTask(
        existingSongs: existingSongs,
        scannedSongs: scannedSongs,
      ).call,
    );
  }

  ArtistSplitAnalysisResult emptyAnalysis() {
    return const ArtistSplitAnalysisResult(
      directSplits: [],
      possibleSplits: [],
      mergeSuggestions: [],
    );
  }

  Future<void> applySplits(
    File databaseFile,
    List<ArtistSplitResultItem> splits,
  ) async {
    if (splits.isEmpty) {
      return;
    }

    await Isolate.run(
      _ApplyArtistSplitsTask(
        databasePath: databaseFile.path,
        splits: splits,
      ).call,
    );
  }

  void applySplitsInsideTransaction(
    Database db,
    List<ArtistSplitResultItem> splits,
  ) {
    for (final split in splits) {
      final artists = _songPropertiesService.normalizeArtists(split.artists);
      db.execute(
        '''
        UPDATE Music
        SET Artist = ?
        WHERE Id = ?
          AND State = ?
      ''',
        [artists.join(', '), split.songId, _activeState],
      );
      _songPropertiesService.syncSongArtists(db, split.songId, artists);
    }
  }
}

class _AnalyzeExistingLibraryTask {
  const _AnalyzeExistingLibraryTask({
    required this.songs,
    this.progressPort,
    this.songIds,
  });

  final List<LibrarySong> songs;
  final SendPort? progressPort;
  final Set<int>? songIds;

  ArtistSplitAnalysisResult call() {
    return artist_split_model.analyzeArtistSplits(
      songs,
      songIds: songIds,
      usageSongs: const [],
      includeScannedSongsInUsage: true,
      onProgress: progressPort?.send,
    );
  }
}

class _AnalyzeScannedLibraryTask {
  const _AnalyzeScannedLibraryTask({
    required this.existingSongs,
    required this.scannedSongs,
  });

  final List<LibrarySong> existingSongs;
  final List<LibrarySong> scannedSongs;

  ArtistSplitAnalysisResult call() {
    final scannedPathKeys = {
      for (final song in scannedSongs) localScanPathComparisonKey(song.path),
    };
    final retainedSongs =
        existingSongs
            .where(
              (song) =>
                  !scannedPathKeys.contains(
                    localScanPathComparisonKey(song.path),
                  ),
            )
            .toList();
    return artist_split_model.analyzeArtistSplits(
      [...retainedSongs, ...scannedSongs],
      analysisSongs: scannedSongs,
      usageSongs: retainedSongs,
      existingLibraryScan: false,
      includeScannedSongsInUsage: true,
    );
  }
}

class _ApplyArtistSplitsTask {
  const _ApplyArtistSplitsTask({
    required this.databasePath,
    required this.splits,
  });

  final String databasePath;
  final List<ArtistSplitResultItem> splits;

  void call() {
    _applyArtistSplits(databasePath, splits);
  }
}

void _applyArtistSplits(
  String databasePath,
  List<ArtistSplitResultItem> splits,
) {
  const service = LibraryArtistSplitService(
    songPropertiesService: LibrarySongPropertiesService(),
  );
  final db = sqlite3.open(databasePath);
  try {
    db.execute('BEGIN');
    try {
      service.applySplitsInsideTransaction(db, splits);
      db.execute('COMMIT');
    } on Object {
      db.execute('ROLLBACK');
      rethrow;
    }
  } finally {
    db.dispose();
  }
}
