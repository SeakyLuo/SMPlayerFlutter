import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../library/data/library_repository.dart';
import '../library/data/library_models.dart';
import '../settings/settings_model.dart';

String _typeName(PreferenceEntityType type) => switch (type) {
  PreferenceEntityType.recentAdded => 'recent-added',
  PreferenceEntityType.myFavorites => 'my-favorites',
  PreferenceEntityType.mostPlayed => 'most-played',
  PreferenceEntityType.leastPlayed => 'least-played',
  _ => type.name,
};
String _levelName(PreferenceLevel level) => switch (level) {
  PreferenceLevel.veryHigh => 'very-high',
  PreferenceLevel.doNotAppear => 'do-not-appear',
  _ => level.name,
};

Future<Map<String, dynamic>> handleSharedPreferences(
  HttpRequest request,
  LibraryRepository repository,
  Map<int, LibrarySong> sharedSongs,
  String root,
  bool Function() canWrite,
) async {
  Map<String, dynamic> values;
  if (request.method == 'GET') {
    values = request.uri.queryParameters;
  } else if (request.method == 'POST') {
    final bytes = <int>[];
    await for (final chunk in request.timeout(const Duration(seconds: 15))) {
      bytes.addAll(chunk);
      if (bytes.length > 1024 * 1024) {
        request.response.statusCode = HttpStatus.requestEntityTooLarge;
        return {};
      }
    }
    values = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    if (!canWrite()) {
      request.response.statusCode = HttpStatus.forbidden;
      return {};
    }
  } else {
    request.response.statusCode = HttpStatus.methodNotAllowed;
    return {};
  }
  final operation = values['operation'] as String;
  if (request.method == 'GET' && operation != 'get' && operation != 'level') {
    request.response.statusCode = HttpStatus.methodNotAllowed;
    return {};
  }
  final snapshot = await repository.getLibraryContentData();
  final preferences = await repository.getPreferenceSettings(
    source: 'local',
    initialize: false,
    unknownAlbumName: values['unknownAlbumName'] as String? ?? '',
  );
  final artists = sharedSongs.values.expand((s) => s.artists).toSet();
  final albums = sharedSongs.values.map((s) => s.album).toSet();
  final playlistIds =
      snapshot.playlists
          .where((p) => p.id > 0 && !p.isBuiltIn)
          .map((p) => '${p.id}')
          .toSet();
  final folders =
      snapshot.folders
          .where((f) => f.path == root || p.isWithin(root, f.path))
          .toList();
  bool allowed(String type, String id) => switch (type) {
    'song' => sharedSongs.containsKey(int.parse(id)),
    'artist' => artists.contains(id),
    'album' => albums.contains(id),
    'playlist' => playlistIds.contains(id),
    'folder' => folders.any((f) => '${f.id}' == id || f.path == id),
    'recent-added' ||
    'my-favorites' ||
    'most-played' ||
    'least-played' => preferences.others.any(
      (item) => _typeName(item.type) == type && item.itemId == id,
    ),
    _ => false,
  };
  final items =
      [
        ...preferences.songs,
        ...preferences.artists,
        ...preferences.albums,
        ...preferences.playlists,
        ...preferences.folders,
        ...preferences.others,
      ].where((item) => allowed(_typeName(item.type), item.itemId)).toList();
  if (operation == 'level') {
    final type = values['type'] as String;
    final id = values['itemId'] as String;
    if (!allowed(type, id)) {
      request.response.statusCode = HttpStatus.notFound;
      return {};
    }
    final item =
        items
            .where(
              (item) =>
                  _typeName(item.type) == type &&
                  item.itemId == id &&
                  item.isEnabled,
            )
            .firstOrNull;
    return {'level': item == null ? null : _levelName(item.level)};
  }
  if (operation == 'get') {
    List<Map<String, dynamic>> encode(List<PreferenceItemSnapshot> group) =>
        group
            .where((item) => allowed(_typeName(item.type), item.itemId))
            .map(
              (item) => <String, dynamic>{
                'id': item.id,
                'type': item.type.index,
                'itemId': item.itemId,
                'name': item.name,
                'isEnabled': item.isEnabled,
                'level': item.level.index,
                'isValid': item.isValid,
                'canRemove': item.canRemove,
              },
            )
            .toList();
    return {
      'enabled': {
        for (final e in preferences.enabled.entries) e.key.name: e.value,
      },
      'songs': encode(preferences.songs),
      'artists': encode(preferences.artists),
      'albums': encode(preferences.albums),
      'playlists': encode(preferences.playlists),
      'folders': encode(preferences.folders),
      'others': encode(preferences.others),
    };
  }
  switch (operation) {
    case 'add':
    case 'remove':
      final type = values['type'] as String;
      final id = values['itemId'] as String;
      if (!allowed(type, id)) {
        request.response.statusCode = HttpStatus.notFound;
        return {};
      }
      if (operation == 'add') {
        await repository.addPreferenceItem(
          type,
          id,
          values['name'] as String,
          values['level'] as String,
          source: 'local',
        );
      } else {
        await repository.removePreferenceItem(type, id, source: 'local');
      }
    case 'settings':
      await repository.updatePreferenceSettings({
        for (final e in (values['enabled'] as Map).entries)
          PreferenceSectionKey.values.byName(e.key as String): e.value as bool,
      }, source: 'local');
    case 'update':
    case 'delete':
      final item = items.where((item) => item.id == values['id']).firstOrNull;
      if (item == null || operation == 'delete' && !item.canRemove) {
        request.response.statusCode = HttpStatus.notFound;
        return {};
      }
      if (operation == 'update') {
        await repository.updatePreferenceItem(
          item.id,
          isEnabled: values['isEnabled'] as bool?,
          level:
              values['level'] == null
                  ? null
                  : PreferenceLevel.values[values['level'] as int],
        );
      } else {
        await repository.removePreferenceItemById(item.id);
      }
    case 'clear':
      final type = PreferenceEntityType.values[values['typeIndex'] as int];
      await repository.removeSharedPreferenceItems(
        items
            .where(
              (item) => item.type == type && !item.isValid && item.canRemove,
            )
            .map((item) => item.id)
            .toList(),
      );
    default:
      throw const FormatException('Unknown preference operation');
  }
  return {};
}
