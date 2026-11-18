part of 'library_providers.dart';

final libraryDirectoryWindowsProvider = AsyncNotifierProvider.autoDispose
    .family<LibraryDirectoryWindows, LibraryContentData, LibraryDataQuery>(
      LibraryDirectoryWindows.new,
    );

class LibraryDirectoryWindows
    extends
        AutoDisposeFamilyAsyncNotifier<LibraryContentData, LibraryDataQuery> {
  final _windows = <(String, int), Map<int, LibrarySong>>{};
  var _generation = 0;
  final _requests = <(String, int), Future<void>>{};
  var _visible = <(String, int)>[];
  @override
  Future<LibraryContentData> build(LibraryDataQuery query) async {
    final generation = ++_generation;
    ref.onDispose(() => _generation++);
    ref.watch(
      libraryQueryInvalidationProvider((
        LibraryQueryKind.folders,
        query.source,
      )),
    );
    _windows.clear();
    _requests.clear();
    _visible = [];
    final page = await ref.read(libraryRepositoryProvider).queryLibrary(query);
    if (generation == _generation) {
      for (final entry in query.directWindows.entries)
        _windows[(entry.key, entry.value)] =
            page.folderSongRows[entry.key] ?? const {};
      await ref.read(libraryLoadedDataProvider.notifier).publish(page, query);
      if (generation == _generation) retainLibraryQuery(ref);
    }
    return page;
  }

  Future<void> loadWindows(Map<String, int> requested) async {
    _visible = [
      for (final entry in requested.entries) (entry.key, entry.value),
    ];
    final waiting = {
      for (final key in _visible)
        if (_requests[key] case final request?) request,
    };
    final missing = {
      for (final entry in requested.entries)
        if (!_windows.containsKey((entry.key, entry.value)) &&
            !_requests.containsKey((entry.key, entry.value)))
          entry.key: entry.value,
    };
    if (missing.isNotEmpty) {
      final generation = _generation;
      late Future<void> request;
      request = () async {
        try {
          final page = await ref
              .read(libraryRepositoryProvider)
              .queryLibrary(
                LibraryDataQuery(
                  LibraryQueryKind.folders,
                  source: arg.source,
                  directWindows: missing,
                  order: arg.order,
                  descending: arg.descending,
                  text: arg.text,
                ),
              );
          if (generation != _generation) return;
          for (final entry in missing.entries)
            _windows[(entry.key, entry.value)] =
                page.folderSongRows[entry.key] ?? const {};
          final keys = [
            ..._visible.where(_windows.containsKey),
            ..._windows.keys.toList().reversed,
          ];
          final retained = keys.toSet().take(3).toSet();
          _windows.removeWhere((key, _) => !retained.contains(key));
          final rows = <String, Map<int, LibrarySong>>{};
          for (final entry in _windows.entries)
            rows.putIfAbsent(entry.key.$1, () => {}).addAll(entry.value);
          final next = page.withPage(
            folderSongRows: rows,
            songs: rows.values.expand((rows) => rows.values).toList(),
          );
          state = AsyncData(next);
          await ref.read(libraryLoadedDataProvider.notifier).publish(next, arg);
        } finally {
          for (final entry in missing.entries) {
            final key = (entry.key, entry.value);
            if (identical(_requests[key], request)) _requests.remove(key);
          }
        }
      }();
      for (final entry in missing.entries)
        _requests[(entry.key, entry.value)] = request;
      waiting.add(request);
    }
    await Future.wait(waiting);
  }
}
