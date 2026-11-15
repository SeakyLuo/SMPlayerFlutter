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
    late final LibraryStorageChange change;
    _updateLocalPageState(() {
      _localOperationTitle = context.smPlayerI18n.t('context.moveToFolder');
      _refreshProgress = const LocalFolderRefreshProgress(
        current: 0,
        total: 1,
        currentPath: '',
      );
    });
    try {
      change = await LibraryStorageActions(
        ref,
      ).moveItems(context, songIds, folderPaths, targetFolderPath);
    } catch (error) {
      if (mounted) {
        _showMessage(
          context.smPlayerI18n.t(
            error is MusicShareException
                ? error.messageKey
                : 'song.updateFailed',
          ),
        );
      }
      return;
    } finally {
      if (mounted) {
        _updateLocalPageState(() {
          _refreshProgress = null;
          _localOperationTitle = null;
        });
      }
    }
    if (!mounted || change.count == 0) {
      await change.commit();
      return;
    }
    await _showStorageChangeUndo(
      change,
      context.smPlayerI18n.t('notification.movedLocalItems', {
        'count': change.count,
      }),
    );
  }

  Future<void> _requestDeleteLocalItems({
    required List<int> songIds,
    required List<String> folderPaths,
    required SmPlayerI18n i18n,
  }) async {
    final storage = LibraryStorageActions(ref);
    late final LibraryStorageChange change;
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
        change = await storage.deleteItems(songIds, folderPaths);
      },
    );
    if (!confirmed) {
      return;
    }

    await _showStorageChangeUndo(
      change,
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
    final storage = LibraryStorageActions(ref);
    late final LibraryStorageChange change;
    final confirmed = await showSmPlayerConfirmDialog(
      context: context,
      i18n: i18n,
      title: i18n.t('local.deleteFolder'),
      message: i18n.t('local.deleteFolderConfirm', {'name': folder.name}),
      confirmText: i18n.t('local.deleteFolder'),
      onConfirm: () async {
        change = await storage.deleteItems(const [], [folder.path]);
      },
    );
    if (!confirmed) {
      return;
    }

    await _showStorageChangeUndo(
      change,
      i18n.t('notification.deletedLocalItems', {'count': 1}),
    );
  }

  Future<void> _showStorageChangeUndo(
    LibraryStorageChange change,
    String message,
  ) async {
    if (!mounted) {
      await change.commit();
      return;
    }
    final reason = await showUndoableNotification(
      context: context,
      i18n: context.smPlayerI18n,
      message: message,
      onUndo: () => runLibraryStorageAction(context, change.undo),
    );
    if (reason != AppNotificationClosedReason.action) {
      if (mounted) {
        await runLibraryStorageAction(context, change.commit);
      } else {
        await change.commit();
      }
    }
  }

  String _formatDeleteSelectedLocalItemsConfirm(
    SmPlayerI18n i18n,
    int itemCount,
  ) {
    return i18n.t('local.deleteSelectedItemsConfirm', {'count': itemCount});
  }
}
