part of 'settings_page.dart';

class _LyricsBatchOptionsDialog extends StatelessWidget {
  const _LyricsBatchOptionsDialog({
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
    return PopupDialog(
      className: 'lyrics-batch-options-dialog ContentDialog',
      navClassName: 'lyrics-batch-options-dialog-nav',
      navLabel: i18n.t('settings.batchAddLyrics'),
      ariaLabel: i18n.t('settings.batchAddLyrics'),
      width: 430,
      height: 220,
      closeOnBackdrop: true,
      onClose: onCancel,
      navChildren: [
        Expanded(child: PopupDialogTitle(i18n.t('settings.batchAddLyrics'))),
      ],
      footer: PopupDialogActions(
        children: [
          PopupDialogActionButton(
            label: i18n.t('common.start'),
            primary: true,
            onPressed: onStart,
          ),
          PopupDialogActionButton(
            label: i18n.t('common.cancel'),
            onPressed: onCancel,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 0, 28, 0),
        child: _LyricsBatchOptionsContent(
          overwrite: overwrite,
          onOverwriteChanged: onOverwriteChanged,
        ),
      ),
    );
  }
}

class _LyricsBatchOptionsContent extends StatelessWidget {
  const _LyricsBatchOptionsContent({
    required this.overwrite,
    required this.onOverwriteChanged,
  });

  final bool overwrite;
  final ValueChanged<bool> onOverwriteChanged;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: ToggleSettingRow(
          label: i18n.t('settings.lyricsBatchOverwriteToggle'),
          checked: overwrite,
          onChange: onOverwriteChanged,
        ),
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
