import 'dart:async';
import 'dart:convert';
import '../platform/system_log.dart';
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
    required this.isCurrent,
  });
  final void Function(MusicPeer, Object, StackTrace)? onNetworkError;
  final bool Function(MusicPeer) isCurrent;
  final LibraryRepository repository;
  final void Function() changed;
  final void Function() permissionChanged;
  final _lists = <String, List<LibraryPlaylist>>{};
  final _signatures = <String, String>{};
  final _submitting = <MusicPeer>{};
  final _requests = <MusicShareTransport, MusicPeer>{};
  final _queues = <String, Future<void>>{};
  final _locations = <int, (String, int)>{};
  final _generations = <String, int>{};
  final _reads = <(MusicPeer, int), Future<bool>>{};
  bool isFresh(String device) => _signatures.containsKey(device);
  bool hasLoaded(String device) => _lists.containsKey(device);
  List<LibraryPlaylist> forDevice(String device) => _lists[device] ?? const [];

  List<LibraryPlaylist> get playlists =>
      _lists.values.expand((v) => v).toList();

  Future<Map<String, dynamic>> _request(
    MusicPeer peer, {
    Map<String, dynamic>? body,
  }) async {
    if (!isCurrent(peer)) {
      throw const MusicShareException('share.deviceForgotten');
    }
    final transport = MusicShareTransport(
      peer.address,
      fingerprint: peer.fingerprint,
      token: peer.token,
      onNetworkError:
          (error, stack) => onNetworkError?.call(peer, error, stack),
    );
    _requests[transport] = peer;
    try {
      final result = await transport.json(
        '/playlists?revision=${peer.catalogRevision ?? ''}',
        method: body == null ? 'GET' : 'POST',
        body: body,
      );
      if (body != null) {
        SystemLog.info(
          'Remote playlist mutation response received: '
          'device=${peer.name}; operation=${body['operation']}',
        );
      }
      return result;
    } on MusicShareException catch (error, stack) {
      if (!isCurrent(peer)) {
        throw const MusicShareException('share.deviceForgotten');
      }
      SystemLog.error(
        'Remote playlist request rejected: device=${peer.name}; '
        'operation=${body?['operation'] ?? 'read'}',
        error,
        stack,
      );
      if (error.messageKey == 'share.readOnlyPermission' && peer.canWrite) {
        peer.canWrite = false;
        permissionChanged();
      }
      rethrow;
    } catch (error, stack) {
      if (!isCurrent(peer)) {
        throw const MusicShareException('share.deviceForgotten');
      }
      SystemLog.error(
        'Remote playlist request failed: device=${peer.name}; '
        'operation=${body?['operation'] ?? 'read'}',
        error,
        stack,
      );
      rethrow;
    } finally {
      _requests.remove(transport);
      transport.close();
    }
  }

  Future<T> _serial<T>(String device, Future<T> Function() action) {
    final operation = (_queues[device] ?? Future<void>.value()).then(
      (_) => action(),
    );
    final tail = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    _queues[device] = tail;
    unawaited(
      tail.whenComplete(() {
        if (identical(_queues[device], tail)) _queues.remove(device);
      }),
    );
    return operation;
  }

  Future<bool> refresh(MusicPeer peer, {bool Function()? canApply}) {
    if (canApply != null) {
      return _serial(peer.id, () => _refresh(peer, canApply: canApply));
    }
    final key = (peer, _generations[peer.id] ?? 0);
    return _reads.putIfAbsent(key, () async {
      try {
        return await _serial(peer.id, () => _refresh(peer));
      } finally {
        _reads.remove(key);
      }
    });
  }

  Future<bool> _refresh(MusicPeer peer, {bool Function()? canApply}) async {
    bool current() => isCurrent(peer) && (canApply?.call() ?? true);
    final generation = _generations[peer.id] ?? 0;
    final result = await _request(peer);
    if (!current()) return false;
    await _apply(peer, result, current);
    if (!current()) return false;
    peer.catalogRevision = result['revision'] as String;
    if (result.containsKey('songs')) peer.catalogLoaded = true;
    if ((_generations[peer.id] ?? 0) != generation) {
      _signatures.remove(peer.id);
    }
    return result.containsKey('songs');
  }

  Future<void> _apply(
    MusicPeer peer,
    Map<String, dynamic> result,
    bool Function() current,
  ) async {
    final device = peer.id;
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
        isCurrent: current,
      );
    }
    if (!current()) return;
    final songs = await repository.getLibrarySongs();
    if (!current()) return;
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
    if (result.containsKey('songs')) peer.catalogLoaded = true;
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
    if (!_submitting.add(peer)) {
      throw const MusicShareException('song.processingRequest');
    }
    invalidate(peer.id);
    try {
      return await _serial(
        peer.id,
        () => _operate(
          peer,
          operation,
          playlistId: playlistId,
          name: name,
          songIds: songIds,
          playlistIds: playlistIds,
          restore: restore,
          criterion: criterion,
        ),
      );
    } finally {
      _submitting.remove(peer);
    }
  }

  Future<LibraryPlaylist?> _operate(
    MusicPeer peer,
    String operation, {
    int? playlistId,
    String? name,
    List<int> songIds = const [],
    List<int> playlistIds = const [],
    LibraryPlaylist? restore,
    PlaylistSortCriterion? criterion,
  }) async {
    if (!isCurrent(peer)) {
      throw const MusicShareException('share.deviceForgotten');
    }
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
    final baseLists = [...?_lists[peer.id]];
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
    if (!isCurrent(peer)) {
      throw const MusicShareException('share.deviceForgotten');
    }
    final lists = baseLists;
    final index = lists.indexWhere((p) => p.id == playlistId);
    LibraryPlaylist? created;
    switch (operation) {
      case 'create':
        for (var i = 0; i < lists.length; i++) {
          lists[i] = lists[i].copyWith(priority: lists[i].priority + 1);
        }
        final raw = (result['created'] as Map).cast<String, dynamic>();
        final hostId = raw['id'] as int;
        final path = '$remoteMusicScheme://${peer.id}/playlists/$hostId';
        final id =
            -int.parse(shareDigest(path).substring(0, 15), radix: 16) - 1;
        created = LibraryPlaylist(
          id: id,
          remotePath: path,
          name: raw['name'] as String,
          priority: raw['priority'] as int,
          songCount: songIds.length,
          songIds: songIds,
          sortCriterion: PlaylistSortCriterion.values[raw['criterion'] as int],
          isBuiltIn: false,
        );
        _locations[id] = (peer.id, hostId);
        lists.removeWhere((p) => p.id == id);
        lists.insert(0, created);
      case 'delete':
        lists.removeWhere((p) => p.id == playlistId);
      case 'restore':
        lists.removeWhere((p) => p.id == restore!.id);
        for (var i = 0; i < lists.length; i++) {
          lists[i] = lists[i].copyWith(priority: lists[i].priority + 1);
        }
        lists.add(restore!);
      case 'order':
        final priorities = {
          for (var i = 0; i < playlistIds.length; i++) playlistIds[i]: i,
        };
        for (var i = 0; i < lists.length; i++) {
          if (priorities.containsKey(lists[i].id)) {
            lists[i] = lists[i].copyWith(priority: priorities[lists[i].id]!);
          }
        }
      case 'rename':
        lists[index] = lists[index].copyWith(name: name!);
      case 'add':
        final ids = {...lists[index].songIds, ...songIds}.toList();
        lists[index] = lists[index].copyWith(
          songIds: ids,
          songCount: ids.length,
        );
      case 'remove':
        final removed = songIds.toSet();
        final ids =
            lists[index].songIds.where((id) => !removed.contains(id)).toList();
        lists[index] = lists[index].copyWith(
          songIds: ids,
          songCount: ids.length,
        );
      case 'reorder':
        lists[index] = lists[index].copyWith(
          songIds: songIds,
          sortCriterion: criterion,
        );
    }
    _lists[peer.id] = lists;
    _signatures.remove(peer.id);
    unawaited(
      Future<void>(() {
        if (isCurrent(peer)) changed();
      }).catchError((Object error, StackTrace stack) {
        SystemLog.error(
          'Remote playlist cache notification failed',
          error,
          stack,
        );
      }),
    );
    return created;
  }

  void invalidate(String device) {
    _generations.update(device, (value) => value + 1, ifAbsent: () => 1);
    _signatures.remove(device);
  }

  void forget(String device) {
    for (final transport
        in _requests.entries
            .where((entry) => entry.value.id == device)
            .map((entry) => entry.key)
            .toList()) {
      transport.close();
    }
    _lists.remove(device);
    _generations.remove(device);
    _signatures.remove(device);
    _locations.removeWhere((_, value) => value.$1 == device);
    changed();
  }
}
