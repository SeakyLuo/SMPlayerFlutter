import 'dart:convert';
import '../library/data/library_models.dart';
import '../library/data/library_repository.dart';
import 'music_share_identity.dart';
import 'music_share_models.dart';
import 'music_share_catalog.dart';

class MusicSharePlaylistClient {
  MusicSharePlaylistClient(
    this.repository,
    this.changed,
    this.permissionChanged, {
    this.onNetworkError,
  });
  final void Function(MusicPeer, Object, StackTrace)? onNetworkError;
  final LibraryRepository repository;
  final void Function() changed;
  final void Function() permissionChanged;
  final _lists = <String, List<LibraryPlaylist>>{};
  final _signatures = <String, String>{};
  final _locations = <int, (String, int)>{};
  List<LibraryPlaylist> get playlists =>
      _lists.values.expand((v) => v).toList();

  Future<Map<String, dynamic>> _request(
    MusicPeer peer, {
    Map<String, dynamic>? body,
  }) async {
    final transport = MusicShareTransport(
      peer.address,
      fingerprint: peer.fingerprint,
      token: peer.token,
      onNetworkError:
          (error, stack) => onNetworkError?.call(peer, error, stack),
    );
    try {
      return await transport.json(
        '/playlists?revision=${peer.catalogRevision ?? ''}',
        method: body == null ? 'GET' : 'POST',
        body: body,
      );
    } on MusicShareException catch (error) {
      if (error.messageKey == 'share.readOnlyPermission' && peer.canWrite) {
        peer.canWrite = false;
        permissionChanged();
      }
      rethrow;
    } finally {
      transport.close();
    }
  }

  Future<void> refresh(MusicPeer peer) async {
    final result = await _request(peer);
    await _apply(peer.id, result);
    peer.catalogRevision = result['revision'] as String;
  }

  Future<void> _apply(String device, Map<String, dynamic> result) async {
    final signature = shareDigest(
      jsonEncode([result['revision'], result['playlists']]),
    );
    if (_signatures[device] == signature) return;
    if (result.containsKey('songs')) {
      await importMusicShareCatalog(
        await repository.getDatabasePath(),
        device,
        (result['songs'] as List)
            .map((s) => (s as Map).cast<String, dynamic>())
            .toList(),
      );
    }
    final songs = await repository.getLibrarySongs();
    final localIds = <int, int>{};
    for (final song in songs) {
      if (isRemoteMusicPath(song.path)) {
        final uri = Uri.parse(song.path);
        if (uri.host == device) {
          localIds[int.parse(uri.pathSegments.single)] = song.id;
        }
      }
    }
    final lists = <LibraryPlaylist>[];
    for (final raw in result['playlists'] as List) {
      final json = raw as Map;
      final hostId = json['id'] as int;
      final path = '$remoteMusicScheme://$device/playlists/$hostId';
      final id = -int.parse(shareDigest(path).substring(0, 15), radix: 16) - 1;
      _locations[id] = (device, hostId);
      final ids =
          (json['songs'] as List)
              .cast<int>()
              .map((id) => localIds[id]!)
              .toList();
      lists.add(
        LibraryPlaylist(
          id: id,
          remotePath: path,
          name: json['name'] as String,
          priority: json['priority'] as int,
          songCount: ids.length,
          songIds: ids,
          sortCriterion: PlaylistSortCriterion.values[json['criterion'] as int],
          isBuiltIn: false,
        ),
      );
    }
    _lists[device] = lists;
    _signatures[device] = signature;
    changed();
  }

  Future<LibraryPlaylist?> operate(
    MusicPeer peer,
    String operation, {
    int? playlistId,
    String? name,
    List<int> songIds = const [],
    List<int> playlistIds = const [],
    LibraryPlaylist? restore,
    PlaylistSortCriterion? criterion,
  }) async {
    if (!peer.canWrite) {
      throw const MusicShareException('share.readOnlyPermission');
    }
    if (!peer.supportsPlaylists) {
      throw const MusicShareException('share.playlistUpgradeRequired');
    }
    if (playlistId != null && _locations[playlistId]!.$1 != peer.id) {
      throw const MusicShareException('share.sameDeviceSongs');
    }
    final songs =
        songIds.isEmpty
            ? <LibrarySong>[]
            : await repository.getLibrarySongs(songIds: songIds);
    if (songs.length != songIds.toSet().length ||
        songs.any(
          (s) =>
              !isRemoteMusicPath(s.path) || Uri.parse(s.path).host != peer.id,
        )) {
      throw const MusicShareException('share.sameDeviceSongs');
    }
    final hostSongs =
        songs
            .map((s) => int.parse(Uri.parse(s.path).pathSegments.single))
            .toList();
    // Preserve the caller's order rather than the repository's song order.
    final byLocal = {
      for (var i = 0; i < songs.length; i++) songs[i].id: hostSongs[i],
    };
    final result = await _request(
      peer,
      body: {
        'operation': operation,
        'id': playlistId == null ? null : _locations[playlistId]!.$2,
        'name': name ?? restore?.name,
        'songs': songIds.map((id) => byLocal[id]!).toList(),
        'ids':
            playlistIds.map((id) {
              final location = _locations[id]!;
              if (location.$1 != peer.id) {
                throw const MusicShareException('share.sameDeviceSongs');
              }
              return location.$2;
            }).toList(),
        'priority': restore?.priority,
        'criterion': criterion?.index ?? restore?.sortCriterion.index,
      },
    );
    await _apply(peer.id, result);
    peer.catalogRevision = result['revision'] as String;
    final created = result['created'] as int?;
    if (created == null) return null;
    return _lists[peer.id]!.firstWhere((p) => _locations[p.id]!.$2 == created);
  }

  void invalidate(String device) {
    _signatures.remove(device);
  }

  void forget(String device) {
    _lists.remove(device);
    _signatures.remove(device);
    _locations.removeWhere((_, value) => value.$1 == device);
    changed();
  }
}
