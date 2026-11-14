import 'dart:async';
import 'dart:io';

import '../library/data/library_models.dart';
import '../library/data/library_repository.dart';
import 'music_share_models.dart';

abstract class MusicShareAccess {
  String get selectedSource;
  void localDataChanged(String scope);
  Stream<String> get remoteDataChanges;
  List<LibraryPlaylist> get remotePlaylists;
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
    !isRemoteMusicPath(song.path) ||
    song.remoteAvailable &&
        activeMusicShareAccess != null &&
        activeMusicShareAccess!.isOnline(song.path);
