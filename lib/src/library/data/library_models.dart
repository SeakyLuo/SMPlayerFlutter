import 'package:smplayer_flutter/src/settings/settings_model.dart'
    show LocalViewMode;

enum MusicLibrarySortCriterion {
  title,
  artist,
  album,
  duration,
  playCount,
  dateAdded,
}

enum MusicLibrarySortDirection { ascending, descending }

enum AlbumSortCriterion { defaultSort, name, artist, reverse }

enum SearchHistoryType { sidebar, artists, albums, songs, playlists, folders }

enum RecentBrowseType { song, artist, album, playlist }

enum LocalFolderSortCriterion { title, artist, album, reverse }

enum PlaylistSortCriterion {
  title,
  artist,
  album,
  duration,
  playCount,
  dateAdded,
}

class PendingSongDelete {
  const PendingSongDelete({required this.id, required this.songId});

  final String id;
  final int songId;
}

class PendingLocalItemsDelete {
  const PendingLocalItemsDelete({
    required this.id,
    required this.songIds,
    required this.folderPaths,
  });

  final String id;
  final List<int> songIds;
  final List<String> folderPaths;
}

class LibrarySong {
  const LibrarySong({
    required this.id,
    required this.path,
    required this.title,
    required this.artist,
    required this.artists,
    required this.album,
    required this.duration,
    required this.playCount,
    required this.lyricsOffsetMs,
    required this.dateAdded,
    required this.favorite,
    required this.thumbnailPath,
  });

  final int id;
  final String path;
  final String title;
  final String artist;
  final List<String> artists;
  final String album;
  final int duration;
  final int playCount;
  final int lyricsOffsetMs;
  final String dateAdded;
  final bool favorite;
  final String thumbnailPath;

  LibrarySong copyWith({
    String? title,
    String? artist,
    List<String>? artists,
    String? album,
    int? duration,
    int? playCount,
    int? lyricsOffsetMs,
    String? dateAdded,
    bool? favorite,
    String? thumbnailPath,
  }) {
    return LibrarySong(
      id: id,
      path: path,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      artists: artists ?? this.artists,
      album: album ?? this.album,
      duration: duration ?? this.duration,
      playCount: playCount ?? this.playCount,
      lyricsOffsetMs: lyricsOffsetMs ?? this.lyricsOffsetMs,
      dateAdded: dateAdded ?? this.dateAdded,
      favorite: favorite ?? this.favorite,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
    );
  }
}

class SongPropertiesSnapshot {
  const SongPropertiesSnapshot({
    required this.songId,
    required this.path,
    required this.title,
    required this.subtitle,
    required this.artist,
    required this.artists,
    required this.album,
    required this.albumArtist,
    required this.publisher,
    required this.trackNumber,
    required this.year,
    required this.genre,
    required this.composers,
    required this.duration,
    required this.bitrate,
    required this.fileSize,
    required this.dateCreated,
    required this.dateModified,
    required this.fileType,
    required this.playCount,
  });

  final int songId;
  final String path;
  final String title;
  final String subtitle;
  final String artist;
  final List<String> artists;
  final String album;
  final String albumArtist;
  final String publisher;
  final int trackNumber;
  final int year;
  final String genre;
  final String composers;
  final int duration;
  final int bitrate;
  final int fileSize;
  final String dateCreated;
  final String dateModified;
  final String fileType;
  final int playCount;

  SongPropertiesSnapshot copyWith({
    String? title,
    String? subtitle,
    String? artist,
    List<String>? artists,
    String? album,
    String? albumArtist,
    String? publisher,
    int? trackNumber,
    int? year,
    String? genre,
    String? composers,
    int? playCount,
  }) {
    return SongPropertiesSnapshot(
      songId: songId,
      path: path,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      artist: artist ?? this.artist,
      artists: artists ?? this.artists,
      album: album ?? this.album,
      albumArtist: albumArtist ?? this.albumArtist,
      publisher: publisher ?? this.publisher,
      trackNumber: trackNumber ?? this.trackNumber,
      year: year ?? this.year,
      genre: genre ?? this.genre,
      composers: composers ?? this.composers,
      duration: duration,
      bitrate: bitrate,
      fileSize: fileSize,
      dateCreated: dateCreated,
      dateModified: dateModified,
      fileType: fileType,
      playCount: playCount ?? this.playCount,
    );
  }
}

class SongPropertiesUpdate {
  const SongPropertiesUpdate({
    required this.title,
    required this.artist,
    required this.artists,
    required this.album,
    required this.playCount,
    this.subtitle = '',
    this.albumArtist = '',
    this.publisher = '',
    this.trackNumber = 0,
    this.year = 0,
    this.genre = '',
    this.composers = '',
  });

  final String title;
  final String subtitle;
  final String artist;
  final List<String> artists;
  final String album;
  final String albumArtist;
  final String publisher;
  final int trackNumber;
  final int year;
  final String genre;
  final String composers;
  final int playCount;
}

enum LyricsSource { none, lrcFile, textFile, musicFile, internet }

class LyricsLine {
  const LyricsLine({
    required this.id,
    required this.timestampMs,
    required this.text,
  });

  final int id;
  final int? timestampMs;
  final String text;
}

class LyricsSnapshot {
  const LyricsSnapshot({
    required this.source,
    required this.isSynced,
    required this.rawText,
    required this.lines,
  });

  final LyricsSource source;
  final bool isSynced;
  final String rawText;
  final List<LyricsLine> lines;
}

class LocalLyricsSearchMatch {
  const LocalLyricsSearchMatch({
    required this.songId,
    required this.snippet,
    required this.contextLines,
    required this.timestampMs,
    required this.additionalMatchCount,
    required this.relevance,
  });

  final int songId;
  final String snippet;
  final List<String> contextLines;
  final int? timestampMs;
  final int additionalMatchCount;
  final int relevance;
}

class LocalLyricsIndexProgress {
  const LocalLyricsIndexProgress({required this.current, required this.total});

  final int current;
  final int total;
}

enum SongArtworkSource { cached, embedded, shell, none }

class SongArtworkSnapshot {
  const SongArtworkSnapshot({
    required this.songId,
    required this.artworkUrl,
    required this.sourceUrl,
    required this.sourcePath,
    required this.source,
  });

  final int songId;
  final String artworkUrl;
  final String sourceUrl;
  final String sourcePath;
  final SongArtworkSource source;
}

class RecentLibrarySong extends LibrarySong {
  const RecentLibrarySong({
    required super.id,
    required super.path,
    required super.title,
    required super.artist,
    required super.artists,
    required super.album,
    required super.duration,
    required super.playCount,
    required super.lyricsOffsetMs,
    required super.dateAdded,
    required super.favorite,
    required super.thumbnailPath,
    required this.playedAt,
  });

  RecentLibrarySong.fromSong(LibrarySong song, {required this.playedAt})
    : super(
        id: song.id,
        path: song.path,
        title: song.title,
        artist: song.artist,
        artists: song.artists,
        album: song.album,
        duration: song.duration,
        playCount: song.playCount,
        lyricsOffsetMs: song.lyricsOffsetMs,
        dateAdded: song.dateAdded,
        favorite: song.favorite,
        thumbnailPath: song.thumbnailPath,
      );

  final String playedAt;
}

class RecentPlaylistPlayback {
  const RecentPlaylistPlayback({
    required this.id,
    required this.playlistId,
    required this.playedAt,
  });

  final int id;
  final int playlistId;
  final String playedAt;
}

class RecentAlbumPlayback {
  const RecentAlbumPlayback({
    required this.id,
    required this.album,
    required this.playedAt,
  });

  final int id;
  final String album;
  final String playedAt;
}

class RecentArtistPlayback {
  const RecentArtistPlayback({
    required this.id,
    required this.artist,
    required this.playedAt,
  });

  final int id;
  final String artist;
  final String playedAt;
}

class SearchHistoryEntry {
  const SearchHistoryEntry({
    required this.id,
    required this.query,
    required this.type,
    required this.searchedAt,
  });

  final int id;
  final String query;
  final SearchHistoryType type;
  final String searchedAt;
}

class RecentBrowseEntry {
  const RecentBrowseEntry({
    required this.id,
    required this.type,
    required this.itemId,
    required this.browsedAt,
  });

  final int id;
  final RecentBrowseType type;
  final String itemId;
  final String browsedAt;
}

List<SearchHistoryEntry> latestSearchHistoryEntries(
  Iterable<SearchHistoryEntry> entries,
  SearchHistoryType type, {
  int limit = 10,
}) {
  final seenQueries = <String>{};
  final result = <SearchHistoryEntry>[];
  for (final entry in entries) {
    if (entry.type != type) {
      continue;
    }
    if (!seenQueries.add(entry.query.toLowerCase())) {
      continue;
    }
    result.add(entry);
    if (result.length == limit) {
      break;
    }
  }
  return result;
}

class LibraryPlaylist {
  const LibraryPlaylist({
    required this.id,
    required this.name,
    required this.priority,
    required this.songCount,
    required this.songIds,
    required this.sortCriterion,
    required this.isBuiltIn,
  });

  final int id;
  final String name;
  final int priority;
  final int songCount;
  final List<int> songIds;
  final PlaylistSortCriterion sortCriterion;
  final bool isBuiltIn;

  LibraryPlaylist copyWith({
    String? name,
    int? priority,
    int? songCount,
    List<int>? songIds,
    PlaylistSortCriterion? sortCriterion,
  }) {
    return LibraryPlaylist(
      id: id,
      name: name ?? this.name,
      priority: priority ?? this.priority,
      songCount: songCount ?? this.songCount,
      songIds: songIds ?? this.songIds,
      sortCriterion: sortCriterion ?? this.sortCriterion,
      isBuiltIn: isBuiltIn,
    );
  }
}

class LibraryFolder {
  const LibraryFolder({
    required this.id,
    required this.path,
    required this.parentId,
    required this.criterion,
  });

  final int id;
  final String path;
  final int parentId;
  final int criterion;
}

class HiddenStorageItem {
  const HiddenStorageItem({
    required this.id,
    required this.type,
    required this.path,
  });

  final int id;
  final String type;
  final String path;
}

class ArtistSplitResultItem {
  const ArtistSplitResultItem({
    required this.songId,
    required this.title,
    required this.artist,
    required this.artists,
  });

  final int songId;
  final String title;
  final String artist;
  final List<String> artists;
}

class ArtistSplitAnalysisResult {
  const ArtistSplitAnalysisResult({
    required this.directSplits,
    required this.possibleSplits,
    required this.mergeSuggestions,
  });

  final List<ArtistSplitResultItem> directSplits;
  final List<ArtistSplitResultItem> possibleSplits;
  final List<ArtistSplitResultItem> mergeSuggestions;

  bool get hasSuggestions =>
      directSplits.isNotEmpty ||
      possibleSplits.isNotEmpty ||
      mergeSuggestions.isNotEmpty;
}

class LocalFolderRefreshResult {
  const LocalFolderRefreshResult({
    required this.filesAdded,
    required this.filesRemoved,
    required this.filesMoved,
    required this.artistSplitsApplied,
    required this.artistSplitSuggestions,
    required this.artistMergeSuggestions,
  });

  final List<String> filesAdded;
  final List<String> filesRemoved;
  final List<String> filesMoved;
  final List<ArtistSplitResultItem> artistSplitsApplied;
  final List<ArtistSplitResultItem> artistSplitSuggestions;
  final List<ArtistSplitResultItem> artistMergeSuggestions;

  bool get hasChanges =>
      filesAdded.isNotEmpty ||
      filesRemoved.isNotEmpty ||
      filesMoved.isNotEmpty ||
      artistSplitsApplied.isNotEmpty ||
      artistSplitSuggestions.isNotEmpty ||
      artistMergeSuggestions.isNotEmpty;
}

enum LocalFolderRefreshStage { checking, reading, updating }

class LocalFolderScanCanceledException implements Exception {
  const LocalFolderScanCanceledException();
}

class LocalFolderScanCancellation {
  var _canceled = false;

  bool get isCanceled => _canceled;

  void cancel() {
    _canceled = true;
  }

  void throwIfCanceled() {
    if (_canceled) {
      throw const LocalFolderScanCanceledException();
    }
  }
}

class LocalFolderRefreshProgress {
  const LocalFolderRefreshProgress({
    required this.current,
    required this.total,
    required this.currentPath,
    this.stage = LocalFolderRefreshStage.updating,
    this.checkedFolderCount = 0,
    this.folderCount = 0,
    this.processedSongCount = 0,
    this.songCount = 0,
    this.addedCount = 0,
    this.updatedCount = 0,
    this.missingCount = 0,
    this.canCancel = false,
  });

  final int current;
  final int total;
  final String currentPath;
  final LocalFolderRefreshStage stage;
  final int checkedFolderCount;
  final int folderCount;
  final int processedSongCount;
  final int songCount;
  final int addedCount;
  final int updatedCount;
  final int missingCount;
  final bool canCancel;
}

class NowPlayingSnapshot {
  const NowPlayingSnapshot({required this.playlistId, required this.songIds});

  final int playlistId;
  final List<int> songIds;
}

class RecentPageData {
  const RecentPageData({
    required this.songs,
    required this.recentSongs,
    required this.recentPlaylists,
    required this.recentAlbums,
    required this.recentArtists,
    required this.recentSearches,
    this.recentBrowses = const [],
    required this.playlists,
    required this.favoritePlaylistId,
    required this.nowPlaying,
    required this.showCount,
    required this.hideMultiSelectCommandBarAfterOperation,
  });

  final List<LibrarySong> songs;
  final List<RecentLibrarySong> recentSongs;
  final List<RecentPlaylistPlayback> recentPlaylists;
  final List<RecentAlbumPlayback> recentAlbums;
  final List<RecentArtistPlayback> recentArtists;
  final List<SearchHistoryEntry> recentSearches;
  final List<RecentBrowseEntry> recentBrowses;
  final List<LibraryPlaylist> playlists;
  final int favoritePlaylistId;
  final NowPlayingSnapshot nowPlaying;
  final bool showCount;
  final bool hideMultiSelectCommandBarAfterOperation;
}

class ShellNavigationData {
  const ShellNavigationData({
    required this.songs,
    required this.playlists,
    required this.folders,
    required this.recentSearches,
    required this.nowPlaying,
    required this.rootPath,
  });

  final List<LibrarySong> songs;
  final List<LibraryPlaylist> playlists;
  final List<LibraryFolder> folders;
  final List<SearchHistoryEntry> recentSearches;
  final NowPlayingSnapshot nowPlaying;
  final String rootPath;
}

class LibraryContentData {
  const LibraryContentData({
    required this.songs,
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
