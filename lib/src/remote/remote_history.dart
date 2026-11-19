import '../library/data/library_models.dart';
import '../library/data/library_repository.dart';
import '../library/data/library_recent_data.dart';
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
  final byHost = await _readRemoteHistorySongs(repository, device, json);
  final songs = byHost.values.toList();
  final playlists = await activeMusicShareAccess!.readPlaylists(device);
  final playlistIds = playlists.map((playlist) => playlist.id).toSet();
  return RecentPageData(
    songs: songs,
    recentSongs: _recentSongs(json, byHost),
    recentPlaylists:
        _recentPlaylists(
          json,
          device,
        ).where((entry) => playlistIds.contains(entry.playlistId)).toList(),
    recentAlbums: _recentAlbums(json),
    recentArtists: _recentArtists(json),
    recentSearches:
        (json['searches'] as List)
            .cast<Map>()
            .map(searchHistoryFromJson)
            .toList(),
    recentBrowses: _recentBrowses(json, byHost, device),
    recentNowPlaying: _recentQueueHistory(json, byHost, device),
    playlists: playlists,
    favoritePlaylistId: 0,
    nowPlaying: const NowPlayingSnapshot(playlistId: 0, songIds: []),
    showCount: true,
    hideMultiSelectCommandBarAfterOperation: true,
  );
}

Future<Map<int, LibrarySong>> _readRemoteHistorySongs(
  LibraryRepository repository,
  String device,
  Map<String, dynamic> json,
) async {
  final raw =
      (json['songs'] as List)
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();
  if (raw.isEmpty) return {};
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
  return {
    for (final s in songs) int.parse(Uri.parse(s.path).pathSegments.single): s,
  };
}

List<RecentBrowseEntry> _recentBrowses(
  Map<String, dynamic> json,
  Map<int, LibrarySong> byHost,
  String device,
) {
  final browses =
      (json['browses'] as List).cast<Map>().map(browseHistoryFromJson).toList();
  String item(RecentBrowseEntry e) => switch (e.type) {
    RecentBrowseType.song => byHost[int.parse(e.itemId)]!.id.toString(),
    RecentBrowseType.playlist =>
      remotePlaylistHistoryId(device, int.parse(e.itemId)).toString(),
    _ => e.itemId,
  };
  return [
    for (final e in browses)
      if (e.type != RecentBrowseType.song ||
          byHost.containsKey(int.parse(e.itemId)))
        RecentBrowseEntry(
          id: e.id,
          type: e.type,
          itemId: item(e),
          browsedAt: e.browsedAt,
        ),
  ];
}

List<RecentLibrarySong> _recentSongs(
  Map<String, dynamic> json,
  Map<int, LibrarySong> byHost,
) => [
  for (final e in (json['played'] as List).cast<Map>())
    if (byHost.containsKey(e['song']))
      RecentLibrarySong.fromSong(
        byHost[e['song']]!,
        playedAt: e['time'] as String,
      ),
];

List<RecentPlaylistPlayback> _recentPlaylists(
  Map<String, dynamic> json,
  String device,
) => [
  for (final e in (json['playlists'] as List).cast<Map>())
    RecentPlaylistPlayback(
      id: e['id'] as int,
      playlistId: remotePlaylistHistoryId(device, e['item'] as int),
      playedAt: e['time'] as String,
    ),
];

List<RecentAlbumPlayback> _recentAlbums(Map<String, dynamic> json) => [
  for (final e in (json['albums'] as List).cast<Map>())
    RecentAlbumPlayback(
      id: e['id'] as int,
      album: e['item'] as String,
      playedAt: e['time'] as String,
    ),
];

List<RecentArtistPlayback> _recentArtists(Map<String, dynamic> json) => [
  for (final e in (json['artists'] as List).cast<Map>())
    RecentArtistPlayback(
      id: e['id'] as int,
      artist: e['item'] as String,
      playedAt: e['time'] as String,
    ),
];

List<RecentNowPlayingSnapshot> _recentQueueHistory(
  Map<String, dynamic> json,
  Map<int, LibrarySong> byHost,
  String device,
) => [
  // Queue history is absent on older sharing hosts.
  if (json['nowPlayingHistory'] case final List entries)
    for (final entry in entries.cast<Map>())
      RecentNowPlayingSnapshot(
        id: entry['id'] as int,
        playlistId: remotePlaylistHistoryId(device, entry['playlist'] as int),
        songIds: [
          for (final id in (entry['songs'] as List).cast<int>())
            if (byHost[id] case final song?) song.id,
        ],
        createdAt: entry['time'] as String,
      ),
];

Future<({List<RecentBrowseEntry> entries, List<LibrarySong> songs})>
readRecentBrowseSection(LibraryRepository repository, String device) async {
  if (device == 'local') return readLocalRecentBrowses(repository);
  final json = await remoteHistory(device, 'getBrowses');
  final songs = await _readRemoteHistorySongs(repository, device, json);
  return (
    entries: _recentBrowses(json, songs, device),
    songs: songs.values.toList(),
  );
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
readRecentPlayedSection(LibraryRepository repository, String device) async {
  if (device == 'local') return readLocalRecentPlayed(repository);
  final json = await remoteHistory(device, 'getPlayed');
  final songs = await _readRemoteHistorySongs(repository, device, json);
  return (
    songs: _recentSongs(json, songs),
    playlists: _recentPlaylists(json, device),
    albums: _recentAlbums(json),
    artists: _recentArtists(json),
    nowPlaying: _recentQueueHistory(json, songs, device),
    queueSongs: songs.values.toList(),
  );
}
