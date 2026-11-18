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
          server.markCatalogChanged();
        }
        for (final changed in scopes) {
          if (changed == 'library') continue;
          server.events.dataChanged(changed);
        }
      } catch (error, stack) {
        _localChanges.addAll(scopes);
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
      _remoteDataChanges.add(peer.id);
      // Subscription changes invalidate caches; page access performs the read.
      _invalidatePeerData(peer);
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
              final scopes = (event['scopes'] as List).cast<String>();
              final hasTypedHistory =
                  scopes.contains(recentHistoryScope) ||
                  scopes.contains(searchHistoryScope);
              for (final scope in [recentHistoryScope, searchHistoryScope]) {
                if (scopes.contains(scope) ||
                    (!hasTypedHistory && scopes.contains('history'))) {
                  libraryHistoryChanges.add((device: peer.id, scope: scope));
                }
              }
              final ids =
                  scopes
                      .where((scope) => scope.startsWith('song:'))
                      .map((scope) => int.parse(scope.substring(5)))
                      .toList();
              if (scopes.contains('library') ||
                  scopes.contains('playlists') ||
                  ids.isNotEmpty) {
                _invalidatePeerData(
                  peer,
                  catalog: scopes.contains('library'),
                  songIds: ids,
                );
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
  }

  void _invalidatePeerData(
    MusicPeer peer, {
    bool catalog = true,
    List<int> songIds = const [],
  }) {
    // The database catalog and playlist list are caches owned by this device.
    // Changes are recorded only; the next explicit page access reads them.
    _peerDataEpochs.update(peer.id, (value) => value + 1, ifAbsent: () => 1);
    if (catalog) {
      peer.catalogRevision = null;
      _pendingCatalogPeers.add(peer.id);
    }
    _pendingSongIds.putIfAbsent(peer.id, () => {}).addAll(songIds);
    _pendingPlaylistPeers.add(peer.id);
    _playlistClient.invalidate(peer.id);
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
