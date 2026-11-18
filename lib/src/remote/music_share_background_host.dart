import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../library/data/library_models.dart';
import '../platform/system_log.dart';
import 'music_share_background_platform.dart';
import 'music_share_background_runtime.dart' show sharingRuntimeDirectory;
import 'music_share_event_hub.dart';
import 'music_share_host.dart';
import 'music_share_models.dart';

class MusicShareBackgroundHost implements MusicShareHost {
  MusicShareBackgroundHost({
    required this.grants,
    required this.grantIdentities,
    required this.mobileGrants,
    required this.writeGrants,
    required this.onState,
  }) {
    events = _BackgroundHostEvents((scope) => markChanged([scope]));
  }
  final Map<String, String> grants, grantIdentities;
  final Set<String> mobileGrants, writeGrants;
  final void Function(Map<String, dynamic>) onState;
  @override
  final requests = <String, MusicPairRequest>{};
  @override
  late final MusicShareEventHub events;
  final _http = HttpClient()..connectionTimeout = const Duration(seconds: 2);
  WebSocket? _socket;
  late int _controlPort;
  late String _token;
  var _running = false;
  @override
  bool get running => _running;

  Future<void> connect() async {
    final directory = await sharingRuntimeDirectory();
    final file = File(p.join(directory.path, 'host.json'));
    if (await file.exists()) {
      _readDescriptor(await file.readAsString());
      try {
        await _send({'operation': 'status'});
        await _subscribe();
        return;
      } on SocketException {
        // A dead process can leave its previous control descriptor behind.
      }
    }
    final ready = Completer<void>();
    ready.future.ignore();
    final subscription = directory.watch().listen((event) async {
      // The previous host removes its descriptor while completing handoff.
      // Only a newly published descriptor signals that the next host is ready.
      if (event is FileSystemDeleteEvent) return;
      final destination =
          event is FileSystemMoveEvent ? event.destination : null;
      if ((event.path != file.path && destination != file.path) ||
          ready.isCompleted) {
        return;
      }
      try {
        _readDescriptor(await file.readAsString());
        await _send({'operation': 'status'});
        if (!ready.isCompleted) ready.complete();
      } catch (error, stack) {
        if (!ready.isCompleted) ready.completeError(error, stack);
      }
    });
    try {
      await MusicShareBackgroundPlatform.start();
      await ready.future.timeout(const Duration(seconds: 15));
      await _subscribe();
    } finally {
      await subscription.cancel();
    }
  }

  void _readDescriptor(String value) {
    final descriptor = jsonDecode(value) as Map<String, dynamic>;
    _controlPort = descriptor['port'] as int;
    _token = descriptor['token'] as String;
  }

  Future<void> _subscribe() async {
    _socket = await WebSocket.connect(
      'ws://127.0.0.1:$_controlPort/events',
      headers: {HttpHeaders.authorizationHeader: 'Bearer $_token'},
    );
    _socket!.listen(
      (message) {
        _apply(jsonDecode(message as String) as Map<String, dynamic>);
      },
      onDone: () {
        _running = false;
        onState({'running': false});
      },
      onError: (Object error, StackTrace stack) {
        SystemLog.error(
          'Background sharing management connection failed',
          error,
          stack,
        );
        _running = false;
        onState({'running': false});
      },
    );
  }

  Future<void> _send(Map<String, dynamic> body) async {
    final request = await _http.postUrl(
      Uri.parse('http://127.0.0.1:$_controlPort/command'),
    );
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $_token');
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(body));
    final response = await request.close().timeout(const Duration(seconds: 15));
    final value =
        jsonDecode(await utf8.decoder.bind(response).join())
            as Map<String, dynamic>;
    if (response.statusCode != HttpStatus.ok) {
      throw MusicShareException(
        value['error'] as String,
        httpStatusCode: response.statusCode,
      );
    }
    _apply((value['state'] as Map).cast<String, dynamic>());
  }

  void _apply(Map<String, dynamic> state) {
    _running = state['running'] as bool;
    grants
      ..clear()
      ..addAll((state['grants'] as Map).cast<String, String>());
    grantIdentities
      ..clear()
      ..addAll((state['grantIdentities'] as Map).cast<String, String>());
    mobileGrants
      ..clear()
      ..addAll((state['mobileGrants'] as List).cast<String>());
    writeGrants
      ..clear()
      ..addAll((state['writeGrants'] as List).cast<String>());
    requests.clear();
    for (final entry in (state['requests'] as Map).entries) {
      final value = entry.value as Map;
      requests[entry.key as String] = MusicPairRequest(
        name: value['name'] as String,
        code: value['code'] as String,
        isMobile: value['isMobile'] as bool,
        expires: DateTime.parse(value['expires'] as String),
      )..state = value['state'] as String;
    }
    onState(state);
  }

  Future<void> configure({
    required String name,
    required int port,
    required String databasePath,
    String? rootPath,
  }) async {
    final bookmark =
        Platform.isMacOS && rootPath != null
            ? await MusicShareBackgroundPlatform.channel.invokeMethod<String>(
              'directoryBookmark',
              rootPath,
            )
            : null;
    await _send({
      'operation': 'configure',
      'name': name,
      'port': port,
      'databasePath': databasePath,
      if (bookmark != null) 'directoryBookmark': bookmark,
    });
  }

  Future<void> configureAgent({
    required bool enabled,
    required int port,
    int? uiPort,
  }) => _send({
    'operation': 'agent',
    'enabled': enabled,
    'port': port,
    'uiPort': uiPort,
  });

  Future<void> disconnectAgent({required bool stop}) =>
      _send({'operation': 'agent-disconnect', 'stop': stop});

  Future<void> markChanged(List<String> scopes) =>
      _send({'operation': 'changed', 'scopes': scopes});

  @override
  void markCatalogChanged() {
    unawaited(
      markChanged(['library']).catchError((Object error, StackTrace stack) {
        SystemLog.error('Background sharing invalidation failed', error, stack);
      }),
    );
  }

  @override
  void updateLibrary(LibraryContentData snapshot, {bool notify = true}) {
    if (notify) markCatalogChanged();
  }

  @override
  Future<void> start({int port = musicSharePort}) => connect();
  @override
  Future<void> changePort(int port) =>
      _send({'operation': 'port', 'port': port});
  @override
  Future<void> stop() async {
    await _send({'operation': 'stop'});
    await disconnect();
  }

  Future<void> suspend() => _send({'operation': 'pause'});

  Future<void> handoff() async {
    await _send({'operation': 'handoff'});
    await disconnect();
  }

  @override
  Future<void> disconnect() async {
    await _socket?.close();
    _socket = null;
    _http.close(force: true);
  }

  @override
  Future<void> approve(
    String key,
    bool allow, {
    required Future<void> Function() persist,
    bool canWrite = false,
  }) => _send({
    'operation': 'approve',
    'key': key,
    'allow': allow,
    'canWrite': canWrite,
  });
  @override
  Future<void> revoke(
    String hash, {
    required Future<void> Function() persist,
  }) => _send({'operation': 'revoke', 'key': hash});
  @override
  Future<void> setWritePermission(
    String hash,
    bool enabled, {
    required Future<void> Function() persist,
  }) => _send({'operation': 'permission', 'key': hash, 'enabled': enabled});
}

class _BackgroundHostEvents extends MusicShareEventHub {
  _BackgroundHostEvents(this.changed);
  final Future<void> Function(String) changed;
  @override
  void dataChanged(String scope) {
    unawaited(
      changed(scope).catchError((Object error, StackTrace stack) {
        SystemLog.error('Background sharing event failed', error, stack);
      }),
    );
  }
}
