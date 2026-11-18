import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:path/path.dart' as p;

import '../library/data/library_models.dart';
import '../library/data/library_queries.dart';
import '../library/data/library_repository.dart';
import '../library/data/library_repository_paths.dart';
import '../platform/system_log.dart';
import 'music_share_connection_store.dart';
import 'music_share_event_hub.dart';
import 'music_share_identity.dart';
import 'music_share_models.dart';
import 'music_share_server.dart';

Future<Directory> sharingRuntimeDirectory() async {
  final directory = Directory(
    p.join(await defaultSmPlayerUserDataPath(), 'sharing-runtime'),
  );
  await directory.create(recursive: true);
  return directory;
}

/// A headless Flutter engine entry point, hosted by an OS-managed process.
@pragma('vm:entry-point')
Future<void> musicSharingWorker() async {
  MusicSharingBinding();
  final runtime = MusicShareBackgroundRuntime();
  try {
    await runtime.start();
  } catch (error, stack) {
    SystemLog.error('Background sharing startup failed', error, stack);
    await SystemLog.flush();
    await runtime.close();
    exit(1);
  }
}

class MusicSharingBinding extends BindingBase
    with SchedulerBinding, ServicesBinding {}

class MusicShareBackgroundRuntime {
  late MusicShareServer server;
  late LibraryRepository repository;
  late Map<String, dynamic> config;
  late String databasePath;
  late File descriptor;
  RandomAccessFile? _lock;
  HttpServer? _control;
  final _token = newShareSecret();
  final _clients = <WebSocket>{};
  Future<void> _commands = Future.value();
  var _initialized = false;
  final _ready = Completer<void>();
  var _dataRevision = 0;
  List<String> _changedScopes = const [];
  late LibraryContentData _library;

  Future<void> start() async {
    const MethodChannel(
      'smplayer_flutter/background_sharing',
    ).setMethodCallHandler((call) async {
      if (call.method == 'stopSharing') {
        await _ready.future;
        final stop = _commands.then((_) async {
          await _command({'operation': 'stop'});
          await close();
          await SystemLog.flush();
          exit(0);
        });
        _commands = stop;
        await stop;
      }
    });
    final directory = await sharingRuntimeDirectory();
    _lock = await File(
      p.join(directory.path, 'host.lock'),
    ).open(mode: FileMode.append);
    await _lock!.lock(FileLock.exclusive);
    descriptor = File(p.join(directory.path, 'host.json'));
    config = (await MusicShareConnectionStore.readHost())!;
    if (config['sharing'] != true || config['backgroundSharing'] != true) {
      await close();
      exit(0);
    }
    databasePath = config['backgroundDatabasePath'] as String;
    repository = LibraryRepository(
      databaseFileResolver: () async => File(databasePath),
    );
    await repository.initializeLibraryDatabase();
    server = MusicShareServer(
      identity: await MusicShareIdentity.load(),
      repository: repository,
      name: () => config['name'] as String,
      grants: (config['grants'] as Map).cast<String, String>(),
      grantIdentities:
          (config['grantIdentities'] as Map).cast<String, String>(),
      mobileGrants: (config['mobileGrants'] as List).cast<String>().toSet(),
      writeGrants: (config['writeGrants'] as List).cast<String>().toSet(),
      eventHub: MusicShareEventHub(
        onDataChanged: (scopes) {
          _dataRevision++;
          _changedScopes = scopes;
          _broadcast();
        },
      ),
      onChanged: _broadcast,
      onLibraryChanged: _broadcast,
      onPeerConnected: (_) => _broadcast(),
    );
    _initialized = true;
    _library = await repository.queryLibrary(
      const LibraryDataQuery(LibraryQueryKind.context),
    );
    server.updateLibrary(_library, notify: false);
    await server.start(port: config['port'] as int);
    _control = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _control!.listen(_handle);
    if (!Platform.isWindows) {
      final mode = await Process.run('/bin/chmod', ['700', directory.path]);
      if (mode.exitCode != 0)
        throw FileSystemException(
          'Cannot protect sharing runtime directory',
          directory.path,
        );
    }
    final temporary = File('${descriptor.path}.new');
    await temporary.writeAsString(
      jsonEncode({'port': _control!.port, 'token': _token}),
      flush: true,
    );
    await temporary.rename(descriptor.path);
    _ready.complete();
    SystemLog.info('Independent background sharing ready');
  }

  Map<String, dynamic> get state => {
    'dataRevision': _dataRevision,
    'changedScopes': _changedScopes,
    'running': server.running,
    'name': config['name'],
    'port': config['port'],
    'sharing': config['sharing'],
    'grants': server.grants,
    'grantIdentities': server.grantIdentities,
    'mobileGrants': server.mobileGrants.toList(),
    'writeGrants': server.writeGrants.toList(),
    'requests': {
      for (final entry in server.requests.entries)
        entry.key: {
          'name': entry.value.name,
          'code': entry.value.code,
          'state': entry.value.state,
          'expires': entry.value.expires.toIso8601String(),
          'isMobile': entry.value.isMobile,
        },
    },
  };

  Future<void> _persist() async {
    config.addAll({
      'grants': server.grants,
      'grantIdentities': server.grantIdentities,
      'mobileGrants': server.mobileGrants.toList(),
      'writeGrants': server.writeGrants.toList(),
    });
    await MusicShareConnectionStore.writeHost(config);
  }

  void _broadcast() {
    if (!_initialized) return;
    final message = jsonEncode(state);
    for (final socket in _clients) {
      if (socket.readyState == WebSocket.open) socket.add(message);
    }
  }

  Future<void> _handle(HttpRequest request) async {
    if (request.headers.value(HttpHeaders.authorizationHeader) !=
            'Bearer $_token' ||
        request.headers.value('origin') != null) {
      request.response.statusCode = HttpStatus.forbidden;
      await request.response.close();
      return;
    }
    if (request.uri.path == '/events' && request.method == 'GET') {
      final socket = await WebSocketTransformer.upgrade(request);
      _clients.add(socket);
      socket.add(jsonEncode(state));
      socket.listen(
        (_) {},
        onDone: () => _clients.remove(socket),
        onError: (Object _) => _clients.remove(socket),
      );
      return;
    }
    if (request.uri.path != '/command' || request.method != 'POST') {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }
    var terminate = false;
    final operation = _commands.then((_) async {
      try {
        final body =
            jsonDecode(
                  await utf8.decoder
                      .bind(request)
                      .join()
                      .timeout(const Duration(seconds: 10)),
                )
                as Map<String, dynamic>;
        await _command(body);
        terminate =
            body['operation'] == 'stop' || body['operation'] == 'handoff';
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({'state': state}));
      } catch (error, stack) {
        SystemLog.error('Background sharing command failed', error, stack);
        request.response.statusCode = HttpStatus.internalServerError;
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'error':
                error is MusicShareException
                    ? error.messageKey
                    : 'share.backgroundOperationFailed',
          }),
        );
      } finally {
        await request.response.close();
      }
    });
    _commands = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    await operation;
    if (terminate) {
      await close();
      await SystemLog.flush();
      exit(0);
    }
  }

  Future<void> _command(Map<String, dynamic> body) async {
    switch (body['operation']) {
      case 'status':
        break;
      case 'approve':
        final key = body['key'] as String;
        if (!server.requests.containsKey(key))
          throw const MusicShareException('share.pairingEnded');
        await server.approve(
          key,
          body['allow'] as bool,
          canWrite: body['canWrite'] as bool,
          persist: _persist,
        );
      case 'revoke':
        await server.revoke(body['key'] as String, persist: _persist);
      case 'permission':
        await server.setWritePermission(
          body['key'] as String,
          body['enabled'] as bool,
          persist: _persist,
        );
      case 'port':
        await _configure(
          config['name'] as String,
          body['port'] as int,
          databasePath,
        );
      case 'configure':
        if (body['directoryBookmark'] case final String bookmark) {
          await const MethodChannel(
            'smplayer_flutter/background_sharing',
          ).invokeMethod<void>('updateFileAccess', bookmark);
        }
        await _configure(
          body['name'] as String,
          body['port'] as int,
          body['databasePath'] as String,
        );
      case 'pause':
        await server.stop();
      case 'changed':
        if (!server.running) return;
        _library = await repository.queryLibrary(
          const LibraryDataQuery(LibraryQueryKind.context),
        );
        server.updateLibrary(_library, notify: false);
        for (final scope in (body['scopes'] as List).cast<String>()) {
          if (scope == 'library') {
            server.markCatalogChanged();
          } else {
            server.events.dataChanged(scope);
          }
        }
      case 'handoff':
        await server.stop();
      case 'stop':
        config['sharing'] = false;
        await server.stop();
        await _persist();
      default:
        throw const FormatException('Unknown background sharing command');
    }
    _broadcast();
  }

  Future<void> _configure(String name, int port, String path) async {
    final previousConfig = Map<String, dynamic>.of(config);
    final previousPath = databasePath;
    final previousLibrary = _library;
    final previousPort = config['port'] as int;
    final switchingDatabase = path != databasePath;
    final wasRunning = server.running;
    try {
      if (switchingDatabase) await server.stop();
      databasePath = path;
      final library = await repository.queryLibrary(
        const LibraryDataQuery(LibraryQueryKind.context),
      );
      if (wasRunning && !switchingDatabase && port != previousPort)
        await server.changePort(port);
      config.addAll({
        'name': name,
        'port': port,
        'backgroundDatabasePath': path,
      });
      await _persist();
      server.updateLibrary(library);
      if (!server.running) {
        await server.start(port: port);
        server.events.dataChanged('library');
      }
      _library = library;
    } catch (_) {
      databasePath = previousPath;
      config = previousConfig;
      server.updateLibrary(previousLibrary, notify: false);
      if (switchingDatabase) {
        if (server.running) await server.stop();
        if (wasRunning) await server.start(port: previousPort);
      } else if (wasRunning && port != previousPort) {
        await server.changePort(previousPort);
      }
      await _persist();
      rethrow;
    }
  }

  Future<void> close() async {
    if (_initialized) await server.stop();
    for (final socket in _clients) {
      await socket.close();
    }
    await _control?.close(force: true);
    if (_control != null && await descriptor.exists())
      await descriptor.delete();
    await _lock?.close();
  }
}
