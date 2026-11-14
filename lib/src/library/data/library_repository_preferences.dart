part of 'library_repository.dart';

mixin _LibraryRepositoryPreferences on _LibraryDataSources {
  Future<File> _resolveDatabaseFile();
  Future<List<LibrarySong>> getLibrarySongs({List<int>? songIds});
  static final _locations = <int, (RemoteLibrarySource, int)>{};

  void forgetRemotePreferences(String device) {
    _locations.removeWhere((_, value) => value.$1.deviceId == device);
  }

  LibrarySource _preferenceSource(String? source) => LibrarySource.fromDevice(
    source ?? activeMusicShareAccess?.selectedSource ?? 'local',
  );

  Future<(LibrarySource, String)> _preferenceTarget(
    String type,
    String itemId,
    String? selection,
  ) async {
    if (type == 'song') {
      final song = (await getLibrarySongs(songIds: [int.parse(itemId)])).single;
      return (
        song.source,
        song.source is RemoteLibrarySource
            ? Uri.parse(song.path).pathSegments.single
            : itemId,
      );
    }
    if (type == 'playlist') {
      final id = int.parse(itemId);
      final source = _playlistSource(id);
      if (source is RemoteLibrarySource) {
        final playlist = activeMusicShareAccess!.remotePlaylists.firstWhere(
          (p) => p.id == id,
        );
        return (source, Uri.parse(playlist.remotePath).pathSegments.last);
      }
      return (source, itemId);
    }
    if (type == 'folder' && selection == null) {
      return (const LocalLibrarySource(), itemId);
    }
    return (_preferenceSource(selection), itemId);
  }

  Future<void> addPreferenceItem(
    String type,
    String itemId,
    String name,
    String level, {
    String? source,
  }) async {
    final target = await _preferenceTarget(type, itemId, source);
    await dataSource(target.$1).addPreferenceItem(type, target.$2, name, level);
  }

  Future<String?> getPreferenceLevel(
    String type,
    String itemId, {
    String? source,
  }) async {
    final target = await _preferenceTarget(type, itemId, source);
    return dataSource(target.$1).getPreferenceLevel(type, target.$2);
  }

  Future<void> removePreferenceItem(
    String type,
    String itemId, {
    String? source,
  }) async {
    final target = await _preferenceTarget(type, itemId, source);
    await dataSource(target.$1).removePreferenceItem(type, target.$2);
  }

  Future<PreferenceSettingsSnapshot> getPreferenceSettings({
    required String unknownAlbumName,
    String? source,
    bool initialize = true,
  }) => dataSource(_preferenceSource(source)).getPreferenceSettings(
    unknownAlbumName: unknownAlbumName,
    initialize: initialize,
  );
  Future<void> updatePreferenceSettings(
    Map<PreferenceSectionKey, bool> enabled, {
    String? source,
  }) => dataSource(_preferenceSource(source)).updatePreferenceSettings(enabled);
  (LibrarySource, int) _preferenceItemLocation(int id) =>
      id >= 0 ? (const LocalLibrarySource(), id) : _locations[id]!;
  Future<void> updatePreferenceItem(
    int itemId, {
    bool? isEnabled,
    PreferenceLevel? level,
  }) {
    final target = _preferenceItemLocation(itemId);
    return dataSource(
      target.$1,
    ).updatePreferenceItem(target.$2, isEnabled: isEnabled, level: level);
  }

  Future<void> removePreferenceItemById(int itemId) {
    final target = _preferenceItemLocation(itemId);
    return dataSource(target.$1).removePreferenceItemById(target.$2);
  }

  Future<void> clearInvalidPreferenceItems(
    PreferenceEntityType type, {
    String? source,
  }) => dataSource(_preferenceSource(source)).clearInvalidPreferenceItems(type);

  Future<void> removeSharedPreferenceItems(List<int> ids) async {
    if (ids.isEmpty) return;
    final db = sqlite3.open((await _resolveDatabaseFile()).path);
    try {
      db.execute(
        'UPDATE PreferenceItem SET State = 0 WHERE Id IN (${List.filled(ids.length, '?').join(',')})',
        ids,
      );
    } finally {
      db.dispose();
    }
  }
}
