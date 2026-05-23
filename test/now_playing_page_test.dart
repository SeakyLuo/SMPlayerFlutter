import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
import 'package:smplayer_flutter/src/library/data/library_repository.dart';
import 'package:smplayer_flutter/src/playback/now_playing_page.dart';

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
      'context.addToPlaylist': 'Add To',
      'context.hideFile': 'Hide File',
      'context.moveToFolder': 'Move To Folder',
      'context.play': 'Play',
      'context.playNext': 'Play Next',
      'context.removeFromList': 'Remove',
      'context.select': 'Select',
      'notification.hiddenStorageItem': 'Hidden "{name}"',
      'notification.movedSong': 'Moved "{title}"',
      'notification.songAddedTo': 'Added {title} to {target}',
      'notification.songsAddedTo': 'Added {count} songs to {target}',
      'nowPlaying.clearQueue': 'Clear Queue',
      'nowPlaying.locateCurrent': 'Locate Current',
      'nowPlaying.noQueueMatch': 'No match for {query}',
      'nowPlaying.playMode': 'Immersive mode',
      'nowPlaying.quickPlay': 'Quick Play',
      'nowPlaying.queueEmpty': 'No songs',
      'nowPlaying.queueEmptyHelp': 'Queue songs first.',
      'nowPlaying.queueSearchHelp': 'Try another search.',
      'nowPlaying.randomPlay': 'Shuffle',
      'nowPlaying.remove': 'Remove',
      'playlists.newPlaylist': 'New Playlist',
      'player.more': 'More',
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

  testWidgets('NowPlayingPage paints page surface when queue is empty', (
    tester,
  ) async {
    final snapshot = _snapshotWithSongs(
      _snapshot,
      _snapshot.songs,
      nowPlaying: const NowPlayingSnapshot(playlistId: 0, songIds: []),
    );

    await tester.pumpWidget(_NowPlayingTestApp(snapshot: snapshot, i18n: i18n));
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is DecoratedBox &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).color ==
                const Color(0xfffafcff),
      ),
      findsOneWidget,
    );
  });

  testWidgets('NowPlayingPage queue menu uses Electron Add To submenu', (
    tester,
  ) async {
    await tester.pumpWidget(
      _NowPlayingTestApp(snapshot: _snapshot, i18n: i18n),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Blue Song'), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();

    expect(find.text('Add To'), findsAtLeastNWidgets(1));
    expect(find.text('Mix'), findsNothing);
    expect(find.text('Built in'), findsNothing);

    await tester.tap(find.text('Add To').last);
    await tester.pumpAndSettle();

    expect(find.text('My Favorites'), findsOneWidget);
    expect(find.text('New Playlist'), findsOneWidget);
    expect(find.text('Mix'), findsOneWidget);
    expect(find.text('Built in'), findsNothing);
  });

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
          home: Scaffold(body: NowPlayingPage(searchQuery: searchQuery)),
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
