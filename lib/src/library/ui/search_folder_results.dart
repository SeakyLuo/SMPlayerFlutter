part of 'search_page_model.dart';

List<SearchResult> _buildFolderResults(
  List<LibrarySong> songs,
  List<LibraryFolder> folders,
  List<LibrarySong> matchedSongs,
  String rootPath,
  String normalizedQuery,
  SmPlayerI18n i18n,
  Map<int, String>? songFolderPaths,
) {
  final matchedFolderPaths =
      matchedSongs
          .map(
            (song) => (songFolderPaths?[song.id] ?? getFolderPath(song.path)),
          )
          .toSet();
  final candidateFolderPaths = <String>{};
  final folderByPath = {for (final folder in folders) folder.path: folder};

  for (final folder in folders) {
    final folderName = getPathLabel(folder.path);
    if (evaluateString(folderName, normalizedQuery) > 0 ||
        evaluateString(folder.path, normalizedQuery) > 0) {
      candidateFolderPaths.add(folder.path);
    }
  }
  candidateFolderPaths.addAll(matchedFolderPaths);

  final normalizedCandidateFolderPathByPath = {
    for (final folderPath in candidateFolderPaths)
      normalizeFolderPath(folderPath): folderPath,
  };
  final songsByFolder = <String, List<LibrarySong>>{};
  for (final song in songs) {
    var currentFolderPath = normalizeFolderPath(
      (songFolderPaths?[song.id] ?? getFolderPath(song.path)),
    );
    while (currentFolderPath.isNotEmpty) {
      final candidateFolderPath =
          normalizedCandidateFolderPathByPath[currentFolderPath];
      if (candidateFolderPath != null) {
        final folderSongs =
            songsByFolder[candidateFolderPath] ?? <LibrarySong>[];
        folderSongs.add(song);
        songsByFolder[candidateFolderPath] = folderSongs;
      }
      currentFolderPath = getParentFolderPath(currentFolderPath);
    }
  }

  final results =
      candidateFolderPaths
          .map((folderPath) {
            final folderSongs =
                songsByFolder[folderPath] ?? const <LibrarySong>[];
            final folderName = getPathLabel(folderPath);
            return SearchResult(
              score: [
                evaluateString(folderName, normalizedQuery),
                evaluateString(folderPath, normalizedQuery),
                matchedFolderPaths.contains(folderPath) ? 1 : 0,
              ].reduce((left, right) => left > right ? left : right),
              title:
                  folderName.isEmpty ? i18n.t('local.libraryRoot') : folderName,
              subtitle: i18n.t('cards.songCount', {
                'count': folderSongs.length,
              }),
              artworkUrl:
                  folderSongs
                      .where((song) => song.thumbnailPath.isNotEmpty)
                      .map((song) => song.thumbnailPath)
                      .firstOrNull ??
                  '',
              path: '/local',
              localFolderRelativePath: getRelativeFolderPath(
                folderPath,
                rootPath,
              ),
              songCount: folderSongs.length,
              playCount: folderSongs.fold(
                0,
                (total, song) => total + song.playCount,
              ),
              duration: folderSongs.fold(
                0,
                (total, song) => total + song.duration,
              ),
              albumCount: 0,
              songIds: folderSongs.map((song) => song.id).toList(),
              sourceId: folderByPath[folderPath]?.id.toString(),
              sourcePath: folderPath,
            );
          })
          .where(
            (result) =>
                result.score > 0 && folderByPath.containsKey(result.sourcePath),
          )
          .toList()
        ..sort(
          (left, right) => _compareMany([
            right.score.compareTo(left.score),
            (left.sourcePath ?? '').compareTo(right.sourcePath ?? ''),
          ]),
        );
  return results;
}
