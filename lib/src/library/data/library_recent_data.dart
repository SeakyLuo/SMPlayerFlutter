import 'dart:isolate';

import 'library_browse_history_service.dart';
import 'library_playback_history_service.dart';
import 'library_snapshot_service.dart';
import 'library_repository.dart';
import 'library_models.dart';
import 'library_queries.dart';

Future<({List<RecentBrowseEntry> entries, List<LibrarySong> songs})>
readLocalRecentBrowses(LibraryRepository repository) async {
  final path = await repository.getDatabasePath();
  await LibrarySnapshotService.waitForPendingOperations();
  final entries = await Isolate.run(() {
    final db = LibrarySnapshotService.openReadDatabase(path);
    try {
      return const LibraryBrowseHistoryService().read(db);
    } finally {
      db.dispose();
    }
  });
  final ids = {
    for (final entry in entries)
      if (entry.type == RecentBrowseType.song) int.parse(entry.itemId),
  };
  final songs =
      ids.isEmpty
          ? const <LibrarySong>[]
          : (await const LibrarySnapshotService().readSongs(
                path,
                songIds: ids.toList(),
              ))
              .where((song) => song.isActive && song.source.deviceId == 'local')
              .toList();
  return (entries: entries, songs: songs);
}

Future<
  ({
    List<RecentLibrarySong> songs,
    List<RecentPlaylistPlayback> playlists,
    List<RecentAlbumPlayback> albums,
    List<RecentArtistPlayback> artists,
    List<RecentNowPlayingSnapshot> nowPlaying,
    List<LibrarySong> queueSongs,
  })
>
readLocalRecentPlayed(LibraryRepository repository) async {
  final path = await repository.getDatabasePath();
  await LibrarySnapshotService.waitForPendingOperations();
  final data = await Isolate.run(() {
    final db = LibrarySnapshotService.openReadDatabase(path);
    const history = LibraryPlaybackHistoryService();
    try {
      return (
        references: history.readRecentSongReferences(db),
        playlists: history.readRecentPlaylists(db),
        albums: history.readRecentAlbums(db),
        artists: history.readRecentArtists(db),
        nowPlaying: history.readRecentNowPlaying(db),
      );
    } finally {
      db.dispose();
    }
  });
  final queueIds = {for (final record in data.nowPlaying) ...record.songIds};
  final ids = {...data.references.map((entry) => entry.id), ...queueIds};
  final songs =
      ids.isEmpty
          ? const <LibrarySong>[]
          : await const LibrarySnapshotService().readSongs(
            path,
            songIds: ids.toList(),
          );
  final byId = {
    for (final song in songs)
      if (song.isActive && song.source.deviceId == 'local') song.id: song,
  };
  return (
    songs: [
      for (final entry in data.references)
        if (byId[entry.id] case final song?)
          RecentLibrarySong.fromSong(song, playedAt: entry.playedAt),
    ],
    playlists: data.playlists,
    albums: data.albums,
    artists: data.artists,
    nowPlaying: data.nowPlaying,
    queueSongs: [
      for (final song in byId.values)
        if (queueIds.contains(song.id)) song,
    ],
  );
}

Future<RecentPageData> readLocalRecentData(LibraryRepository repository) async {
  final (added, played, playlists) =
      await (
        repository.queryLibrary(
          const LibraryDataQuery(
            LibraryQueryKind.songs,
            order: MusicLibrarySortCriterion.dateAdded,
            descending: true,
            limit: 500,
          ),
        ),
        repository.queryLibrary(
          const LibraryDataQuery(LibraryQueryKind.recent),
        ),
        repository.getLocalPlaylists(),
      ).wait;
  return repository.getRecentPageData(
    played
        .withPage(
          songs:
              {
                for (final s in [...added.songs, ...played.songs]) s.id: s,
              }.values.toList(),
        )
        .withPlaylists(playlists),
  );
}
