part of 'music_share_controller.dart';

extension MusicShareEvents on MusicShareController {
  void _localDataChanged(String scope) {
    if (!initialized || !server.running || _disposed) return;
    _localChanges.add(scope);
    _localChangeTimer ??= Timer(const Duration(milliseconds: 100), () async {
      final scopes = _localChanges.toList();
      _localChanges.clear();
      _localChangeTimer = null;
      try {
        if (scopes.contains('library')) {
          final snapshot = await repository.getLibraryContentData();
          if (_disposed || !server.running) return;
          server.updateLibrary(snapshot);
        }
        for (final changed in scopes) {
          server.events.dataChanged(changed);
        }
      } catch (error, stack) {
        SystemLog.error('Shared data notification failed', error, stack);
      }
    });
  }

  Future<void> _connectEvents(MusicPeer peer) async {
    final current = _events[peer.id];
    if (current != null && current.address == peer.address) return;
    current?.close();
    final connection = _MusicShareEventConnection(peer);
    _events[peer.id] = connection;
    try {
      final socket = await connection.transport.connectEvents();
      if (_disposed || !identical(_events[peer.id], connection)) {
        await socket.close();
        return;
      }
      connection.socket = socket;
      socket.listen(
        (message) {
          if (!identical(_events[peer.id], connection)) return;
          final event = jsonDecode(message as String) as Map<String, dynamic>;
          switch (event['type']) {
            case 'permissions':
              final canWrite = event['canWrite'] as bool;
              if (peer.canWrite != canWrite) {
                peer.canWrite = canWrite;
                _notify();
              }
            case 'revoked':
              peer.status = MusicPeerStatus.unauthorized;
              peer.canWrite = false;
              _disconnectEvents(peer.id);
              _notify();
            case 'data-changed':
              _remoteDataChanges.add(peer.id);
              if ((event['scopes'] as List).contains('library')) {
                _invalidatePeerData(peer);
              }
          }
        },
        onDone: () => _eventsDisconnected(peer, connection),
        onError: (Object error, StackTrace stack) {
          _eventsDisconnected(peer, connection);
        },
        cancelOnError: true,
      );
    } catch (_) {
      if (identical(_events[peer.id], connection)) _events.remove(peer.id);
      connection.close();
      rethrow;
    }
  }

  void _eventsDisconnected(
    MusicPeer peer,
    _MusicShareEventConnection connection,
  ) {
    if (!identical(_events[peer.id], connection)) return;
    _disconnectEvents(peer.id);
    _requestConnectionRecovery(
      peer,
      const SocketException('Remote event connection closed'),
      StackTrace.current,
    );
  }

  void _disconnectEvents(String device) {
    _events.remove(device)?.close();
    _eventRefreshTimers.remove(device)?.cancel();
  }

  void _invalidatePeerData(MusicPeer peer) {
    // The database catalog and playlist list are caches owned by this device.
    // Inactive sources are fetched when selected; the visible source refreshes now.
    _peerDataEpochs.update(peer.id, (value) => value + 1, ifAbsent: () => 1);
    peer.catalogRevision = null;
    _playlistClient.invalidate(peer.id);
    if (selectedSource != peer.id) return;
    _eventRefreshTimers.remove(peer.id)?.cancel();
    _eventRefreshTimers[peer
        .id] = Timer(const Duration(milliseconds: 100), () async {
      _eventRefreshTimers.remove(peer.id);
      try {
        // Let an in-flight snapshot finish before fetching the invalidated data.
        await _peerSyncs[peer.id];
        if (_disposed ||
            !peers.contains(peer) ||
            peer.status == MusicPeerStatus.unauthorized) {
          return;
        }
        await syncPeer(peer, importCatalog: true);
      } catch (error, stack) {
        SystemLog.error('Remote event synchronization failed', error, stack);
      }
    });
  }
}

class _MusicShareEventConnection {
  _MusicShareEventConnection(MusicPeer peer)
    : address = peer.address,
      transport = MusicShareTransport(
        peer.address,
        fingerprint: peer.fingerprint,
        token: peer.token,
      );

  final String address;
  final MusicShareTransport transport;
  WebSocket? socket;

  void close() {
    unawaited(socket?.close());
    transport.close();
  }
}
