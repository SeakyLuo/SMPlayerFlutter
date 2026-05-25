import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'library_models.dart';
import 'library_repository.dart';

final libraryRepositoryProvider = Provider<LibraryRepository>((ref) {
  return const LibraryRepository();
});

final libraryDatabaseInitializationProvider = FutureProvider<void>((ref) {
  return ref.watch(libraryRepositoryProvider).initializeLibraryDatabase();
});

final recentPageDataProvider = FutureProvider<RecentPageData>((ref) {
  return ref.watch(libraryRepositoryProvider).getRecentPageData();
});

final shellNavigationDataProvider = FutureProvider<ShellNavigationData>((ref) {
  return ref.watch(libraryRepositoryProvider).getShellNavigationData();
});

final recentSearchesProvider = FutureProvider<List<SearchHistoryEntry>>((ref) {
  return ref.watch(libraryRepositoryProvider).getRecentSearches();
});

final librarySongCountProvider = FutureProvider<int>((ref) {
  return ref.watch(libraryRepositoryProvider).getLibrarySongCount();
});

final libraryContentDataProvider = FutureProvider<LibraryContentData>((
  ref,
) async {
  return ref.watch(libraryRepositoryProvider).getLibraryContentData();
});

void invalidateRecentSearchData(WidgetRef ref) {
  ref.invalidate(libraryContentDataProvider);
  ref.invalidate(recentPageDataProvider);
  ref.invalidate(shellNavigationDataProvider);
  ref.invalidate(recentSearchesProvider);
}
