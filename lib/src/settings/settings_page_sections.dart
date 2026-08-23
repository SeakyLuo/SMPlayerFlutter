part of 'settings_page.dart';

// ignore_for_file: invalid_use_of_protected_member

extension _SettingsPageSections on _SettingsPageState {
  List<Widget> _buildLeftColumn(BuildContext context, SmPlayerI18n i18n) {
    final colors = SettingsPageColors.of(context);
    return [
      SettingsCard(
        title: i18n.t('library.root'),
        children: [
          Row(
            children: [
              Expanded(
                child: TooltipVisibility(
                  visible: _snapshot.rootPath.isNotEmpty,
                  child: Tooltip(
                    message: _snapshot.rootPath,
                    child: TextField(
                      enabled: false,
                      controller: TextEditingController(
                        text: _snapshot.rootPath,
                      ),
                      decoration: InputDecoration(
                        hintText: i18n.t('settings.musicFolderPlaceholder'),
                        isDense: true,
                        filled: true,
                        fillColor: colors.inputSurface,
                        disabledBorder: OutlineInputBorder(
                          borderRadius: const BorderRadius.all(
                            Radius.circular(8),
                          ),
                          borderSide: BorderSide(color: colors.inputBorder),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox.square(
                dimension: 42,
                child: _SettingsIconButton(
                  icon: FluentIcons.folder_24_regular,
                  tooltip: i18n.t('common.folders'),
                  busy: _pickingLibraryRoot,
                  onPressed:
                      widget.loading || _isScanning || _pickingLibraryRoot
                          ? null
                          : () {
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
            label: i18n.t('settings.loadUsingFilename'),
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
                _SettingsPageState._lyricsRequestModeOptions
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
                icon: FluentIcons.text_bullet_list_add_20_regular,
                disabled:
                    _lyricsBatchCancelRequested ||
                    widget.lyricsBatchSongCount == null ||
                    widget.lyricsBatchSongCount == 0,
                onClick: _handleLyricsBatchPrimaryAction,
                child: Text(_lyricsBatchPrimaryLabel(i18n)),
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
            _LyricsBatchOptionsDialog(
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
        children: [
          ToggleSettingRow(
            label: i18n.t('settings.desktopLyricsEnabled'),
            checked: _snapshot.desktopLyricsEnabled,
            onChange: (checked) {
              _updateSettings(AppSettingsUpdate(desktopLyricsEnabled: checked));
            },
          ),
          ColorSettingRow(
            label: i18n.t('settings.desktopLyricsColor'),
            value: _snapshot.desktopLyricsColor,
            onPickColor: widget.onPickColor,
            onChange: (value) {
              _updateSettings(AppSettingsUpdate(desktopLyricsColor: value));
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
            searchPlaceholder: i18n.t('settings.desktopLyricsFontSearch'),
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
              _updateSettings(AppSettingsUpdate(desktopLyricsFontSize: value));
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
              _updateSettings(AppSettingsUpdate(desktopLyricsOpacity: value));
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
                child: Text(i18n.t('settings.desktopLyricsRestoreDefaults')),
              ),
            ],
          ),
        ],
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
            label: i18n.t('settings.previousButtonRestartsTrack'),
            checked: _snapshot.previousButtonRestartsTrack,
            onChange: (checked) {
              _updateSettings(
                AppSettingsUpdate(previousButtonRestartsTrack: checked),
              );
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
}
