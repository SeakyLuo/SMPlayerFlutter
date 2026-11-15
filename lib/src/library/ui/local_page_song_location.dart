part of 'local_page.dart';

extension _LocalPageSongLocation on _LocalPageState {
  Future<void> _revealLocatedSong(LocalSongLocation location) =>
      runMusicShareAction(context, () async {
        if (!mounted ||
            _handledSongLocation != location ||
            widget.currentRelativePath != location.folderPath)
          return;
        final query = _windowQuery!;
        final path = query.directWindows.keys.single;
        final ids = await ref
            .read(selectedLibraryDataSourceProvider)
            .resolveSongIds(
              LibraryDataQuery(
                LibraryQueryKind.songs,
                directFolders: [path],
                order: _directoryOrder,
                descending: _sortMode == LocalSortMode.reverse,
              ),
            );
        final index = ids.indexOf(location.songId);
        if (index < 0) {
          if (mounted)
            _showMessage(context.smPlayerI18n.t('local.cannotLocateSong'));
          return;
        }
        await ref
            .read(libraryDirectoryWindowsProvider(query).notifier)
            .loadWindows({path: index ~/ 200 * 200});
        if (!mounted || query != _windowQuery) return;
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted || query != _windowQuery) return;
        final render =
            _songSliverKey.currentContext!.findRenderObject()! as RenderSliver;
        final offset =
            render is RenderSliverGrid
                ? render.constraints.precedingScrollExtent +
                    render.gridDelegate
                        .getLayout(render.constraints)
                        .getGeometryForChildIndex(index)
                        .scrollOffset
                : render.constraints.precedingScrollExtent +
                    index *
                        (PlaylistControlItemMetrics.rowHeight(
                              MediaQuery.sizeOf(context).width,
                            ) +
                            1);
        _scrollController.jumpTo(
          offset.clamp(0, _scrollController.position.maxScrollExtent),
        );
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted || query != _windowQuery) return;
        final song =
            ref
                .read(libraryDirectoryWindowsProvider(query))
                .requireValue
                .folderSongRows[path]![index]!;
        final target = GlobalObjectKey(song).currentContext!;
        await Scrollable.ensureVisible(
          target,
          alignment: 0.35,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
        if (!mounted) return;
        ref.read(localSongLocationProvider.notifier).state = null;
        _songLocationTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) _updateLocalPageState(() => _locatedSongId = null);
        });
      });
}
