import '../library/data/library_models.dart';
import '../library/data/library_repository.dart';
import 'music_share_access.dart';
import 'music_share_catalog.dart';
import 'music_share_models.dart';
import 'music_share_history.dart';

String selectedHistorySource() =>
    activeMusicShareAccess?.selectedSource ?? 'local';
Future<Map<String, dynamic>> remoteHistory(
  String device,
  String operation, [
  Map<String, dynamic> values = const {},
]) => activeMusicShareAccess!.historyRequest(device, operation, values);
int remotePlaylistHistoryId(String device, int id) =>
    -int.parse(
      shareDigest(
        '$remoteMusicScheme://$device/playlists/$id',
      ).substring(0, 15),
      radix: 16,
    ) -
    1;
int hostPlaylistHistoryId(int id) => int.parse(
  Uri.parse(
    activeMusicShareAccess!.remotePlaylists
        .firstWhere((p) => p.id == id)
        .remotePath,
  ).pathSegments.last,
);

Future<RecentPageData> readRemoteRecentData(
  LibraryRepository repository,
  String device,
) async {
  final json = await remoteHistory(device, 'get');
  final raw =
      (json['songs'] as List)
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();
  await importMusicShareCatalog(
    await repository.getDatabasePath(),
    device,
    raw,
    replace: false,
    isCurrent: () => selectedHistorySource() == device,
  );
  final songs = await repository.readRemoteSelection(
    device,
    raw.map((e) => e['id'] as int).toList(),
  );
  final byHost = {
    for (final s in songs) int.parse(Uri.parse(s.path).pathSegments.single): s,
  };
  final playlists = await activeMusicShareAccess!.readPlaylists(device);
  final byPlaylist = {
    for (final p in playlists) hostPlaylistHistoryId(p.id): p.id,
  };
  final browses =
      (json['browses'] as List).cast<Map>().map(browseHistoryFromJson).toList();
  String item(RecentBrowseEntry e) => switch (e.type) {
    RecentBrowseType.song => byHost[int.parse(e.itemId)]!.id.toString(),
    RecentBrowseType.playlist =>
      remotePlaylistHistoryId(device, int.parse(e.itemId)).toString(),
    _ => e.itemId,
  };
  return RecentPageData(
    songs: songs,
    recentSongs: [
      for (final e in (json['played'] as List).cast<Map>())
        if (byHost.containsKey(e['song']))
          RecentLibrarySong.fromSong(
            byHost[e['song']]!,
            playedAt: e['time'] as String,
          ),
    ],
    recentPlaylists: [
      for (final e in (json['playlists'] as List).cast<Map>())
        if (byPlaylist.containsKey(e['item']))
          RecentPlaylistPlayback(
            id: e['id'] as int,
            playlistId: byPlaylist[e['item']]!,
            playedAt: e['time'] as String,
          ),
    ],
    recentAlbums: [
      for (final e in (json['albums'] as List).cast<Map>())
        RecentAlbumPlayback(
          id: e['id'] as int,
          album: e['item'] as String,
          playedAt: e['time'] as String,
        ),
    ],
    recentArtists: [
      for (final e in (json['artists'] as List).cast<Map>())
        RecentArtistPlayback(
          id: e['id'] as int,
          artist: e['item'] as String,
          playedAt: e['time'] as String,
        ),
    ],
    recentSearches:
        (json['searches'] as List)
            .cast<Map>()
            .map(searchHistoryFromJson)
            .toList(),
    recentBrowses: [
      for (final e in browses)
        if (e.type != RecentBrowseType.song ||
            byHost.containsKey(int.parse(e.itemId)))
          RecentBrowseEntry(
            id: e.id,
            type: e.type,
            itemId: item(e),
            browsedAt: e.browsedAt,
          ),
    ],
    recentNowPlaying: [
      for (final entry in (json['nowPlayingHistory'] as List).cast<Map>())
        RecentNowPlayingSnapshot(
          id: entry['id'] as int,
          playlistId: remotePlaylistHistoryId(device, entry['playlist'] as int),
          songIds: [
            for (final id in (entry['songs'] as List).cast<int>())
              if (byHost.containsKey(id)) byHost[id]!.id,
          ],
          createdAt: entry['time'] as String,
        ),
    ],
    playlists: playlists,
    favoritePlaylistId: 0,
    nowPlaying: const NowPlayingSnapshot(playlistId: 0, songIds: []),
    showCount: true,
    hideMultiSelectCommandBarAfterOperation: true,
  );
}
