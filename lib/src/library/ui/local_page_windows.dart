part of 'local_page.dart';

extension _LocalPageWindows on _LocalPageState {
  MusicLibrarySortCriterion get _directoryOrder => switch (_sortMode) {
    LocalSortMode.artist => MusicLibrarySortCriterion.artist,
    LocalSortMode.album => MusicLibrarySortCriterion.album,
    _ => MusicLibrarySortCriterion.title,
  };

  void _accessFolderSong(String path, int index) {
    final offset = index ~/ 200 * 200;
    if (_requestedWindows[path] == offset) return;
    _requestedWindows[path] = offset;
    _pendingWindows[path] = offset;
    if (_windowsScheduled) return;
    _windowsScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _windowsScheduled = false;
      if (!mounted) return;
      final requested = Map<String, int>.fromEntries(
        _pendingWindows.entries.toList().reversed.take(3),
      );
      _pendingWindows.clear();
      final query = _windowQuery!;
      unawaited(
        runMusicShareAction(context, () async {
          try {
            await ref
                .read(libraryDirectoryWindowsProvider(query).notifier)
                .loadWindows(requested);
          } finally {
            for (final path in requested.keys) _requestedWindows.remove(path);
          }
        }),
      );
    });
  }

  Future<void> _selectDirectoryScope(
    FolderNode current,
    List<String> folders,
    Map<String, FolderNode> nodes, {
    required bool reverse,
  }) => runMusicShareAction(context, () async {
    final source = ref.read(selectedLibraryDataSourceProvider);
    final search = widget.searchQuery;
    final direct = [
      current.path,
      for (final relative in _treeExpandedFolderPaths) nodes[relative]!.path,
    ];
    final ids = await source.resolveSongIds(
      LibraryDataQuery(
        LibraryQueryKind.songs,
        directFolders: direct,
        text: widget.searchQuery,
      ),
    );
    if (!mounted ||
        source.source.deviceId != _source ||
        current.relativePath != widget.currentRelativePath ||
        search != widget.searchQuery)
      return;
    _updateLocalPageState(() {
      final selectedFolders =
          reverse
              ? folders
                  .where((path) => !_selectedFolderPaths.contains(path))
                  .toList()
              : folders;
      final selectedSongs =
          reverse
              ? ids.where((id) => !_selectedSongIds.contains(id)).toList()
              : ids;
      _selectedFolderPaths
        ..clear()
        ..addAll(selectedFolders);
      _selectedSongIds
        ..clear()
        ..addAll(selectedSongs);
    });
  });

  Future<void> _playDirectorySong(
    LibrarySong song,
    LibraryContentData snapshot,
  ) => runMusicShareAction(context, () async {
    final folder =
        _remote ? snapshot.songFolderPaths[song.id]! : p.dirname(song.path);
    final ids = await ref
        .read(selectedLibraryDataSourceProvider)
        .resolveSongIds(
          LibraryDataQuery(
            LibraryQueryKind.songs,
            directFolders: [folder],
            text: widget.searchQuery,
            substringSearch: true,
            order: _directoryOrder,
            descending: _sortMode == LocalSortMode.reverse,
          ),
        );
    if (mounted) _playTrack(song.id, ids);
  });

  Future<List<int>> _folderScopeIds(FolderNode node, {bool recursive = true}) =>
      ref
          .read(selectedLibraryDataSourceProvider)
          .resolveSongIds(
            LibraryDataQuery(
              LibraryQueryKind.songs,
              folder: recursive ? node.path : null,
              directFolders: recursive ? const [] : [node.path],
              text: widget.searchQuery,
              substringSearch: true,
              order: _directoryOrder,
              descending: _sortMode == LocalSortMode.reverse,
            ),
          );
}
