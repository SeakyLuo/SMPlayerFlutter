import 'package:flutter_test/flutter_test.dart';
import 'package:smplayer_flutter/src/library/data/artist_split_model.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';

void main() {
  test('analyzeArtistSplits promotes known artists to direct splits', () {
    final result = analyzeArtistSplits([
      _song(1, 'Duet', 'Alpha / Beta'),
      _song(2, 'Solo Alpha', 'Alpha'),
    ]);

    expect(result.directSplits, hasLength(1));
    expect(result.directSplits.single.title, 'Duet');
    expect(result.directSplits.single.artists, ['Alpha', 'Beta']);
    expect(result.possibleSplits, isEmpty);
  });

  test('analyzeArtistSplits keeps unsupported feat text unsplit', () {
    final result = analyzeArtistSplits([
      _song(1, 'Collab', 'Alpha feat. Gamma'),
      _song(2, 'Solo Alpha', 'Alpha'),
    ]);

    expect(result.directSplits, isEmpty);
    expect(result.possibleSplits, isEmpty);
  });

  test('analyzeArtistSplits splits pipe separated artists', () {
    final result = analyzeArtistSplits([
      _song(1, 'Pipe Collab', 'Alpha|Beta'),
      _song(2, 'Solo Alpha', 'Alpha'),
    ]);

    expect(result.directSplits, hasLength(1));
    expect(result.directSplits.single.artists, ['Alpha', 'Beta']);
  });

  test('analyzeArtistSplits promotes recurring candidate parts', () {
    final result = analyzeArtistSplits([
      _song(1, 'First Collab', 'Alpha / Beta'),
      _song(2, 'Second Collab', 'Alpha / Gamma'),
    ]);

    expect(result.directSplits, hasLength(2));
    expect(result.possibleSplits, isEmpty);
    expect(result.directSplits.map((item) => item.artists), [
      ['Alpha', 'Beta'],
      ['Alpha', 'Gamma'],
    ]);
  });

  test('analyzeArtistSplits skips songs already split in artist table', () {
    final result = analyzeArtistSplits([
      _song(1, 'Already Split', 'Alpha, Beta', ['Alpha', 'Beta']),
      _song(2, 'Solo Alpha', 'Alpha'),
      _song(3, 'Solo Beta', 'Beta'),
    ]);

    expect(result.hasSuggestions, isFalse);
  });

  test('analyzeArtistSplits suggests contained artist merges', () {
    final result = analyzeArtistSplits([
      _song(1, 'Short Artist', 'Jay', ['Jay']),
      _song(2, 'Canonical Artist', 'Jay Chou', ['Jay Chou']),
    ]);

    expect(result.directSplits, isEmpty);
    expect(result.possibleSplits, isEmpty);
    expect(result.mergeSuggestions, hasLength(1));
    expect(result.mergeSuggestions.single.songId, 1);
    expect(result.mergeSuggestions.single.artists, ['Jay Chou']);
  });

  test('analyzeArtistSplits promotes known composite artist values', () {
    final result = analyzeArtistSplits([
      _song(1, 'Composite Artist', 'Jay, Wen', ['Jay, Wen']),
      _song(2, 'Solo Jay', 'Jay', ['Jay']),
      _song(3, 'Solo Wen', 'Wen', ['Wen']),
    ]);

    expect(result.directSplits, hasLength(1));
    expect(result.directSplits.single.songId, 1);
    expect(result.directSplits.single.artists, ['Jay', 'Wen']);
    expect(result.possibleSplits, isEmpty);
    expect(result.mergeSuggestions, isEmpty);
  });

  test(
    'analyzeArtistSplits scans already split songs in scanned-library mode',
    () {
      final result = analyzeArtistSplits(
        [
          _song(1, 'Already Split', 'Alpha, Beta', ['Alpha', 'Beta']),
        ],
        existingLibraryScan: false,
        includeScannedSongsInUsage: true,
      );

      expect(result.directSplits, hasLength(1));
      expect(result.directSplits.single.artists, ['Alpha', 'Beta']);
    },
  );

  test(
    'analyzeArtistSplits limits scanned-library results to target songs',
    () {
      final targetSong = _song(1, 'Target Collab', 'Alpha / Beta');
      final outsideSong = _song(2, 'Outside Collab', 'Alpha / Gamma');
      final result = analyzeArtistSplits(
        [targetSong, outsideSong, _song(3, 'Solo Alpha', 'Alpha')],
        analysisSongs: [targetSong],
        existingLibraryScan: false,
        includeScannedSongsInUsage: true,
      );

      expect(result.directSplits, hasLength(1));
      expect(result.directSplits.single.songId, 1);
      expect(result.directSplits.single.artists, ['Alpha', 'Beta']);
      expect(result.possibleSplits, isEmpty);
      expect(result.mergeSuggestions, isEmpty);
    },
  );

  test('analyzeArtistSplits counts scanned target songs once for merges', () {
    final targetSong = _song(1, 'Short Artist', 'Jay', ['Jay']);
    final existingSong = _song(2, 'Canonical Artist', 'Jay Chou', ['Jay Chou']);
    final result = analyzeArtistSplits(
      [targetSong, existingSong],
      analysisSongs: [targetSong],
      usageSongs: [existingSong],
      existingLibraryScan: false,
      includeScannedSongsInUsage: true,
    );

    expect(result.mergeSuggestions, hasLength(1));
    expect(result.mergeSuggestions.single.songId, 1);
    expect(result.mergeSuggestions.single.artists, ['Jay Chou']);
  });
}

LibrarySong _song(
  int id,
  String title,
  String artist, [
  List<String>? artists,
]) {
  return LibrarySong(
    id: id,
    path: '/music/$title.mp3',
    title: title,
    artist: artist,
    artists: artists ?? [artist],
    album: 'Album',
    duration: 180,
    playCount: 0,
    lyricsOffsetMs: 0,
    dateAdded: '2026-05-20T00:00:00.000',
    favorite: false,
    thumbnailPath: '',
  );
}
