part of 'music_share_controller.dart';

extension MusicSharePageData on MusicShareController {
  Future<void> applyDirectoryChanges(
    String device,
    Map<String, dynamic> result, {
    bool notify = true,
  }) async {
    final changed = (result['changed'] as List?)?.cast<int>() ?? const <int>[];
    final songs = result['songs'] as List;
    final removed = (result['removed'] as List).cast<int>();
    if (songs.isEmpty && removed.isEmpty) {
      if (notify && changed.isNotEmpty) onCatalogChanged(device);
      return;
    }
    try {
      await importMusicShareCatalog(
        databasePath,
        device,
        songs.map((song) => (song as Map).cast<String, dynamic>()).toList(),
        replace: false,
        removedSongIds: removed,
        isCurrent: () => !_disposed && peers.any((peer) => peer.id == device),
      );
      if (notify) onCatalogChanged(device);
    } catch (error, stack) {
      SystemLog.error(
        'Remote change saved but cache update failed',
        error,
        stack,
      );
      if (notify) onCatalogChanged(device);
    }
  }

  /// Called by a page entry or its explicit retry, never by connection or WS events.
  Future<void> readPlaylistData(String device) async {
    await ready;
    final peer = peers.firstWhere((peer) => peer.id == device);
    // Page reads do not wait for connection or notification maintenance.
    bool active() => !_disposed && peers.contains(peer);
    final epoch = _peerDataEpochs[device];
    await _playlistClient.refresh(peer, canApply: active);
    if (!active()) return;
    peer.status = MusicPeerStatus.online;
    if (_peerDataEpochs[device] == epoch) {
      _pendingPlaylistPeers.remove(device);
    }
    _notify();
  }
}
