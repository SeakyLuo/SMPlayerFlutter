part of 'local_page.dart';

extension _LocalPageScanActions on _LocalPageState {
  Future<void> _refreshFolder(FolderNode folder, SmPlayerI18n i18n) async {
    final cancellation = LocalFolderScanCancellation();
    _updateLocalPageState(() {
      _scanCancellation = cancellation;
      _localOperationTitle = i18n.t('local.updateFolderProgressTitle');
      _refreshProgress = const LocalFolderRefreshProgress(
        current: 0,
        total: 1,
        currentPath: '',
        stage: LocalFolderRefreshStage.checking,
        canCancel: true,
      );
    });

    try {
      final result = await ref
          .read(libraryRepositoryProvider)
          .refreshLocalFolder(
            folder.path,
            cancellation: cancellation,
            onProgress: _setScanProgress,
          );
      if (!mounted) {
        return;
      }
      ref.invalidate(libraryViewDataProvider);
      _updateLocalPageState(() {
        _refreshProgress = null;
        _localOperationTitle = null;
        _scanCancellation = null;
        _refreshResultDialog = (folder: folder, result: result);
      });
      _showMessage(getRefreshResultMessage(result, i18n));
    } on LocalFolderScanCanceledException {
      _clearScanOverlay();
    } catch (_) {
      if (mounted) {
        _clearScanOverlay();
        _showMessage(i18n.t('local.updateFolder'));
      }
    }
  }

  Future<void> _pickAndScanLibraryRoot(SmPlayerI18n i18n) async {
    if (_pickingLibraryRoot || _rootScanRunning) {
      return;
    }
    _updateLocalPageState(() {
      _pickingLibraryRoot = true;
    });
    final String? selectedRootPath;
    try {
      selectedRootPath =
          widget.onPickLibraryRoot == null
              ? Platform.isMacOS
                  ? await pickDirectoryFromDesktopShell(
                    title: i18n.t('local.chooseMusicLibraryFolderDialogTitle'),
                    buttonLabel: i18n.t(
                      'local.chooseMusicLibraryFolderDialogButton',
                    ),
                  )
                  : await FilePicker.getDirectoryPath()
              : await widget.onPickLibraryRoot!();
    } finally {
      if (mounted) {
        _updateLocalPageState(() {
          _pickingLibraryRoot = false;
        });
      }
    }
    if (selectedRootPath == null || selectedRootPath.isEmpty) {
      if (mounted) {
        _showMessage(i18n.t('library.folderPickerUnavailable'));
      }
      return;
    }
    await _scanLibraryRoot(selectedRootPath, i18n);
  }

  Future<void> _scanLibraryRoot(String rootPath, SmPlayerI18n i18n) async {
    if (_rootScanRunning) {
      return;
    }
    final cancellation = LocalFolderScanCancellation();
    _updateLocalPageState(() {
      _rootScanRunning = true;
      _scanCancellation = cancellation;
      _localOperationTitle = i18n.t('library.scanning');
      _refreshProgress = const LocalFolderRefreshProgress(
        current: 0,
        total: 1,
        currentPath: '',
        stage: LocalFolderRefreshStage.checking,
        canCancel: true,
      );
    });
    try {
      final result =
          widget.onScanLibrary == null
              ? await ref
                  .read(libraryRepositoryProvider)
                  .scanAllMusicLibrary(
                    rootPath,
                    cancellation: cancellation,
                    onProgress: _setScanProgress,
                  )
              : await widget.onScanLibrary!(
                rootPath,
                cancellation: cancellation,
                onProgress: _setScanProgress,
              );
      ref.invalidate(libraryViewDataProvider);
      if (mounted) {
        _updateLocalPageState(() {
          _refreshResultDialog = (
            folder: createFolderNode('', rootPath),
            result: result,
          );
        });
      }
    } on LocalFolderScanCanceledException {
      _clearScanOverlay();
    } finally {
      if (mounted) {
        _updateLocalPageState(() {
          _rootScanRunning = false;
          _scanCancellation = null;
          _refreshProgress = null;
          _localOperationTitle = null;
        });
      }
    }
  }

  void _setScanProgress(LocalFolderRefreshProgress progress) {
    if (!mounted) {
      return;
    }
    _updateLocalPageState(() {
      _refreshProgress = progress;
    });
  }

  Future<void> _requestCancelScan(SmPlayerI18n i18n) async {
    final cancellation = _scanCancellation;
    if (cancellation == null) {
      return;
    }
    final confirmed = await showSmPlayerConfirmDialog(
      context: context,
      i18n: i18n,
      title: i18n.t('local.updateFolderProgressStopConfirmTitle'),
      message: i18n.t('local.updateFolderProgressStopConfirmMessage'),
      confirmText: i18n.t('local.updateFolderProgressStopConfirm'),
    );
    if (confirmed) {
      cancellation.cancel();
    }
  }

  void _clearScanOverlay() {
    if (!mounted) {
      return;
    }
    _updateLocalPageState(() {
      _refreshProgress = null;
      _localOperationTitle = null;
      _scanCancellation = null;
    });
  }
}
