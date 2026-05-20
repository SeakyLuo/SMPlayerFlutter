import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/settings/settings_controller.dart';
import 'package:smplayer_flutter/src/settings/settings_model.dart';

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
    this.onUpdateSettings,
    this.controller,
  });

  final SettingsSnapshot initialSnapshot;
  final SettingsController? controller;
  final bool loading;
  final bool scanning;
  final String? error;
  final VoidCallback? onPickLibraryRoot;
  final VoidCallback? onScanLibrary;
  final VoidCallback? onRequestSmartArtistFix;
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
  var _dataTransferState = DataTransferState.idle;

  SettingsSnapshot get _snapshot => _settingsController.snapshot;

  @override
  void initState() {
    super.initState();
    _ownsSettingsController = widget.controller == null;
    _settingsController =
        widget.controller ?? SettingsController(widget.initialSnapshot);
    _settingsController.addListener(_onSettingsChanged);
    if (_ownsSettingsController) {
      _settingsController.refresh();
    }
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
                Text(
                  '${i18n.t('app.shell')} 1.0.0',
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
          if (_showPreferenceSettings)
            PreferenceSettingsPage(
              onClose: () {
                setState(() {
                  _showPreferenceSettings = false;
                });
              },
            ),
          if (_showReleaseNotes)
            _SimpleSettingsDialog(
              title: i18n.t('settings.releaseNotes'),
              message: i18n.t('settings.releaseNotesIntro'),
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
                setState(() {
                  _showImportDataDialog = false;
                  _dataTransferState = DataTransferState.importing;
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
                  onPressed: widget.onPickLibraryRoot ?? _pickLibraryRoot,
                ),
              ),
            ],
          ),
          if (widget.loading)
            Text(
              i18n.t('settings.rescan'),
              style: const TextStyle(
                color: SettingsPageColors.textMuted,
                fontSize: 13,
              ),
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
              disabled: widget.loading || widget.scanning,
              onClick:
                  widget.onRequestSmartArtistFix ??
                  () {
                    _showMessage(i18n.t('settings.smartMultiArtistFixPending'));
                  },
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
            onClick: () {
              _showMessage(i18n.t('settings.lyricsBatchStarting'));
            },
            child: Text(i18n.t('settings.batchAddLyrics')),
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
                    options: [
                      SelectSettingOption(
                        value: 'system',
                        label: i18n.t('settings.desktopLyricsFontSystem'),
                      ),
                      SelectSettingOption(
                        value: 'Microsoft YaHei UI',
                        label: 'Microsoft YaHei UI',
                      ),
                      SelectSettingOption(value: 'Segoe UI', label: 'Segoe UI'),
                    ],
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
                          desktopLyricsColor: '#4AA8FF',
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
              _updateSettings(AppSettingsUpdate(notificationSend: value));
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
                onClick: () {
                  setState(() {
                    _showImportDataDialog = true;
                  });
                },
                child: Text(i18n.t('settings.importData')),
              ),
              SettingsActionButton(
                onClick: () {
                  setState(() {
                    _dataTransferState = DataTransferState.exporting;
                  });
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
                  _showMessage(label);
                },
              ),
              SettingsActionButton(
                onClick: () {
                  _showMessage(i18n.t('settings.systemLog'));
                },
                child: Text(i18n.t('settings.systemLog')),
              ),
            ],
          ),
        ],
      ),
    ];
  }

  void _pickLibraryRoot() {
    _updateSettings(
      const AppSettingsUpdate(rootPath: r'C:\Users\Public\Music'),
    );
  }

  void _updateSettings(AppSettingsUpdate update) {
    _settingsController.updateSettings(update);
    widget.onUpdateSettings?.call(update);
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
  });

  final String label;
  final T value;
  final List<SelectSettingOption<T>> options;
  final ValueChanged<T> onChange;

  @override
  Widget build(BuildContext context) {
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

  static const _times = [
    '00:00',
    '01:00',
    '02:00',
    '03:00',
    '04:00',
    '05:00',
    '06:00',
    '07:00',
    '08:00',
    '09:00',
    '10:00',
    '11:00',
    '12:00',
    '13:00',
    '14:00',
    '15:00',
    '16:00',
    '17:00',
    '18:00',
    '19:00',
    '20:00',
    '21:00',
    '22:00',
    '23:00',
  ];

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
            child: _TimeDropdown(
              value: startValue,
              options: _times,
              onChange: onStartChange,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            endLabel,
            style: const TextStyle(color: SettingsPageColors.textMuted),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _TimeDropdown(
              value: endValue,
              options: _times,
              onChange: onEndChange,
            ),
          ),
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

class ColorSettingRow extends StatelessWidget {
  const ColorSettingRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChange,
  });

  static const _swatches = [
    '#4AA8FF',
    '#FFFFFF',
    '#111111',
    '#FFD166',
    '#FF5C8A',
  ];

  final String label;
  final String value;
  final ValueChanged<String> onChange;

  @override
  Widget build(BuildContext context) {
    return _SettingsRowFrame(
      label: label,
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: _parseHexColor(value),
              shape: BoxShape.circle,
              border: Border.all(color: SettingsPageColors.inputBorder),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value.toUpperCase(),
                isExpanded: true,
                borderRadius: BorderRadius.circular(8),
                items:
                    _swatches
                        .map(
                          (swatch) => DropdownMenuItem<String>(
                            value: swatch,
                            child: Text(swatch),
                          ),
                        )
                        .toList(),
                onChanged: (nextValue) {
                  onChange(nextValue!);
                },
              ),
            ),
          ),
        ],
      ),
    );
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

class PreferenceSettingsPage extends StatefulWidget {
  const PreferenceSettingsPage({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  State<PreferenceSettingsPage> createState() => _PreferenceSettingsPageState();
}

class _PreferenceSettingsPageState extends State<PreferenceSettingsPage> {
  var _snapshot = PreferenceSettingsSnapshot.defaults();
  final _expandedSections = <PreferenceSectionKey>{};

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
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 6, 18, 20),
                child: Column(
                  children: [
                    const _PreferenceInfo(),
                    PreferenceSection(
                      title: i18n.t('preferences.songs'),
                      section: PreferenceSectionKey.songs,
                      limit: 100,
                      enabled: _snapshot.enabled[PreferenceSectionKey.songs]!,
                      items: _snapshot.songs,
                      expanded: _expandedSections.contains(
                        PreferenceSectionKey.songs,
                      ),
                      onToggleEnabled: _toggleEnabled,
                      onToggleExpanded: _toggleExpanded,
                      onUpdateItem: _updateItem,
                    ),
                    PreferenceSection(
                      title: i18n.t('preferences.artists'),
                      section: PreferenceSectionKey.artists,
                      limit: 50,
                      enabled: _snapshot.enabled[PreferenceSectionKey.artists]!,
                      items: _snapshot.artists,
                      expanded: _expandedSections.contains(
                        PreferenceSectionKey.artists,
                      ),
                      onToggleEnabled: _toggleEnabled,
                      onToggleExpanded: _toggleExpanded,
                      onUpdateItem: _updateItem,
                    ),
                    PreferenceSection(
                      title: i18n.t('preferences.albums'),
                      section: PreferenceSectionKey.albums,
                      limit: 50,
                      enabled: _snapshot.enabled[PreferenceSectionKey.albums]!,
                      items: _snapshot.albums,
                      expanded: _expandedSections.contains(
                        PreferenceSectionKey.albums,
                      ),
                      onToggleEnabled: _toggleEnabled,
                      onToggleExpanded: _toggleExpanded,
                      onUpdateItem: _updateItem,
                    ),
                    PreferenceSection(
                      title: i18n.t('preferences.playlists'),
                      section: PreferenceSectionKey.playlists,
                      limit: 30,
                      enabled:
                          _snapshot.enabled[PreferenceSectionKey.playlists]!,
                      items: _snapshot.playlists,
                      expanded: _expandedSections.contains(
                        PreferenceSectionKey.playlists,
                      ),
                      onToggleEnabled: _toggleEnabled,
                      onToggleExpanded: _toggleExpanded,
                      onUpdateItem: _updateItem,
                    ),
                    PreferenceSection(
                      title: i18n.t('preferences.folders'),
                      section: PreferenceSectionKey.folders,
                      limit: 30,
                      enabled: _snapshot.enabled[PreferenceSectionKey.folders]!,
                      items: _snapshot.folders,
                      expanded: _expandedSections.contains(
                        PreferenceSectionKey.folders,
                      ),
                      onToggleEnabled: _toggleEnabled,
                      onToggleExpanded: _toggleExpanded,
                      onUpdateItem: _updateItem,
                    ),
                    _PreferenceOthersSection(
                      items: _snapshot.others,
                      onUpdateItem: _updateItem,
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

  void _toggleEnabled(PreferenceSectionKey section, bool enabled) {
    setState(() {
      _snapshot = _snapshot.copyWith(
        enabled: {..._snapshot.enabled, section: enabled},
      );
    });
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
      _snapshot = _snapshot.copyWith(
        others:
            _snapshot.others
                .map((current) => current.name == item.name ? update : current)
                .toList(),
      );
    });
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

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final visibleItems = expanded ? items : items.take(5).toList();

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
        ],
      ),
      child:
          visibleItems.isEmpty
              ? const _PreferenceEmpty()
              : PreferenceItems(
                items: visibleItems,
                onUpdateItem: onUpdateItem,
              ),
    );
  }
}

class PreferenceItems extends StatelessWidget {
  const PreferenceItems({
    super.key,
    required this.items,
    required this.onUpdateItem,
  });

  final List<PreferenceItemSnapshot> items;
  final void Function(
    PreferenceItemSnapshot item,
    PreferenceItemSnapshot update,
  )
  onUpdateItem;

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
        items:
            options
                .map((time) => DropdownMenuItem(value: time, child: Text(time)))
                .toList(),
        onChanged: (time) {
          onChange(time!);
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

class _SimpleSettingsDialog extends StatelessWidget {
  const _SimpleSettingsDialog({
    required this.title,
    required this.message,
    required this.onClose,
  });

  final String title;
  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return _DialogOverlay(
      child: _DialogBox(title: title, onClose: onClose, child: Text(message)),
    );
  }
}

class _ConfirmSettingsDialog extends StatelessWidget {
  const _ConfirmSettingsDialog({
    required this.title,
    required this.message,
    required this.onCancel,
    required this.onConfirm,
  });

  final String title;
  final String message;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

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
                  onPressed: onCancel,
                  child: Text(i18n.t('common.cancel')),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: onConfirm,
                  child: Text(i18n.t('common.confirm')),
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
  });

  final String title;
  final VoidCallback onClose;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 460,
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
    return Positioned.fill(
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
  });

  final List<PreferenceItemSnapshot> items;
  final void Function(
    PreferenceItemSnapshot item,
    PreferenceItemSnapshot update,
  )
  onUpdateItem;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;

    return _PreferenceSectionFrame(
      title: i18n.t('settings.others'),
      counter: '${items.length}',
      action: const SizedBox.shrink(),
      child: PreferenceItems(items: items, onUpdateItem: onUpdateItem),
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
  static const inputBorder = Color(0x387e8b9a);
  static const buttonSurface = Color(0xb8ffffff);
  static const dialogSurface = Color(0xfffbfdff);
  static const overlay = Color(0x47202b36);
  static const preferenceHeader = Color(0x7affffff);
  static const danger = Color(0xffb42318);
}
