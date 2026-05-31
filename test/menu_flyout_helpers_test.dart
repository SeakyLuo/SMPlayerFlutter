import 'package:flutter_test/flutter_test.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/ui/menu_flyout_helpers.dart';

void main() {
  const i18n = SmPlayerI18n(
    locale: 'en-US',
    messages: {
      'common.album': 'Album',
      'common.artist': 'Artist',
      'common.nowPlaying': 'Now Playing',
      'common.playlist': 'Playlist',
      'common.recentAdded': 'Recent Added',
      'nowPlaying.quickPlay': 'Quick Play',
      'random.leastPlayed': 'Least Played',
      'random.localFolder': 'Local Folder',
      'random.mostPlayed': 'Most Played',
      'random.musicLibrary': 'Music Library',
      'random.recentPlayed': 'Recent Played',
    },
  );

  test(
    'shuffle menu artist branch includes unknown artist songs like Electron',
    () {
      List<int>? playedSongIds;
      final items = buildShuffleMenuFlyoutItems(
        i18n: i18n,
        songs: const [],
        librarySongs: const [
          LibrarySong(
            id: 1,
            path: r'C:\Music\unknown.mp3',
            title: 'Unknown',
            artist: '',
            artists: [],
            album: '',
            duration: 120,
            playCount: 0,
            lyricsOffsetMs: 0,
            dateAdded: '2026-05-31T00:00:00',
            favorite: false,
            thumbnailPath: '',
          ),
        ],
        recentSongs: const [],
        playlists: const [],
        folders: const [],
        randomLimit: 100,
        onPlaySongs: (songIds) {
          playedSongIds = songIds;
        },
      );

      items.singleWhere((item) => item.key == 'artist').onPressed!();

      expect(playedSongIds, [1]);
    },
  );

  test('shuffle menu album branch keeps Electron raw album grouping', () {
    List<int>? playedSongIds;
    final items = buildShuffleMenuFlyoutItems(
      i18n: i18n,
      songs: const [],
      librarySongs: const [
        LibrarySong(
          id: 1,
          path: r'C:\Music\blue.mp3',
          title: 'Blue',
          artist: 'Artist',
          artists: ['Artist'],
          album: 'Blue Hour',
          duration: 120,
          playCount: 0,
          lyricsOffsetMs: 0,
          dateAdded: '2026-05-31T00:00:00',
          favorite: false,
          thumbnailPath: '',
        ),
        LibrarySong(
          id: 2,
          path: r'C:\Music\trimmed.mp3',
          title: 'Trimmed',
          artist: 'Artist',
          artists: ['Artist'],
          album: ' Blue Hour ',
          duration: 120,
          playCount: 0,
          lyricsOffsetMs: 0,
          dateAdded: '2026-05-31T00:00:00',
          favorite: false,
          thumbnailPath: '',
        ),
      ],
      recentSongs: const [],
      playlists: const [],
      folders: const [],
      randomLimit: 100,
      onPlaySongs: (songIds) {
        playedSongIds = songIds;
      },
    );

    items.singleWhere((item) => item.key == 'album').onPressed!();

    expect(playedSongIds, hasLength(1));
    expect({1, 2}.contains(playedSongIds!.single), isTrue);
  });
}
