import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
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
    this.appVersion,
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
  final String? appVersion;
  final ValueChanged<AppSettingsUpdate>? onUpdateSettings;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final SettingsController _settingsController;
  late final bool _ownsSettingsController;
  var _showPreferenceSettings = false;
  var _showReleaseNotes = false;
  var _showFeedbackOptions = false;
  var _showImportDataDialog = false;
  var _showSmartArtistFixDialog = false;
  var _smartArtistFixRunning = false;
  var _smartArtistApplyRunning = false;
  ArtistSplitAnalysisResult? _artistSplitAnalysisResult;
  var _showLyricsBatchOptions = false;
  var _lyricsBatchOverwrite = false;
  var _lyricsBatchRunning = false;
  var _lyricsBatchCancelRequested = false;
  var _lyricsBatchPaused = false;
  var _showLyricsBatchDetails = false;
  LyricsBatchProgress? _lyricsBatchProgress;
  LyricsBatchResult? _lyricsBatchResult;
  var _dataTransferState = DataTransferState.idle;
  var _scanRunning = false;
  LocalFolderRefreshProgress? _scanProgress;
  LocalFolderScanCancellation? _scanCancellation;
  var _systemFonts = const <String>[];
  String? _appVersion;

  SettingsSnapshot get _snapshot => _settingsController.snapshot;
  bool get _isDataTransferBusy => _dataTransferState != DataTransferState.idle;
  bool get _isScanning => widget.scanning || _scanRunning;

  @override
  void initState() {
    super.initState();
    _ownsSettingsController = widget.controller == null;
    _settingsController =
        widget.controller ??
        SettingsController(widget.initialSnapshot, widget.libraryRepository);
    _settingsController.addListener(_onSettingsChanged);
    if (_ownsSettingsController) {
      _settingsController.refresh();
    }
    _loadAppVersion();
    _loadSystemFonts();
  }

  @override
  void dispose() {
    _settingsController.removeListener(_onSettingsChanged);
    if (_ownsSettingsController) {
      _settingsController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 42),
            child: Column(
              children: [
                if (widget.error != null) _ErrorBanner(message: widget.error!),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final narrow = constraints.maxWidth < 820;
                    final columns = <Widget>[
                      _SettingsColumn(children: _buildLeftColumn(i18n)),
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
                        Expanded(child: columns[0]),
                        const SizedBox(width: 22),
                        Expanded(child: columns[1]),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 18),
                if (_appVersion case final appVersion?)
                  Text(
                    '${i18n.t('app.shell')} $appVersion',
                    style: TextStyle(
                      color: SettingsPageColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
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
    );
  }

  List<Widget> _buildLeftColumn(SmPlayerI18n i18n) {
    return [
      SettingsCard(
        title: i18n.t('common.folders'),
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
                    disabledBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                      borderSide: BorderSide(
                        color: SettingsPageColors.inputBorder,
                      ),
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
          if (_isScanning)
            Text(
              i18n.t('library.scanning'),
              style: const TextStyle(
                color: SettingsPageColors.textMuted,
                fontSize: 13,
              ),
            ),
          if (_snapshot.rootPath.isNotEmpty)
            SettingsActionButton(
              icon: FluentIcons.arrow_sync_24_regular,
              disabled: widget.loading || _isScanning,
              onClick: () {
                unawaited(_scanLibraryRoot(_snapshot.rootPath));
              },
              child: Text(i18n.t('settings.rescan')),
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
            SettingsActionButton(
              icon: FluentIcons.people_24_regular,
              disabled: widget.loading || _isScanning,
              onClick: _requestSmartArtistFix,
              child: Text(i18n.t('settings.smartMultiArtistFix')),
            ),
        ],
      ),
      SettingsCard(
        title: i18n.t('settings.lyrics'),
        children: [
          Text(
            i18n.t('settings.batchAddLyricsCopy'),
            style: const TextStyle(
              color: SettingsPageColors.textMuted,
              fontSize: 13,
            ),
          ),
          SettingsActionButton(
            icon: FluentIcons.text_grammar_wand_24_regular,
            disabled: _lyricsBatchRunning,
            onClick: () {
              setState(() {
                _showLyricsBatchOptions = !_showLyricsBatchOptions;
              });
            },
            child: Text(i18n.t('settings.batchAddLyrics')),
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
          if (_lyricsBatchRunning)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SettingsActionButton(
                  icon:
                      _lyricsBatchPaused
                          ? FluentIcons.play_24_regular
                          : FluentIcons.pause_24_regular,
                  onClick: () {
                    setState(() {
                      _lyricsBatchPaused = !_lyricsBatchPaused;
                    });
                  },
                  child: Text(
                    _lyricsBatchPaused
                        ? i18n.t('common.continue')
                        : i18n.t('common.pause'),
                  ),
                ),
                SettingsActionButton(
                  icon: FluentIcons.dismiss_24_regular,
                  onClick: () {
                    setState(() {
                      _lyricsBatchCancelRequested = true;
                      _lyricsBatchPaused = false;
                    });
                  },
                  child: Text(i18n.t('common.cancel')),
                ),
              ],
            ),
          if (_lyricsBatchProgress case final progress?)
            _LyricsBatchProgressPanel(progress: progress),
          if (!_lyricsBatchRunning)
            if (_lyricsBatchResult case final result?)
              _LyricsBatchResultPanel(
                result: result,
                onDetails:
                    result.details.isEmpty
                        ? null
                        : () {
                          setState(() {
                            _showLyricsBatchDetails = true;
                          });
                        },
                onClear: () {
                  setState(() {
                    _lyricsBatchResult = null;
                    _lyricsBatchProgress = null;
                    _showLyricsBatchDetails = false;
                  });
                },
              ),
        ],
      ),
      SettingsCard(
        id: 'desktop-lyrics',
        title: i18n.t('settings.desktopLyrics'),
        headerAction: Switch(
          value: _snapshot.desktopLyricsEnabled,
          activeColor: SettingsPageColors.accent,
          onChanged: (checked) {
            _updateSettings(AppSettingsUpdate(desktopLyricsEnabled: checked));
          },
        ),
        children:
            _snapshot.desktopLyricsEnabled
                ? [
                  ToggleSettingRow(
                    label: i18n.t('settings.desktopLyricsLock'),
                    checked: _snapshot.desktopLyricsLocked,
                    onChange: (checked) {
                      _updateSettings(
                        AppSettingsUpdate(desktopLyricsLocked: checked),
                      );
                    },
                  ),
                  ColorSettingRow(
                    label: i18n.t('settings.desktopLyricsColor'),
                    value: _snapshot.desktopLyricsColor,
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
                  SettingsActionButton(
                    icon: FluentIcons.arrow_undo_24_regular,
                    onClick: () {
                      _updateSettings(
                        const AppSettingsUpdate(
                          desktopLyricsLocked: false,
                          desktopLyricsColor: '#4AA8FF',
                          desktopLyricsStrokeColor: '#111111',
                          desktopLyricsFontSize: 28,
                          desktopLyricsFontFamily: 'system',
                          desktopLyricsOpacity: 88,
                          desktopLyricsBounds: '',
                        ),
                      );
                    },
                    child: Text(
                      i18n.t('settings.desktopLyricsRestoreDefaults'),
                    ),
                  ),
                  SettingsActionButton(
                    icon: FluentIcons.arrow_reset_24_regular,
                    onClick: () {
                      _updateSettings(
                        const AppSettingsUpdate(desktopLyricsBounds: ''),
                      );
                    },
                    child: Text(i18n.t('settings.desktopLyricsResetOffset')),
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
          SettingsActionButton(
            icon: FluentIcons.star_24_regular,
            onClick: () {
              setState(() {
                _showPreferenceSettings = true;
              });
            },
            child: Text(i18n.t('settings.preferenceSettings')),
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
                onClick: () {
                  setState(() {
                    _showImportDataDialog = true;
                  });
                },
                child: Text(i18n.t('settings.importData')),
              ),
              SettingsActionButton(
                disabled: _isDataTransferBusy,
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
        _appVersion = '1.0.0';
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
        <String>{
          ..._systemFonts,
          if (_snapshot.desktopLyricsFontFamily != 'system')
            _snapshot.desktopLyricsFontFamily,
        }.toList();
    fontNames.sort(
      (left, right) => left.toLowerCase().compareTo(right.toLowerCase()),
    );
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
          if (!mounted) {
            return;
          }
          setState(() {
            _lyricsBatchProgress = progress;
          });
        },
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _lyricsBatchResult = result;
      });
      final message =
          _lyricsBatchCancelRequested
              ? i18n.t('settings.lyricsBatchStopped')
              : i18n.t('settings.lyricsBatchDone');
      _showMessage(
        '$message: ${i18n.t('settings.lyricsBatchSaved')} ${result.saved} · '
        '${i18n.t('settings.lyricsBatchOverwritten')} ${result.overwritten} · '
        '${i18n.t('settings.lyricsBatchSkipped')} ${result.skipped} · '
        '${i18n.t('settings.lyricsBatchMissing')} ${result.missing} · '
        '${i18n.t('settings.lyricsBatchFailed')} ${result.failed}',
      );
    } catch (_) {
      if (mounted) {
        _showMessage(i18n.t('settings.lyricsBatchFailed'));
      }
    } finally {
      if (mounted) {
        setState(() {
          _lyricsBatchRunning = false;
          _lyricsBatchCancelRequested = false;
          _lyricsBatchPaused = false;
        });
      }
    }
  }

  Future<void> _waitForLyricsBatchResume() async {
    while (mounted && _lyricsBatchPaused && !_lyricsBatchCancelRequested) {
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
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        onChange(!checked);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Switch(
              value: checked,
              activeColor: SettingsPageColors.accent,
              onChanged: onChange,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: SettingsPageColors.textStrong,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (hint != null) ...[
                    const SizedBox(width: 8),
                    Tooltip(
                      message: hint!,
                      child: const Icon(
                        FluentIcons.info_24_regular,
                        size: 16,
                        color: SettingsPageColors.textMuted,
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
    if (searchable) {
      final selectedOption = options.firstWhere(
        (option) => option.value == value,
        orElse: () => options.first,
      );
      return _SettingsRowFrame(
        label: label,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            _showSearchableSelect(context);
          },
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: SettingsPageColors.inputSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: SettingsPageColors.inputBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    selectedOption.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: SettingsPageColors.textStrong,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(
                  FluentIcons.search_24_regular,
                  size: 18,
                  color: SettingsPageColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return _SettingsRowFrame(
      label: label,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          borderRadius: BorderRadius.circular(8),
          items:
              options
                  .map(
                    (option) => DropdownMenuItem<T>(
                      value: option.value,
                      child: Text(
                        option.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
          onChanged: (nextValue) {
            onChange(nextValue as T);
          },
        ),
      ),
    );
  }

  Future<void> _showSearchableSelect(BuildContext context) async {
    final selected = await showDialog<T>(
      context: context,
      builder: (context) {
        var query = '';
        return StatefulBuilder(
          builder: (context, setState) {
            final normalizedQuery = query.toLowerCase();
            final filteredOptions =
                normalizedQuery.isEmpty
                    ? options
                    : options
                        .where(
                          (option) => option.label.toLowerCase().contains(
                            normalizedQuery,
                          ),
                        )
                        .toList();
            return Dialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 32,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 420,
                  maxHeight: 560,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: searchPlaceholder,
                          prefixIcon: const Icon(FluentIcons.search_24_regular),
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (value) {
                          setState(() {
                            query = value;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child:
                            filteredOptions.isEmpty
                                ? Center(
                                  child: Text(
                                    emptyLabel ?? '',
                                    style: const TextStyle(
                                      color: SettingsPageColors.textMuted,
                                    ),
                                  ),
                                )
                                : ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: filteredOptions.length,
                                  itemBuilder: (context, index) {
                                    final option = filteredOptions[index];
                                    final selected = option.value == value;
                                    return ListTile(
                                      selected: selected,
                                      title: Text(
                                        option.label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      trailing:
                                          selected
                                              ? const Icon(
                                                FluentIcons
                                                    .checkmark_24_regular,
                                              )
                                              : null,
                                      onTap: () {
                                        Navigator.of(context).pop(option.value);
                                      },
                                    );
                                  },
                                ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    if (selected != null) {
      onChange(selected);
    }
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
    return _SettingsRowFrame(
      label: label,
      child: Row(
        children: [
          Text(
            startLabel,
            style: const TextStyle(color: SettingsPageColors.textMuted),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _TimePicker(value: startValue, onChange: onStartChange),
          ),
          const SizedBox(width: 12),
          Text(
            endLabel,
            style: const TextStyle(color: SettingsPageColors.textMuted),
          ),
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
    return _SettingsRowFrame(
      label: label,
      child: Row(
        children: [
          Expanded(
            child: Slider(
              value: value.toDouble(),
              min: min.toDouble(),
              max: max.toDouble(),
              divisions: ((max - min) / step).round(),
              activeColor: SettingsPageColors.accent,
              onChanged: (nextValue) {
                onChange(nextValue.round());
              },
            ),
          ),
          SizedBox(
            width: 58,
            child: Text(
              valueLabel,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: SettingsPageColors.textMuted,
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
  });

  final String label;
  final String value;
  final ValueChanged<String> onChange;

  @override
  State<ColorSettingRow> createState() => _ColorSettingRowState();
}

class _ColorSettingRowState extends State<ColorSettingRow> {
  static const _swatches = [
    '#4AA8FF',
    '#FFFFFF',
    '#111111',
    '#FFD166',
    '#FF5C8A',
  ];

  late final TextEditingController _controller;
  var _hasError = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value.toUpperCase());
  }

  @override
  void didUpdateWidget(ColorSettingRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextValue = widget.value.toUpperCase();
    if (_controller.text.toUpperCase() != nextValue) {
      _controller.text = nextValue;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsRowFrame(
      label: widget.label,
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: _parseHexColor(widget.value),
              shape: BoxShape.circle,
              border: Border.all(color: SettingsPageColors.inputBorder),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                isDense: true,
                errorText: _hasError ? '' : null,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: SettingsPageColors.inputBorder,
                  ),
                ),
              ),
              onSubmitted: _commitColor,
              onEditingComplete: () {
                _commitColor(_controller.text);
              },
            ),
          ),
          const SizedBox(width: 8),
          for (final swatch in _swatches)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Tooltip(
                message: swatch,
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () {
                    _controller.text = swatch;
                    setState(() {
                      _hasError = false;
                    });
                    widget.onChange(swatch);
                  },
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: _parseHexColor(swatch),
                      shape: BoxShape.circle,
                      border: Border.all(color: SettingsPageColors.inputBorder),
                    ),
                    child: const SizedBox.square(dimension: 18),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _commitColor(String value) {
    final normalized = value.trim().toUpperCase();
    final valid = RegExp(r'^#[0-9A-F]{6}$').hasMatch(normalized);
    setState(() {
      _hasError = !valid;
    });
    if (valid) {
      _controller.text = normalized;
      widget.onChange(normalized);
    }
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
    return Container(
      key: id == null ? null : ValueKey(id),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: BoxDecoration(
        color: SettingsPageColors.cardSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: SettingsPageColors.cardBorder),
        boxShadow: const [
          BoxShadow(
            color: SettingsPageColors.cardShadow,
            offset: Offset(0, 18),
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
                  style: const TextStyle(
                    color: SettingsPageColors.textStrong,
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
            ...children!.map(
              (child) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: child,
              ),
            ),
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
    this.disabled = false,
    this.onClick,
  });

  final Widget child;
  final IconData? icon;
  final bool disabled;
  final VoidCallback? onClick;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: disabled ? null : onClick,
      icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 16),
      label: child,
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 36),
        padding: EdgeInsets.only(left: icon == null ? 14 : 12, right: 14),
        foregroundColor: SettingsPageColors.accent,
        disabledForegroundColor: SettingsPageColors.textMuted,
        backgroundColor: SettingsPageColors.buttonSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SettingsPageColors.buttonSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: SettingsPageColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            i18n.t('settings.lyricsBatchWriteStrategy'),
            style: const TextStyle(
              color: SettingsPageColors.textStrong,
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
  const _LyricsBatchProgressPanel({required this.progress});

  final LyricsBatchProgress progress;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final ratio =
        progress.total == 0 ? 0.0 : progress.currentIndex / progress.total;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SettingsPageColors.buttonSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: SettingsPageColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  i18n.t('settings.lyricsBatchRequesting'),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Text('${progress.currentIndex}/${progress.total}'),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: ratio.clamp(0, 1).toDouble()),
          const SizedBox(height: 8),
          Text(
            progress.currentSongTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            '${i18n.t('settings.lyricsBatchSaved')} ${progress.saved} · '
            '${i18n.t('settings.lyricsBatchOverwritten')} ${progress.overwritten} · '
            '${i18n.t('settings.lyricsBatchSkipped')} ${progress.skipped} · '
            '${i18n.t('settings.lyricsBatchMissing')} ${progress.missing} · '
            '${i18n.t('settings.lyricsBatchFailed')} ${progress.failed}',
            style: const TextStyle(
              color: SettingsPageColors.textMuted,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _LyricsBatchResultPanel extends StatelessWidget {
  const _LyricsBatchResultPanel({
    required this.result,
    required this.onClear,
    this.onDetails,
  });

  final LyricsBatchResult result;
  final VoidCallback? onDetails;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SettingsPageColors.buttonSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: SettingsPageColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${i18n.t('settings.lyricsBatchSaved')} ${result.saved} · '
            '${i18n.t('settings.lyricsBatchOverwritten')} ${result.overwritten} · '
            '${i18n.t('settings.lyricsBatchSkipped')} ${result.skipped} · '
            '${i18n.t('settings.lyricsBatchMissing')} ${result.missing} · '
            '${i18n.t('settings.lyricsBatchFailed')} ${result.failed}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          if (result.backedUp > 0) ...[
            const SizedBox(height: 6),
            Text(
              '${i18n.t('settings.lyricsBatchBackedUp')} ${result.backedUp} (${_formatBytes(result.backupBytes)})',
              style: const TextStyle(
                color: SettingsPageColors.textMuted,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              if (onDetails != null)
                SettingsActionButton(
                  onClick: onDetails!,
                  child: Text(i18n.t('common.detail')),
                ),
              SettingsActionButton(
                onClick: onClear,
                child: Text(i18n.t('common.clear')),
              ),
            ],
          ),
        ],
      ),
    );
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
  final _expandedDetailIds = <String>{};
  final _collapsedResults = <LyricsBatchDetailResult>{};

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final groups =
        LyricsBatchDetailResult.values
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
      child: Container(
        width: 980,
        height: 740,
        margin: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: SettingsPageColors.dialogSurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: SettingsPageColors.cardBorder),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: _DialogHeader(
                title: i18n.t('settings.lyricsBatchTaskDetails'),
                onClose: widget.onClose,
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                itemBuilder: (context, index) {
                  final group = groups[index];
                  final collapsed = _collapsedResults.contains(group.result);
                  return _LyricsBatchDetailGroup(
                    result: group.result,
                    details: group.details,
                    collapsed: collapsed,
                    expandedDetailIds: _expandedDetailIds,
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
                        if (_expandedDetailIds.contains(id)) {
                          _expandedDetailIds.remove(id);
                        } else {
                          _expandedDetailIds.add(id);
                        }
                      });
                    },
                  );
                },
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemCount: groups.length,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LyricsBatchDetailGroup extends StatelessWidget {
  const _LyricsBatchDetailGroup({
    required this.result,
    required this.details,
    required this.collapsed,
    required this.expandedDetailIds,
    required this.onToggleGroup,
    required this.onToggleDetail,
  });

  final LyricsBatchDetailResult result;
  final List<LyricsBatchDetail> details;
  final bool collapsed;
  final Set<String> expandedDetailIds;
  final VoidCallback onToggleGroup;
  final ValueChanged<String> onToggleDetail;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    return Container(
      decoration: BoxDecoration(
        color: SettingsPageColors.buttonSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SettingsPageColors.cardBorder),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggleGroup,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    collapsed
                        ? FluentIcons.chevron_right_24_regular
                        : FluentIcons.chevron_down_24_regular,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _lyricsBatchResultLabel(i18n, result),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Text('${details.length}'),
                ],
              ),
            ),
          ),
          if (!collapsed)
            for (final detail in details)
              _LyricsBatchDetailTile(
                detail: detail,
                expanded: expandedDetailIds.contains(
                  _lyricsBatchDetailId(detail),
                ),
                onToggle: () => onToggleDetail(_lyricsBatchDetailId(detail)),
              ),
        ],
      ),
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
    final reason = _lyricsBatchReasonLabel(i18n, detail.reason);
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: SettingsPageColors.cardBorder)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    expanded
                        ? FluentIcons.chevron_down_24_regular
                        : FluentIcons.chevron_right_24_regular,
                    size: 18,
                    color: SettingsPageColors.textMuted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      detail.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    [
                      _lyricsBatchResultLabel(i18n, detail.result),
                      if (reason.isNotEmpty) '($reason)',
                    ].join(' '),
                    style: const TextStyle(
                      color: SettingsPageColors.textMuted,
                      fontSize: 12,
                    ),
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

class _LyricsBatchExpandedDetail extends StatelessWidget {
  const _LyricsBatchExpandedDetail({required this.detail});

  final LyricsBatchDetail detail;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final source = detail.sourceRawLyrics;
    final target = detail.targetRawLyrics;
    if (detail.result == LyricsBatchDetailResult.overwritten) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _LyricsTextPreview(
                title: i18n.t('settings.lyricsBatchDetailOriginalLyrics'),
                text: source,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _LyricsTextPreview(
                title: i18n.t('settings.lyricsBatchDetailNewLyrics'),
                text: target,
              ),
            ),
          ],
        ),
      );
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

class _LyricsTextPreview extends StatelessWidget {
  const _LyricsTextPreview({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    return Container(
      constraints: const BoxConstraints(minHeight: 120),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SettingsPageColors.cardSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: SettingsPageColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: SettingsPageColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            text.trim().isEmpty
                ? i18n.t('settings.lyricsBatchDetailNoLyrics')
                : text,
            maxLines: 10,
            overflow: TextOverflow.fade,
            style: const TextStyle(
              color: SettingsPageColors.textStrong,
              height: 1.35,
            ),
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

    return _DialogOverlay(
      child: Container(
        width: 1080,
        height: 820,
        margin: const EdgeInsets.all(24),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: SettingsPageColors.dialogSurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: SettingsPageColors.cardBorder),
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
                      ? Center(child: Text(i18n.t('preferences.loadFailed')))
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

    return Column(
      children:
          items.map((item) {
            return Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: SettingsPageColors.cardBorder),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _preferenceItemName(i18n, item),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: SettingsPageColors.textStrong,
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

class PreferenceLevelSelect extends StatelessWidget {
  const PreferenceLevelSelect({
    super.key,
    required this.value,
    required this.onChange,
  });

  final PreferenceLevel value;
  final ValueChanged<PreferenceLevel> onChange;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;

    return DropdownButtonHideUnderline(
      child: DropdownButton<PreferenceLevel>(
        value: value,
        isExpanded: true,
        borderRadius: BorderRadius.circular(9),
        items:
            PreferenceLevel.values
                .map(
                  (level) => DropdownMenuItem(
                    value: level,
                    child: Text(_preferenceLevelLabel(i18n, level)),
                  ),
                )
                .toList(),
        onChanged: (level) {
          onChange(level!);
        },
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

String _preferredLanguageLabel(SmPlayerI18n i18n, PreferredLanguage language) {
  return switch (language) {
    PreferredLanguage.system => i18n.t('settings.languageSystem'),
    PreferredLanguage.zhCN => i18n.t('settings.languageChinese'),
    PreferredLanguage.enUS => i18n.t('settings.languageEnglish'),
    PreferredLanguage.de => i18n.t('settings.languageGerman'),
    PreferredLanguage.fr => i18n.t('settings.languageFrench'),
    PreferredLanguage.ja => i18n.t('settings.languageJapanese'),
    PreferredLanguage.ru => i18n.t('settings.languageRussian'),
    PreferredLanguage.ptBR => i18n.t('settings.languagePortugueseBrazil'),
    PreferredLanguage.es => i18n.t('settings.languageSpanish'),
    PreferredLanguage.it => i18n.t('settings.languageItalian'),
    PreferredLanguage.zhHant => i18n.t('settings.languageChineseTraditional'),
    PreferredLanguage.nl => i18n.t('settings.languageDutch'),
    PreferredLanguage.cs => i18n.t('settings.languageCzech'),
    PreferredLanguage.uk => i18n.t('settings.languageUkrainian'),
    PreferredLanguage.sv => i18n.t('settings.languageSwedish'),
    PreferredLanguage.id => i18n.t('settings.languageIndonesian'),
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
  const _SettingsRowFrame({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: SettingsPageColors.textStrong,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(width: 260, child: child),
      ],
    );
  }
}

class _TimePicker extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final parts = value.split(':');
    final hour = parts.first;
    final minute = parts.last;

    return Row(
      children: [
        Expanded(
          child: _TimeDropdown(
            value: hour,
            options: _hours,
            onChange: (nextHour) {
              onChange('$nextHour:$minute');
            },
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text(':', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
        Expanded(
          child: _TimeDropdown(
            value: minute,
            options: _minutes,
            onChange: (nextMinute) {
              onChange('$hour:$nextMinute');
            },
          ),
        ),
      ],
    );
  }
}

class _TimeDropdown extends StatelessWidget {
  const _TimeDropdown({
    required this.value,
    required this.options,
    required this.onChange,
  });

  final String value;
  final List<String> options;
  final ValueChanged<String> onChange;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        borderRadius: BorderRadius.circular(8),
        menuMaxHeight: 260,
        items:
            options
                .map((part) => DropdownMenuItem(value: part, child: Text(part)))
                .toList(),
        onChanged: (part) {
          onChange(part!);
        },
      ),
    );
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
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon),
        style: IconButton.styleFrom(
          backgroundColor: SettingsPageColors.buttonSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}

class _FeedbackActionButton extends StatelessWidget {
  const _FeedbackActionButton({
    required this.showOptions,
    required this.onToggle,
    required this.onSelected,
  });

  final bool showOptions;
  final VoidCallback onToggle;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        SettingsActionButton(
          onClick: onToggle,
          child: Text(i18n.t('settings.feedback')),
        ),
        if (showOptions)
          Positioned(
            left: 0,
            bottom: 42,
            child: Material(
              color: SettingsPageColors.dialogSurface,
              elevation: 8,
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 138,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      dense: true,
                      title: Text(i18n.t('settings.viaEmail')),
                      onTap: () {
                        onSelected(i18n.t('settings.viaEmail'));
                      },
                    ),
                    ListTile(
                      dense: true,
                      title: Text(i18n.t('settings.viaWebBrowser')),
                      onTap: () {
                        onSelected(i18n.t('settings.viaWebBrowser'));
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SettingsProgressOverlay extends StatelessWidget {
  const _SettingsProgressOverlay({required this.state});

  final DataTransferState state;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
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
          color: SettingsPageColors.dialogSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: SettingsPageColors.cardBorder),
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
          color: SettingsPageColors.dialogSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: SettingsPageColors.cardBorder),
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
                    style: const TextStyle(
                      color: SettingsPageColors.textStrong,
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
              style: const TextStyle(
                color: SettingsPageColors.textStrong,
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
                Text(
                  countText,
                  style: const TextStyle(color: SettingsPageColors.textMuted),
                ),
                Text(
                  '${i18n.t('local.updateFolderProgressAdded')}: ${progress.addedCount}',
                  style: const TextStyle(color: SettingsPageColors.textMuted),
                ),
                Text(
                  '${i18n.t('local.updateFolderProgressUpdated')}: ${progress.updatedCount}',
                  style: const TextStyle(color: SettingsPageColors.textMuted),
                ),
                Text(
                  '${i18n.t('local.updateFolderProgressMissing')}: ${progress.missingCount}',
                  style: const TextStyle(color: SettingsPageColors.textMuted),
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
                style: const TextStyle(color: SettingsPageColors.textMuted),
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
    final title =
        entry.version == 'History Updates'
            ? i18n.t('settings.releaseNotesIntro')
            : '${i18n.t('settings.releaseNotesVersion')} ${entry.version}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: SettingsPageColors.textStrong,
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
              style: const TextStyle(
                color: SettingsPageColors.textStrong,
                height: 1.35,
              ),
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
              style: const TextStyle(
                color: SettingsPageColors.textMuted,
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: SettingsPageColors.textStrong,
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
    final separator = i18n.t('common.artistSeparator');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SettingsPageColors.cardSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: SettingsPageColors.cardBorder),
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
                  style: const TextStyle(
                    color: SettingsPageColors.textStrong,
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
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          color: SettingsPageColors.textMuted,
          fontSize: 13,
          height: 1.3,
        ),
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
    return Container(
      width: width,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        color: SettingsPageColors.dialogSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SettingsPageColors.cardBorder),
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
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: SettingsPageColors.textStrong,
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
    return SizedBox.expand(
      child: Material(
        color: SettingsPageColors.overlay,
        child: Center(child: child),
      ),
    );
  }
}

class _PreferenceInfo extends StatelessWidget {
  const _PreferenceInfo();

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;

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
              style: const TextStyle(
                color: SettingsPageColors.textMuted,
                fontSize: 13,
              ),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: SettingsPageColors.cardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SettingsPageColors.cardBorder),
      ),
      child: Column(
        children: [
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            color: SettingsPageColors.preferenceHeader,
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
                          color: SettingsPageColors.accentHover,
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

    return SizedBox(
      height: 44,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Text(
          i18n.t('preferences.noItems'),
          style: const TextStyle(color: SettingsPageColors.textMuted),
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
  static const accentHover = Color(0x1a0078d7);
  static const cardSurface = Color(0x9effffff);
  static const cardBorder = Color(0x9eccd5e0);
  static const cardShadow = Color(0x14445870);
  static const inputSurface = Color(0xf4ffffff);
  static const inputBorder = Color(0x387e8b9a);
  static const buttonSurface = Color(0xb8ffffff);
  static const dialogSurface = Color(0xfffbfdff);
  static const overlay = Color(0x47202b36);
  static const preferenceHeader = Color(0x7affffff);
  static const danger = Color(0xffb42318);
}
