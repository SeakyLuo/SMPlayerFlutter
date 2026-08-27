import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import 'ai_agent_api.dart';

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
    required this.updateSong,
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
  final Future<bool> Function(int songId, Map<String, Object?> properties)
  updateSong;
}

class AiAgentRemoteController extends ChangeNotifier {
  AiAgentControlBindings? _bindings;
  HttpServer? _server;
  var _state = AiAgentRemoteState.stopped;
  var _port = defaultAiAgentApiPort;

  AiAgentRemoteState get state => _state;
  bool get isRunning => _state == AiAgentRemoteState.running;
  bool get isBusy =>
      _state == AiAgentRemoteState.starting ||
      _state == AiAgentRemoteState.stopping;
  int get port => _port;
  String get endpoint => aiAgentApiBaseUrl(_port);
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

  void configurePort(int port) {
    _port = port;
    notifyListeners();
  }

  Future<void> start({required int port}) async {
    if (isRunning) {
      return;
    }
    final bindings = _bindings!;
    _port = port;
    _setState(AiAgentRemoteState.starting);
    try {
      _server = await _serve(_port);
      _bindings = bindings;
      _setState(AiAgentRemoteState.running);
    } on Object {
      _server = null;
      _setState(AiAgentRemoteState.stopped);
      rethrow;
    }
  }

  Future<void> changePort(int port) async {
    final previousServer = _server!;
    _setState(AiAgentRemoteState.starting);
    final HttpServer nextServer;
    try {
      nextServer = await _serve(port);
    } on Object {
      _setState(AiAgentRemoteState.running);
      rethrow;
    }
    _server = nextServer;
    _port = port;
    await previousServer.close(force: true);
    _setState(AiAgentRemoteState.running);
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

  Future<HttpServer> _serve(int port) {
    final router =
        Router()
          ..get('/agent', _handleInfo)
          ..get('/player/state', _handlePlayerState)
          ..post('/song/play', _handleSongPlay)
          ..post('/queue/play', _handleQueuePlay)
          ..post('/player/play', _handlePlay)
          ..post('/player/pause', _handlePause)
          ..post('/player/next', _handleNext)
          ..post('/player/previous', _handlePrevious)
          ..post('/player/seek', _handleSeek)
          ..post('/player/volume', _handleVolume)
          ..post('/song/update', _handleSongUpdate);
    final handler = Pipeline()
        .addMiddleware(_localAgentOnly())
        .addHandler(router.call);
    return shelf_io.serve(
      handler,
      InternetAddress.loopbackIPv4,
      port,
      shared: false,
    );
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
      'endpoint': endpoint,
      'endpoints': {
        'info': {'method': 'GET', 'path': '/agent'},
        'playerState': {'method': 'GET', 'path': '/player/state'},
        'songPlay': {
          'method': 'POST',
          'path': '/song/play',
          'body': {'songId': 'integer'},
        },
        'queuePlay': {
          'method': 'POST',
          'path': '/queue/play',
          'body': {'songIds': 'integer[]', 'startIndex': 'integer'},
        },
        'playerPlay': {'method': 'POST', 'path': '/player/play'},
        'playerPause': {'method': 'POST', 'path': '/player/pause'},
        'playerNext': {'method': 'POST', 'path': '/player/next'},
        'playerPrevious': {'method': 'POST', 'path': '/player/previous'},
        'playerSeek': {
          'method': 'POST',
          'path': '/player/seek',
          'body': {'seconds': 'number'},
        },
        'playerVolume': {
          'method': 'POST',
          'path': '/player/volume',
          'body': {'value': 'integer (0-100)'},
        },
        'songUpdate': {
          'method': 'POST',
          'path': '/song/update',
          'body': {
            'songId': 'integer',
            'properties': {
              'title': 'string',
              'subtitle': 'string',
              'artists': 'string[] (maximum 6)',
              'album': 'string',
              'albumArtist': 'string',
              'publisher': 'string',
              'trackNumber': 'integer',
              'year': 'integer',
              'genre': 'string',
              'composers': 'string',
              'playCount': 'integer',
            },
          },
        },
      },
      'database': {
        'type': 'sqlite',
        'path': bindings.databasePath,
        'songTable': 'Music',
        'songIdColumn': 'Id',
      },
    });
  }

  Response _handlePlayerState(Request request) {
    return _jsonResponse(HttpStatus.ok, _bindings!.playerState());
  }

  Future<Response> _handleSongPlay(Request request) async {
    final decoded = await _readRequestBody(request);
    if (decoded is Response) {
      return decoded;
    }
    final body = decoded as Map<String, dynamic>;
    final songId = body['songId'];
    if (songId is! int) {
      return _invalidRequest('invalid_song_id');
    }
    return _playerOperationResponse('song_play', _bindings!.playSong(songId));
  }

  Future<Response> _handleQueuePlay(Request request) async {
    final decoded = await _readRequestBody(request);
    if (decoded is Response) {
      return decoded;
    }
    final body = decoded as Map<String, dynamic>;
    final rawSongIds = body['songIds'];
    final startIndex = body['startIndex'];
    if (rawSongIds is! List ||
        rawSongIds.any((value) => value is! int) ||
        startIndex is! int) {
      return _invalidRequest('invalid_queue');
    }
    return _playerOperationResponse(
      'queue_play',
      _bindings!.playQueue(rawSongIds.cast<int>(), startIndex),
    );
  }

  Response _handlePlay(Request request) {
    return _playerOperationResponse('play', _bindings!.play());
  }

  Response _handlePause(Request request) {
    return _playerOperationResponse('pause', _bindings!.pause());
  }

  Response _handleNext(Request request) {
    return _playerOperationResponse('next', _bindings!.next());
  }

  Response _handlePrevious(Request request) {
    return _playerOperationResponse('previous', _bindings!.previous());
  }

  Future<Response> _handleSeek(Request request) async {
    final decoded = await _readRequestBody(request);
    if (decoded is Response) {
      return decoded;
    }
    final body = decoded as Map<String, dynamic>;
    final seconds = body['seconds'];
    if (seconds is! num) {
      return _invalidRequest('invalid_seconds');
    }
    return _playerOperationResponse(
      'seek',
      _bindings!.seek(seconds.toDouble()),
    );
  }

  Future<Response> _handleVolume(Request request) async {
    final decoded = await _readRequestBody(request);
    if (decoded is Response) {
      return decoded;
    }
    final body = decoded as Map<String, dynamic>;
    final value = body['value'];
    if (value is! int || value < 0 || value > 100) {
      return _invalidRequest('invalid_volume');
    }
    return _playerOperationResponse('volume', _bindings!.setVolume(value));
  }

  Future<Response> _handleSongUpdate(Request request) async {
    final decoded = await _readRequestBody(request);
    if (decoded is Response) {
      return decoded;
    }
    final body = decoded as Map<String, dynamic>;
    final songId = body['songId'];
    final properties = body['properties'];
    if (songId is! int ||
        properties is! Map<String, dynamic> ||
        !_validSongProperties(properties)) {
      return _invalidRequest('invalid_song_properties');
    }
    try {
      final updated = await _bindings!.updateSong(songId, properties);
      if (!updated) {
        return _jsonResponse(HttpStatus.notFound, {
          'ok': false,
          'error': 'song_not_found',
        });
      }
    } on Object {
      return _jsonResponse(HttpStatus.unprocessableEntity, {
        'ok': false,
        'error': 'song_update_failed',
      });
    }
    return _jsonResponse(HttpStatus.ok, {'ok': true, 'songId': songId});
  }

  Future<Object> _readRequestBody(Request request) async {
    final Object? decoded;
    try {
      decoded = jsonDecode(await request.readAsString());
    } on FormatException {
      return _invalidRequest('invalid_json');
    }
    if (decoded is! Map<String, dynamic>) {
      return _invalidRequest('invalid_body');
    }
    return decoded;
  }

  Response _playerOperationResponse(String operation, bool executed) {
    if (!executed) {
      return _jsonResponse(HttpStatus.unprocessableEntity, {
        'ok': false,
        'operation': operation,
        'error': 'operation_not_available',
      });
    }
    return _jsonResponse(HttpStatus.ok, {
      'ok': true,
      'operation': operation,
      'player': _bindings!.playerState(),
    });
  }

  Response _invalidRequest(String error) {
    return _jsonResponse(HttpStatus.badRequest, {'ok': false, 'error': error});
  }

  bool _validSongProperties(Map<String, dynamic> properties) {
    if (properties.isEmpty) {
      return false;
    }
    const textFields = {
      'title',
      'subtitle',
      'album',
      'albumArtist',
      'publisher',
      'genre',
      'composers',
    };
    const numberFields = {'trackNumber', 'year', 'playCount'};
    for (final entry in properties.entries) {
      if (textFields.contains(entry.key)) {
        if (entry.value is! String) {
          return false;
        }
        continue;
      }
      if (numberFields.contains(entry.key)) {
        if (entry.value is! int || (entry.value as int) < 0) {
          return false;
        }
        continue;
      }
      if (entry.key == 'artists') {
        final artists = entry.value;
        if (artists is! List ||
            artists.length > 6 ||
            artists.any((artist) => artist is! String)) {
          return false;
        }
        continue;
      }
      return false;
    }
    return true;
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
