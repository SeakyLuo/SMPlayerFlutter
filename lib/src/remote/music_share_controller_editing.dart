part of 'music_share_controller.dart';

extension MusicShareEditing on MusicShareController {
  Future<Map<String, dynamic>> _historyRequest(
    String device,
    String operation,
    Map<String, dynamic> values,
  ) async {
    await ready;
    final peer = peerFor(remoteMusicPath(device, 0));
    final transport = MusicShareTransport(
      peer.address,
      fingerprint: peer.fingerprint,
      token: peer.token,
      onNetworkError:
          (error, stack) => _requestConnectionRecovery(peer, error, stack),
    );
    try {
      final section = switch (operation) {
        'getSearches' => 'searches',
        'getBrowses' => 'browses',
        'getPlayed' => 'played',
        _ => null,
      };
      final reading = operation == 'get' || section != null;
      return await transport.json(
        section == null ? '/history' : '/history?section=$section',
        method: reading ? 'GET' : 'POST',
        body: reading ? null : {'operation': operation, ...values},
      );
    } finally {
      transport.close();
    }
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
        if (result.containsKey('songs')) {
          await applyDirectoryChanges(peer.id, result, notify: false);
        }
        if (Uri.parse(endpoint).path == '/songs/favorites') {
          await repository.applyRemoteSongFavorites(
            peer.id,
            ((body as Map)['ids'] as List).cast<int>(),
            (body['data'] as Map)['favorite'] as bool,
          );
        }
        final batchIds =
            body is Map && body.containsKey('ids')
                ? (body['ids'] as List).cast<int>()
                : null;
        final ids = Uri.parse(endpoint).queryParameters['ids'];
        _invalidatePeerData(
          peer,
          catalog: false,
          songIds:
              batchIds ??
              (ids == null
                  ? [int.parse(Uri.parse(path).pathSegments.single)]
                  : ids.split(',').map(int.parse).toList()),
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
}
