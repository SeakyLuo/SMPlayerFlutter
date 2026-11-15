import 'music_share_catalog.dart';
import 'dart:async';
import 'package:path/path.dart' as p;
import '../library/data/library_models.dart';
import '../library/data/library_repository.dart';
import '../library/data/library_queries.dart';
import 'music_share_models.dart';
import '../platform/system_log.dart';

Future<Map<String, dynamic>> sharedLyricsSearch(
  LibraryRepository repository,
  String query,
  String relative, {
  required int offset,
  MusicLibrarySortCriterion? order,
}) async {
  if (p.posix.isAbsolute(relative) ||
      relative.contains('\\') ||
      relative.split('/').contains('..')) {
    throw const MusicShareException('share.fileOutsideLibrary');
  }
  final metadata = await repository.queryLibrary(
    const LibraryDataQuery(LibraryQueryKind.context),
  );
  final root = metadata.rootPath;
  final page = await repository.queryLocalLyrics(
    query,
    folderPath: p.joinAll([root, ...relative.split('/')]),
    offset: offset,
    order: order,
  );
  unawaited(
    repository
        .indexMissingLocalLyrics(
          folderPath: p.joinAll([root, ...relative.split('/')]),
        )
        .catchError((Object error, StackTrace stack) {
          SystemLog.error('Shared lyrics indexing failed', error, stack);
        }),
  );
  return {
    'total': page.totalCount,
    'songData': page.songs.map(sharedSongJson).toList(),
    'matches': [for (final match in page.matches) _encode(match)],
  };
}

Map<String, dynamic> _encode(LocalLyricsSearchMatch match) => {
  'song': match.songId,
  'snippet': match.snippet,
  'contextLines': match.contextLines,
  'matchContexts': match.matchContexts,
  'timestampMs': match.timestampMs,
  'additionalMatchCount': match.additionalMatchCount,
  'relevance': match.relevance,
};
