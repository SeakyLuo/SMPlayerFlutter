import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/ui/headered_playlist_control.dart';
import 'package:smplayer_flutter/src/platform/desktop_features.dart';
import 'package:window_manager/window_manager.dart';

Future<void> main() async {
  debugPrint('SMPLAYER_HEADERED_VERIFY_TARGET');
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  await windowManager.setTitle('SMPlayer Headered Verify');
  const verifyWidth = int.fromEnvironment(
    'SMPLAYER_HEADERED_VERIFY_WIDTH',
    defaultValue: 1200,
  );
  const verifyHeight = int.fromEnvironment(
    'SMPLAYER_HEADERED_VERIFY_HEIGHT',
    defaultValue: 800,
  );
  await windowManager.setSize(
    const Size(verifyWidth + 0.0, verifyHeight + 0.0),
  );
  await windowManager.center();
  await windowManager.show();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(dismissNativeSplash());
  });
  runApp(const _VerifyApp());
}

class _VerifyApp extends StatelessWidget {
  const _VerifyApp();

  @override
  Widget build(BuildContext context) {
    const dark = bool.fromEnvironment('SMPLAYER_HEADERED_VERIFY_DARK');
    return ProviderScope(
      overrides: [smPlayerI18nProvider.overrideWith((ref) async => _i18n)],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        home: Scaffold(
          body: SmPlayerI18nScope(
            i18n: _i18n,
            child: HeaderedPlaylistControl(
              type: HeaderedPlaylistType.album,
              title: 'Blue Hour',
              songs: _songs,
              selectedTrackId: null,
              playlists: _playlists,
              favoritePlaylistId: 3,
              artworkUrl: '',
              showAlbum: true,
              canEditArtwork: true,
              canSetPreferred: true,
              onPlayTrack: (_, _) {},
              onAddSongToPlaylist: (_, _) {},
              onPlayNext: (_) {},
              onEditArtwork: () {},
            ),
          ),
        ),
      ),
    );
  }
}

const _i18n = SmPlayerI18n(
  locale: 'en-US',
  messages: {
    'albums.editArtwork': 'Edit Artwork',
    'albums.multiSelect': 'Multi Select',
    'albums.sort.reverse': 'Reverse',
    'common.album': 'Album',
    'common.albumUnknown': 'Unknown Album',
    'common.artist': 'Artist',
    'common.artistSeparator': ' / ',
    'common.duration': 'Duration',
    'common.favorite': 'Favorite',
    'common.myFavorites': 'My Favorites',
    'common.nowPlaying': 'Now Playing',
    'common.sort': 'Sort',
    'context.addToPlaylist': 'Add To',
    'context.playNext': 'Play Next',
    'context.removeFromList': 'Remove From List',
    'headeredPlaylist.songArtist': 'Song/Artist',
    'headeredPlaylist.songsPrefix': 'Songs: ',
    'nowPlaying.randomPlay': 'Shuffle',
    'player.more': 'More',
    'playlists.newPlaylist': 'New Playlist',
    'settings.preferenceSettings': 'Preference Settings',
    'table.album': 'Album',
    'table.artist': 'Artist',
    'table.dateAdded': 'Date Added',
    'table.duration': 'Duration',
    'table.playCount': 'Play Count',
    'table.title': 'Title',
  },
);

const _playlists = [
  LibraryPlaylist(
    id: 10,
    name: 'Mix',
    priority: 1,
    songCount: 0,
    songIds: [],
    sortCriterion: PlaylistSortCriterion.title,
    isBuiltIn: false,
  ),
];

final _songs = [
  const LibrarySong(
    id: 1,
    path: r'C:\Music\blue.mp3',
    title: 'Blue Song',
    artist: 'Artist A',
    artists: ['Artist A'],
    album: 'Blue Hour',
    duration: 120,
    playCount: 0,
    lyricsOffsetMs: 0,
    dateAdded: '2026-05-20T00:00:00',
    favorite: false,
    thumbnailPath: '',
  ),
  for (var index = 0; index < 22; index += 1)
    LibrarySong(
      id: 100 + index,
      path: r'C:\Music\blue-extra.mp3',
      title: 'Blue Extra $index',
      artist: 'Artist A',
      artists: const ['Artist A'],
      album: 'Blue Hour',
      duration: 120,
      playCount: 0,
      lyricsOffsetMs: 0,
      dateAdded: '2026-05-20T00:00:00',
      favorite: false,
      thumbnailPath: '',
    ),
];
