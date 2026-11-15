import 'music_share_directory_index.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;

import '../library/data/library_repository.dart';
import '../library/data/library_models.dart';
import '../library/data/library_queries.dart';
import '../settings/settings_model.dart' hide MusicLibrarySortCriterion;
import 'music_share_catalog.dart';
import 'music_share_random_play.dart';
import 'music_share_library_queries.dart';
import 'music_share_event_hub.dart';
import 'music_share_song_editor.dart';
import 'music_share_batch_editor.dart';
import 'music_share_preferences.dart';
import 'music_share_files.dart';
import 'music_share_directory_commands.dart';
import 'music_share_directory_refresh.dart';
import '../platform/system_log.dart';
import 'music_share_playlists.dart';
import 'music_share_identity.dart';
import 'music_share_models.dart';
import 'music_share_pair_identity.dart';
import 'music_share_hidden_storage.dart';
import 'music_share_lyrics_search.dart';
import 'music_share_download_manifest.dart';

part 'music_share_http_files.dart';

part 'music_share_server_catalog.dart';
part 'music_share_server_http.dart';

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
  late LibraryContentData _sharedSnapshot;
  final _catalogIdentity = DateTime.now().microsecondsSinceEpoch.toString();
  var _catalogGeneration = 0;
  String get catalogRevision =>
      shareDigest('$_catalogIdentity:$_catalogGeneration');
  final events = MusicShareEventHub();

  late final _files = MusicShareFiles(repository, () {
    onLibraryChanged();
  });
  late final _directoryCommands = MusicShareDirectoryCommands(repository);

  void updateLibrary(LibraryContentData snapshot, {bool notify = true}) {
    _sharedSnapshot = snapshot;
    _rootPath = snapshot.rootPath;
    _songs.clear();
    for (final song in snapshot.songs) {
      if (!isRemoteMusicPath(song.path) && p.isWithin(_rootPath, song.path))
        _songs[song.id] = song;
    }
    if (notify) markCatalogChanged();
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
    await _directoryCommands.close();
    requests.clear();
    _connectedClients.clear();
    _streams.clear();
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
    final encoded = jsonEncode(body);
    response.write(encoded);
  }
}
