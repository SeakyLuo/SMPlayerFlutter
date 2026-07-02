import 'package:flutter_test/flutter_test.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/ui/headered_playlist_model.dart';

void main() {
  test('sortSongs title mode follows Electron localeCompare', () {
    final sorted = sortSongs([
      _song(id: 1, title: 'Song 2'),
      _song(id: 2, title: 'Song 10'),
      _song(id: 3, title: 'Song 1'),
    ], PlaylistSortCriterion.title);

    expect(sorted.map((song) => song.id), [3, 2, 1]);
  });
}

LibrarySong _song({required int id, required String title}) {
  return LibrarySong(
    id: id,
    path: r'C:\Music\song.mp3',
    title: title,
    artist: 'Artist',
    artists: const ['Artist'],
    album: 'Album',
    duration: 120,
    playCount: 0,
    lyricsOffsetMs: 0,
    dateAdded: '2026-05-20T00:00:00',
    favorite: false,
    thumbnailPath: '',
  );
}
