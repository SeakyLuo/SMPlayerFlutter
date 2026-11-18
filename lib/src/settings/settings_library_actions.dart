part of 'settings_page.dart';

extension _SettingsLibraryActions on _SettingsPageState {
  Future<void> _copyLibraryRoot() async {
    await Clipboard.setData(ClipboardData(text: _snapshot.rootPath));
    if (mounted) {
      _showMessage(context.smPlayerI18n.t('common.copied'));
    }
  }

  Future<void> _pickLibraryRoot() async {
    if (_pickingLibraryRoot || _isScanning) {
      return;
    }
    final i18n = context.smPlayerI18n;
    _updateSettingsPageState(() {
      _pickingLibraryRoot = true;
    });
    final String? selectedRootPath;
    try {
      selectedRootPath =
          widget.onPickLibraryRoot == null
              ? await pickMusicLibraryRoot(
                i18n,
                currentPath: _snapshot.rootPath,
              )
              : await widget.onPickLibraryRoot!();
    } on PlatformException {
      if (mounted) {
        _showMessage(i18n.t('library.folderPickerUnavailable'));
      }
      return;
    } finally {
      if (mounted) {
        _updateSettingsPageState(() {
          _pickingLibraryRoot = false;
        });
      }
    }
    if (selectedRootPath == null || selectedRootPath.isEmpty) {
      return;
    }

    await _scanLibraryRoot(selectedRootPath);
  }

  Future<void> _scanLibraryRoot(String rootPath) async {
    if (_isScanning) {
      return;
    }
    final cancellation = LocalFolderScanCancellation();
    _updateSettingsPageState(() {
      _scanRunning = true;
      _scanCancellation = cancellation;
      _scanProgress = const LocalFolderRefreshProgress(
        current: 0,
        total: 1,
        currentPath: '',
        stage: LocalFolderRefreshStage.checking,
        canCancel: true,
      );
    });
    try {
      final LocalFolderRefreshResult? result;
      if (widget.onScanLibrary == null) {
        result = await widget.libraryRepository.scanAllMusicLibrary(
          rootPath,
          cancellation: cancellation,
          onProgress: _setScanProgress,
        );
      } else {
        result = await widget.onScanLibrary!(
          rootPath,
          cancellation: cancellation,
          onProgress: _setScanProgress,
        );
      }
      if (mounted) {
        await finishLocalFolderRefreshProgress(
          progress: _scanProgress!,
          onProgress: _setScanProgress,
        );
      }
      if (mounted) {
        _updateSettingsPageState(() {
          _scanResultDialog =
              result == null
                  ? null
                  : (folder: createFolderNode('', rootPath), result: result);
        });
        _updateSettings(AppSettingsUpdate(rootPath: rootPath));
      }
    } on LocalFolderScanCanceledException {
      if (mounted) {
        _updateSettingsPageState(() {
          _scanProgress = null;
        });
      }
    } finally {
      if (mounted) {
        _updateSettingsPageState(() {
          _scanRunning = false;
          _scanCancellation = null;
          _scanProgress = null;
        });
      }
    }
  }

  void _setScanProgress(LocalFolderRefreshProgress progress) {
    if (!mounted) {
      return;
    }
    _updateSettingsPageState(() {
      _scanProgress = progress;
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

  void _requestSmartArtistFix() {
    if (widget.onRequestSmartArtistFix case final callback?) {
      callback();
      return;
    }

    _updateSettingsPageState(() {
      _showSmartArtistFixDialog = true;
    });
  }

  Future<void> _analyzeSmartArtistFix(SmPlayerI18n i18n) async {
    _updateSettingsPageState(() {
      _smartArtistFixRunning = true;
      _smartArtistFixProgress = 0;
    });

    try {
      final result = await widget.libraryRepository.analyzeArtistSplits(
        onProgress: (progress) {
          if (!mounted) {
            return;
          }
          _updateSettingsPageState(() {
            _smartArtistFixProgress = progress;
          });
        },
      );
      if (!mounted) {
        return;
      }
      _updateSettingsPageState(() {
        _showSmartArtistFixDialog = false;
        _artistSplitAnalysisResult = result.hasSuggestions ? result : null;
      });
      if (!result.hasSuggestions) {
        _showMessage(i18n.t('common.saved'));
      }
    } finally {
      if (mounted) {
        _updateSettingsPageState(() {
          _smartArtistFixRunning = false;
          _smartArtistFixProgress = null;
        });
      }
    }
  }

  Future<void> _applySmartArtistFix(
    List<ArtistSplitResultItem> splits,
    SmPlayerI18n i18n,
  ) async {
    _updateSettingsPageState(() {
      _smartArtistApplyRunning = true;
    });

    try {
      final sources = await widget.libraryRepository.applyArtistSplits(splits);
      await widget.onArtistDataChanged?.call(sources, splits);
      if (!mounted) {
        return;
      }
      _updateSettingsPageState(() {
        _artistSplitAnalysisResult = null;
      });
      _showMessage(i18n.t('common.saved'));
    } finally {
      if (mounted) {
        _updateSettingsPageState(() {
          _smartArtistApplyRunning = false;
        });
      }
    }
  }

  Future<void> _applyScanResultArtistSplits(
    List<ArtistSplitResultItem> splits,
    SmPlayerI18n i18n,
  ) async {
    if (splits.isEmpty) {
      return;
    }

    final sources = await widget.libraryRepository.applyArtistSplits(splits);
    await widget.onArtistDataChanged?.call(sources, splits);
    if (!mounted) {
      return;
    }
    _showMessage(i18n.t('common.saved'));
    _updateSettingsPageState(() {
      final current = _scanResultDialog;
      if (current == null) {
        return;
      }
      final appliedSongIds = splits.map((split) => split.songId).toSet();
      _scanResultDialog = (
        folder: current.folder,
        result: LocalFolderRefreshResult(
          libraryChanged: current.result.libraryChanged,
          requiresFullReload: current.result.requiresFullReload,
          filesAdded: current.result.filesAdded,
          filesUpdated: current.result.filesUpdated,
          filesRemoved: current.result.filesRemoved,
          filesMoved: current.result.filesMoved,
          artistSplitsApplied:
              current.result.artistSplitsApplied
                  .where((item) => !appliedSongIds.contains(item.songId))
                  .toList(),
          artistSplitSuggestions:
              current.result.artistSplitSuggestions
                  .where((item) => !appliedSongIds.contains(item.songId))
                  .toList(),
          artistMergeSuggestions:
              current.result.artistMergeSuggestions
                  .where((item) => !appliedSongIds.contains(item.songId))
                  .toList(),
        ),
      );
    });
  }

  void _dismissScanResultArtistSplitSuggestions() {
    _updateSettingsPageState(() {
      final current = _scanResultDialog;
      if (current == null) {
        return;
      }
      _scanResultDialog = (
        folder: current.folder,
        result: LocalFolderRefreshResult(
          libraryChanged: current.result.libraryChanged,
          requiresFullReload: current.result.requiresFullReload,
          filesAdded: current.result.filesAdded,
          filesUpdated: current.result.filesUpdated,
          filesRemoved: current.result.filesRemoved,
          filesMoved: current.result.filesMoved,
          artistSplitsApplied: const [],
          artistSplitSuggestions: const [],
          artistMergeSuggestions: const [],
        ),
      );
    });
  }
}
