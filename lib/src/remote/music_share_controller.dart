import '../library/data/library_history_changes.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../library/data/library_models.dart';
import '../library/data/library_queries.dart';
import '../library/data/library_repository.dart';
import '../library/data/library_snapshot_service.dart';
import '../platform/system_log.dart';
import 'music_share_access.dart';
import 'ai_agent_remote_controller.dart';
import 'music_share_artwork_cache.dart';
import 'music_share_catalog.dart';
import 'music_share_identity.dart';
import 'music_share_models.dart';
import 'remote_directory_refresh.dart';
import 'music_share_server.dart';
import 'music_share_host.dart';
import 'music_share_background_host.dart';
import 'music_share_background_platform.dart';
import 'music_share_connection_store.dart';
import 'music_share_playlist_client.dart';

part 'music_share_controller_authorization.dart';
part 'music_share_controller_host.dart';
part 'music_share_controller_connections.dart';
part 'music_share_controller_events.dart';
part 'music_share_controller_page_data.dart';
part 'music_share_controller_initialization.dart';
part 'music_share_controller_reading.dart';
part 'music_share_controller_editing.dart';
part 'music_share_controller_storage.dart';

class MusicShareController extends ChangeNotifier
    with _MusicShareAuthorization
    implements MusicShareAccess {
  MusicShareController(
    this.repository,
    this.onCatalogChanged, {
    required this.loadLibrary,
    required this.onPlaylistsChanged,
    required this.onHostDataChanged,
    required this.onScopedPeerChange,
  }) {
    ready = _load();
    initialConnection = ready.then((_) => checkConnections()).whenComplete(() {
      _initialConnectionDone = true;
      _notify();
    });
    startup = ready.then((_) async {
      busy = true;
      try {
        if (sharing || backgroundSharing) await _startSharingHost();
      } catch (error, stack) {
        hostFailure = (error: error, stack: stack);
        SystemLog.error('Music sharing host startup failed', error, stack);
      } finally {
        busy = false;
        _notify();
      }
    });
  }

  final LibraryRepository repository;
  final void Function(String source) onCatalogChanged;
  final Future<LibraryContentData> Function() loadLibrary;
  final void Function(List<LibraryPlaylist>) onPlaylistsChanged;
  final void Function(List<String>) onHostDataChanged;
  final Future<void> Function(String, Set<int>, bool) onScopedPeerChange;
  late final Future<void> ready;
  late final Future<void> initialConnection;
  late final Future<void> startup;
  late MusicShareIdentity identity;
  @override
  late MusicShareHost server;
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
  var backgroundSharing = false;
  ({Object error, StackTrace stack})? hostFailure;
  ({int revision, String name})? incomingConnection;
  var autoConnect = true;
  var updatingAutoConnect = false;
  var updatingBackgroundSharing = false;
  var _backgroundUpdateRevision = 0;
  bool? sharingTarget;
  var _sharingUpdateRevision = 0;
  String? lastConnectedPeerId;
  var port = musicSharePort;
  var busy = false;
  var initialized = false;
  var _initialConnectionDone = false;
  var _disposed = false;
  Future<void>? _shutdownFuture;
  Future<void> _savePending = Future.value();
  Future<void> _hostMutations = Future.value();
  Timer? _connectionTimer;
  var _checking = false;
  final _events = <String, _MusicShareEventConnection>{};
  final _editingRequests = <(String, String, String)>{};
  final _peerTransports = <MusicShareTransport, MusicPeer>{};
  final _peerSyncs = <String, Future<void>>{};
  final _pendingPlaylistPeers = <String>{};
  final _pendingCatalogPeers = <String>{};
  final _pendingPageChanges = <String, _PeerPageChanges>{};
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

  late final MusicSharePlaylistClient _playlistClient =
      MusicSharePlaylistClient(
        repository,
        () {
          onPlaylistsChanged(_playlistClient.playlists);
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
  Future<Map<String, dynamic>> directoryOperation(
    String device,
    String path,
    String operation, {
    String? name,
    Map<String, dynamic> values = const {},
  }) =>
      _directoryOperation(device, path, operation, name: name, values: values);
  @override
  Future<Map<String, dynamic>> storageDirectoryIndex(String device) =>
      _storageDirectoryIndex(device);
  @override
  Future<Map<String, dynamic>> refreshStorageDirectory(
    String device,
    String path,
    LocalFolderScanCancellation cancellation,
    void Function(LocalFolderRefreshProgress) onProgress,
  ) => _refreshStorageDirectory(device, path, cancellation, onProgress);
  @override
  Future<List<HiddenStorageItem>> hiddenStorageItems(String device) =>
      _hiddenStorageItems(device);
  @override
  Future<void> resumeHiddenStorage(String device, HiddenStorageItem item) =>
      _resumeHiddenStorage(device, item);

  @override
  List<LibraryPlaylist> get remotePlaylists => _playlistClient.playlists;

  @override
  Future<List<LibraryPlaylist>> readPlaylists(String device) async {
    await ready;
    if (!_playlistClient.isFresh(device)) await readPlaylistData(device);
    return _playlistClient.forDevice(device);
  }

  @override
  Future<Map<String, dynamic>> historyRequest(
    String device,
    String operation,
    Map<String, dynamic> values,
  ) => _historyRequest(device, operation, values);

  @override
  Future<LibraryContentData> queryLibraryData(
    String device,
    LibraryDataQuery query,
  ) => _queryLibraryData(device, query);

  @override
  Future<LibraryLyricsSearchPage> searchLyrics(
    String device,
    String query,
    String folderPath, {
    int offset = 0,
    MusicLibrarySortCriterion? order,
  }) => _searchLyrics(device, query, folderPath, offset: offset, order: order);

  Future<void> notifyLibraryAccess(String device) async {
    final changes = _pendingPageChanges.remove(device);
    if (changes == null) return;
    // One notification invalidates every affected query once. Pending playlist
    // or song reads must not invalidate unrelated pages again on every visit.
    if (changes.catalog) {
      onCatalogChanged(device);
    } else {
      try {
        await onScopedPeerChange(device, changes.songIds, changes.playlists);
      } catch (_) {
        if (!_disposed && peers.any((peer) => peer.id == device)) {
          _pendingPageChanges
              .putIfAbsent(device, _PeerPageChanges.new)
              .add(
                catalog: false,
                songIds: changes.songIds,
                playlists: changes.playlists,
              );
        }
        rethrow;
      }
    }
  }

  @override
  Future<Map<String, dynamic>> randomPlayRequest(
    String device,
    Map<String, String> parameters,
  ) async {
    final peer = peerFor(remoteMusicPath(device, 0));
    final transport = MusicShareTransport(
      peer.address,
      fingerprint: peer.fingerprint,
      token: peer.token,
      onNetworkError:
          (error, stack) => _requestConnectionRecovery(peer, error, stack),
    );
    _peerTransports[transport] = peer;
    try {
      final selection = parameters['kind'] == 'selection';
      final result = await transport.json(
        selection
            ? '/random-play'
            : Uri(path: '/random-play', queryParameters: parameters).toString(),
        method: selection ? 'POST' : 'GET',
        body: selection ? parameters : null,
      );
      if (_disposed || !peers.contains(peer))
        throw const MusicShareException('share.deviceForgotten');
      return result;
    } finally {
      _peerTransports.remove(transport);
      transport.close();
    }
  }

  @override
  Future<ArtistSplitAnalysisResult> analyzeArtists(
    String device, {
    void Function(double)? onProgress,
  }) => _analyzeArtists(device, onProgress: onProgress);

  @override
  Future<List<int>> resolveSongIds(String device, LibraryDataQuery query) =>
      _resolveSongIds(device, query);

  @override
  Future<List<int>> readRandomSelectionIds(
    String device,
    Map<String, String> parameters,
  ) async {
    final result = await randomPlayRequest(device, parameters);
    return repository.cacheRemoteSongReferences(
      device,
      (result['ids'] as List).cast<int>(),
    );
  }

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

  @override
  void localDataChanged(String scope) => _localDataChanged(scope);

  @override
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> save() => _saveConnections();

  @override
  Future<void> syncSharingConfiguration() =>
      _runHostMutation(_syncSharingConfiguration);

  @override
  Future<T> withSharingSuspended<T>(Future<T> Function() operation) =>
      _runHostMutation(() => _withSharingSuspended(operation));

  @override
  Future<void> _persistHostSettings() async {
    if (server is MusicShareServer)
      await MusicShareConnectionStore.writeHost(_hostConfiguration);
  }

  @override
  Future<T> _runHostMutation<T>(Future<T> Function() action) {
    final operation = _hostMutations.then((_) => action());
    _hostMutations = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return operation;
  }

  Future<void> setSharing(bool enabled) => _updateSharing(enabled);
  Future<void> setBackgroundSharing(bool enabled) =>
      _updateBackgroundSharing(enabled);
  Future<void> setHostName(String value) =>
      _runHostMutation(() => _setHostName(value));
  Future<void> setPort(int value) => _runHostMutation(() => _setPort(value));

  Future<void> setAutoConnect(bool enabled) async {
    final previous = autoConnect;
    autoConnect = enabled;
    updatingAutoConnect = true;
    _notify();
    try {
      await save();
    } catch (_) {
      autoConnect = previous;
      rethrow;
    } finally {
      updatingAutoConnect = false;
      _notify();
    }
    if (enabled) unawaited(checkConnections());
  }

  Future<void> selectSource(String source) async {
    await ready;
    final peer = peers.where((peer) => peer.id == source).firstOrNull;
    if (peer != null) lastConnectedPeerId = peer.id;
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
    _pendingPageChanges.remove(peer.id);
    _peerDataEpochs.remove(peer.id);
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
        await syncPeer(peer, rememberConnection: true);
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
  }) async {
    final result = await _editRequest(
      path,
      '/songs/${Uri.parse(path).pathSegments.single}/$resource',
      method: method,
      body: body,
    );
    return result;
  }

  @override
  Future<Map<String, dynamic>> songsRequest(
    List<String> paths,
    String resource, {
    String method = 'GET',
    Object? body,
  }) async {
    final device = Uri.parse(paths.first).host;
    if (paths.any((path) => Uri.parse(path).host != device)) {
      throw const MusicShareException('share.sameDeviceSongs');
    }
    final ids =
        paths
            .map((path) => int.parse(Uri.parse(path).pathSegments.single))
            .toList();
    final payload = {'ids': ids, 'method': method, 'data': body};
    final endpoint = '/songs/$resource';
    final result =
        method == 'GET'
            ? await _libraryReadRequest(device, endpoint, body: payload)
            : await _editRequest(
              paths.first,
              endpoint,
              method: 'POST',
              body: payload,
            );
    return result;
  }

  @override
  Future<Map<String, dynamic>> preferenceRequest(
    String device,
    String operation,
    Map<String, dynamic> values,
  ) async {
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
    final result = await _editRequest(
      remoteMusicPath(device, 0),
      uri.toString(),
      method: read ? 'GET' : 'POST',
      body: read ? null : {'operation': operation, ...values},
    );
    return result;
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
    if (!read) {
      await applyDirectoryChanges(Uri.parse(path).host, result);
    }
    return result;
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
    await aiAgentRemoteController.detach();
    await Future.wait([
      if (_proxy != null) _proxy!.close(force: true),
      if (initialized) server.disconnect(),
    ]);
  }

  @override
  void dispose() {
    unawaited(shutdown());
    super.dispose();
  }
}
