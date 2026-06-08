part of 'local_page.dart';

extension _LocalPageFolderActions on _LocalPageState {
  void _openFolder(String relativePath) {
    final query = <String, String>{};
    if (relativePath.isNotEmpty) {
      query['path'] = relativePath;
    }
    if (widget.searchQuery.trim().isNotEmpty) {
      query['query'] = widget.searchQuery.trim();
    }

    context.go(Uri(path: '/local', queryParameters: query).toString());
  }

  Future<void> _createFolder({
    required FolderNode parent,
    required Map<String, FolderNode> nodes,
    required String rootPath,
    required SmPlayerI18n i18n,
  }) async {
    final repository = ref.read(libraryRepositoryProvider);
    final name = await _requestFolderName(
      i18n: i18n,
      defaultName: _nextFolderName(parent.relativePath, nodes, i18n),
      validate: (value) {
        return _folderNameValidationError(
          parent.relativePath,
          value,
          nodes,
          i18n,
        );
      },
    );
    if (name == null) {
      return;
    }

    final relativePath =
        parent.relativePath.isEmpty ? name : '${parent.relativePath}/$name';
    await repository.createLocalFolder(rootPath, parent.relativePath, name);
    if (!mounted) {
      return;
    }

    _updateLocalPageState(() {
      _createdFolderPaths.add(relativePath);
    });
    ref.invalidate(libraryContentDataProvider);
  }

  Future<void> _renameFolder({
    required FolderNode folder,
    required Map<String, FolderNode> nodes,
    required String rootPath,
    required SmPlayerI18n i18n,
  }) async {
    final name = await _requestFolderName(
      i18n: i18n,
      title: i18n.t('local.renameFolderPrompt'),
      defaultName: folder.name,
      validate: (value) {
        return _folderNameValidationError(
          getParentPath(folder.relativePath),
          value,
          nodes,
          i18n,
          folder.name,
        );
      },
    );
    if (name == null || name == folder.name) {
      return;
    }

    await ref.read(libraryRepositoryProvider).renameFolder(folder.path, name);
    ref.invalidate(libraryContentDataProvider);

    if (folder.relativePath == widget.currentRelativePath && mounted) {
      final parentPath = getParentPath(folder.relativePath);
      final nextRelativePath = parentPath.isEmpty ? name : '$parentPath/$name';
      _openFolder(nextRelativePath);
    }
  }

  Future<void> _hideFolder(FolderNode folder) async {
    await ref.read(libraryRepositoryProvider).hideFolder(folder.path);
    ref.invalidate(libraryContentDataProvider);
    if (mounted) {
      _updateLocalPageState(_clearMultiSelectStatus);
      showUndoableNotification(
        context: context,
        i18n: context.smPlayerI18n,
        message: context.smPlayerI18n.t('notification.hiddenStorageItem', {
          'name':
              folder.name.isEmpty
                  ? context.smPlayerI18n.t('local.libraryRoot')
                  : folder.name,
        }),
        onUndo: () async {
          await ref.read(libraryRepositoryProvider).unhideFolder(folder.path);
          ref.invalidate(libraryContentDataProvider);
        },
      );
    }
  }

  Future<void> _searchDirectory(FolderNode folder, SmPlayerI18n i18n) async {
    final query = await _requestSearchDirectoryQuery(folder, i18n);
    if (query == null) {
      return;
    }
    if (!mounted) {
      return;
    }

    unawaited(
      ref
          .read(libraryRepositoryProvider)
          .addRecentSearch(query, SearchHistoryType.folders)
          .then((_) {
            invalidateRecentSearchData(ref);
          }),
    );
    context.go(
      Uri(
        path: '/search',
        queryParameters: {
          'query': query,
          'type': 'folders',
          'folder': folder.relativePath,
        },
      ).toString(),
    );
  }

  Future<String?> _requestSearchDirectoryQuery(
    FolderNode folder,
    SmPlayerI18n i18n,
  ) async {
    return showSmPlayerInputDialog(
      context: context,
      i18n: i18n,
      title: i18n.t('local.searchDirectoryPrompt', {'name': folder.name}),
      defaultValue: '',
      confirmText: i18n.t('common.search'),
      validate: (query) {
        return query.isEmpty ? i18n.t('local.searchQueryEmpty') : '';
      },
    );
  }

  Future<void> _revealFolder(FolderNode folder) async {
    await ref.read(localPageOpenFolderInShellProvider)(folder.path);
  }

  Future<void> _revealSong(LibrarySong song) async {
    await ref.read(localPageRevealItemInFolderProvider)(song.path);
  }

  String _nextFolderName(
    String parentRelativePath,
    Map<String, FolderNode> nodes,
    SmPlayerI18n i18n,
  ) {
    final baseName = i18n.t('local.newFolderName');
    if (!_folderPathExists(parentRelativePath, baseName, nodes)) {
      return baseName;
    }

    var index = 1;
    var nextName = '$baseName ($index)';
    while (_folderPathExists(parentRelativePath, nextName, nodes)) {
      index += 1;
      nextName = '$baseName ($index)';
    }
    return nextName;
  }

  bool _folderPathExists(
    String parentRelativePath,
    String folderName,
    Map<String, FolderNode> nodes,
  ) {
    final relativePath =
        parentRelativePath.isEmpty
            ? folderName
            : '$parentRelativePath/$folderName';
    return nodes.containsKey(relativePath) ||
        _createdFolderPaths.contains(relativePath);
  }

  String _folderNameValidationError(
    String parentRelativePath,
    String name,
    Map<String, FolderNode> nodes,
    SmPlayerI18n i18n, [
    String currentName = '',
  ]) {
    final nextName = name.trim();
    if (nextName.isEmpty) {
      return i18n.t('local.folderNameEmpty');
    }
    if (nextName.length > 50) {
      return i18n.t('local.folderNameTooLong');
    }
    if (nextName != currentName &&
        _folderPathExists(parentRelativePath, nextName, nodes)) {
      return i18n.t('local.folderNameUsed');
    }
    return '';
  }

  Future<String?> _requestFolderName({
    required SmPlayerI18n i18n,
    required String defaultName,
    required String Function(String value) validate,
    String? title,
  }) async {
    final result = await showSmPlayerInputDialog(
      context: context,
      i18n: i18n,
      title: title ?? i18n.t('local.newFolderPrompt'),
      defaultValue: defaultName,
      confirmText: i18n.t('playlists.create'),
      validate: validate,
    );
    return result;
  }
}
