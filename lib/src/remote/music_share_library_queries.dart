import 'dart:io';
import '../library/data/library_models.dart';
import 'dart:convert';
import 'package:path/path.dart' as p;
import '../library/data/library_queries.dart';
import '../library/data/library_repository.dart';
import '../library/data/library_text.dart' show LibraryIndex;
import 'music_share_catalog.dart';
import 'music_share_models.dart';

Future<Map<String, dynamic>> sharedLibraryQuery(
  LibraryRepository repository,
  Map<String, String> parameters, {
  bool idsOnly = false,
}) async {
  final context = await repository.queryLibrary(
    const LibraryDataQuery(LibraryQueryKind.context),
  );
  final root = context.rootPath;
  final kind = LibraryQueryKind.values.byName(parameters['kind']!);
  if ({
    LibraryQueryKind.context,
    LibraryQueryKind.queue,
    LibraryQueryKind.recent,
    LibraryQueryKind.playlistIndex,
  }.contains(kind)) {
    throw const FormatException('This query is not a shared song query');
  }
  final relative = parameters['folder'];
  if (relative != null &&
      (p.posix.isAbsolute(relative) ||
          relative.contains('\\') ||
          relative.split('/').contains('..'))) {
    throw const MusicShareException('share.fileOutsideLibrary');
  }
  final folder =
      relative == null ? root : p.joinAll([root, ...relative.split('/')]);
  final query = LibraryDataQuery(
    kind,
    offset: int.parse(parameters['offset']!),
    anchorSongId:
        parameters.containsKey('anchor')
            ? int.parse(parameters['anchor']!)
            : null,
    limit:
        parameters.containsKey('limit')
            ? int.parse(parameters['limit']!)
            : null,
    text: parameters['text']!,
    order: MusicLibrarySortCriterion.values.byName(parameters['order']!),
    descending: parameters['descending'] == 'true',
    libraryIndex: LibraryIndex.values.byName(
      parameters['libraryIndex'] ?? 'standard',
    ),
    relevance: parameters['relevance'] == 'true',
    substringSearch: parameters['substring'] == 'true',
    unknownArtist: parameters['unknownArtist']!,
    unknownAlbum: parameters['unknownAlbum']!,
    folder: folder,
    recursiveFolders:
        parameters.containsKey('recursiveFolders')
            ? [
              for (final path
                  in (jsonDecode(parameters['recursiveFolders']!) as List)
                      .cast<String>())
                p.joinAll([root, ...path.split('/')]),
            ]
            : const [],
    directWindows:
        parameters.containsKey('directWindows')
            ? {
              for (final entry
                  in (jsonDecode(parameters['directWindows']!) as Map).entries)
                p.joinAll([root, ...(entry.key as String).split('/')]):
                    entry.value as int,
            }
            : const {},
    directFolders:
        parameters.containsKey('directFolders')
            ? [
              for (final path
                  in (jsonDecode(parameters['directFolders']!) as List)
                      .cast<String>())
                p.joinAll([root, ...path.split('/')]),
            ]
            : const [],
    playlistId:
        parameters.containsKey('playlist')
            ? int.parse(parameters['playlist']!)
            : null,
    album: parameters['album'] ?? '',
    albumNames:
        parameters.containsKey('albums')
            ? (jsonDecode(parameters['albums']!) as List).cast<String>()
            : const [],
    artists:
        parameters.containsKey('artists')
            ? (jsonDecode(parameters['artists']!) as List).cast<String>()
            : const [],
    songIds:
        parameters.containsKey('ids')
            ? (jsonDecode(parameters['ids']!) as List).cast<int>()
            : const [],
  );
  if (idsOnly) return {'ids': await repository.resolveLocalSongIds(query)};
  final data = await repository.queryLibrary(query);
  Map<String, dynamic> artwork(int id, String path) => {
    'artworkId': id,
    'artwork': path.isNotEmpty,
    'artworkRevision': shareDigest(path),
  };
  return {
    'total': data.totalSongCount,
    'offset': data.pageOffset,
    'anchor': data.anchorIndex,
    'folderRows': {
      for (final entry in data.folderSongRows.entries)
        p
            .relative(entry.key, from: root)
            .split(p.separator)
            .where((s) => s != '.')
            .join('/'): {
          for (final row in entry.value.entries) '${row.key}': row.value.id,
        },
    },
    'duration': data.totalDuration,
    'folderSummaries': [
      for (final item in data.folderSummaries)
        {
          'path': p
              .relative(item.path, from: root)
              .split(p.separator)
              .where((part) => part != '.')
              .join('/'),
          'direct': item.directCount,
          'songs': item.songCount,
          'duration': item.duration,
          'plays': item.playCount,
          'artworkIds': item.artworkSongIds,
        },
    ],
    'quickJump': data.quickJumpOffsets,
    'artists': [
      for (final item in data.artistSummaries)
        {
          'name': item.name,
          'songs': item.songCount,
          'albums': item.albumCount,
          'duration': item.duration,
          'plays': item.playCount,
          ...artwork(item.artworkSongId, item.artworkPath),
        },
    ],
    'albums': [
      for (final item in data.albumSummaries)
        {
          'name': item.name,
          'songs': item.songCount,
          'duration': item.duration,
          'plays': item.playCount,
          'artists': item.artists,
          ...artwork(item.artworkSongId, item.artworkPath),
        },
    ],
    'songs':
        data.songs
            .where((song) => p.isWithin(root, song.path))
            .map(
              (song) => {
                ...sharedSongJson(song),
                'folder': p
                    .relative(p.dirname(song.path), from: root)
                    .split(p.separator)
                    .where((part) => part != '.')
                    .join('/'),
              },
            )
            .toList(),
  };
}

Future<Map<String, String>> readLibraryQueryParameters(
  HttpRequest request,
) async {
  if (request.method == 'GET') return request.uri.queryParameters;
  final text =
      await utf8.decoder
          .bind(request)
          .timeout(const Duration(seconds: 15))
          .join();
  return (jsonDecode(text) as Map).cast<String, String>();
}
