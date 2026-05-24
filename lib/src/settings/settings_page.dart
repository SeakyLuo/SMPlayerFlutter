import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:smplayer_flutter/src/app/app_version.dart';
import 'package:smplayer_flutter/src/app/input_dialog.dart';
import 'package:smplayer_flutter/src/app/shell_colors.dart';
import 'package:smplayer_flutter/src/app/text_icon_button.dart';
import 'package:smplayer_flutter/src/app/undoable_notification.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_repository.dart';
import 'package:smplayer_flutter/src/library/ui/folder_update_result_dialog.dart';
import 'package:smplayer_flutter/src/library/ui/local_folder_model.dart';
import 'package:smplayer_flutter/src/library/ui/scan_progress_overlay.dart';
import 'package:smplayer_flutter/src/library/ui/remove_dialog.dart';
import 'package:smplayer_flutter/src/settings/artist_split_review_dialog.dart';
import 'package:smplayer_flutter/src/settings/lyrics_batch_details_dialog.dart';
import 'package:smplayer_flutter/src/settings/release_notes_dialog.dart';
import 'package:smplayer_flutter/src/settings/settings_colors.dart';
import 'package:smplayer_flutter/src/settings/settings_dialog_shell.dart';
import 'package:smplayer_flutter/src/platform/desktop_features.dart';
import 'package:smplayer_flutter/src/settings/settings_controller.dart';
import 'package:smplayer_flutter/src/settings/settings_formatters.dart';
import 'package:smplayer_flutter/src/settings/settings_model.dart';

part 'settings_page_sections.dart';

typedef SettingsScanLibraryCallback =
    FutureOr<LocalFolderRefreshResult?> Function(
      String rootPath, {
      LocalFolderScanCancellation? cancellation,
      void Function(LocalFolderRefreshProgress progress)? onProgress,
    });
typedef SettingsPickColorCallback = FutureOr<String?> Function(String value);

final _sharedLyricsBatchState = _SharedLyricsBatchState();
Widget _settingsNoTextScaling(BuildContext context, Widget child) {
  return MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
    child: child,
  );
}

class _SharedLyricsBatchState extends ChangeNotifier {
  var showOptions = false;
  var overwrite = false;
  var running = false;
  var cancelRequested = false;
  var stopped = false;
  var paused = false;
  var showDetails = false;
  LyricsBatchProgress? progress;
  LyricsBatchResult? result;

  void update(VoidCallback change) {
    change();
    scheduleMicrotask(notifyListeners);
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    this.initialSnapshot = const SettingsSnapshot.defaults(),
    this.loading = false,
    this.scanning = false,
    this.error,
    this.onPickLibraryRoot,
    this.onScanLibrary,
    this.librarySongs = const [],
    this.onRequestSmartArtistFix,
    this.onImportData,
    this.onDataImported,
    this.onExportData,
    this.onRevealSystemLogs,
    this.onSendFeedbackEmail,
    this.onOpenFeedbackInBrowser,
    this.onLoadSystemFonts,
    this.onPickColor,
    this.appVersion,
    this.initialFragment = '',
    this.lyricsBatchSongCount,
    this.onUpdateSettings,
    this.controller,
    this.libraryRepository = const LibraryRepository(),
  });

  final SettingsSnapshot initialSnapshot;
  final SettingsController? controller;
  final LibraryRepository libraryRepository;
  final bool loading;
  final bool scanning;
  final String? error;
  final FutureOr<String?> Function()? onPickLibraryRoot;
  final SettingsScanLibraryCallback? onScanLibrary;
  final List<LibrarySong> librarySongs;
  final VoidCallback? onRequestSmartArtistFix;
  final FutureOr<bool> Function()? onImportData;
  final FutureOr<void> Function()? onDataImported;
  final FutureOr<bool> Function()? onExportData;
  final VoidCallback? onRevealSystemLogs;
  final VoidCallback? onSendFeedbackEmail;
  final VoidCallback? onOpenFeedbackInBrowser;
  final FutureOr<List<String>> Function()? onLoadSystemFonts;
  final SettingsPickColorCallback? onPickColor;
  final String? appVersion;
  final String initialFragment;
  final int? lyricsBatchSongCount;
  final ValueChanged<AppSettingsUpdate>? onUpdateSettings;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const _lyricsRequestModeOptions = [
    LyricsRequestMode.auto,
    LyricsRequestMode.internet,
    LyricsRequestMode.local,
    LyricsRequestMode.embedded,
  ];

  late final SettingsController _settingsController;
  late final bool _ownsSettingsController;
  final _scrollController = ScrollController();
  final _desktopLyricsKey = GlobalKey();
  var _showPreferenceSettings = false;
  var _showReleaseNotes = false;
  var _showFeedbackOptions = false;
  var _showImportDataDialog = false;
  var _showSmartArtistFixDialog = false;
  var _smartArtistFixRunning = false;
  var _smartArtistApplyRunning = false;
  ArtistSplitAnalysisResult? _artistSplitAnalysisResult;
  var _dataTransferState = DataTransferState.idle;
  var _scanRunning = false;
  var _pickingLibraryRoot = false;
  LocalFolderRefreshProgress? _scanProgress;
  ({FolderNode folder, LocalFolderRefreshResult result})? _scanResultDialog;
  LocalFolderScanCancellation? _scanCancellation;
  var _systemFonts = const <String>[];
  String? _appVersion;

  SettingsSnapshot get _snapshot => _settingsController.snapshot;
  bool get _isDataTransferBusy => _dataTransferState != DataTransferState.idle;
  bool get _isScanning => widget.scanning || _scanRunning;
  bool get _showLyricsBatchOptions => _sharedLyricsBatchState.showOptions;
  set _showLyricsBatchOptions(bool value) => _sharedLyricsBatchState.update(
    () => _sharedLyricsBatchState.showOptions = value,
  );
  bool get _lyricsBatchOverwrite => _sharedLyricsBatchState.overwrite;
  set _lyricsBatchOverwrite(bool value) => _sharedLyricsBatchState.update(
    () => _sharedLyricsBatchState.overwrite = value,
  );
  bool get _lyricsBatchRunning => _sharedLyricsBatchState.running;
  set _lyricsBatchRunning(bool value) => _sharedLyricsBatchState.update(
    () => _sharedLyricsBatchState.running = value,
  );
  bool get _lyricsBatchCancelRequested =>
      _sharedLyricsBatchState.cancelRequested;
  set _lyricsBatchCancelRequested(bool value) => _sharedLyricsBatchState.update(
    () => _sharedLyricsBatchState.cancelRequested = value,
  );
  bool get _lyricsBatchStopped => _sharedLyricsBatchState.stopped;
  set _lyricsBatchStopped(bool value) => _sharedLyricsBatchState.update(
    () => _sharedLyricsBatchState.stopped = value,
  );
  bool get _lyricsBatchPaused => _sharedLyricsBatchState.paused;
  set _lyricsBatchPaused(bool value) => _sharedLyricsBatchState.update(
    () => _sharedLyricsBatchState.paused = value,
  );
  bool get _showLyricsBatchDetails => _sharedLyricsBatchState.showDetails;
  set _showLyricsBatchDetails(bool value) => _sharedLyricsBatchState.update(
    () => _sharedLyricsBatchState.showDetails = value,
  );
  LyricsBatchProgress? get _lyricsBatchProgress =>
      _sharedLyricsBatchState.progress;
  set _lyricsBatchProgress(LyricsBatchProgress? value) =>
      _sharedLyricsBatchState.update(
        () => _sharedLyricsBatchState.progress = value,
      );
  LyricsBatchResult? get _lyricsBatchResult => _sharedLyricsBatchState.result;
  set _lyricsBatchResult(LyricsBatchResult? value) => _sharedLyricsBatchState
      .update(() => _sharedLyricsBatchState.result = value);

  void _scrollToInitialFragment() {
    if (widget.initialFragment != 'desktop-lyrics') {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _desktopLyricsKey.currentContext;
      if (!mounted || context == null) {
        return;
      }
      Scrollable.ensureVisible(
        context,
        alignment: 0.5,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void initState() {
    super.initState();
    _ownsSettingsController = widget.controller == null;
    _settingsController =
        widget.controller ??
        SettingsController(widget.initialSnapshot, widget.libraryRepository);
    _settingsController.addListener(_onSettingsChanged);
    _sharedLyricsBatchState.addListener(_onLyricsBatchStateChanged);
    if (_ownsSettingsController) {
      _settingsController.refresh();
    }
    _loadAppVersion();
    _loadSystemFonts();
    _scrollToInitialFragment();
  }

  @override
  void didUpdateWidget(covariant SettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialFragment != widget.initialFragment) {
      _scrollToInitialFragment();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _sharedLyricsBatchState.removeListener(_onLyricsBatchStateChanged);
    _settingsController.removeListener(_onSettingsChanged);
    if (_ownsSettingsController) {
      _settingsController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final colors = SettingsPageColors.of(context);

    return _settingsNoTextScaling(
      context,
      Material(
        color: ShellThemeColors.of(context).workspaceSolidSurface,
        child: Stack(
          children: [
            SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(18, 24, 18, 42),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.error != null)
                    _ErrorBanner(message: widget.error!),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final narrow = constraints.maxWidth < 720;
                      final columns = <Widget>[
                        _SettingsColumn(
                          children: _buildLeftColumn(context, i18n),
                        ),
                        _SettingsColumn(
                          children: _buildRightColumn(context, i18n),
                        ),
                      ];

                      if (narrow) {
                        return Column(
                          spacing: 16,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: columns,
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 10, child: columns[0]),
                          const SizedBox(width: 22),
                          Expanded(flex: 11, child: columns[1]),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 18),
                  if (_appVersion case final appVersion?)
                    Align(
                      alignment: Alignment.center,
                      child: Opacity(
                        opacity: 0.82,
                        child: Text(
                          '${i18n.t('app.shell')} $appVersion',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: colors.textMuted,
                            fontSize: 12,
                            height: 1.4,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (_dataTransferState != DataTransferState.idle)
              _SettingsProgressOverlay(state: _dataTransferState),
            if (_scanProgress case final progress?)
              ScanProgressOverlay(
                title: i18n.t('local.updateFolderProgressTitle'),
                progress: progress,
                onCancel:
                    progress.canCancel ? () => _requestCancelScan(i18n) : null,
              ),
            if (_scanResultDialog case final dialog?)
              FolderUpdateResultDialog(
                folder: dialog.folder,
                result: dialog.result,
                songs: widget.librarySongs,
                selectedTrackId: null,
                isPlaying: false,
                onPlay: (_) {},
                onClose: () {
                  setState(() {
                    _scanResultDialog = null;
                  });
                },
              ),
            if (_showPreferenceSettings)
              PreferenceSettingsPage(
                libraryRepository: widget.libraryRepository,
                onClose: () {
                  setState(() {
                    _showPreferenceSettings = false;
                  });
                },
              ),
            if (_showReleaseNotes)
              ReleaseNotesDialog(
                version: _appVersion,
                onClose: () {
                  setState(() {
                    _showReleaseNotes = false;
                  });
                },
              ),
            if (_showImportDataDialog)
              _ConfirmSettingsDialog(
                title: i18n.t('settings.importData'),
                message: i18n.t('settings.importDataConfirm'),
                onCancel: () {
                  setState(() {
                    _showImportDataDialog = false;
                  });
                },
                onConfirm: () {
                  unawaited(_importData());
                },
              ),
            if (_showSmartArtistFixDialog)
              _ConfirmSettingsDialog(
                title: i18n.t('settings.smartMultiArtistFix'),
                message: i18n.t('settings.smartMultiArtistFixMessage'),
                confirmText: i18n.t('settings.smartMultiArtistFixConfirm'),
                busy: _smartArtistFixRunning,
                onCancel: () {
                  if (_smartArtistFixRunning) {
                    return;
                  }
                  setState(() {
                    _showSmartArtistFixDialog = false;
                  });
                },
                onConfirm: () {
                  unawaited(_analyzeSmartArtistFix(i18n));
                },
              ),
            if (_artistSplitAnalysisResult case final result?)
              ArtistSplitReviewDialog(
                result: result,
                applying: _smartArtistApplyRunning,
                onCancel: () {
                  if (_smartArtistApplyRunning) {
                    return;
                  }
                  setState(() {
                    _artistSplitAnalysisResult = null;
                  });
                },
                onApply: (splits) {
                  unawaited(_applySmartArtistFix(splits, i18n));
                },
              ),
            if (_showLyricsBatchDetails && _lyricsBatchResult != null)
              LyricsBatchDetailsDialog(
                result: _lyricsBatchResult!,
                onClose: () {
                  setState(() {
                    _showLyricsBatchDetails = false;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadAppVersion() async {
    final providedVersion = widget.appVersion;
    if (providedVersion != null) {
      setState(() {
        _appVersion = providedVersion;
      });
      return;
    }

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (!mounted) {
        return;
      }
      setState(() {
        _appVersion = packageInfo.version;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _appVersion = smPlayerAppVersion;
      });
    }
  }

  Future<void> _loadSystemFonts() async {
    final loader = widget.onLoadSystemFonts ?? loadDesktopSystemFonts;
    final fonts = await loader();
    if (!mounted) {
      return;
    }
    setState(() {
      _systemFonts = fonts;
    });
  }

  List<SelectSettingOption<String>> _desktopLyricsFontOptions(
    SmPlayerI18n i18n,
  ) {
    final fontNames =
        _snapshot.desktopLyricsFontFamily == 'system' ||
                _systemFonts.contains(_snapshot.desktopLyricsFontFamily)
            ? _systemFonts
            : [_snapshot.desktopLyricsFontFamily, ..._systemFonts];
    return [
      SelectSettingOption(
        value: 'system',
        label: i18n.t('settings.desktopLyricsFontSystem'),
      ),
      for (final fontName in fontNames)
        SelectSettingOption(value: fontName, label: fontName),
    ];
  }

  Future<void> _pickLibraryRoot() async {
    if (_pickingLibraryRoot || _isScanning) {
      return;
    }
    final i18n = context.smPlayerI18n;
    setState(() {
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
                    defaultPath:
                        _snapshot.rootPath.isEmpty ? null : _snapshot.rootPath,
                  )
                  : await FilePicker.getDirectoryPath()
              : await widget.onPickLibraryRoot!();
    } finally {
      if (mounted) {
        setState(() {
          _pickingLibraryRoot = false;
        });
      }
    }
    if (selectedRootPath == null || selectedRootPath.isEmpty) {
      _showMessage(i18n.t('library.folderPickerUnavailable'));
      return;
    }

    await _scanLibraryRoot(selectedRootPath);
  }

  Future<void> _scanLibraryRoot(String rootPath) async {
    if (_isScanning) {
      return;
    }
    final cancellation = LocalFolderScanCancellation();
    setState(() {
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
        setState(() {
          _scanResultDialog =
              result == null
                  ? null
                  : (folder: createFolderNode('', rootPath), result: result);
        });
        _updateSettings(AppSettingsUpdate(rootPath: rootPath));
      }
    } on LocalFolderScanCanceledException {
      if (mounted) {
        setState(() {
          _scanProgress = null;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
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
    setState(() {
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

  Future<void> _exportData() async {
    final i18n = context.smPlayerI18n;
    setState(() {
      _dataTransferState = DataTransferState.openingExport;
    });

    try {
      final exported =
          widget.onExportData == null
              ? await _exportDataWithPicker(i18n)
              : await widget.onExportData!();
      if (exported && mounted) {
        _showMessage(i18n.t('settings.dataExported'));
      }
    } catch (_) {
      if (mounted) {
        _showMessage(i18n.t('settings.dataExportFailed'));
      }
    } finally {
      if (mounted) {
        setState(() {
          _dataTransferState = DataTransferState.idle;
        });
      }
    }
  }

  Future<void> _importData() async {
    final i18n = context.smPlayerI18n;
    setState(() {
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
        setState(() {
          _dataTransferState = DataTransferState.reloading;
        });
        _showMessage(i18n.t('settings.dataImported'));
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
        setState(() {
          _dataTransferState = DataTransferState.idle;
        });
      }
    }
  }

  void _requestSmartArtistFix() {
    if (widget.onRequestSmartArtistFix case final callback?) {
      callback();
      return;
    }

    setState(() {
      _showSmartArtistFixDialog = true;
    });
  }

  Future<void> _analyzeSmartArtistFix(SmPlayerI18n i18n) async {
    setState(() {
      _smartArtistFixRunning = true;
    });

    try {
      final result = await widget.libraryRepository.analyzeArtistSplits();
      if (!mounted) {
        return;
      }
      setState(() {
        _showSmartArtistFixDialog = false;
        _artistSplitAnalysisResult = result.hasSuggestions ? result : null;
      });
      if (!result.hasSuggestions) {
        _showMessage(i18n.t('common.saved'));
      }
    } catch (_) {
      if (mounted) {
        _showMessage(i18n.t('settings.smartMultiArtistFixPending'));
      }
    } finally {
      if (mounted) {
        setState(() {
          _smartArtistFixRunning = false;
        });
      }
    }
  }

  Future<void> _applySmartArtistFix(
    List<ArtistSplitResultItem> splits,
    SmPlayerI18n i18n,
  ) async {
    setState(() {
      _smartArtistApplyRunning = true;
    });

    try {
      await widget.libraryRepository.applyArtistSplits(splits);
      if (!mounted) {
        return;
      }
      setState(() {
        _artistSplitAnalysisResult = null;
      });
      _showMessage(i18n.t('common.saved'));
    } catch (_) {
      if (mounted) {
        _showMessage(i18n.t('settings.smartMultiArtistFixPending'));
      }
    } finally {
      if (mounted) {
        setState(() {
          _smartArtistApplyRunning = false;
        });
      }
    }
  }

  Future<void> _startLyricsBatch(SmPlayerI18n i18n) async {
    setState(() {
      _showLyricsBatchOptions = false;
      _lyricsBatchRunning = true;
      _lyricsBatchCancelRequested = false;
      _lyricsBatchStopped = false;
      _lyricsBatchPaused = false;
      _lyricsBatchProgress = null;
      _lyricsBatchResult = null;
    });

    try {
      final result = await widget.libraryRepository.batchAddInternetLyrics(
        overwrite: _lyricsBatchOverwrite,
        isCanceled: () => _lyricsBatchCancelRequested,
        waitIfPaused: _waitForLyricsBatchResume,
        onProgress: (progress) {
          _lyricsBatchProgress = progress;
          if (!mounted) return;
          setState(() {
            _lyricsBatchProgress = progress;
          });
        },
      );
      _lyricsBatchResult = result;
      _lyricsBatchStopped = _lyricsBatchCancelRequested;
      if (!mounted) return;
      setState(() {
        _lyricsBatchResult = result;
        _lyricsBatchStopped = _lyricsBatchCancelRequested;
      });
      final message =
          _lyricsBatchCancelRequested
              ? i18n.t('settings.lyricsBatchStopped')
              : i18n.t('settings.lyricsBatchDone');
      final backupSummary =
          _lyricsBatchOverwrite
              ? '，${i18n.t('settings.lyricsBatchBackedUp')} '
                  '${result.backedUp}（${formatSettingsBytes(result.backupBytes)}）'
              : '';
      _showMessage(
        '$message: ${i18n.t('settings.lyricsBatchSaved')} ${result.saved} · '
        '${i18n.t('settings.lyricsBatchOverwritten')} ${result.overwritten} · '
        '${i18n.t('settings.lyricsBatchSkipped')} ${result.skipped} · '
        '${i18n.t('settings.lyricsBatchMissing')} ${result.missing} · '
        '${i18n.t('settings.lyricsBatchFailed')} ${result.failed}'
        '$backupSummary',
      );
    } catch (_) {
      if (mounted) {
        _showMessage(i18n.t('settings.lyricsBatchFailed'));
      }
    } finally {
      _lyricsBatchRunning = false;
      _lyricsBatchCancelRequested = false;
      _lyricsBatchPaused = false;
      if (mounted) {
        setState(() {
          _lyricsBatchRunning = false;
          _lyricsBatchCancelRequested = false;
          _lyricsBatchPaused = false;
        });
      }
    }
  }

  String _lyricsBatchPrimaryLabel(SmPlayerI18n i18n) {
    if (_lyricsBatchCancelRequested) {
      return i18n.t('settings.batchAddLyrics');
    }
    if (_lyricsBatchRunning) {
      return _lyricsBatchPaused
          ? i18n.t('common.continue')
          : i18n.t('common.pause');
    }
    return i18n.t('settings.batchAddLyrics');
  }

  void _handleLyricsBatchPrimaryAction() {
    if (widget.lyricsBatchSongCount == null ||
        widget.lyricsBatchSongCount == 0 ||
        _lyricsBatchCancelRequested) {
      return;
    }
    if (_lyricsBatchRunning) {
      setState(() {
        _lyricsBatchPaused = !_lyricsBatchPaused;
      });
      return;
    }
    setState(() {
      _showLyricsBatchOptions = !_showLyricsBatchOptions;
    });
  }

  Future<void> _waitForLyricsBatchResume() async {
    while (_lyricsBatchPaused && !_lyricsBatchCancelRequested) {
      await Future<void>.delayed(const Duration(milliseconds: 180));
    }
  }

  void _updateSettings(AppSettingsUpdate update) {
    _settingsController.updateSettings(update);
    widget.onUpdateSettings?.call(update);
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
    return widget.libraryRepository.importDataFrom(sourcePath);
  }

  void _onSettingsChanged() {
    setState(() {});
  }

  void _onLyricsBatchStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _showMessage(String message) {
    showAppNotification(context: context, message: message);
  }
}

class ToggleSettingRow extends StatelessWidget {
  const ToggleSettingRow({
    super.key,
    required this.label,
    required this.checked,
    required this.onChange,
    this.hint,
  });

  final String label;
  final String? hint;
  final bool checked;
  final ValueChanged<bool> onChange;

  @override
  Widget build(BuildContext context) {
    final colors = SettingsPageColors.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 38),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          onChange(!checked);
        },
        child: Row(
          children: [
            _ElectronSwitch(value: checked, onChanged: onChange),
            const SizedBox(width: 14),
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: colors.textStrong,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (hint != null) ...[
                    const SizedBox(width: 8),
                    Tooltip(
                      message: hint!,
                      child: Icon(
                        FluentIcons.info_24_regular,
                        size: 16,
                        color: colors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ElectronSwitch extends StatelessWidget {
  const _ElectronSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = SettingsPageColors.of(context);
    return Semantics(
      checked: value,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          onChanged(!value);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          width: 48,
          height: 26,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: value ? colors.accent : colors.buttonSurface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: value ? Colors.transparent : const Color(0x52535e6a),
            ),
          ),
          child: Align(
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOutCubic,
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: value ? Colors.white : const Color(0xff767c83),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SelectSettingOption<T> {
  const SelectSettingOption({required this.value, required this.label});

  final T value;
  final String label;
}

class SelectSettingRow<T> extends StatelessWidget {
  const SelectSettingRow({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChange,
    this.searchable = false,
    this.searchPlaceholder,
    this.emptyLabel,
  });

  final String label;
  final T value;
  final List<SelectSettingOption<T>> options;
  final ValueChanged<T> onChange;
  final bool searchable;
  final String? searchPlaceholder;
  final String? emptyLabel;

  @override
  Widget build(BuildContext context) {
    return _InlineSelectSettingRow<T>(
      label: label,
      value: value,
      options: options,
      searchable: searchable,
      searchPlaceholder: searchPlaceholder,
      emptyLabel: emptyLabel,
      onChange: onChange,
    );
  }
}

class _InlineSelectSettingRow<T> extends StatefulWidget {
  const _InlineSelectSettingRow({
    required this.label,
    required this.value,
    required this.options,
    required this.searchable,
    required this.searchPlaceholder,
    required this.emptyLabel,
    required this.onChange,
  });

  final String label;
  final T value;
  final List<SelectSettingOption<T>> options;
  final bool searchable;
  final String? searchPlaceholder;
  final String? emptyLabel;
  final ValueChanged<T> onChange;

  @override
  State<_InlineSelectSettingRow<T>> createState() =>
      _InlineSelectSettingRowState<T>();
}

class _InlineSelectSettingRowState<T>
    extends State<_InlineSelectSettingRow<T>> {
  final _link = LayerLink();
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  BuildContext? _targetContext;
  OverlayEntry? _overlayEntry;
  var _open = false;
  var _openUpward = false;
  var _query = '';
  double? _dropdownMaxHeight;

  @override
  void dispose() {
    _removeOverlay();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = SettingsPageColors.of(context);
    final selectedOption = widget.options.firstWhere(
      (option) => option.value == widget.value,
    );
    return _SettingsRowFrame(
      label: widget.label,
      controlWidth: 210,
      child: CompositedTransformTarget(
        link: _link,
        child: Builder(
          builder: (targetContext) {
            _targetContext = targetContext;
            return SizedBox(
              height: 38,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  backgroundColor:
                      _open ? colors.selectOpenSurface : colors.inputSurface,
                  foregroundColor:
                      _open ? colors.accentStrong : colors.textStrong,
                  side: BorderSide(
                    color: _open ? colors.selectOpenBorder : colors.inputBorder,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                onPressed: _toggleOpen,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        selectedOption.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(
                      _open
                          ? FluentIcons.chevron_up_20_regular
                          : FluentIcons.chevron_down_20_regular,
                      size: 16,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _toggleOpen() {
    if (_open) {
      _close();
      return;
    }
    setState(() {
      _open = true;
    });
    _showOverlay();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _open) {
        _updateDropdownGeometry();
      }
    });
  }

  void _showOverlay() {
    _removeOverlay();
    _overlayEntry = OverlayEntry(builder: _buildOverlay);
    Overlay.of(context).insert(_overlayEntry!);
  }

  Widget _buildOverlay(BuildContext context) {
    final normalizedQuery = _query.toLowerCase();
    final visibleOptions =
        normalizedQuery.isEmpty
            ? widget.options
            : widget.options
                .where(
                  (option) =>
                      option.label.toLowerCase().contains(normalizedQuery),
                )
                .toList();
    return _settingsNoTextScaling(
      context,
      Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _close,
              child: const SizedBox.expand(),
            ),
          ),
          CompositedTransformFollower(
            link: _link,
            targetAnchor:
                _openUpward ? Alignment.topRight : Alignment.bottomRight,
            followerAnchor:
                _openUpward ? Alignment.bottomRight : Alignment.topRight,
            offset: Offset(0, _openUpward ? -6 : 6),
            child: SizedBox(
              width: _overlayWidth(),
              child: _SettingsSelectOptionsPanel<T>(
                options: visibleOptions,
                maxHeight: _dropdownMaxHeight,
                value: widget.value,
                searchable: widget.searchable,
                searchController: _searchController,
                searchFocusNode: _searchFocusNode,
                searchPlaceholder: widget.searchPlaceholder,
                emptyLabel: widget.emptyLabel,
                onSearchChanged: (value) {
                  setState(() {
                    _query = value;
                  });
                  _overlayEntry?.markNeedsBuild();
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && _open) {
                      _updateDropdownGeometry();
                    }
                  });
                },
                onSelected: (value) {
                  widget.onChange(value);
                  _close();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _close() {
    if (!_open && _overlayEntry == null) {
      return;
    }
    setState(() {
      _open = false;
      _query = '';
    });
    _searchController.clear();
    _removeOverlay();
  }

  double _overlayWidth() {
    final box = _targetBox();
    final triggerWidth = box?.size.width ?? 210;
    final contentWidth = widget.searchable ? 240.0 : 210.0;
    return math.min(320.0, math.max(triggerWidth, contentWidth));
  }

  void _updateDropdownGeometry() {
    final box = _targetBox();
    if (box == null) {
      return;
    }
    final position = box.localToGlobal(Offset.zero);
    final viewportHeight = MediaQuery.sizeOf(context).height;
    final bottomBoundary = math.max(0.0, viewportHeight - 128.0);
    final optionHeight = widget.searchable ? 48.0 : 0.0;
    final desiredHeight = math.max(
      120.0,
      math.min(320.0, optionHeight + (_visibleOptionCount() * 38.0) + 12.0),
    );
    final spaceBelow = math.max(
      0.0,
      bottomBoundary - position.dy - box.size.height - 8.0,
    );
    final spaceAbove = math.max(0.0, position.dy - 8.0);
    final nextOpenUpward =
        spaceBelow < desiredHeight && spaceAbove > spaceBelow;
    final availableSpace = nextOpenUpward ? spaceAbove : spaceBelow;
    final nextMaxHeight =
        availableSpace >= desiredHeight - 56.0
            ? desiredHeight
            : math.max(120.0, availableSpace);
    setState(() {
      _openUpward = nextOpenUpward;
      _dropdownMaxHeight = nextMaxHeight;
    });
    _overlayEntry?.markNeedsBuild();
  }

  int _visibleOptionCount() {
    final normalizedQuery = _query.toLowerCase();
    if (normalizedQuery.isEmpty) {
      return widget.options.length;
    }
    return widget.options
        .where((option) => option.label.toLowerCase().contains(normalizedQuery))
        .length;
  }

  RenderBox? _targetBox() {
    final targetContext = _targetContext;
    if (targetContext == null || !targetContext.mounted) {
      return null;
    }
    return targetContext.findRenderObject() as RenderBox?;
  }
}

class _SettingsSelectOptionsPanel<T> extends StatelessWidget {
  const _SettingsSelectOptionsPanel({
    required this.options,
    required this.maxHeight,
    required this.value,
    required this.searchable,
    required this.searchController,
    required this.searchFocusNode,
    required this.searchPlaceholder,
    required this.emptyLabel,
    required this.onSearchChanged,
    required this.onSelected,
  });

  final List<SelectSettingOption<T>> options;
  final double? maxHeight;
  final T value;
  final bool searchable;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final String? searchPlaceholder;
  final String? emptyLabel;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = SettingsPageColors.of(context);
    return Material(
      color: Colors.transparent,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: colors.dropdownSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colors.inputBorder),
          boxShadow: [
            BoxShadow(
              color: colors.dropdownShadow,
              offset: const Offset(0, 18),
              blurRadius: 44,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (searchable)
              Container(
                height: 46,
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                decoration: BoxDecoration(
                  color: colors.dropdownSurface,
                  border: Border(bottom: BorderSide(color: colors.cardBorder)),
                ),
                child: SizedBox(
                  height: 34,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 20,
                        child: Icon(
                          FluentIcons.search_20_regular,
                          color: colors.textMuted,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ClipRect(
                          child: SizedBox(
                            height: 18,
                            child: Stack(
                              alignment: Alignment.centerLeft,
                              children: [
                                if (searchController.text.isEmpty)
                                  IgnorePointer(
                                    child: Text(
                                      searchPlaceholder ?? '',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: colors.textMuted,
                                        fontSize: 13,
                                        height: 1,
                                      ),
                                    ),
                                  ),
                                EditableText(
                                  controller: searchController,
                                  focusNode: searchFocusNode,
                                  autofocus: true,
                                  maxLines: 1,
                                  cursorHeight: 15,
                                  cursorColor: colors.accent,
                                  backgroundCursorColor: Colors.transparent,
                                  selectionColor: colors.accentHover,
                                  style: TextStyle(
                                    color: colors.textStrong,
                                    fontSize: 13,
                                    height: 1,
                                  ),
                                  onChanged: onSearchChanged,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight ?? 260),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(6),
                child:
                    options.isEmpty
                        ? Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 12,
                          ),
                          child: Text(
                            emptyLabel ?? '',
                            style: TextStyle(
                              color: colors.textMuted,
                              fontSize: 13,
                            ),
                          ),
                        )
                        : Column(
                          mainAxisSize: MainAxisSize.min,
                          children:
                              options.indexed.map((entry) {
                                final index = entry.$1;
                                final option = entry.$2;
                                final selected = option.value == value;
                                return Padding(
                                  padding: EdgeInsets.only(
                                    bottom: index == options.length - 1 ? 0 : 4,
                                  ),
                                  child: _SettingsSelectOptionButton(
                                    selected: selected,
                                    label: option.label,
                                    onPressed: () {
                                      onSelected(option.value);
                                    },
                                  ),
                                );
                              }).toList(),
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSelectOptionButton extends StatelessWidget {
  const _SettingsSelectOptionButton({
    required this.selected,
    required this.label,
    required this.onPressed,
  });

  final bool selected;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = SettingsPageColors.of(context);
    final foreground = selected ? colors.accentStrong : colors.textStrong;
    return Tooltip(
      message: label,
      waitDuration: const Duration(milliseconds: 350),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(7),
          hoverColor: colors.accentHover,
          onTap: onPressed,
          child: Ink(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: selected ? colors.accentHover : Colors.transparent,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  child:
                      selected
                          ? Icon(
                            FluentIcons.checkmark_20_regular,
                            size: 16,
                            color: foreground,
                          )
                          : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: foreground, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TimeSettingRow extends StatelessWidget {
  const TimeSettingRow({
    super.key,
    required this.label,
    required this.startLabel,
    required this.endLabel,
    required this.startValue,
    required this.endValue,
    required this.onStartChange,
    required this.onEndChange,
  });

  final String label;
  final String startLabel;
  final String endLabel;
  final String startValue;
  final String endValue;
  final ValueChanged<String> onStartChange;
  final ValueChanged<String> onEndChange;

  @override
  Widget build(BuildContext context) {
    final colors = SettingsPageColors.of(context);
    return _SettingsRowFrame(
      label: label,
      controlWidth: 300,
      child: Row(
        children: [
          Text(startLabel, style: TextStyle(color: colors.textMuted)),
          const SizedBox(width: 8),
          Expanded(
            child: _TimePicker(value: startValue, onChange: onStartChange),
          ),
          const SizedBox(width: 12),
          Text(endLabel, style: TextStyle(color: colors.textMuted)),
          const SizedBox(width: 8),
          Expanded(child: _TimePicker(value: endValue, onChange: onEndChange)),
        ],
      ),
    );
  }
}

class RangeSettingRow extends StatelessWidget {
  const RangeSettingRow({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.valueLabel,
    required this.onChange,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final int step;
  final String valueLabel;
  final ValueChanged<int> onChange;

  @override
  Widget build(BuildContext context) {
    final colors = SettingsPageColors.of(context);
    return _SettingsRowFrame(
      label: label,
      controlWidth: 290,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                activeTrackColor: colors.accent,
                inactiveTrackColor: const Color(0x2e323e4e),
                thumbColor: colors.accent,
                overlayShape: SliderComponentShape.noOverlay,
                tickMarkShape: SliderTickMarkShape.noTickMark,
                showValueIndicator: ShowValueIndicator.never,
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 9,
                  elevation: 2,
                  pressedElevation: 3,
                ),
              ),
              child: SizedBox(
                height: 18,
                child: Slider(
                  value: value.toDouble(),
                  min: min.toDouble(),
                  max: max.toDouble(),
                  divisions: ((max - min) / step).round(),
                  onChanged: (nextValue) {
                    onChange(nextValue.round());
                  },
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 58,
            child: Text(
              valueLabel,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: colors.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ColorSettingRow extends StatefulWidget {
  const ColorSettingRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChange,
    this.onPickColor,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChange;
  final SettingsPickColorCallback? onPickColor;

  @override
  State<ColorSettingRow> createState() => _ColorSettingRowState();
}

class _ColorSettingRowState extends State<ColorSettingRow> {
  @override
  Widget build(BuildContext context) {
    final colors = SettingsPageColors.of(context);
    final normalized = widget.value.toUpperCase();
    return _SettingsRowFrame(
      label: widget.label,
      controlWidth: 112,
      keepInlineWhenNarrow: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: _pickColor,
        child: SizedBox(
          height: 34,
          width: 112,
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: _parseHexColor(widget.value),
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.inputBorder),
                  boxShadow: [
                    BoxShadow(
                      color: colors.colorSwatchInset,
                      blurStyle: BlurStyle.inner,
                      blurRadius: 0,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const SizedBox.square(dimension: 28),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 74,
                child: Text(
                  normalized,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  softWrap: false,
                  style: TextStyle(
                    color: colors.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickColor() async {
    final picked = await _pickNativeColor();
    if (picked == null) {
      return;
    }
    widget.onChange(picked);
  }

  Future<String?> _pickNativeColor() async {
    final picker = widget.onPickColor ?? pickDesktopColor;
    final picked = await picker(widget.value);
    if (picked == null) {
      return null;
    }
    return RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(picked)
        ? picked.toLowerCase()
        : null;
  }

  Color _parseHexColor(String value) {
    return Color(0xff000000 + int.parse(value.substring(1), radix: 16));
  }
}

class SettingsSectionCard extends StatelessWidget {
  const SettingsSectionCard({
    super.key,
    required this.title,
    this.id,
    this.headerAction,
    this.children,
  });

  final String title;
  final String? id;
  final Widget? headerAction;
  final List<Widget>? children;

  @override
  Widget build(BuildContext context) {
    final colors = SettingsPageColors.of(context);
    return Container(
      key: id == null ? null : ValueKey(id),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: BoxDecoration(
        color: colors.cardSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: colors.cardShadow,
            offset: const Offset(0, 18),
            blurRadius: 42,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: colors.textStrong,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (headerAction != null) headerAction!,
            ],
          ),
          if (children != null) ...[
            const SizedBox(height: 14),
            for (var index = 0; index < children!.length; index++) ...[
              children![index],
              if (index != children!.length - 1) const SizedBox(height: 12),
            ],
          ],
        ],
      ),
    );
  }
}

class SettingsCard extends SettingsSectionCard {
  const SettingsCard({
    super.key,
    required super.title,
    super.id,
    super.headerAction,
    super.children,
  });
}

class SettingsActionButton extends StatelessWidget {
  const SettingsActionButton({
    super.key,
    required this.child,
    this.icon,
    this.primary = false,
    this.compact = false,
    this.disabled = false,
    this.tooltip,
    this.onClick,
  });

  final Widget child;
  final IconData? icon;
  final bool primary;
  final bool compact;
  final bool disabled;
  final String? tooltip;
  final VoidCallback? onClick;

  @override
  Widget build(BuildContext context) {
    final label =
        tooltip ??
        switch (child) {
          Text(:final data?) => data,
          _ => '',
        };
    final button = _settingsNoTextScaling(
      context,
      SmPlayerTextIconButton(
        icon: icon,
        label: label,
        disabled: disabled,
        active: primary,
        minWidth: compact ? 0 : 0,
        height: 40,
        horizontalPadding: compact ? 12 : 14,
        iconSize: compact ? 16 : 18,
        onPressed: onClick,
        child: child,
      ),
    );
    return button;
  }
}

class SettingsButtonRow extends StatelessWidget {
  const SettingsButtonRow({
    super.key,
    required this.children,
    this.stretchSingle = false,
  });

  final List<Widget> children;
  final bool stretchSingle;

  @override
  Widget build(BuildContext context) {
    if (stretchSingle && children.length == 1) {
      return SizedBox(width: double.infinity, child: children.single);
    }
    return Wrap(spacing: 12, runSpacing: 12, children: children);
  }
}

class _LyricsBatchOptions extends StatelessWidget {
  const _LyricsBatchOptions({
    required this.overwrite,
    required this.onOverwriteChanged,
    required this.onStart,
    required this.onCancel,
  });

  final bool overwrite;
  final ValueChanged<bool> onOverwriteChanged;
  final VoidCallback onStart;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final colors = SettingsPageColors.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.progressPanelSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.progressPanelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            i18n.t('settings.lyricsBatchWriteStrategy'),
            style: TextStyle(
              color: colors.textStrong,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          ToggleSettingRow(
            label: i18n.t('settings.lyricsBatchOverwriteToggle'),
            checked: overwrite,
            onChange: onOverwriteChanged,
          ),
          Wrap(
            spacing: 10,
            children: [
              SettingsActionButton(
                primary: true,
                onClick: onStart,
                child: Text(i18n.t('common.start')),
              ),
              SettingsActionButton(
                onClick: onCancel,
                child: Text(i18n.t('common.cancel')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LyricsBatchProgressPanel extends StatelessWidget {
  const _LyricsBatchProgressPanel({
    required this.progress,
    required this.message,
  });

  final LyricsBatchProgress progress;
  final String message;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final colors = SettingsPageColors.of(context);
    final ratio =
        progress.total == 0 ? 0.0 : progress.currentIndex / progress.total;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.progressPanelSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.progressPanelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: colors.textStrong,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${progress.currentIndex}/${progress.total}',
                style: TextStyle(color: colors.textMuted, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 9),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 6,
              child: LinearProgressIndicator(
                value: ratio.clamp(0, 1).toDouble(),
                backgroundColor: colors.progressTrack,
                color: colors.accent,
              ),
            ),
          ),
          const SizedBox(height: 9),
          Text(
            progress.currentSongTitle.isEmpty
                ? i18n.t('settings.lyricsBatchNoCurrent')
                : progress.currentSongTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: colors.textStrong, fontSize: 13),
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 10,
            runSpacing: 4,
            children: [
              _LyricsBatchStat(
                '${i18n.t('settings.lyricsBatchSaved')} ${progress.saved}',
              ),
              _LyricsBatchStat(
                '${i18n.t('settings.lyricsBatchOverwritten')} ${progress.overwritten}',
              ),
              _LyricsBatchStat(
                '${i18n.t('settings.lyricsBatchSkipped')} ${progress.skipped}',
              ),
              _LyricsBatchStat(
                '${i18n.t('settings.lyricsBatchMissing')} ${progress.missing}',
              ),
              _LyricsBatchStat(
                '${i18n.t('settings.lyricsBatchFailed')} ${progress.failed}',
              ),
              _LyricsBatchStat(
                '${i18n.t('settings.lyricsBatchBackedUp')} ${progress.backedUp}（${formatSettingsBytes(progress.backupBytes)}）',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LyricsBatchStat extends StatelessWidget {
  const _LyricsBatchStat(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = SettingsPageColors.of(context);
    return Text(label, style: TextStyle(color: colors.textMuted, fontSize: 12));
  }
}

class PreferenceSettingsPage extends StatefulWidget {
  const PreferenceSettingsPage({
    super.key,
    required this.onClose,
    this.libraryRepository = const LibraryRepository(),
    this.initialSnapshot,
  });

  final VoidCallback onClose;
  final LibraryRepository libraryRepository;
  final PreferenceSettingsSnapshot? initialSnapshot;

  @override
  State<PreferenceSettingsPage> createState() => _PreferenceSettingsPageState();
}

class _PreferenceSettingsPageState extends State<PreferenceSettingsPage> {
  late PreferenceSettingsSnapshot _snapshot;
  final _expandedSections = <PreferenceSectionKey>{};
  var _loading = false;
  var _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _snapshot = widget.initialSnapshot ?? PreferenceSettingsSnapshot.defaults();
    if (widget.initialSnapshot == null) {
      _loading = true;
      unawaited(_loadPreferenceSnapshot());
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final colors = SettingsPageColors.of(context);

    return SettingsDialogOverlay(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact =
              constraints.maxWidth < 640 || constraints.maxHeight < 720;
          final width =
              compact
                  ? constraints.maxWidth
                  : math.min(1080.0, constraints.maxWidth - 48.0);
          final height =
              compact
                  ? constraints.maxHeight
                  : math.min(820.0, constraints.maxHeight - 48.0);
          return Container(
            width: math.max(0, width),
            height: math.max(0, height),
            margin: compact ? EdgeInsets.zero : const EdgeInsets.all(24),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: colors.dialogSurface,
              borderRadius: BorderRadius.circular(compact ? 0 : 18),
              border: compact ? null : Border.all(color: colors.cardBorder),
            ),
            child: Column(
              children: [
                SettingsDialogHeader(
                  title: i18n.t('settings.preferenceSettings'),
                  onClose: widget.onClose,
                ),
                Expanded(
                  child:
                      _loading
                          ? Center(child: Text(i18n.t('preferences.loading')))
                          : _loadFailed
                          ? Center(
                            child: Text(i18n.t('preferences.loadFailed')),
                          )
                          : SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(18, 6, 18, 20),
                            child: Column(
                              children: [
                                const _PreferenceInfo(),
                                PreferenceSection(
                                  title: i18n.t('preferences.songs'),
                                  section: PreferenceSectionKey.songs,
                                  limit: 100,
                                  enabled:
                                      _snapshot.enabled[PreferenceSectionKey
                                          .songs]!,
                                  items: _snapshot.songs,
                                  expanded: _expandedSections.contains(
                                    PreferenceSectionKey.songs,
                                  ),
                                  onToggleEnabled: _toggleEnabled,
                                  onToggleExpanded: _toggleExpanded,
                                  onUpdateItem: _updateItem,
                                  onRemoveItem: _removeItem,
                                  onClearInvalid: _clearInvalid,
                                ),
                                PreferenceSection(
                                  title: i18n.t('preferences.artists'),
                                  section: PreferenceSectionKey.artists,
                                  limit: 50,
                                  enabled:
                                      _snapshot.enabled[PreferenceSectionKey
                                          .artists]!,
                                  items: _snapshot.artists,
                                  expanded: _expandedSections.contains(
                                    PreferenceSectionKey.artists,
                                  ),
                                  onToggleEnabled: _toggleEnabled,
                                  onToggleExpanded: _toggleExpanded,
                                  onUpdateItem: _updateItem,
                                  onRemoveItem: _removeItem,
                                  onClearInvalid: _clearInvalid,
                                ),
                                PreferenceSection(
                                  title: i18n.t('preferences.albums'),
                                  section: PreferenceSectionKey.albums,
                                  limit: 50,
                                  enabled:
                                      _snapshot.enabled[PreferenceSectionKey
                                          .albums]!,
                                  items: _snapshot.albums,
                                  expanded: _expandedSections.contains(
                                    PreferenceSectionKey.albums,
                                  ),
                                  onToggleEnabled: _toggleEnabled,
                                  onToggleExpanded: _toggleExpanded,
                                  onUpdateItem: _updateItem,
                                  onRemoveItem: _removeItem,
                                  onClearInvalid: _clearInvalid,
                                ),
                                PreferenceSection(
                                  title: i18n.t('preferences.playlists'),
                                  section: PreferenceSectionKey.playlists,
                                  limit: 30,
                                  enabled:
                                      _snapshot.enabled[PreferenceSectionKey
                                          .playlists]!,
                                  items: _snapshot.playlists,
                                  expanded: _expandedSections.contains(
                                    PreferenceSectionKey.playlists,
                                  ),
                                  onToggleEnabled: _toggleEnabled,
                                  onToggleExpanded: _toggleExpanded,
                                  onUpdateItem: _updateItem,
                                  onRemoveItem: _removeItem,
                                  onClearInvalid: _clearInvalid,
                                ),
                                PreferenceSection(
                                  title: i18n.t('preferences.folders'),
                                  section: PreferenceSectionKey.folders,
                                  limit: 30,
                                  enabled:
                                      _snapshot.enabled[PreferenceSectionKey
                                          .folders]!,
                                  items: _snapshot.folders,
                                  expanded: _expandedSections.contains(
                                    PreferenceSectionKey.folders,
                                  ),
                                  onToggleEnabled: _toggleEnabled,
                                  onToggleExpanded: _toggleExpanded,
                                  onUpdateItem: _updateItem,
                                  onRemoveItem: _removeItem,
                                  onClearInvalid: _clearInvalid,
                                ),
                                _PreferenceOthersSection(
                                  items: _snapshot.others,
                                  onUpdateItem: _updateItem,
                                  onRemoveItem: _removeItem,
                                ),
                              ],
                            ),
                          ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _loadPreferenceSnapshot() async {
    try {
      final snapshot = await widget.libraryRepository.getPreferenceSettings();
      if (!mounted) {
        return;
      }
      setState(() {
        _snapshot = snapshot;
        _loading = false;
        _loadFailed = false;
      });
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  void _toggleEnabled(PreferenceSectionKey section, bool enabled) {
    setState(() {
      _snapshot = _snapshot.copyWith(
        enabled: {..._snapshot.enabled, section: enabled},
      );
    });
    unawaited(
      widget.libraryRepository.updatePreferenceSettings({section: enabled}),
    );
  }

  void _toggleExpanded(PreferenceSectionKey section) {
    setState(() {
      if (_expandedSections.contains(section)) {
        _expandedSections.remove(section);
      } else {
        _expandedSections.add(section);
      }
    });
  }

  void _updateItem(PreferenceItemSnapshot item, PreferenceItemSnapshot update) {
    setState(() {
      _snapshot = _snapshotWithUpdatedItems(
        _snapshot,
        _sectionForPreferenceType(item.type),
        (items) =>
            items
                .map(
                  (current) =>
                      _samePreferenceItem(current, item) ? update : current,
                )
                .toList(),
      );
    });
    unawaited(
      widget.libraryRepository.updatePreferenceItem(
        item.id,
        isEnabled: update.isEnabled,
        level: update.level,
      ),
    );
  }

  void _removeItem(PreferenceItemSnapshot item) {
    setState(() {
      _snapshot = _snapshotWithUpdatedItems(
        _snapshot,
        _sectionForPreferenceType(item.type),
        (items) =>
            items
                .where((current) => !_samePreferenceItem(current, item))
                .toList(),
      );
    });
    unawaited(widget.libraryRepository.removePreferenceItemById(item.id));
  }

  void _clearInvalid(PreferenceSectionKey section) {
    setState(() {
      _snapshot = _snapshotWithUpdatedItems(
        _snapshot,
        section,
        (items) => items.where((item) => item.isValid).toList(),
      );
    });
    unawaited(
      widget.libraryRepository.clearInvalidPreferenceItems(
        _preferenceEntityTypeForSection(section),
      ),
    );
  }
}

class PreferenceSection extends StatelessWidget {
  const PreferenceSection({
    super.key,
    required this.title,
    required this.section,
    required this.limit,
    required this.enabled,
    required this.items,
    required this.expanded,
    required this.onToggleEnabled,
    required this.onToggleExpanded,
    required this.onUpdateItem,
    required this.onRemoveItem,
    required this.onClearInvalid,
  });

  final String title;
  final PreferenceSectionKey section;
  final int limit;
  final bool enabled;
  final List<PreferenceItemSnapshot> items;
  final bool expanded;
  final void Function(PreferenceSectionKey section, bool enabled)
  onToggleEnabled;
  final ValueChanged<PreferenceSectionKey> onToggleExpanded;
  final void Function(
    PreferenceItemSnapshot item,
    PreferenceItemSnapshot update,
  )
  onUpdateItem;
  final ValueChanged<PreferenceItemSnapshot> onRemoveItem;
  final ValueChanged<PreferenceSectionKey> onClearInvalid;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final visibleItems = expanded ? items : items.take(5).toList();
    final hasInvalid = items.any((item) => !item.isValid);

    return _PreferenceSectionFrame(
      title: title,
      counter: '${items.length}/$limit',
      action: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PreferenceSwitch(
            checked: enabled,
            onChanged: (checked) {
              onToggleEnabled(section, checked);
            },
          ),
          if (items.length > 5)
            TextButton(
              onPressed: () {
                onToggleExpanded(section);
              },
              child: Text(
                expanded
                    ? i18n.t('preferences.collapse')
                    : i18n.t('preferences.expand'),
              ),
            ),
          if (hasInvalid)
            TextButton(
              onPressed: () {
                onClearInvalid(section);
              },
              child: Text(i18n.t('preferences.clearInvalid')),
            ),
        ],
      ),
      child:
          visibleItems.isEmpty
              ? const _PreferenceEmpty()
              : PreferenceItems(
                items: visibleItems,
                onUpdateItem: onUpdateItem,
                onRemoveItem: onRemoveItem,
              ),
    );
  }
}

class PreferenceItems extends StatelessWidget {
  const PreferenceItems({
    super.key,
    required this.items,
    required this.onUpdateItem,
    required this.onRemoveItem,
  });

  final List<PreferenceItemSnapshot> items;
  final void Function(
    PreferenceItemSnapshot item,
    PreferenceItemSnapshot update,
  )
  onUpdateItem;
  final ValueChanged<PreferenceItemSnapshot> onRemoveItem;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final colors = SettingsPageColors.of(context);

    return Column(
      children:
          items.map((item) {
            return Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: colors.cardBorder)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _preferenceItemName(i18n, item),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textStrong,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (!item.isValid)
                    Text(
                      i18n.t('preferences.invalid'),
                      style: const TextStyle(color: SettingsPageColors.danger),
                    ),
                  const SizedBox(width: 12),
                  if (item.canRemove)
                    IconButton(
                      tooltip: i18n.t('playlists.removeSelected'),
                      icon: const Icon(FluentIcons.dismiss_20_regular),
                      onPressed: () {
                        onRemoveItem(item);
                      },
                    )
                  else
                    const SizedBox(width: 40),
                  const SizedBox(width: 4),
                  _PreferenceSwitch(
                    checked: item.isEnabled,
                    onChanged: (checked) {
                      onUpdateItem(item, item.copyWith(isEnabled: checked));
                    },
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 150,
                    child: PreferenceLevelSelect(
                      value: item.level,
                      onChange: (level) {
                        onUpdateItem(item, item.copyWith(level: level));
                      },
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
    );
  }
}

class PreferenceLevelSelect extends StatefulWidget {
  const PreferenceLevelSelect({
    super.key,
    required this.value,
    required this.onChange,
  });

  final PreferenceLevel value;
  final ValueChanged<PreferenceLevel> onChange;

  @override
  State<PreferenceLevelSelect> createState() => _PreferenceLevelSelectState();
}

class _PreferenceLevelSelectState extends State<PreferenceLevelSelect> {
  static const _levels = PreferenceLevel.values;

  final _link = LayerLink();
  OverlayEntry? _overlayEntry;
  var _open = false;
  var _openUpward = false;

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final colors = SettingsPageColors.of(context);

    return CompositedTransformTarget(
      link: _link,
      child: SizedBox(
        height: 36,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            alignment: Alignment.centerLeft,
            backgroundColor:
                _open ? colors.selectOpenSurface : colors.inputSurface,
            foregroundColor: _open ? colors.accentStrong : colors.textStrong,
            side: BorderSide(
              color: _open ? colors.selectOpenBorder : colors.inputBorder,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(9),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10),
          ),
          onPressed: _toggleOpen,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _preferenceLevelLabel(i18n, widget.value),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(
                _open
                    ? FluentIcons.chevron_up_20_regular
                    : FluentIcons.chevron_down_20_regular,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleOpen() {
    if (_open) {
      _close();
      return;
    }
    setState(() {
      _open = true;
    });
    _showOverlay();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _open) {
        _updateDropdownGeometry();
      }
    });
  }

  void _showOverlay() {
    _removeOverlay();
    _overlayEntry = OverlayEntry(builder: _buildOverlay);
    Overlay.of(context).insert(_overlayEntry!);
  }

  Widget _buildOverlay(BuildContext context) {
    return _settingsNoTextScaling(
      context,
      Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _close,
              child: const SizedBox.expand(),
            ),
          ),
          CompositedTransformFollower(
            link: _link,
            targetAnchor:
                _openUpward ? Alignment.topRight : Alignment.bottomRight,
            followerAnchor:
                _openUpward ? Alignment.bottomRight : Alignment.topRight,
            offset: Offset(0, _openUpward ? -6 : 6),
            child: SizedBox(
              width: 170,
              child: _PreferenceLevelMenu(
                value: widget.value,
                levels: _levels,
                onSelected: (level) {
                  widget.onChange(level);
                  _close();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _close() {
    if (!_open && _overlayEntry == null) {
      return;
    }
    setState(() {
      _open = false;
    });
    _removeOverlay();
  }

  void _updateDropdownGeometry() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) {
      return;
    }
    final position = box.localToGlobal(Offset.zero);
    final viewportHeight = MediaQuery.sizeOf(context).height;
    final bottomBoundary = math.max(0.0, viewportHeight - 128.0);
    final desiredHeight = (_levels.length * 38.0) + 16.0;
    final spaceBelow = math.max(
      0.0,
      bottomBoundary - position.dy - box.size.height - 8.0,
    );
    final spaceAbove = math.max(0.0, position.dy - 8.0);
    final nextOpenUpward =
        spaceBelow < desiredHeight && spaceAbove > spaceBelow;
    if (_openUpward == nextOpenUpward) {
      return;
    }
    setState(() {
      _openUpward = nextOpenUpward;
    });
    _overlayEntry?.markNeedsBuild();
  }
}

class _PreferenceLevelMenu extends StatelessWidget {
  const _PreferenceLevelMenu({
    required this.value,
    required this.levels,
    required this.onSelected,
  });

  final PreferenceLevel value;
  final List<PreferenceLevel> levels;
  final ValueChanged<PreferenceLevel> onSelected;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final colors = SettingsPageColors.of(context);
    return Material(
      color: Colors.transparent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.dropdownSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colors.inputBorder),
          boxShadow: [
            BoxShadow(
              color: colors.dropdownShadow,
              offset: const Offset(0, 18),
              blurRadius: 44,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children:
                levels.map((level) {
                  final selected = level == value;
                  return TextButton(
                    style: TextButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      foregroundColor:
                          selected ? colors.accentStrong : colors.textStrong,
                      backgroundColor:
                          selected ? colors.accentHover : Colors.transparent,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      minimumSize: const Size.fromHeight(34),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onPressed: () {
                      onSelected(level);
                    },
                    child: Text(
                      _preferenceLevelLabel(i18n, level),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
          ),
        ),
      ),
    );
  }
}

enum DataTransferState {
  idle,
  openingImport,
  openingExport,
  importing,
  exporting,
  reloading,
}

String _nightModeLabel(SmPlayerI18n i18n, NightMode mode) {
  return switch (mode) {
    NightMode.system => i18n.t('settings.nightModeSystem'),
    NightMode.auto => i18n.t('settings.nightModeAuto'),
    NightMode.onMode => i18n.t('settings.nightModeOn'),
    NightMode.never => i18n.t('settings.nightModeNever'),
  };
}

String _notificationSendLabel(SmPlayerI18n i18n, NotificationSendMode mode) {
  return switch (mode) {
    NotificationSendMode.musicChanged => i18n.t(
      'settings.notificationSendMusicChanged',
    ),
    NotificationSendMode.never => i18n.t('settings.notificationSendNever'),
  };
}

String _lyricsRequestModeLabel(SmPlayerI18n i18n, LyricsRequestMode mode) {
  return switch (mode) {
    LyricsRequestMode.auto => i18n.t('song.lyrics.auto'),
    LyricsRequestMode.internet => i18n.t('settings.sourceInternet'),
    LyricsRequestMode.local => i18n.t('settings.sourceLocal'),
    LyricsRequestMode.embedded => i18n.t('settings.sourceEmbedded'),
  };
}

String _preferredLanguageLabel(SmPlayerI18n i18n, PreferredLanguage language) {
  return switch (language) {
    PreferredLanguage.system => i18n.t('settings.languageSystem'),
    PreferredLanguage.enUS => 'English',
    PreferredLanguage.zhCN => '简体中文',
    PreferredLanguage.fr => 'Français',
    PreferredLanguage.ru => 'Русский',
    PreferredLanguage.ja => '日本語',
    PreferredLanguage.de => 'Deutsch',
    PreferredLanguage.ptBR => 'Português (Brasil)',
    PreferredLanguage.es => 'Español',
    PreferredLanguage.it => 'Italiano',
    PreferredLanguage.zhHant => '繁體中文',
    PreferredLanguage.nl => 'Nederlands',
    PreferredLanguage.cs => 'Čeština',
    PreferredLanguage.uk => 'Українська',
    PreferredLanguage.sv => 'Svenska',
    PreferredLanguage.id => 'Bahasa Indonesia',
  };
}

String _preferenceLevelLabel(SmPlayerI18n i18n, PreferenceLevel level) {
  return switch (level) {
    PreferenceLevel.veryHigh => i18n.t('preferences.level.very-high'),
    PreferenceLevel.higher => i18n.t('preferences.level.higher'),
    PreferenceLevel.high => i18n.t('preferences.level.high'),
    PreferenceLevel.normal => i18n.t('preferences.level.normal'),
    PreferenceLevel.dislike => i18n.t('preferences.level.dislike'),
    PreferenceLevel.doNotAppear => i18n.t('preferences.level.do-not-appear'),
  };
}

String _preferenceItemName(SmPlayerI18n i18n, PreferenceItemSnapshot item) {
  return switch (item.type) {
    PreferenceEntityType.recentAdded => i18n.t(
      'preferences.builtin.recent-added',
    ),
    PreferenceEntityType.myFavorites => i18n.t(
      'preferences.builtin.my-favorites',
    ),
    PreferenceEntityType.mostPlayed => i18n.t(
      'preferences.builtin.most-played',
    ),
    PreferenceEntityType.leastPlayed => i18n.t(
      'preferences.builtin.least-played',
    ),
    _ => item.name,
  };
}

PreferenceSectionKey? _sectionForPreferenceType(PreferenceEntityType type) {
  return switch (type) {
    PreferenceEntityType.song => PreferenceSectionKey.songs,
    PreferenceEntityType.artist => PreferenceSectionKey.artists,
    PreferenceEntityType.album => PreferenceSectionKey.albums,
    PreferenceEntityType.playlist => PreferenceSectionKey.playlists,
    PreferenceEntityType.folder => PreferenceSectionKey.folders,
    PreferenceEntityType.recentAdded ||
    PreferenceEntityType.myFavorites ||
    PreferenceEntityType.mostPlayed ||
    PreferenceEntityType.leastPlayed => null,
  };
}

PreferenceEntityType _preferenceEntityTypeForSection(
  PreferenceSectionKey section,
) {
  return switch (section) {
    PreferenceSectionKey.songs => PreferenceEntityType.song,
    PreferenceSectionKey.artists => PreferenceEntityType.artist,
    PreferenceSectionKey.albums => PreferenceEntityType.album,
    PreferenceSectionKey.playlists => PreferenceEntityType.playlist,
    PreferenceSectionKey.folders => PreferenceEntityType.folder,
  };
}

PreferenceSettingsSnapshot _snapshotWithUpdatedItems(
  PreferenceSettingsSnapshot snapshot,
  PreferenceSectionKey? section,
  List<PreferenceItemSnapshot> Function(List<PreferenceItemSnapshot> items)
  update,
) {
  return switch (section) {
    PreferenceSectionKey.songs => snapshot.copyWith(
      songs: update(snapshot.songs),
    ),
    PreferenceSectionKey.artists => snapshot.copyWith(
      artists: update(snapshot.artists),
    ),
    PreferenceSectionKey.albums => snapshot.copyWith(
      albums: update(snapshot.albums),
    ),
    PreferenceSectionKey.playlists => snapshot.copyWith(
      playlists: update(snapshot.playlists),
    ),
    PreferenceSectionKey.folders => snapshot.copyWith(
      folders: update(snapshot.folders),
    ),
    null => snapshot.copyWith(others: update(snapshot.others)),
  };
}

bool _samePreferenceItem(
  PreferenceItemSnapshot left,
  PreferenceItemSnapshot right,
) {
  if (left.id != 0 || right.id != 0) {
    return left.id == right.id;
  }
  return left.type == right.type && left.name == right.name;
}

class _SettingsColumn extends StatelessWidget {
  const _SettingsColumn({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 16,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

class _SettingsRowFrame extends StatelessWidget {
  const _SettingsRowFrame({
    required this.label,
    required this.child,
    this.controlWidth = 300,
    this.keepInlineWhenNarrow = false,
  });

  final String label;
  final Widget child;
  final double controlWidth;
  final bool keepInlineWhenNarrow;

  @override
  Widget build(BuildContext context) {
    final colors = SettingsPageColors.of(context);
    final labelWidget = Text(
      label,
      style: TextStyle(
        color: colors.textStrong,
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 38),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 430 && !keepInlineWhenNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                labelWidget,
                const SizedBox(height: 8),
                SizedBox(width: double.infinity, child: child),
              ],
            );
          }
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: labelWidget),
              const SizedBox(width: 18),
              SizedBox(
                width: controlWidth,
                child: Align(
                  alignment: Alignment.centerRight,
                  widthFactor: 1,
                  child: SizedBox(width: controlWidth, child: child),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TimePicker extends StatefulWidget {
  const _TimePicker({required this.value, required this.onChange});

  static final _hours = List.generate(
    24,
    (index) => index.toString().padLeft(2, '0'),
  );
  static final _minutes = List.generate(
    60,
    (index) => index.toString().padLeft(2, '0'),
  );

  final String value;
  final ValueChanged<String> onChange;

  @override
  State<_TimePicker> createState() => _TimePickerState();
}

class _TimePickerState extends State<_TimePicker> {
  final _link = LayerLink();
  OverlayEntry? _overlayEntry;
  var _open = false;
  var _openUpward = false;

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = SettingsPageColors.of(context);

    return CompositedTransformTarget(
      link: _link,
      child: SizedBox(
        width: 112,
        height: 38,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            alignment: Alignment.centerLeft,
            backgroundColor:
                _open ? colors.selectOpenSurface : colors.inputSurface,
            foregroundColor: _open ? colors.accentStrong : colors.textStrong,
            side: BorderSide(
              color: _open ? colors.selectOpenBorder : colors.inputBorder,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10),
          ),
          onPressed: _toggleOpen,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(FluentIcons.clock_20_regular, size: 15),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleOpen() {
    if (_open) {
      _close();
      return;
    }
    setState(() {
      _open = true;
    });
    _showOverlay();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _open) {
        _updateDropdownGeometry();
      }
    });
  }

  void _showOverlay() {
    _removeOverlay();
    _overlayEntry = OverlayEntry(builder: _buildOverlay);
    Overlay.of(context).insert(_overlayEntry!);
  }

  Widget _buildOverlay(BuildContext context) {
    final parts = widget.value.split(':');
    final hour = parts.first;
    final minute = parts.last;
    return _settingsNoTextScaling(
      context,
      Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _close,
              child: const SizedBox.expand(),
            ),
          ),
          CompositedTransformFollower(
            link: _link,
            targetAnchor:
                _openUpward ? Alignment.topRight : Alignment.bottomRight,
            followerAnchor:
                _openUpward ? Alignment.bottomRight : Alignment.topRight,
            offset: Offset(0, _openUpward ? -6 : 6),
            child: _TimePickerPanel(
              hour: hour,
              minute: minute,
              onHourSelected: (nextHour) {
                widget.onChange('$nextHour:$minute');
                _overlayEntry?.markNeedsBuild();
              },
              onMinuteSelected: (nextMinute) {
                widget.onChange('$hour:$nextMinute');
                _close();
              },
            ),
          ),
        ],
      ),
    );
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _close() {
    if (!_open && _overlayEntry == null) {
      return;
    }
    setState(() {
      _open = false;
    });
    _removeOverlay();
  }

  void _updateDropdownGeometry() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) {
      return;
    }
    final position = box.localToGlobal(Offset.zero);
    final viewportHeight = MediaQuery.sizeOf(context).height;
    final bottomBoundary = math.max(0.0, viewportHeight - 128.0);
    const desiredHeight = 236.0;
    final spaceBelow = math.max(
      0.0,
      bottomBoundary - position.dy - box.size.height - 8.0,
    );
    final spaceAbove = math.max(0.0, position.dy - 8.0);
    final nextOpenUpward =
        spaceBelow < desiredHeight && spaceAbove > spaceBelow;
    if (_openUpward == nextOpenUpward) {
      return;
    }
    setState(() {
      _openUpward = nextOpenUpward;
    });
    _overlayEntry?.markNeedsBuild();
  }
}

class _TimePickerPanel extends StatelessWidget {
  const _TimePickerPanel({
    required this.hour,
    required this.minute,
    required this.onHourSelected,
    required this.onMinuteSelected,
  });

  final String hour;
  final String minute;
  final ValueChanged<String> onHourSelected;
  final ValueChanged<String> onMinuteSelected;

  @override
  Widget build(BuildContext context) {
    final colors = SettingsPageColors.of(context);
    return Material(
      color: Colors.transparent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.dropdownSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colors.inputBorder),
          boxShadow: [
            BoxShadow(
              color: colors.dropdownShadow,
              offset: const Offset(0, 18),
              blurRadius: 44,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _TimePickerColumn(
                options: _TimePicker._hours,
                selectedValue: hour,
                onSelected: onHourSelected,
              ),
              const SizedBox(width: 6),
              _TimePickerColumn(
                options: _TimePicker._minutes,
                selectedValue: minute,
                onSelected: onMinuteSelected,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimePickerColumn extends StatefulWidget {
  const _TimePickerColumn({
    required this.options,
    required this.selectedValue,
    required this.onSelected,
  });

  final List<String> options;
  final String selectedValue;
  final ValueChanged<String> onSelected;

  @override
  State<_TimePickerColumn> createState() => _TimePickerColumnState();
}

class _TimePickerColumnState extends State<_TimePickerColumn> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController(
      initialScrollOffset: _initialScrollOffset(widget.selectedValue),
    );
  }

  @override
  void didUpdateWidget(covariant _TimePickerColumn oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedValue != widget.selectedValue) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) {
          return;
        }
        _scrollController.animateTo(
          _initialScrollOffset(widget.selectedValue),
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
        );
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = SettingsPageColors.of(context);
    return SizedBox(
      width: 58,
      height: 220,
      child: ListView(
        controller: _scrollController,
        padding: EdgeInsets.zero,
        children:
            widget.options.map((option) {
              final selected = option == widget.selectedValue;
              return TextButton(
                style: TextButton.styleFrom(
                  foregroundColor:
                      selected ? colors.accentStrong : colors.textStrong,
                  backgroundColor:
                      selected ? colors.accentHover : Colors.transparent,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size.fromHeight(32),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(7),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onPressed: () {
                  widget.onSelected(option);
                },
                child: Text(option),
              );
            }).toList(),
      ),
    );
  }

  double _initialScrollOffset(String value) {
    final index = widget.options.indexOf(value);
    if (index <= 0) {
      return 0;
    }
    return math.max(0, index * 32.0 - 94.0);
  }
}

class _SettingsIconButton extends StatelessWidget {
  const _SettingsIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.busy = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final colors = SettingsPageColors.of(context);
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        icon:
            busy
                ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                : Icon(icon),
        style: IconButton.styleFrom(
          backgroundColor: colors.buttonSurface,
          side: BorderSide(color: colors.inputBorder),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}

class _FeedbackActionButton extends StatefulWidget {
  const _FeedbackActionButton({
    required this.showOptions,
    required this.onToggle,
    required this.onDismiss,
    required this.onSelected,
  });

  final bool showOptions;
  final VoidCallback onToggle;
  final VoidCallback onDismiss;
  final ValueChanged<String> onSelected;

  @override
  State<_FeedbackActionButton> createState() => _FeedbackActionButtonState();
}

class _FeedbackActionButtonState extends State<_FeedbackActionButton> {
  final _link = LayerLink();
  OverlayEntry? _overlayEntry;

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _FeedbackActionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (widget.showOptions) {
        _showOverlay();
      } else {
        _removeOverlay();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;

    return CompositedTransformTarget(
      link: _link,
      child: SettingsActionButton(
        onClick: widget.onToggle,
        child: Text(i18n.t('settings.feedback')),
      ),
    );
  }

  void _showOverlay() {
    _removeOverlay();
    _overlayEntry = OverlayEntry(builder: _buildOverlay);
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Widget _buildOverlay(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final colors = SettingsPageColors.of(context);
    return _settingsNoTextScaling(
      context,
      Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: widget.onDismiss,
              child: const SizedBox.expand(),
            ),
          ),
          CompositedTransformFollower(
            link: _link,
            targetAnchor: Alignment.topLeft,
            followerAnchor: Alignment.bottomLeft,
            offset: const Offset(0, -6),
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 138,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: colors.dropdownSurface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colors.inputBorder),
                  boxShadow: [
                    BoxShadow(
                      color: colors.dropdownShadow,
                      offset: const Offset(0, 16),
                      blurRadius: 42,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _FeedbackOptionButton(
                      label: i18n.t('settings.viaEmail'),
                      onSelected: widget.onSelected,
                    ),
                    _FeedbackOptionButton(
                      label: i18n.t('settings.viaWebBrowser'),
                      onSelected: widget.onSelected,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedbackOptionButton extends StatelessWidget {
  const _FeedbackOptionButton({required this.label, required this.onSelected});

  final String label;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = SettingsPageColors.of(context);
    return TextButton(
      style: TextButton.styleFrom(
        minimumSize: const Size.fromHeight(34),
        alignment: Alignment.centerLeft,
        foregroundColor: colors.textStrong,
        backgroundColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        padding: const EdgeInsets.symmetric(horizontal: 10),
      ),
      onPressed: () {
        onSelected(label);
      },
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(label, style: const TextStyle(fontSize: 13)),
      ),
    );
  }
}

class _SettingsProgressOverlay extends StatelessWidget {
  const _SettingsProgressOverlay({required this.state});

  final DataTransferState state;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final colors = SettingsPageColors.of(context);
    final label = switch (state) {
      DataTransferState.openingImport => i18n.t('settings.openingImportData'),
      DataTransferState.openingExport => i18n.t('settings.openingExportData'),
      DataTransferState.importing => i18n.t('settings.importingData'),
      DataTransferState.exporting => i18n.t('settings.exportingData'),
      DataTransferState.reloading => i18n.t('settings.dataImported'),
      DataTransferState.idle => '',
    };

    return SettingsDialogOverlay(
      child: Container(
        width: 260,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: colors.dialogSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colors.cardBorder),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfirmSettingsDialog extends StatelessWidget {
  const _ConfirmSettingsDialog({
    required this.title,
    required this.message,
    required this.onCancel,
    required this.onConfirm,
    this.confirmText,
    this.busy = false,
  });

  final String title;
  final String message;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  final String? confirmText;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    return RemoveDialog(
      title: title,
      message: message,
      confirmText: confirmText,
      pendingText: i18n.t('settings.smartMultiArtistFixPending'),
      destructive: false,
      submitting: busy,
      onCancel: onCancel,
      onConfirm: onConfirm,
    );
  }
}

class _PreferenceInfo extends StatelessWidget {
  const _PreferenceInfo();

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final colors = SettingsPageColors.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 9,
            backgroundColor: Colors.transparent,
            child: Text('i', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              i18n.t('preferences.info'),
              style: TextStyle(color: colors.textMuted, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreferenceSectionFrame extends StatelessWidget {
  const _PreferenceSectionFrame({
    required this.title,
    required this.counter,
    required this.action,
    required this.child,
  });

  final String title;
  final String counter;
  final Widget action;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = SettingsPageColors.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.cardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.cardBorder),
      ),
      child: Column(
        children: [
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            color: colors.preferenceHeader,
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: colors.accentHover,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          counter,
                          style: const TextStyle(
                            color: SettingsPageColors.accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                action,
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _PreferenceOthersSection extends StatelessWidget {
  const _PreferenceOthersSection({
    required this.items,
    required this.onUpdateItem,
    required this.onRemoveItem,
  });

  final List<PreferenceItemSnapshot> items;
  final void Function(
    PreferenceItemSnapshot item,
    PreferenceItemSnapshot update,
  )
  onUpdateItem;
  final ValueChanged<PreferenceItemSnapshot> onRemoveItem;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;

    return _PreferenceSectionFrame(
      title: i18n.t('settings.others'),
      counter: '${items.length}',
      action: const SizedBox.shrink(),
      child: PreferenceItems(
        items: items,
        onUpdateItem: onUpdateItem,
        onRemoveItem: onRemoveItem,
      ),
    );
  }
}

class _PreferenceEmpty extends StatelessWidget {
  const _PreferenceEmpty();

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final colors = SettingsPageColors.of(context);

    return SizedBox(
      height: 44,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Text(
          i18n.t('preferences.noItems'),
          style: TextStyle(color: colors.textMuted),
        ),
      ),
    );
  }
}

class _PreferenceSwitch extends StatelessWidget {
  const _PreferenceSwitch({required this.checked, required this.onChanged});

  final bool checked;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Switch(
      value: checked,
      // ignore: deprecated_member_use
      activeColor: SettingsPageColors.accent,
      onChanged: onChanged,
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xffffebee),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xffffcdd2)),
      ),
      child: Text(
        message,
        style: const TextStyle(color: SettingsPageColors.danger),
      ),
    );
  }
}
