import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

const aiAgentApiPort = 29643;
const aiAgentApiBaseUrl = 'http://127.0.0.1:$aiAgentApiPort/agent';

enum AiAgentRemoteState { stopped, starting, running, stopping }

class AiAgentControlBindings {
  const AiAgentControlBindings({
    required this.databasePath,
    required this.playerState,
    required this.playSong,
    required this.playQueue,
    required this.play,
    required this.pause,
    required this.next,
    required this.previous,
    required this.seek,
    required this.setVolume,
  });

  final String databasePath;
  final Map<String, Object?> Function() playerState;
  final bool Function(int songId) playSong;
  final bool Function(List<int> songIds, int startIndex) playQueue;
  final bool Function() play;
  final bool Function() pause;
  final bool Function() next;
  final bool Function() previous;
  final bool Function(double seconds) seek;
  final bool Function(int volume) setVolume;
}

class AiAgentRemoteController extends ChangeNotifier {
  AiAgentControlBindings? _bindings;
  HttpServer? _server;
  var _state = AiAgentRemoteState.stopped;

  AiAgentRemoteState get state => _state;
  bool get isRunning => _state == AiAgentRemoteState.running;
  bool get isBusy =>
      _state == AiAgentRemoteState.starting ||
      _state == AiAgentRemoteState.stopping;
  String get endpoint => aiAgentApiBaseUrl;
  String? get databasePath => _bindings?.databasePath;

  void attach(AiAgentControlBindings bindings) {
    _bindings = bindings;
    notifyListeners();
  }

  Future<void> detach() async {
    await stop();
    _bindings = null;
    notifyListeners();
  }

  Future<void> start() async {
    if (isRunning) {
      return;
    }
    final bindings = _bindings!;
    _setState(AiAgentRemoteState.starting);
    try {
      final router =
          Router()
            ..get('/agent', _handleInfo)
            ..get('/agent/state', _handlePlayerState)
            ..post('/agent/control', _handleControl);
      final handler = Pipeline()
          .addMiddleware(_localAgentOnly())
          .addHandler(router.call);
      _server = await shelf_io.serve(
        handler,
        InternetAddress.loopbackIPv4,
        aiAgentApiPort,
        shared: false,
      );
      _bindings = bindings;
      _setState(AiAgentRemoteState.running);
    } on Object {
      _server = null;
      _setState(AiAgentRemoteState.stopped);
      rethrow;
    }
  }

  Future<void> stop() async {
    final server = _server;
    if (server == null) {
      _setState(AiAgentRemoteState.stopped);
      return;
    }
    _setState(AiAgentRemoteState.stopping);
    await server.close(force: true);
    _server = null;
    _setState(AiAgentRemoteState.stopped);
  }

  Middleware _localAgentOnly() {
    return (innerHandler) {
      return (request) {
        final connectionInfo =
            request.context['shelf.io.connection_info'] as HttpConnectionInfo;
        if (!connectionInfo.remoteAddress.isLoopback ||
            request.headers['origin'] != null) {
          return _jsonResponse(HttpStatus.forbidden, const {
            'error': 'local_agent_only',
          });
        }
        return innerHandler(request);
      };
    };
  }

  Response _handleInfo(Request request) {
    final bindings = _bindings!;
    return _jsonResponse(HttpStatus.ok, {
      'endpoint': aiAgentApiBaseUrl,
      'endpoints': {
        'info': {'method': 'GET', 'path': '/agent'},
        'state': {'method': 'GET', 'path': '/agent/state'},
        'control': {'method': 'POST', 'path': '/agent/control'},
      },
      'database': {
        'type': 'sqlite',
        'path': bindings.databasePath,
        'songTable': 'Music',
        'songIdColumn': 'Id',
      },
      'actions': {
        'play_song': {'songId': 'integer'},
        'play_queue': {'songIds': 'integer[]', 'startIndex': 'integer'},
        'play': const <String, Object?>{},
        'pause': const <String, Object?>{},
        'next': const <String, Object?>{},
        'previous': const <String, Object?>{},
        'seek': {'seconds': 'number'},
        'set_volume': {'value': 'integer (0-100)'},
      },
    });
  }

  Response _handlePlayerState(Request request) {
    return _jsonResponse(HttpStatus.ok, _bindings!.playerState());
  }

  Future<Response> _handleControl(Request request) async {
    final Object? decoded;
    try {
      decoded = jsonDecode(await request.readAsString());
    } on FormatException {
      return _invalidRequest('invalid_json');
    }
    if (decoded is! Map<String, dynamic>) {
      return _invalidRequest('invalid_body');
    }
    final action = decoded['action'];
    if (action is! String) {
      return _invalidRequest('missing_action');
    }

    final bindings = _bindings!;
    final bool executed;
    switch (action) {
      case 'play_song':
        final songId = decoded['songId'];
        if (songId is! int) {
          return _invalidRequest('invalid_song_id');
        }
        executed = bindings.playSong(songId);
      case 'play_queue':
        final rawSongIds = decoded['songIds'];
        final startIndex = decoded['startIndex'];
        if (rawSongIds is! List ||
            rawSongIds.any((value) => value is! int) ||
            startIndex is! int) {
          return _invalidRequest('invalid_queue');
        }
        executed = bindings.playQueue(rawSongIds.cast<int>(), startIndex);
      case 'play':
        executed = bindings.play();
      case 'pause':
        executed = bindings.pause();
      case 'next':
        executed = bindings.next();
      case 'previous':
        executed = bindings.previous();
      case 'seek':
        final seconds = decoded['seconds'];
        if (seconds is! num) {
          return _invalidRequest('invalid_seconds');
        }
        executed = bindings.seek(seconds.toDouble());
      case 'set_volume':
        final value = decoded['value'];
        if (value is! int || value < 0 || value > 100) {
          return _invalidRequest('invalid_volume');
        }
        executed = bindings.setVolume(value);
      default:
        return _invalidRequest('unknown_action');
    }

    if (!executed) {
      return _jsonResponse(HttpStatus.unprocessableEntity, {
        'ok': false,
        'action': action,
        'error': 'action_not_available',
      });
    }
    return _jsonResponse(HttpStatus.ok, {
      'ok': true,
      'action': action,
      'player': bindings.playerState(),
    });
  }

  Response _invalidRequest(String error) {
    return _jsonResponse(HttpStatus.badRequest, {'ok': false, 'error': error});
  }

  Response _jsonResponse(int statusCode, Map<String, Object?> body) {
    return Response(
      statusCode,
      body: jsonEncode(body),
      headers: {
        HttpHeaders.contentTypeHeader: 'application/json; charset=utf-8',
      },
    );
  }

  void _setState(AiAgentRemoteState state) {
    if (_state == state) {
      return;
    }
    _state = state;
    notifyListeners();
  }
}

final aiAgentRemoteController = AiAgentRemoteController();
