import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
import 'package:smplayer_flutter/src/library/data/library_repository.dart';
import 'package:smplayer_flutter/src/library/ui/album_detail_page.dart';

void main() {
  const i18n = SmPlayerI18n(
    locale: 'en-US',
    messages: {
      'albums.clearSelection': 'Clear Selection',
      'albums.editArtwork': 'Edit Artwork',
      'albums.multiSelect': 'Multi Select',
      'albums.playSelected': 'Play Selected',
      'albums.reverseSelection': 'Reverse Selection',
      'albums.selectAll': 'Select All',
      'albums.selectedCount': '{count} selected',
      'albums.sort.reverse': 'Reverse',
      'collection.albumNotFound': 'Album Not Found',
      'collection.albumNotFoundCopy':
          'Try selecting another album from your library.',
      'common.album': 'Album',
      'common.albumUnknown': 'Unknown Album',
      'common.artist': 'Artist',
      'common.artistUnknown': 'Unknown Artist',
      'common.cancel': 'Cancel',
      'common.clear': 'Clear',
      'common.close': 'Close',
      'common.duration': 'Duration',
      'common.favorite': 'Favorite',
      'common.myFavorites': 'My Favorites',
      'common.name': 'Name',
      'common.nowPlaying': 'Now Playing',
      'common.reset': 'Reset',
      'common.sort': 'Sort',
      'common.yes': 'Yes',
      'context.addToPlaylist': 'Add To',
      'context.play': 'Play',
      'context.playNext': 'Play Next',
      'context.removeFromList': 'Remove From List',
      'headeredPlaylist.songArtist': 'Song/Artist',
      'headeredPlaylist.songsPrefix': 'Songs: ',
      'nowPlaying.randomPlay': 'Shuffle',
      'player.more': 'More',
      'playlists.delete': 'Delete',
      'playlists.newPlaylist': 'New Playlist',
      'playlists.removeSelected': 'Remove Selected',
      'preferences.level.dislike': 'Dislike',
      'preferences.level.do-not-appear': 'Do Not Appear',
      'preferences.level.high': 'High',
      'preferences.level.higher': 'Higher',
      'preferences.level.normal': 'Normal',
      'preferences.level.very-high': 'Very High',
      'settings.preferenceSettings': 'Preference Settings',
      'settings.save': 'Save',
      'song.albumArt': 'Album Art',
      'song.albumArtDeleted': 'Album art deleted',
      'song.albumArtReset': 'Album art has been reset.',
      'song.albumArtSaved': 'New album art has been saved!',
      'song.changeArtwork': 'Change',
      'song.noAlbumArt': 'No Album Art',
      'song.processingRequest': 'Your previous request is still processing.',
      'song.removeAlbumArt': 'Remove album art from "{title}"?',
      'song.updateFailed': 'Update failed.',
      'table.album': 'Album',
      'table.artist': 'Artist',
      'table.dateAdded': 'Date Added',
      'table.duration': 'Duration',
      'table.playCount': 'Play Count',
      'table.title': 'Title',
    },
  );

  testWidgets('AlbumDetailPage Add To matches Electron targets', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final repository = _FakeLibraryRepository();

    await tester.pumpWidget(
      _AlbumDetailTestApp(repository: repository, i18n: i18n),
    );
    await tester.pumpAndSettle();

    expect(find.text('Play'), findsNothing);
    expect(find.text('Preference Settings'), findsOneWidget);
    expect(find.text('Edit Artwork'), findsOneWidget);
    await tester.tap(find.byTooltip('Add To'));
    await tester.pumpAndSettle();

    expect(find.text('Now Playing'), findsOneWidget);
    expect(find.text('My Favorites'), findsOneWidget);
    expect(find.text('New Playlist'), findsOneWidget);
    expect(find.text('Mix'), findsOneWidget);

    await tester.tap(find.text('Now Playing'));
    await tester.pumpAndSettle();

    expect(repository.replacedNowPlaying, [9, 1]);

    await tester.tap(find.byTooltip('Add To'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('My Favorites'));
    await tester.pumpAndSettle();

    expect(repository.favoriteSongIds, [1]);
    expect(repository.favoriteValue, isTrue);
  });

  testWidgets(
    'AlbumDetailPage wires Electron preference and artwork commands',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 800);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repository = _FakeLibraryRepository();

      await tester.pumpWidget(
        _AlbumDetailTestApp(repository: repository, i18n: i18n),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Preference Settings'));
      await tester.pumpAndSettle();

      expect(find.text('Do Not Appear'), findsOneWidget);
      expect(find.text('Dislike'), findsOneWidget);
      expect(find.text('Normal'), findsOneWidget);
      expect(find.text('High'), findsOneWidget);
      expect(find.text('Higher'), findsOneWidget);
      expect(find.text('Very High'), findsOneWidget);

      await tester.tap(find.text('High'));
      await tester.pump();

      expect(repository.preferenceType, 'album');
      expect(repository.preferenceItemId, 'Blue Hour');
      expect(repository.preferenceName, 'Blue Hour');
      expect(repository.preferenceLevel, 'high');

      await tester.tap(find.text('Edit Artwork'));
      await tester.pumpAndSettle();

      expect(find.text('Album Art'), findsWidgets);
      expect(find.text('Change'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
      expect(find.text('Reset'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      expect(find.text('No Album Art'), findsOneWidget);
    },
  );

  testWidgets('AlbumDetailPage records play only for Electron shuffle', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repository = _FakeLibraryRepository();

    await tester.pumpWidget(
      _AlbumDetailTestApp(repository: repository, i18n: i18n),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Blue Song'));
    await tester.pumpAndSettle();

    expect(repository.replacedNowPlaying, [1]);
    expect(repository.recordedAlbums, isEmpty);

    await tester.tap(find.text('Shuffle'));
    await tester.pumpAndSettle();

    expect(repository.recordedAlbums, ['Blue Hour']);
  });

  testWidgets('AlbumDetailPage renders Electron not found state', (
    tester,
  ) async {
    await tester.pumpWidget(
      const _AlbumDetailTestApp(albumName: 'Missing', i18n: i18n),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Album Not Found'), findsOneWidget);
    expect(find.textContaining('Try selecting another album'), findsOneWidget);
  });

  testWidgets('AlbumDetailPage matches Electron raw album route', (
    tester,
  ) async {
    await tester.pumpWidget(
      _AlbumDetailTestApp(albumName: i18n.t('common.albumUnknown'), i18n: i18n),
    );
    await tester.pumpAndSettle();

    expect(find.text('Unknown Album Song'), findsNothing);
    expect(find.textContaining('Album Not Found'), findsOneWidget);
  });
}

class _AlbumDetailTestApp extends StatelessWidget {
  const _AlbumDetailTestApp({
    required this.i18n,
    this.repository,
    this.albumName = 'Blue Hour',
  });

  final SmPlayerI18n i18n;
  final LibraryRepository? repository;
  final String albumName;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        smPlayerI18nProvider.overrideWith((ref) async => i18n),
        musicLibrarySnapshotProvider.overrideWith((ref) async => _snapshot),
        if (repository != null)
          libraryRepositoryProvider.overrideWithValue(repository!),
      ],
      child: MaterialApp(
        home: Scaffold(body: AlbumDetailPage(albumName: albumName)),
      ),
    );
  }
}

class _FakeLibraryRepository extends LibraryRepository {
  List<int> replacedNowPlaying = [];
  List<int> favoriteSongIds = [];
  List<String> recordedAlbums = [];
  bool? favoriteValue;
  String? preferenceType;
  String? preferenceItemId;
  String? preferenceName;
  String? preferenceLevel;

  @override
  Future<void> replaceNowPlaying(List<int> songIds) async {
    replacedNowPlaying = songIds.toList();
  }

  @override
  Future<void> setSongsFavorite(List<int> songIds, bool favorite) async {
    favoriteSongIds = songIds.toList();
    favoriteValue = favorite;
  }

  @override
  Future<void> recordAlbumPlayed(String albumName) async {
    recordedAlbums.add(albumName);
  }

  @override
  Future<void> addPreferenceItem(
    String type,
    String itemId,
    String name,
    String level,
  ) async {
    preferenceType = type;
    preferenceItemId = itemId;
    preferenceName = name;
    preferenceLevel = level;
  }
}

const _snapshot = MusicLibrarySnapshot(
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
    LibrarySong(
      id: 9,
      path: r'C:\Music\queued.mp3',
      title: 'Queued Song',
      artist: 'Artist Q',
      artists: ['Artist Q'],
      album: 'Queue',
      duration: 90,
      playCount: 0,
      lyricsOffsetMs: 0,
      dateAdded: '2026-05-20T00:00:00',
      favorite: false,
      thumbnailPath: '',
    ),
    LibrarySong(
      id: 11,
      path: r'C:\Music\unknown.mp3',
      title: 'Unknown Album Song',
      artist: 'Artist U',
      artists: ['Artist U'],
      album: '',
      duration: 90,
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
      id: 10,
      name: 'Mix',
      priority: 1,
      songCount: 0,
      songIds: [],
      sortCriterion: PlaylistSortCriterion.title,
      isBuiltIn: false,
    ),
  ],
  favoritePlaylistId: 3,
  nowPlaying: NowPlayingSnapshot(playlistId: 0, songIds: [9]),
  hasLibrary: true,
  sortCriterion: MusicLibrarySortCriterion.title,
  albumsSort: AlbumSortCriterion.defaultSort,
  showCount: true,
  hideMultiSelectCommandBarAfterOperation: true,
  databasePath: '',
);
