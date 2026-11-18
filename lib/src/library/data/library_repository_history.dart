part of 'library_repository.dart';

mixin _LibraryRepositoryHistory on _LibraryDataSources {
  Future<File> _resolveDatabaseFile();

  Future<T> _localHistory<T>(Future<T> operation) async {
    final result = await operation;
    activeMusicShareAccess?.localDataChanged('history');
    return result;
  }

  Future<RecentPageData> getRecentPageData(LibraryContentData content) {
    return const LibrarySnapshotService().readRecent(content);
  }

  Future<List<SearchHistoryEntry>> getRecentSearches() async {
    final device = selectedHistorySource();
    if (device != 'local') {
      final data = await remoteHistory(device, 'getSearches');
      return (data['searches'] as List)
          .cast<Map>()
          .map(searchHistoryFromJson)
          .toList();
    }
    final databaseFile = await _resolveDatabaseFile();
    return LibraryRepository._searchHistoryService.getRecentSearches(
      databaseFile,
    );
  }

  Future<RecentBrowseEntry> recordRecentBrowse(
    RecentBrowseType type,
    String itemId,
  ) async {
    final device = selectedHistorySource();
    if (device != 'local') {
      var target = itemId;
      if (type == RecentBrowseType.song) {
        target =
            Uri.parse(
              (await (this as LibraryRepository).songReferences([
                int.parse(itemId),
              ]))[int.parse(itemId)]!,
            ).pathSegments.single;
      }
      if (type == RecentBrowseType.playlist) {
        target = hostPlaylistHistoryId(int.parse(itemId)).toString();
      }
      final entry = browseHistoryFromJson(
        await remoteHistory(device, 'browse', {
          'type': type.index,
          'item': target,
        }),
      );
      return RecentBrowseEntry(
        id: entry.id,
        type: type,
        itemId: itemId,
        browsedAt: entry.browsedAt,
      );
    }
    final databaseFile = await _resolveDatabaseFile();
    return _localHistory(
      LibraryRepository._browseHistoryService.record(
        databaseFile,
        type,
        itemId,
      ),
    );
  }

  Future<void> removeRecentBrowses(List<int> entryIds) async {
    final device = selectedHistorySource();
    if (device != 'local') {
      await remoteHistory(device, 'removeBrowses', {'ids': entryIds});
      return;
    }
    final databaseFile = await _resolveDatabaseFile();
    await _localHistory(
      LibraryRepository._browseHistoryService.remove(databaseFile, entryIds),
    );
  }

  Future<void> restoreRecentBrowses(List<int> entryIds) async {
    final device = selectedHistorySource();
    if (device != 'local') {
      await remoteHistory(device, 'restoreBrowses', {'ids': entryIds});
      return;
    }
    final databaseFile = await _resolveDatabaseFile();
    await _localHistory(
      LibraryRepository._browseHistoryService.restore(databaseFile, entryIds),
    );
  }

  Future<void> clearRecentBrowses() async {
    final device = selectedHistorySource();
    if (device != 'local') {
      await remoteHistory(device, 'clearBrowses', const <String, dynamic>{});
      return;
    }
    final databaseFile = await _resolveDatabaseFile();
    await _localHistory(
      LibraryRepository._browseHistoryService.clear(databaseFile),
    );
  }

  Future<void> removeRecentPlayed(List<int> songIds) async {
    final device = selectedHistorySource();
    if (device != 'local') {
      await remoteHistory(device, 'removePlayed', {
        'ids':
            (await (this as LibraryRepository).songReferences(
                  songIds,
                  includeInactive: true,
                )).values
                .map((path) => int.parse(Uri.parse(path).pathSegments.single))
                .toList(),
      });
      return;
    }
    final databaseFile = await _resolveDatabaseFile();
    await _localHistory(
      LibraryRepository._playbackHistoryService.removeRecentPlayed(
        databaseFile,
        songIds,
      ),
    );
  }

  Future<void> clearRecentPlayed() async {
    final device = selectedHistorySource();
    if (device != 'local') {
      await remoteHistory(device, 'clearPlayed', const <String, dynamic>{});
      return;
    }
    final databaseFile = await _resolveDatabaseFile();
    await _localHistory(
      LibraryRepository._playbackHistoryService.clearRecentPlayed(databaseFile),
    );
  }

  Future<void> removeRecentSearches(List<int> entryIds) async {
    final device = selectedHistorySource();
    if (device != 'local') {
      await remoteHistory(device, 'removeSearches', {'ids': entryIds});
      return;
    }
    final databaseFile = await _resolveDatabaseFile();
    await _localHistory(
      LibraryRepository._searchHistoryService.removeRecentSearches(
        databaseFile,
        entryIds,
      ),
    );
  }

  Future<void> restoreRecentSearches(List<SearchHistoryEntry> entries) async {
    final device = selectedHistorySource();
    if (device != 'local') {
      await remoteHistory(device, 'restoreSearches', {
        'entries': entries.map(searchHistoryJson).toList(),
      });
      return;
    }
    final databaseFile = await _resolveDatabaseFile();
    await _localHistory(
      LibraryRepository._searchHistoryService.restoreRecentSearches(
        databaseFile,
        entries,
      ),
    );
  }

  Future<void> restoreRecentPlayed(List<int> songIds) async {
    final device = selectedHistorySource();
    if (device != 'local') {
      await remoteHistory(device, 'restorePlayed', {
        'ids':
            (await (this as LibraryRepository).songReferences(
                  songIds,
                  includeInactive: true,
                )).values
                .map((path) => int.parse(Uri.parse(path).pathSegments.single))
                .toList(),
      });
      return;
    }
    final databaseFile = await _resolveDatabaseFile();
    await _localHistory(
      LibraryRepository._playbackHistoryService.restoreRecentPlayed(
        databaseFile,
        songIds,
      ),
    );
  }

  Future<void> clearRecentSearches() async {
    final device = selectedHistorySource();
    if (device != 'local') {
      await remoteHistory(device, 'clearSearches', const <String, dynamic>{});
      return;
    }
    final databaseFile = await _resolveDatabaseFile();
    await _localHistory(
      LibraryRepository._searchHistoryService.clearRecentSearches(databaseFile),
    );
  }

  Future<SearchHistoryEntry?> addRecentSearch(
    String query, [
    SearchHistoryType type = SearchHistoryType.sidebar,
  ]) async {
    final device = selectedHistorySource();
    if (device != 'local') {
      final result = await remoteHistory(device, 'search', {
        'query': query,
        'type': type.index,
      });
      return result['entry'] == null
          ? null
          : searchHistoryFromJson(result['entry'] as Map);
    }
    final databaseFile = await _resolveDatabaseFile();
    return _localHistory(
      LibraryRepository._searchHistoryService.addRecentSearch(
        databaseFile,
        query,
        type,
      ),
    );
  }

  Future<void> markSongPlayed(int songId) async {
    final path =
        (await (this as LibraryRepository).songReferences([
          songId,
        ], includeInactive: true))[songId]!;
    if (isRemoteMusicPath(path)) {
      final uri = Uri.parse(path);
      await remoteHistory(uri.host, 'song', {
        'song': int.parse(uri.pathSegments.single),
      });
      return;
    }
    final databaseFile = await _resolveDatabaseFile();
    await _localHistory(
      LibraryRepository._playbackHistoryService.markSongPlayed(
        databaseFile,
        songId,
      ),
    );
  }

  Future<RecentPlaylistPlayback> recordPlaylistPlayed(int playlistId) async {
    if (playlistId < 0) {
      final playlist = activeMusicShareAccess!.remotePlaylists.firstWhere(
        (p) => p.id == playlistId,
      );
      final result = await remoteHistory(playlist.source.deviceId, 'playlist', {
        'item': hostPlaylistHistoryId(playlistId),
      });
      return RecentPlaylistPlayback(
        id: result['id'] as int,
        playlistId: playlistId,
        playedAt: result['time'] as String,
      );
    }
    final databaseFile = await _resolveDatabaseFile();
    return _localHistory(
      LibraryRepository._playbackHistoryService.recordPlaylistPlayed(
        databaseFile,
        playlistId,
      ),
    );
  }

  Future<RecentAlbumPlayback> recordAlbumPlayed(String album) async {
    final device = selectedHistorySource();
    if (device != 'local') {
      final result = await remoteHistory(device, 'album', {'item': album});
      return RecentAlbumPlayback(
        id: result['id'] as int,
        album: album,
        playedAt: result['time'] as String,
      );
    }
    final databaseFile = await _resolveDatabaseFile();
    return _localHistory(
      LibraryRepository._playbackHistoryService.recordAlbumPlayed(
        databaseFile,
        album,
      ),
    );
  }

  Future<RecentArtistPlayback> recordArtistPlayed(String artist) async {
    final device = selectedHistorySource();
    if (device != 'local') {
      final result = await remoteHistory(device, 'artist', {'item': artist});
      return RecentArtistPlayback(
        id: result['id'] as int,
        artist: artist,
        playedAt: result['time'] as String,
      );
    }
    final databaseFile = await _resolveDatabaseFile();
    return _localHistory(
      LibraryRepository._playbackHistoryService.recordArtistPlayed(
        databaseFile,
        artist,
      ),
    );
  }
}
