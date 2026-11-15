import 'library_models.dart';
import 'library_source.dart';

enum LibraryQueryKind {
  context,
  songs,
  artistIndex,
  albumIndex,
  folders,
  playlists,
  playlistIndex,
  directoryIndex,
  recent,
  favorites,
  album,
  artist,
  queue,
  lyrics,
}

class LibraryDataQuery {
  const LibraryDataQuery(
    this.kind, {
    this.source = 'local',
    this.album = '',
    this.folder,
    this.artists = const [],
    this.directFolders = const [],
    this.directWindows = const {},
    this.recursiveFolders = const [],
    this.albumNames = const [],
    this.playlistId,
    this.songIds = const [],
    this.useSongIds = false,
    this.anchorSongId,
    this.offset = 0,
    this.limit,
    this.text = '',
    this.order = MusicLibrarySortCriterion.title,
    this.descending = false,
    this.relevance = false,
    this.substringSearch = false,
    this.unknownArtist = '',
    this.unknownAlbum = '',
  });

  final int offset;
  final int? limit;
  final String text;
  final MusicLibrarySortCriterion order;
  final bool descending;
  final bool relevance;
  final bool substringSearch;
  final String unknownArtist, unknownAlbum;
  LibraryDataQuery withPage({
    String? source,
    int? offset,
    MusicLibrarySortCriterion? order,
    bool? descending,
    int? anchorSongId,
  }) => LibraryDataQuery(
    kind,
    relevance: relevance,
    substringSearch: substringSearch,
    unknownArtist: unknownArtist,
    unknownAlbum: unknownAlbum,
    source: source ?? this.source,
    offset: offset ?? this.offset,
    limit: limit,
    text: text,
    order: order ?? this.order,
    descending: descending ?? this.descending,
    album: album,
    folder: folder,
    artists: artists,
    directFolders: directFolders,
    directWindows: directWindows,
    recursiveFolders: recursiveFolders,
    albumNames: albumNames,
    playlistId: playlistId,
    songIds: songIds,
    useSongIds: useSongIds,
    anchorSongId: anchorSongId ?? this.anchorSongId,
  );
  final LibraryQueryKind kind;
  final String source;
  final String album;
  final String? folder;
  final List<String> artists;
  final List<String> directFolders;
  final Map<String, int> directWindows;
  final List<String> recursiveFolders;
  final List<String> albumNames;
  final int? playlistId;
  final List<int> songIds;
  final bool useSongIds;
  final int? anchorSongId;

  @override
  bool operator ==(Object other) {
    if (other is! LibraryDataQuery ||
        kind != other.kind ||
        anchorSongId != other.anchorSongId ||
        useSongIds != other.useSongIds ||
        relevance != other.relevance ||
        substringSearch != other.substringSearch ||
        unknownArtist != other.unknownArtist ||
        unknownAlbum != other.unknownAlbum ||
        offset != other.offset ||
        limit != other.limit ||
        text != other.text ||
        order != other.order ||
        descending != other.descending ||
        source != other.source ||
        album != other.album ||
        folder != other.folder ||
        playlistId != other.playlistId ||
        songIds.length != other.songIds.length ||
        directFolders.length != other.directFolders.length ||
        directWindows.length != other.directWindows.length ||
        recursiveFolders.length != other.recursiveFolders.length ||
        artists.length != other.artists.length ||
        albumNames.length != other.albumNames.length)
      return false;
    for (var index = 0; index < recursiveFolders.length; index++) {
      if (recursiveFolders[index] != other.recursiveFolders[index])
        return false;
    }
    for (final entry in directWindows.entries) {
      if (other.directWindows[entry.key] != entry.value) return false;
    }
    for (var index = 0; index < directFolders.length; index++) {
      if (directFolders[index] != other.directFolders[index]) return false;
    }
    for (var index = 0; index < songIds.length; index++) {
      if (songIds[index] != other.songIds[index]) return false;
    }
    for (var index = 0; index < albumNames.length; index++) {
      if (albumNames[index] != other.albumNames[index]) return false;
    }
    for (var index = 0; index < artists.length; index++) {
      if (artists[index] != other.artists[index]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    kind,
    useSongIds,
    anchorSongId,
    relevance,
    Object.hash(substringSearch, unknownArtist, unknownAlbum),
    offset,
    limit,
    text,
    order,
    descending,
    source,
    album,
    folder,
    playlistId,
    Object.hashAll(songIds),
    Object.hashAll(directFolders),
    Object.hashAll(recursiveFolders),
    Object.hashAllUnordered(
      directWindows.entries.map((e) => Object.hash(e.key, e.value)),
    ),
    Object.hashAll(artists),
    Object.hashAll(albumNames),
  );
}

LibraryContentData mergeLoadedLibraryData(
  LibraryContentData context,
  LibraryContentData page,
  LibraryDataQuery query,
) => LibraryContentData(
  totalSongCount: page.totalSongCount,
  totalDuration: page.totalDuration,
  folderSummaries: page.folderSummaries,
  songFolderPaths: page.songFolderPaths,
  folderSongRows: page.folderSongRows,
  artistSummaries:
      query.kind == LibraryQueryKind.artistIndex
          ? page.artistSummaries
          : context.artistSummaries,
  albumSummaries:
      query.kind == LibraryQueryKind.albumIndex
          ? page.albumSummaries
          : context.albumSummaries,
  songs:
      {
        for (final song in context.songs)
          if (!((query.kind == LibraryQueryKind.songs ||
                  query.kind == LibraryQueryKind.folders) &&
              query.songIds.isEmpty &&
              query.folder == null &&
              query.limit == null &&
              song.source == LibrarySource.fromDevice(query.source)))
            song.id: song,
        for (final song in page.songs) song.id: song,
      }.values.toList(),
  hasLibrary: context.hasLibrary || page.hasLibrary,
  sortCriterion: page.sortCriterion,
  albumsSort: page.albumsSort,
  databasePath: page.databasePath,
  rootPath: page.rootPath,
  folders:
      query.kind == LibraryQueryKind.folders && query.source == 'local'
          ? page.folders
          : context.folders,
  playlists:
      {
        for (final playlist in context.playlists)
          if ((query.kind != LibraryQueryKind.playlists &&
                  query.kind != LibraryQueryKind.playlistIndex) ||
              playlist.source != LibrarySource.fromDevice(query.source))
            playlist.id: playlist,
        for (final playlist in page.playlists) playlist.id: playlist,
      }.values.toList(),
  recentSearches: context.recentSearches,
  nowPlaying: page.nowPlaying,
  favoritePlaylistId: page.favoritePlaylistId,
  showCount: page.showCount,
  hideMultiSelectCommandBarAfterOperation:
      page.hideMultiSelectCommandBarAfterOperation,
  localViewMode: page.localViewMode,
);

LibraryContentData libraryDataWithSongs(
  LibraryContentData context,
  List<LibrarySong> songs,
) => context.withPage(songs: songs);
