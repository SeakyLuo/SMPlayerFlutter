import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
import 'package:smplayer_flutter/src/library/data/library_repository.dart';
import 'package:smplayer_flutter/src/library/ui/library_page_actions.dart';

void main() {
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
    'common.library': 'Library',
    'common.undo': 'Undo',
    'context.deleteSongConfirm': 'Delete {title}?',
    'library.title': 'Music Library',
    'notification.deletedFromDisk': 'Deleted {title} from disk',
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
