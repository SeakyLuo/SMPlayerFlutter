import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import 'ai_agent_api.dart';
import 'ai_agent_background_bridge.dart';
import 'ai_agent_discovery.dart';
import 'music_share_background_host.dart';
import 'ai_agent_settings_codec.dart';
import '../settings/settings_model.dart';

enum AiAgentRemoteState { stopped, starting, running, stopping }

class AiAgentControlBindings {
  const AiAgentControlBindings({
    required this.databasePath,
    required this.sharing,
    required this.openPlayer,
    required this.updateSharing,
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
    required this.settings,
    required this.updateSettings,
    required this.loadSystemFonts,
    required this.syncChanges,
  });

  final String databasePath;
  final Future<void> Function() openPlayer;
  final Future<Map<String, Object?>> Function() sharing;
  final Future<void> Function(Map<String, dynamic>) updateSharing;
  final Map<String, Object?> Function() playerState;
  final Future<bool> Function(int songId) playSong;
  final Future<bool> Function(List<int> songIds, int startIndex) playQueue;
  final bool Function() play;
  final bool Function() pause;
  final bool Function() next;
  final bool Function() previous;
  final bool Function(double seconds) seek;
  final bool Function(int volume) setVolume;
  final Future<bool> Function(int songId, Map<String, Object?> properties)
  updateSong;
  final SettingsSnapshot Function() settings;
  final Future<void> Function(AppSettingsUpdate update) updateSettings;
  final Future<List<String>> Function() loadSystemFonts;
  final Future<void> Function(List<String> settings, List<int> songIds)
  syncChanges;
}

class AiAgentRemoteController extends ChangeNotifier {
  AiAgentControlBindings? _bindings;
  HttpServer? _server;
  var _state = AiAgentRemoteState.stopped;
  var _port = defaultAiAgentApiPort;
  Future<List<String>>? _systemFonts;
  final background = AiAgentBackgroundBridge();
  Future<void>? _detaching;
  var _relay = false;
  var _backgroundPending = false;
  Future<void> _transition = Future.value();

  Future<T> _runTransition<T>(Future<T> Function() action) {
    final operation = _transition.then((_) => action());
    _transition = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return operation;
  }

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
    _detaching = null;
    _systemFonts = null;
    notifyListeners();
  }

  Future<void> detach() => _detaching ??= _detach();

  Future<void> _detach() async {
    await stop(detach: true);
    _bindings = null;
    notifyListeners();
  }

  void configurePort(int port) {
    _port = port;
    notifyListeners();
  }

  Future<void> start({required int port}) => _runTransition(() => _start(port));

  Future<void> _start(int port) async {
    if (isRunning) {
      return;
    }
    final bindings = _bindings!;
    _port = port;
    _setState(AiAgentRemoteState.starting);
    try {
      _systemFonts ??= bindings.loadSystemFonts();
      await _systemFonts;
      _server = await _serve(
        background.active || _backgroundPending ? 0 : _port,
      );
      _relay = background.active || _backgroundPending;
      await background.configure(
        enabled: true,
        port: _port,
        uiPort: _server!.port,
      );
      _bindings = bindings;
      _setState(AiAgentRemoteState.running);
    } on Object {
      await _server?.close(force: true);
      _server = null;
      _setState(AiAgentRemoteState.stopped);
      rethrow;
    }
  }

  Future<void> changePort(int port) => _runTransition(() => _changePort(port));

  Future<void> _changePort(int port) async {
    final previousServer = _server!;
    _setState(AiAgentRemoteState.starting);
    HttpServer? nextServer;
    try {
      nextServer = await _serve(
        background.active || _backgroundPending ? 0 : port,
      );
      await background.configure(
        enabled: true,
        port: port,
        uiPort: nextServer.port,
      );
    } on Object {
      await nextServer?.close(force: true);
      _setState(AiAgentRemoteState.running);
      rethrow;
    }
    _server = nextServer;
    _port = port;
    await previousServer.close(force: true);
    _setState(AiAgentRemoteState.running);
  }

  Future<void> stop({bool detach = false}) =>
      _runTransition(() => _stop(detach: detach));

  Future<void> _stop({required bool detach}) async {
    if (detach) {
      await background.disconnect();
    } else {
      await background.configure(enabled: false, port: _port);
    }
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
          ..post('/app/open', (request) async {
            await _bindings!.openPlayer();
            return _jsonResponse(200, {'ok': true, 'playerReady': true});
          })
          ..get('/sharing', _handleSharing)
          ..post('/sharing/update', _handleSharingUpdate)
          ..get('/player/state', _handlePlayerState)
          ..get('/settings', _handleSettings)
          ..post('/settings/update', _handleSettingsUpdate)
          ..post('/app/sync', _handleAppSync)
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

  Response _handleInfo(Request request) => _jsonResponse(
    HttpStatus.ok,
    aiAgentDiscovery(_bindings!.databasePath, endpoint),
  );

  Future<Response> _handleSharing(Request request) async =>
      _jsonResponse(HttpStatus.ok, await _bindings!.sharing());

  Future<Response> _handleSharingUpdate(Request request) async {
    final decoded = await _readRequestBody(request);
    if (decoded is Response) return decoded;
    final body = decoded as Map<String, dynamic>;
    if (body.isEmpty ||
        body.entries.any(
          (entry) =>
              !{'enabled', 'background'}.contains(entry.key) ||
              entry.value is! bool,
        )) {
      return _invalidRequest('invalid_sharing_settings');
    }
    try {
      await _bindings!.updateSharing(body);
      return _jsonResponse(HttpStatus.ok, {
        'ok': true,
        ...await _bindings!.sharing(),
      });
    } catch (error) {
      return _jsonResponse(HttpStatus.unprocessableEntity, {
        'ok': false,
        'error': 'sharing_update_failed',
        'message': '$error',
      });
    }
  }

  Future<void> prepareBackground() => _runTransition(_prepareBackground);

  Future<void> _prepareBackground() async {
    _backgroundPending = true;
    if (!isRunning || _relay) return;
    final previous = _server!;
    _server = await _serve(0);
    _relay = true;
    // Stop accepting on the public port without aborting the AI request that
    // initiated this handoff. Its response finishes on the original socket.
    unawaited(previous.close());
  }

  Future<void> attachBackground(MusicShareBackgroundHost host) =>
      _runTransition(() => _attachBackground(host));

  Future<void> _attachBackground(MusicShareBackgroundHost host) async {
    if (isRunning) {
      await host.configureAgent(
        enabled: true,
        port: _port,
        uiPort: _server!.port,
      );
    }
    background.host = host;
    _backgroundPending = false;
  }

  Future<void> restoreForeground() => _runTransition(_restoreForeground);

  Future<void> _restoreForeground() async {
    _backgroundPending = false;
    await background.disconnect(stop: true);
    if (!isRunning || !_relay) return;
    final previous = _server!;
    _server = await _serve(_port);
    _relay = false;
    unawaited(previous.close());
  }

  Response _handlePlayerState(Request request) {
    return _jsonResponse(HttpStatus.ok, _bindings!.playerState());
  }

  Future<List<String>> _settingFonts() async {
    final fonts = await _systemFonts!;
    final current = _bindings!.settings().desktopLyricsFontFamily;
    return [
      'system',
      if (current != 'system' && !fonts.contains(current)) current,
      ...fonts,
    ];
  }

  Future<Response> _handleSettings(Request request) async {
    try {
      final fonts = await _settingFonts();
      return _jsonResponse(HttpStatus.ok, {
        'values': AiAgentSettingsCodec.read(_bindings!.settings()),
        'schema': AiAgentSettingsCodec.schema(fonts),
        'notEditable': {
          'rootPath':
              'Changing the library directory requires a scan operation',
          'aiAgentEnabled': 'Manage the API lifecycle from the settings page',
          'aiAgentPort': 'Manage the API connection from the settings page',
        },
      });
    } on Object {
      return _jsonResponse(HttpStatus.unprocessableEntity, {
        'ok': false,
        'error': 'settings_read_failed',
      });
    }
  }

  Future<Response> _handleSettingsUpdate(Request request) async {
    final decoded = await _readRequestBody(request);
    if (decoded is Response) return decoded;
    final properties = (decoded as Map<String, dynamic>)['properties'];
    if (properties is! Map<String, dynamic>) {
      return _invalidRequest('invalid_settings_properties');
    }
    final AppSettingsUpdate update;
    try {
      update = AiAgentSettingsCodec.decode(properties, await _settingFonts());
    } on FormatException catch (error) {
      return _jsonResponse(HttpStatus.badRequest, {
        'ok': false,
        'error': 'invalid_settings_properties',
        'message': error.message,
      });
    } on Object {
      return _jsonResponse(HttpStatus.unprocessableEntity, {
        'ok': false,
        'error': 'settings_options_failed',
      });
    }
    try {
      await _bindings!.updateSettings(update);
      return _jsonResponse(HttpStatus.ok, {
        'ok': true,
        'values': AiAgentSettingsCodec.read(_bindings!.settings()),
      });
    } on Object {
      return _jsonResponse(HttpStatus.unprocessableEntity, {
        'ok': false,
        'error': 'settings_update_failed',
      });
    }
  }

  Future<Response> _handleAppSync(Request request) async {
    final decoded = await _readRequestBody(request);
    if (decoded is Response) return decoded;
    final body = decoded as Map<String, dynamic>;
    final settings =
        body.containsKey('settings') ? body['settings'] : const <String>[];
    final songIds =
        body.containsKey('songIds') ? body['songIds'] : const <int>[];
    final fields = AiAgentSettingsCodec.read(_bindings!.settings());
    if (body.keys.any((key) => key != 'settings' && key != 'songIds') ||
        settings is! List ||
        settings.any((key) => key is! String || !fields.containsKey(key)) ||
        songIds is! List ||
        songIds.length > 128 ||
        songIds.any((id) => id is! int) ||
        (settings.isEmpty && songIds.isEmpty)) {
      return _invalidRequest('invalid_sync_changes');
    }
    try {
      await _bindings!.syncChanges(
        settings.cast<String>(),
        songIds.cast<int>(),
      );
      return _jsonResponse(HttpStatus.ok, {
        'ok': true,
        'settings': settings,
        'songIds': songIds,
      });
    } on FormatException catch (error) {
      return _jsonResponse(HttpStatus.badRequest, {
        'ok': false,
        'error': 'invalid_sync_changes',
        'message': error.message,
      });
    } on Object {
      return _jsonResponse(HttpStatus.unprocessableEntity, {
        'ok': false,
        'error': 'app_sync_failed',
      });
    }
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
    return _playerOperationResponse(
      'song_play',
      await _bindings!.playSong(songId),
    );
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
      await _bindings!.playQueue(rawSongIds.cast<int>(), startIndex),
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
