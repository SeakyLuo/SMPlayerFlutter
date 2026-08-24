import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:smplayer_flutter/src/app/input_dialog.dart';
import 'package:smplayer_flutter/src/app/shell_colors.dart';
import 'package:smplayer_flutter/src/app/smplayer_switch.dart';
import 'package:smplayer_flutter/src/app/text_icon_button.dart';
import 'package:smplayer_flutter/src/app/undoable_notification.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_repository.dart';
import 'package:smplayer_flutter/src/library/ui/folder_update_result_dialog.dart';
import 'package:smplayer_flutter/src/library/ui/local_folder_model.dart';
import 'package:smplayer_flutter/src/library/ui/popup_dialog.dart';
import 'package:smplayer_flutter/src/library/ui/scan_progress_overlay.dart';
import 'package:smplayer_flutter/src/library/ui/remove_dialog.dart';
import 'package:smplayer_flutter/src/settings/artist_split_review_dialog.dart';
import 'package:smplayer_flutter/src/settings/lyrics_batch_details_dialog.dart';
import 'package:smplayer_flutter/src/settings/release_notes_dialog.dart';
import 'package:smplayer_flutter/src/settings/settings_colors.dart';
import 'package:smplayer_flutter/src/settings/settings_dialog_shell.dart';
import 'package:smplayer_flutter/src/platform/desktop_feature_service.dart';
import 'package:smplayer_flutter/src/remote/ai_agent_remote_controller.dart';
import 'package:smplayer_flutter/src/settings/settings_controller.dart';
import 'package:smplayer_flutter/src/settings/settings_formatters.dart';
import 'package:smplayer_flutter/src/settings/settings_model.dart';

part 'settings_controls.dart';
part 'batch_add_lyrics_control.dart';
part 'preference_page.dart';
part 'settings_layout_parts.dart';
part 'preference_page_parts.dart';

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
    this.onArtistDataChanged,
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
  final FutureOr<void> Function()? onArtistDataChanged;
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
  var _updatingAiAgent = false;

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
    aiAgentRemoteController.addListener(_onAiAgentRemoteChanged);
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
    aiAgentRemoteController.removeListener(_onAiAgentRemoteChanged);
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
                onOpenSongMenu: (_, _) {},
                onApplyArtistSplits:
                    (splits) => _applyScanResultArtistSplits(splits, i18n),
                onDismissArtistSplitSuggestions:
                    _dismissScanResultArtistSplitSuggestions,
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
                artworkPathBySongId: {
                  for (final song in widget.librarySongs)
                    song.id: song.thumbnailPath,
                },
                onCancel: () {
                  if (_smartArtistApplyRunning) {
                    return;
                  }
                  setState(() {
                    _artistSplitAnalysisResult = null;
                  });
                },
                onApply: (splits) {
                  return _applySmartArtistFix(splits, i18n);
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
        _appVersion = null;
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
                    locale: i18n.locale,
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
        setState(() {
          _dataTransferState = DataTransferState.idle;
        });
      }
    }
  }

  Future<bool> _exportDataWithCallback() async {
    setState(() {
      _dataTransferState = DataTransferState.exporting;
    });
    return widget.onExportData!();
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
      await widget.onArtistDataChanged?.call();
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
      if (_lyricsBatchCancelRequested) {
        _lyricsBatchResult = null;
        _lyricsBatchProgress = null;
        if (mounted) {
          setState(() {
            _lyricsBatchResult = null;
            _lyricsBatchProgress = null;
          });
        }
        return;
      }
      _lyricsBatchResult = result;
      if (!mounted) return;
      setState(() {
        _lyricsBatchResult = result;
      });
      final message = i18n.t('settings.lyricsBatchDone');
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
        duration: const Duration(seconds: 5),
      );
    } catch (_) {
      if (mounted) {
        _showMessage(
          i18n.t('settings.lyricsBatchFailed'),
          duration: const Duration(seconds: 5),
        );
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

  Future<void> _requestCancelLyricsBatch(SmPlayerI18n i18n) async {
    final confirmed = await showSmPlayerConfirmDialog(
      context: context,
      i18n: i18n,
      title: i18n.t('settings.lyricsBatchCancelConfirmTitle'),
      message: i18n.t('settings.lyricsBatchCancelConfirmMessage'),
      confirmText: i18n.t('common.confirm'),
    );
    if (!mounted || !confirmed || !_lyricsBatchRunning) {
      return;
    }
    setState(() {
      _lyricsBatchCancelRequested = true;
      _lyricsBatchPaused = false;
      _lyricsBatchProgress = null;
      _lyricsBatchResult = null;
      _showLyricsBatchDetails = false;
    });
  }

  void _updateSettings(AppSettingsUpdate update) {
    _settingsController.updateSettings(update);
    widget.onUpdateSettings?.call(update);
  }

  void _onAiAgentRemoteChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _setAiAgentEnabled(bool enabled, SmPlayerI18n i18n) async {
    final previousSnapshot = _settingsController.snapshot;
    final update = AppSettingsUpdate(aiAgentEnabled: enabled);
    var updated = false;
    setState(() {
      _updatingAiAgent = true;
    });
    try {
      if (enabled) {
        await aiAgentRemoteController.start();
      } else {
        await aiAgentRemoteController.stop();
      }
      await _settingsController.updateSettings(update);
      updated = true;
    } on Object {
      _settingsController.restoreSnapshot(previousSnapshot);
      if (enabled) {
        await aiAgentRemoteController.stop();
      } else {
        await aiAgentRemoteController.start();
      }
      if (mounted) {
        _showMessage(i18n.t('settings.aiAgentUpdateFailed'));
      }
    } finally {
      if (mounted) {
        setState(() {
          _updatingAiAgent = false;
        });
      }
    }
    if (updated) {
      widget.onUpdateSettings?.call(update);
    }
  }

  Future<void> _copyAiAgentValue(String value, SmPlayerI18n i18n) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) {
      _showMessage(i18n.t('common.copied'));
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
      setState(() {
        _dataTransferState = DataTransferState.exporting;
      });
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

  Future<void> _applyScanResultArtistSplits(
    List<ArtistSplitResultItem> splits,
    SmPlayerI18n i18n,
  ) async {
    if (splits.isEmpty) {
      return;
    }

    await widget.libraryRepository.applyArtistSplits(splits);
    await widget.onArtistDataChanged?.call();
    if (!mounted) {
      return;
    }
    _showMessage(i18n.t('common.saved'));
    setState(() {
      final current = _scanResultDialog;
      if (current == null) {
        return;
      }
      final appliedSongIds = splits.map((split) => split.songId).toSet();
      _scanResultDialog = (
        folder: current.folder,
        result: LocalFolderRefreshResult(
          filesAdded: current.result.filesAdded,
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
    setState(() {
      final current = _scanResultDialog;
      if (current == null) {
        return;
      }
      _scanResultDialog = (
        folder: current.folder,
        result: LocalFolderRefreshResult(
          filesAdded: current.result.filesAdded,
          filesRemoved: current.result.filesRemoved,
          filesMoved: current.result.filesMoved,
          artistSplitsApplied: const [],
          artistSplitSuggestions: const [],
          artistMergeSuggestions: const [],
        ),
      );
    });
  }

  void _showMessage(String message, {Duration? duration}) {
    showAppNotification(
      context: context,
      message: message,
      duration: duration ?? appNotificationDuration,
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
