part of 'headered_playlist_control.dart';

extension _HeaderedPlaylistPaging on _HeaderedPlaylistControlState {
  LibraryDataQuery? get _effectiveQuery => _sortQuery ?? widget.query;

  LibraryContentData? get _page {
    final query = _effectiveQuery;
    if (query == null) return null;
    final page = ref.read(browsingLibraryPageProvider(query)).valueOrNull;
    if (page == null) return null;
    return applyLibraryFavoriteOverrides(
      page,
      ref.read(libraryFavoriteOverridesProvider),
      ref.read(librarySongOverridesProvider),
      ref.read(libraryPlaylistOverridesProvider),
      ref.read(libraryDeletedPlaylistIdsProvider),
      ref.read(libraryPlaylistOrderProvider),
    );
  }

  Future<List<int>> _scopeIds(List<int> loadedIds) async {
    final query = _effectiveQuery;
    if (query == null) return loadedIds;
    final source = ref.read(selectedLibraryDataSourceProvider);
    final scope = query.withPage(
      source:
          query.kind == LibraryQueryKind.queue
              ? 'local'
              : source.source.deviceId,
    );
    if (_scopeQuery != scope) {
      _scopeQuery = scope;
      _scopeRead =
          scope.kind == LibraryQueryKind.queue
              ? ref.read(libraryRepositoryProvider).resolveLocalSongIds(scope)
              : source.resolveSongIds(scope);
    }
    final request = _scopeRead!;
    try {
      return await request;
    } finally {
      if (identical(request, _scopeRead)) {
        _scopeRead = null;
        _scopeQuery = null;
      }
    }
  }

  Future<void> _selectScope(
    List<int> loadedIds, {
    required bool reverse,
  }) async {
    await runMusicShareAction(context, () async {
      final query = _effectiveQuery;
      final source =
          query?.kind == LibraryQueryKind.queue
              ? 'local'
              : ref.read(selectedLibraryDataSourceProvider).source.deviceId;
      final ids = await _scopeIds(loadedIds);
      if (!mounted ||
          query != _effectiveQuery ||
          source !=
              (_effectiveQuery?.kind == LibraryQueryKind.queue
                  ? 'local'
                  : ref
                      .read(selectedLibraryDataSourceProvider)
                      .source
                      .deviceId))
        return;
      _updateState(() {
        if (reverse) {
          _selection.reverseSelection(ids);
        } else {
          _selection.selectAll(ids);
        }
      });
    });
  }

  void _requestWindow(int index) {
    final query = _effectiveQuery!;
    final offset = index ~/ query.limit! * query.limit!;
    if (!_attemptedWindows.add(offset)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || query != _effectiveQuery) return;
      unawaited(
        runMusicShareAction(context, () async {
          final source =
              query.kind == LibraryQueryKind.queue
                  ? 'local'
                  : ref.read(selectedLibraryDataSourceProvider).source.deviceId;
          await ref
              .read(
                libraryPagedQueryProvider(
                  query.withPage(source: source),
                ).notifier,
              )
              .loadWindow(index);
        }),
      );
    });
  }

  String _headerInfo(SmPlayerI18n i18n, List<LibrarySong> songs) {
    final page = _page;
    if (page == null) return getHeaderPlaylistInfo(songs, i18n);
    final count =
        '${i18n.t('headeredPlaylist.songsPrefix')}${page.totalSongCount}';
    return page.totalSongCount < 2
        ? count
        : '$count • ${formatDuration(page.totalDuration.toDouble())}';
  }
}
