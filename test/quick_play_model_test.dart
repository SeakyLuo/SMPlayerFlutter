import 'package:flutter_test/flutter_test.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/playback/quick_play_model.dart';
import 'package:smplayer_flutter/src/settings/settings_model.dart';

void main() {
  test('quickPlaySongIds removes do-not-appear songs like Electron', () {
    final blocked = _song(1, 'Blocked', favorite: true);
    final allowed = _song(2, 'Allowed');

    final result = quickPlaySongIds(
      songs: [blocked, allowed],
      playlists: const [],
      folders: const [],
      preferences: PreferenceSettingsSnapshot.defaults().copyWith(
        songs: [
          const PreferenceItemSnapshot(
            id: 1,
            type: PreferenceEntityType.song,
            itemId: '1',
            name: 'Blocked',
            tooltip: 'Blocked',
            isEnabled: true,
            level: PreferenceLevel.doNotAppear,
            isValid: true,
            canRemove: true,
          ),
        ],
      ),
    );

    expect(result, isNot(contains(1)));
    expect(result, contains(2));
  });

  test(
    'quickPlaySongIds ignores folder preferences that are not folder ids',
    () {
      final song = _songInPath(1, '/music/Legacy/Song.mp3');

      final result = quickPlaySongIds(
        songs: [song],
        playlists: const [],
        folders: const [
          LibraryFolder(
            id: 10,
            path: '/music/Folder',
            parentId: 0,
            criterion: 0,
          ),
        ],
        preferences: PreferenceSettingsSnapshot.defaults().copyWith(
          folders: const [
            PreferenceItemSnapshot(
              id: 1,
              type: PreferenceEntityType.folder,
              itemId: '/music/Legacy',
              name: 'Legacy',
              tooltip: 'Legacy',
              isEnabled: true,
              level: PreferenceLevel.veryHigh,
              isValid: true,
              canRemove: true,
            ),
          ],
        ),
        randomLimit: 0,
      );

      expect(result, isEmpty);
    },
  );
}

LibrarySong _song(int id, String title, {bool favorite = false}) {
  return LibrarySong(
    id: id,
    path: '/music/$title.mp3',
    title: title,
    artist: 'Artist',
    artists: const ['Artist'],
    album: 'Album',
    duration: 180,
    playCount: id,
    lyricsOffsetMs: 0,
    dateAdded: '2026-05-20T00:00:00',
    favorite: favorite,
    thumbnailPath: '',
  );
}

LibrarySong _songInPath(int id, String path) {
  return LibrarySong(
    id: id,
    path: path,
    title: 'Song $id',
    artist: 'Artist',
    artists: const ['Artist'],
    album: 'Album',
    duration: 180,
    playCount: id,
    lyricsOffsetMs: 0,
    dateAdded: '2026-05-20T00:00:00',
    favorite: false,
    thumbnailPath: '',
  );
}
