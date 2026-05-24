import 'dart:io';

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

  ArtistSplitAnalysisResult analyze(List<LibrarySong> songs) {
    return artist_split_model.analyzeArtistSplits(songs);
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

    final db = sqlite3.open(databaseFile.path);
    try {
      db.execute('BEGIN');
      try {
        applySplitsInsideTransaction(db, splits);
        db.execute('COMMIT');
      } on Object {
        db.execute('ROLLBACK');
        rethrow;
      }
    } finally {
      db.dispose();
    }
  }

  void applySplitsInsideTransaction(
    Database db,
    List<ArtistSplitResultItem> splits,
  ) {
    for (final split in splits) {
      final artists =
          _songPropertiesService
              .normalizeArtists(split.artists)
              .take(6)
              .toList();
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
