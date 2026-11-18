part of 'search_page.dart';

final _searchIndexProvider = FutureProvider.autoDispose.family<
  LibraryContentData,
  LibraryDataQuery
>((ref, query) async {
  var active = true;
  ref.onDispose(() => active = false);
  ref.watch(
    libraryQueryInvalidationProvider((
      LibraryQueryKind.artistIndex,
      query.source,
    )),
  );
  ref.watch(
    libraryQueryInvalidationProvider((
      LibraryQueryKind.albumIndex,
      query.source,
    )),
  );
  ref.watch(
    libraryQueryInvalidationProvider((
      LibraryQueryKind.directoryIndex,
      query.source,
    )),
  );
  ref.watch(
    libraryQueryInvalidationProvider((
      LibraryQueryKind.playlistIndex,
      query.source,
    )),
  );
  final source = ref
      .read(libraryRepositoryProvider)
      .dataSource(LibrarySource.fromDevice(query.source));
  final (artists, albums, directories, lists) =
      await (
        source.query(
          LibraryDataQuery(LibraryQueryKind.artistIndex, folder: query.folder),
        ),
        source.query(
          LibraryDataQuery(LibraryQueryKind.albumIndex, folder: query.folder),
        ),
        source.query(const LibraryDataQuery(LibraryQueryKind.directoryIndex)),
        source.query(const LibraryDataQuery(LibraryQueryKind.playlistIndex)),
      ).wait;
  if (active) retainLibraryQuery(ref);
  return directories
      .withPlaylists(lists.playlists)
      .withPage(
        artistSummaries: artists.artistSummaries,
        albumSummaries: albums.albumSummaries,
      );
});

extension _SearchQueries on _SearchPageState {
  LibraryDataQuery _queryForSongs(String source, String? folder) {
    final criterion = _settings.searchSongsCriterion;
    final order = switch (criterion) {
      SearchSortCriterion.artist => MusicLibrarySortCriterion.artist,
      SearchSortCriterion.album => MusicLibrarySortCriterion.album,
      SearchSortCriterion.duration => MusicLibrarySortCriterion.duration,
      SearchSortCriterion.playCount => MusicLibrarySortCriterion.playCount,
      SearchSortCriterion.dateAdded => MusicLibrarySortCriterion.dateAdded,
      _ => MusicLibrarySortCriterion.title,
    };
    return LibraryDataQuery(
      LibraryQueryKind.songs,
      source: source,
      text: widget.query.trim(),
      folder: folder,
      unknownArtist: context.smPlayerI18n.t('common.artistUnknown'),
      unknownAlbum: context.smPlayerI18n.t('common.albumUnknown'),
      order: order,
      descending: criterion == SearchSortCriterion.playCount,
      relevance: criterion == SearchSortCriterion.defaultCriterion,
      limit: 200,
    );
  }

  Future<List<int>> _cardIds(SearchResult card) =>
      card.scope == null
          ? Future.value(card.songIds)
          : ref
              .read(selectedLibraryDataSourceProvider)
              .resolveSongIds(card.scope!);

  Future<void> _selectSearchScope(List<String> keys, {required bool reverse}) =>
      runMusicShareAction(context, () async {
        final query = _songQuery!;
        final allKeys = keys.toSet();
        if (_activeFilter == SearchFilterKey.all ||
            _activeFilter == SearchFilterKey.songs) {
          final ids = await ref
              .read(selectedLibraryDataSourceProvider)
              .resolveSongIds(query);
          allKeys.addAll(ids.map((id) => 'songs:$id'));
        }
        if (_activeFilter == SearchFilterKey.all ||
            _activeFilter == SearchFilterKey.lyrics) {
          final ids = await ref
              .read(selectedLibraryDataSourceProvider)
              .resolveSongIds(_lyricsQuery!);
          allKeys.addAll(ids.map((id) => 'songs:$id'));
        }
        if (!mounted || query != _songQuery) return;
        _updateSearchPageState(() {
          if (reverse) {
            _selection.reverseSelection(allKeys.toList());
          } else {
            _selection.selectAll(allKeys.toList());
          }
        });
      });

  void _accessSearchRow(int index) {
    final offset = index ~/ 200;
    if (!_attemptedSongWindows.add(offset)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        runMusicShareAction(context, () async {
          await ref
              .read(libraryPagedQueryProvider(_songQuery!).notifier)
              .loadWindow(index);
          _attemptedSongWindows.remove(offset);
        }),
      );
    });
  }
}
