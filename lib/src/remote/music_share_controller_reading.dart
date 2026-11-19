part of 'music_share_controller.dart';

extension _MusicShareReading on MusicShareController {
  Future<Map<String, dynamic>> _libraryReadRequest(
    String device,
    String endpoint, {
    Object? body,
  }) async {
    final peer = peerFor(remoteMusicPath(device, 0));
    final transport = MusicShareTransport(
      peer.address,
      fingerprint: peer.fingerprint,
      token: peer.token,
      onNetworkError:
          (error, stack) => _requestConnectionRecovery(peer, error, stack),
    );
    try {
      final uri = Uri.parse(endpoint);
      return await transport.json(
        uri.path,
        method: 'POST',
        body: body ?? uri.queryParameters,
      );
    } finally {
      transport.close();
    }
  }

  Future<List<int>> _resolveSongIds(
    String device,
    LibraryDataQuery query,
  ) async {
    await ready;
    final hostIds =
        query.songIds.isEmpty
            ? const <int>[]
            : (await repository.songReferences(query.songIds)).values
                .map((path) => int.parse(Uri.parse(path).pathSegments.single))
                .toList();
    final result = await _libraryReadRequest(
      device,
      Uri(
        path: '/library/ids',
        queryParameters: {
          'kind': query.kind.name,
          'offset': '0',
          'text': query.text,
          'order': query.order.name,
          'descending': '${query.descending}',
          'relevance': '${query.relevance}',
          'substring': '${query.substringSearch}',
          'unknownArtist': query.unknownArtist,
          'unknownAlbum': query.unknownAlbum,
          'album': query.album,
          if (query.recursiveFolders.isNotEmpty)
            'recursiveFolders': jsonEncode([
              for (final path in query.recursiveFolders)
                Uri.parse(path).pathSegments.join('/'),
            ]),
          if (query.directWindows.isNotEmpty)
            'directWindows': jsonEncode({
              for (final entry in query.directWindows.entries)
                Uri.parse(entry.key).pathSegments.join('/'): entry.value,
            }),
          if (query.directFolders.isNotEmpty)
            'directFolders': jsonEncode([
              for (final path in query.directFolders)
                Uri.parse(path).pathSegments.join('/'),
            ]),
          if (query.albumNames.isNotEmpty)
            'albums': jsonEncode(query.albumNames),
          if (query.artists.isNotEmpty) 'artists': jsonEncode(query.artists),
          if (query.folder != null)
            'folder': Uri.parse(query.folder!).pathSegments.join('/'),
          if (hostIds.isNotEmpty) 'ids': jsonEncode(hostIds),
          if (query.playlistId != null)
            'playlist':
                Uri.parse(
                  remotePlaylists
                      .firstWhere((list) => list.id == query.playlistId)
                      .remotePath,
                ).pathSegments.last,
        },
      ).toString(),
    );
    return repository.cacheRemoteSongReferences(
      device,
      (result['ids'] as List).cast<int>(),
    );
  }

  Future<ArtistSplitAnalysisResult> _analyzeArtists(
    String device, {
    void Function(double)? onProgress,
  }) async {
    await ready;
    onProgress?.call(0);
    final result = await _editRequest(
      remoteMusicPath(device, 0),
      '/artist-analysis',
    );
    final hostIds =
        {
          for (final key in ['direct', 'possible', 'merges'])
            for (final row in (result[key] as List).cast<Map>())
              row['song'] as int,
        }.toList();
    final localIds = await repository.cacheRemoteSongReferences(
      device,
      hostIds,
    );
    final ids = {
      for (var index = 0; index < hostIds.length; index++)
        hostIds[index]: localIds[index],
    };
    List<ArtistSplitResultItem> read(String key) => [
      for (final row in (result[key] as List).cast<Map>())
        ArtistSplitResultItem(
          songId: ids[row['song']]!,
          title: row['title'] as String,
          artist: row['artist'] as String,
          artists: (row['artists'] as List).cast<String>(),
        ),
    ];
    onProgress?.call(1);
    return ArtistSplitAnalysisResult(
      directSplits: read('direct'),
      possibleSplits: read('possible'),
      mergeSuggestions: read('merges'),
    );
  }

  Future<LibraryLyricsSearchPage> _searchLyrics(
    String device,
    String query,
    String folderPath, {
    int offset = 0,
    MusicLibrarySortCriterion? order,
  }) async {
    if (query.trim().runes.length < 2)
      return const LibraryLyricsSearchPage(matches: [], totalCount: 0);
    await ready;
    final peer = peerFor(remoteMusicPath(device, 0));
    final response = await _editRequest(
      remoteMusicPath(device, 0),
      Uri(
        path: '/lyrics-search',
        queryParameters: {
          'query': query,
          'offset': '$offset',
          if (order != null) 'order': order.name,
          'folder':
              folderPath.isEmpty
                  ? ''
                  : Uri.parse(folderPath).pathSegments.join('/'),
        },
      ).toString(),
    );
    final songData =
        (response['songData'] as List)
            .map((raw) => (raw as Map).cast<String, dynamic>())
            .toList();
    await importMusicShareCatalog(
      databasePath,
      device,
      songData,
      replace: false,
      isCurrent: () => !_disposed && peers.contains(peer),
    );
    if (_disposed || !peers.contains(peer)) {
      throw const MusicShareException('share.deviceForgotten');
    }
    final songs = await repository.readRemoteSelection(
      device,
      songData.map((song) => song['id'] as int).toList(),
    );
    final ids = {
      for (final song in songs)
        int.parse(Uri.parse(song.path).pathSegments.single): song.id,
    };
    return LibraryLyricsSearchPage(
      totalCount: response['total'] as int,
      songs: songs,
      matches: [
        for (final match in (response['matches'] as List).cast<Map>())
          LocalLyricsSearchMatch(
            songId: ids[match['song']]!,
            snippet: match['snippet'] as String,
            contextLines: (match['contextLines'] as List).cast<String>(),
            matchContexts:
                (match['matchContexts'] as List)
                    .map((lines) => (lines as List).cast<String>())
                    .toList(),
            timestampMs: match['timestampMs'] as int?,
            additionalMatchCount: match['additionalMatchCount'] as int,
            relevance: match['relevance'] as int,
          ),
      ],
    );
  }

  Future<LibraryContentData> _queryLibraryData(
    String device,
    LibraryDataQuery query,
  ) async {
    await ready;
    final peer = peerFor(remoteMusicPath(device, 0));
    final ids =
        query.songIds.isEmpty
            ? const <int>[]
            : (await repository.songReferences(query.songIds)).values
                .map((path) => int.parse(Uri.parse(path).pathSegments.single))
                .toList();
    final result = await _libraryReadRequest(
      device,
      Uri(
        path: '/library/query',
        queryParameters: {
          'kind': query.kind.name,
          if (query.playlistId != null)
            'playlist':
                Uri.parse(
                  remotePlaylists
                      .firstWhere((list) => list.id == query.playlistId)
                      .remotePath,
                ).pathSegments.last,
          'offset': '${query.offset}',
          if (query.anchorSongId != null)
            'anchor':
                Uri.parse(
                  (await repository.songReferences([
                    query.anchorSongId!,
                  ], includeInactive: true))[query.anchorSongId]!,
                ).pathSegments.single,
          if (query.limit != null) 'limit': '${query.limit}',
          if (query.albumNames.isNotEmpty)
            'albums': jsonEncode(query.albumNames),
          'text': query.text,
          'order': query.order.name,
          'descending': '${query.descending}',
          'relevance': '${query.relevance}',
          'substring': '${query.substringSearch}',
          'unknownArtist': query.unknownArtist,
          'unknownAlbum': query.unknownAlbum,
          if (query.kind == LibraryQueryKind.album) 'album': query.album,
          if (query.recursiveFolders.isNotEmpty)
            'recursiveFolders': jsonEncode([
              for (final path in query.recursiveFolders)
                Uri.parse(path).pathSegments.join('/'),
            ]),
          if (query.directWindows.isNotEmpty)
            'directWindows': jsonEncode({
              for (final entry in query.directWindows.entries)
                Uri.parse(entry.key).pathSegments.join('/'): entry.value,
            }),
          if (query.directFolders.isNotEmpty)
            'directFolders': jsonEncode([
              for (final path in query.directFolders)
                Uri.parse(path).pathSegments.join('/'),
            ]),
          if (query.artists.isNotEmpty) 'artists': jsonEncode(query.artists),
          if (query.folder != null)
            'folder': Uri.parse(query.folder!).pathSegments.join('/'),
          if (ids.isNotEmpty) 'ids': jsonEncode(ids),
        },
      ).toString(),
    );
    final songs =
        (result['songs'] as List)
            .map((song) => (song as Map).cast<String, dynamic>())
            .toList();
    await importMusicShareCatalog(
      databasePath,
      device,
      songs,
      replace: false,
      removedSongIds:
          ids.where((id) => !songs.any((song) => song['id'] == id)).toList(),
      isCurrent: () => !_disposed && peers.contains(peer),
    );
    if (_disposed || !peers.contains(peer))
      throw const MusicShareException('share.deviceForgotten');
    peer.catalogLoaded = true;
    if (query.kind == LibraryQueryKind.songs ||
        query.kind == LibraryQueryKind.folders) {
      _pendingCatalogPeers.remove(device);
    }
    final localSongs =
        songs.isEmpty
            ? const <LibrarySong>[]
            : await repository.readRemoteSelection(
              device,
              songs.map((song) => song['id'] as int).toList(),
            );
    final context = await repository.queryLibrary(
      const LibraryDataQuery(LibraryQueryKind.context),
    );
    String artwork(Map row) =>
        row['artwork'] == true
            ? '${remoteMusicPath(device, row['artworkId'] as int)}?art=${row['artworkRevision']}'
            : '';
    return context.withPage(
      songs: localSongs,
      totalSongCount: result['total'] as int,
      totalDuration: result['duration'] as int,
      pageOffset: result['offset'] as int,
      anchorIndex: result['anchor'] as int?,
      songRows: {
        for (var index = 0; index < localSongs.length; index++)
          (result['offset'] as int) + index: localSongs[index],
      },
      quickJumpOffsets: (result['quickJump'] as Map).cast<String, int>(),
      folderSongRows: {
        for (final entry in (result['folderRows'] as Map).entries)
          '$remoteMusicScheme://$device${(entry.key as String).isEmpty ? '' : '/${entry.key}'}':
              {
                for (final row in (entry.value as Map).entries)
                  int.parse(row.key as String): localSongs.firstWhere(
                    (song) =>
                        Uri.parse(song.path).pathSegments.single ==
                        '${row.value}',
                  ),
              },
      },
      songFolderPaths: {
        for (var index = 0; index < localSongs.length; index++)
          localSongs[index].id:
              '$remoteMusicScheme://$device${(songs[index]['folder'] as String).isEmpty ? '' : '/${songs[index]['folder']}'}',
      },
      folderSummaries: [
        for (final row in (result['folderSummaries'] as List).cast<Map>())
          LibraryFolderSummary(
            path:
                '$remoteMusicScheme://$device${(row['path'] as String).isEmpty ? '' : '/${row['path']}'}',
            directCount: row['direct'] as int,
            songCount: row['songs'] as int,
            duration: row['duration'] as int,
            playCount: row['plays'] as int,
            artworkPaths: [
              for (final id in (row['artworkIds'] as List).cast<int>())
                remoteMusicPath(device, id),
            ],
          ),
      ],
      artistSummaries: [
        for (final row in (result['artists'] as List).cast<Map>())
          LibraryArtistSummary(
            name: row['name'] as String,
            songCount: row['songs'] as int,
            albumCount: row['albums'] as int,
            duration: row['duration'] as int,
            playCount: row['plays'] as int,
            artworkSongId: row['artworkId'] as int,
            artworkPath: artwork(row),
          ),
      ],
      albumSummaries: [
        for (final row in (result['albums'] as List).cast<Map>())
          LibraryAlbumSummary(
            name: row['name'] as String,
            songCount: row['songs'] as int,
            duration: row['duration'] as int,
            playCount: row['plays'] as int,
            artists: (row['artists'] as List).cast<String>(),
            artworkSongId: row['artworkId'] as int,
            artworkPath: artwork(row),
          ),
      ],
    );
  }
}
