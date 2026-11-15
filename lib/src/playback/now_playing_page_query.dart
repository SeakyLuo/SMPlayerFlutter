part of 'now_playing_page.dart';

final _queueSearchIdsProvider = FutureProvider.autoDispose
    .family<List<int>, LibraryDataQuery>((ref, query) async {
      final repository = ref.read(libraryRepositoryProvider);
      final paths = await repository.songReferences(query.songIds);
      final groups = <LibrarySource, List<int>>{};
      for (final entry in paths.entries)
        groups
            .putIfAbsent(LibrarySource.fromPath(entry.value), () => [])
            .add(entry.key);
      final matches = await Future.wait(
        groups.entries.map(
          (entry) => repository
              .dataSource(entry.key)
              .resolveSongIds(
                LibraryDataQuery(
                  LibraryQueryKind.songs,
                  songIds: entry.value,
                  text: query.text,
                  substringSearch: true,
                ),
              ),
        ),
      );
      return matches.expand((ids) => ids).toList();
    });
