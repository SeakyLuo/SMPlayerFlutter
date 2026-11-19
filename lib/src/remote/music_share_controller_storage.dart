part of 'music_share_controller.dart';

extension MusicShareStorage on MusicShareController {
  Future<Map<String, dynamic>> _storageRequest(
    String device,
    String endpoint, {
    String method = 'GET',
    Object? body,
  }) async {
    final peer = peerFor(remoteMusicPath(device, 0));
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
    _peerTransports[transport] = peer;
    try {
      final result = await transport.json(endpoint, method: method, body: body);
      if (_disposed || !peers.contains(peer)) {
        throw const MusicShareException('share.deviceForgotten');
      }
      if (method != 'GET' && !result.containsKey('conflicts')) {
        final overwritten = result['overwrittenSongIds'] as List?;
        await applyDirectoryChanges(
          device,
          result,
          notify: overwritten == null || overwritten.isNotEmpty,
        );
      }
      return result;
    } on MusicShareException catch (error) {
      if (error.messageKey == 'share.readOnlyPermission') {
        peer.canWrite = false;
        _notify();
      }
      if (error.httpStatusCode == 404 || error.httpStatusCode == 405) {
        throw const MusicShareException('share.directoryUpgradeRequired');
      }
      rethrow;
    } finally {
      _peerTransports.remove(transport);
      transport.close();
    }
  }

  Future<void> _resumeHiddenStorage(
    String device,
    HiddenStorageItem item,
  ) async {
    await _storageRequest(
      device,
      '/hidden-storage',
      method: 'POST',
      body: {'id': item.id},
    );
  }

  Future<List<HiddenStorageItem>> _hiddenStorageItems(String device) async {
    final data = await _storageRequest(device, '/hidden-storage');
    return [
      for (final item in data['items'] as List)
        HiddenStorageItem(
          id: item['id'] as int,
          type: item['type'] as String,
          path: item['path'] as String,
        ),
    ];
  }

  Future<Map<String, dynamic>> _directoryOperation(
    String device,
    String path,
    String operation, {
    String? name,
    Map<String, dynamic> values = const {},
  }) => _storageRequest(
    device,
    '/directories',
    method: 'POST',
    body: {
      'path': path,
      'operation': operation,
      if (name != null) 'name': name,
      ...values,
    },
  );

  Future<Map<String, dynamic>> _storageDirectoryIndex(String device) async {
    final result = await _storageRequest(device, '/directories');
    if (!result.containsKey('rootName') || !result.containsKey('folderInfo')) {
      throw const MusicShareException('share.directoryUpgradeRequired');
    }
    return result;
  }

  Future<Map<String, dynamic>> _refreshStorageDirectory(
    String device,
    String path,
    LocalFolderScanCancellation cancellation,
    void Function(LocalFolderRefreshProgress) onProgress,
  ) async {
    final peer = peerFor(remoteMusicPath(device, 0));
    if (!peer.canWrite) {
      throw const MusicShareException('share.readOnlyPermission');
    }
    final transport = MusicShareTransport(
      peer.address,
      fingerprint: peer.fingerprint,
      token: peer.token,
      onNetworkError:
          (error, stack) => _requestConnectionRecovery(peer, error, stack),
    );
    _peerTransports[transport] = peer;
    try {
      final result = await refreshRemoteDirectory(
        transport,
        path,
        cancellation,
        onProgress,
      );
      if (_disposed || !peers.contains(peer)) {
        throw const MusicShareException('share.deviceForgotten');
      }
      await applyDirectoryChanges(device, result);
      return result;
    } finally {
      _peerTransports.remove(transport);
      transport.close();
    }
  }
}
