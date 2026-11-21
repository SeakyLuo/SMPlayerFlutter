part of 'settings_page.dart';

extension _SettingsLyricsBatchActions on _SettingsPageState {
  Future<void> _startLyricsBatch(SmPlayerI18n i18n) async {
    if (_sharedLyricsBatchState.changingOverwrite) return;
    _sharedLyricsBatchState.liveDetails.clear();
    _updateSettingsPageState(() {
      _showLyricsBatchOptions = false;
      _lyricsBatchRunning = true;
      _lyricsBatchCancelRequested = false;
      _lyricsBatchPaused = false;
      _lyricsBatchCanceled = false;
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
          _updateSettingsPageState(() {
            _lyricsBatchProgress = progress;
          });
        },
        onDetailCompleted: (detail, progress) {
          _sharedLyricsBatchState.update(() {
            _sharedLyricsBatchState.liveDetails.add(detail);
            _sharedLyricsBatchState.progress = progress;
            _sharedLyricsBatchState.result = LyricsBatchResult(
              total: progress.total,
              saved: progress.saved,
              overwritten: progress.overwritten,
              skipped: progress.skipped,
              missing: progress.missing,
              failed: progress.failed,
              backedUp: progress.backedUp,
              backupBytes: progress.backupBytes,
              details: _sharedLyricsBatchState.liveDetails,
            );
          });
        },
      );
      if (_lyricsBatchCancelRequested) {
        _lyricsBatchResult = result;
        _sharedLyricsBatchState.liveDetails.clear();
        if (mounted) {
          _updateSettingsPageState(() {
            _lyricsBatchResult = result;
          });
        }
        return;
      }
      _lyricsBatchResult = result;
      _sharedLyricsBatchState.liveDetails.clear();
      if (!mounted) return;
      _updateSettingsPageState(() {
        _lyricsBatchResult = result;
      });
      _showMessage(
        _lyricsBatchResultSummary(
          i18n,
          i18n.t('settings.lyricsBatchDone'),
          result,
        ),
        autoDismiss: false,
      );
    } catch (_) {
      if (mounted) {
        _showMessage(i18n.t('settings.lyricsBatchFailed'), autoDismiss: false);
      }
    } finally {
      _lyricsBatchRunning = false;
      _lyricsBatchCancelRequested = false;
      _lyricsBatchPaused = false;
      if (mounted) {
        _updateSettingsPageState(() {
          _lyricsBatchRunning = false;
          _lyricsBatchCancelRequested = false;
          _lyricsBatchPaused = false;
        });
      }
    }
  }

  Future<void> _changeLyricsBatchOverwrite(
    LyricsBatchDetail detail,
    SmPlayerI18n i18n,
  ) async {
    _sharedLyricsBatchState.update(() {
      _sharedLyricsBatchState.changingOverwrite = true;
    });
    try {
      final changed = await widget.libraryRepository.changeBatchLyricsOverwrite(
        detail,
      );
      if (!mounted) return;
      if (changed) {
        widget.onLyricsChanged?.call(detail.songId);
        _showMessage(
          i18n.t('song.lyricsUpdated', {'title': detail.title}),
        );
      } else {
        _showMessage(i18n.t('settings.lyricsBatchLyricsChanged'));
      }
    } catch (_) {
      if (mounted) _showMessage(i18n.t('song.updateFailed'));
    } finally {
      _sharedLyricsBatchState.update(() {
        _sharedLyricsBatchState.changingOverwrite = false;
      });
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
      _updateSettingsPageState(() {
        _lyricsBatchPaused = !_lyricsBatchPaused;
      });
      return;
    }
    _updateSettingsPageState(() {
      _showLyricsBatchOptions = !_showLyricsBatchOptions;
    });
  }

  Future<void> _waitForLyricsBatchResume() async {
    while (_lyricsBatchPaused && !_lyricsBatchCancelRequested) {
      await Future<void>.delayed(const Duration(milliseconds: 180));
    }
  }

  Future<void> _requestCancelLyricsBatch(SmPlayerI18n i18n) async {
    _updateSettingsPageState(() {
      _lyricsBatchPaused = true;
    });
    final confirmed = await showSmPlayerConfirmDialog(
      context: context,
      i18n: i18n,
      title: i18n.t('settings.lyricsBatchCancelConfirmTitle'),
      message: i18n.t('settings.lyricsBatchCancelConfirmMessage'),
      confirmText: i18n.t('settings.lyricsBatchStop'),
      cancelText: i18n.t('settings.lyricsBatchContinue'),
    );
    if (!mounted) {
      return;
    }
    if (!confirmed) {
      if (_lyricsBatchRunning) {
        _updateSettingsPageState(() {
          _lyricsBatchPaused = false;
        });
      }
      return;
    }
    if (!_lyricsBatchRunning) {
      return;
    }
    _updateSettingsPageState(() {
      _lyricsBatchCancelRequested = true;
      _lyricsBatchPaused = false;
      _lyricsBatchCanceled = true;
    });
    final result = _lyricsBatchResult;
    unawaited(
      showAppNotification(
        context: context,
        message:
            result == null
                ? i18n.t('settings.lyricsBatchStopped')
                : _lyricsBatchResultSummary(
                  i18n,
                  i18n.t('settings.lyricsBatchStopped'),
                  result,
                ),
        autoDismiss: false,
        closeOnAction: false,
        actionLabel:
            result != null && result.details.isNotEmpty
                ? i18n.t('common.detail')
                : null,
        onAction:
            result != null && result.details.isNotEmpty
                ? () {
                  if (mounted) {
                    _updateSettingsPageState(() {
                      _showLyricsBatchDetails = true;
                    });
                  }
                }
                : null,
      ),
    );
  }

  String _lyricsBatchResultSummary(
    SmPlayerI18n i18n,
    String status,
    LyricsBatchResult result,
  ) {
    final backupSummary =
        _lyricsBatchOverwrite
            ? '，${i18n.t('settings.lyricsBatchBackedUp')} '
                '${result.backedUp}（${formatSettingsBytes(result.backupBytes)}）'
            : '';
    return '$status: ${i18n.t('settings.lyricsBatchSaved')} ${result.saved} · '
        '${i18n.t('settings.lyricsBatchOverwritten')} ${result.overwritten} · '
        '${i18n.t('settings.lyricsBatchSkipped')} ${result.skipped} · '
        '${i18n.t('settings.lyricsBatchMissing')} ${result.missing} · '
        '${i18n.t('settings.lyricsBatchFailed')} ${result.failed}'
        '$backupSummary';
  }
}
