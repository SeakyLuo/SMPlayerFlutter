part of 'search_page.dart';

class _LyricsWindow {
  const _LyricsWindow(this.total, this.rows);
  final int total;
  final Map<int, SearchLyricsResult> rows;
}

final _lyricsWindowProvider = AsyncNotifierProvider.autoDispose
    .family<_LyricsWindowNotifier, _LyricsWindow, LibraryDataQuery>(
      _LyricsWindowNotifier.new,
    );

class _LyricsWindowNotifier
    extends AutoDisposeFamilyAsyncNotifier<_LyricsWindow, LibraryDataQuery> {
  final _pages = <int, Map<int, SearchLyricsResult>>{};
  final _requests = <int, Future<void>>{};
  var _generation = 0;
  @override
  Future<_LyricsWindow> build(LibraryDataQuery query) async {
    final generation = ++_generation;
    ref.onDispose(() => _generation++);
    _pages.clear();
    _requests.clear();
    final page = await _read(query, 0);
    if (generation == _generation) _pages[0] = page.rows;
    return page;
  }

  Future<_LyricsWindow> _read(LibraryDataQuery query, int offset) async {
    final source = ref
        .read(libraryRepositoryProvider)
        .dataSource(LibrarySource.fromDevice(query.source));
    final page = await source.searchLyrics(
      query.text,
      folderPath: query.folder ?? '',
      offset: offset,
      order: query.relevance ? null : query.order,
    );
    final songs = {for (final song in page.songs) song.id: song};
    return _LyricsWindow(page.totalCount, {
      for (var index = 0; index < page.matches.length; index++)
        offset + index: SearchLyricsResult(
          song: songs[page.matches[index].songId]!,
          match: page.matches[index],
        ),
    });
  }

  Future<void> loadWindow(int index) {
    final offset = index ~/ 100 * 100;
    if (_pages.containsKey(offset)) return Future.value();
    return _requests.putIfAbsent(offset, () {
      final generation = _generation;
      return _read(arg, offset)
          .then((page) {
            if (generation != _generation) return;
            _pages[offset] = page.rows;
            final keys =
                _pages.keys.toList()..sort(
                  (a, b) => (a - offset).abs().compareTo((b - offset).abs()),
                );
            final keep = keys.take(3).toSet();
            _pages.removeWhere((key, _) => !keep.contains(key));
            state = AsyncData(
              _LyricsWindow(page.total, {
                for (final rows in _pages.values) ...rows,
              }),
            );
          })
          .whenComplete(() => _requests.remove(offset));
    });
  }
}

extension _SearchLyricsAccess on _SearchPageState {
  LibraryDataQuery _queryForLyrics(String source, String? folder) =>
      LibraryDataQuery(
        LibraryQueryKind.lyrics,
        source: source,
        folder: folder,
        text: widget.query.trim(),
        limit: 100,
        relevance: _lyricsCriterion == SearchSortCriterion.defaultCriterion,
        order: switch (_lyricsCriterion) {
          SearchSortCriterion.artist => MusicLibrarySortCriterion.artist,
          SearchSortCriterion.album => MusicLibrarySortCriterion.album,
          SearchSortCriterion.duration => MusicLibrarySortCriterion.duration,
          _ => MusicLibrarySortCriterion.title,
        },
      );
  void _accessLyricsRow(int index) {
    if (!_attemptedLyricsWindows.add(index ~/ 100)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        runMusicShareAction(context, () async {
          await ref
              .read(_lyricsWindowProvider(_lyricsQuery!).notifier)
              .loadWindow(index);
          _attemptedLyricsWindows.remove(index ~/ 100);
        }),
      );
    });
  }
}
