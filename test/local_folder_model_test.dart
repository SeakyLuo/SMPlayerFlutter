import 'package:flutter_test/flutter_test.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/ui/grid_view_folder.dart';
import 'package:smplayer_flutter/src/library/ui/local_folder_model.dart';
import 'package:smplayer_flutter/src/library/ui/local_page_model.dart';

void main() {
  const i18n = SmPlayerI18n(
    locale: 'en-US',
    messages: {
      'common.albumUnknown': 'Unknown Album',
      'common.artistUnknown': 'Unknown Artist',
      'common.artistSeparator': ', ',
      'common.comma': ', ',
      'local.refreshAddedMultiple': '{count} songs added',
      'local.refreshAddedOne': '"{name}" added',
      'local.refreshArtistMergeSuggestionsGroup': 'Possible merges ({count})',
      'local.refreshArtistSplitSuggestionsGroup': 'Possible splits ({count})',
      'local.refreshArtistSplitsAppliedGroup': 'Ready to Split ({count})',
      'local.refreshMovedMultiple': '{count} songs moved',
      'local.refreshMovedOne': '"{name}" moved',
      'local.refreshNoChange': 'No changes found.',
      'local.refreshRemovedMultiple': '{count} songs removed',
      'local.refreshRemovedOne': '"{name}" removed',
      'local.updateFolderAccessDenied':
          'Authorization is needed to access {path}!',
      'local.updateFolderNotFound': 'Cannot find folder "{path}"!',
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

  test('buildFolderIndex applies folder criterion to direct songs', () {
    const rootPath = r'C:\Music';
    final songs = [
      _song(
        id: 1,
        path: r'C:\Music\Sorted\Zulu.mp3',
        title: 'Zulu',
        artist: 'Beta',
        album: 'Two',
      ),
      _song(
        id: 2,
        path: r'C:\Music\Sorted\Alpha.mp3',
        title: 'Alpha',
        artist: 'Beta',
        album: 'One',
      ),
      _song(
        id: 3,
        path: r'C:\Music\Sorted\Echo.mp3',
        title: 'Echo',
        artist: 'Alpha',
        album: 'Two',
      ),
    ];
    const folders = [
      LibraryFolder(
        id: 10,
        path: r'C:\Music\Sorted',
        parentId: 0,
        criterion: 2,
      ),
    ];

    final index = buildFolderIndex(songs, folders, rootPath);

    expect(index.nodes['Sorted']!.directSongIds, [2, 3, 1]);
  });

  test('folder thumbnail candidate groups mirror Electron ordering', () {
    const rootPath = r'C:\Music';
    final songs = [
      _song(
        id: 5,
        path: r'C:\Music\Root Later.mp3',
        title: 'Root Later',
        album: 'Root Album',
      ),
      _song(
        id: 4,
        path: r'C:\Music\Root First.mp3',
        title: 'Root First',
        album: 'Root Album',
      ),
      _song(
        id: 3,
        path: r'C:\Music\AChild\Alpha.mp3',
        title: 'Alpha',
        album: 'Alpha Album',
      ),
      _song(
        id: 2,
        path: r'C:\Music\BChild\Beta.mp3',
        title: 'Beta',
        album: 'Beta Album',
      ),
    ];
    const folders = [
      LibraryFolder(
        id: 20,
        path: r'C:\Music\AChild',
        parentId: 0,
        criterion: 0,
      ),
      LibraryFolder(
        id: 10,
        path: r'C:\Music\BChild',
        parentId: 0,
        criterion: 0,
      ),
    ];
    final index = buildFolderIndex(songs, folders, rootPath);

    expect(index.nodes['']!.childPaths, ['AChild', 'BChild']);
    expect(index.nodes['']!.thumbnailChildPaths, ['BChild', 'AChild']);
    expect(index.nodes['']!.thumbnailDirectSongIds, [4, 5]);
    expect(
      getOriginalFolderThumbnailCandidateGroups(
        index.nodes['']!,
        index.nodes,
        index.songsById,
      ).map((group) => group.map((song) => song.id).toList()),
      [
        [4, 5],
        [2],
        [3],
      ],
    );
  });

  test('matchesSongSearch mirrors Electron searchable song fields', () {
    final song = _song(
      id: 1,
      path: r'C:\Music\Deep\folder-file.mp3',
      title: 'Title Needle',
      artist: 'Primary Artist',
      artists: const ['Primary Artist', 'Guest Singer'],
      album: 'Album Hit',
    );

    expect(matchesSongSearch(song, 'title needle'), isTrue);
    expect(matchesSongSearch(song, 'primary artist'), isTrue);
    expect(matchesSongSearch(song, 'guest singer'), isTrue);
    expect(matchesSongSearch(song, 'album hit'), isTrue);
    expect(matchesSongSearch(song, 'folder-file'), isTrue);
    expect(matchesSongSearch(song, 'song id 1'), isFalse);
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
        payload: const LocalItemsDragPayload(songIds: [], folderPaths: []),
        targetFolder: index.nodes['Pop']!,
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
          folderPaths: [r'C:\Music\Rock'],
        ),
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
          folderPaths: [r'C:\Music\Rock\Live'],
        ),
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

  test('refresh result message mirrors Electron single and multiple copy', () {
    expect(
      getRefreshResultMessage(
        const LocalFolderRefreshResult(
          filesAdded: [r'C:\Music\New Song.mp3'],
          filesRemoved: [],
          filesMoved: [],
          artistSplitsApplied: [],
          artistSplitSuggestions: [],
          artistMergeSuggestions: [],
        ),
        i18n,
      ),
      '"New Song" added',
    );
    expect(
      getRefreshResultMessage(
        const LocalFolderRefreshResult(
          filesAdded: [],
          filesRemoved: [r'C:\Music\Old Song.flac'],
          filesMoved: [r'C:\Music\Moved Song.m4a'],
          artistSplitsApplied: [],
          artistSplitSuggestions: [],
          artistMergeSuggestions: [],
        ),
        i18n,
      ),
      '"Old Song" removed, "Moved Song" moved',
    );
    expect(
      getRefreshResultMessage(
        const LocalFolderRefreshResult(
          filesAdded: [r'C:\Music\One.mp3', r'C:\Music\Two.mp3'],
          filesRemoved: [],
          filesMoved: [],
          artistSplitsApplied: [],
          artistSplitSuggestions: [],
          artistMergeSuggestions: [],
        ),
        i18n,
      ),
      '2 songs added',
    );
  });

  test('refresh folder error message mirrors Electron prefix mapping', () {
    expect(
      getRefreshFolderErrorMessage('Folder not found: C:/Missing', i18n),
      'Cannot find folder "C:/Missing"!',
    );
    expect(
      getRefreshFolderErrorMessage('Cannot access folder: C:/Private', i18n),
      'Authorization is needed to access C:/Private!',
    );
    expect(
      getRefreshFolderErrorMessage('Unexpected refresh error', i18n),
      'Unexpected refresh error',
    );
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
