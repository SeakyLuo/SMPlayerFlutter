part of 'local_page.dart';

extension _LocalPageScanActions on _LocalPageState {
  Future<void> _refreshFolder(FolderNode folder, SmPlayerI18n i18n) async {
    if (_refreshFolderRunning) {
      final activeFolder = _refreshingFolder!;
      if (activeFolder.path == folder.path) {
        _showRefreshFolderTask();
        return;
      }

      final activeCancellation = _scanCancellation!;
      final activeCompletion = _refreshFolderCompletion!.future;
      if (!activeCancellation.isCanceled) {
        if (!_refreshProgress!.canCancel) {
          _showRefreshFolderTask();
          return;
        }
        final confirmed = await showSmPlayerConfirmDialog(
          context: context,
          i18n: i18n,
          title: i18n.t('local.updateFolderConflictTitle'),
          message: i18n.t('local.updateFolderConflictMessage', {
            'current': activeFolder.name,
            'next': folder.name,
          }),
          confirmText: i18n.t('local.updateFolderConflictConfirm'),
          cancelText: i18n.t('local.updateFolderConflictViewCurrent'),
          cancelIsPrimary: true,
          onCancel: _showRefreshFolderTask,
        );
        if (!confirmed) {
          return;
        }
        activeCancellation.cancel();
      }
      await activeCompletion;
      if (!mounted) {
        return;
      }
    }
    if (_refreshProgress != null) {
      return;
    }

    await _runRefreshFolder(folder, i18n);
  }

  Future<void> _runRefreshFolder(FolderNode folder, SmPlayerI18n i18n) async {
    final previousSnapshot = ref.read(libraryContentDataProvider).value!;
    final cancellation = LocalFolderScanCancellation();
    final completion = Completer<void>();
    _updateLocalPageState(() {
      _refreshingFolder = folder;
      _refreshFolderCompletion = completion;
      _refreshFolderRunning = true;
      _refreshButtonProgressNotifier.value = 0;
      _refreshFolderBackgrounded = false;
      _refreshFolderCollapsing = false;
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
            onLibraryCommitted:
                () => _reloadCommittedLibrary(previousSnapshot, i18n),
          );
      if (!mounted) {
        return;
      }
      _updateLocalPageState(() {
        final showResultDialog = !_refreshFolderBackgrounded;
        _refreshProgress = null;
        _localOperationTitle = null;
        _scanCancellation = null;
        _refreshResultDialog =
            showResultDialog && hasRefreshResultChanges(result)
                ? (folder: folder, result: result)
                : null;
      });
      unawaited(
        showAppNotification(
          context: context,
          message: getRefreshResultMessage(result, i18n),
          autoDismiss: false,
          actionLabel:
              hasRefreshResultChanges(result) ? i18n.t('common.detail') : null,
          onAction:
              hasRefreshResultChanges(result)
                  ? () {
                    if (mounted) {
                      _updateLocalPageState(() {
                        _refreshResultDialog = (folder: folder, result: result);
                      });
                    }
                  }
                  : null,
        ),
      );
    } on LocalFolderScanCanceledException {
      _clearScanOverlay();
    } catch (error) {
      if (mounted) {
        _clearScanOverlay();
        final message = error is StateError ? error.message : error.toString();
        _showMessage(
          getRefreshFolderErrorMessage(message, i18n),
          autoDismiss: false,
        );
      }
    } finally {
      if (mounted) {
        _updateLocalPageState(() {
          _refreshFolderRunning = false;
          _refreshButtonProgressNotifier.value = null;
          _refreshFolderBackgrounded = false;
          _refreshFolderCollapsing = false;
          _refreshingFolder = null;
          _refreshFolderCompletion = null;
        });
      }
      completion.complete();
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
              ? (Platform.isMacOS || Platform.isWindows)
                  ? await pickDirectoryFromDesktopShell(
                    title: i18n.t('local.chooseMusicLibraryFolderDialogTitle'),
                    buttonLabel: i18n.t(
                      'local.chooseMusicLibraryFolderDialogButton',
                    ),
                    locale: i18n.locale,
                    defaultPath:
                        ref.read(libraryContentDataProvider).value!.rootPath,
                  )
                  : await FilePicker.getDirectoryPath()
              : await widget.onPickLibraryRoot!();
    } on PlatformException {
      if (mounted) {
        _showMessage(i18n.t('library.folderPickerUnavailable'));
      }
      return;
    } finally {
      if (mounted) {
        _updateLocalPageState(() {
          _pickingLibraryRoot = false;
        });
      }
    }
    if (selectedRootPath == null || selectedRootPath.isEmpty) {
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
                    onLibraryCommitted:
                        () => _reloadCommittedLibrary(previousSnapshot, i18n),
                  )
              : await widget.onScanLibrary!(
                rootPath,
                cancellation: cancellation,
                onProgress: _setScanProgress,
              );
      if (widget.onScanLibrary != null) {
        await _reloadCommittedLibrary(previousSnapshot, i18n);
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

  Future<void> _reloadCommittedLibrary(
    LibraryContentData previousSnapshot,
    SmPlayerI18n i18n,
  ) async {
    if (!mounted) return;
    ref.invalidate(libraryContentDataProvider);
    final nextSnapshot = await ref.read(libraryContentDataProvider.future);
    if (!mounted) return;
    await reconcileNowPlayingQueueWithLibrary(
      ref: ref,
      previousSnapshot: previousSnapshot,
      nextSnapshot: nextSnapshot,
      i18n: i18n,
    );
  }

  void _setScanProgress(LocalFolderRefreshProgress progress) {
    if (!mounted || _scanCancellation == null) {
      return;
    }
    final elapsedMs = _scanProgressClock.elapsedMilliseconds;
    final stageChanged = _refreshProgress?.stage != progress.stage;
    final stageCompleted = progress.current >= progress.total;
    if (!stageChanged &&
        !stageCompleted &&
        elapsedMs - _lastScanProgressUpdateMs < 100) {
      return;
    }
    _lastScanProgressUpdateMs = elapsedMs;
    if (_refreshFolderRunning) {
      _refreshButtonProgressNotifier.value = localFolderRefreshOverallProgress(
        progress,
      );
    }
    _refreshProgress = progress;
  }

  Widget _buildScanProgressOverlay(SmPlayerI18n i18n) {
    return ValueListenableBuilder<LocalFolderRefreshProgress?>(
      valueListenable: _scanProgressNotifier,
      builder: (context, progress, child) {
        if (progress == null) return const SizedBox.shrink();
        return ScanProgressOverlay(
          title: _localOperationTitle ?? i18n.t('local.updateFolder'),
          progress: progress,
          onCancel:
              progress.canCancel && !_scanCancellation!.isCanceled
                  ? () => _requestCancelScan(i18n)
                  : null,
          onRunInBackground:
              _refreshFolderRunning ? _runRefreshFolderInBackground : null,
          collapsing: _refreshFolderCollapsing,
          collapseAlignment: _refreshOverlayCollapseAlignment,
        );
      },
    );
  }

  void _showRefreshFolderTask() {
    if (!_refreshFolderBackgrounded && !_refreshFolderCollapsing) {
      return;
    }
    _updateLocalPageState(() {
      _refreshFolderBackgrounded = false;
      _refreshFolderCollapsing = false;
    });
  }

  void _runRefreshFolderInBackground() {
    _updateLocalPageState(() {
      _refreshOverlayCollapseAlignment = const Alignment(0.55, -0.82);
      _refreshFolderCollapsing = true;
    });
    Future<void>.delayed(const Duration(milliseconds: 240), () {
      if (!mounted || !_refreshFolderRunning) {
        return;
      }
      _updateLocalPageState(() {
        _refreshFolderBackgrounded = true;
        _refreshFolderCollapsing = false;
      });
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
