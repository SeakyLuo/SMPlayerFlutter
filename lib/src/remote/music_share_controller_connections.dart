part of 'music_share_controller.dart';

extension MusicShareConnections on MusicShareController {
  Future<void> checkConnections() async {
    if (_checking || _disposed) return;
    _checking = true;
    try {
      final targets =
          peers
              .where(
                (peer) =>
                    peer.status == MusicPeerStatus.online ||
                    (autoConnect &&
                        peer.id == lastConnectedPeerId &&
                        peer.status != MusicPeerStatus.unauthorized),
              )
              .toList();
      final failed = <MusicPeer>[];
      await Future.wait(
        targets.map((peer) async {
          try {
            await syncPeer(
              peer,
              importCatalog: peer.status != MusicPeerStatus.online,
            );
          } catch (_) {
            if (peer.status == MusicPeerStatus.offline) failed.add(peer);
            // Background checks update connection state; user actions show a toast.
          }
        }),
      );
      if (failed.isEmpty) return;
      final addresses = {for (final peer in failed) peer.id: peer.address};
      try {
        await discover();
      } on SocketException {
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
    }
  }

  Future<void> syncPeer(
    MusicPeer peer, {
    bool importCatalog = true,
    bool rememberConnection = false,
  }) async {
    final transport = MusicShareTransport(
      peer.address,
      fingerprint: peer.fingerprint,
      token: peer.token,
    );
    final previous = peer.status;
    var reachable = false;
    try {
      final status = await transport.json('/status');
      reachable = true;
      peer.supportsPlaylists = status['playlistSupport'] == true;
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
      if (peer.supportsPlaylists) await _playlistClient.refresh(peer);
      peer.status = MusicPeerStatus.online;
      if (rememberConnection) {
        lastConnectedPeerId = peer.id;
        await save();
      }
    } on MusicShareException catch (error) {
      peer.status =
          error.messageKey == 'share.authorizationRequired'
              ? MusicPeerStatus.unauthorized
              : reachable
              ? MusicPeerStatus.online
              : MusicPeerStatus.offline;
      rethrow;
    } catch (_) {
      peer.status =
          reachable ? MusicPeerStatus.online : MusicPeerStatus.offline;
      rethrow;
    } finally {
      transport.close();
      if (previous != peer.status) _notify();
    }
  }
}
