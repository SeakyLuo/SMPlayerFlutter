import 'library_sql_functions.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import 'library_artist_tag_normalizer.dart' as artist_tags;
import 'library_models.dart';
import 'library_text.dart';
import 'library_search_matching.dart' as search;
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

  List<int> readSongIds(
    Database db, {
    List<int>? songIds,
    String? source,
    String? album,
    bool favoritesOnly = false,
    bool includeInactive = false,
    String? folder,
    List<String> artistNames = const [],
    List<String> albumNames = const [],
    List<String> directFolders = const [],
    List<String> recursiveFolders = const [],
    int? limit,
    int offset = 0,
    String text = '',
    MusicLibrarySortCriterion order = MusicLibrarySortCriterion.title,
    bool descending = false,
    LibraryIndex libraryIndex = LibraryIndex.standard,
    bool relevance = false,
    bool substringSearch = false,
    String unknownArtist = '',
    String unknownAlbum = '',
    void Function(int)? onCount,
    void Function(int)? onDuration,
    int? anchorSongId,
    void Function(int, int?)? onPagePosition,
    void Function(Map<String, int>)? onQuickJump,
  }) {
    db.createFunction(
      functionName: 'song_directory',
      argumentCount: const AllowedArgumentCount(1),
      deterministic: true,
      function: (values) => p.dirname(values.single as String),
    );
    registerLibraryTimeSql(db);
    final sortKeys = <String, ArtistTextSortKey>{};
    ArtistTextSortKey sortKey(String text) => sortKeys.putIfAbsent(
      text,
      () => buildArtistTextSortKey(text, index: libraryIndex),
    );
    db.createCollation(
      name: 'library_text',
      function: (left, right) => sortKey(left!).compareTo(sortKey(right!)),
    );
    db.createFunction(
      functionName: 'library_match',
      argumentCount: const AllowedArgumentCount(4),
      deterministic: true,
      function:
          (values) => search.matchLibraryText(
            values[0] as String,
            (jsonDecode(values[1] as String) as List)
                .cast<String>()
                .map((name) => name.isEmpty ? unknownArtist : name)
                .toList(),
            (values[2] as String).isEmpty ? unknownAlbum : values[2] as String,
            values[3] as int,
            text.toLowerCase(),
          ),
    );
    final matchExpression =
        "library_match(Music.Name, COALESCE(ArtistTexts.Names, json_array(Music.Artist)), Music.Album, Music.PlayCount)";
    const artistsCte =
        "ArtistTexts AS MATERIALIZED (SELECT MusicId, json_group_array(Name) AS Names,group_concat(Name, ' ') AS SearchArtists FROM MusicArtist WHERE State = 1 AND Name <> '' GROUP BY MusicId)";
    final fromMusic =
        text.isEmpty
            ? 'FROM Music'
            : 'FROM Music LEFT JOIN ArtistTexts ON ArtistTexts.MusicId = Music.Id';
    db.createFunction(
      functionName: 'library_contains',
      argumentCount: const AllowedArgumentCount(2),
      deterministic: true,
      function:
          (values) =>
              (values[0] as String).toLowerCase().contains(
                    (values[1] as String).toLowerCase(),
                  )
                  ? 1
                  : 0,
    );
    final artistParameters = List.filled(artistNames.length, '?').join(',');
    final queryFilters = <String>[
      if (directFolders.isNotEmpty)
        'song_directory(Music.Path) IN (SELECT value FROM json_each(?))',
      if (albumNames.isNotEmpty)
        'Music.Album IN (SELECT value FROM json_each(?))',
      if (text.isNotEmpty)
        substringSearch
            ? "library_contains(Music.Name || ' ' || COALESCE(ArtistTexts.SearchArtists,Music.Artist) || ' ' || Music.Album || ' ' || Music.Path,?)=1"
            : '$matchExpression > 0',
      if (artistNames.isNotEmpty)
        '(Music.Artist IN ($artistParameters) OR Music.Id IN (SELECT MusicId FROM MusicArtist WHERE State = 1 AND Name IN ($artistParameters)))',
      if (source == 'local') "Music.Path NOT LIKE 'smplayer-music://%'",
      if (source != null && source != 'local') 'Music.Path LIKE ?',
      if (album != null) 'Music.Album = ?',
      if (folder != null) '(Music.Path = ? OR substr(Music.Path, 1, ?) = ?)',
      if (favoritesOnly)
        '''Music.Id IN (
        SELECT ItemId FROM PlaylistItem WHERE State = 1 AND PlaylistId = (
          SELECT MyFavorites FROM Settings ORDER BY Id LIMIT 1
        )
      )''',
    ];
    final queryArguments = <Object?>[
      if (directFolders.isNotEmpty) jsonEncode(directFolders),
      if (albumNames.isNotEmpty) jsonEncode(albumNames),
      if (text.isNotEmpty && substringSearch) text,

      ...artistNames,
      ...artistNames,
      if (source != null && source != 'local') 'smplayer-music://$source/%',
      if (album != null) album,
      if (folder != null) ...[
        folder,
        folder.length + 1,
        '$folder${Platform.pathSeparator}',
      ],
    ];
    final idFilter =
        recursiveFolders.isNotEmpty
            ? " AND (Music.Id IN (SELECT value FROM json_each(?)) OR EXISTS(SELECT 1 FROM json_each(?) AS folders WHERE substr(Music.Path,1,length(folders.value)+1) = folders.value || ?))"
            : songIds == null
            ? ''
            : ' AND Music.Id IN (SELECT value FROM json_each(?))';
    final filters =
        queryFilters.isEmpty ? '' : ' AND ${queryFilters.join(' AND ')}';
    final arguments = <Object?>[
      includeInactive ? 0 : _activeState,
      if (recursiveFolders.isNotEmpty) ...[
        jsonEncode(songIds ?? const []),
        jsonEncode(recursiveFolders),
        Platform.pathSeparator,
      ] else if (songIds != null)
        jsonEncode(songIds),
      ...queryArguments,
    ];
    int? scopedCount;
    if (onCount != null || onDuration != null) {
      final metrics =
          db
              .select(
                'WITH $artistsCte SELECT COUNT(*) AS count, COALESCE(SUM(Duration), 0) AS duration $fromMusic WHERE Music.State ${includeInactive ? ">=" : "="} ? $idFilter $filters',
                arguments,
              )
              .first;
      scopedCount = metrics['count'] as int;
      onCount?.call(scopedCount);
      onDuration?.call(metrics['duration'] as int);
    }
    final sortColumn =
        relevance && text.isNotEmpty
            ? matchExpression
            : switch (order) {
              MusicLibrarySortCriterion.title =>
                'Music.Name COLLATE library_text',
              MusicLibrarySortCriterion.artist =>
                'Music.Artist COLLATE library_text',
              MusicLibrarySortCriterion.album =>
                'Music.Album COLLATE library_text',
              MusicLibrarySortCriterion.duration => 'Music.Duration',
              MusicLibrarySortCriterion.playCount => 'Music.PlayCount',
              MusicLibrarySortCriterion.dateAdded =>
                'library_time(CAST(Music.DateAdded AS TEXT))',
            };
    final direction =
        (relevance && text.isNotEmpty) || descending ? 'DESC' : 'ASC';
    int? anchorIndex;
    if (anchorSongId != null && limit != null) {
      final rows = db.select(
        '''WITH $artistsCte, Ordered AS (
        SELECT Music.Id,ROW_NUMBER() OVER(ORDER BY $sortColumn $direction,Music.Name COLLATE library_text $direction,Music.Id $direction)-1 AS position
        $fromMusic WHERE Music.State= ? $idFilter $filters
      ) SELECT position FROM Ordered WHERE Id=?''',
        [...arguments, anchorSongId],
      );
      if (rows.isNotEmpty) {
        anchorIndex = rows.single['position'] as int;
        offset = anchorIndex ~/ limit * limit;
      }
    }
    if (limit != null && scopedCount != null && offset >= scopedCount) {
      offset = scopedCount == 0 ? 0 : (scopedCount - 1) ~/ limit * limit;
    }
    onPagePosition?.call(offset, anchorIndex);
    if (onQuickJump != null) {
      final keys = libraryQuickJumpKeys(index: libraryIndex);
      db.createFunction(
        functionName: 'library_bucket',
        argumentCount: const AllowedArgumentCount(1),
        deterministic: true,
        function:
            (values) => keys[sortKey(values.single as String).bucketIndex],
      );
      final bucketColumn = switch (order) {
        MusicLibrarySortCriterion.title => 'Music.Name',
        MusicLibrarySortCriterion.artist => 'Music.Artist',
        MusicLibrarySortCriterion.album => 'Music.Album',
        _ => "''",
      };
      final rows = db.select(
        '''WITH $artistsCte, Ordered AS (
        SELECT $bucketColumn AS value, ROW_NUMBER() OVER (ORDER BY $sortColumn $direction, Music.Name COLLATE library_text $direction, Music.Id $direction) - 1 AS position
         $fromMusic WHERE Music.State ${includeInactive ? ">=" : "="} ? $idFilter $filters
      ) SELECT library_bucket(value) AS key, MIN(position) AS position FROM Ordered GROUP BY key''',
        arguments,
      );
      onQuickJump({
        for (final row in rows) row['key'] as String: row['position'] as int,
      });
    }
    return db
        .select(
          'WITH $artistsCte SELECT Music.Id  $fromMusic WHERE Music.State ${includeInactive ? ">=" : "="} ? $idFilter $filters ORDER BY $sortColumn $direction, Music.Name COLLATE library_text $direction, Music.Id $direction ${limit == null ? '' : 'LIMIT ? OFFSET ?'}',
          [
            ...arguments,
            if (limit != null) ...[limit, offset],
          ],
        )
        .map((row) => row['Id'] as int)
        .toList();
  }

  List<LibrarySong> readSongs(
    Database db, {
    List<int>? songIds,
    String? source,
    String? album,
    bool favoritesOnly = false,
    bool includeInactive = false,
    String? folder,
    List<String> artistNames = const [],
    List<String> albumNames = const [],
    List<String> directFolders = const [],
    List<String> recursiveFolders = const [],
    int? limit,
    int offset = 0,
    String text = '',
    MusicLibrarySortCriterion order = MusicLibrarySortCriterion.title,
    bool descending = false,
    LibraryIndex libraryIndex = LibraryIndex.standard,
    bool relevance = false,
    bool substringSearch = false,
    String unknownArtist = '',
    String unknownAlbum = '',
    void Function(int)? onCount,
    void Function(int)? onDuration,
    int? anchorSongId,
    void Function(int, int?)? onPagePosition,
    void Function(Map<String, int>)? onQuickJump,
  }) {
    final ids = readSongIds(
      db,
      songIds: songIds,
      source: source,
      album: album,
      favoritesOnly: favoritesOnly,
      includeInactive: includeInactive,
      folder: folder,
      artistNames: artistNames,
      albumNames: albumNames,
      directFolders: directFolders,
      recursiveFolders: recursiveFolders,
      limit: limit,
      offset: offset,
      text: text,
      order: order,
      descending: descending,
      libraryIndex: libraryIndex,
      relevance: relevance,
      substringSearch: substringSearch,
      unknownArtist: unknownArtist,
      unknownAlbum: unknownAlbum,
      onCount: onCount,
      onDuration: onDuration,
      anchorSongId: anchorSongId,
      onPagePosition: onPagePosition,
      onQuickJump: onQuickJump,
    );
    final rows = db.select(
      '''
      SELECT
        Music.Id AS id,
        Music.Path AS path,
        Music.State AS state,
        Music.ThumbnailPath AS thumbnailPath,
        Music.Name AS title,
        Music.Artist AS artist,
        Music.Album AS album,
        Music.Duration AS duration,
        Music.PlayCount AS playCount,
        Music.LyricsOffsetMs AS lyricsOffsetMs,
        CAST(Music.DateAdded AS TEXT) AS dateAdded
      FROM Music WHERE Id IN (SELECT value FROM json_each(?))
    ''',
      [jsonEncode(ids)],
    );
    final loadedIds = jsonEncode(rows.map((row) => row['id'] as int).toList());
    final favorites =
        db
            .select(
              '''SELECT ItemId FROM PlaylistItem WHERE State = ?
      AND PlaylistId = (SELECT MyFavorites FROM Settings ORDER BY Id LIMIT 1)
      AND ItemId IN (SELECT value FROM json_each(?))''',
              [_activeState, loadedIds],
            )
            .map((row) => row['ItemId'] as int)
            .toSet();
    final artistRows = db.select(
      '''SELECT MusicId, Name FROM MusicArtist WHERE State = ?
      AND MusicId IN (SELECT value FROM json_each(?)) ORDER BY MusicId, Priority, Id''',
      [_activeState, loadedIds],
    );
    final artistsBySong = <int, Set<String>>{};
    for (final row in artistRows) {
      final artist = normalizeTagText(row['Name'] as String);
      if (artist.isNotEmpty) {
        artistsBySong.putIfAbsent(row['MusicId'] as int, () => {}).add(artist);
      }
    }

    final songs =
        rows.map((row) {
          final artist = normalizeTagText(row['artist'] as String);
          final artists = artistsBySong[row['id']]?.toList() ?? [artist];

          return LibrarySong(
            id: row['id'] as int,
            path: row['path'] as String,
            isActive: row['state'] == 1,
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
    final byId = {for (final song in songs) song.id: song};
    return [for (final id in ids) byId[id]!];
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
