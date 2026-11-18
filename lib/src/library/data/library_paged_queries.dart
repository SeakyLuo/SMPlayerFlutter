part of 'library_providers.dart';

final libraryPagedQueryProvider = AsyncNotifierProvider.autoDispose
    .family<LibraryPagedQuery, LibraryContentData, LibraryDataQuery>(
      LibraryPagedQuery.new,
    );

class LibraryPagedQuery
    extends
        AutoDisposeFamilyAsyncNotifier<LibraryContentData, LibraryDataQuery> {
  var _generation = 0;
  void Function()? _releaseCache;
  var _visibleOffset = 0;
  var _visibleIndex = 0;
  final _pages = <int, Map<int, LibrarySong>>{};
  final _requests = <int, Future<void>>{};

  @override
  Future<LibraryContentData> build(LibraryDataQuery query) async {
    final generation = ++_generation;
    ref.onDispose(() => _generation++);
    ref.watch(libraryQueryInvalidationProvider((query.kind, query.source)));
    if (query.kind == LibraryQueryKind.playlists && query.playlistId != null)
      ref.watch(
        libraryPlaylistQueryInvalidationProvider((
          query.source,
          query.playlistId!,
        )),
      );
    final playlistOverrides = ref.read(libraryPlaylistOverridesProvider);
    final previous = state.valueOrNull;
    final previousIndex = _visibleIndex;
    final anchor = previous?.songRows[previousIndex]?.id;
    _pages.clear();
    _requests.clear();
    final offset = previous == null ? query.offset : _visibleOffset;
    final raw = await ref
        .read(libraryRepositoryProvider)
        .queryLibrary(query.withPage(offset: offset, anchorSongId: anchor));
    final page = raw.withPage(
      anchorShift:
          previous == null
              ? 0
              : (raw.anchorIndex ?? previousIndex) - previousIndex,
      anchorRevision: generation,
    );
    if (_generation == generation) {
      if (page.playlists.isNotEmpty &&
          identical(
            playlistOverrides,
            ref.read(libraryPlaylistOverridesProvider),
          )) {
        final ids = page.playlists.map((list) => list.id).toSet();
        ref.read(libraryPlaylistOverridesProvider.notifier).state = {
          ...playlistOverrides,
        }..removeWhere((id, _) => ids.contains(id));
      }
      _visibleOffset = page.pageOffset;
      _visibleIndex = page.anchorIndex ?? previousIndex;
      _pages[page.pageOffset] = page.songRows;
      await ref.read(libraryLoadedDataProvider.notifier).publish(page, query);
      if (_generation == generation) _releaseCache = retainLibraryQuery(ref);
    }
    return page;
  }

  Future<void> loadWindow(int rowIndex) async {
    final current = state.valueOrNull;
    if (current == null || current.totalSongCount == 0) return;
    final size = arg.limit!;
    final index = rowIndex.clamp(0, current.totalSongCount - 1);
    _visibleIndex = index;
    _visibleOffset = index ~/ size * size;
    final offsets = [
      _visibleOffset,
      if (_visibleOffset + size < current.totalSongCount) _visibleOffset + size,
    ];
    await Future.wait(offsets.map(_readPage));
  }

  Future<void> _readPage(int offset) {
    if (_pages.containsKey(offset)) return Future.value();
    return _requests.putIfAbsent(offset, () {
      final generation = _generation;
      late Future<void> request;
      request = () async {
        try {
          final page = await ref
              .read(libraryRepositoryProvider)
              .queryLibrary(arg.withPage(offset: offset));
          if (generation != _generation) return;
          _pages[page.pageOffset] = page.songRows;
          final keep =
              _pages.keys.toList()..sort(
                (a, b) => (a - _visibleOffset).abs().compareTo(
                  (b - _visibleOffset).abs(),
                ),
              );
          final retained = keep.take(3).toSet();
          _pages.removeWhere((key, _) => !retained.contains(key));
          final rows = <int, LibrarySong>{
            for (final page in _pages.values) ...page,
          };
          final positions = rows.keys.toList()..sort();
          if (!state.hasValue) return;
          final current = state.requireValue;
          final next = current.withPage(
            songs: [for (final position in positions) rows[position]!],
            songRows: rows,
            totalSongCount: page.totalSongCount,
            totalDuration: page.totalDuration,
          );
          state = AsyncData(next);
          await ref.read(libraryLoadedDataProvider.notifier).publish(next, arg);
        } catch (error, stack) {
          if (generation == _generation) {
            state = AsyncError<LibraryContentData>(
              error,
              stack,
            ).copyWithPrevious(state);
          }
        } finally {
          if (identical(_requests[offset], request)) _requests.remove(offset);
        }
      }();
      return request;
    });
  }
}
