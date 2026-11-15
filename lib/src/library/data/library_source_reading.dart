part of 'library_repository.dart';

mixin _LocalLibraryReading {
  LibraryRepository get repository;
  Future<List<int>> resolveSongIds(LibraryDataQuery query) =>
      repository.resolveLocalSongIds(query);
  Future<ArtistSplitAnalysisResult> analyzeArtists({
    void Function(double)? onProgress,
  }) => repository.analyzeLocalArtistBatches(onProgress: onProgress);
  Future<LibraryLyricsSearchPage> searchLyrics(
    String query, {
    required String folderPath,
    int offset = 0,
    MusicLibrarySortCriterion? order,
  }) => repository.queryLocalLyrics(
    query,
    folderPath: folderPath,
    offset: offset,
    order: order,
  );

  Future<LibraryContentData> query(LibraryDataQuery query) async {
    final page = await repository._readDatabaseQuery(query);
    if (!page.songs.any((song) => !song.detailsLoaded)) return page;
    final songs = await repository.getLibrarySongs(
      songIds: page.songs.map((song) => song.id).toList(),
    );
    final byId = {for (final song in songs) song.id: song};
    return page.withPage(
      songs: songs,
      songRows: {
        for (final entry in page.songRows.entries)
          entry.key: byId[entry.value.id]!,
      },
    );
  }

  Future<List<LibrarySelectionKind>> selectionModes(int limit) =>
      repository.readSelectionModes(limit);

  Future<List<int>> selectSongIds(LibrarySelectionRequest request) =>
      repository.selectLocalSongIds(request);
}

mixin _RemoteLibraryReading {
  LibraryRepository get repository;
  Future<List<int>> resolveSongIds(LibraryDataQuery query) =>
      access.resolveSongIds(source.deviceId, query);
  Future<ArtistSplitAnalysisResult> analyzeArtists({
    void Function(double)? onProgress,
  }) => access.analyzeArtists(source.deviceId, onProgress: onProgress);
  MusicShareAccess get access;
  RemoteLibrarySource get source;

  Future<LibraryLyricsSearchPage> searchLyrics(
    String query, {
    required String folderPath,
    int offset = 0,
    MusicLibrarySortCriterion? order,
  }) => access.searchLyrics(
    source.deviceId,
    query,
    folderPath,
    offset: offset,
    order: order,
  );

  Future<LibraryContentData> query(LibraryDataQuery request) async {
    final query = request.withPage(source: source.deviceId);
    if (query.kind == LibraryQueryKind.playlistIndex) {
      await access.readPlaylists(source.deviceId);
      return repository._readDatabaseQuery(query);
    }
    if (query.kind == LibraryQueryKind.playlists)
      await access.readPlaylists(source.deviceId);
    return access.queryLibraryData(source.deviceId, query);
  }

  Future<List<LibrarySelectionKind>> selectionModes(int limit) async {
    final result = await access.randomPlayRequest(source.deviceId, {
      'kind': 'options',
      'limit': '$limit',
    });
    return (result['modes'] as List)
        .cast<String>()
        .map(LibrarySelectionKind.fromWire)
        .toList();
  }

  Future<List<int>> selectSongIds(LibrarySelectionRequest request) async {
    final List<int> hostIds;
    if (request.kind == LibrarySelectionKind.selection) {
      final paths = await repository.songReferences(request.songIds);
      final byId = {
        for (final entry in paths.entries)
          entry.key: int.parse(Uri.parse(entry.value).pathSegments.single),
      };
      hostIds = request.songIds.map((id) => byId[id]!).toList();
    } else {
      hostIds = const [];
    }
    final hostPlaylist =
        request.kind == LibrarySelectionKind.savedPlaylist
            ? int.parse(
              Uri.parse(
                access.remotePlaylists
                    .firstWhere((list) => list.id == request.playlistId)
                    .remotePath,
              ).pathSegments.last,
            )
            : null;
    return access.readRandomSelectionIds(source.deviceId, {
      'kind': request.kind.wireName,
      'limit': '${request.limit}',
      if (request.kind == LibrarySelectionKind.quick)
        'unknownAlbumName': request.unknownAlbumName,
      if (request.kind == LibrarySelectionKind.currentArtist)
        'artists': jsonEncode(request.artists),
      if (request.kind == LibrarySelectionKind.currentAlbum)
        'album': request.album,
      if (hostPlaylist != null) 'playlist': '$hostPlaylist',
      if (request.kind == LibrarySelectionKind.selection)
        'ids': jsonEncode(hostIds),
    });
  }
}
