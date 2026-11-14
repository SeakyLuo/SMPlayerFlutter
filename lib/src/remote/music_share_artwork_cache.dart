import 'dart:io';

import 'package:path/path.dart' as p;

import 'music_share_identity.dart';
import 'music_share_models.dart';

const _artworkIdleTimeout = Duration(seconds: 15);

class MusicShareArtworkCache {
  MusicShareArtworkCache(this.directory, {this.onNetworkError});

  final void Function(MusicPeer, Object, StackTrace)? onNetworkError;

  final Directory directory;
  final _files = <String, File>{};
  final _generations = <String, int>{};
  final _loads = <String, Future<File?>>{};
  final _transports = <String, MusicShareTransport>{};

  Future<void> restore() async {
    if (!await directory.exists()) return;
    await for (final entry in directory.list()) {
      if (entry is File && p.extension(entry.path) == '.img') {
        _files[p.basenameWithoutExtension(entry.path)] = entry;
      }
    }
  }

  // The catalog revision identifies the host's artwork path, shared by songs
  // using the same cover. Paths without a revision remain scoped to the song.
  String _key(Uri uri) =>
      '${uri.host}-${uri.queryParameters['art'] ?? uri.pathSegments.single}';

  File? cached(String path) => _files[_key(Uri.parse(path))];

  Future<File?> load(String path, MusicPeer peer) {
    final uri = Uri.parse(path);
    final key = _key(uri);
    final generation = _generations[peer.id] ?? 0;
    bool isCurrent() => (_generations[peer.id] ?? 0) == generation;
    final cachedFile = _files[key];
    if (cachedFile != null) return Future.value(cachedFile);
    return _loads.putIfAbsent(key, () async {
      try {
        final file = await _download(uri, key, _transport(peer), isCurrent);
        if (!isCurrent()) return null;
        if (file != null) _files[key] = file;
        return file;
      } finally {
        if (isCurrent()) _loads.remove(key);
      }
    });
  }

  MusicShareTransport _transport(MusicPeer peer) {
    final existing = _transports[peer.id];
    if (existing != null &&
        existing.address == peer.address &&
        existing.fingerprint == peer.fingerprint &&
        existing.token == peer.token) {
      return existing;
    }
    existing?.close();
    return _transports[peer.id] = MusicShareTransport(
      peer.address,
      fingerprint: peer.fingerprint,
      token: peer.token,
      onNetworkError:
          (error, stack) => onNetworkError?.call(peer, error, stack),
      maxConnectionsPerHost: 4,
    );
  }

  Future<File?> _download(
    Uri uri,
    String key,
    MusicShareTransport transport,
    bool Function() isCurrent,
  ) async {
    final file = File(p.join(directory.path, '$key.img'));
    if (await file.exists()) return file;

    // Retain covers downloaded before the cache was shared across songs.
    final remoteId = uri.pathSegments.single;
    final previous = File(
      p.join(
        directory.path,
        '${uri.host}-$remoteId-${uri.queryParameters['art'] ?? 'original'}.img',
      ),
    );
    if (await previous.exists()) return previous.rename(file.path);

    final response = await transport.open('/songs/$remoteId/artwork');
    if (response.statusCode == HttpStatus.notFound) {
      await transport.runNetworkOperation(
        () => response.timeout(_artworkIdleTimeout).drain<void>(),
      );
      return null;
    }
    if (response.statusCode != HttpStatus.ok) {
      await transport.runNetworkOperation(
        () => response.timeout(_artworkIdleTimeout).drain<void>(),
      );
      throw const MusicShareException('share.connectionFailed');
    }
    await directory.create(recursive: true);
    final pending = File('${file.path}.part');
    try {
      await transport.runNetworkOperation(() async {
        final sink = pending.openWrite();
        try {
          await sink.addStream(response.timeout(_artworkIdleTimeout));
        } finally {
          await sink.close();
        }
      });
      if (!isCurrent()) return null;
      return await pending.rename(file.path);
    } finally {
      if (await pending.exists()) await pending.delete();
    }
  }

  Future<void> disconnect(String peerId) async {
    final prefix = '$peerId-';
    final pending =
        _loads.entries
            .where((entry) => entry.key.startsWith(prefix))
            .map((entry) => entry.value)
            .toList();
    _generations.update(peerId, (value) => value + 1, ifAbsent: () => 1);
    _loads.removeWhere((key, _) => key.startsWith(prefix));
    _files.removeWhere((key, _) => key.startsWith(prefix));
    _transports.remove(peerId)?.close();
    await Future.wait(
      pending.map(
        (load) =>
            load.then<void>((_) {}, onError: (Object _, StackTrace __) {}),
      ),
    );
  }

  void dispose() {
    for (final transport in _transports.values) {
      transport.close();
    }
    _transports.clear();
    _files.clear();
  }
}
