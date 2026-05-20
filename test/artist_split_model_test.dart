import 'package:flutter_test/flutter_test.dart';
import 'package:smplayer_flutter/src/library/data/artist_split_model.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';

void main() {
  test('analyzeArtistSplits promotes known artists to direct splits', () {
    final result = analyzeArtistSplits([
      _song(1, 'Duet', 'Alpha / Beta'),
      _song(2, 'Solo Alpha', 'Alpha'),
      _song(3, 'Solo Beta', 'Beta'),
    ]);

    expect(result.directSplits, hasLength(1));
    expect(result.directSplits.single.title, 'Duet');
    expect(result.directSplits.single.artists, ['Alpha', 'Beta']);
    expect(result.possibleSplits, isEmpty);
  });

  test('analyzeArtistSplits keeps unknown artists as possible splits', () {
    final result = analyzeArtistSplits([
      _song(1, 'Collab', 'Alpha feat. Gamma'),
      _song(2, 'Solo Alpha', 'Alpha'),
    ]);

    expect(result.directSplits, isEmpty);
    expect(result.possibleSplits, hasLength(1));
    expect(result.possibleSplits.single.artists, ['Alpha', 'Gamma']);
  });

  test('analyzeArtistSplits skips songs already split in artist table', () {
    final result = analyzeArtistSplits([
      _song(1, 'Already Split', 'Alpha, Beta', ['Alpha', 'Beta']),
      _song(2, 'Solo Alpha', 'Alpha'),
      _song(3, 'Solo Beta', 'Beta'),
    ]);

    expect(result.hasSuggestions, isFalse);
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
