part of 'music_share_controller.dart';

const _heartbeatFailureLimit = 3;
const _heartbeatOfflineGrace = Duration(minutes: 2);
const _heartbeatRecoveryInterval = Duration(seconds: 3);
const _heartbeatRegularInterval = Duration(seconds: 30);
const _heartbeatOfflineInterval = Duration(seconds: 10);

extension MusicShareConnections on MusicShareController {
  Future<void> checkConnections() async {
    if (_checking || _disposed) return;
    _connectionTimer?.cancel();
    _checking = true;
    try {
      final targets =
          peers
              .where(
                (peer) =>
                    peer.status == MusicPeerStatus.online &&
                        !_events.containsKey(peer.id) ||
                    (autoConnect &&
                        peer.id == lastConnectedPeerId &&
                        peer.status != MusicPeerStatus.unauthorized &&
                        !_events.containsKey(peer.id)),
              )
              .toList();
      final failed = <MusicPeer>[];
      await Future.wait(
        targets.map((peer) async {
          try {
            await syncPeer(
              peer,
              heartbeat: true,
              importCatalog: peer.status != MusicPeerStatus.online,
            );
          } catch (_) {
            if (peer.status != MusicPeerStatus.unauthorized &&
                (_heartbeatFailures[peer.id] ?? 0) > 0) {
              failed.add(peer);
            }
            // Background checks update connection state; user actions show a toast.
          }
        }),
      );
      if (failed.isEmpty) return;
      final addresses = {for (final peer in failed) peer.id: peer.address};
      try {
        await discover();
      } on SocketException catch (error, stack) {
        SystemLog.error(
          'Remote discovery failed during reconnection',
          error,
          stack,
        );
        // UDP discovery may be unavailable; saved HTTPS addresses still work.
        return;
      }
      await Future.wait(
        failed.where((peer) => peer.address != addresses[peer.id]).map((
          peer,
        ) async {
          try {
            await syncPeer(peer);
          } catch (_) {
            // A newly discovered address can also become unreachable.
          }
        }),
      );
    } finally {
      _checking = false;
      if (!_disposed) _scheduleConnectionCheck();
    }
  }

  void _requestConnectionRecovery(
    MusicPeer peer,
    Object error,
    StackTrace stack,
  ) {
    if (_disposed ||
        _checking ||
        !isMusicShareNetworkFailure(error) ||
        peer.status == MusicPeerStatus.unauthorized ||
        !peers.contains(peer)) {
      return;
    }
    if (peer.status == MusicPeerStatus.offline &&
        !(autoConnect && peer.id == lastConnectedPeerId)) {
      return;
    }
    if (!_requestRecoveryPeers.add(peer.id)) return;
    _heartbeatSilence.putIfAbsent(peer.id, () => Stopwatch()..start());
    SystemLog.error(
      'Remote operation failed; checking connection immediately: '
      'device=${peer.name}; address=${peer.address}',
      error,
      stack,
    );
    _connectionTimer?.cancel();
    _connectionTimer = Timer(
      Duration.zero,
      () => unawaited(checkConnections()),
    );
  }

  void _scheduleConnectionCheck() {
    final needsConnection = peers.any(
      (peer) =>
          !_events.containsKey(peer.id) &&
          (peer.status == MusicPeerStatus.online ||
              autoConnect &&
                  peer.id == lastConnectedPeerId &&
                  peer.status != MusicPeerStatus.unauthorized),
    );
    if (!needsConnection) return;
    final recovering = peers.any(
      (peer) =>
          peer.status != MusicPeerStatus.unauthorized &&
          (peer.status == MusicPeerStatus.online ||
              autoConnect && peer.id == lastConnectedPeerId) &&
          ((_heartbeatFailures[peer.id] ?? 0) > 0 ||
              _requestRecoveryPeers.contains(peer.id)) &&
          _heartbeatSilence[peer.id]!.elapsed < _heartbeatOfflineGrace,
    );
    final offlineReconnect =
        autoConnect &&
        peers.any(
          (peer) =>
              peer.id == lastConnectedPeerId &&
              peer.status == MusicPeerStatus.offline,
        );
    _connectionTimer = Timer(
      recovering
          ? _heartbeatRecoveryInterval
          : offlineReconnect
          ? _heartbeatOfflineInterval
          : _heartbeatRegularInterval,
      () => unawaited(checkConnections()),
    );
  }

  Future<void> syncPeer(
    MusicPeer peer, {
    bool importCatalog = true,
    bool heartbeat = false,
    bool rememberConnection = false,
  }) async {
    final pending = _peerSyncs[peer.id];
    if (pending != null) {
      await pending;
      if (_disposed || !peers.contains(peer)) return;
      if (rememberConnection) {
        lastConnectedPeerId = peer.id;
        await save();
      }
      return;
    }
    final epoch = _peerDataEpochs[peer.id];
    final operation = _syncPeer(
      peer,
      importCatalog: importCatalog,
      heartbeat: heartbeat,
      rememberConnection: rememberConnection,
    );
    _peerSyncs[peer.id] = operation;
    try {
      await operation;
    } finally {
      if (identical(_peerSyncs[peer.id], operation)) _peerSyncs.remove(peer.id);
      if (_peerDataEpochs[peer.id] != epoch) peer.catalogRevision = null;
    }
  }

  Future<void> _syncPeer(
    MusicPeer peer, {
    required bool importCatalog,
    required bool heartbeat,
    required bool rememberConnection,
  }) async {
    final transport = MusicShareTransport(
      peer.address,
      fingerprint: peer.fingerprint,
      token: peer.token,
    );
    _peerTransports[transport] = peer;
    final previous = peer.status;
    final elapsed = Stopwatch()..start();
    var stage = 'status';
    var notifiedStatus = peer.status;
    var reachable = false;
    try {
      final status = await transport.json('/status');
      peer.supportsPlaylists = status['playlistSupport'] == true;
      final canWrite = status['canWrite'] == true;
      if (peer.canWrite != canWrite) {
        peer.canWrite = canWrite;
        _notify();
      }
      final revision = status['revision'] as String;
      final recovering = _requestRecoveryPeers.contains(peer.id);
      if (_disposed || !peers.contains(peer)) return;
      reachable = true;
      _requestRecoveryPeers.remove(peer.id);
      _heartbeatSilence[peer.id] = Stopwatch()..start();
      final failedHeartbeats = _heartbeatFailures.remove(peer.id) ?? 0;
      if (failedHeartbeats > 0) {
        SystemLog.info(
          'Remote heartbeat recovered: device=${peer.name}; '
          'address=${peer.address}; previousFailures=$failedHeartbeats',
        );
      }
      if (previous != MusicPeerStatus.online ||
          failedHeartbeats > 0 ||
          recovering) {
        _remoteDataChanges.add(peer.id);
      }
      final updatedName = status['name'] as String;
      if (updatedName != peer.name) {
        peer.name = updatedName;
        await save();
        _notify();
      }
      peer.status = MusicPeerStatus.online;
      if (notifiedStatus != peer.status) {
        notifiedStatus = peer.status;
        SystemLog.info(
          'Remote connection restored: device=${peer.name}; address=${peer.address}; '
          'from=${previous.name}; elapsedMs=${elapsed.elapsedMilliseconds}',
        );
        _notify();
      }
      unawaited(
        _connectEvents(peer).catchError((Object error, StackTrace stack) {
          SystemLog.error(
            'Remote notification channel connection failed: device=${peer.name}',
            error,
            stack,
          );
        }),
      );
      _retryPendingPeerData(peer);
      if (_localChanges.isNotEmpty && _localChangeTimer == null) {
        _localDataChanged(_localChanges.first);
      }
      if (importCatalog || peer.catalogRevision != revision) {
        stage = 'catalog';
        final page = await transport.json('/catalog');
        if (_disposed || !peers.contains(peer)) return;
        final songs =
            (page['songs'] as List)
                .map((item) => (item as Map).cast<String, dynamic>())
                .toList();
        stage = 'catalog-import';
        await importMusicShareCatalog(
          databasePath,
          peer.id,
          songs,
          isCurrent: () => !_disposed && peers.contains(peer),
        );
        if (_disposed || !peers.contains(peer)) return;
        peer.catalogRevision = revision;
        onCatalogChanged();
      }
      if (peer.supportsPlaylists) {
        stage = 'playlists';
        await _playlistClient.refresh(peer);
      }
      if (_disposed || !peers.contains(peer)) return;
      stage = 'save';
      if (rememberConnection) {
        lastConnectedPeerId = peer.id;
        await save();
      }
      final recovered = _connectionFailures.remove(peer.id) != null;
      if (previous != MusicPeerStatus.online ||
          recovered ||
          rememberConnection) {
        SystemLog.info(
          'Remote synchronization completed: device=${peer.name}; '
          'address=${peer.address}; elapsedMs=${elapsed.elapsedMilliseconds}; '
          'manual=$rememberConnection; recovered=$recovered',
        );
      }
    } catch (error, stack) {
      if (_disposed || !peers.contains(peer)) return;
      if (error is MusicShareException &&
          error.messageKey == 'share.authorizationRequired') {
        _requestRecoveryPeers.remove(peer.id);
        _heartbeatSilence.remove(peer.id);
        _heartbeatFailures.remove(peer.id);
        peer.status = MusicPeerStatus.unauthorized;
        _disconnectEvents(peer.id);
      } else if (!reachable && heartbeat) {
        _heartbeatSilence.putIfAbsent(peer.id, () => Stopwatch()..start());
        final count = _heartbeatFailures[peer.id] ?? 0;
        final failures = count < _heartbeatFailureLimit ? count + 1 : count;
        _heartbeatFailures[peer.id] = failures;
        if (peer.status == MusicPeerStatus.online &&
            failures >= _heartbeatFailureLimit &&
            _heartbeatSilence[peer.id]!.elapsed >= _heartbeatOfflineGrace) {
          SystemLog.warning(
            'Remote device marked offline after heartbeat grace: '
            'device=${peer.name}; address=${peer.address}; '
            'unansweredMs=${_heartbeatSilence[peer.id]!.elapsedMilliseconds}',
          );
          peer.status = MusicPeerStatus.offline;
        }
      }
      if (!heartbeat) _requestConnectionRecovery(peer, error, stack);
      _logConnectionFailure(peer, stage, previous, elapsed, error, stack);
      rethrow;
    } finally {
      _peerTransports.remove(transport);
      transport.close();
      if (notifiedStatus != peer.status) _notify();
    }
  }

  void _logConnectionFailure(
    MusicPeer peer,
    String stage,
    MusicPeerStatus previous,
    Stopwatch elapsed,
    Object error,
    StackTrace stack,
  ) {
    final failures = _heartbeatFailures[peer.id] ?? 0;
    final signature =
        '$stage:${peer.status.name}:$failures:${error.runtimeType}:$error';
    if (_connectionFailures[peer.id] == signature) return;
    _connectionFailures[peer.id] = signature;
    SystemLog.error(
      'Remote connection check failed: device=${peer.name}; address=${peer.address}; '
      'stage=$stage; from=${previous.name}; to=${peer.status.name}; '
      'autoConnect=$autoConnect; heartbeatFailures=$failures/$_heartbeatFailureLimit; '
      'elapsedMs=${elapsed.elapsedMilliseconds}',
      error,
      stack,
    );
  }
}
