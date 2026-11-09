import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;

import '../library/data/library_repository.dart';
import '../library/data/library_models.dart';
import '../settings/settings_model.dart';
import 'music_share_catalog.dart';
import 'music_share_identity.dart';
import 'music_share_models.dart';

class MusicShareServer {
  MusicShareServer({
    required this.identity,
    required this.repository,
    required this.name,
    required this.grants,
    required this.onChanged,
  });

  final MusicShareIdentity identity;
  final LibraryRepository repository;
  final String Function() name;
  final Map<String, String> grants;
  final void Function() onChanged;
  final requests = <String, MusicPairRequest>{};
  final _streams = <String, Set<HttpResponse>>{};
  HttpServer? _server;
  RawDatagramSocket? _discovery;
  Timer? _expiryTimer;
  String _rootPath = '';
  final _songs = <int, LibrarySong>{};
  String _catalog = '{"songs":[]}';
  String catalogRevision = '';

  void updateLibrary(LibraryContentData snapshot) {
    _rootPath = snapshot.rootPath;
    _songs.clear();
    for (final song in snapshot.songs) {
      if (!isRemoteMusicPath(song.path) && p.isWithin(_rootPath, song.path)) {
        _songs[song.id] = song;
      }
    }
    _catalog = jsonEncode({
      'songs': _songs.values.map(sharedSongJson).toList(),
    });
    catalogRevision = shareDigest(_catalog);
  }

  bool get running => _server != null;

  Future<void> start({int port = musicSharePort}) async {
    _server = await HttpServer.bindSecure(
      InternetAddress.anyIPv4,
      port,
      identity.serverContext(),
    );
    _server!.listen((request) => unawaited(_handle(request)));
    try {
      _discovery = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        musicDiscoveryPort,
      );
      _discovery!.listen((event) {
        if (event != RawSocketEvent.read) return;
        final datagram = _discovery!.receive();
        if (datagram == null || datagram.data.length > 512) return;
        if (utf8.decode(datagram.data, allowMalformed: true) !=
            'SMPLAYER_DISCOVER_V1') {
          return;
        }
        _discovery!.send(
          utf8.encode(
            jsonEncode({
              'protocol': 'smplayer-music-v1',
              'id': identity.id,
              'name': name(),
              'port': _server!.port,
            }),
          ),
          datagram.address,
          datagram.port,
        );
      });
      _expiryTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        final before = requests.length;
        requests.removeWhere(
          (_, value) => DateTime.now().isAfter(value.expires),
        );
        if (before != requests.length) onChanged();
      });
    } catch (_) {
      await stop();
      rethrow;
    }
  }

  Future<void> changePort(int port) async {
    final replacement = await HttpServer.bindSecure(
      InternetAddress.anyIPv4,
      port,
      identity.serverContext(),
    );
    final previous = _server!;
    _server = replacement;
    replacement.listen((request) => unawaited(_handle(request)));
    await previous.close(force: true);
    _streams.clear();
  }

  Future<void> approve(
    String key,
    bool allow, {
    required Future<void> Function() persist,
  }) async {
    final request = requests[key]!;
    if (DateTime.now().isAfter(request.expires) || request.state != 'pending') {
      return;
    }
    if (!allow) {
      request.state = 'rejected';
      onChanged();
      return;
    }
    final token = newShareSecret();
    final hash = shareDigest(token);
    grants[hash] = request.name;
    try {
      await persist();
    } catch (_) {
      grants.remove(hash);
      onChanged();
      rethrow;
    }
    if (!identical(requests[key], request) ||
        DateTime.now().isAfter(request.expires)) {
      grants.remove(hash);
      await persist();
      throw const MusicShareException('share.pairingEnded');
    }
    request.token = token;
    request.state = 'approved';
    onChanged();
  }

  Future<void> revoke(String hash) async {
    grants.remove(hash);
    final responses = _streams.remove(hash) ?? {};
    for (final response in responses.toList()) {
      try {
        final socket = await response.detachSocket(writeHeaders: false);
        socket.destroy();
      } on HttpException {
        // The client may have closed this response while revocation started.
      } on StateError {
        // An already completed response has no active socket to detach.
      }
    }
    onChanged();
  }

  Future<void> stop() async {
    _expiryTimer?.cancel();
    _discovery?.close();
    _discovery = null;
    await _server?.close(force: true);
    _server = null;
    requests.clear();
    _streams.clear();
  }

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    try {
      if (request.headers.value('origin') != null) {
        response.statusCode = HttpStatus.forbidden;
        return;
      }
      final path = request.uri.path;
      if (request.method == 'GET' && path == '/hello') {
        _json(response, {'id': identity.id, 'name': name(), 'version': 1});
        return;
      }
      if (path == '/pair' && request.method == 'POST') {
        if (requests.length >= 8) {
          response.statusCode = HttpStatus.forbidden;
          return;
        }
        final body = await _readJson(request);
        final secret = body['secret'] as String;
        final clientName = body['name'] as String;
        if (secret.length != 44 ||
            clientName.isEmpty ||
            clientName.length > 80) {
          response.statusCode = HttpStatus.badRequest;
          return;
        }
        final key = shareDigest(secret);
        final code = shareDigest(
          '${identity.fingerprint}:$secret',
        ).substring(0, 8);
        requests[key] = MusicPairRequest(
          secret: secret,
          name: clientName,
          code: code,
        );
        _json(response, {'code': code});
        onChanged();
        return;
      }
      if (path == '/pair/status' && request.method == 'POST') {
        final body = await _readJson(request);
        final key = shareDigest(body['secret'] as String);
        final pending = requests[key];
        if (pending == null || DateTime.now().isAfter(pending.expires)) {
          _json(response, {'state': 'expired'});
          return;
        }
        _json(response, {'state': pending.state, 'token': pending.token});
        return;
      }
      final authorization = request.headers.value(
        HttpHeaders.authorizationHeader,
      );
      if (authorization == null || !authorization.startsWith('Bearer ')) {
        response.statusCode = HttpStatus.unauthorized;
        return;
      }
      final hash = shareDigest(authorization.substring(7));
      if (!grants.containsKey(hash)) {
        response.statusCode = HttpStatus.unauthorized;
        return;
      }
      if (request.method != 'GET' && request.method != 'HEAD') {
        response.statusCode = HttpStatus.methodNotAllowed;
        return;
      }
      if (path == '/status') {
        _json(response, {'name': name(), 'revision': catalogRevision});
        return;
      }
      if (path == '/catalog') {
        response.headers.contentType = ContentType.json;
        response.write(_catalog);
        return;
      }
      final match = RegExp(
        r'^/songs/(\d+)/(audio|artwork|lyrics)$',
      ).firstMatch(path);
      if (match == null) {
        response.statusCode = HttpStatus.notFound;
        return;
      }
      final songId = int.parse(match.group(1)!);
      final song = _songs[songId];
      if (song == null) {
        response.statusCode = HttpStatus.notFound;
        return;
      }
      final resolved = await File(song.path).resolveSymbolicLinks();
      final root = await Directory(_rootPath).resolveSymbolicLinks();
      if (!p.isWithin(root, resolved)) {
        response.statusCode = HttpStatus.forbidden;
        return;
      }
      final kind = match.group(2)!;
      if (kind == 'lyrics') {
        final lyrics = await repository.getSongLyrics(
          songId,
          mode: LyricsRequestMode.local,
        );
        _json(response, {
          'rawText': lyrics.rawText,
          'isSynced': lyrics.isSynced,
          'lines': [
            for (final line in lyrics.lines)
              {'id': line.id, 'time': line.timestampMs, 'text': line.text},
          ],
        });
      } else {
        final file = File(kind == 'audio' ? song.path : song.thumbnailPath);
        if (!await file.exists()) {
          response.statusCode = HttpStatus.notFound;
          return;
        }
        (_streams[hash] ??= {}).add(response);
        try {
          await _sendFile(
            request,
            file,
            kind == 'audio'
                ? ContentType.parse(
                  _audioContentTypes[p.extension(song.path).toLowerCase()]!,
                )
                : ContentType.binary,
          );
        } finally {
          _streams[hash]?.remove(response);
        }
      }
    } on FormatException {
      response.statusCode = HttpStatus.badRequest;
    } on FileSystemException {
      response.statusCode = HttpStatus.notFound;
    } catch (_) {
      // A client may disconnect while seeking or while its grant is revoked.
    } finally {
      await response.close();
    }
  }

  Future<Map<String, dynamic>> _readJson(HttpRequest request) async {
    var size = 0;
    final chunks = <int>[];
    await for (final chunk in request.timeout(const Duration(seconds: 5))) {
      size += chunk.length;
      if (size > 2048) throw const FormatException();
      chunks.addAll(chunk);
    }
    return jsonDecode(utf8.decode(chunks)) as Map<String, dynamic>;
  }

  void _json(HttpResponse response, Object body) {
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(body));
  }
}

const _audioContentTypes = {
  '.aac': 'audio/aac',
  '.aiff': 'audio/aiff',
  '.alac': 'audio/mp4',
  '.ape': 'audio/x-ape',
  '.flac': 'audio/flac',
  '.m4a': 'audio/mp4',
  '.mp3': 'audio/mpeg',
  '.ogg': 'audio/ogg',
  '.opus': 'audio/ogg',
  '.wav': 'audio/wav',
  '.wma': 'audio/x-ms-wma',
};

Future<void> _sendFile(HttpRequest request, File file, ContentType type) async {
  final response = request.response;
  final length = await file.length();
  var start = 0;
  var end = length - 1;
  response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
  final range = request.headers.value(HttpHeaders.rangeHeader);
  if (range != null) {
    final match = RegExp(r'^bytes=(\d*)-(\d*)$').firstMatch(range);
    if (match == null || (match.group(1)!.isEmpty && match.group(2)!.isEmpty)) {
      response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
      response.headers.set(HttpHeaders.contentRangeHeader, 'bytes */$length');
      return;
    }
    if (match.group(1)!.isEmpty) {
      start = max(0, length - int.parse(match.group(2)!));
    } else {
      start = int.parse(match.group(1)!);
      if (match.group(2)!.isNotEmpty) {
        end = min(end, int.parse(match.group(2)!));
      }
    }
    if (start > end || start >= length) {
      response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
      response.headers.set(HttpHeaders.contentRangeHeader, 'bytes */$length');
      return;
    }
    response.statusCode = HttpStatus.partialContent;
    response.headers.set(
      HttpHeaders.contentRangeHeader,
      'bytes $start-$end/$length',
    );
  }
  response.headers.contentType = type;
  response.contentLength = end - start + 1;
  if (request.method != 'HEAD') {
    await response.addStream(file.openRead(start, end + 1));
  }
}
