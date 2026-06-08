part of 'local_page.dart';

extension _LocalPageFileActions on _LocalPageState {
  void _showSelectedMoveToFolderMenu({
    required BuildContext buttonContext,
    required Map<String, FolderNode> nodes,
    required Map<int, LibrarySong> songsById,
    required List<int> songIds,
    required List<String> folderPaths,
    required SmPlayerI18n i18n,
    required bool hideMultiSelectCommandBarAfterOperation,
  }) {
    final moveItems = buildLocalMoveToFolderMenuItems(
      nodes: nodes,
      songsById: songsById,
      songIds: songIds,
      folderPaths: folderPaths,
      i18n: i18n,
      onMoveToFolder: (targetFolder) async {
        await _moveLocalItemsToFolder(
          songIds: songIds,
          folderPaths: folderPaths,
          targetFolderPath: targetFolder.path,
        );
        if (mounted) {
          _updateLocalPageState(() {
            _hideMultiSelectAfterOperation(
              hideMultiSelectCommandBarAfterOperation,
            );
          });
        }
      },
    );
    if (moveItems.isEmpty) {
      return;
    }

    showMenuFlyout(buttonContext, items: moveItems);
  }

  Future<void> _moveLocalItemsToFolder({
    required List<int> songIds,
    required List<String> folderPaths,
    required String targetFolderPath,
  }) async {
    _updateLocalPageState(() {
      _localOperationTitle = context.smPlayerI18n.t('context.moveToFolder');
      _refreshProgress = const LocalFolderRefreshProgress(
        current: 0,
        total: 1,
        currentPath: '',
      );
    });
    try {
      final result = await ref
          .read(libraryRepositoryProvider)
          .moveLocalItemsToFolder(
            songIds,
            folderPaths,
            targetFolderPath,
            resolveConflict:
                (sourcePath, targetPath) => requestLocalMoveConflictResolution(
                  context: context,
                  i18n: context.smPlayerI18n,
                  sourcePath: sourcePath,
                  targetPath: targetPath,
                ),
          );
      if (!mounted) {
        return;
      }
      ref.invalidate(libraryContentDataProvider);
      if (result.itemCount > 0) {
        showUndoableNotification(
          context: context,
          i18n: context.smPlayerI18n,
          message: context.smPlayerI18n.t('notification.movedLocalItems', {
            'count': result.itemCount,
          }),
          onUndo: () async {
            await ref
                .read(libraryRepositoryProvider)
                .undoMoveLocalItems(result);
            ref.invalidate(libraryContentDataProvider);
          },
        );
      }
    } finally {
      if (mounted) {
        _updateLocalPageState(() {
          _refreshProgress = null;
          _localOperationTitle = null;
        });
      }
    }
  }

  Future<void> _requestDeleteLocalItems({
    required List<int> songIds,
    required List<String> folderPaths,
    required SmPlayerI18n i18n,
  }) async {
    late final PendingLocalItemsDelete pendingDelete;
    final confirmed = await showSmPlayerConfirmDialog(
      context: context,
      i18n: i18n,
      title: i18n.t('context.deleteFromDisk'),
      message: _formatDeleteSelectedLocalItemsConfirm(
        i18n,
        songIds.length + folderPaths.length,
      ),
      confirmText: i18n.t('context.deleteFromDisk'),
      onConfirm: () async {
        pendingDelete = await ref
            .read(libraryRepositoryProvider)
            .beginDeleteLocalItems(songIds, folderPaths);
      },
    );
    if (!confirmed) {
      return;
    }

    await _showPendingLocalItemsDeleteUndo(
      pendingDelete.id,
      i18n.t('notification.deletedLocalItems', {
        'count': songIds.length + folderPaths.length,
      }),
    );
    if (mounted) {
      _updateLocalPageState(() {
        _clearMultiSelectStatus();
      });
    }
  }

  Future<void> _requestDeleteFolder(
    FolderNode folder,
    SmPlayerI18n i18n,
  ) async {
    late final PendingLocalItemsDelete pendingDelete;
    final confirmed = await showSmPlayerConfirmDialog(
      context: context,
      i18n: i18n,
      title: i18n.t('local.deleteFolder'),
      message: i18n.t('local.deleteFolderConfirm', {'name': folder.name}),
      confirmText: i18n.t('local.deleteFolder'),
      onConfirm: () async {
        pendingDelete = await ref
            .read(libraryRepositoryProvider)
            .beginDeleteLocalItems(const [], [folder.path]);
      },
    );
    if (!confirmed) {
      return;
    }

    await _showPendingLocalItemsDeleteUndo(
      pendingDelete.id,
      i18n.t('notification.deletedLocalItems', {'count': 1}),
    );
  }

  Future<void> _showPendingLocalItemsDeleteUndo(
    String deleteId,
    String message,
  ) async {
    ref.invalidate(libraryContentDataProvider);
    if (!mounted) {
      await ref
          .read(libraryRepositoryProvider)
          .commitDeleteLocalItems(deleteId);
      return;
    }

    final closedReason = await showUndoableNotification(
      context: context,
      i18n: context.smPlayerI18n,
      message: message,
      onUndo: () async {
        await ref
            .read(libraryRepositoryProvider)
            .undoDeleteLocalItems(deleteId);
        ref.invalidate(libraryContentDataProvider);
      },
    );
    if (closedReason != AppNotificationClosedReason.action) {
      await ref
          .read(libraryRepositoryProvider)
          .commitDeleteLocalItems(deleteId);
    }
  }

  String _formatDeleteSelectedLocalItemsConfirm(
    SmPlayerI18n i18n,
    int itemCount,
  ) {
    if (i18n.locale.startsWith('zh')) {
      return '要从磁盘删除选中的 $itemCount 个项目吗？';
    }
    return 'Delete $itemCount selected item${itemCount == 1 ? '' : 's'} from disk?';
  }
}
