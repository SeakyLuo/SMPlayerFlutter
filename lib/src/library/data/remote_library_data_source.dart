part of 'library_repository.dart';

final class RemoteLibraryDataSource
    with _RemoteLibraryStorage, _RemoteLibraryReading
    implements LibraryDataSource {
  const RemoteLibraryDataSource(this.source, this.access, this.repository);
  @override
  Future<RecentPageData> readRecentData() =>
      readRemoteRecentData(repository, source.deviceId);
  @override
  final RemoteLibrarySource source;
  @override
  final MusicShareAccess access;
  @override
  final LibraryRepository repository;
  @override
  bool get canWrite => access.canWrite(source.rootPath);

  void _checkWrite() {
    if (!canWrite) throw const MusicShareException('share.readOnlyPermission');
  }

  @override
  Future<void> applyArtistSplits(
    Map<int, String> songs,
    List<ArtistSplitResultItem> splits,
  ) async {
    _checkWrite();
    final byId = {for (final split in splits) split.songId: split};
    await access.songsRequest(
      songs.values.toList(),
      'artist-splits',
      method: 'POST',
      body: {
        'artists': {
          for (final song in songs.entries)
            Uri.parse(song.value).pathSegments.single: byId[song.key]!.artists,
        },
      },
    );
  }

  Future<LibraryPlaylist?> _playlist(
    String operation, {
    int? id,
    String? name,
    List<int> songIds = const [],
    List<int> ids = const [],
    LibraryPlaylist? restore,
    PlaylistSortCriterion? criterion,
  }) {
    _checkWrite();
    return access.playlistOperation(
      source.deviceId,
      operation,
      playlistId: id,
      name: name,
      songIds: songIds,
      playlistIds: ids,
      restore: restore,
      criterion: criterion,
    );
  }

  @override
  Future<LibraryPlaylist> createPlaylist(
    String name,
    List<int> songIds,
  ) async => (await _playlist('create', name: name, songIds: songIds))!;
  @override
  Future<void> deletePlaylist(int id) async {
    await _playlist('delete', id: id);
  }

  @override
  Future<void> restorePlaylist(LibraryPlaylist playlist) async {
    await _playlist(
      'restore',
      id: playlist.id,
      restore: playlist,
      songIds: playlist.songIds,
    );
  }

  @override
  Future<void> renamePlaylist(int id, String name) async {
    await _playlist('rename', id: id, name: name);
  }

  @override
  Future<void> reorderPlaylists(List<int> ids) async {
    await _playlist('order', ids: ids);
  }

  @override
  Future<void> addSongsToPlaylist(int id, List<int> songIds) async {
    await _playlist('add', id: id, songIds: songIds);
  }

  @override
  Future<void> removeSongsFromPlaylist(int id, List<int> songIds) async {
    await _playlist('remove', id: id, songIds: songIds);
  }

  @override
  Future<void> reorderPlaylistSongs(
    int id,
    List<int> songIds,
    PlaylistSortCriterion? criterion,
  ) async {
    await _playlist('reorder', id: id, songIds: songIds, criterion: criterion);
  }

  @override
  Future<SongPropertiesSnapshot> getProperty(LibrarySong song) async {
    final json = await access.songRequest(song.path, 'properties');
    return sharedPropertiesFromJson(json, song.id, song.path);
  }

  @override
  Future<void> updateProperty(
    LibrarySong song,
    SongPropertiesUpdate update,
  ) async {
    _checkWrite();
    await access.songRequest(
      song.path,
      'properties',
      method: 'POST',
      body: sharedUpdateJson(update),
    );
  }

  @override
  Future<List<SongPropertiesSnapshot>> getProperties(
    Map<int, String> songs,
  ) async {
    final result = await access.songsRequest(
      songs.values.toList(),
      'properties',
    );
    final byHost = {
      for (final song in songs.entries)
        int.parse(Uri.parse(song.value).pathSegments.single): song,
    };
    return (result['properties'] as List).map((raw) {
      final json = (raw as Map).cast<String, dynamic>();
      final song = byHost[json['id']]!;
      return sharedPropertiesFromJson(json, song.key, song.value);
    }).toList();
  }

  @override
  Future<BatchSongPropertiesUpdateResult> updateProperties(
    Map<int, String> songs,
    Map<int, SongPropertiesUpdate> updates,
  ) async {
    _checkWrite();
    final byHost = {
      for (final song in songs.entries)
        int.parse(Uri.parse(song.value).pathSegments.single): song.key,
    };
    final result = await access.songsRequest(
      songs.values.toList(),
      'properties',
      method: 'POST',
      body: {
        'updates': {
          for (final song in songs.entries)
            Uri.parse(song.value).pathSegments.single: sharedUpdateJson(
              updates[song.key]!,
            ),
        },
      },
    );
    return BatchSongPropertiesUpdateResult(
      updatedSongIds:
          (result['updated'] as List).map((id) => byHost[id]!).toList(),
      failedSongIds:
          (result['failed'] as List).map((id) => byHost[id]!).toList(),
    );
  }

  @override
  Future<List<int>> setFavorites(Map<int, String> songs, bool favorite) async {
    _checkWrite();
    final result = await access.songsRequest(
      songs.values.toList(),
      'favorites',
      method: 'POST',
      body: {'favorite': favorite},
    );
    final byHost = {
      for (final entry in songs.entries)
        int.parse(Uri.parse(entry.value).pathSegments.single): entry.key,
    };
    return (result['changed'] as List)
        .cast<int>()
        .map((id) => byHost[id]!)
        .toList();
  }

  @override
  Future<void> updatePlayCount(LibrarySong song, int count) async {
    _checkWrite();
    await access.songRequest(
      song.path,
      'play-count',
      method: 'POST',
      body: {'playCount': count},
    );
  }

  @override
  Future<void> saveLyrics(LibrarySong song, String text) async {
    _checkWrite();
    await access.songRequest(
      song.path,
      'lyrics',
      method: 'POST',
      body: {'rawText': text},
    );
  }

  @override
  Future<void> updateLyricsOffset(LibrarySong song, int offsetMs) async {
    _checkWrite();
    await access.songRequest(
      song.path,
      'lyrics-offset',
      method: 'POST',
      body: {'offsetMs': offsetMs},
    );
  }

  @override
  Future<void> writeArtwork(Map<int, String> songs, String? sourcePath) async {
    _checkWrite();
    final body =
        sourcePath == null
            ? null
            : {'image': base64Encode(await File(sourcePath).readAsBytes())};
    if (songs.length == 1) {
      final song = songs.values.single;
      await access.songRequest(
        song,
        'artwork',
        method: sourcePath == null ? 'DELETE' : 'POST',
        body: body,
      );
    } else {
      await access.songsRequest(
        songs.values.toList(),
        'artwork',
        method: sourcePath == null ? 'DELETE' : 'POST',
        body: body,
      );
    }
  }

  @override
  Future<void> writeAlbumArtwork(String album, String? sourcePath) async {
    _checkWrite();
    final ids = await resolveSongIds(
      LibraryDataQuery(LibraryQueryKind.album, album: album),
    );
    final songs = await repository.songReferences(ids);
    await access.songsRequest(
      songs.values.toList(),
      'artwork',
      method: sourcePath == null ? 'DELETE' : 'POST',
      body:
          sourcePath == null
              ? null
              : {'image': base64Encode(await File(sourcePath).readAsBytes())},
    );
  }

  @override
  Future<void> addPreferenceItem(
    String type,
    String itemId,
    String name,
    String level,
  ) async {
    await _preference('add', {
      'type': type,
      'itemId': itemId,
      'name': name,
      'level': level,
    });
  }

  @override
  Future<String?> getPreferenceLevel(String type, String itemId) async {
    final result = await _preference('level', {'type': type, 'itemId': itemId});
    return result['level'] as String?;
  }

  @override
  Future<void> removePreferenceItem(String type, String itemId) async {
    await _preference('remove', {'type': type, 'itemId': itemId});
  }

  @override
  Future<void> updatePreferenceSettings(
    Map<PreferenceSectionKey, bool> enabled,
  ) async {
    await _preference('settings', {
      'enabled': {for (final e in enabled.entries) e.key.name: e.value},
    });
  }

  @override
  Future<void> updatePreferenceItem(
    int itemId, {
    bool? isEnabled,
    PreferenceLevel? level,
  }) async {
    await _preference('update', {
      'id': itemId,
      'isEnabled': isEnabled,
      'level': level?.index,
    });
  }

  @override
  Future<void> removePreferenceItemById(int itemId) async {
    await _preference('delete', {'id': itemId});
  }

  @override
  Future<void> clearInvalidPreferenceItems(PreferenceEntityType type) async {
    await _preference('clear', {'typeIndex': type.index});
  }

  @override
  Future<PreferenceSettingsSnapshot> getPreferenceSettings({
    required String unknownAlbumName,
    bool initialize = true,
  }) async {
    final device = source.deviceId;
    final json = await access.preferenceRequest(device, 'get', {
      'unknownAlbumName': unknownAlbumName,
    });
    final hostIds = (json['songIds'] as List).cast<int>();
    final localIds = await repository.cacheRemoteSongReferences(
      device,
      hostIds,
    );
    final songIds = {
      for (var index = 0; index < hostIds.length; index++)
        '${hostIds[index]}': '${localIds[index]}',
    };
    final playlists = {
      for (final raw in json['playlists'] as List)
        (raw as Map)['itemId'] as String:
            (-int.parse(
                      shareDigest(
                        '$remoteMusicScheme://$device/playlists/${raw['itemId']}',
                      ).substring(0, 15),
                      radix: 16,
                    ) -
                    1)
                .toString(),
    };
    repository.forgetRemotePreferences(device);
    List<PreferenceItemSnapshot> decode(String key) =>
        (json[key] as List).map((raw) {
          final value = raw as Map;
          final hostId = value['id'] as int;
          final id =
              -int.parse(
                shareDigest('$device/preferences/$hostId').substring(0, 15),
                radix: 16,
              ) -
              1;
          _LibraryRepositoryPreferences._locations[id] = (source, hostId);
          final type = PreferenceEntityType.values[value['type'] as int];
          final hostItemId = value['itemId'] as String;
          final mapped =
              type == PreferenceEntityType.song
                  ? songIds[hostItemId]
                  : type == PreferenceEntityType.playlist
                  ? playlists[hostItemId]
                  : hostItemId;
          return PreferenceItemSnapshot(
            id: id,
            type: type,
            itemId: mapped ?? '',
            name: value['name'] as String,
            tooltip: value['name'] as String,
            isEnabled: value['isEnabled'] as bool,
            level: PreferenceLevel.values[value['level'] as int],
            isValid: value['isValid'] as bool && mapped != null,
            canRemove: value['canRemove'] as bool,
          );
        }).toList();
    return PreferenceSettingsSnapshot(
      source: device,
      enabled: {
        for (final e in (json['enabled'] as Map).entries)
          PreferenceSectionKey.values.byName(e.key as String): e.value as bool,
      },
      songs: decode('songs'),
      artists: decode('artists'),
      albums: decode('albums'),
      playlists: decode('playlists'),
      folders: decode('folders'),
      others: decode('others'),
    );
  }

  Future<Map<String, dynamic>> _preference(
    String operation,
    Map<String, dynamic> values,
  ) {
    if (operation != 'get' && operation != 'level') _checkWrite();
    return access.preferenceRequest(source.deviceId, operation, values);
  }
}
