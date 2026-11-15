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
    final storage = LibraryStorageActions(ref);
    final source =
        isRemoteMusicPath(parent.path) ? Uri.parse(parent.path).host : 'local';
    final name = await _requestFolderName(
      i18n: i18n,
      confirmText: i18n.t('playlists.create'),
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
    try {
      await storage.createFolder(rootPath, parent.relativePath, name);
    } catch (error) {
      if (mounted) {
        _showMessage(
          i18n.t(
            error is MusicShareException
                ? error.messageKey
                : 'song.updateFailed',
          ),
        );
      }
      return;
    }
    if (!mounted || _source != source) {
      return;
    }

    _updateLocalPageState(() {
      _createdFolderPaths.add(relativePath);
    });
  }

  Future<void> _renameFolder({
    required FolderNode folder,
    required Map<String, FolderNode> nodes,
    required String rootPath,
    required SmPlayerI18n i18n,
  }) async {
    final source =
        isRemoteMusicPath(folder.path) ? Uri.parse(folder.path).host : 'local';
    final name = await _requestFolderName(
      i18n: i18n,
      title: i18n.t('local.renameFolder'),
      confirmText: i18n.t('playlists.rename'),
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

    if (!mounted) return;
    await runLibraryStorageAction(context, () async {
      final change = await LibraryStorageActions(
        ref,
      ).renameFolder(folder.path, name);
      final parentPath = getParentPath(folder.relativePath);
      final next = parentPath.isEmpty ? name : '$parentPath/$name';
      if (!mounted) {
        await change.commit();
        return;
      }
      if (_source == source &&
          folder.relativePath == widget.currentRelativePath) {
        _openFolder(next);
      }
      final reason = await showUndoableNotification(
        context: context,
        i18n: i18n,
        message: i18n.t('share.fileRenamed'),
        onUndo: () async {
          await change.undo();
          if (mounted &&
              _source == source &&
              widget.currentRelativePath == next) {
            _openFolder(folder.relativePath);
          }
        },
      );
      if (reason != AppNotificationClosedReason.action) await change.commit();
    });
  }

  Future<void> _hideFolder(FolderNode folder) async {
    await runLibraryStorageAction(context, () async {
      final change = await LibraryStorageActions(ref).hideFolder(folder.path);
      if (!mounted) {
        await change.commit();
        return;
      }
      _updateLocalPageState(_clearMultiSelectStatus);
      await _showStorageChangeUndo(
        change,
        context.smPlayerI18n.t('notification.hiddenStorageItem', {
          'name': folder.name,
        }),
      );
    });
  }

  Future<void> _searchDirectory(FolderNode folder, SmPlayerI18n i18n) async {
    final result = await _requestSearchDirectoryQuery(folder, i18n);
    if (result == null) {
      return;
    }
    if (!mounted) {
      return;
    }

    if (result.addToRecentSearches) {
      final recentSearches = ref.read(recentSearchesProvider.notifier);
      unawaited(
        ref
            .read(libraryRepositoryProvider)
            .addRecentSearch(result.query, SearchHistoryType.folders)
            .then((entry) {
              if (entry != null) {
                return recentSearches.record(entry);
              }
            }),
      );
    }
    context.go(
      Uri(
        path: '/search',
        queryParameters: {
          'query': result.query,
          'type': 'folders',
          'folder': folder.relativePath,
        },
      ).toString(),
    );
  }

  Future<({String query, bool addToRecentSearches})?>
  _requestSearchDirectoryQuery(FolderNode folder, SmPlayerI18n i18n) async {
    final recentSearches =
        latestSearchHistoryEntries(
          ref.read(recentSearchesProvider).valueOrNull ??
              ref.read(libraryContentDataProvider).value!.recentSearches,
          SearchHistoryType.folders,
        ).toList();
    var selectedSearchHistory = false;
    final query = await showSmPlayerInputDialog(
      context: context,
      i18n: i18n,
      title: i18n.t('local.searchDirectoryPrompt', {'name': folder.name}),
      defaultValue: '',
      confirmText: i18n.t('common.search'),
      searchHistoryEntries: recentSearches,
      onSearchHistorySelected: (_) {
        selectedSearchHistory = true;
      },
      onRemoveSearchHistory: _removeSearchDirectoryHistory,
      onClearSearchHistory: () {
        _clearSearchDirectoryHistory(recentSearches);
      },
      validate: (query) {
        return query.isEmpty ? i18n.t('local.searchQueryEmpty') : '';
      },
    );
    if (query == null) {
      return null;
    }
    return (query: query, addToRecentSearches: !selectedSearchHistory);
  }

  void _removeSearchDirectoryHistory(int entryId) {
    final recentSearches = ref.read(recentSearchesProvider.notifier);
    unawaited(
      ref.read(libraryRepositoryProvider).removeRecentSearches([entryId]).then((
        _,
      ) {
        return recentSearches.remove([entryId]);
      }),
    );
  }

  void _clearSearchDirectoryHistory(List<SearchHistoryEntry> entries) {
    final entryIds = entries.map((entry) => entry.id).toList();
    final recentSearches = ref.read(recentSearchesProvider.notifier);
    unawaited(
      ref.read(libraryRepositoryProvider).removeRecentSearches(entryIds).then((
        _,
      ) {
        return recentSearches.remove(entryIds);
      }),
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
    required String confirmText,
    required SmPlayerI18n i18n,
    required String defaultName,
    required String Function(String value) validate,
    String? title,
  }) async {
    final result = await showSmPlayerInputDialog(
      context: context,
      i18n: i18n,
      title: title ?? i18n.t('local.createFolderTitle'),
      defaultValue: defaultName,
      placeholder: i18n.t('local.newFolderPrompt'),
      confirmText: confirmText,
      validate: validate,
    );
    return result;
  }
}
