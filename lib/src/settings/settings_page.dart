import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:smplayer_flutter/src/app/app_version.dart';
import 'package:smplayer_flutter/src/app/input_dialog.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_repository.dart';
import 'package:smplayer_flutter/src/platform/desktop_features.dart';
import 'package:smplayer_flutter/src/settings/release_notes_model.dart';
import 'package:smplayer_flutter/src/settings/settings_controller.dart';
import 'package:smplayer_flutter/src/settings/settings_model.dart';

typedef SettingsScanLibraryCallback =
    FutureOr<void> Function(
      String rootPath, {
      LocalFolderScanCancellation? cancellation,
      void Function(LocalFolderRefreshProgress progress)? onProgress,
    });
typedef SettingsPickColorCallback = FutureOr<String?> Function(String value);

final _sharedLyricsBatchState = _SharedLyricsBatchState();
const _lyricsBatchDetailResultOrder = [
  LyricsBatchDetailResult.overwritten,
  LyricsBatchDetailResult.saved,
  LyricsBatchDetailResult.skipped,
  LyricsBatchDetailResult.missing,
  LyricsBatchDetailResult.failed,
];

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
  LocalFolderRefreshProgress? _scanProgress;
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
        color: Colors.transparent,
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
              _SettingsScanProgressOverlay(
                progress: progress,
                onCancel:
                    progress.canCancel ? () => _requestCancelScan(i18n) : null,
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
                onApply: () {
                  unawaited(_applySmartArtistFix(result, i18n));
                },
              ),
            if (_showLyricsBatchDetails && _lyricsBatchResult != null)
              _LyricsBatchDetailsDialog(
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

  List<Widget> _buildLeftColumn(BuildContext context, SmPlayerI18n i18n) {
    final colors = SettingsPageColors.of(context);
    return [
      SettingsCard(
        title: i18n.t('library.root'),
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  enabled: false,
                  controller: TextEditingController(text: _snapshot.rootPath),
                  decoration: InputDecoration(
                    hintText: i18n.t('settings.musicFolderPlaceholder'),
                    isDense: true,
                    filled: true,
                    fillColor: colors.inputSurface,
                    disabledBorder: OutlineInputBorder(
                      borderRadius: const BorderRadius.all(Radius.circular(8)),
                      borderSide: BorderSide(color: colors.inputBorder),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 52,
                height: 42,
                child: _SettingsIconButton(
                  icon: FluentIcons.folder_24_regular,
                  tooltip: i18n.t('common.folders'),
                  onPressed: () {
                    unawaited(_pickLibraryRoot());
                  },
                ),
              ),
            ],
          ),
          if (widget.loading)
            Text(
              i18n.t('library.refreshing'),
              style: TextStyle(color: colors.textMuted, fontSize: 13),
            ),
          ToggleSettingRow(
            label:
                _snapshot.useFilenameNotMusicName
                    ? i18n.t('settings.loadUsingFilename')
                    : i18n.t('settings.loadUsingMusicName'),
            checked: _snapshot.useFilenameNotMusicName,
            onChange: (checked) {
              _updateSettings(
                AppSettingsUpdate(useFilenameNotMusicName: checked),
              );
            },
          ),
          ToggleSettingRow(
            label: i18n.t('settings.smartMultiArtistRecognition'),
            hint: i18n.t('settings.smartMultiArtistRecognitionHint'),
            checked: _snapshot.smartMultiArtistRecognition,
            onChange: (checked) {
              _updateSettings(
                AppSettingsUpdate(smartMultiArtistRecognition: checked),
              );
            },
          ),
          if (_snapshot.smartMultiArtistRecognition)
            Align(
              alignment: Alignment.centerLeft,
              child: SettingsActionButton(
                icon: FluentIcons.people_24_regular,
                disabled: widget.loading || _isScanning,
                onClick: _requestSmartArtistFix,
                child: Text(i18n.t('settings.smartMultiArtistFix')),
              ),
            ),
        ],
      ),
      SettingsCard(
        title: i18n.t('settings.lyrics'),
        children: [
          SelectSettingRow<LyricsRequestMode>(
            label: i18n.t('settings.playerLyricsSource'),
            value: _snapshot.playerLyricsSource,
            options:
                _lyricsRequestModeOptions
                    .map(
                      (mode) => SelectSettingOption(
                        value: mode,
                        label: _lyricsRequestModeLabel(i18n, mode),
                      ),
                    )
                    .toList(),
            onChange: (value) {
              _updateSettings(AppSettingsUpdate(playerLyricsSource: value));
            },
          ),
          ToggleSettingRow(
            label: i18n.t('settings.autoLyrics'),
            checked: _snapshot.autoLyrics,
            onChange: (checked) {
              _updateSettings(AppSettingsUpdate(autoLyrics: checked));
            },
          ),
          ToggleSettingRow(
            label: i18n.t('settings.preserveLyricsTimestamps'),
            checked: _snapshot.preserveInternetLyricsTimestamps,
            onChange: (checked) {
              _updateSettings(
                AppSettingsUpdate(preserveInternetLyricsTimestamps: checked),
              );
            },
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SettingsActionButton(
                disabled:
                    _lyricsBatchCancelRequested ||
                    widget.lyricsBatchSongCount == null ||
                    widget.lyricsBatchSongCount == 0,
                onClick: _handleLyricsBatchPrimaryAction,
                child: Text(_lyricsBatchPrimaryLabel(i18n)),
              ),
              Tooltip(
                message: i18n.t('settings.batchAddLyricsCopy'),
                child: Icon(
                  FluentIcons.info_24_regular,
                  color: colors.textMuted,
                  size: 16,
                ),
              ),
              if (_lyricsBatchRunning)
                SettingsActionButton(
                  onClick: () {
                    setState(() {
                      _lyricsBatchCancelRequested = true;
                      _lyricsBatchPaused = false;
                    });
                  },
                  child: Text(i18n.t('common.cancel')),
                ),
              if (_lyricsBatchResult case final result?)
                if (result.details.isNotEmpty)
                  SettingsActionButton(
                    onClick: () {
                      setState(() {
                        _showLyricsBatchDetails = true;
                      });
                    },
                    child: Text(i18n.t('common.detail')),
                  ),
              if (!_lyricsBatchRunning && _lyricsBatchResult != null)
                SettingsActionButton(
                  onClick: () {
                    setState(() {
                      _lyricsBatchResult = null;
                      _lyricsBatchProgress = null;
                      _lyricsBatchStopped = false;
                      _showLyricsBatchDetails = false;
                    });
                  },
                  child: Text(i18n.t('common.clear')),
                ),
            ],
          ),
          if (_showLyricsBatchOptions)
            _LyricsBatchOptions(
              overwrite: _lyricsBatchOverwrite,
              onOverwriteChanged: (checked) {
                setState(() {
                  _lyricsBatchOverwrite = checked;
                });
              },
              onStart: () {
                unawaited(_startLyricsBatch(i18n));
              },
              onCancel: () {
                setState(() {
                  _showLyricsBatchOptions = false;
                });
              },
            ),
          if (_lyricsBatchProgress case final progress?)
            _LyricsBatchProgressPanel(
              progress: progress,
              message:
                  _lyricsBatchRunning
                      ? i18n.t('settings.lyricsBatchRequesting')
                      : _lyricsBatchStopped
                      ? i18n.t('settings.lyricsBatchStopped')
                      : i18n.t('settings.lyricsBatchDone'),
            ),
        ],
      ),
      SettingsCard(
        key: _desktopLyricsKey,
        id: 'desktop-lyrics',
        title: i18n.t('settings.desktopLyrics'),
        headerAction: _ElectronSwitch(
          value: _snapshot.desktopLyricsEnabled,
          onChanged: (checked) {
            _updateSettings(AppSettingsUpdate(desktopLyricsEnabled: checked));
          },
        ),
        children:
            _snapshot.desktopLyricsEnabled
                ? [
                  ColorSettingRow(
                    label: i18n.t('settings.desktopLyricsColor'),
                    value: _snapshot.desktopLyricsColor,
                    onPickColor: widget.onPickColor,
                    onChange: (value) {
                      _updateSettings(
                        AppSettingsUpdate(desktopLyricsColor: value),
                      );
                    },
                  ),
                  ToggleSettingRow(
                    label: i18n.t('settings.desktopLyricsStroke'),
                    checked: _snapshot.desktopLyricsStrokeColor.isNotEmpty,
                    onChange: (checked) {
                      _updateSettings(
                        AppSettingsUpdate(
                          desktopLyricsStrokeColor: checked ? '#111111' : '',
                        ),
                      );
                    },
                  ),
                  if (_snapshot.desktopLyricsStrokeColor.isNotEmpty)
                    ColorSettingRow(
                      label: i18n.t('settings.desktopLyricsStrokeColor'),
                      value: _snapshot.desktopLyricsStrokeColor,
                      onPickColor: widget.onPickColor,
                      onChange: (value) {
                        _updateSettings(
                          AppSettingsUpdate(desktopLyricsStrokeColor: value),
                        );
                      },
                    ),
                  SelectSettingRow<String>(
                    label: i18n.t('settings.desktopLyricsFontFamily'),
                    value: _snapshot.desktopLyricsFontFamily,
                    options: _desktopLyricsFontOptions(i18n),
                    searchable: true,
                    searchPlaceholder: i18n.t(
                      'settings.desktopLyricsFontSearch',
                    ),
                    emptyLabel: i18n.t('settings.desktopLyricsFontNoResults'),
                    onChange: (value) {
                      _updateSettings(
                        AppSettingsUpdate(desktopLyricsFontFamily: value),
                      );
                    },
                  ),
                  RangeSettingRow(
                    label: i18n.t('settings.desktopLyricsFontSize'),
                    min: 20,
                    max: 48,
                    step: 1,
                    value: _snapshot.desktopLyricsFontSize,
                    valueLabel: '${_snapshot.desktopLyricsFontSize}px',
                    onChange: (value) {
                      _updateSettings(
                        AppSettingsUpdate(desktopLyricsFontSize: value),
                      );
                    },
                  ),
                  RangeSettingRow(
                    label: i18n.t('settings.desktopLyricsOpacity'),
                    min: 45,
                    max: 100,
                    step: 1,
                    value: _snapshot.desktopLyricsOpacity,
                    valueLabel: '${_snapshot.desktopLyricsOpacity}%',
                    onChange: (value) {
                      _updateSettings(
                        AppSettingsUpdate(desktopLyricsOpacity: value),
                      );
                    },
                  ),
                  SettingsButtonRow(
                    children: [
                      SettingsActionButton(
                        icon: FluentIcons.arrow_undo_24_regular,
                        onClick: () {
                          _updateSettings(
                            const AppSettingsUpdate(
                              desktopLyricsColor: '#4aa8ff',
                              desktopLyricsStrokeColor: '#111111',
                              desktopLyricsFontSize: 28,
                              desktopLyricsFontFamily: 'system',
                              desktopLyricsOpacity: 88,
                            ),
                          );
                        },
                        child: Text(
                          i18n.t('settings.desktopLyricsRestoreDefaults'),
                        ),
                      ),
                    ],
                  ),
                ]
                : null,
      ),
    ];
  }

  List<Widget> _buildRightColumn(BuildContext context, SmPlayerI18n i18n) {
    return [
      SettingsCard(
        title: i18n.t('settings.display'),
        children: [
          SelectSettingRow<PreferredLanguage>(
            label: i18n.t('settings.interfaceLanguage'),
            value: _snapshot.preferredLanguage,
            options:
                PreferredLanguage.values
                    .map(
                      (language) => SelectSettingOption(
                        value: language,
                        label: _preferredLanguageLabel(i18n, language),
                      ),
                    )
                    .toList(),
            onChange: (value) {
              _updateSettings(AppSettingsUpdate(preferredLanguage: value));
            },
          ),
          SelectSettingRow<NightMode>(
            label: i18n.t('settings.nightMode'),
            value: _snapshot.nightMode,
            options:
                NightMode.values
                    .map(
                      (mode) => SelectSettingOption(
                        value: mode,
                        label: _nightModeLabel(i18n, mode),
                      ),
                    )
                    .toList(),
            onChange: (value) {
              _updateSettings(AppSettingsUpdate(nightMode: value));
            },
          ),
          if (_snapshot.nightMode == NightMode.auto)
            TimeSettingRow(
              label: i18n.t('settings.nightModeTimeRange'),
              startLabel: i18n.t('settings.nightModeStartTime'),
              endLabel: i18n.t('settings.nightModeEndTime'),
              startValue: _snapshot.nightModeStartTime,
              endValue: _snapshot.nightModeEndTime,
              onStartChange: (value) {
                _updateSettings(AppSettingsUpdate(nightModeStartTime: value));
              },
              onEndChange: (value) {
                _updateSettings(AppSettingsUpdate(nightModeEndTime: value));
              },
            ),
          ToggleSettingRow(
            label: i18n.t('settings.showCounts'),
            checked: _snapshot.showCount,
            onChange: (checked) {
              _updateSettings(AppSettingsUpdate(showCount: checked));
            },
          ),
          ToggleSettingRow(
            label: i18n.t('settings.hideMultiSelectCommandBar'),
            checked: _snapshot.hideMultiSelectCommandBarAfterOperation,
            onChange: (checked) {
              _updateSettings(
                AppSettingsUpdate(
                  hideMultiSelectCommandBarAfterOperation: checked,
                ),
              );
            },
          ),
        ],
      ),
      SettingsCard(
        title: i18n.t('settings.play'),
        children: [
          ToggleSettingRow(
            label: i18n.t('settings.autoPlay'),
            checked: _snapshot.autoPlay,
            onChange: (checked) {
              _updateSettings(AppSettingsUpdate(autoPlay: checked));
            },
          ),
          ToggleSettingRow(
            label: i18n.t('settings.shuffleAfterOneRound'),
            checked: _snapshot.shuffleAfterOneRound,
            onChange: (checked) {
              _updateSettings(AppSettingsUpdate(shuffleAfterOneRound: checked));
            },
          ),
          ToggleSettingRow(
            label: i18n.t('settings.saveProgress'),
            checked: _snapshot.saveMusicProgress,
            onChange: (checked) {
              _updateSettings(AppSettingsUpdate(saveMusicProgress: checked));
            },
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: SettingsActionButton(
              icon: FluentIcons.star_24_regular,
              onClick: () {
                setState(() {
                  _showPreferenceSettings = true;
                });
              },
              child: Text(i18n.t('settings.preferenceSettings')),
            ),
          ),
        ],
      ),
      SettingsCard(
        title: i18n.t('settings.notification'),
        children: [
          SelectSettingRow<NotificationSendMode>(
            label: i18n.t('settings.notificationSend'),
            value: _snapshot.notificationSend,
            options:
                NotificationSendMode.values
                    .map(
                      (mode) => SelectSettingOption(
                        value: mode,
                        label: _notificationSendLabel(i18n, mode),
                      ),
                    )
                    .toList(),
            onChange: (value) {
              _updateSettings(
                AppSettingsUpdate(
                  notificationSend: value,
                  showNotifications: value != NotificationSendMode.never,
                ),
              );
            },
          ),
        ],
      ),
      SettingsCard(
        title: i18n.t('settings.others'),
        children: [
          ToggleSettingRow(
            label: i18n.t('settings.quitOnClose'),
            checked: _snapshot.quitOnClose,
            onChange: (checked) {
              _updateSettings(AppSettingsUpdate(quitOnClose: checked));
            },
          ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              SettingsActionButton(
                onClick: () {
                  setState(() {
                    _showReleaseNotes = true;
                  });
                },
                child: Text(i18n.t('settings.releaseNotes')),
              ),
              SettingsActionButton(
                disabled: _isDataTransferBusy,
                tooltip: i18n.t('settings.importDataHint'),
                onClick: () {
                  setState(() {
                    _showImportDataDialog = true;
                  });
                },
                child: Text(i18n.t('settings.importData')),
              ),
              SettingsActionButton(
                disabled: _isDataTransferBusy,
                tooltip: i18n.t('settings.exportDataHint'),
                onClick: () {
                  unawaited(_exportData());
                },
                child: Text(i18n.t('settings.exportData')),
              ),
              _FeedbackActionButton(
                showOptions: _showFeedbackOptions,
                onToggle: () {
                  setState(() {
                    _showFeedbackOptions = !_showFeedbackOptions;
                  });
                },
                onDismiss: () {
                  setState(() {
                    _showFeedbackOptions = false;
                  });
                },
                onSelected: (label) {
                  setState(() {
                    _showFeedbackOptions = false;
                  });
                  if (label == i18n.t('settings.viaEmail')) {
                    widget.onSendFeedbackEmail?.call();
                  } else {
                    widget.onOpenFeedbackInBrowser?.call();
                  }
                },
              ),
              SettingsActionButton(
                onClick: () {
                  widget.onRevealSystemLogs?.call();
                },
                child: Text(i18n.t('settings.systemLog')),
              ),
            ],
          ),
        ],
      ),
    ];
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
    final selectedRootPath =
        widget.onPickLibraryRoot == null
            ? await FilePicker.getDirectoryPath()
            : await widget.onPickLibraryRoot!();
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
      if (widget.onScanLibrary == null) {
        await widget.libraryRepository.scanAllMusicLibrary(
          rootPath,
          cancellation: cancellation,
          onProgress: _setScanProgress,
        );
      } else {
        await widget.onScanLibrary!(
          rootPath,
          cancellation: cancellation,
          onProgress: _setScanProgress,
        );
      }
      if (mounted) {
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
    ArtistSplitAnalysisResult result,
    SmPlayerI18n i18n,
  ) async {
    setState(() {
      _smartArtistApplyRunning = true;
    });

    try {
      await widget.libraryRepository.applyArtistSplits(_splitItems(result));
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
                  '${result.backedUp}（${_formatBytes(result.backupBytes)}）'
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }
}

List<ArtistSplitResultItem> _splitItems(ArtistSplitAnalysisResult result) {
  return [
    ...result.directSplits,
    ...result.possibleSplits,
    ...result.mergeSuggestions,
  ];
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
          SizedBox(
            width: 220,
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

class SettingsCard extends StatelessWidget {
  const SettingsCard({
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
    final colors = SettingsPageColors.of(context);
    final foreground =
        disabled ? colors.textMuted : (primary ? Colors.white : colors.accent);
    final background =
        disabled
            ? Colors.transparent
            : (primary ? colors.accent : colors.buttonSurface);
    final borderColor = primary ? Colors.transparent : const Color(0x1f0e1927);
    final content = _settingsNoTextScaling(
      context,
      IconTheme(
        data: IconThemeData(color: foreground, size: compact ? 14 : 16),
        child: DefaultTextStyle.merge(
          style: TextStyle(
            color: foreground,
            fontSize: compact ? 12 : 13,
            fontWeight: compact ? FontWeight.w600 : FontWeight.w700,
            height: 1.0,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[Icon(icon), const SizedBox(width: 7)],
              Flexible(child: child),
            ],
          ),
        ),
      ),
    );
    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: disabled ? null : onClick,
        borderRadius: BorderRadius.circular(6),
        hoverColor: primary ? Colors.transparent : colors.accentHover,
        child: Ink(
          height: compact ? 32 : 36,
          padding: EdgeInsets.only(
            left: icon == null ? 14 : (compact ? 10 : 12),
            right: compact ? 12 : 14,
          ),
          decoration: BoxDecoration(
            color: background,
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(widthFactor: 1, child: content),
        ),
      ),
    );
    final tooltip = this.tooltip;
    if (tooltip == null || tooltip.isEmpty) {
      return button;
    }
    return Tooltip(message: tooltip, child: button);
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
              fontWeight: FontWeight.w800,
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
                '${i18n.t('settings.lyricsBatchBackedUp')} ${progress.backedUp}（${_formatBytes(progress.backupBytes)}）',
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

class _LyricsBatchDetailsDialog extends StatefulWidget {
  const _LyricsBatchDetailsDialog({
    required this.result,
    required this.onClose,
  });

  final LyricsBatchResult result;
  final VoidCallback onClose;

  @override
  State<_LyricsBatchDetailsDialog> createState() =>
      _LyricsBatchDetailsDialogState();
}

class _LyricsBatchDetailsDialogState extends State<_LyricsBatchDetailsDialog> {
  String? _selectedDetailId;
  final _collapsedResults = <LyricsBatchDetailResult>{};

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final colors = SettingsPageColors.of(context);
    final groups =
        _lyricsBatchDetailResultOrder
            .map(
              (result) => (
                result: result,
                details:
                    widget.result.details
                        .where((detail) => detail.result == result)
                        .toList(),
              ),
            )
            .where((group) => group.details.isNotEmpty)
            .toList();

    return _DialogOverlay(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = math.min(1180.0, constraints.maxWidth - 64.0);
          final height = math.min(860.0, constraints.maxHeight - 64.0);
          return Container(
            width: math.max(360.0, width),
            height: math.max(360.0, height),
            decoration: BoxDecoration(
              color: colors.dialogSurface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: colors.cardBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  offset: const Offset(0, 28),
                  blurRadius: 80,
                ),
              ],
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 10, 28, 0),
                  child: _DialogHeader(
                    title: i18n.t('settings.lyricsBatchTaskDetails'),
                    onClose: widget.onClose,
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(28, 18, 28, 28),
                    itemBuilder: (context, index) {
                      final group = groups[index];
                      final collapsed = _collapsedResults.contains(
                        group.result,
                      );
                      return _LyricsBatchDetailGroup(
                        result: group.result,
                        details: group.details,
                        collapsed: collapsed,
                        selectedDetailId: _selectedDetailId,
                        onToggleGroup: () {
                          setState(() {
                            if (collapsed) {
                              _collapsedResults.remove(group.result);
                            } else {
                              _collapsedResults.add(group.result);
                            }
                          });
                        },
                        onToggleDetail: (id) {
                          setState(() {
                            _selectedDetailId =
                                _selectedDetailId == id ? null : id;
                          });
                        },
                      );
                    },
                    separatorBuilder: (_, _) => const SizedBox(height: 18),
                    itemCount: groups.length,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LyricsBatchDetailGroup extends StatelessWidget {
  const _LyricsBatchDetailGroup({
    required this.result,
    required this.details,
    required this.collapsed,
    required this.selectedDetailId,
    required this.onToggleGroup,
    required this.onToggleDetail,
  });

  final LyricsBatchDetailResult result;
  final List<LyricsBatchDetail> details;
  final bool collapsed;
  final String? selectedDetailId;
  final VoidCallback onToggleGroup;
  final ValueChanged<String> onToggleDetail;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final colors = SettingsPageColors.of(context);
    return Column(
      children: [
        SizedBox(
          height: 36,
          child: Row(
            children: [
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: colors.textStrong,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: onToggleGroup,
                icon: Icon(
                  collapsed
                      ? FluentIcons.chevron_right_24_regular
                      : FluentIcons.chevron_down_24_regular,
                  size: 16,
                  color: colors.textMuted,
                ),
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _lyricsBatchResultLabel(i18n, result),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _LyricsBatchHeaderCountPill(
                      result: result,
                      count: details.length,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!collapsed)
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.cardSurface.withValues(alpha: 0.72),
                border: Border.all(color: colors.cardBorder),
              ),
              child: Column(
                children: [
                  for (var index = 0; index < details.length; index++) ...[
                    _LyricsBatchDetailTile(
                      detail: details[index],
                      expanded:
                          selectedDetailId ==
                          _lyricsBatchDetailId(details[index]),
                      onToggle:
                          () => onToggleDetail(
                            _lyricsBatchDetailId(details[index]),
                          ),
                    ),
                    if (index != details.length - 1)
                      Divider(height: 1, color: colors.cardBorder),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _LyricsBatchDetailTile extends StatelessWidget {
  const _LyricsBatchDetailTile({
    required this.detail,
    required this.expanded,
    required this.onToggle,
  });

  final LyricsBatchDetail detail;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final colors = SettingsPageColors.of(context);
    final reason = _lyricsBatchReasonLabel(i18n, detail.reason);
    return DecoratedBox(
      decoration: const BoxDecoration(),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  _LyricsBatchArtwork(thumbnailPath: detail.thumbnailPath),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          detail.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        if (detail.artist.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            detail.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _LyricsBatchStatusPill(
                        result: detail.result,
                        label: [
                          _lyricsBatchResultLabel(i18n, detail.result),
                          if (reason.isNotEmpty) '($reason)',
                        ].join(' '),
                      ),
                      const SizedBox(width: 10),
                      Icon(
                        expanded
                            ? FluentIcons.chevron_down_24_regular
                            : FluentIcons.chevron_right_24_regular,
                        size: 16,
                        color: colors.textMuted,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (expanded) _LyricsBatchExpandedDetail(detail: detail),
        ],
      ),
    );
  }
}

class _LyricsBatchArtwork extends StatelessWidget {
  const _LyricsBatchArtwork({required this.thumbnailPath});

  final String thumbnailPath;

  @override
  Widget build(BuildContext context) {
    final colors = SettingsPageColors.of(context);
    final image =
        thumbnailPath.isEmpty
            ? null
            : Image.file(
              File(thumbnailPath),
              width: 44,
              height: 44,
              fit: BoxFit.cover,
              errorBuilder:
                  (_, _, _) => Icon(
                    FluentIcons.music_note_2_24_regular,
                    size: 24,
                    color: colors.textMuted,
                  ),
            );
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: DecoratedBox(
        decoration: BoxDecoration(color: colors.inputSurface),
        child: SizedBox.square(
          dimension: 44,
          child:
              image ??
              Icon(
                FluentIcons.music_note_2_24_regular,
                size: 24,
                color: colors.textMuted,
              ),
        ),
      ),
    );
  }
}

class _LyricsBatchStatusPill extends StatelessWidget {
  const _LyricsBatchStatusPill({required this.result, required this.label});

  final LyricsBatchDetailResult result;
  final String label;

  @override
  Widget build(BuildContext context) {
    final statusColors = _lyricsBatchStatusColors(result);
    return Container(
      constraints: const BoxConstraints(minHeight: 28),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: statusColors.$1,
        borderRadius: BorderRadius.circular(999),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: statusColors.$2,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _LyricsBatchHeaderCountPill extends StatelessWidget {
  const _LyricsBatchHeaderCountPill({
    required this.result,
    required this.count,
  });

  final LyricsBatchDetailResult result;
  final int count;

  @override
  Widget build(BuildContext context) {
    final statusColors = _lyricsBatchStatusColors(result);
    return Container(
      constraints: const BoxConstraints(minWidth: 24, minHeight: 22),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: statusColors.$1,
        borderRadius: BorderRadius.circular(999),
      ),
      alignment: Alignment.center,
      child: Text(
        '$count',
        style: TextStyle(
          color: statusColors.$2,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

(Color, Color) _lyricsBatchStatusColors(LyricsBatchDetailResult result) {
  return switch (result) {
    LyricsBatchDetailResult.overwritten => (
      const Color(0xffffedd5),
      const Color(0xffc2410c),
    ),
    LyricsBatchDetailResult.saved => (
      const Color(0xffdcfce7),
      const Color(0xff15803d),
    ),
    LyricsBatchDetailResult.skipped => (
      const Color(0xfff1f5f9),
      const Color(0xff64748b),
    ),
    LyricsBatchDetailResult.missing || LyricsBatchDetailResult.failed => (
      const Color(0xfffee2e2),
      const Color(0xffb91c1c),
    ),
  };
}

class _LyricsBatchExpandedDetail extends StatelessWidget {
  const _LyricsBatchExpandedDetail({required this.detail});

  final LyricsBatchDetail detail;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final source = detail.sourceRawLyrics;
    final target = detail.targetRawLyrics;
    if (detail.result == LyricsBatchDetailResult.overwritten) {
      return _LyricsBatchOverwriteDetail(source: source, target: target);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: _LyricsTextPreview(
        title:
            target.trim().isNotEmpty
                ? i18n.t('settings.lyricsBatchDetailWrittenLyrics')
                : i18n.t('settings.lyricsBatchCurrentLyrics'),
        text: target.trim().isNotEmpty ? target : source,
      ),
    );
  }
}

class _LyricsBatchOverwriteDetail extends StatefulWidget {
  const _LyricsBatchOverwriteDetail({
    required this.source,
    required this.target,
  });

  final String source;
  final String target;

  @override
  State<_LyricsBatchOverwriteDetail> createState() =>
      _LyricsBatchOverwriteDetailState();
}

class _LyricsBatchOverwriteDetailState
    extends State<_LyricsBatchOverwriteDetail> {
  var _canceled = false;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final colors = SettingsPageColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.cardSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0x9efdbA74)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: const BoxDecoration(
                color: Color(0xfffff7ed),
                border: Border(bottom: BorderSide(color: Color(0x73fdba74))),
              ),
              child: Row(
                children: [
                  const Icon(
                    FluentIcons.info_24_regular,
                    size: 16,
                    color: Color(0xfff97316),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      i18n.t('settings.lyricsBatchOverwriteWarning'),
                      style: const TextStyle(
                        color: Color(0xff9a3412),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor:
                          _canceled
                              ? const Color(0xff2563eb)
                              : const Color(0xff334155),
                      backgroundColor:
                          _canceled
                              ? const Color(0xffeff6ff)
                              : const Color(0xe6ffffff),
                      side: BorderSide(
                        color:
                            _canceled
                                ? const Color(0xff93c5fd)
                                : const Color(0xffcbd5e1),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onPressed: () {
                      setState(() {
                        _canceled = !_canceled;
                      });
                    },
                    child: Text(
                      _canceled
                          ? i18n.t('settings.lyricsBatchAgainOverwrite')
                          : i18n.t('settings.lyricsBatchCancelOverwrite'),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _LyricsTextPreview(
                      title: i18n.t('settings.lyricsBatchCurrentLyrics'),
                      badge: i18n.t('settings.lyricsBatchOldVersion'),
                      text: widget.source,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 72),
                    child: CircleAvatar(
                      radius: 15,
                      backgroundColor: Color(0xffeff6ff),
                      child: Icon(
                        FluentIcons.arrow_right_20_regular,
                        size: 16,
                        color: Color(0xff2563eb),
                      ),
                    ),
                  ),
                  Expanded(
                    child: _LyricsTextPreview(
                      title: i18n.t('settings.lyricsBatchNewLyrics'),
                      badge: i18n.t('settings.lyricsBatchNewVersion'),
                      newBadge: true,
                      text: widget.target,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LyricsTextPreview extends StatelessWidget {
  const _LyricsTextPreview({
    required this.title,
    required this.text,
    this.badge,
    this.newBadge = false,
  });

  final String title;
  final String text;
  final String? badge;
  final bool newBadge;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final colors = SettingsPageColors.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 120),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.cardSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: TextStyle(
              color: colors.textStrong,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (badge case final badge?) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color:
                      newBadge
                          ? const Color(0xffdbeafe)
                          : const Color(0xffe2e8f0),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    color:
                        newBadge
                            ? const Color(0xff2563eb)
                            : const Color(0xff64748b),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            text.trim().isEmpty
                ? i18n.t('settings.lyricsBatchDetailNoLyrics')
                : text,
            maxLines: 10,
            overflow: TextOverflow.fade,
            style: TextStyle(color: colors.textStrong, height: 1.35),
          ),
        ],
      ),
    );
  }
}

String _lyricsBatchDetailId(LyricsBatchDetail detail) {
  return '${detail.songId}-${detail.result.index}-${detail.reason?.index ?? -1}';
}

String _lyricsBatchResultLabel(
  SmPlayerI18n i18n,
  LyricsBatchDetailResult result,
) {
  return switch (result) {
    LyricsBatchDetailResult.saved => i18n.t('settings.lyricsBatchSaved'),
    LyricsBatchDetailResult.overwritten => i18n.t(
      'settings.lyricsBatchOverwritten',
    ),
    LyricsBatchDetailResult.skipped => i18n.t('settings.lyricsBatchSkipped'),
    LyricsBatchDetailResult.missing => i18n.t('settings.lyricsBatchMissing'),
    LyricsBatchDetailResult.failed => i18n.t('settings.lyricsBatchFailed'),
  };
}

String _lyricsBatchReasonLabel(
  SmPlayerI18n i18n,
  LyricsBatchSkipReason? reason,
) {
  return switch (reason) {
    LyricsBatchSkipReason.alreadyExists => i18n.t(
      'settings.lyricsBatchReasonAlreadyExists',
    ),
    LyricsBatchSkipReason.sameContent => i18n.t(
      'settings.lyricsBatchReasonSameContent',
    ),
    null => '',
  };
}

String _formatBytes(int size) {
  if (size <= 0) {
    return '0 B';
  }
  if (size < 1024) {
    return '$size B';
  }
  if (size < 1024 * 1024) {
    return '${(size / 1024).toStringAsFixed(1)} KB';
  }
  return '${(size / (1024 * 1024)).toStringAsFixed(2)} MB';
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

    return _DialogOverlay(
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
                _DialogHeader(
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
  });

  final String label;
  final Widget child;
  final double controlWidth;

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
          if (constraints.maxWidth < 430) {
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
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = SettingsPageColors.of(context);
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon),
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

    return _DialogOverlay(
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

class _SettingsScanProgressOverlay extends StatelessWidget {
  const _SettingsScanProgressOverlay({
    required this.progress,
    required this.onCancel,
  });

  final LocalFolderRefreshProgress progress;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final colors = SettingsPageColors.of(context);
    final value = (progress.current / progress.total).clamp(0, 1).toDouble();
    final stageText = switch (progress.stage) {
      LocalFolderRefreshStage.checking => i18n.t(
        'local.updateFolderProgressActionChecking',
      ),
      LocalFolderRefreshStage.reading => i18n.t(
        'local.updateFolderProgressActionReading',
      ),
      LocalFolderRefreshStage.updating => i18n.t(
        'local.updateFolderProgressActionUpdating',
      ),
    };
    final countText = switch (progress.stage) {
      LocalFolderRefreshStage.checking => i18n.t(
        'local.updateFolderProgressChecked',
        {'count': progress.current, 'total': progress.total},
      ),
      LocalFolderRefreshStage.reading ||
      LocalFolderRefreshStage.updating => i18n.t(
        'local.updateFolderProgressProcessedSongs',
        {'count': progress.processedSongCount, 'total': progress.songCount},
      ),
    };

    return _DialogOverlay(
      child: Container(
        width: 440,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colors.dialogSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colors.cardBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    i18n.t('local.updateFolderProgressTitle'),
                    style: TextStyle(
                      color: colors.textStrong,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (onCancel != null)
                  TextButton(
                    onPressed: onCancel,
                    child: Text(i18n.t('local.updateFolderProgressStop')),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              stageText,
              style: TextStyle(
                color: colors.textStrong,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: value),
            const SizedBox(height: 10),
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                Text(countText, style: TextStyle(color: colors.textMuted)),
                Text(
                  '${i18n.t('local.updateFolderProgressAdded')}: ${progress.addedCount}',
                  style: TextStyle(color: colors.textMuted),
                ),
                Text(
                  '${i18n.t('local.updateFolderProgressUpdated')}: ${progress.updatedCount}',
                  style: TextStyle(color: colors.textMuted),
                ),
                Text(
                  '${i18n.t('local.updateFolderProgressMissing')}: ${progress.missingCount}',
                  style: TextStyle(color: colors.textMuted),
                ),
              ],
            ),
            if (progress.currentPath.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                progress.stage == LocalFolderRefreshStage.checking
                    ? i18n.t('local.updateFolderProgressCurrentFolder', {
                      'name': _settingsFileTitle(progress.currentPath),
                    })
                    : _settingsFileTitle(progress.currentPath),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: colors.textMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _settingsFileTitle(String path) {
  final normalized = path.replaceAll('\\', '/');
  final index = normalized.lastIndexOf('/');
  return index < 0 ? normalized : normalized.substring(index + 1);
}

class ReleaseNotesDialog extends StatelessWidget {
  const ReleaseNotesDialog({
    super.key,
    required this.version,
    required this.onClose,
  });

  final String? version;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final releaseNotes = getReleaseNotes(i18n);

    return _DialogOverlay(
      child: _DialogBox(
        title: i18n.t('settings.releaseNotes'),
        onClose: onClose,
        width: 640,
        child: SizedBox(
          height: 480,
          child: Scrollbar(
            child: ListView.separated(
              primary: false,
              padding: const EdgeInsets.only(right: 14),
              itemCount: releaseNotes.length,
              separatorBuilder: (_, _) => const SizedBox(height: 18),
              itemBuilder: (context, index) {
                return _ReleaseNoteVersion(entry: releaseNotes[index]);
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ReleaseNoteVersion extends StatelessWidget {
  const _ReleaseNoteVersion({required this.entry});

  final ReleaseNoteEntry entry;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final colors = SettingsPageColors.of(context);
    final title =
        entry.version == 'History Updates'
            ? i18n.t('settings.releaseNotesIntro')
            : '${i18n.t('settings.releaseNotesVersion')} ${entry.version}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: TextStyle(
            color: colors.textStrong,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        ...entry.items.map((item) => _ReleaseNoteItem(text: item)),
      ],
    );
  }
}

class _ReleaseNoteItem extends StatelessWidget {
  const _ReleaseNoteItem({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = SettingsPageColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: SizedBox(
              width: 5,
              height: 5,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: SettingsPageColors.accent,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: colors.textStrong, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class ArtistSplitReviewDialog extends StatelessWidget {
  const ArtistSplitReviewDialog({
    super.key,
    required this.result,
    required this.applying,
    required this.onCancel,
    required this.onApply,
  });

  final ArtistSplitAnalysisResult result;
  final bool applying;
  final VoidCallback onCancel;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final colors = SettingsPageColors.of(context);
    final splitItems = _splitItems(result);

    return _DialogOverlay(
      child: _DialogBox(
        width: 640,
        title: i18n.t('local.startupArtistSplitSuggestionsTitle'),
        onClose: onCancel,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              i18n.t('local.artistSplitReviewTotal', {
                'count': splitItems.length,
              }),
              style: TextStyle(
                color: colors.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 390),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (result.directSplits.isNotEmpty)
                      _ArtistSplitGroup(
                        title: i18n.t('local.directArtistSplitsGroup', {
                          'count': result.directSplits.length,
                        }),
                        items: result.directSplits,
                      ),
                    if (result.possibleSplits.isNotEmpty)
                      _ArtistSplitGroup(
                        title: i18n.t(
                          'local.refreshArtistSplitSuggestionsGroup',
                          {'count': result.possibleSplits.length},
                        ),
                        items: result.possibleSplits,
                      ),
                    if (result.mergeSuggestions.isNotEmpty)
                      _ArtistSplitGroup(
                        title: i18n.t('local.artistMergeSuggestionsTitle'),
                        items: result.mergeSuggestions,
                        afterLabelKey: 'local.artistMergeAfter',
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: applying ? null : onCancel,
                  child: Text(i18n.t('local.keepArtistSplits')),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: applying ? null : onApply,
                  child: Text(
                    applying
                        ? i18n.t('local.applyingArtistSplits')
                        : i18n.t('local.applyArtistSplits'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ArtistSplitGroup extends StatelessWidget {
  const _ArtistSplitGroup({
    required this.title,
    required this.items,
    this.afterLabelKey = 'local.artistSplitAfter',
  });

  final String title;
  final List<ArtistSplitResultItem> items;
  final String afterLabelKey;

  @override
  Widget build(BuildContext context) {
    final colors = SettingsPageColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: TextStyle(
              color: colors.textStrong,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          for (final item in items)
            _ArtistSplitTile(item: item, afterLabelKey: afterLabelKey),
        ],
      ),
    );
  }
}

class _ArtistSplitTile extends StatelessWidget {
  const _ArtistSplitTile({required this.item, required this.afterLabelKey});

  final ArtistSplitResultItem item;
  final String afterLabelKey;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final colors = SettingsPageColors.of(context);
    final separator = i18n.t('common.artistSeparator');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.cardSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            FluentIcons.people_24_regular,
            color: SettingsPageColors.accent,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textStrong,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                _ArtistSplitLine(
                  label: i18n.t('local.artistSplitOriginal'),
                  text: item.artist,
                ),
                const SizedBox(height: 4),
                _ArtistSplitLine(
                  label: i18n.t(afterLabelKey),
                  text: item.artists.join(separator),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ArtistSplitLine extends StatelessWidget {
  const _ArtistSplitLine({required this.label, required this.text});

  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = SettingsPageColors.of(context);
    return RichText(
      text: TextSpan(
        style: TextStyle(color: colors.textMuted, fontSize: 13, height: 1.3),
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          TextSpan(text: text),
        ],
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

    return _DialogOverlay(
      child: _DialogBox(
        title: title,
        onClose: onCancel,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(message),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: busy ? null : onCancel,
                  child: Text(i18n.t('common.cancel')),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: busy ? null : onConfirm,
                  child: Text(
                    busy
                        ? i18n.t('settings.smartMultiArtistFixPending')
                        : confirmText ?? i18n.t('common.confirm'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogBox extends StatelessWidget {
  const _DialogBox({
    required this.title,
    required this.onClose,
    required this.child,
    this.width = 460,
  });

  final String title;
  final VoidCallback onClose;
  final Widget child;
  final double width;

  @override
  Widget build(BuildContext context) {
    final colors = SettingsPageColors.of(context);
    return Container(
      width: width,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        color: colors.dialogSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.cardBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DialogHeader(title: title, onClose: onClose),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _DialogHeader extends StatelessWidget {
  const _DialogHeader({required this.title, required this.onClose});

  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = SettingsPageColors.of(context);
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: colors.textStrong,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            tooltip: context.smPlayerI18n.t('common.close'),
            onPressed: onClose,
            icon: const Icon(FluentIcons.dismiss_24_regular),
          ),
        ],
      ),
    );
  }
}

class _DialogOverlay extends StatelessWidget {
  const _DialogOverlay({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = SettingsPageColors.of(context);
    return SizedBox.expand(
      child: Material(color: colors.overlay, child: Center(child: child)),
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

class SettingsPageColors {
  const SettingsPageColors._();

  static const textStrong = Color(0xff1f252b);
  static const textMuted = Color(0xff5f625f);
  static const accent = Color(0xff0078d7);
  static const accentStrong = Color(0xff0063b1);
  static const accentHover = Color(0x1a0078d7);
  static const cardSurface = Color(0x9effffff);
  static const cardBorder = Color(0x9eccd5e0);
  static const cardShadow = Color(0x14445870);
  static const inputSurface = Color(0xf4ffffff);
  static const inputBorder = Color(0x387e8b9a);
  static const selectOpenSurface = Color(0x140078d7);
  static const selectOpenBorder = Color(0x570078d7);
  static const dropdownSurface = Color(0xfaffffff);
  static const dropdownShadow = Color(0x2e263344);
  static const colorSwatchInset = Color(0xb8ffffff);
  static const buttonSurface = Color(0xb8ffffff);
  static const dialogSurface = Color(0xfffbfdff);
  static const overlay = Color(0x47202b36);
  static const preferenceHeader = Color(0x7affffff);
  static const danger = Color(0xffb42318);

  static SettingsPalette of(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (!dark) {
      return const SettingsPalette(
        textStrong: textStrong,
        textMuted: textMuted,
        accent: accent,
        accentStrong: accentStrong,
        accentHover: accentHover,
        cardSurface: cardSurface,
        cardBorder: cardBorder,
        cardShadow: cardShadow,
        inputSurface: inputSurface,
        inputBorder: inputBorder,
        selectOpenSurface: selectOpenSurface,
        selectOpenBorder: selectOpenBorder,
        dropdownSurface: dropdownSurface,
        dropdownShadow: dropdownShadow,
        colorSwatchInset: colorSwatchInset,
        buttonSurface: buttonSurface,
        progressPanelSurface: Color(0xc2ffffff),
        progressPanelBorder: Color(0x247e8b9a),
        progressTrack: Color(0x297e8b9a),
        dialogSurface: dialogSurface,
        overlay: overlay,
        preferenceHeader: preferenceHeader,
      );
    }
    return const SettingsPalette(
      textStrong: Color(0xeff6f9fc),
      textMuted: Color(0xadCBD5E1),
      accent: accent,
      accentStrong: Color(0xff7fc4ff),
      accentHover: Color(0x2e0078d7),
      cardSurface: Color(0x0cffffff),
      cardBorder: Color(0x1fd6e0ec),
      cardShadow: Color(0x33000000),
      inputSurface: Color(0x11ffffff),
      inputBorder: Color(0x1fd6e0ec),
      selectOpenSurface: Color(0x290078d7),
      selectOpenBorder: Color(0x570078d7),
      dropdownSurface: Color(0xfa181e26),
      dropdownShadow: Color(0x5c000000),
      colorSwatchInset: Color(0x1fffffff),
      buttonSurface: Color(0x11ffffff),
      progressPanelSurface: Color(0x11ffffff),
      progressPanelBorder: Color(0x1fd6e0ec),
      progressTrack: Color(0x2ecbd5e1),
      dialogSurface: Color(0xff181e26),
      overlay: Color(0x7a05070a),
      preferenceHeader: Color(0x14ffffff),
    );
  }
}

class SettingsPalette {
  const SettingsPalette({
    required this.textStrong,
    required this.textMuted,
    required this.accent,
    required this.accentStrong,
    required this.accentHover,
    required this.cardSurface,
    required this.cardBorder,
    required this.cardShadow,
    required this.inputSurface,
    required this.inputBorder,
    required this.selectOpenSurface,
    required this.selectOpenBorder,
    required this.dropdownSurface,
    required this.dropdownShadow,
    required this.colorSwatchInset,
    required this.buttonSurface,
    required this.progressPanelSurface,
    required this.progressPanelBorder,
    required this.progressTrack,
    required this.dialogSurface,
    required this.overlay,
    required this.preferenceHeader,
  });

  final Color textStrong;
  final Color textMuted;
  final Color accent;
  final Color accentStrong;
  final Color accentHover;
  final Color cardSurface;
  final Color cardBorder;
  final Color cardShadow;
  final Color inputSurface;
  final Color inputBorder;
  final Color selectOpenSurface;
  final Color selectOpenBorder;
  final Color dropdownSurface;
  final Color dropdownShadow;
  final Color colorSwatchInset;
  final Color buttonSurface;
  final Color progressPanelSurface;
  final Color progressPanelBorder;
  final Color progressTrack;
  final Color dialogSurface;
  final Color overlay;
  final Color preferenceHeader;
}
