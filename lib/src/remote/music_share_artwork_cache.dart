import 'dart:io';

import 'package:path/path.dart' as p;

import 'music_share_identity.dart';
import 'music_share_models.dart';

class MusicShareArtworkCache {
  MusicShareArtworkCache(this.directory);

  final Directory directory;
  final _files = <String, File>{};
  final _loads = <String, Future<File?>>{};
  final _transports = <String, MusicShareTransport>{};

  // The catalog revision identifies the host's artwork path, shared by songs
  // using the same cover. Paths without a revision remain scoped to the song.
  String _key(Uri uri) =>
      '${uri.host}-${uri.queryParameters['art'] ?? uri.pathSegments.single}';

  File? cached(String path) => _files[_key(Uri.parse(path))];

  Future<File?> load(String path, MusicPeer peer) {
    final uri = Uri.parse(path);
    final key = _key(uri);
    final cachedFile = _files[key];
    if (cachedFile != null) return Future.value(cachedFile);
    return _loads.putIfAbsent(key, () async {
      try {
        final file = await _download(uri, key, _transport(peer));
        if (file != null) _files[key] = file;
        return file;
      } finally {
        _loads.remove(key);
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
      maxConnectionsPerHost: 4,
    );
  }

  Future<File?> _download(
    Uri uri,
    String key,
    MusicShareTransport transport,
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
      await response.drain<void>();
      return null;
    }
    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>();
      throw const MusicShareException('share.connectionFailed');
    }
    await directory.create(recursive: true);
    final pending = File('${file.path}.part');
    try {
      await response.pipe(pending.openWrite());
      return await pending.rename(file.path);
    } finally {
      if (await pending.exists()) await pending.delete();
    }
  }

  void disconnect(String peerId) {
    _transports.remove(peerId)?.close();
  }

  void dispose() {
    for (final transport in _transports.values) {
      transport.close();
    }
    _transports.clear();
    _files.clear();
  }
}
