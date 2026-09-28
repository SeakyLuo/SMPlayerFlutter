import 'dart:io';

import 'dart:isolate';

import 'package:sqlite3/sqlite3.dart';

import 'artist_split_model.dart' as artist_split_model;
import 'library_models.dart';
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
  }) async {
    if (onProgress == null) {
      return Isolate.run(
        () => artist_split_model.analyzeArtistSplits(
          songs,
          usageSongs: const [],
          includeScannedSongsInUsage: true,
        ),
      );
    }

    final progressPort = ReceivePort();
    final subscription = progressPort.listen((progress) {
      onProgress(progress as double);
    });
    try {
      final sendPort = progressPort.sendPort;
      return await Isolate.run(
        () => artist_split_model.analyzeArtistSplits(
          songs,
          usageSongs: const [],
          includeScannedSongsInUsage: true,
          onProgress: sendPort.send,
        ),
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
      () => artist_split_model.analyzeArtistSplits(
        [...existingSongs, ...scannedSongs],
        analysisSongs: scannedSongs,
        usageSongs: existingSongs,
        existingLibraryScan: false,
        includeScannedSongsInUsage: true,
      ),
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

    await Isolate.run(() => _applyArtistSplits(databaseFile.path, splits));
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
