import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../library/data/library_history_changes.dart';

/// Authenticated event connections use the same TLS listener as data requests.
class MusicShareEventHub {
  MusicShareEventHub({this.onDataChanged});
  final void Function(List<String>)? onDataChanged;
  final _clients = <String, Set<WebSocket>>{};
  final _changes = <String>{};
  final _hostChanges = <String>{};
  Timer? _broadcastTimer;

  void attach(String grant, WebSocket socket, bool canWrite) {
    _clients.putIfAbsent(grant, () => {}).add(socket);
    socket.pingInterval = const Duration(seconds: 20);
    socket.add(jsonEncode({'type': 'permissions', 'canWrite': canWrite}));
    socket.listen(
      (_) {},
      onDone: () => _remove(grant, socket),
      onError: (Object error) => _remove(grant, socket),
      cancelOnError: true,
    );
  }

  void _remove(String grant, WebSocket socket) {
    final clients = _clients[grant];
    clients?.remove(socket);
    if (clients != null && clients.isEmpty) _clients.remove(grant);
  }

  void permissionChanged(String grant, bool canWrite) {
    _send(grant, {'type': 'permissions', 'canWrite': canWrite});
  }

  Future<void> revoke(String grant) async {
    _send(grant, {'type': 'revoked'});
    final clients = _clients.remove(grant) ?? {};
    await Future.wait(clients.map((socket) => socket.close()));
  }

  void dataChanged(String scope, {bool notifyHost = true}) {
    _changes.add(scope);
    if (notifyHost) _hostChanges.add(scope);
    _broadcastTimer ??= Timer(const Duration(milliseconds: 100), () {
      final scopes =
          {
            ..._changes,
            // Older clients subscribe to the combined history event.
            if (_changes.any((scope) => scope.startsWith('history:')))
              'history',
            if (_changes.contains(playedHistoryScope) ||
                _changes.contains(browsedHistoryScope))
              recentHistoryScope,
          }.toList();
      final event = {'type': 'data-changed', 'scopes': scopes};
      if (_hostChanges.isNotEmpty) onDataChanged?.call(_hostChanges.toList());
      _hostChanges.clear();
      _changes.clear();
      _broadcastTimer = null;
      for (final grant in _clients.keys) {
        _send(grant, event);
      }
    });
  }

  void _send(String grant, Map<String, Object> event) {
    final message = jsonEncode(event);
    for (final socket in _clients[grant] ?? <WebSocket>{}) {
      if (socket.readyState == WebSocket.open) socket.add(message);
    }
  }

  Future<void> close() async {
    _broadcastTimer?.cancel();
    _broadcastTimer = null;
    _changes.clear();
    _hostChanges.clear();
    final sockets = _clients.values.expand((clients) => clients).toList();
    _clients.clear();
    await Future.wait(sockets.map((socket) => socket.close()));
  }
}
