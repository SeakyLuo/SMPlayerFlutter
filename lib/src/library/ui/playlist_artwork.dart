import '../../remote/music_share_models.dart';
import '../data/library_models.dart';
import '../data/library_repository.dart';
import 'local_folder_model.dart';

final _playlistArtworkUrlsCache = <String, List<String>>{};
final _localFolderThumbnailUrlsCache = <String, List<String>>{};

String getPlaylistArtworkSignature(List<LibrarySong> songs) {
  return songs.map((song) => '${song.id}:${song.thumbnailPath}').join('|');
}

List<String>? getCachedPlaylistArtworkUrls(String signature) {
  return _playlistArtworkUrlsCache[signature];
}

void cachePlaylistArtworkUrls(String signature, List<String> artworkUrls) {
  _playlistArtworkUrlsCache[signature] = artworkUrls;
}

List<String> getKnownPlaylistArtworkUrls(List<LibrarySong> songs) {
  final albums = <String>{};
  final paths = <String>[];
  for (final song in songs) {
    if (song.thumbnailPath.isNotEmpty && albums.add(song.album)) {
      paths.add(song.thumbnailPath);
      if (paths.length == 4) break;
    }
  }
  return paths;
}

Future<List<String>> resolvePlaylistArtworkUrls(
  List<LibrarySong> songs,
  LibraryRepository repository,
) async {
  final artworkUrls = <String>[];
  final songsByAlbum = <String, List<LibrarySong>>{};

  for (final song in songs) {
    final album = song.album;
    final albumSongs = songsByAlbum[album];
    if (albumSongs == null) {
      songsByAlbum[album] = [song];
    } else {
      albumSongs.add(song);
    }
  }

  final artworkBySongId = await _resolveSongArtworkMap(songs, repository);
  for (final albumSongs in songsByAlbum.values) {
    for (final song in albumSongs) {
      final artworkUrl = artworkBySongId[song.id] ?? '';
      if (artworkUrl.isNotEmpty) {
        artworkUrls.add(artworkUrl);
        break;
      }
    }
    if (artworkUrls.length == 4) {
      return artworkUrls;
    }
  }

  return artworkUrls;
}

List<String> getPlaylistArtworkDisplayUrls(List<String> artworkUrls) {
  return artworkUrls.length >= 3
      ? artworkUrls.take(4).toList()
      : artworkUrls.take(1).toList();
}

String getFolderThumbnailSignature(
  FolderNode folder,
  List<List<LibrarySong>> candidateGroups,
) {
  return [
    folder.relativePath,
    candidateGroups
        .map((group) => group.map((song) => song.id).join(','))
        .join('|'),
  ].join(':');
}

List<String>? getCachedOriginalFolderThumbnailUrls(String signature) {
  return _localFolderThumbnailUrlsCache[signature];
}

void cacheOriginalFolderThumbnailUrls(
  String signature,
  List<String> artworkUrls,
) {
  _localFolderThumbnailUrlsCache[signature] = artworkUrls;
}

Future<List<String>> resolveOriginalFolderThumbnailUrls(
  List<List<LibrarySong>> candidateGroups,
  LibraryRepository repository,
) async {
  final artworkUrls = <String>[];
  final songs = [for (final groupSongs in candidateGroups) ...groupSongs];
  final snapshotsBySongId = await _resolveSongArtworkSnapshotMap(
    songs,
    repository,
  );

  for (final groupSongs in candidateGroups) {
    for (final song in groupSongs) {
      final snapshot = snapshotsBySongId[song.id];
      if (snapshot != null &&
          snapshot.artworkUrl.isNotEmpty &&
          snapshot.source != SongArtworkSource.none) {
        artworkUrls.add(snapshot.artworkUrl);
        break;
      }
    }

    if (artworkUrls.length == 4) {
      return artworkUrls;
    }
  }

  return artworkUrls;
}

Future<Map<int, String>> _resolveSongArtworkMap(
  List<LibrarySong> songs,
  LibraryRepository repository,
) async {
  final localSongs =
      songs.where((song) => !isRemoteMusicPath(song.path)).toList();
  final snapshotsBySongId = await _resolveSongArtworkSnapshotMap(
    localSongs,
    repository,
  );
  return {
    for (final song in songs)
      if (isRemoteMusicPath(song.path)) song.id: song.thumbnailPath,
    for (final entry in snapshotsBySongId.entries)
      entry.key: entry.value.artworkUrl,
  };
}

Future<Map<int, SongArtworkSnapshot>> _resolveSongArtworkSnapshotMap(
  List<LibrarySong> songs,
  LibraryRepository repository,
) async {
  final songIds = <int>[];
  final seenSongIds = <int>{};
  for (final song in songs) {
    if (seenSongIds.add(song.id)) {
      songIds.add(song.id);
    }
  }

  if (songIds.isEmpty) {
    return const {};
  }

  final snapshots = await repository.getSongArtworkSnapshots(songIds);
  return {for (final snapshot in snapshots) snapshot.songId: snapshot};
}
