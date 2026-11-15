import 'dart:convert';
import 'dart:io';
import '../library/data/library_queries.dart';
import '../library/data/library_selection.dart';
import '../library/data/library_repository.dart';

Future<Map<String, dynamic>> sharedRandomPlay(
  LibraryRepository repository,
  Map<String, String> parameters,
) async {
  final mode = parameters['kind']!;
  final context = await repository.queryLibrary(
    const LibraryDataQuery(LibraryQueryKind.context),
  );
  final root = context.rootPath;
  final limit = int.parse(parameters['limit']!);
  if (mode == 'options') {
    final modes = await repository.readSelectionModes(limit, folder: root);
    return {'modes': modes.map((mode) => mode.wireName).toList()};
  }
  final request = LibrarySelectionRequest(
    LibrarySelectionKind.fromWire(mode),
    limit: limit,
    album: parameters['album'] ?? '',
    artists:
        parameters.containsKey('artists')
            ? (jsonDecode(parameters['artists']!) as List).cast<String>()
            : const [],
    songIds:
        parameters.containsKey('ids')
            ? (jsonDecode(parameters['ids']!) as List).cast<int>()
            : const [],
    playlistId:
        parameters.containsKey('playlist')
            ? int.parse(parameters['playlist']!)
            : null,
    unknownAlbumName: parameters['unknownAlbumName'] ?? '',
  );
  final songs = await repository.selectLocalSongIds(
    request,
    folder: root,
    initializePreferences: false,
  );
  return {'ids': songs};
}

Future<Map<String, String>> readRandomPlayParameters(
  HttpRequest request,
) async {
  if (request.method == 'GET') return request.uri.queryParameters;
  final bytes = <int>[];
  await for (final chunk in request.timeout(const Duration(seconds: 15))) {
    bytes.addAll(chunk);
    if (bytes.length > 1024 * 1024)
      throw const FormatException('Random selection is too large');
  }
  return (jsonDecode(utf8.decode(bytes)) as Map).cast<String, String>();
}
