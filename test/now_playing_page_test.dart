import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smplayer_flutter/src/app/app_appearance_model.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
import 'package:smplayer_flutter/src/library/data/library_repository.dart';
import 'package:smplayer_flutter/src/library/ui/command_bar.dart';
import 'package:smplayer_flutter/src/library/ui/default_album_artwork.dart';
import 'package:smplayer_flutter/src/playback/media_control_model.dart';
import 'package:smplayer_flutter/src/playback/media_control_provider.dart';
import 'package:smplayer_flutter/src/playback/now_playing_full_page.dart';
import 'package:smplayer_flutter/src/playback/now_playing_page.dart';
import 'package:smplayer_flutter/src/settings/settings_model.dart'
    show LyricsRequestMode, SettingsSnapshot;

void main() {
  const i18n = SmPlayerI18n(
    locale: 'en-US',
    messages: {
      'albums.addSelectedTo': 'Add To',
      'albums.clearSelection': 'Clear Selection',
      'albums.playSelected': 'Play Selected',
      'albums.reverseSelection': 'Reverse Selection',
      'albums.selectAll': 'Select All',
      'albums.selectedCount': '{count} selected',
      'common.albumUnknown': 'Unknown Album',
      'common.artistUnknown': 'Unknown Artist',
      'common.cancel': 'Cancel',
      'common.multiSelect': 'Multi Select',
      'common.myFavorites': 'My Favorites',
      'common.nowPlaying': 'Now Playing',
      'common.undo': 'Undo',
      'common.close': 'Close',
      'context.addToPlaylist': 'Add To',
      'context.seeAlbum': 'See Album',
      'context.seeAlbumArt': 'See Album Art',
      'context.seeArtist': 'See Artist',
      'context.seeLyrics': 'See Lyrics',
      'context.seeMusicInfo': 'See Music Info',
      'context.view': 'View',
      'context.hideFile': 'Hide File',
      'context.moveToFolder': 'Move To Folder',
      'context.play': 'Play',
      'context.playNext': 'Play Next',
      'context.removeFromList': 'Remove',
      'context.select': 'Select',
      'detail.playAlbum': 'Play Album',
      'detail.playArtist': 'Play Artist',
      'notification.hiddenStorageItem': 'Hidden "{name}"',
      'notification.movedSong': 'Moved "{title}"',
      'notification.songAddedTo': 'Added {title} to {target}',
      'notification.songsAddedTo': 'Added {count} songs to {target}',
      'nowPlaying.clearNowPlaying': 'Clear Now Playing',
      'nowPlaying.clearQueue': 'Clear Queue',
      'nowPlaying.exitImmersiveMode': 'Exit immersive mode',
      'nowPlaying.locateCurrent': 'Locate Current',
      'nowPlaying.loading': 'Loading',
      'nowPlaying.loadingLyrics': 'Loading Lyrics',
      'nowPlaying.lyricsCopy': 'Lyrics are unavailable.',
      'nowPlaying.noActiveTrack': 'No active track',
      'nowPlaying.noActiveTrackCopy': 'Choose music first.',
      'nowPlaying.noLyrics': 'No Lyrics',
      'nowPlaying.noQueueMatch': 'No match for {query}',
      'nowPlaying.playMode': 'Immersive mode',
      'nowPlaying.playlist': 'Playlist',
      'nowPlaying.quickPlay': 'Quick Play',
      'nowPlaying.queueEmpty': 'No songs',
      'nowPlaying.queueEmptyHelp': 'Queue songs first.',
      'nowPlaying.queueSearchHelp': 'Try another search.',
      'nowPlaying.randomPlay': 'Shuffle',
      'nowPlaying.remove': 'Remove',
      'nowPlaying.savePlaylist': 'Save Playlist',
      'playlists.newPlaylist': 'New Playlist',
      'playlists.create': 'Create',
      'playlists.createNew': 'Create New Playlist',
      'playlists.namePlaceholder': 'Playlist name',
      'playlists.nameDuplicate': 'Playlist already exists',
      'playlists.songCount': '{count} songs',
      'player.like': 'Like',
      'player.more': 'More',
      'player.next': 'Next',
      'player.pause': 'Pause',
      'player.play': 'Play',
      'player.playbackLoadFailed': 'Playback failed',
      'player.playbackMode': 'Playback Mode',
      'player.playbackModeList': 'List',
      'player.playbackModeRepeat': 'Repeat',
      'player.playbackModeRepeatOne': 'Repeat One',
      'player.playbackModeShuffle': 'Shuffle',
      'player.previous': 'Previous',
      'player.unlike': 'Unlike',
      'player.volume': 'Volume',
      'sidebar.back': 'Back',
    },
  );

  testWidgets('NowPlayingPage command bar uses Electron Add To submenu', (
    tester,
  ) async {
    await tester.pumpWidget(
      _NowPlayingTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: _FakeNowPlayingRepository(_snapshot),
      ),
    );
    await tester.pumpAndSettle();

    await _openAddToMenu(tester);

    expect(find.text('My Favorites'), findsOneWidget);
    expect(find.text('New Playlist'), findsOneWidget);
    expect(find.text('Mix'), findsOneWidget);
    expect(find.text('Built in'), findsNothing);
  });

  testWidgets('NowPlayingPage hides queue commands when queue is empty', (
    tester,
  ) async {
    final snapshot = _snapshotWithSongs(
      _snapshot,
      _snapshot.songs,
      nowPlaying: const NowPlayingSnapshot(playlistId: 0, songIds: []),
    );

    await tester.pumpWidget(_NowPlayingTestApp(snapshot: snapshot, i18n: i18n));
    await tester.pumpAndSettle();

    expect(find.text('Quick Play'), findsOneWidget);
    expect(find.text('Shuffle'), findsOneWidget);
    expect(find.text('Locate Current'), findsNothing);
    expect(find.text('Add To').hitTestable(), findsNothing);
    expect(find.text('Clear Queue'), findsNothing);
    expect(find.text('Immersive mode'), findsNothing);
    expect(find.text('Multi Select'), findsNothing);
  });

  testWidgets('NowPlayingPage aligns queue rows to the command bar edge', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1012, 760);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _NowPlayingTestApp(snapshot: _snapshot, i18n: i18n),
    );
    await tester.pumpAndSettle();

    final commandBarRight = tester.getRect(find.byType(CommandBar)).right;
    final rowRight =
        tester.getRect(find.byKey(const ValueKey('now-playing-1-0'))).right;

    expect(rowRight, commandBarRight);
  });

  testWidgets('NowPlayingPage keeps queue body empty when queue is empty', (
    tester,
  ) async {
    final snapshot = _snapshotWithSongs(
      _snapshot,
      _snapshot.songs,
      nowPlaying: const NowPlayingSnapshot(playlistId: 0, songIds: []),
    );

    await tester.pumpWidget(_NowPlayingTestApp(snapshot: snapshot, i18n: i18n));
    await tester.pumpAndSettle();

    expect(find.text('No active track'), findsNothing);
    expect(find.text('Choose music first.'), findsNothing);
    expect(find.byKey(const ValueKey('now-playing-1-0')), findsNothing);
  });

  testWidgets(
    'NowPlayingPage queue menu omits Add To in current compact menu',
    (tester) async {
      await tester.pumpWidget(
        _NowPlayingTestApp(snapshot: _snapshot, i18n: i18n),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Blue Song'), buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();

      expect(find.text('Add To'), findsNothing);
      expect(find.text('Mix'), findsNothing);
      expect(find.text('Built in'), findsNothing);
    },
  );

  testWidgets('NowPlayingPage Add To favorites updates repository with undo', (
    tester,
  ) async {
    final repository = _FakeNowPlayingRepository(_snapshot);
    await tester.pumpWidget(
      _NowPlayingTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: repository,
      ),
    );
    await tester.pumpAndSettle();

    await _openAddToMenu(tester);
    await tester.tap(find.text('My Favorites'));
    await tester.pumpAndSettle();

    expect(repository.favoriteSongIds, [1]);
    expect(repository.snapshot.songs.single.favorite, isTrue);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(repository.favoriteSongIds, isEmpty);
    expect(repository.snapshot.songs.single.favorite, isFalse);
  });

  testWidgets('NowPlayingPage Add To playlist writes selected target', (
    tester,
  ) async {
    final repository = _FakeNowPlayingRepository(_snapshot);
    await tester.pumpWidget(
      _NowPlayingTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: repository,
      ),
    );
    await tester.pumpAndSettle();

    await _openAddToMenu(tester);
    await tester.tap(find.text('Mix'));
    await tester.pumpAndSettle();

    expect(repository.playlistSongIds[10], [1]);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets(
    'NowPlayingPage queue menu hides file-management actions like Electron',
    (tester) async {
      final repository = _FakeNowPlayingRepository(_snapshot);
      await tester.pumpWidget(
        _NowPlayingTestApp(
          snapshot: _snapshot,
          i18n: i18n,
          repository: repository,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Blue Song'), buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();

      expect(find.text('Move To Folder'), findsNothing);
      expect(find.text('Hide File'), findsNothing);
    },
  );

  testWidgets('NowPlayingPage filters queue like Electron search', (
    tester,
  ) async {
    await tester.pumpWidget(
      _NowPlayingTestApp(
        snapshot: _searchSnapshot,
        i18n: i18n,
        searchQuery: 'red',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Red Song'), findsOneWidget);
    expect(find.text('Blue Song'), findsNothing);
  });

  testWidgets(
    'NowPlayingFullPage shows immersive lyrics and Electron fallback',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final repository = _FakeNowPlayingRepository(_snapshot);
      final mediaController = MediaControlController();
      mediaController.playTrack(
        const MediaControlTrack(
          id: 1,
          title: 'Blue Song',
          artist: 'Artist A',
          artworkUrl: '',
          isLoading: false,
          favorite: false,
        ),
        durationSeconds: 120,
        queueIndex: 0,
      );
      mediaController.syncPlaybackProgress(12, durationSeconds: 120);

      await tester.pumpWidget(
        _NowPlayingFullTestApp(
          snapshot: _snapshot,
          i18n: i18n,
          repository: repository,
          mediaController: mediaController,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(DefaultAlbumArtwork), findsOneWidget);
      expect(find.text('Blue Song'), findsWidgets);
      expect(find.text('Artist A'), findsOneWidget);
      expect(find.text('Blue Hour'), findsOneWidget);
      expect(find.text('Current lyric', skipOffstage: false), findsOneWidget);

      await tester.tap(find.text('Now Playing').first);
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Now Playing'), findsWidgets);
      expect(find.text('1 songs'), findsOneWidget);
    },
  );

  testWidgets('NowPlayingFullPage shows playback error like Electron', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final repository = _FakeNowPlayingRepository(_snapshot);
    final mediaController = MediaControlController();
    mediaController.playTrack(
      const MediaControlTrack(
        id: 1,
        title: 'Blue Song',
        artist: 'Artist A',
        artworkUrl: '',
        isLoading: false,
        favorite: false,
      ),
      durationSeconds: 120,
      queueIndex: 0,
    );
    mediaController.setPlaybackLoadFailed();

    await tester.pumpWidget(
      _NowPlayingFullTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: repository,
        mediaController: mediaController,
      ),
    );
    await tester.pump();

    expect(find.text('Playback failed'), findsOneWidget);
  });

  testWidgets('NowPlayingFullPage keeps full player surface out of loading', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final repository = _FakeNowPlayingRepository(_snapshot);
    final mediaController = MediaControlController();
    mediaController.playTrack(
      const MediaControlTrack(
        id: 1,
        title: 'Blue Song',
        artist: 'Artist A',
        artworkUrl: '',
        isLoading: false,
        favorite: false,
      ),
      durationSeconds: 0,
      queueIndex: 0,
    );
    mediaController.setTrackLoading(true);

    await tester.pumpWidget(
      _NowPlayingFullTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: repository,
        mediaController: mediaController,
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('MediaControl.ProgressLoading')),
      findsNothing,
    );
    expect(find.text('2:00'), findsOneWidget);
  });

  testWidgets('NowPlayingFullPage favorite button updates current song', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final repository = _FakeNowPlayingRepository(_snapshot);
    final mediaController = MediaControlController();
    mediaController.playTrack(
      const MediaControlTrack(
        id: 1,
        title: 'Blue Song',
        artist: 'Artist A',
        artworkUrl: '',
        isLoading: false,
        favorite: false,
      ),
      durationSeconds: 120,
      queueIndex: 0,
    );

    await tester.pumpWidget(
      _NowPlayingFullTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: repository,
        mediaController: mediaController,
      ),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('Like'));
    await tester.pumpAndSettle();

    expect(repository.favoriteSongIds, [1]);
    expect(repository.snapshot.songs.single.favorite, isTrue);
    expect(mediaController.state.track.favorite, isTrue);
  });

  testWidgets('NowPlayingFullPage queue panel does not pin player bar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final repository = _FakeNowPlayingRepository(_snapshot);
    final mediaController = MediaControlController();
    mediaController.playTrack(
      const MediaControlTrack(
        id: 1,
        title: 'Blue Song',
        artist: 'Artist A',
        artworkUrl: '',
        isLoading: false,
        favorite: false,
      ),
      durationSeconds: 120,
      queueIndex: 0,
    );

    await tester.pumpWidget(
      _NowPlayingFullTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: repository,
        mediaController: mediaController,
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Now Playing').first);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 300));

    expect(_hasPlayerBarOpacity(tester, 0.24), isTrue);
  });

  testWidgets(
    'NowPlayingFullPage empty queue panel omits header like Electron',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final snapshot = _snapshotWithSongs(
        _snapshot,
        _snapshot.songs,
        nowPlaying: const NowPlayingSnapshot(playlistId: 0, songIds: []),
      );
      final repository = _FakeNowPlayingRepository(snapshot);
      final mediaController = MediaControlController();
      mediaController.playTrack(
        const MediaControlTrack(
          id: 1,
          title: 'Blue Song',
          artist: 'Artist A',
          artworkUrl: '',
          isLoading: false,
          favorite: false,
        ),
        durationSeconds: 120,
        queueIndex: null,
      );

      await tester.pumpWidget(
        _NowPlayingFullTestApp(
          snapshot: snapshot,
          i18n: i18n,
          repository: repository,
          mediaController: mediaController,
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Now Playing').first);
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('0 songs'), findsNothing);
      expect(find.byTooltip('Close'), findsNothing);
    },
  );

  testWidgets('NowPlayingFullPage lyric rows do not seek on tap', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final repository = _FakeNowPlayingRepository(_snapshot);
    final mediaController = MediaControlController();
    mediaController.playTrack(
      const MediaControlTrack(
        id: 1,
        title: 'Blue Song',
        artist: 'Artist A',
        artworkUrl: '',
        isLoading: false,
        favorite: false,
      ),
      durationSeconds: 120,
      queueIndex: 0,
    );
    mediaController.syncPlaybackProgress(12, durationSeconds: 120);

    await tester.pumpWidget(
      _NowPlayingFullTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: repository,
        mediaController: mediaController,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('Opening lyric'));
    await tester.pump();

    expect(mediaController.state.progressSeconds, 12);
  });
}

class _NowPlayingTestApp extends StatelessWidget {
  const _NowPlayingTestApp({
    required this.snapshot,
    required this.i18n,
    this.repository,
    this.searchQuery = '',
  });

  final LibraryViewData snapshot;
  final SmPlayerI18n i18n;
  final _FakeNowPlayingRepository? repository;
  final String searchQuery;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        smPlayerI18nProvider.overrideWith((ref) async => i18n),
        if (repository == null)
          libraryViewDataProvider.overrideWith((ref) async => snapshot)
        else
          libraryRepositoryProvider.overrideWithValue(repository!),
      ],
      child: SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp(
          theme: buildSmPlayerTheme(const SettingsSnapshot.defaults()),
          home: Scaffold(body: NowPlayingPage(searchQuery: searchQuery)),
        ),
      ),
    );
  }
}

class _NowPlayingFullTestApp extends StatelessWidget {
  const _NowPlayingFullTestApp({
    required this.snapshot,
    required this.i18n,
    required this.repository,
    required this.mediaController,
  });

  final LibraryViewData snapshot;
  final SmPlayerI18n i18n;
  final _FakeNowPlayingRepository repository;
  final MediaControlController mediaController;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        smPlayerI18nProvider.overrideWith((ref) async => i18n),
        libraryRepositoryProvider.overrideWithValue(repository),
        mediaControlControllerProvider.overrideWith((ref) => mediaController),
      ],
      child: SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp(
          theme: buildSmPlayerTheme(const SettingsSnapshot.defaults()),
          home: const Scaffold(body: NowPlayingFullPage()),
        ),
      ),
    );
  }
}

class _FakeNowPlayingRepository extends LibraryRepository {
  _FakeNowPlayingRepository(this.snapshot);

  LibraryViewData snapshot;
  final favoriteSongIds = <int>[];
  final playlistSongIds = <int, List<int>>{};
  int? hiddenSongId;
  int? movedSongId;
  String? movedFolderPath;

  @override
  Future<LibraryViewData> getLibraryViewData() async => snapshot;

  @override
  Future<String?> getPreferenceLevel(String type, String itemId) async {
    return null;
  }

  @override
  Future<void> setSongsFavorite(List<int> songIds, bool favorite) async {
    if (favorite) {
      favoriteSongIds.addAll(
        songIds.where((songId) => !favoriteSongIds.contains(songId)),
      );
    } else {
      favoriteSongIds.removeWhere(songIds.contains);
    }
    snapshot = _snapshotWithSongs(
      snapshot,
      snapshot.songs
          .map(
            (song) =>
                songIds.contains(song.id)
                    ? _songWithFavorite(song, favorite)
                    : song,
          )
          .toList(),
    );
  }

  @override
  Future<void> addSongsToPlaylist(int playlistId, List<int> songIds) async {
    playlistSongIds[playlistId] = [
      ...(playlistSongIds[playlistId] ?? const <int>[]),
      ...songIds,
    ];
  }

  @override
  Future<void> removeSongsFromPlaylist(
    int playlistId,
    List<int> songIds,
  ) async {
    playlistSongIds[playlistId] = [
      for (final songId in playlistSongIds[playlistId] ?? const <int>[])
        if (!songIds.contains(songId)) songId,
    ];
  }

  @override
  Future<void> hideSong(int songId) async {
    hiddenSongId = songId;
  }

  @override
  Future<void> unhideSong(int songId) async {
    hiddenSongId = null;
  }

  @override
  Future<LocalItemsMoveResult> moveSongToFolder(
    int songId,
    String folderPath, {
    LocalMoveConflictResolver? resolveConflict,
  }) async {
    movedSongId = songId;
    movedFolderPath = folderPath;
    return LocalItemsMoveResult(
      songs: [
        LocalSongMove(
          id: songId,
          oldPath: r'C:\Music\blue.mp3',
          newPath: r'C:\Target\blue.mp3',
        ),
      ],
      folders: const [],
    );
  }

  @override
  Future<void> undoMoveLocalItems(LocalItemsMoveResult result) async {
    movedSongId = null;
    movedFolderPath = null;
  }

  @override
  Future<void> replaceNowPlaying(List<int> songIds) async {
    snapshot = _snapshotWithSongs(
      snapshot,
      snapshot.songs,
      nowPlaying: NowPlayingSnapshot(
        playlistId: snapshot.nowPlaying.playlistId,
        songIds: songIds,
      ),
    );
  }

  @override
  Future<LyricsSnapshot> getSongLyrics(
    int songId, {
    LyricsRequestMode mode = LyricsRequestMode.auto,
  }) async {
    return const LyricsSnapshot(
      source: LyricsSource.musicFile,
      isSynced: true,
      rawText: '[00:00.00]Opening lyric\n[00:10.00]Current lyric',
      lines: [
        LyricsLine(id: 1, timestampMs: 0, text: 'Opening lyric'),
        LyricsLine(id: 2, timestampMs: 10000, text: 'Current lyric'),
      ],
    );
  }
}

const _snapshot = LibraryViewData(
  songs: [
    LibrarySong(
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
  ],
  recentSongs: [],
  recentPlaylists: [],
  recentAlbums: [],
  recentArtists: [],
  recentSearches: [],
  playlists: [
    LibraryPlaylist(
      id: 3,
      name: 'Built in',
      priority: 0,
      songCount: 0,
      songIds: [],
      sortCriterion: PlaylistSortCriterion.title,
      isBuiltIn: true,
    ),
    LibraryPlaylist(
      id: 10,
      name: 'Mix',
      priority: 1,
      songCount: 0,
      songIds: [],
      sortCriterion: PlaylistSortCriterion.title,
      isBuiltIn: false,
    ),
  ],
  folders: [
    LibraryFolder(id: 20, path: r'C:\Target', parentId: 0, criterion: 0),
  ],
  favoritePlaylistId: 3,
  nowPlaying: NowPlayingSnapshot(playlistId: 0, songIds: [1]),
  hasLibrary: true,
  sortCriterion: MusicLibrarySortCriterion.title,
  albumsSort: AlbumSortCriterion.defaultSort,
  showCount: true,
  hideMultiSelectCommandBarAfterOperation: true,
  databasePath: '',
);

final _searchSnapshot = _snapshotWithSongs(_snapshot, [
  ..._snapshot.songs,
  const LibrarySong(
    id: 2,
    path: r'C:\Music\red.mp3',
    title: 'Red Song',
    artist: 'Artist B',
    artists: ['Artist B'],
    album: 'Red Hour',
    duration: 130,
    playCount: 0,
    lyricsOffsetMs: 0,
    dateAdded: '2026-05-20T00:00:00',
    favorite: false,
    thumbnailPath: '',
  ),
], nowPlaying: const NowPlayingSnapshot(playlistId: 0, songIds: [1, 2]));

LibraryViewData _snapshotWithSongs(
  LibraryViewData snapshot,
  List<LibrarySong> songs, {
  NowPlayingSnapshot? nowPlaying,
}) {
  return LibraryViewData(
    songs: songs,
    recentSongs: snapshot.recentSongs,
    recentPlaylists: snapshot.recentPlaylists,
    recentAlbums: snapshot.recentAlbums,
    recentArtists: snapshot.recentArtists,
    recentSearches: snapshot.recentSearches,
    playlists: snapshot.playlists,
    folders: snapshot.folders,
    favoritePlaylistId: snapshot.favoritePlaylistId,
    nowPlaying: nowPlaying ?? snapshot.nowPlaying,
    hasLibrary: snapshot.hasLibrary,
    sortCriterion: snapshot.sortCriterion,
    albumsSort: snapshot.albumsSort,
    showCount: snapshot.showCount,
    hideMultiSelectCommandBarAfterOperation:
        snapshot.hideMultiSelectCommandBarAfterOperation,
    rootPath: snapshot.rootPath,
    databasePath: snapshot.databasePath,
  );
}

LibrarySong _songWithFavorite(LibrarySong song, bool favorite) {
  return LibrarySong(
    id: song.id,
    path: song.path,
    title: song.title,
    artist: song.artist,
    artists: song.artists,
    album: song.album,
    duration: song.duration,
    playCount: song.playCount,
    lyricsOffsetMs: song.lyricsOffsetMs,
    dateAdded: song.dateAdded,
    favorite: favorite,
    thumbnailPath: song.thumbnailPath,
  );
}

Future<void> _openAddToMenu(WidgetTester tester) async {
  final inlineAddTo = find.text('Add To');
  if (inlineAddTo.evaluate().isNotEmpty) {
    await tester.tap(inlineAddTo.first);
    await tester.pumpAndSettle();
    return;
  }

  await tester.tap(find.byTooltip('More').first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Add To').first);
  await tester.pumpAndSettle();
}

bool _hasPlayerBarOpacity(WidgetTester tester, double opacity) {
  return tester
      .widgetList<AnimatedOpacity>(find.byType(AnimatedOpacity))
      .any((widget) => widget.opacity == opacity);
}
