import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smplayer_flutter/src/app/undoable_notification.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
import 'package:smplayer_flutter/src/library/data/library_repository.dart';
import 'package:smplayer_flutter/src/library/ui/library_page_actions.dart';

void main() {
  testWidgets('favorite playlist add-to uses favorite mutation with undo', (
    tester,
  ) async {
    final repository = _FavoriteAddRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          libraryRepositoryProvider.overrideWithValue(repository),
          libraryContentDataProvider.overrideWith((ref) async => _snapshot),
        ],
        child: SmPlayerI18nScope(
          i18n: _i18n,
          child: MaterialApp(
            theme: ThemeData(extensions: [AppNotificationThemeColors.light]),
            home: Consumer(
              builder: (context, ref, _) {
                return Scaffold(
                  body: TextButton(
                    onPressed: () {
                      addSongsToPlaylistWithUndo(
                        context: context,
                        ref: ref,
                        i18n: _i18n,
                        playlistId: _snapshot.favoritePlaylistId,
                        songIds: const [7],
                        useSingleSongCall: true,
                      );
                    },
                    child: const Text('Add Favorite'),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Add Favorite'));
    await tester.pumpAndSettle();

    expect(repository.favoriteWrites, hasLength(1));
    expect(repository.favoriteWrites[0].songIds, [7]);
    expect(repository.favoriteWrites[0].favorite, isTrue);
    expect(repository.addedPlaylistIds, isEmpty);
    expect(repository.singleAddedPlaylistIds, isEmpty);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(repository.favoriteWrites, hasLength(2));
    expect(repository.favoriteWrites[1].songIds, [7]);
    expect(repository.favoriteWrites[1].favorite, isFalse);
  });

  testWidgets(
    'favorite undo action waits for library snapshot before writing',
    (tester) async {
      final repository = _FavoriteAddRepository();
      final snapshot = Completer<LibraryContentData>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryRepositoryProvider.overrideWithValue(repository),
            libraryContentDataProvider.overrideWith((ref) => snapshot.future),
          ],
          child: SmPlayerI18nScope(
            i18n: _i18n,
            child: MaterialApp(
              theme: ThemeData(extensions: [AppNotificationThemeColors.light]),
              home: Consumer(
                builder: (context, ref, _) {
                  return Scaffold(
                    body: TextButton(
                      onPressed: () {
                        unawaited(
                          setSongsFavoriteWithUndo(
                            context: context,
                            ref: ref,
                            i18n: _i18n,
                            songIds: const [7],
                            favorite: true,
                          ),
                        );
                      },
                      child: const Text('Favorite'),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Favorite'));
      await tester.pump();
      expect(repository.favoriteWrites, isEmpty);

      snapshot.complete(_snapshot);
      await tester.pumpAndSettle();

      expect(repository.favoriteWrites, hasLength(1));
      expect(repository.favoriteWrites[0].songIds, [7]);
      expect(repository.favoriteWrites[0].favorite, isTrue);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      expect(repository.favoriteWrites, hasLength(2));
      expect(repository.favoriteWrites[1].songIds, [7]);
      expect(repository.favoriteWrites[1].favorite, isFalse);
    },
  );

  testWidgets('delete song from disk uses Electron pending undo flow', (
    tester,
  ) async {
    final repository = _PendingDeleteRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [libraryRepositoryProvider.overrideWithValue(repository)],
        child: SmPlayerI18nScope(
          i18n: _i18n,
          child: MaterialApp(
            theme: ThemeData(extensions: [AppNotificationThemeColors.light]),
            home: Consumer(
              builder: (context, ref, _) {
                return Scaffold(
                  body: TextButton(
                    onPressed: () {
                      requestDeleteSongFromDisk(
                        context: context,
                        ref: ref,
                        i18n: _i18n,
                        song: _song,
                      );
                    },
                    child: const Text('Delete'),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete From Disk').last);
    await tester.pumpAndSettle();

    expect(repository.beganSongIds, [7]);
    expect(repository.committedIds, isEmpty);
    expect(find.text('Deleted Song from disk'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(repository.undoneIds, ['pending-7']);
    expect(repository.committedIds, isEmpty);
  });
}

const _i18n = SmPlayerI18n(
  locale: 'en-US',
  messages: {
    'common.cancel': 'Cancel',
    'common.myFavorites': 'My Favorites',
    'common.library': 'Library',
    'common.undo': 'Undo',
    'context.deleteSongConfirm': 'Delete {title}?',
    'library.title': 'Music Library',
    'notification.deletedFromDisk': 'Deleted {title} from disk',
    'notification.songAddedTo': 'Added {title} to {target}',
    'playlists.delete': 'Delete From Disk',
  },
);

const _song = LibrarySong(
  id: 7,
  path: '/tmp/song.mp3',
  title: 'Song',
  artist: 'Artist',
  artists: ['Artist'],
  album: 'Album',
  duration: 120,
  playCount: 0,
  lyricsOffsetMs: 0,
  dateAdded: '2026-05-20T00:00:00',
  favorite: false,
  thumbnailPath: '',
);

const _snapshot = LibraryContentData(
  songs: [_song],
  recentSongs: [],
  recentPlaylists: [],
  recentAlbums: [],
  recentArtists: [],
  recentSearches: [],
  playlists: [
    LibraryPlaylist(
      id: 11,
      name: 'My Favorites',
      priority: 0,
      songCount: 0,
      songIds: [],
      sortCriterion: PlaylistSortCriterion.title,
      isBuiltIn: true,
    ),
  ],
  favoritePlaylistId: 11,
  nowPlaying: NowPlayingSnapshot(playlistId: 12, songIds: []),
  hasLibrary: true,
  sortCriterion: MusicLibrarySortCriterion.title,
  albumsSort: AlbumSortCriterion.defaultSort,
  showCount: true,
  hideMultiSelectCommandBarAfterOperation: true,
  databasePath: '/tmp/SMPlayerSettings.db',
  rootPath: '/tmp',
);

class _FavoriteAddRepository extends LibraryRepository {
  final favoriteWrites = <({List<int> songIds, bool favorite})>[];
  final addedPlaylistIds = <int>[];
  final singleAddedPlaylistIds = <int>[];

  @override
  Future<void> setSongsFavorite(List<int> songIds, bool favorite) async {
    favoriteWrites.add((songIds: songIds.toList(), favorite: favorite));
  }

  @override
  Future<void> addSongsToPlaylist(int playlistId, List<int> songIds) async {
    addedPlaylistIds.add(playlistId);
  }

  @override
  Future<void> addSongToPlaylist(int playlistId, int songId) async {
    singleAddedPlaylistIds.add(playlistId);
  }
}

class _PendingDeleteRepository extends LibraryRepository {
  final beganSongIds = <int>[];
  final undoneIds = <String>[];
  final committedIds = <String>[];

  @override
  Future<PendingSongDelete> beginDeleteSongFromDisk(int songId) async {
    beganSongIds.add(songId);
    return PendingSongDelete(id: 'pending-$songId', songId: songId);
  }

  @override
  Future<void> undoDeleteSongFromDisk(String deleteId) async {
    undoneIds.add(deleteId);
  }

  @override
  Future<void> commitDeleteSongFromDisk(String deleteId) async {
    committedIds.add(deleteId);
  }
}
