part of 'settings_page.dart';

extension _SettingsDataTransferActions on _SettingsPageState {
  Future<void> _exportData() async {
    final i18n = context.smPlayerI18n;
    _updateDataTransferState(() {
      _dataTransferState = DataTransferState.openingExport;
    });

    try {
      final exported =
          widget.onExportData == null
              ? await _exportDataWithPicker(i18n)
              : await _exportDataWithCallback();
      if (exported && mounted) {
        _showMessage(i18n.t('settings.dataExported'));
      }
    } catch (_) {
      if (mounted) {
        _showMessage(i18n.t('settings.dataExportFailed'));
      }
    } finally {
      if (mounted) {
        _updateDataTransferState(() {
          _dataTransferState = DataTransferState.idle;
        });
      }
    }
  }

  Future<bool> _exportDataWithCallback() async {
    _updateDataTransferState(() {
      _dataTransferState = DataTransferState.exporting;
    });
    return widget.onExportData!();
  }

  Future<void> _importData() async {
    final i18n = context.smPlayerI18n;
    _importedWithoutQueue = false;
    _updateDataTransferState(() {
      _showImportDataDialog = false;
      _dataTransferState = DataTransferState.openingImport;
    });

    try {
      final imported =
          widget.onImportData == null
              ? await _importDataWithPicker(i18n)
              : await widget.onImportData!();
      if (!mounted) {
        return;
      }
      if (imported) {
        _updateDataTransferState(() {
          _dataTransferState = DataTransferState.reloading;
        });
        _showMessage(
          _importedWithoutQueue
              ? '${i18n.t('settings.dataImported')} ${i18n.t('settings.importLegacyQueue')}'
              : i18n.t('settings.dataImported'),
        );
        await _settingsController.refresh();
        await widget.onDataImported?.call();
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
    } catch (_) {
      if (mounted) {
        _showMessage(i18n.t('settings.dataImportFailed'));
      }
    } finally {
      if (mounted) {
        _updateDataTransferState(() {
          _dataTransferState = DataTransferState.idle;
        });
      }
    }
  }

  Future<bool> _exportDataWithPicker(SmPlayerI18n i18n) async {
    final targetPath = await FilePicker.saveFile(
      dialogTitle: i18n.t('settings.exportData'),
      fileName: 'SMPlayerSettings.db',
      type: FileType.custom,
      allowedExtensions: const ['db'],
    );
    if (targetPath == null) {
      return false;
    }
    if (mounted) {
      _updateDataTransferState(() {
        _dataTransferState = DataTransferState.exporting;
      });
    }
    await _settingsController.waitForPendingPlaybackSettings();
    return widget.libraryRepository.exportDataTo(targetPath);
  }

  Future<bool> _importDataWithPicker(SmPlayerI18n i18n) async {
    final result = await FilePicker.pickFiles(
      dialogTitle: i18n.t('settings.importData'),
      type: FileType.custom,
      allowedExtensions: const ['db'],
      allowMultiple: false,
    );
    if (result == null) {
      return false;
    }
    final sourcePath = result.files.single.path;
    if (sourcePath == null) {
      return false;
    }
    final hasQueue = LibraryQueueBackup.read(File(sourcePath)) != null;
    await widget.onPrepareDataImport?.call();
    var imported = false;
    try {
      await _settingsController.suspendPersistenceForImport();
      imported = await widget.libraryRepository.importDataFrom(
        sourcePath,
        restoreNowPlaying: _restoreImportedQueue,
      );
      _importedWithoutQueue = imported && !hasQueue;
      return imported;
    } finally {
      if (!imported) _settingsController.resumePersistenceAfterImport();
    }
  }
}
