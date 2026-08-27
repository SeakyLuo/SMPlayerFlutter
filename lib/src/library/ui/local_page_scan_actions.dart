part of 'local_page.dart';

extension _LocalPageScanActions on _LocalPageState {
  Future<void> _refreshFolder(FolderNode folder, SmPlayerI18n i18n) async {
    if (_refreshProgress != null || _refreshFolderRunning) {
      return;
    }
    final previousSnapshot = ref.read(libraryContentDataProvider).value!;
    final cancellation = LocalFolderScanCancellation();
    _updateLocalPageState(() {
      _refreshFolderRunning = true;
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
      ref.invalidate(libraryContentDataProvider);
      final nextSnapshot = await ref.read(libraryContentDataProvider.future);
      await reconcileNowPlayingQueueWithLibrary(
        ref: ref,
        previousSnapshot: previousSnapshot,
        nextSnapshot: nextSnapshot,
        i18n: i18n,
      );
      if (!mounted) {
        return;
      }
      _updateLocalPageState(() {
        _refreshProgress = null;
        _localOperationTitle = null;
        _scanCancellation = null;
        _refreshResultDialog =
            hasRefreshResultChanges(result)
                ? (folder: folder, result: result)
                : null;
      });
      _showMessage(getRefreshResultMessage(result, i18n));
    } on LocalFolderScanCanceledException {
      _clearScanOverlay();
    } catch (error) {
      if (mounted) {
        _clearScanOverlay();
        final message = error is StateError ? error.message : error.toString();
        _showMessage(getRefreshFolderErrorMessage(message, i18n));
      }
    } finally {
      if (mounted) {
        _updateLocalPageState(() {
          _refreshFolderRunning = false;
        });
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
                    locale: i18n.locale,
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
    final previousSnapshot = ref.read(libraryContentDataProvider).value!;
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
      if (mounted) {
        ref.invalidate(libraryContentDataProvider);
        final nextSnapshot = await ref.read(libraryContentDataProvider.future);
        await reconcileNowPlayingQueueWithLibrary(
          ref: ref,
          previousSnapshot: previousSnapshot,
          nextSnapshot: nextSnapshot,
          i18n: i18n,
        );
      }
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
    if (!mounted || _scanCancellation == null) {
      return;
    }
    final elapsedMs = _scanProgressClock.elapsedMilliseconds;
    final stageChanged = _refreshProgress?.stage != progress.stage;
    if (!stageChanged && elapsedMs - _lastScanProgressUpdateMs < 100) {
      return;
    }
    _lastScanProgressUpdateMs = elapsedMs;
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
      _updateLocalPageState(() {
        _refreshProgress = null;
        _localOperationTitle = null;
        _scanCancellation = null;
      });
      cancellation.cancel();
    }
  }

  Future<void> _applyFolderUpdateArtistSplits(
    List<ArtistSplitResultItem> splits,
    SmPlayerI18n i18n,
  ) async {
    if (splits.isEmpty) {
      return;
    }

    await ref.read(libraryRepositoryProvider).applyArtistSplits(splits);
    ref.invalidate(libraryContentDataProvider);
    if (!mounted) {
      return;
    }
    _showMessage(i18n.t('common.saved'));
    _updateLocalPageState(() {
      final current = _refreshResultDialog;
      if (current == null) {
        return;
      }
      final splitSongIds = splits.map((split) => split.songId).toSet();
      final mergeSongIds =
          current.result.artistMergeSuggestions
              .map((item) => item.songId)
              .toSet();
      _refreshResultDialog = (
        folder: current.folder,
        result: LocalFolderRefreshResult(
          filesAdded: current.result.filesAdded,
          filesRemoved: current.result.filesRemoved,
          filesMoved: current.result.filesMoved,
          artistSplitsApplied: [
            ...current.result.artistSplitsApplied,
            ...splits.where((split) => !mergeSongIds.contains(split.songId)),
          ],
          artistSplitSuggestions:
              current.result.artistSplitSuggestions
                  .where((item) => !splitSongIds.contains(item.songId))
                  .toList(),
          artistMergeSuggestions:
              current.result.artistMergeSuggestions
                  .where((item) => !splitSongIds.contains(item.songId))
                  .toList(),
        ),
      );
    });
  }

  void _dismissFolderUpdateArtistSplitSuggestions() {
    _updateLocalPageState(() {
      final current = _refreshResultDialog;
      if (current == null) {
        return;
      }
      _refreshResultDialog = (
        folder: current.folder,
        result: LocalFolderRefreshResult(
          filesAdded: current.result.filesAdded,
          filesRemoved: current.result.filesRemoved,
          filesMoved: current.result.filesMoved,
          artistSplitsApplied: current.result.artistSplitsApplied,
          artistSplitSuggestions: const [],
          artistMergeSuggestions: const [],
        ),
      );
    });
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
