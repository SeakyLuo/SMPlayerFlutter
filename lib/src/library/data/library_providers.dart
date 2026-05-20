import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'library_models.dart';
import 'library_repository.dart';

final libraryRepositoryProvider = Provider<LibraryRepository>((ref) {
  return const LibraryRepository();
});

final musicLibrarySnapshotProvider = FutureProvider<MusicLibrarySnapshot>((
  ref,
) async {
  return ref.watch(libraryRepositoryProvider).getMusicLibrarySnapshot();
});
