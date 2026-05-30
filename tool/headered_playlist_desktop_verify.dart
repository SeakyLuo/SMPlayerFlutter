import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/ui/default_album_artwork.dart';
import 'package:smplayer_flutter/src/library/ui/headered_playlist_control.dart';
import 'package:window_manager/window_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  final width = double.parse(Platform.environment['HEADERED_VERIFY_WIDTH']!);
  final height = double.parse(Platform.environment['HEADERED_VERIFY_HEIGHT']!);
  final verifyCase = Platform.environment['HEADERED_VERIFY_CASE']!;
  await windowManager.setTitle('SMPlayer Headered Verify');
  await windowManager.setSize(Size(width, height));
  await windowManager.center();
  await windowManager.show();
  runApp(_VerifyApp(width: width, verifyCase: verifyCase));
}

class _VerifyApp extends StatefulWidget {
  const _VerifyApp({required this.width, required this.verifyCase});

  final double width;
  final String verifyCase;

  @override
  State<_VerifyApp> createState() => _VerifyAppState();
}

class _VerifyAppState extends State<_VerifyApp> {
  final GlobalKey _boundaryKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_captureAfterLayout());
    });
  }

  Future<void> _captureAfterLayout() async {
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    final boundary =
        _boundaryKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File(
      '${Directory.systemTemp.path}/flutter_headered_verify_${widget.verifyCase}_${widget.width.round()}.png',
    );
    await file.writeAsBytes(data!.buffer.asUint8List());
    debugPrint('Headered verify screenshot: ${file.path}');
  }

  @override
  Widget build(BuildContext context) {
    final sample = _sampleFor(widget.verifyCase);
    return ProviderScope(
      overrides: [smPlayerI18nProvider.overrideWith((ref) async => _i18n)],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          extensions: const [DefaultAlbumArtworkThemeColors.light],
        ),
        home: Scaffold(
          body: RepaintBoundary(
            key: _boundaryKey,
            child: SmPlayerI18nScope(
              i18n: _i18n,
              child: HeaderedPlaylistControl(
                type: sample.type,
                title: sample.title,
                headerSongs: sample.headerSongs,
                songs: sample.songs,
                selectedTrackId: null,
                playlists: _playlists,
                favoritePlaylistId: 3,
                artworkUrl: '',
                removable: sample.removable,
                showAlbum: sample.showAlbum,
                canRename: sample.canRename,
                canDelete: sample.canDelete,
                canClear: sample.canClear,
                canEditArtwork: sample.canEditArtwork,
                canSetPreferred: sample.canSetPreferred,
                sortCriterion: PlaylistSortCriterion.title,
                preferenceType: sample.preferenceType,
                preferenceItemId: sample.preferenceItemId,
                onPlayTrack: (_, _) {},
                onAddSongToPlaylist: (_, _) {},
                onPlayNext: (_) {},
                onRemoveSongs: (_) {},
                onRename: (_) {},
                onDelete: () {},
                onClear: () {},
                onEditArtwork: () {},
                onSetPreferred: (_) async {},
              ),
            ),
          ),
        ),
      ),
    );
  }
}

_HeaderedVerifySample _sampleFor(String verifyCase) {
  switch (verifyCase) {
    case 'album':
      return _HeaderedVerifySample(
        type: HeaderedPlaylistType.album,
        title: 'Blue Hour',
        songs: _songs,
        showAlbum: false,
        canEditArtwork: true,
        canSetPreferred: true,
        preferenceType: 'album',
        preferenceItemId: 'Blue Hour',
      );
    case 'playlist':
      return _HeaderedVerifySample(
        type: HeaderedPlaylistType.playlist,
        title: 'Mix',
        headerSongs: _playlistSongs,
        songs: _playlistSongs,
        removable: true,
        showAlbum: true,
        canRename: true,
        canDelete: true,
        canClear: true,
        canSetPreferred: true,
        preferenceType: 'playlist',
        preferenceItemId: '10',
      );
  }
  throw UnimplementedError(verifyCase);
}

class _HeaderedVerifySample {
  const _HeaderedVerifySample({
    required this.type,
    required this.title,
    required this.songs,
    required this.showAlbum,
    required this.canSetPreferred,
    required this.preferenceType,
    required this.preferenceItemId,
    this.headerSongs,
    this.removable = false,
    this.canRename = false,
    this.canDelete = false,
    this.canClear = false,
    this.canEditArtwork = false,
  });

  final HeaderedPlaylistType type;
  final String title;
  final List<LibrarySong>? headerSongs;
  final List<LibrarySong> songs;
  final bool removable;
  final bool showAlbum;
  final bool canRename;
  final bool canDelete;
  final bool canClear;
  final bool canEditArtwork;
  final bool canSetPreferred;
  final String preferenceType;
  final String preferenceItemId;
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
    'common.clear': 'Clear',
    'common.delete': 'Delete',
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
    'playlists.delete': 'Delete',
    'playlists.newPlaylist': 'New Playlist',
    'playlists.rename': 'Rename',
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

final _playlistSongs = [
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
  const LibrarySong(
    id: 2,
    path: r'C:\Music\green.mp3',
    title: 'Green Song',
    artist: 'Artist B',
    artists: ['Artist B'],
    album: 'Green Hour',
    duration: 90,
    playCount: 0,
    lyricsOffsetMs: 0,
    dateAdded: '2026-05-20T00:00:00',
    favorite: false,
    thumbnailPath: '',
  ),
];
