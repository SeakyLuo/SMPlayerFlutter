part of 'music_share_controller.dart';

extension MusicSharePageData on MusicShareController {
  /// Called by a page entry or its explicit retry, never by connection or WS events.
  Future<void> readPageData(
    String device, {
    bool playlists = false,
    bool Function()? isCurrent,
  }) async {
    await ready;
    final peer = peers.firstWhere((peer) => peer.id == device);
    // Page reads do not wait for connection or notification maintenance.
    bool active() =>
        !_disposed && peers.contains(peer) && (isCurrent?.call() ?? true);
    if (!active()) return;
    final epoch = _peerDataEpochs[device];
    var catalogFetched = false;
    if (playlists) {
      if (!peer.catalogLoaded ||
          _pendingCatalogPeers.contains(device) ||
          (_pendingSongIds[device]?.isNotEmpty ?? false)) {
        peer.catalogRevision = null;
      }
      catalogFetched = await _playlistClient.refresh(peer, canApply: active);
    } else {
      final transport = MusicShareTransport(
        peer.address,
        fingerprint: peer.fingerprint,
        token: peer.token,
      );
      _peerTransports[transport] = peer;
      try {
        final page = await transport.json('/catalog');
        if (!active()) return;
        await applyPageCatalog(
          device,
          (page['songs'] as List)
              .map((song) => (song as Map).cast<String, dynamic>())
              .toList(),
          isCurrent: active,
        );
        if (!active()) return;
        catalogFetched = true;
      } finally {
        _peerTransports.remove(transport);
        transport.close();
      }
    }
    if (!active()) return;
    peer.status = MusicPeerStatus.online;
    if (_peerDataEpochs[device] == epoch) {
      if (catalogFetched) {
        _pendingCatalogPeers.remove(device);
        _pendingSongIds.remove(device);
      }
      if (playlists) _pendingPlaylistPeers.remove(device);
    }
    _notify();
    await loadLibrary();
  }

  Future<void> applyPageCatalog(
    String device,
    List<Map<String, dynamic>> songs, {
    bool Function()? isCurrent,
  }) async {
    final peer = peers.firstWhere((peer) => peer.id == device);
    bool active() =>
        !_disposed && peers.contains(peer) && (isCurrent?.call() ?? true);
    await importMusicShareCatalog(
      databasePath,
      device,
      songs,
      isCurrent: active,
    );
    if (!active()) return;
    peer.catalogRevision = shareDigest(jsonEncode({'songs': songs}));
    peer.catalogLoaded = true;
    onCatalogChanged();
    _notify();
    await loadLibrary();
  }
}
