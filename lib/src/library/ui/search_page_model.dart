import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/ui/album_tile.dart';
import 'package:smplayer_flutter/src/library/ui/song_display_helpers.dart';
import 'package:smplayer_flutter/src/settings/settings_model.dart';

enum SearchResultType { artists, albums, songs, playlists, folders }

enum SearchFilterKey { all, artists, albums, songs, playlists, folders }

class SearchResult {
  const SearchResult({
    required this.title,
    required this.subtitle,
    required this.artworkUrl,
    required this.path,
    required this.score,
    required this.songCount,
    required this.playCount,
    required this.duration,
    required this.albumCount,
    required this.songIds,
    this.sourceId,
    this.sourcePath,
    this.localFolderRelativePath,
  });

  final String title;
  final String subtitle;
  final String artworkUrl;
  final String path;
  final int score;
  final int songCount;
  final int playCount;
  final int duration;
  final int albumCount;
  final List<int> songIds;
  final String? sourceId;
  final String? sourcePath;
  final String? localFolderRelativePath;
}

AlbumTileData getSearchAlbumTileData(
  SearchResult card,
  Map<int, LibrarySong> songsById,
  SmPlayerI18n i18n,
) {
  final songs = card.songIds.map((songId) => songsById[songId]!).toList();
  return AlbumTileData(
    name: card.title,
    artist: getSearchAlbumArtistLabel(songs, i18n),
    songs: songs,
    duration: songs.fold(0, (total, song) => total + song.duration),
  );
}

String getSearchAlbumArtistLabel(List<LibrarySong> songs, SmPlayerI18n i18n) {
  final artists =
      songs.expand((song) => _searchSongArtists(song, i18n)).toSet().toList();
  if (artists.length >= 3) {
    return i18n.t('albums.artistsAndMore', {
      'first': artists[0],
      'second': artists[1],
      'count': artists.length - 2,
    });
  }

  return artists.join(', ');
}

class SearchResults {
  const SearchResults({
    required this.artists,
    required this.albums,
    required this.songs,
    required this.playlists,
    required this.folders,
  });

  const SearchResults.empty()
    : artists = const [],
      albums = const [],
      songs = const [],
      playlists = const [],
      folders = const [];

  final List<SearchResult> artists;
  final List<SearchResult> albums;
  final List<LibrarySong> songs;
  final List<SearchResult> playlists;
  final List<SearchResult> folders;
}

class SearchCriteria {
  const SearchCriteria({
    required this.artists,
    required this.albums,
    required this.songs,
    required this.playlists,
    required this.folders,
  });

  final SearchSortCriterion artists;
  final SearchSortCriterion albums;
  final SearchSortCriterion songs;
  final SearchSortCriterion playlists;
  final SearchSortCriterion folders;

  SearchSortCriterion criterionFor(SearchResultType type) {
    return switch (type) {
      SearchResultType.artists => artists,
      SearchResultType.albums => albums,
      SearchResultType.songs => songs,
      SearchResultType.playlists => playlists,
      SearchResultType.folders => folders,
    };
  }
}

List<({SearchSortCriterion value, String label})> getSortOptions(
  SearchResultType section,
  SmPlayerI18n i18n,
) {
  final baseOptions = [
    (
      value: SearchSortCriterion.defaultCriterion,
      label: i18n.t('search.sortDefault'),
    ),
  ];

  return switch (section) {
    SearchResultType.artists => [
      ...baseOptions,
      (value: SearchSortCriterion.name, label: i18n.t('search.sortName')),
      (value: SearchSortCriterion.album, label: i18n.t('common.albums')),
      (value: SearchSortCriterion.playCount, label: i18n.t('common.playCount')),
      (value: SearchSortCriterion.duration, label: i18n.t('common.duration')),
    ],
    SearchResultType.albums => [
      ...baseOptions,
      (value: SearchSortCriterion.name, label: i18n.t('search.sortName')),
      (value: SearchSortCriterion.playCount, label: i18n.t('common.playCount')),
      (value: SearchSortCriterion.duration, label: i18n.t('common.duration')),
    ],
    SearchResultType.songs => [
      ...baseOptions,
      (value: SearchSortCriterion.title, label: i18n.t('search.sortTitle')),
      (value: SearchSortCriterion.artist, label: i18n.t('common.artist')),
      (value: SearchSortCriterion.album, label: i18n.t('common.album')),
      (value: SearchSortCriterion.playCount, label: i18n.t('common.playCount')),
      (value: SearchSortCriterion.duration, label: i18n.t('common.duration')),
      (value: SearchSortCriterion.dateAdded, label: i18n.t('common.dateAdded')),
    ],
    SearchResultType.playlists => [
      ...baseOptions,
      (value: SearchSortCriterion.name, label: i18n.t('search.sortName')),
      (value: SearchSortCriterion.playCount, label: i18n.t('common.playCount')),
      (value: SearchSortCriterion.duration, label: i18n.t('common.duration')),
    ],
    SearchResultType.folders => [
      ...baseOptions,
      (value: SearchSortCriterion.name, label: i18n.t('search.sortName')),
    ],
  };
}

List<LibraryPlaylist> buildSearchablePlaylists(
  List<LibraryPlaylist> playlists,
  int nowPlayingPlaylistId,
) {
  return playlists
      .where((playlist) => playlist.id != nowPlayingPlaylistId)
      .toList();
}

SearchResults buildSearchResults(
  List<LibrarySong> songs,
  List<LibraryFolder> folders,
  List<LibraryPlaylist> playlists,
  String rootPath,
  String normalizedQuery,
  SmPlayerI18n i18n,
) {
  if (normalizedQuery.isEmpty) {
    return const SearchResults.empty();
  }

  final matchedSongs =
      songs
          .map(
            (song) => (
              entity: song,
              score: matchSong(song, normalizedQuery, i18n),
            ),
          )
          .where((result) => result.score > 0)
          .toList()
        ..sort(
          (left, right) => _compareMany([
            right.score.compareTo(left.score),
            left.entity.title.compareTo(right.entity.title),
          ]),
        );
  final matchedSongList = matchedSongs.map((result) => result.entity).toList();
  final matchedSongIds = matchedSongList.map((song) => song.id).toSet();
  final songsById = {for (final song in songs) song.id: song};

  final playlistResults =
      playlists
          .map((playlist) {
            final score = [
              evaluateString(playlist.name, normalizedQuery),
              playlist.songIds.any(matchedSongIds.contains) ? 1 : 0,
            ].reduce((left, right) => left > right ? left : right);
            return (playlist: playlist, score: score);
          })
          .where((result) => result.score > 0)
          .toList()
        ..sort(
          (left, right) => _compareMany([
            right.score.compareTo(left.score),
            left.playlist.name.compareTo(right.playlist.name),
          ]),
        );

  return SearchResults(
    artists: _buildArtistResults(songs, normalizedQuery, i18n),
    albums: _buildAlbumResults(songs, normalizedQuery, i18n),
    songs: matchedSongList,
    playlists:
        playlistResults.map((result) {
          final playlistSongs =
              result.playlist.songIds
                  .map((songId) => songsById[songId])
                  .whereType<LibrarySong>()
                  .toList();
          return SearchResult(
            score: result.score,
            title: result.playlist.name,
            subtitle: i18n.t('cards.songCount', {
              'count': result.playlist.songCount,
            }),
            artworkUrl:
                playlistSongs
                    .where((song) => song.thumbnailPath.isNotEmpty)
                    .map((song) => song.thumbnailPath)
                    .firstOrNull ??
                '',
            path: '/playlists/${result.playlist.id}',
            songCount: result.playlist.songCount,
            playCount: playlistSongs.fold(
              0,
              (total, song) => total + song.playCount,
            ),
            duration: playlistSongs.fold(
              0,
              (total, song) => total + song.duration,
            ),
            albumCount: 0,
            songIds: playlistSongs.map((song) => song.id).toList(),
            sourceId: result.playlist.id.toString(),
          );
        }).toList(),
    folders: _buildFolderResults(
      songs,
      folders,
      matchedSongList,
      rootPath,
      normalizedQuery,
      i18n,
    ),
  );
}

List<SearchResult> sortSearchResults(
  List<SearchResult> cards,
  SearchSortCriterion criterion,
) {
  final sorted = cards.toList();
  switch (criterion) {
    case SearchSortCriterion.name:
    case SearchSortCriterion.title:
      sorted.sort((left, right) => left.title.compareTo(right.title));
      return sorted;
    case SearchSortCriterion.album:
      sorted.sort(
        (left, right) => _compareMany([
          right.albumCount.compareTo(left.albumCount),
          left.title.compareTo(right.title),
        ]),
      );
      return sorted;
    case SearchSortCriterion.playCount:
      sorted.sort(
        (left, right) => _compareMany([
          right.playCount.compareTo(left.playCount),
          left.title.compareTo(right.title),
        ]),
      );
      return sorted;
    case SearchSortCriterion.duration:
      sorted.sort(
        (left, right) => _compareMany([
          right.duration.compareTo(left.duration),
          left.title.compareTo(right.title),
        ]),
      );
      return sorted;
    case SearchSortCriterion.artist:
    case SearchSortCriterion.dateAdded:
    case SearchSortCriterion.defaultCriterion:
      return sorted;
  }
}

List<LibrarySong> sortSearchSongs(
  List<LibrarySong> songs,
  SearchSortCriterion criterion,
) {
  final sorted = songs.toList();
  switch (criterion) {
    case SearchSortCriterion.title:
    case SearchSortCriterion.name:
      sorted.sort(
        (left, right) => _compareMany([
          left.title.compareTo(right.title),
          right.playCount.compareTo(left.playCount),
        ]),
      );
      return sorted;
    case SearchSortCriterion.artist:
      sorted.sort(
        (left, right) => _compareMany([
          _searchPrimaryArtist(left).compareTo(_searchPrimaryArtist(right)),
          right.playCount.compareTo(left.playCount),
        ]),
      );
      return sorted;
    case SearchSortCriterion.album:
      sorted.sort(
        (left, right) => _compareMany([
          left.album.compareTo(right.album),
          right.playCount.compareTo(left.playCount),
        ]),
      );
      return sorted;
    case SearchSortCriterion.playCount:
      sorted.sort(
        (left, right) => _compareMany([
          right.playCount.compareTo(left.playCount),
          left.title.compareTo(right.title),
        ]),
      );
      return sorted;
    case SearchSortCriterion.duration:
      sorted.sort(
        (left, right) => _compareMany([
          left.duration.compareTo(right.duration),
          right.playCount.compareTo(left.playCount),
        ]),
      );
      return sorted;
    case SearchSortCriterion.dateAdded:
      sorted.sort(
        (left, right) => _compareMany([
          left.dateAdded.compareTo(right.dateAdded),
          right.playCount.compareTo(left.playCount),
        ]),
      );
      return sorted;
    case SearchSortCriterion.defaultCriterion:
      return sorted;
  }
}

String getSearchResultCardKey(SearchResultType sectionKey, SearchResult card) {
  return '${sectionKey.name}:${card.path}:${card.title}';
}

List<int> getUniqueSongIds(List<int> songIds) {
  return songIds.toSet().toList();
}

List<int> shuffleSearchSongIds(List<int> songIds) {
  return songIds.toList()..shuffle();
}

SearchHistoryType searchHistoryTypeForFilter(SearchFilterKey filter) {
  return switch (filter) {
    SearchFilterKey.artists => SearchHistoryType.artists,
    SearchFilterKey.albums => SearchHistoryType.albums,
    SearchFilterKey.songs => SearchHistoryType.songs,
    SearchFilterKey.playlists => SearchHistoryType.playlists,
    SearchFilterKey.folders => SearchHistoryType.folders,
    SearchFilterKey.all => SearchHistoryType.sidebar,
  };
}

SearchFilterKey searchFilterKeyFromType(String? value) {
  return switch (value) {
    'artists' => SearchFilterKey.artists,
    'albums' => SearchFilterKey.albums,
    'songs' => SearchFilterKey.songs,
    'playlists' => SearchFilterKey.playlists,
    'folders' => SearchFilterKey.folders,
    _ => SearchFilterKey.all,
  };
}

String searchFilterTypeValue(SearchFilterKey filter) {
  return switch (filter) {
    SearchFilterKey.artists => 'artists',
    SearchFilterKey.albums => 'albums',
    SearchFilterKey.songs => 'songs',
    SearchFilterKey.playlists => 'playlists',
    SearchFilterKey.folders => 'folders',
    SearchFilterKey.all => 'all',
  };
}

List<SearchResult> _buildArtistResults(
  List<LibrarySong> songs,
  String normalizedQuery,
  SmPlayerI18n i18n,
) {
  final groups = <String, List<LibrarySong>>{};
  for (final song in songs) {
    for (final artist in _searchSongArtists(song, i18n)) {
      if (artist.toLowerCase().contains(normalizedQuery)) {
        final artistSongs = groups[artist] ?? <LibrarySong>[];
        artistSongs.add(song);
        groups[artist] = artistSongs;
      }
    }
  }

  final results =
      groups.entries
          .map((entry) {
            final albums =
                entry.value
                    .map((song) => displayAlbum(song, i18n))
                    .where((album) => album.isNotEmpty)
                    .toSet();
            return SearchResult(
              score: evaluateString(entry.key, normalizedQuery),
              title: entry.key,
              subtitle: i18n.t('artists.artistSummary', {
                'albums': albums.length,
                'songs': entry.value.length,
              }),
              artworkUrl:
                  entry.value
                      .where((song) => song.thumbnailPath.isNotEmpty)
                      .map((song) => song.thumbnailPath)
                      .firstOrNull ??
                  '',
              path: '/artists?artist=${Uri.encodeQueryComponent(entry.key)}',
              songCount: entry.value.length,
              playCount: entry.value.fold(
                0,
                (total, song) => total + song.playCount,
              ),
              duration: entry.value.fold(
                0,
                (total, song) => total + song.duration,
              ),
              albumCount: albums.length,
              songIds: entry.value.map((song) => song.id).toList(),
            );
          })
          .where((result) => result.score > 0)
          .toList()
        ..sort(
          (left, right) => _compareMany([
            right.score.compareTo(left.score),
            left.title.compareTo(right.title),
          ]),
        );
  return results;
}

List<SearchResult> _buildAlbumResults(
  List<LibrarySong> songs,
  String normalizedQuery,
  SmPlayerI18n i18n,
) {
  final groups = <String, List<LibrarySong>>{};
  for (final song in songs) {
    final album = displayAlbum(song, i18n);
    final artists = _searchSongArtists(song, i18n);
    if (album.toLowerCase().contains(normalizedQuery) ||
        artists.any(
          (artist) => artist.toLowerCase().contains(normalizedQuery),
        )) {
      final albumSongs = groups[album] ?? <LibrarySong>[];
      albumSongs.add(song);
      groups[album] = albumSongs;
    }
  }

  final results =
      groups.entries
          .map((entry) {
            final artists =
                entry.value
                    .expand((song) => _searchSongArtists(song, i18n))
                    .toSet();
            final artistScore = artists
                .map((artist) => evaluateString(artist, normalizedQuery) - 10)
                .fold(0, (best, score) => score > best ? score : best);
            return SearchResult(
              score: [
                evaluateString(entry.key, normalizedQuery),
                artistScore,
              ].reduce((left, right) => left > right ? left : right),
              title: entry.key,
              subtitle: i18n.t('cards.albumSubtitle', {
                'tracks': i18n.t('cards.trackCount', {
                  'count': entry.value.length,
                }),
                'artists': i18n.t('cards.artistCount', {
                  'count': artists.length,
                }),
              }),
              artworkUrl:
                  entry.value
                      .where((song) => song.thumbnailPath.isNotEmpty)
                      .map((song) => song.thumbnailPath)
                      .firstOrNull ??
                  '',
              path: '/albums?album=${Uri.encodeQueryComponent(entry.key)}',
              songCount: entry.value.length,
              playCount: entry.value.fold(
                0,
                (total, song) => total + song.playCount,
              ),
              duration: entry.value.fold(
                0,
                (total, song) => total + song.duration,
              ),
              albumCount: 0,
              songIds: entry.value.map((song) => song.id).toList(),
            );
          })
          .where((result) => result.score > 0)
          .toList()
        ..sort(
          (left, right) => _compareMany([
            right.score.compareTo(left.score),
            left.title.compareTo(right.title),
          ]),
        );
  return results;
}

List<SearchResult> _buildFolderResults(
  List<LibrarySong> songs,
  List<LibraryFolder> folders,
  List<LibrarySong> matchedSongs,
  String rootPath,
  String normalizedQuery,
  SmPlayerI18n i18n,
) {
  final matchedFolderPaths =
      matchedSongs.map((song) => getFolderPath(song.path)).toSet();
  final candidateFolderPaths = <String>{};
  final folderByPath = {for (final folder in folders) folder.path: folder};

  for (final folder in folders) {
    final folderName = getPathLabel(folder.path);
    if (evaluateString(folderName, normalizedQuery) > 0 ||
        evaluateString(folder.path, normalizedQuery) > 0) {
      candidateFolderPaths.add(folder.path);
    }
  }
  candidateFolderPaths.addAll(matchedFolderPaths);

  final normalizedCandidateFolderPathByPath = {
    for (final folderPath in candidateFolderPaths)
      normalizeFolderPath(folderPath): folderPath,
  };
  final songsByFolder = <String, List<LibrarySong>>{};
  for (final song in songs) {
    var currentFolderPath = normalizeFolderPath(getFolderPath(song.path));
    while (currentFolderPath.isNotEmpty) {
      final candidateFolderPath =
          normalizedCandidateFolderPathByPath[currentFolderPath];
      if (candidateFolderPath != null) {
        final folderSongs =
            songsByFolder[candidateFolderPath] ?? <LibrarySong>[];
        folderSongs.add(song);
        songsByFolder[candidateFolderPath] = folderSongs;
      }
      currentFolderPath = getParentFolderPath(currentFolderPath);
    }
  }

  final results =
      candidateFolderPaths
          .map((folderPath) {
            final folderSongs =
                songsByFolder[folderPath] ?? const <LibrarySong>[];
            final folderName = getPathLabel(folderPath);
            return SearchResult(
              score: [
                evaluateString(folderName, normalizedQuery),
                evaluateString(folderPath, normalizedQuery),
                matchedFolderPaths.contains(folderPath) ? 1 : 0,
              ].reduce((left, right) => left > right ? left : right),
              title:
                  folderName.isEmpty ? i18n.t('local.libraryRoot') : folderName,
              subtitle: i18n.t('cards.songCount', {
                'count': folderSongs.length,
              }),
              artworkUrl:
                  folderSongs
                      .where((song) => song.thumbnailPath.isNotEmpty)
                      .map((song) => song.thumbnailPath)
                      .firstOrNull ??
                  '',
              path: '/local',
              localFolderRelativePath: getRelativeFolderPath(
                folderPath,
                rootPath,
              ),
              songCount: folderSongs.length,
              playCount: folderSongs.fold(
                0,
                (total, song) => total + song.playCount,
              ),
              duration: folderSongs.fold(
                0,
                (total, song) => total + song.duration,
              ),
              albumCount: 0,
              songIds: folderSongs.map((song) => song.id).toList(),
              sourceId: folderByPath[folderPath]?.id.toString(),
              sourcePath: folderPath,
            );
          })
          .where(
            (result) =>
                result.score > 0 && folderByPath.containsKey(result.sourcePath),
          )
          .toList()
        ..sort(
          (left, right) => _compareMany([
            right.score.compareTo(left.score),
            (left.sourcePath ?? '').compareTo(right.sourcePath ?? ''),
          ]),
        );
  return results;
}

int matchSong(LibrarySong song, String normalizedQuery, SmPlayerI18n i18n) {
  final artists = _searchSongArtists(song, i18n);
  final artistScore = artists
      .map((artist) => evaluateString(artist, normalizedQuery))
      .fold(0, (best, score) => score > best ? score : best);
  final baseScore = [
    evaluateString(song.title, normalizedQuery),
    artistScore - 10,
    evaluateString(displayAlbum(song, i18n), normalizedQuery) - 20,
    0,
  ].reduce((left, right) => left > right ? left : right);
  return baseScore == 0
      ? 0
      : baseScore + (song.playCount / 10).clamp(0, 10).floor();
}

int evaluateString(String value, String normalizedQuery, [int offset = 0]) {
  if (value.isEmpty) {
    return 0;
  }

  final normalizedValue = value.toLowerCase();
  if (value == normalizedQuery) {
    return 100 + offset;
  }
  if (normalizedValue == normalizedQuery) {
    return 95 + offset;
  }
  if (value.startsWith(normalizedQuery)) {
    return 90 + offset;
  }
  if (normalizedValue.startsWith(normalizedQuery)) {
    return 85 + offset;
  }
  if (value.contains(normalizedQuery)) {
    return 80 + offset;
  }
  if (normalizedValue.contains(normalizedQuery)) {
    return 75 + offset;
  }
  if (normalizedQuery.contains(normalizedValue)) {
    return 70 + offset;
  }

  final editDistance = getEditDistance(normalizedValue, normalizedQuery);
  final ratio =
      (editDistance * 100) ~/
      [
        normalizedValue.length,
        normalizedQuery.length,
      ].reduce((left, right) => left > right ? left : right);
  return ratio <= 60 ? 70 - ratio + offset : 0;
}

List<String> _searchSongArtists(LibrarySong song, [SmPlayerI18n? i18n]) {
  final artists = songArtists(song);
  return artists.isEmpty
      ? [i18n?.t('common.artistUnknown') ?? 'Unknown artist']
      : artists;
}

String _searchPrimaryArtist(LibrarySong song) {
  return _searchSongArtists(song).first;
}

int getEditDistance(String target, String given) {
  final dp = List.generate(
    target.length + 1,
    (rowIndex) => List.generate(
      given.length + 1,
      (columnIndex) =>
          rowIndex == 0
              ? columnIndex
              : columnIndex == 0
              ? rowIndex
              : 0,
    ),
  );

  for (var rowIndex = 1; rowIndex <= target.length; rowIndex += 1) {
    for (var columnIndex = 1; columnIndex <= given.length; columnIndex += 1) {
      final replaceCost =
          target[rowIndex - 1] == given[columnIndex - 1] ? 0 : 1;
      dp[rowIndex][columnIndex] = [
        dp[rowIndex - 1][columnIndex] + 1,
        dp[rowIndex][columnIndex - 1] + 1,
        dp[rowIndex - 1][columnIndex - 1] + replaceCost,
      ].reduce((left, right) => left < right ? left : right);
    }
  }

  return dp[target.length][given.length];
}

String getFolderPath(String filePath) {
  final separatorIndex = [
    filePath.lastIndexOf('/'),
    filePath.lastIndexOf('\\'),
  ].reduce((left, right) => left > right ? left : right);
  return separatorIndex >= 0 ? filePath.substring(0, separatorIndex) : '';
}

String getParentFolderPath(String folderPath) {
  final separatorIndex = folderPath.lastIndexOf('/');
  return separatorIndex > 0 ? folderPath.substring(0, separatorIndex) : '';
}

String normalizeFolderPath(String folderPath) {
  return folderPath.replaceAll('\\', '/').replaceFirst(RegExp(r'/+$'), '');
}

String getPathLabel(String path) {
  final segments =
      path
          .split(RegExp(r'[/\\]+'))
          .where((segment) => segment.isNotEmpty)
          .toList();
  return segments.isEmpty ? path : segments.last;
}

String getRelativeFolderPath(String folderPath, String rootPath) {
  final normalizedFolder = normalizeFolderPath(folderPath);
  final normalizedRoot = normalizeFolderPath(rootPath);

  if (normalizedFolder == normalizedRoot) {
    return '';
  }

  if (normalizedFolder.startsWith('$normalizedRoot/')) {
    return normalizedFolder.substring(normalizedRoot.length + 1);
  }

  return folderPath;
}

bool isSongUnderFolder(String songPath, String folderPath) {
  final normalizedSongPath = songPath.replaceAll('\\', '/');
  final normalizedFolderPath = normalizeFolderPath(folderPath);
  return normalizedSongPath.startsWith('$normalizedFolderPath/');
}

bool isFolderUnderFolder(String candidatePath, String folderPath) {
  final normalizedCandidatePath = normalizeFolderPath(candidatePath);
  final normalizedFolderPath = normalizeFolderPath(folderPath);
  return normalizedCandidatePath == normalizedFolderPath ||
      normalizedCandidatePath.startsWith('$normalizedFolderPath/');
}

int _compareMany(List<int> results) {
  for (final result in results) {
    if (result != 0) {
      return result;
    }
  }
  return 0;
}
