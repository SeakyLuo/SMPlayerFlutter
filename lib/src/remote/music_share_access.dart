import 'dart:async';
import 'dart:io';

import '../library/data/library_models.dart';
import '../library/data/library_queries.dart';
import '../library/data/library_repository.dart';
import 'music_share_models.dart';

abstract class MusicShareAccess {
  String get selectedSource;
  Future<List<int>> resolveSongIds(String device, LibraryDataQuery query);
  Future<ArtistSplitAnalysisResult> analyzeArtists(
    String device, {
    void Function(double)? onProgress,
  });
  Future<LibraryLyricsSearchPage> searchLyrics(
    String device,
    String query,
    String folderPath, {
    int offset = 0,
    MusicLibrarySortCriterion? order,
  });
  void localDataChanged(String scope);
  Stream<String> get remoteDataChanges;
  List<LibraryPlaylist> get remotePlaylists;
  Future<LibraryContentData> queryLibraryData(
    String device,
    LibraryDataQuery query,
  );
  Future<Map<String, dynamic>> directoryOperation(
    String device,
    String path,
    String operation, {
    String? name,
    Map<String, dynamic> values = const {},
  });
  Future<Map<String, dynamic>> storageDirectoryIndex(String device);
  Future<Map<String, dynamic>> refreshStorageDirectory(
    String device,
    String path,
    LocalFolderScanCancellation cancellation,
    void Function(LocalFolderRefreshProgress) onProgress,
  );
  Future<List<HiddenStorageItem>> hiddenStorageItems(String device);
  Future<void> resumeHiddenStorage(String device, HiddenStorageItem item);
  Future<List<LibraryPlaylist>> readPlaylists(String device);
  Future<Map<String, dynamic>> randomPlayRequest(
    String device,
    Map<String, String> parameters,
  );
  Future<List<int>> readRandomSelectionIds(
    String device,
    Map<String, String> parameters,
  );
  Future<LibraryPlaylist?> playlistOperation(
    String device,
    String operation, {
    int? playlistId,
    String? name,
    List<int> songIds = const [],
    List<int> playlistIds = const [],
    LibraryPlaylist? restore,
    PlaylistSortCriterion? criterion,
  });
  Future<Map<String, dynamic>> songsRequest(
    List<String> paths,
    String resource, {
    String method = 'GET',
    Object? body,
  });
  Future<Map<String, dynamic>> preferenceRequest(
    String device,
    String operation,
    Map<String, dynamic> values,
  );
  Future<Map<String, dynamic>> fileRequest(
    String path,
    String operation,
    Map<String, dynamic> values,
  );
  bool isOnline(String path);
  bool canWrite(String path);
  Future<Map<String, dynamic>> songRequest(
    String path,
    String resource, {
    String method = 'GET',
    Object? body,
  });
  Future<Uri> audioUri(String path);
  File? cachedArtwork(String path);
  Future<File?> artwork(String path);
  Future<LyricsSnapshot> lyrics(String path);
}

// Installed once by the application provider. Repositories used by pages and
// background lyric consumers resolve the same authorized device connections.
MusicShareAccess? activeMusicShareAccess;

bool playlistBelongsToSource(LibraryPlaylist playlist, String source) =>
    playlist.isBuiltIn || playlist.source == LibrarySource.fromDevice(source);

bool canEditPlaylist(LibraryPlaylist playlist) =>
    const LibraryRepository().dataSource(playlist.source).canWrite;

bool canEditLibrarySong(LibrarySong song) =>
    const LibraryRepository().dataSource(song.source).canWrite;

bool canCreateSourcePlaylist() {
  final share = activeMusicShareAccess;
  // Source restoration starts after the first frame.
  if (share == null) return false;
  if (share.selectedSource == 'all') return false;
  return const LibraryRepository()
      .dataSource(LibrarySource.fromDevice(share.selectedSource))
      .canWrite;
}

bool canPlayLibrarySong(LibrarySong song) =>
    song.isActive &&
    (!isRemoteMusicPath(song.path) ||
        activeMusicShareAccess != null &&
            activeMusicShareAccess!.isOnline(song.path));
