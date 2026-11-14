import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../library/data/library_models.dart';
import '../library/data/library_repository.dart';
import '../library/data/library_snapshot_service.dart';
import '../platform/system_log.dart';
import 'music_share_access.dart';
import 'music_share_artwork_cache.dart';
import 'music_share_catalog.dart';
import 'music_share_identity.dart';
import 'music_share_models.dart';
import 'music_share_server.dart';
import 'music_share_playlist_client.dart';

part 'music_share_controller_authorization.dart';
part 'music_share_controller_connections.dart';
part 'music_share_controller_events.dart';

class MusicShareController extends ChangeNotifier
    with _MusicShareAuthorization
    implements MusicShareAccess {
  MusicShareController(
    this.repository,
    this.onCatalogChanged, {
    required this.loadLibrary,
  }) {
    ready = _load();
    initialConnection = ready.then((_) => checkConnections()).whenComplete(() {
      _initialConnectionDone = true;
      _notify();
    });
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
  late final Future<void> initialConnection;
  late final Future<void> startup;
  late MusicShareIdentity identity;
  @override
  late MusicShareServer server;
  late String databasePath;
  final peers = <MusicPeer>[];
  final discovered = <DiscoveredMusicHost>[];
  final grants = <String, String>{};
  final grantIdentities = <String, String>{};
  final mobileGrants = <String>{};
  @override
  final writeGrants = <String>{};
  @override
  final permissionChanges = <String>{};
  var name = Platform.localHostname;
  @override
  var selectedSource = 'local';
  var sharing = false;
  ({int revision, String name})? incomingConnection;
  var autoConnect = true;
  String? lastConnectedPeerId;
  var port = musicSharePort;
  var busy = false;
  var initialized = false;
  var _initialConnectionDone = false;
  var _disposed = false;
  Future<void>? _shutdownFuture;
  Future<void> _savePending = Future.value();
  Timer? _connectionTimer;
  var _checking = false;
  final _events = <String, _MusicShareEventConnection>{};
  final _editingRequests = <(String, String, String)>{};
  final _peerTransports = <MusicShareTransport, MusicPeer>{};
  final _peerSyncs = <String, Future<void>>{};
  final _eventRefreshTimers = <String, Timer>{};
  final _refreshingPeers = <MusicPeer>{};
  final _pendingPlaylistPeers = <String>{};
  final _pendingCatalogPeers = <String>{};
  final _pendingSongIds = <String, Set<int>>{};
  final _peerDataEpochs = <String, int>{};
  Timer? _localChangeTimer;
  final _localChanges = <String>{};
  final _remoteDataChanges = StreamController<String>.broadcast();
  @override
  Stream<String> get remoteDataChanges => _remoteDataChanges.stream;
  final _connectionFailures = <String, String>{};
  final _heartbeatFailures = <String, int>{};
  final _requestRecoveryPeers = <String>{};
  final _heartbeatSilence = <String, Stopwatch>{};
  HttpServer? _proxy;
  final _proxySecret = newShareSecret();
  final _proxyTransports = <MusicShareTransport>{};
  late final _artworkCache = MusicShareArtworkCache(
    Directory(p.join(p.dirname(databasePath), 'remote-artwork')),
    onNetworkError: _requestConnectionRecovery,
  );

  late final _playlistClient = MusicSharePlaylistClient(
    repository,
    () {
      onCatalogChanged();
      _notify();
    },
    _notify,
    onNetworkError: _requestConnectionRecovery,
    isCurrent: (peer) => !_disposed && peers.contains(peer),
  );
  bool get selectedPlaylistsLoaded => _playlistClient.hasLoaded(selectedSource);
  bool get selectedPlaylistsLoading =>
      !_initialConnectionDone || _peerSyncs.containsKey(selectedSource);
  List<LibraryPlaylist> get selectedPlaylists =>
      _playlistClient.forDevice(selectedSource);

  @override
  List<LibraryPlaylist> get remotePlaylists => _playlistClient.playlists;

  @override
  Future<LibraryPlaylist?> playlistOperation(
    String device,
    String operation, {
    int? playlistId,
    String? name,
    List<int> songIds = const [],
    List<int> playlistIds = const [],
    LibraryPlaylist? restore,
    PlaylistSortCriterion? criterion,
  }) async {
    final peer = peerFor(remoteMusicPath(device, 0));
    final result = await _playlistClient.operate(
      peer,
      operation,
      playlistId: playlistId,
      name: name,
      songIds: songIds,
      playlistIds: playlistIds,
      restore: restore,
      criterion: criterion,
    );
    _invalidatePeerData(peer, catalog: false);
    return result;
  }

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
      // Existing configurations default to automatic connection.
      autoConnect =
          json.containsKey('autoConnect') ? json['autoConnect'] as bool : true;
      lastConnectedPeerId = json['lastConnectedPeerId'] as String?;
      if (!json.containsKey('lastConnectedPeerId') &&
          selectedSource != 'local' &&
          selectedSource != 'all') {
        lastConnectedPeerId = selectedSource;
      }
      sharing = json['sharing'] as bool;
      port = json['port'] as int? ?? musicSharePort;
      grants.addAll((json['grants'] as Map).cast<String, String>());
      if (json.containsKey('grantIdentities')) {
        grantIdentities.addAll(
          (json['grantIdentities'] as Map).cast<String, String>(),
        );
      }
      if (json.containsKey('mobileGrants')) {
        mobileGrants.addAll((json['mobileGrants'] as List).cast<String>());
      }
      // Older saved authorizations grant playback only.
      if (json.containsKey('writeGrants')) {
        writeGrants.addAll((json['writeGrants'] as List).cast<String>());
      }
      peers.addAll(
        (json['peers'] as List).map(
          (item) => MusicPeer.fromJson((item as Map).cast<String, dynamic>()),
        ),
      );
      if (json['source'] == 'all') {
        selectedSource = 'local';
        await save();
      }
    }
    server = MusicShareServer(
      onLibraryChanged: onCatalogChanged,
      onPeerConnected: (name) {
        incomingConnection = (
          revision: (incomingConnection?.revision ?? 0) + 1,
          name: name,
        );
        _notify();
      },
      identity: identity,
      repository: repository,
      name: () => name,
      grants: grants,
      grantIdentities: grantIdentities,
      mobileGrants: mobileGrants,
      writeGrants: writeGrants,
      onChanged: () {
        _notify();
      },
    );
    server.updateLibrary(snapshot);
    await _artworkCache.restore();
    initialized = true;
    _notify();
  }

  @override
  void localDataChanged(String scope) => _localDataChanged(scope);

  @override
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  Future<void> save() {
    final value = jsonEncode({
      'name': name,
      'source': selectedSource,
      'sharing': sharing,
      'autoConnect': autoConnect,
      'lastConnectedPeerId': lastConnectedPeerId,
      'port': port,
      'grants': grants,
      'grantIdentities': grantIdentities,
      'mobileGrants': mobileGrants.toList(),
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

  Future<void> setAutoConnect(bool enabled) async {
    final previous = autoConnect;
    autoConnect = enabled;
    busy = true;
    _notify();
    try {
      await save();
    } catch (_) {
      autoConnect = previous;
      rethrow;
    } finally {
      busy = false;
      _notify();
    }
    if (enabled) unawaited(checkConnections());
  }

  Future<void> selectSource(String source) async {
    await ready;
    final peer = peers.where((peer) => peer.id == source).firstOrNull;
    if (peer != null) {
      await syncPeer(peer, importCatalog: false, rememberConnection: true);
    }
    final previous = selectedSource;
    selectedSource = source;
    try {
      await save();
    } catch (_) {
      selectedSource = previous;
      rethrow;
    }
    _notify();
  }

  bool includes(LibrarySong song) {
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

  @override
  bool isOnline(String path) => peers.any(
    (peer) =>
        peer.id == Uri.parse(path).host &&
        peer.status == MusicPeerStatus.online,
  );

  @override
  bool canWrite(String path) => peers.any(
    (peer) =>
        peer.id == Uri.parse(path).host &&
        peer.canWrite &&
        peer.status != MusicPeerStatus.unauthorized,
  );

  Future<void> forget(MusicPeer peer) async {
    _peerSyncs.remove(peer.id);
    for (final transport
        in _peerTransports.entries
            .where((entry) => identical(entry.value, peer))
            .map((entry) => entry.key)
            .toList()) {
      transport.close();
    }
    _pendingPlaylistPeers.remove(peer.id);
    _pendingCatalogPeers.remove(peer.id);
    _pendingSongIds.remove(peer.id);
    _disconnectEvents(peer.id);
    _requestRecoveryPeers.remove(peer.id);
    _heartbeatSilence.remove(peer.id);
    _heartbeatFailures.remove(peer.id);
    _connectionFailures.remove(peer.id);
    final artworkStopped = _artworkCache.disconnect(peer.id);
    peers.remove(peer);
    _playlistClient.forget(peer.id);
    repository.forgetRemotePreferences(peer.id);
    if (lastConnectedPeerId == peer.id) lastConnectedPeerId = null;
    for (final transport
        in _proxyTransports
            .where((item) => item.address == peer.address)
            .toList()) {
      transport.close();
    }
    if (selectedSource == peer.id) selectedSource = 'local';
    await Future.wait([
      artworkStopped,
      LibrarySnapshotService.waitForPendingOperations(),
    ]);
    await save();
    _notify();
  }

  Future<void> discover() async {
    await ready;
    final scanResults = <DiscoveredMusicHost>[];
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
          SystemLog.info(
            'Remote device address changed: device=${peer.name}; '
            'from=${peer.address}; to=$address',
          );
          peer.address = address;
          addressChanged = true;
        }
        if (scanResults.any((host) => host.id == id)) return;
        scanResults.add(
          DiscoveredMusicHost(id, json['name'] as String, address),
        );
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
    discovered
      ..clear()
      ..addAll(scanResults);
    _notify();
    if (addressChanged) await save();
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
        onNetworkError:
            (error, stack) => _requestConnectionRecovery(peer, error, stack),
      );
      _proxyTransports.add(transport);
      final response = await transport.open(
        '/songs/${segments[2]}/audio',
        method: request.method,
        range: request.headers.value(HttpHeaders.rangeHeader),
      );
      if ((response.statusCode == HttpStatus.ok ||
              response.statusCode == HttpStatus.partialContent) &&
          lastConnectedPeerId != peer.id) {
        lastConnectedPeerId = peer.id;
        unawaited(
          save().catchError((Object error, StackTrace stack) {
            SystemLog.error('Unable to remember audio device', error, stack);
          }),
        );
      }
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
      await request.response.addStream(
        response.handleError((Object error, StackTrace stack) {
          transport!.reportNetworkFailure(error, stack);
          Error.throwWithStackTrace(error, stack);
        }),
      );
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
  }) => _editRequest(
    path,
    '/songs/${Uri.parse(path).pathSegments.single}/$resource',
    method: method,
    body: body,
  );

  @override
  Future<Map<String, dynamic>> songsRequest(
    List<String> paths,
    String resource, {
    String method = 'GET',
    Object? body,
  }) {
    final device = Uri.parse(paths.first).host;
    if (paths.any((path) => Uri.parse(path).host != device)) {
      throw const MusicShareException('share.sameDeviceSongs');
    }
    final ids = paths
        .map((path) => Uri.parse(path).pathSegments.single)
        .join(',');
    return _editRequest(
      paths.first,
      '/songs/$resource?ids=$ids',
      method: method,
      body: body,
    );
  }

  @override
  Future<Map<String, dynamic>> preferenceRequest(
    String device,
    String operation,
    Map<String, dynamic> values,
  ) {
    final read = operation == 'get' || operation == 'level';
    final uri = Uri(
      path: '/preferences',
      queryParameters:
          read
              ? {
                'operation': operation,
                for (final e in values.entries) e.key: e.value.toString(),
              }
              : null,
    );
    return _editRequest(
      remoteMusicPath(device, 0),
      uri.toString(),
      method: read ? 'GET' : 'POST',
      body: read ? null : {'operation': operation, ...values},
    );
  }

  @override
  Future<Map<String, dynamic>> fileRequest(
    String path,
    String operation,
    Map<String, dynamic> values,
  ) async {
    final id = Uri.parse(path).pathSegments.single;
    final read = operation == 'info';
    final result = await _editRequest(
      path,
      read ? '/files?operation=info&song=$id' : '/files',
      method: read ? 'GET' : 'POST',
      body: read ? null : {'operation': operation, 'song': id, ...values},
    );
    if (result['error'] case final String key) throw MusicShareException(key);
    return result;
  }

  Future<Map<String, dynamic>> _editRequest(
    String path,
    String endpoint, {
    String method = 'GET',
    Object? body,
  }) async {
    final key = (path, endpoint, method);
    final writing = method != 'GET';
    if (writing && !_editingRequests.add(key)) {
      throw const MusicShareException('song.processingRequest');
    }
    try {
      return await _performEditRequest(
        path,
        endpoint,
        method: method,
        body: body,
      );
    } finally {
      if (writing) _editingRequests.remove(key);
    }
  }

  Future<Map<String, dynamic>> _performEditRequest(
    String path,
    String endpoint, {
    required String method,
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
      onNetworkError:
          (error, stack) => _requestConnectionRecovery(peer, error, stack),
    );
    try {
      final result = await transport.json(endpoint, method: method, body: body);
      if (_disposed || !peers.contains(peer)) {
        throw const MusicShareException('share.deviceForgotten');
      }
      if (method != 'GET' && !result.containsKey('error')) {
        final ids = Uri.parse(endpoint).queryParameters['ids'];
        _invalidatePeerData(
          peer,
          catalog: false,
          songIds:
              ids == null
                  ? [int.parse(Uri.parse(path).pathSegments.single)]
                  : ids.split(',').map(int.parse).toList(),
        );
      }
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
      onNetworkError:
          (error, stack) => _requestConnectionRecovery(peer, error, stack),
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
    _localChangeTimer?.cancel();
    for (final device in _events.keys.toList()) {
      _disconnectEvents(device);
    }
    await _remoteDataChanges.close();
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
