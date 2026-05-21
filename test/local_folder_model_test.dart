import 'package:flutter_test/flutter_test.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/ui/local_grid_content.dart';
import 'package:smplayer_flutter/src/library/ui/local_folder_model.dart';
import 'package:smplayer_flutter/src/library/ui/local_page_model.dart';

void main() {
  const i18n = SmPlayerI18n(
    locale: 'en-US',
    messages: {
      'common.albumUnknown': 'Unknown Album',
      'common.artistUnknown': 'Unknown Artist',
      'common.artistSeparator': ', ',
    },
  );

  test('buildFolderIndex mirrors Electron folder tree and flatten order', () {
    const rootPath = r'C:\Music';
    final songs = [
      _song(id: 1, path: r'C:\Music\Rock\B.mp3', title: 'B'),
      _song(id: 2, path: r'C:\Music\Rock\Live\A.mp3', title: 'A'),
      _song(id: 3, path: r'C:\Music\Pop\C.mp3', title: 'C'),
    ];
    const folders = [
      LibraryFolder(id: 10, path: r'C:\Music\Rock', parentId: 0, criterion: 0),
      LibraryFolder(
        id: 11,
        path: r'C:\Music\Rock\Live',
        parentId: 10,
        criterion: 0,
      ),
      LibraryFolder(id: 12, path: r'C:\Music\Pop', parentId: 0, criterion: 0),
    ];

    final index = buildFolderIndex(songs, folders, rootPath);

    expect(index.nodes['']!.childPaths, ['Pop', 'Rock']);
    expect(index.nodes['Rock']!.directSongIds, [1]);
    expect(index.nodes['Rock']!.subtreeSongIds, [2, 1]);
    expect(index.nodes['Rock/Live']!.directSongIds, [2]);
  });

  test('isMoveTargetFolder mirrors Electron local folder drop rules', () {
    const rootPath = r'C:\Music';
    final songs = [
      _song(id: 1, path: r'C:\Music\Rock\B.mp3', title: 'B'),
      _song(id: 2, path: r'C:\Music\Rock\Live\A.mp3', title: 'A'),
    ];
    const folders = [
      LibraryFolder(id: 10, path: r'C:\Music\Rock', parentId: 0, criterion: 0),
      LibraryFolder(
        id: 11,
        path: r'C:\Music\Rock\Live',
        parentId: 10,
        criterion: 0,
      ),
      LibraryFolder(id: 12, path: r'C:\Music\Pop', parentId: 0, criterion: 0),
    ];
    final index = buildFolderIndex(songs, folders, rootPath);

    expect(
      isMoveTargetFolder(
        payload: const LocalItemsDragPayload(songIds: [1], folderPaths: []),
        targetFolder: index.nodes['Pop']!,
        nodes: index.nodes,
        songsById: index.songsById,
      ),
      isTrue,
    );
    expect(
      isMoveTargetFolder(
        payload: const LocalItemsDragPayload(songIds: [1], folderPaths: []),
        targetFolder: index.nodes['Rock']!,
        nodes: index.nodes,
        songsById: index.songsById,
      ),
      isFalse,
    );
    expect(
      isMoveTargetFolder(
        payload: const LocalItemsDragPayload(
          songIds: [],
          folderPaths: [r'C:\Music\Rock'],
        ),
        targetFolder: index.nodes['Rock/Live']!,
        nodes: index.nodes,
        songsById: index.songsById,
      ),
      isFalse,
    );
    expect(
      isMoveTargetFolder(
        payload: const LocalItemsDragPayload(
          songIds: [],
          folderPaths: [r'C:\Music\Rock\Live'],
        ),
        targetFolder: index.nodes['Pop']!,
        nodes: index.nodes,
        songsById: index.songsById,
      ),
      isTrue,
    );
  });

  test('sortSongs keeps Electron local sort modes', () {
    final songs = [
      _song(id: 1, title: 'Zulu', artist: 'Beta', album: 'Two'),
      _song(id: 2, title: 'Alpha', artist: 'Beta', album: 'One'),
      _song(id: 3, title: 'Echo', artist: 'Alpha', album: 'Two'),
    ];

    expect(sortSongs(songs, LocalSortMode.title).map((song) => song.id), [
      2,
      3,
      1,
    ]);
    expect(sortSongs(songs, LocalSortMode.artist).map((song) => song.id), [
      3,
      2,
      1,
    ]);
    expect(
      sortSongs(
        songs,
        LocalSortMode.reverse,
        LocalSortMode.title,
      ).map((song) => song.id),
      [1, 3, 2],
    );
  });

  test('local sort criterion values match Electron store values', () {
    expect(localSortModeFromCriterion(0), LocalSortMode.title);
    expect(localSortModeFromCriterion(1), LocalSortMode.artist);
    expect(localSortModeFromCriterion(2), LocalSortMode.album);
    expect(localSortModeFromCriterion(7), LocalSortMode.reverse);
    expect(toLocalFolderSortValue(LocalSortMode.title), 0);
    expect(toLocalFolderSortValue(LocalSortMode.artist), 1);
    expect(toLocalFolderSortValue(LocalSortMode.album), 2);
    expect(toLocalFolderSortValue(LocalSortMode.reverse), 7);
  });

  test('local grid song detail label follows Electron sort-mode display', () {
    final song = _song(
      id: 1,
      title: 'Track',
      artist: '',
      album: '',
      artists: const [],
    );

    expect(
      getLocalSongDetailLabel(
        song,
        LocalSortMode.title,
        LocalSortMode.title,
        i18n,
      ),
      isNull,
    );
    expect(
      getLocalSongDetailLabel(
        song,
        LocalSortMode.album,
        LocalSortMode.album,
        i18n,
      ),
      'Unknown Artist · Unknown Album',
    );

    expect(
      getLocalSongDetailLabel(
        _song(
          id: 2,
          title: 'Track',
          artist: '',
          album: 'Album',
          artists: const ['Artist A', 'Artist B'],
        ),
        LocalSortMode.album,
        LocalSortMode.album,
        i18n,
      ),
      'Artist A, Artist B · Album',
    );
  });

  test('compact folder tree rows follow Electron expansion behavior', () {
    const rootPath = r'C:\Music';
    final songs = [
      _song(id: 1, path: r'C:\Music\Rock\root.mp3', title: 'Root'),
      _song(id: 2, path: r'C:\Music\Rock\Live\live.mp3', title: 'Live'),
    ];
    const folders = [
      LibraryFolder(id: 10, path: r'C:\Music\Rock', parentId: 0, criterion: 0),
      LibraryFolder(
        id: 11,
        path: r'C:\Music\Rock\Live',
        parentId: 10,
        criterion: 0,
      ),
    ];
    final index = buildFolderIndex(songs, folders, rootPath);
    final rows = buildLocalCompactFolderTreeRows(
      childFolders: [index.nodes['Rock']!],
      nodes: index.nodes,
      songsById: index.songsById,
      expandedFolderPaths: {'Rock'},
      sortMode: LocalSortMode.title,
      searchQuery: '',
    );

    expect(rows.map((row) => row.key), [
      'folder:Rock',
      'folder:Rock/Live',
      'song:Rock:1',
    ]);
    expect(rows.first.expanded, isTrue);
    expect(rows[1].depth, 1);
    expect(rows[2].depth, 1);
  });
}

LibrarySong _song({
  required int id,
  String path = '',
  String title = '',
  String artist = '',
  String album = '',
  List<String>? artists,
}) {
  return LibrarySong(
    id: id,
    path: path,
    title: title,
    artist: artist,
    artists: artists ?? (artist.isEmpty ? const [] : [artist]),
    album: album,
    duration: 0,
    playCount: 0,
    lyricsOffsetMs: 0,
    dateAdded: '',
    favorite: false,
    thumbnailPath: '',
  );
}
