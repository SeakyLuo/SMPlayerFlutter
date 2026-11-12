import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../library/data/library_models.dart';
import '../library/data/library_repository.dart';
import 'music_share_access.dart';
import 'music_share_artwork_cache.dart';
import 'music_share_catalog.dart';
import 'music_share_identity.dart';
import 'music_share_models.dart';
import 'music_share_server.dart';

class MusicShareController extends ChangeNotifier implements MusicShareAccess {
  MusicShareController(
    this.repository,
    this.onCatalogChanged, {
    required this.loadLibrary,
  }) {
    ready = _load();
    startup = ready.then((_) async {
      busy = true;
      try {
        if (sharing) await server.start(port: port);
      } finally {
        busy = false;
        _notify();
      }
    });
  }

  final LibraryRepository repository;
  final VoidCallback onCatalogChanged;
  final Future<LibraryContentData> Function() loadLibrary;
  late final Future<void> ready;
  late final Future<void> startup;
  late MusicShareIdentity identity;
  late MusicShareServer server;
  late String databasePath;
  final peers = <MusicPeer>[];
  final discovered = <DiscoveredMusicHost>[];
  final grants = <String, String>{};
  final writeGrants = <String>{};
  final permissionChanges = <String>{};
  var name = Platform.localHostname;
  var selectedSource = 'local';
  var sharing = false;
  var port = musicSharePort;
  var busy = false;
  var initialized = false;
  var _disposed = false;
  Future<void>? _shutdownFuture;
  Future<void> _savePending = Future.value();
  Timer? _connectionTimer;
  var _checking = false;
  HttpServer? _proxy;
  final _proxySecret = newShareSecret();
  final _proxyTransports = <MusicShareTransport>{};
  late final _artworkCache = MusicShareArtworkCache(
    Directory(p.join(p.dirname(databasePath), 'remote-artwork')),
  );

  Future<void> _load() async {
    final (snapshot, loadedIdentity, stored) =
        await (
          loadLibrary(),
          MusicShareIdentity.load(),
          MusicShareIdentity.storage.read(key: 'music-share-connections-v1'),
        ).wait;
    databasePath = snapshot.databasePath;
    identity = loadedIdentity;
    if (stored != null) {
      final json = jsonDecode(stored) as Map<String, dynamic>;
      name = json['name'] as String;
      selectedSource = json['source'] as String;
      sharing = json['sharing'] as bool;
      port = json['port'] as int? ?? musicSharePort;
      grants.addAll((json['grants'] as Map).cast<String, String>());
      // Older saved authorizations grant playback only.
      if (json.containsKey('writeGrants')) {
        writeGrants.addAll((json['writeGrants'] as List).cast<String>());
      }
      peers.addAll(
        (json['peers'] as List).map(
          (item) => MusicPeer.fromJson((item as Map).cast<String, dynamic>()),
        ),
      );
    }
    server = MusicShareServer(
      onLibraryChanged: onCatalogChanged,
      identity: identity,
      repository: repository,
      name: () => name,
      grants: grants,
      writeGrants: writeGrants,
      onChanged: () {
        _notify();
      },
    );
    server.updateLibrary(snapshot);
    initialized = true;
    _notify();
    _connectionTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      unawaited(checkConnections());
    });
    unawaited(checkConnections());
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> save() {
    final value = jsonEncode({
      'name': name,
      'source': selectedSource,
      'sharing': sharing,
      'port': port,
      'grants': grants,
      'writeGrants': writeGrants.toList(),
      'peers': peers.map((peer) => peer.toJson()).toList(),
    });
    final operation = _savePending.then(
      (_) => MusicShareIdentity.storage.write(
        key: 'music-share-connections-v1',
        value: value,
      ),
    );
    _savePending = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return operation;
  }

  Future<void> selectSource(String source) async {
    selectedSource = source;
    _notify();
    await save();
    final peer = peers.where((peer) => peer.id == source).firstOrNull;
    if (peer != null) await syncPeer(peer);
  }

  bool includes(LibrarySong song) {
    if (selectedSource == 'all') return true;
    if (selectedSource == 'local') return !isRemoteMusicPath(song.path);
    return isRemoteMusicPath(song.path) &&
        Uri.parse(song.path).host == selectedSource;
  }

  Future<void> setSharing(bool enabled) async {
    if (!initialized) await ready;
    busy = true;
    _notify();
    try {
      if (enabled) {
        final settings = await repository.readSettingsSnapshot();
        if (settings.rootPath.isEmpty) {
          throw const MusicShareException('share.chooseLibraryFirst');
        }
        await server.start(port: port);
      } else {
        await server.stop();
      }
      sharing = enabled;
      await save();
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> setPort(int value) async {
    busy = true;
    _notify();
    final previous = port;
    try {
      if (server.running) await server.changePort(value);
      port = value;
      try {
        await save();
      } catch (_) {
        port = previous;
        if (server.running) await server.changePort(previous);
        rethrow;
      }
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> approve(String key, bool allow, {bool canWrite = false}) async {
    await server.approve(key, allow, persist: save, canWrite: canWrite);
  }

  Future<void> revoke(String hash) async {
    try {
      await server.revoke(hash);
    } finally {
      await save();
    }
  }

  Future<void> setWritePermission(String hash, bool enabled) async {
    final previous = writeGrants.contains(hash);
    permissionChanges.add(hash);
    enabled ? writeGrants.add(hash) : writeGrants.remove(hash);
    _notify();
    try {
      await save();
    } catch (_) {
      previous ? writeGrants.add(hash) : writeGrants.remove(hash);
      rethrow;
    } finally {
      permissionChanges.remove(hash);
      _notify();
    }
  }

  @override
  bool canWrite(String path) => peers.any(
    (peer) =>
        peer.id == Uri.parse(path).host &&
        peer.canWrite &&
        peer.status != MusicPeerStatus.unauthorized,
  );

  Future<void> forget(MusicPeer peer) async {
    _artworkCache.disconnect(peer.id);
    peers.remove(peer);
    for (final transport
        in _proxyTransports
            .where((item) => item.address == peer.address)
            .toList()) {
      transport.close();
    }
    if (selectedSource == peer.id) selectedSource = 'local';
    await save();
    _notify();
  }

  Future<void> discover() async {
    await ready;
    discovered.clear();
    _notify();
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    socket.broadcastEnabled = true;
    var addressChanged = false;
    final subscription = socket.listen((event) {
      if (event != RawSocketEvent.read) return;
      final datagram = socket.receive();
      if (datagram == null || datagram.data.length > 2048) return;
      try {
        final json =
            jsonDecode(utf8.decode(datagram.data)) as Map<String, dynamic>;
        if (json['protocol'] != 'smplayer-music-v1' ||
            json['id'] == identity.id) {
          return;
        }
        final id = json['id'] as String;
        final address = 'https://${datagram.address.address}:${json['port']}';
        final peer = peers.where((peer) => peer.id == id).firstOrNull;
        if (peer != null && peer.address != address) {
          // Discovery is only an address hint. TLS still checks the paired key.
          peer.address = address;
          addressChanged = true;
        }
        if (discovered.any((host) => host.id == id)) return;
        discovered.add(
          DiscoveredMusicHost(id, json['name'] as String, address),
        );
        _notify();
      } on FormatException {
        return;
      } on TypeError {
        return;
      }
    });
    try {
      socket.send(
        utf8.encode('SMPLAYER_DISCOVER_V1'),
        InternetAddress('255.255.255.255'),
        musicDiscoveryPort,
      );
      await Future<void>.delayed(const Duration(seconds: 3));
    } finally {
      await subscription.cancel();
      socket.close();
    }
    if (addressChanged) await save();
  }

  Future<void> checkConnections() async {
    if (_checking || _disposed) return;
    _checking = true;
    try {
      if (peers.any((peer) => peer.status == MusicPeerStatus.offline)) {
        try {
          await discover();
        } on SocketException {
          // UDP discovery may be unavailable; saved HTTPS addresses still work.
        }
      }
      await Future.wait(
        peers.map((peer) async {
          final previous = peer.status;
          try {
            await syncPeer(
              peer,
              importCatalog: previous != MusicPeerStatus.online,
            );
          } catch (_) {
            // Background checks update connection state; user actions show a toast.
          }
        }),
      );
    } finally {
      _checking = false;
    }
  }

  Future<void> syncPeer(MusicPeer peer, {bool importCatalog = true}) async {
    final transport = MusicShareTransport(
      peer.address,
      fingerprint: peer.fingerprint,
      token: peer.token,
    );
    final previous = peer.status;
    try {
      final status = await transport.json('/status');
      final canWrite = status['canWrite'] == true;
      if (peer.canWrite != canWrite) {
        peer.canWrite = canWrite;
        _notify();
      }
      final revision = status['revision'] as String;
      final updatedName = status['name'] as String;
      if (updatedName != peer.name) {
        peer.name = updatedName;
        await save();
        _notify();
      }
      if (importCatalog || peer.catalogRevision != revision) {
        final page = await transport.json('/catalog');
        final songs =
            (page['songs'] as List)
                .map((item) => (item as Map).cast<String, dynamic>())
                .toList();
        await importMusicShareCatalog(databasePath, peer.id, songs);
        peer.catalogRevision = revision;
        onCatalogChanged();
      }
      peer.status = MusicPeerStatus.online;
    } on MusicShareException catch (error) {
      peer.status =
          error.messageKey == 'share.authorizationRequired'
              ? MusicPeerStatus.unauthorized
              : MusicPeerStatus.offline;
      rethrow;
    } catch (_) {
      peer.status = MusicPeerStatus.offline;
      rethrow;
    } finally {
      transport.close();
      if (previous != peer.status) _notify();
    }
  }

  Future<MusicPeer> finishPairing(
    MusicShareTransport transport,
    String secret,
    Map<String, dynamic> host,
    bool Function() canceled,
  ) async {
    final deadline = DateTime.now().add(const Duration(minutes: 2));
    while (!canceled() && DateTime.now().isBefore(deadline)) {
      final state = await transport.json(
        '/pair/status',
        method: 'POST',
        body: {'secret': secret},
      );
      if (canceled()) throw const MusicShareException('share.pairingEnded');
      if (state['state'] == 'approved') {
        final peer = MusicPeer(
          id: host['id'] as String,
          name: host['name'] as String,
          address: transport.address,
          fingerprint: transport.observedFingerprint!,
          token: state['token'] as String,
        );
        peers.removeWhere((item) => item.id == peer.id);
        peers.add(peer);
        await save();
        await selectSource(peer.id);
        return peer;
      }
      if (state['state'] != 'pending') {
        throw const MusicShareException('share.pairingEnded');
      }
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    throw const MusicShareException('share.pairingEnded');
  }

  MusicPeer peerFor(String path) {
    final id = Uri.parse(path).host;
    final peer = peers.where((peer) => peer.id == id).firstOrNull;
    if (peer == null || peer.status == MusicPeerStatus.unauthorized) {
      throw const MusicShareException('share.authorizationRequired');
    }
    return peer;
  }

  @override
  Future<Uri> audioUri(String path) async {
    await ready;
    final peer = peerFor(path);
    await syncPeer(peer, importCatalog: false);
    _proxy ??= await HttpServer.bind(InternetAddress.loopbackIPv4, 0)
      ..listen((request) => unawaited(_serveProxy(request)));
    final song = Uri.parse(path).pathSegments.single;
    return Uri.parse(
      'http://127.0.0.1:${_proxy!.port}/$_proxySecret/${peer.id}/$song',
    );
  }

  Future<void> _serveProxy(HttpRequest request) async {
    MusicShareTransport? transport;
    var streaming = false;
    try {
      final segments = request.uri.pathSegments;
      if (segments.length != 3 ||
          segments[0] != _proxySecret ||
          request.headers.value('origin') != null ||
          (request.method != 'GET' && request.method != 'HEAD')) {
        request.response.statusCode = HttpStatus.forbidden;
        return;
      }
      final peer = peerFor(
        remoteMusicPath(segments[1], int.parse(segments[2])),
      );
      transport = MusicShareTransport(
        peer.address,
        fingerprint: peer.fingerprint,
        token: peer.token,
      );
      _proxyTransports.add(transport);
      final response = await transport.open(
        '/songs/${segments[2]}/audio',
        method: request.method,
        range: request.headers.value(HttpHeaders.rangeHeader),
      );
      request.response.statusCode = response.statusCode;
      for (final header in [
        HttpHeaders.contentTypeHeader,
        HttpHeaders.contentLengthHeader,
        HttpHeaders.contentRangeHeader,
        HttpHeaders.acceptRangesHeader,
      ]) {
        final value = response.headers.value(header);
        if (value != null) request.response.headers.set(header, value);
      }
      streaming = true;
      await request.response.addStream(response);
    } catch (_) {
      if (!streaming) request.response.statusCode = HttpStatus.badGateway;
      // Closing an incomplete stream lets the backend report an interruption.
    } finally {
      if (transport != null) {
        _proxyTransports.remove(transport);
        transport.close();
      }
      await request.response.close();
    }
  }

  @override
  File? cachedArtwork(String path) =>
      initialized ? _artworkCache.cached(path) : null;

  @override
  Future<File?> artwork(String path) async {
    await ready;
    return _artworkCache.load(path, peerFor(path));
  }

  @override
  Future<Map<String, dynamic>> songRequest(
    String path,
    String resource, {
    String method = 'GET',
    Object? body,
  }) async {
    final peer = peerFor(path);
    if (method != 'GET' && !peer.canWrite) {
      throw const MusicShareException('share.readOnlyPermission');
    }
    final transport = MusicShareTransport(
      peer.address,
      fingerprint: peer.fingerprint,
      token: peer.token,
    );
    try {
      final id = Uri.parse(path).pathSegments.single;
      final result = await transport.json(
        '/songs/$id/$resource',
        method: method,
        body: body,
      );
      if (method != 'GET') unawaited(checkConnections());
      return result;
    } on MusicShareException catch (error) {
      if (error.messageKey == 'share.readOnlyPermission') {
        peer.canWrite = false;
        _notify();
      }
      rethrow;
    } finally {
      transport.close();
    }
  }

  @override
  Future<LyricsSnapshot> lyrics(String path) async {
    await ready;
    final peer = peerFor(path);
    final remoteId = Uri.parse(path).pathSegments.single;
    final transport = MusicShareTransport(
      peer.address,
      fingerprint: peer.fingerprint,
      token: peer.token,
    );
    try {
      final json = await transport.json('/songs/$remoteId/lyrics');
      return LyricsSnapshot(
        source: LyricsSource.lrcFile,
        isSynced: json['isSynced'] as bool,
        rawText: json['rawText'] as String,
        lines: [
          for (final item in json['lines'] as List)
            LyricsLine(
              id: item['id'] as int,
              timestampMs: item['time'] as int?,
              text: item['text'] as String,
            ),
        ],
      );
    } finally {
      transport.close();
    }
  }

  Future<void> shutdown() => _shutdownFuture ??= _shutdown();

  Future<void> _shutdown() async {
    _disposed = true;
    // Startup may already have failed; shutdown must still release resources.
    await startup.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    _connectionTimer?.cancel();
    if (initialized) _artworkCache.dispose();
    for (final transport in _proxyTransports) {
      transport.close();
    }
    await Future.wait([
      if (_proxy != null) _proxy!.close(force: true),
      if (initialized) server.stop(),
    ]);
  }

  @override
  void dispose() {
    unawaited(shutdown());
    super.dispose();
  }
}
