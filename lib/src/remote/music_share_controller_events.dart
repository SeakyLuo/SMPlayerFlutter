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
        } else if (scopes.contains('playlists')) {
          server.updatePlaylists(await repository.getLocalPlaylists());
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
    _eventRefreshTimers.remove(device)?.cancel();
  }

  void _invalidatePeerData(
    MusicPeer peer, {
    bool catalog = true,
    List<int> songIds = const [],
  }) {
    // The database catalog and playlist list are caches owned by this device.
    // Inactive sources are fetched when selected; the visible source refreshes now.
    if (catalog) {
      _peerDataEpochs.update(peer.id, (value) => value + 1, ifAbsent: () => 1);
      peer.catalogRevision = null;
      _pendingCatalogPeers.add(peer.id);
    }
    _pendingSongIds.putIfAbsent(peer.id, () => {}).addAll(songIds);
    _pendingPlaylistPeers.add(peer.id);
    _playlistClient.invalidate(peer.id);
    _schedulePeerRefresh(peer, const Duration(milliseconds: 100));
  }

  void _retryPendingPeerData(MusicPeer peer) {
    if (_eventRefreshTimers.containsKey(peer.id) ||
        _refreshingPeers.contains(peer)) {
      return;
    }
    if (_pendingCatalogPeers.contains(peer.id) ||
        _pendingPlaylistPeers.contains(peer.id) ||
        (_pendingSongIds[peer.id]?.isNotEmpty ?? false)) {
      _schedulePeerRefresh(peer, const Duration(milliseconds: 100));
    }
  }

  void _schedulePeerRefresh(MusicPeer peer, Duration delay) {
    if (_disposed ||
        selectedSource != peer.id ||
        peer.status != MusicPeerStatus.online) {
      return;
    }
    _eventRefreshTimers.remove(peer.id)?.cancel();
    _eventRefreshTimers[peer.id] = Timer(delay, () async {
      _eventRefreshTimers.remove(peer.id);
      if (!_refreshingPeers.add(peer)) return;
      var completed = false;
      var fullCatalog = false;
      var playlists = false;
      var ids = <int>{};
      try {
        // Let an in-flight snapshot finish before fetching the invalidated data.
        await _peerSyncs[peer.id];
        if (_disposed ||
            selectedSource != peer.id ||
            !peers.contains(peer) ||
            peer.status != MusicPeerStatus.online) {
          return;
        }
        fullCatalog = _pendingCatalogPeers.remove(peer.id);
        playlists = _pendingPlaylistPeers.remove(peer.id);
        ids = _pendingSongIds.remove(peer.id) ?? <int>{};
        if (fullCatalog || ids.length > 128) {
          await syncPeer(peer, importCatalog: true);
        } else {
          if (ids.isNotEmpty) {
            await _refreshPeerSongs(peer, ids.toList());
            ids.clear();
          }
          if (playlists) await _playlistClient.refresh(peer);
        }
        completed = true;
      } catch (error, stack) {
        if (_disposed || !peers.contains(peer)) return;
        if (fullCatalog) _pendingCatalogPeers.add(peer.id);
        if (playlists) _pendingPlaylistPeers.add(peer.id);
        _pendingSongIds.putIfAbsent(peer.id, () => {}).addAll(ids);
        if (isMusicShareNetworkFailure(error) ||
            error is MusicShareException &&
                error.messageKey == 'share.requestTimedOut') {
          _schedulePeerRefresh(peer, _heartbeatRecoveryInterval);
        }
        SystemLog.error('Remote event synchronization failed', error, stack);
      } finally {
        _refreshingPeers.remove(peer);
        if (completed) _retryPendingPeerData(peer);
      }
    });
  }

  Future<void> _refreshPeerSongs(MusicPeer peer, List<int> ids) async {
    final transport = MusicShareTransport(
      peer.address,
      fingerprint: peer.fingerprint,
      token: peer.token,
      onNetworkError:
          (error, stack) => _requestConnectionRecovery(peer, error, stack),
    );
    _peerTransports[transport] = peer;
    try {
      final result = await transport.json('/catalog?ids=${ids.join(',')}');
      if (_disposed || !peers.contains(peer)) return;
      await importMusicShareCatalog(
        databasePath,
        peer.id,
        (result['songs'] as List)
            .map((s) => (s as Map).cast<String, dynamic>())
            .toList(),
        replace: false,
        isCurrent: () => !_disposed && peers.contains(peer),
        removedSongIds: (result['removed'] as List).cast<int>(),
      );
      if (_disposed || !peers.contains(peer)) return;
      peer.catalogRevision = result['revision'] as String;
      onCatalogChanged();
    } finally {
      _peerTransports.remove(transport);
      transport.close();
    }
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
