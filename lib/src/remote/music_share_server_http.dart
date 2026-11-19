part of 'music_share_server.dart';

extension _MusicShareServerHttp on MusicShareServer {
  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    var sendingFile = false;
    var upgraded = false;
    try {
      if (request.headers.value('origin') != null) {
        response.statusCode = HttpStatus.forbidden;
        _json(response, {'error': 'share.readOnlyPermission'});
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
        _json(response, {'error': 'share.authorizationRequired'});
        return;
      }
      final hash = shareDigest(authorization.substring(7));
      if (!grants.containsKey(hash)) {
        response.statusCode = HttpStatus.unauthorized;
        _json(response, {'error': 'share.authorizationRequired'});
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
          path != '/history' &&
          path != '/random-play' &&
          path != '/library/query' &&
          path != '/library/ids' &&
          !{
            '/songs/properties',
            '/songs/artwork',
            '/songs/favorites',
            '/songs/artist-splits',
          }.contains(path) &&
          !writeGrants.contains(hash)) {
        response.statusCode = HttpStatus.forbidden;
        _json(response, {'error': 'share.readOnlyPermission'});
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
      if (path == '/downloads') {
        if (request.method != 'GET') {
          response.statusCode = HttpStatus.methodNotAllowed;
          return;
        }
        _json(
          response,
          await sharedDownloadManifest(repository, request.uri.queryParameters),
        );
        return;
      }
      if (path == '/lyrics-search') {
        if (request.method != 'GET') {
          response.statusCode = HttpStatus.methodNotAllowed;
          return;
        }
        _json(
          response,
          await sharedLyricsSearch(
            repository,
            request.uri.queryParameters['query']!,
            request.uri.queryParameters['folder']!,
            offset: int.parse(request.uri.queryParameters['offset']!),
            order:
                request.uri.queryParameters.containsKey('order')
                    ? MusicLibrarySortCriterion.values.byName(
                      request.uri.queryParameters['order']!,
                    )
                    : null,
          ),
        );
        return;
      }
      if ((path == '/library/query' || path == '/library/ids') &&
          (request.method == 'GET' || request.method == 'POST')) {
        _json(
          response,
          await sharedLibraryQuery(
            repository,
            await readLibraryQueryParameters(request),
            idsOnly: path == '/library/ids',
          ),
        );
        return;
      }
      if (path == '/artist-analysis' && request.method == 'GET') {
        final context = await repository.queryLibrary(
          const LibraryDataQuery(LibraryQueryKind.context),
        );
        final result = await repository.analyzeLocalArtistBatches(
          folder: context.rootPath,
        );
        List<Map<String, dynamic>> encode(List<ArtistSplitResultItem> items) =>
            [
              for (final item in items)
                {
                  'song': item.songId,
                  'title': item.title,
                  'artist': item.artist,
                  'artists': item.artists,
                },
            ];
        _json(response, {
          'direct': encode(result.directSplits),
          'possible': encode(result.possibleSplits),
          'merges': encode(result.mergeSuggestions),
        });
        return;
      }
      if (path == '/playlists') {
        final result = await serveSharedPlaylists(
          request,
          repository,
          () => grants.containsKey(hash) && writeGrants.contains(hash),
          _deletedPlaylists,
        );
        if (request.method == 'POST' && response.statusCode == HttpStatus.ok) {
          events.dataChanged('playlists');
          onLibraryChanged();
        }
        _json(response, result);
        return;
      }
      if (path == '/random-play' &&
          (request.method == 'GET' || request.method == 'POST')) {
        _json(
          response,
          await sharedRandomPlay(
            repository,
            await readRandomPlayParameters(request),
          ),
        );
        return;
      }
      if (path == '/directories' &&
          (request.method == 'GET' || request.method == 'HEAD')) {
        _json(response, await readSharedDirectoryIndex(repository));
        return;
      }
      if (path == '/hidden-storage' ||
          path == '/directories' ||
          path == '/directory-refresh') {
        final metadata = await repository.queryLibrary(
          const LibraryDataQuery(LibraryQueryKind.context),
        );
        _rootPath = metadata.rootPath;
      }
      if (RegExp(r'^/songs/\d+/').hasMatch(path) ||
          (path == '/catalog' &&
              request.uri.queryParameters.containsKey('ids'))) {
        final match = RegExp(r'^/songs/(\d+)/').firstMatch(path);
        await _readSharedSongsOnAccess(
          match == null
              ? request.uri.queryParameters['ids']!
                  .split(',')
                  .map(int.parse)
                  .toList()
              : [int.parse(match.group(1)!)],
        );
      }
      if (path == '/history' &&
          (request.method == 'GET' || request.method == 'POST')) {
        final result = await handleSharedHistory(
          request,
          repository,
          () => grants.containsKey(hash) && writeGrants.contains(hash),
          onChanged: (operation) {
            final scope =
                operation == 'search' || operation.endsWith('Searches')
                    ? searchHistoryScope
                    : operation == 'browse' || operation.endsWith('Browses')
                    ? browsedHistoryScope
                    : playedHistoryScope;
            libraryHistoryChanges.add((device: 'local', scope: scope));
            events.dataChanged(scope);
          },
        );
        _json(response, result);
        return;
      }
      if (path == '/hidden-storage') {
        late String resumedPath;
        final result = await MusicShareHiddenStorage(
          repository,
          _rootPath,
        ).handle(request, onResumed: (path) => resumedPath = path);
        if (request.method == 'POST' && response.statusCode == HttpStatus.ok) {
          final changed = await _refreshSharedEntries(
            const [],
            folder: resumedPath,
            directoriesChanged: true,
          );
          onLibraryChanged();
          _json(response, {...result, ...sharedCatalogChanges(changed)});
        } else {
          _json(response, result);
        }
        return;
      }
      if (path == '/directory-refresh') {
        (_streams[hash] ??= {}).add(response);
        try {
          await refreshSharedDirectory(
            request,
            repository,
            _rootPath,
            () => grants.containsKey(hash) && writeGrants.contains(hash),
            (folder) async {},
            (result, folder) async {
              final changed = await _refreshSharedEntries(
                const [],
                folder: folder,
                directoriesChanged: true,
              );
              onLibraryChanged();
              return {
                ...sharedCatalogChanges(changed),
                'songPaths': {
                  for (final entry in result.songIdsByPath.entries)
                    p
                        .relative(entry.key, from: _rootPath)
                        .split(p.separator)
                        .join('/'): entry.value,
                },
              };
            },
          );
        } finally {
          _streams[hash]?.remove(response);
        }
        return;
      }
      if (path == '/directories') {
        if (request.method == 'POST') {
          List<int>? changedIds;
          String? refreshedFolder;
          final result = await _directoryCommands.handle(
            request,
            _rootPath,
            hash,
            () => grants.containsKey(hash) && writeGrants.contains(hash),
            onChangedSongs: (ids, folder) {
              changedIds = ids;
              refreshedFolder = folder;
            },
          );
          if (result.containsKey('conflicts')) {
            _json(response, result);
            return;
          }
          final ids = changedIds;
          final changed =
              ids == null
                  ? const <int>{}
                  : await _refreshSharedEntries(
                    ids,
                    folder: refreshedFolder,
                    directoriesChanged: true,
                  );
          if (ids != null) onLibraryChanged();
          _json(response, {
            ...result,
            ...sharedCatalogChanges(changed),
            if (result['overwrittenSongIds'] case final List overwritten)
              'removed': overwritten,
          });
          return;
        }
        if (request.method != 'GET' && request.method != 'HEAD') {
          response.statusCode = HttpStatus.methodNotAllowed;
          return;
        }
        response.statusCode = HttpStatus.methodNotAllowed;
        return;
      }
      if (path == '/catalog') {
        final ids = request.uri.queryParameters['ids'];
        if (ids != null) {
          final requested = ids.split(',').map(int.parse).toSet();
          _json(response, {
            'songs':
                requested
                    .where(_songs.containsKey)
                    .map((id) => sharedSongJson(_songs[id]!))
                    .toList(),
            'removed':
                requested.where((id) => !_songs.containsKey(id)).toList(),
            'revision': catalogRevision,
          });
          return;
        }
        response.statusCode = HttpStatus.notFound;
        return;
      }
      if (path == '/files') {
        final changedIds = <int>[];
        final result = await _files.handle(
          request,
          hash,
          () => grants.containsKey(hash) && writeGrants.contains(hash),
          changedIds.add,
        );
        if (request.method == 'POST' &&
            !result.containsKey('error') &&
            response.statusCode == HttpStatus.ok) {
          final changed = await _refreshSharedEntries(
            changedIds,
            directoriesChanged: true,
          );
          _json(response, {...result, ...sharedCatalogChanges(changed)});
        } else {
          _json(response, result);
        }
        return;
      }
      if (path == '/preferences') {
        final result = await handleSharedPreferences(
          request,
          repository,
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
          path == '/songs/favorites' ||
          path == '/songs/artist-splits') {
        final result = await handleSharedBatchEdit(
          request,
          path.split('/').last,
          repository,
          () => grants.containsKey(hash) && writeGrants.contains(hash),
        );
        if (response.statusCode == HttpStatus.ok &&
            (result.containsKey('changed') || result.containsKey('updated'))) {
          final ids =
              (result[result.containsKey('changed') ? 'changed' : 'updated']
                      as List)
                  .cast<int>();
          for (final id in ids) _songs.remove(id);
          markCatalogChanged();
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
        _json(response, {'error': 'share.readOnlyPermission'});
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
          final changed = await _refreshSharedEntries([song.id]);
          result.addAll(sharedCatalogChanges(changed));
          onLibraryChanged();
        }
        _json(response, result);
        return;
      }
      if (kind == 'lyrics') {
        final lyrics = await repository.getLocalLyricsForPath(song.path);
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
      response.statusCode =
          error.messageKey == 'share.readOnlyPermission'
              ? HttpStatus.forbidden
              : HttpStatus.badRequest;
      _json(response, {'error': error.messageKey});
    } on TypeError catch (error, stack) {
      SystemLog.error(
        'Shared request failed: ${request.method} ${request.uri.path}',
        error,
        stack,
      );
      response.statusCode = HttpStatus.badRequest;
      _json(response, {'error': error.toString()});
    } on FormatException catch (error) {
      response.statusCode = HttpStatus.badRequest;
      _json(response, {'error': error.message});
    } on FileSystemException catch (error) {
      if (!sendingFile) {
        response.statusCode = HttpStatus.notFound;
        _json(response, {'error': error.message});
      }
    } catch (error, stack) {
      if (!sendingFile) {
        SystemLog.error(
          'Shared request failed: ${request.method} ${request.uri.path}',
          error,
          stack,
        );
        response.statusCode = HttpStatus.internalServerError;
        _json(response, {'error': error.toString()});
      }
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
}
