import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import '../platform/system_log.dart';
import 'ai_agent_api.dart';
import 'ai_agent_discovery.dart';

class AiAgentBackgroundGateway {
  AiAgentBackgroundGateway({required this.databasePath, required this.sharing});
  final String Function() databasePath;
  final Map<String, Object?> Function() sharing;
  HttpServer? _server;
  final _closing = <Future<dynamic>>{};
  final _http = HttpClient()..connectionTimeout = const Duration(seconds: 3);
  int? _uiPort;
  Completer<int>? _opening;
  int _port = defaultAiAgentApiPort;

  Future<void> configure({
    required bool enabled,
    required int port,
    int? uiPort,
  }) async {
    if (enabled && (_server == null || _port != port)) {
      final next = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
      _retireListener();
      _server = next;
      _port = port;
      next.listen(_handle);
    } else if (!enabled) {
      _retireListener();
    }
    _uiPort = uiPort;
    if (uiPort != null && _opening != null) {
      if (!_opening!.isCompleted) _opening!.complete(uiPort);
    }
  }

  void disconnectUI({required bool stop}) {
    _uiPort = null;
    if (stop) _retireListener();
  }

  void _retireListener() {
    final server = _server;
    _server = null;
    if (server != null) {
      late Future<dynamic> closing;
      closing = server.close().whenComplete(() => _closing.remove(closing));
      _closing.add(closing);
    }
  }

  Future<void> _handle(HttpRequest request) async {
    try {
      if (!request.connectionInfo!.remoteAddress.isLoopback ||
          request.headers.value('origin') != null) {
        _json(request.response, 403, {'error': 'local_agent_only'});
      } else if (request.method == 'GET' && request.uri.path == '/agent') {
        _json(
          request.response,
          200,
          aiAgentDiscovery(databasePath(), aiAgentApiBaseUrl(_port)),
        );
      } else if (request.method == 'GET' && request.uri.path == '/sharing') {
        _json(request.response, 200, sharing());
      } else if (request.method == 'POST' && request.uri.path == '/app/open') {
        await _openPlayer();
        _json(request.response, 200, {
          'ok': true,
          'playerReady': true,
          'endpoint': aiAgentApiBaseUrl(_uiPort!),
        });
      } else if (_uiPort == null) {
        _json(request.response, 409, {
          'ok': false,
          'error': 'player_not_open',
          'action': 'POST /app/open before using player or settings operations',
        });
      } else if (request.method == 'POST' &&
          request.uri.path == '/sharing/update') {
        // A sharing change may terminate this host. Send it directly to the UI
        // so the command's response survives stopping the background process.
        request.response.headers.set(
          HttpHeaders.locationHeader,
          'http://127.0.0.1:$_uiPort/sharing/update',
        );
        _json(request.response, HttpStatus.temporaryRedirect, {
          'endpoint': aiAgentApiBaseUrl(_uiPort!),
        });
      } else {
        final body = <int>[];
        await for (final bytes in request.timeout(
          const Duration(seconds: 10),
        )) {
          if (body.length + bytes.length > 65536) {
            throw const FormatException('Request body exceeds 64 KB');
          }
          body.addAll(bytes);
        }
        final upstream = await _http.openUrl(
          request.method,
          Uri.parse('http://127.0.0.1:$_uiPort${request.uri}'),
        );
        upstream.headers.contentType = request.headers.contentType;
        upstream.add(body);
        final response = await upstream.close().timeout(
          const Duration(seconds: 45),
        );
        request.response.statusCode = response.statusCode;
        request.response.headers.contentType = response.headers.contentType;
        await request.response.addStream(response);
      }
    } catch (error, stack) {
      SystemLog.error('Background AI request failed', error, stack);
      _json(request.response, 503, {
        'ok': false,
        'error':
            error is PlatformException
                ? error.code
                : error is TimeoutException
                ? 'player_start_timed_out'
                : 'agent_request_failed',
      });
    } finally {
      await request.response.close();
    }
  }

  Future<void> _openPlayer() async {
    if (_uiPort != null) {
      final request = await _http.postUrl(
        Uri.parse('http://127.0.0.1:$_uiPort/app/open'),
      );
      final response = await request.close().timeout(
        const Duration(seconds: 10),
      );
      await response.drain<void>();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('Opening the player failed');
      }
      return;
    }
    if (_opening case final opening?) {
      await opening.future;
      return;
    }
    final opening = Completer<int>();
    _opening = opening;
    opening.future.ignore();
    try {
      if (Platform.isLinux) {
        await Process.start(
          Platform.resolvedExecutable,
          const [],
          mode: ProcessStartMode.detached,
        );
      } else {
        await const MethodChannel(
          'smplayer_flutter/background_sharing',
        ).invokeMethod<void>('openPlayer');
      }
      await opening.future.timeout(const Duration(seconds: 45));
    } catch (error, stack) {
      if (!opening.isCompleted) opening.completeError(error, stack);
      rethrow;
    } finally {
      _opening = null;
    }
  }

  void _json(HttpResponse response, int status, Map<String, Object?> value) {
    response.statusCode = status;
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(value));
  }

  Future<void> close() async {
    final opening = _opening;
    if (opening != null && !opening.isCompleted) {
      opening.completeError(StateError('Background sharing is stopping'));
    }
    _retireListener();
    await Future.wait(_closing.toList());
    _http.close(force: true);
  }
}
