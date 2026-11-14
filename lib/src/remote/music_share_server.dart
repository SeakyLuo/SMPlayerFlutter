import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;

import '../library/data/library_repository.dart';
import '../library/data/library_models.dart';
import '../settings/settings_model.dart';
import 'music_share_catalog.dart';
import 'music_share_event_hub.dart';
import 'music_share_song_editor.dart';
import 'music_share_batch_editor.dart';
import 'music_share_preferences.dart';
import 'music_share_files.dart';
import 'music_share_playlists.dart';
import 'music_share_identity.dart';
import 'music_share_models.dart';
import 'music_share_pair_identity.dart';

class MusicShareServer {
  MusicShareServer({
    required this.identity,
    required this.repository,
    required this.name,
    required this.grants,
    required this.grantIdentities,
    required this.mobileGrants,
    required this.writeGrants,
    required this.onChanged,
    required this.onLibraryChanged,
    required this.onPeerConnected,
  });

  final MusicShareIdentity identity;
  final LibraryRepository repository;
  final String Function() name;
  final Map<String, String> grants;
  final Map<String, String> grantIdentities;
  final Set<String> mobileGrants;
  final Set<String> writeGrants;
  final void Function() onChanged;
  final void Function() onLibraryChanged;
  final void Function(String name) onPeerConnected;
  final _connectedClients = <String>{};
  final requests = <String, MusicPairRequest>{};
  final _streams = <String, Set<HttpResponse>>{};
  HttpServer? _server;
  RawDatagramSocket? _discovery;
  Timer? _expiryTimer;
  String _rootPath = '';
  final _songs = <int, LibrarySong>{};
  final _deletedPlaylists = <int, (LibraryPlaylist, DateTime)>{};
  String _catalog = '{"songs":[]}';
  String catalogRevision = '';
  String _libraryRevision = '';
  final events = MusicShareEventHub();

  late final _files = MusicShareFiles(repository, (snapshot) {
    updateLibrary(snapshot);
    onLibraryChanged();
  });

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
    final sharedIds = _songs.keys.toSet();
    final revision = shareDigest(
      jsonEncode([
        catalogRevision,
        name(),
        snapshot.playlists
            .where((playlist) => !playlist.isBuiltIn && playlist.id > 0)
            .map((playlist) => sharedPlaylistJson(playlist, sharedIds))
            .toList(),
      ]),
    );
    if (revision != _libraryRevision) {
      _libraryRevision = revision;
      if (running) events.dataChanged('library');
    }
  }

  bool get running => _server != null;

  Future<void> start({int port = musicSharePort}) async {
    await repository.getPreferenceSettings(
      source: 'local',
      unknownAlbumName: '',
    );
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
    await events.close();
    await previous.close(force: true);
    _streams.clear();
  }

  Future<void> approve(
    String key,
    bool allow, {
    required Future<void> Function() persist,
    bool canWrite = false,
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
    final replaced = <String, (String, bool, String?, bool)>{
      if (request.deviceIdentity != null)
        for (final entry in grants.entries)
          if (grantIdentities[entry.key] == request.deviceIdentity ||
              entry.key == request.previousGrant &&
                  !grantIdentities.containsKey(entry.key))
            entry.key: (
              entry.value,
              writeGrants.contains(entry.key),
              grantIdentities[entry.key],
              mobileGrants.contains(entry.key),
            ),
    };
    void restorePrevious() {
      grants.remove(hash);
      writeGrants.remove(hash);
      grantIdentities.remove(hash);
      mobileGrants.remove(hash);
      for (final entry in replaced.entries) {
        grants[entry.key] = entry.value.$1;
        if (entry.value.$2) writeGrants.add(entry.key);
        if (entry.value.$4) mobileGrants.add(entry.key);
        if (entry.value.$3 case final device?) {
          grantIdentities[entry.key] = device;
        }
      }
    }

    for (final old in replaced.keys) {
      grants.remove(old);
      writeGrants.remove(old);
      grantIdentities.remove(old);
      mobileGrants.remove(old);
    }
    grants[hash] = request.name;
    if (request.deviceIdentity case final device?) {
      grantIdentities[hash] = device;
    }
    if (canWrite) writeGrants.add(hash);
    if (request.isMobile) mobileGrants.add(hash);
    try {
      await persist();
    } catch (_) {
      restorePrevious();
      onChanged();
      rethrow;
    }
    if (!identical(requests[key], request) ||
        DateTime.now().isAfter(request.expires)) {
      restorePrevious();
      await persist();
      throw const MusicShareException('share.pairingEnded');
    }
    request.token = token;
    request.state = 'approved';
    onChanged();
    for (final old in replaced.keys) {
      await revoke(old);
    }
  }

  Future<void> revoke(String hash) async {
    _connectedClients.remove(hash);
    grants.remove(hash);
    grantIdentities.remove(hash);
    writeGrants.remove(hash);
    mobileGrants.remove(hash);
    onChanged();
    final responses = _streams.remove(hash) ?? {};
    for (final response in responses) {
      // The client may have closed this response while revocation started.
      // An already completed response has no active socket to detach.
      // A deadline can abort an active response after its headers have been sent.
      response.deadline = Duration.zero;
    }
    await events.revoke(hash);
  }

  Future<void> stop() async {
    _expiryTimer?.cancel();
    _discovery?.close();
    _discovery = null;
    await events.close();
    await _server?.close(force: true);
    _server = null;
    await _files.close();
    requests.clear();
    _connectedClients.clear();
    _streams.clear();
  }

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    var sendingFile = false;
    var upgraded = false;
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
        // Old clients do not provide a device key and cannot be deduplicated.
        final deviceIdentity =
            body.containsKey('publicKey') || body.containsKey('proof')
                ? await verifyPairIdentity(
                  body['publicKey'] as String,
                  body['proof'] as String,
                  identity.fingerprint,
                  secret,
                  clientName,
                )
                : null;
        final previousGrant =
            deviceIdentity != null && body.containsKey('previousToken')
                ? shareDigest(body['previousToken'] as String)
                : null;
        final key = shareDigest(secret);
        final code = shareDigest(
          '${identity.fingerprint}:$secret',
        ).substring(0, 8);
        requests[key] = MusicPairRequest(
          secret: secret,
          name: clientName,
          code: code,
          deviceIdentity: deviceIdentity,
          previousGrant: previousGrant,
          isMobile: request.headers.value('X-Smplayer-Device-Type') == 'mobile',
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
      if (path == '/events' && request.method == 'GET') {
        final socket = await WebSocketTransformer.upgrade(request);
        upgraded = true;
        // A grant can be revoked while the upgrade is awaiting its socket.
        if (!grants.containsKey(hash)) {
          await socket.close(WebSocketStatus.policyViolation);
          return;
        }
        events.attach(hash, socket, writeGrants.contains(hash));
        return;
      }
      if (request.method != 'GET' &&
          request.method != 'HEAD' &&
          !writeGrants.contains(hash)) {
        response.statusCode = HttpStatus.forbidden;
        return;
      }
      if (!{'GET', 'HEAD', 'POST', 'DELETE'}.contains(request.method)) {
        response.statusCode = HttpStatus.methodNotAllowed;
        return;
      }
      if ((path == '/status' || path == '/catalog') &&
          request.method != 'GET' &&
          request.method != 'HEAD') {
        response.statusCode = HttpStatus.methodNotAllowed;
        return;
      }
      if (path == '/status') {
        if (request.method == 'GET' && _connectedClients.add(hash)) {
          onPeerConnected(grants[hash]!);
        }
        _json(response, {
          'name': name(),
          'revision': catalogRevision,
          'canWrite': writeGrants.contains(hash),
          'playlistSupport': true,
          'eventsSupport': true,
        });
        return;
      }
      if (path == '/catalog') {
        response.headers.contentType = ContentType.json;
        response.write(_catalog);
        return;
      }
      if (path == '/playlists') {
        final result = await serveSharedPlaylists(
          request,
          repository,
          _songs.keys.toSet(),
          () => grants.containsKey(hash) && writeGrants.contains(hash),
          _deletedPlaylists,
        );
        if (request.method == 'POST' && response.statusCode == HttpStatus.ok) {
          events.dataChanged('library');
          onLibraryChanged();
        }
        _json(response, result);
        return;
      }
      if (path == '/files') {
        _json(
          response,
          await _files.handle(
            request,
            hash,
            () => grants.containsKey(hash) && writeGrants.contains(hash),
          ),
        );
        return;
      }
      if (path == '/preferences') {
        final result = await handleSharedPreferences(
          request,
          repository,
          _songs,
          _rootPath,
          () => grants.containsKey(hash) && writeGrants.contains(hash),
        );
        if (request.method == 'POST' && response.statusCode == HttpStatus.ok) {
          events.dataChanged('preferences');
          onLibraryChanged();
        }
        _json(response, result);
        return;
      }
      if (path == '/songs/properties' ||
          path == '/songs/artwork' ||
          path == '/songs/favorites') {
        final result = await handleSharedBatchEdit(
          request,
          path.split('/').last,
          _songs,
          _rootPath,
          repository,
          () => grants.containsKey(hash) && writeGrants.contains(hash),
        );
        if (response.statusCode == HttpStatus.ok && request.method != 'GET') {
          updateLibrary(await repository.getLibraryContentData());
          events.dataChanged('library');
          onLibraryChanged();
        }
        _json(response, result);
        return;
      }
      final match = RegExp(
        r'^/songs/(\d+)/(audio|artwork|lyrics|properties|play-count|lyrics-offset)$',
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
      if (kind == 'properties' ||
          kind == 'lyrics-offset' ||
          kind == 'play-count' ||
          request.method == 'POST' ||
          request.method == 'DELETE') {
        final result = await handleSharedSongEdit(
          request,
          song,
          kind,
          repository,
          canWrite:
              () => grants.containsKey(hash) && writeGrants.contains(hash),
        );
        if (response.statusCode == HttpStatus.ok && request.method != 'GET') {
          updateLibrary(await repository.getLibraryContentData());
          events.dataChanged('library');
          onLibraryChanged();
          result.addAll(sharedSongJson(_songs[songId]!));
        }
        _json(response, result);
        return;
      }
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
          sendingFile = true;
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
    } on MusicShareException catch (error) {
      if (error.messageKey != 'share.readOnlyPermission') rethrow;
      response.statusCode = HttpStatus.forbidden;
    } on TypeError {
      response.statusCode = HttpStatus.badRequest;
    } on FormatException {
      response.statusCode = HttpStatus.badRequest;
    } on FileSystemException {
      if (!sendingFile) response.statusCode = HttpStatus.notFound;
    } catch (_) {
      if (!sendingFile) response.statusCode = HttpStatus.internalServerError;
      // A client may disconnect while seeking or while its grant is revoked.
    } finally {
      try {
        if (!upgraded) await response.close();
      } on HttpException {
        // Revocation can close a response while its file stream is finishing.
      } on SocketException {
        // The revoked client no longer has an open connection.
      }
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
