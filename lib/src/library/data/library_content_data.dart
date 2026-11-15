part of 'library_models.dart';

class LibraryContentData {
  const LibraryContentData({
    required this.songs,
    this.totalSongCount = 0,
    this.totalDuration = 0,
    this.pageOffset = 0,
    this.anchorIndex,
    this.anchorShift = 0,
    this.anchorRevision = 0,
    this.songRows = const {},
    this.quickJumpOffsets = const {},
    this.artistSummaries = const [],
    this.albumSummaries = const [],
    this.folderSummaries = const [],
    this.songFolderPaths = const {},
    this.folderSongRows = const {},
    required this.hasLibrary,
    required this.sortCriterion,
    required this.albumsSort,
    required this.databasePath,
    this.recentSongs = const [],
    this.recentPlaylists = const [],
    this.recentAlbums = const [],
    this.recentArtists = const [],
    this.recentSearches = const [],
    this.playlists = const [],
    this.folders = const [],
    this.favoritePlaylistId = 0,
    this.nowPlaying = const NowPlayingSnapshot(playlistId: 0, songIds: []),
    this.showCount = true,
    this.hideMultiSelectCommandBarAfterOperation = true,
    this.localViewMode = LocalViewMode.grid,
    this.rootPath = '',
  });

  LibraryContentData withPlaylists(List<LibraryPlaylist> values) =>
      LibraryContentData(
        songs: songs,
        totalSongCount: totalSongCount,
        totalDuration: totalDuration,
        pageOffset: pageOffset,
        anchorIndex: anchorIndex,
        anchorShift: anchorShift,
        anchorRevision: anchorRevision,
        songRows: songRows,
        quickJumpOffsets: quickJumpOffsets,
        artistSummaries: artistSummaries,
        albumSummaries: albumSummaries,
        folderSummaries: folderSummaries,
        songFolderPaths: songFolderPaths,
        folderSongRows: folderSongRows,
        hasLibrary: hasLibrary,
        sortCriterion: sortCriterion,
        albumsSort: albumsSort,
        databasePath: databasePath,
        recentSongs: recentSongs,
        recentPlaylists: recentPlaylists,
        recentAlbums: recentAlbums,
        recentArtists: recentArtists,
        recentSearches: recentSearches,
        playlists: values,
        folders: folders,
        favoritePlaylistId: favoritePlaylistId,
        nowPlaying: nowPlaying,
        showCount: showCount,
        hideMultiSelectCommandBarAfterOperation:
            hideMultiSelectCommandBarAfterOperation,
        localViewMode: localViewMode,
        rootPath: rootPath,
      );

  LibraryContentData withPage({
    List<LibrarySong>? songs,
    NowPlayingSnapshot? nowPlaying,
    Map<int, LibrarySong>? songRows,
    Map<String, int>? quickJumpOffsets,
    int? totalSongCount,
    int? totalDuration,
    int? pageOffset,
    int? anchorIndex,
    int? anchorShift,
    int? anchorRevision,
    List<LibraryArtistSummary>? artistSummaries,
    List<LibraryAlbumSummary>? albumSummaries,
    List<LibraryFolderSummary>? folderSummaries,
    Map<int, String>? songFolderPaths,
    Map<String, Map<int, LibrarySong>>? folderSongRows,
  }) => LibraryContentData(
    songs: songs ?? this.songs,
    totalSongCount: totalSongCount ?? this.totalSongCount,
    totalDuration: totalDuration ?? this.totalDuration,
    pageOffset: pageOffset ?? this.pageOffset,
    anchorIndex: anchorIndex ?? this.anchorIndex,
    anchorShift: anchorShift ?? this.anchorShift,
    anchorRevision: anchorRevision ?? this.anchorRevision,
    songRows: songRows ?? this.songRows,
    quickJumpOffsets: quickJumpOffsets ?? this.quickJumpOffsets,
    artistSummaries: artistSummaries ?? this.artistSummaries,
    albumSummaries: albumSummaries ?? this.albumSummaries,
    folderSummaries: folderSummaries ?? this.folderSummaries,
    songFolderPaths: songFolderPaths ?? this.songFolderPaths,
    folderSongRows: folderSongRows ?? this.folderSongRows,
    hasLibrary: hasLibrary || (totalSongCount ?? this.totalSongCount) > 0,
    sortCriterion: sortCriterion,
    albumsSort: albumsSort,
    databasePath: databasePath,
    rootPath: rootPath,
    playlists: playlists,
    folders: folders,
    nowPlaying: nowPlaying ?? this.nowPlaying,
    favoritePlaylistId: favoritePlaylistId,
    recentSongs: recentSongs,
    recentPlaylists: recentPlaylists,
    recentAlbums: recentAlbums,
    recentArtists: recentArtists,
    recentSearches: recentSearches,
    showCount: showCount,
    localViewMode: localViewMode,
    hideMultiSelectCommandBarAfterOperation:
        hideMultiSelectCommandBarAfterOperation,
  );

  final int totalSongCount;
  final int totalDuration;
  final int pageOffset;
  final int? anchorIndex;
  final int anchorShift;
  final int anchorRevision;
  final Map<int, LibrarySong> songRows;
  final Map<String, int> quickJumpOffsets;
  final List<LibraryArtistSummary> artistSummaries;
  final List<LibraryAlbumSummary> albumSummaries;
  final List<LibraryFolderSummary> folderSummaries;
  final Map<int, String> songFolderPaths;
  final Map<String, Map<int, LibrarySong>> folderSongRows;
  final List<LibrarySong> songs;
  final List<RecentLibrarySong> recentSongs;
  final List<RecentPlaylistPlayback> recentPlaylists;
  final List<RecentAlbumPlayback> recentAlbums;
  final List<RecentArtistPlayback> recentArtists;
  final List<SearchHistoryEntry> recentSearches;
  final List<LibraryPlaylist> playlists;
  final List<LibraryFolder> folders;
  final int favoritePlaylistId;
  final NowPlayingSnapshot nowPlaying;
  final bool hasLibrary;
  final MusicLibrarySortCriterion sortCriterion;
  final AlbumSortCriterion albumsSort;
  final bool showCount;
  final bool hideMultiSelectCommandBarAfterOperation;
  final LocalViewMode localViewMode;
  final String rootPath;
  final String databasePath;
}
