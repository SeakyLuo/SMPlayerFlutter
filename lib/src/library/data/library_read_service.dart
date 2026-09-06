import 'package:sqlite3/sqlite3.dart';

import 'library_artist_tag_normalizer.dart' as artist_tags;
import 'library_models.dart';
import 'package:smplayer_flutter/src/settings/settings_model.dart' as settings;

const _activeState = 1;

class LibraryReadService {
  const LibraryReadService();

  LibraryReadSettings readLibrarySettings(Database db) {
    final rows = db.select('''
      SELECT
        RootPath AS rootPath,
        MusicLibraryCriterion AS musicLibraryCriterion,
        AlbumsCriterion AS albumsCriterion,
        MyFavorites AS myFavorites,
        NowPlaying AS nowPlaying,
        ShowCount AS showCount,
        HideMultiSelectCommandBarAfterOperation
          AS hideMultiSelectCommandBarAfterOperation,
        LocalViewMode AS localViewMode,
        UseFilenameNotMusicName AS useFilenameNotMusicName,
        SmartMultiArtistRecognition AS smartMultiArtistRecognition
      FROM Settings
      ORDER BY Id
      LIMIT 1
    ''');
    final rootPath = rows.isEmpty ? '' : (rows.first['rootPath'] as String);
    final musicLibraryCriterion =
        rows.isEmpty ? 0 : (rows.first['musicLibraryCriterion'] as int);
    final albumsCriterion =
        rows.isEmpty ? -1 : (rows.first['albumsCriterion'] as int);
    final myFavorites = rows.isEmpty ? 0 : (rows.first['myFavorites'] as int);
    final nowPlaying = rows.isEmpty ? 0 : (rows.first['nowPlaying'] as int);
    final showCount = rows.isEmpty || (rows.first['showCount'] as int) != 0;
    final hideMultiSelectCommandBarAfterOperation =
        rows.isEmpty ||
        (rows.first['hideMultiSelectCommandBarAfterOperation'] as int) != 0;
    final localViewMode =
        rows.isEmpty
            ? settings.LocalViewMode.grid
            : localViewModeFromValue(rows.first['localViewMode'] as int);
    final useFilenameNotMusicName =
        rows.isNotEmpty && (rows.first['useFilenameNotMusicName'] as int) != 0;
    final smartMultiArtistRecognition =
        rows.isEmpty || (rows.first['smartMultiArtistRecognition'] as int) != 0;

    return LibraryReadSettings(
      rootPath: rootPath,
      sortCriterion: fromStoredSortCriterion(musicLibraryCriterion),
      albumsSort: fromStoredAlbumSortCriterion(albumsCriterion),
      myFavoritesId: myFavorites,
      nowPlayingId: nowPlaying,
      showCount: showCount,
      hideMultiSelectCommandBarAfterOperation:
          hideMultiSelectCommandBarAfterOperation,
      localViewMode: localViewMode,
      useFilenameNotMusicName: useFilenameNotMusicName,
      smartMultiArtistRecognition: smartMultiArtistRecognition,
    );
  }

  List<LibrarySong> readSongs(Database db) {
    final rows = db.select(
      '''
      SELECT
        Music.Id AS id,
        Music.Path AS path,
        Music.ThumbnailPath AS thumbnailPath,
        Music.Name AS title,
        Music.Artist AS artist,
        Music.Album AS album,
        Music.Duration AS duration,
        Music.PlayCount AS playCount,
        Music.LyricsOffsetMs AS lyricsOffsetMs,
        CAST(Music.DateAdded AS TEXT) AS dateAdded
      FROM Music
      WHERE Music.State = ?
      ORDER BY Music.Name COLLATE NOCASE, Music.Artist COLLATE NOCASE, Music.Id
    ''',
      [_activeState],
    );
    final favorites =
        db
            .select(
              '''
      SELECT ItemId FROM PlaylistItem
      WHERE State = ? AND PlaylistId = (
        SELECT MyFavorites FROM Settings ORDER BY Id LIMIT 1
      )
    ''',
              [_activeState],
            )
            .map((row) => row['ItemId'] as int)
            .toSet();
    final artistRows = db.select(
      '''
      SELECT MusicId, Name FROM MusicArtist
      WHERE State = ? AND Name IS NOT NULL
        AND MusicId IN (SELECT Id FROM Music WHERE State = ?)
      ORDER BY MusicId, Priority, Id
    ''',
      [_activeState, _activeState],
    );
    final artistsBySong = <int, Set<String>>{};
    for (final row in artistRows) {
      final artist = normalizeTagText(row['Name'] as String);
      if (artist.isNotEmpty) {
        artistsBySong.putIfAbsent(row['MusicId'] as int, () => {}).add(artist);
      }
    }

    return rows.map((row) {
      final artist = normalizeTagText(row['artist'] as String);
      final artists = artistsBySong[row['id']]?.toList() ?? [artist];

      return LibrarySong(
        id: row['id'] as int,
        path: row['path'] as String,
        thumbnailPath: row['thumbnailPath'] as String,
        title: normalizeTagText(row['title'] as String),
        artist: artist,
        artists: artists.isEmpty ? [artist] : artists,
        album: normalizeTagText(row['album'] as String),
        duration: row['duration'] as int,
        playCount: row['playCount'] as int,
        lyricsOffsetMs: row['lyricsOffsetMs'] as int,
        dateAdded: row['dateAdded'] as String,
        favorite: favorites.contains(row['id']),
      );
    }).toList();
  }

  List<LibraryFolder> readFolders(Database db) {
    final rows = db.select(
      '''
      SELECT
        Id AS id,
        Path AS path,
        ParentId AS parentId,
        Criterion AS criterion
      FROM Folder
      WHERE State = ?
      ORDER BY Path COLLATE NOCASE
    ''',
      [_activeState],
    );

    return rows.map((row) {
      return LibraryFolder(
        id: row['id'] as int,
        path: row['path'] as String,
        parentId: row['parentId'] as int,
        criterion: row['criterion'] as int,
      );
    }).toList();
  }

  int readLibrarySongCount(Database db) {
    final rows = db.select(
      'SELECT COUNT(*) AS count FROM Music WHERE State = ?',
      [_activeState],
    );
    return rows.single['count'] as int;
  }
}

class LibraryReadSettings {
  const LibraryReadSettings({
    required this.rootPath,
    required this.sortCriterion,
    required this.albumsSort,
    required this.myFavoritesId,
    required this.nowPlayingId,
    required this.showCount,
    required this.hideMultiSelectCommandBarAfterOperation,
    required this.localViewMode,
    required this.useFilenameNotMusicName,
    required this.smartMultiArtistRecognition,
  });

  final String rootPath;
  final MusicLibrarySortCriterion sortCriterion;
  final AlbumSortCriterion albumsSort;
  final int myFavoritesId;
  final int nowPlayingId;
  final bool showCount;
  final bool hideMultiSelectCommandBarAfterOperation;
  final settings.LocalViewMode localViewMode;
  final bool useFilenameNotMusicName;
  final bool smartMultiArtistRecognition;
}

MusicLibrarySortCriterion fromStoredSortCriterion(int value) {
  switch (value) {
    case 1:
      return MusicLibrarySortCriterion.artist;
    case 2:
      return MusicLibrarySortCriterion.album;
    case 3:
      return MusicLibrarySortCriterion.duration;
    case 4:
      return MusicLibrarySortCriterion.playCount;
    case 5:
      return MusicLibrarySortCriterion.dateAdded;
    default:
      return MusicLibrarySortCriterion.title;
  }
}

int toStoredSortCriterion(MusicLibrarySortCriterion value) {
  switch (value) {
    case MusicLibrarySortCriterion.artist:
      return 1;
    case MusicLibrarySortCriterion.album:
      return 2;
    case MusicLibrarySortCriterion.duration:
      return 3;
    case MusicLibrarySortCriterion.playCount:
      return 4;
    case MusicLibrarySortCriterion.dateAdded:
      return 5;
    case MusicLibrarySortCriterion.title:
      return 0;
  }
}

AlbumSortCriterion fromStoredAlbumSortCriterion(int value) {
  switch (value) {
    case 1:
      return AlbumSortCriterion.artist;
    case 6:
      return AlbumSortCriterion.name;
    default:
      return AlbumSortCriterion.defaultSort;
  }
}

int toStoredAlbumSortCriterion(AlbumSortCriterion value) {
  switch (value) {
    case AlbumSortCriterion.artist:
      return 1;
    case AlbumSortCriterion.name:
      return 6;
    case AlbumSortCriterion.defaultSort:
    case AlbumSortCriterion.reverse:
      return -1;
  }
}

settings.LocalViewMode localViewModeFromValue(int value) {
  return value == 1 ? settings.LocalViewMode.list : settings.LocalViewMode.grid;
}

int toStoredLocalFolderSortCriterion(LocalFolderSortCriterion value) {
  switch (value) {
    case LocalFolderSortCriterion.artist:
      return 1;
    case LocalFolderSortCriterion.album:
      return 2;
    case LocalFolderSortCriterion.reverse:
      return 7;
    case LocalFolderSortCriterion.title:
      return 0;
  }
}

String normalizeTagText(String value) {
  return artist_tags.normalizeTagText(value);
}
