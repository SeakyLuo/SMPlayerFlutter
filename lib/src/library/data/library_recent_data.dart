import 'library_repository.dart';
import 'library_models.dart';
import 'library_queries.dart';

Future<RecentPageData> readLocalRecentData(LibraryRepository repository) async {
  final (added, played, playlists) =
      await (
        repository.queryLibrary(
          const LibraryDataQuery(
            LibraryQueryKind.songs,
            order: MusicLibrarySortCriterion.dateAdded,
            descending: true,
            limit: 500,
          ),
        ),
        repository.queryLibrary(
          const LibraryDataQuery(LibraryQueryKind.recent),
        ),
        repository.getLocalPlaylists(),
      ).wait;
  return repository.getRecentPageData(
    played
        .withPage(
          songs:
              {
                for (final s in [...added.songs, ...played.songs]) s.id: s,
              }.values.toList(),
        )
        .withPlaylists(playlists),
  );
}
