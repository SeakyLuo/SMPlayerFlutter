import 'package:flutter_test/flutter_test.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_repository.dart';
import 'package:smplayer_flutter/src/library/ui/local_folder_model.dart';
import 'package:smplayer_flutter/src/library/ui/playlist_artwork.dart';

void main() {
  test('playlist artwork mirrors Electron album-group selection', () async {
    final repository = _ArtworkRepository({
      1: _snapshot(1, ''),
      2: _snapshot(2, '/covers/a.png'),
      3: _snapshot(3, '/covers/b.png'),
      4: _snapshot(4, '/covers/b-alt.png'),
      5: _snapshot(5, '/covers/c.png'),
      6: _snapshot(6, '/covers/d.png'),
      7: _snapshot(7, '/covers/e.png'),
    });

    final urls = await resolvePlaylistArtworkUrls([
      _song(1, 'A'),
      _song(2, 'A'),
      _song(3, 'B'),
      _song(4, 'B'),
      _song(5, 'C'),
      _song(6, 'D'),
      _song(7, 'E'),
    ], repository);

    expect(urls, [
      '/covers/a.png',
      '/covers/b.png',
      '/covers/c.png',
      '/covers/d.png',
    ]);
    expect(repository.requests, [
      [1, 2, 3, 4, 5, 6, 7],
    ]);
  });

  test('playlist artwork groups by raw Electron album key', () async {
    final repository = _ArtworkRepository({
      1: _snapshot(1, '/covers/empty.png'),
      2: _snapshot(2, '/covers/space.png'),
      3: _snapshot(3, '/covers/empty-alt.png'),
    });

    final urls = await resolvePlaylistArtworkUrls([
      _song(1, ''),
      _song(2, ' '),
      _song(3, ''),
    ], repository);

    expect(urls, ['/covers/empty.png', '/covers/space.png']);
    expect(repository.requests, [
      [1, 2, 3],
    ]);
  });

  test(
    'playlist artwork display uses mosaic only for three or more covers',
    () {
      expect(getPlaylistArtworkDisplayUrls(['/a.png', '/b.png']), ['/a.png']);
      expect(getPlaylistArtworkDisplayUrls(['/a.png', '/b.png', '/c.png']), [
        '/a.png',
        '/b.png',
        '/c.png',
      ]);
    },
  );

  test(
    'folder thumbnail candidates follow original direct then child groups',
    () {
      final root =
          createFolderNode('', '/music')
            ..thumbnailDirectSongIds = [1, 2]
            ..thumbnailChildPaths = ['child'];
      final child = createFolderNode('child', '/music')
        ..thumbnailSubtreeSongIds = [3, 4];
      final songsById = {
        1: _song(1, 'A'),
        2: _song(2, 'A'),
        3: _song(3, 'B'),
        4: _song(4, 'B'),
      };

      final groups = getOriginalFolderThumbnailCandidateGroups(root, {
        '': root,
        'child': child,
      }, songsById);

      expect(
        groups.map((group) => group.map((song) => song.id).toList()).toList(),
        [
          [1, 2],
          [3, 4],
        ],
      );
    },
  );

  test('folder thumbnail candidates group raw album names like Electron', () {
    final root =
        createFolderNode('', '/music')..thumbnailDirectSongIds = [1, 2, 3];
    final songsById = {
      1: _song(1, ''),
      2: _song(2, ' '),
      3: _song(3, ''),
    };

    final groups = getOriginalFolderThumbnailCandidateGroups(root, {
      '': root,
    }, songsById);

    expect(
      groups.map((group) => group.map((song) => song.id).toList()).toList(),
      [
        [1, 3],
        [2],
      ],
    );
  });

  test(
    'folder thumbnail resolver skips only missing artwork sources',
    () async {
      final repository = _ArtworkRepository({
        1: _snapshot(1, '', source: SongArtworkSource.none),
        2: _snapshot(2, '/covers/a.png'),
        3: _snapshot(3, '/covers/b.png', source: SongArtworkSource.shell),
      });

      final urls = await resolveOriginalFolderThumbnailUrls([
        [_song(1, 'A'), _song(2, 'A')],
        [_song(3, 'B')],
      ], repository);

      expect(urls, ['/covers/a.png', '/covers/b.png']);
      expect(repository.requests, [
        [1, 2, 3],
      ]);
    },
  );
}

class _ArtworkRepository extends LibraryRepository {
  _ArtworkRepository(this.snapshotsBySongId);

  final Map<int, SongArtworkSnapshot> snapshotsBySongId;
  final List<List<int>> requests = [];

  @override
  Future<List<SongArtworkSnapshot>> getSongArtworkSnapshots(
    List<int> songIds,
  ) async {
    requests.add(songIds);
    return [
      for (final songId in songIds)
        snapshotsBySongId[songId] ??
            _snapshot(songId, '', source: SongArtworkSource.none),
    ];
  }
}

LibrarySong _song(int id, String album, [String thumbnailPath = '']) {
  return LibrarySong(
    id: id,
    path: '/music/$id.mp3',
    title: 'Song $id',
    artist: 'Artist',
    artists: const ['Artist'],
    album: album,
    duration: 60,
    playCount: 0,
    lyricsOffsetMs: 0,
    dateAdded: '2026-05-23T00:00:00',
    favorite: false,
    thumbnailPath: thumbnailPath,
  );
}

SongArtworkSnapshot _snapshot(
  int songId,
  String artworkUrl, {
  SongArtworkSource source = SongArtworkSource.cached,
}) {
  return SongArtworkSnapshot(
    songId: songId,
    artworkUrl: artworkUrl,
    sourceUrl: artworkUrl,
    sourcePath: artworkUrl,
    source: artworkUrl.isEmpty ? SongArtworkSource.none : source,
  );
}
