import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';

import '../../i18n/app_i18n.dart';
import '../data/library_models.dart';
import 'local_folder_model.dart';
import 'local_page_quick_jump.dart';

class ScanProgressOverlay extends StatelessWidget {
  const ScanProgressOverlay({
    super.key,
    required this.title,
    required this.progress,
    required this.onCancel,
  });

  final String title;
  final LocalFolderRefreshProgress progress;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final value = (progress.current / progress.total).clamp(0, 1).toDouble();
    final percent = (value * 100).round();
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

    return ColoredBox(
      color: const Color(0x38121b26),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.fromLTRB(34, 28, 34, 26),
            decoration: BoxDecoration(
              color: const Color(0xf0ffffff),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xb3ccd5e0)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x3d1a2738),
                  blurRadius: 80,
                  offset: Offset(0, 26),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0x210078d7),
                      ),
                      child: const Icon(
                        FluentIcons.arrow_sync_24_regular,
                        color: LocalPageColors.accentStrong,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: LocalPageColors.textStrong,
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                Container(
                  padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
                  decoration: BoxDecoration(
                    color: const Color(0x94ffffff),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xb8ccd5e0)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _LocalRefreshPercent(value: value, percent: percent),
                          const SizedBox(width: 18),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  stageText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: LocalPageColors.textStrong,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 7),
                                Text(
                                  _progressDescription(i18n),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: LocalPageColors.textMuted,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _LocalRefreshStats(progress: progress),
                    ],
                  ),
                ),
                if (onCancel != null) ...[
                  const SizedBox(height: 28),
                  Center(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: progress.canCancel ? onCancel : null,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(160, 48),
                          foregroundColor: const Color(0xffdc2626),
                          disabledForegroundColor: const Color(0x9e5b697a),
                          side: const BorderSide(color: Color(0x3ddc2626)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: Text(i18n.t('local.updateFolderProgressStop')),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _progressDescription(SmPlayerI18n i18n) {
    if (progress.stage == LocalFolderRefreshStage.checking) {
      final folderName =
          progress.currentPath.isEmpty
              ? i18n.t('local.updateFolderProgressPreparing')
              : getUpdateResultCurrentPathName(progress.currentPath);
      return [
        i18n.t('local.updateFolderProgressCurrentFolder', {'name': folderName}),
        i18n.t('local.updateFolderProgressChecked', {
          'count': progress.checkedFolderCount,
          'total': progress.folderCount,
        }),
      ].join(' · ');
    }
    if (progress.stage == LocalFolderRefreshStage.updating) {
      return i18n.t('local.updateFolderProgressProcessedItems', {
        'count': progress.current,
        'total': progress.total,
      });
    }
    return i18n.t('local.updateFolderProgressProcessedSongs', {
      'count': progress.processedSongCount,
      'total': progress.songCount,
    });
  }
}

String getUpdateResultCurrentPathName(String filePath) {
  final name = normalizePath(filePath).split('/').last;
  final extensionIndex = name.lastIndexOf('.');
  return extensionIndex > 0 ? name.substring(0, extensionIndex) : name;
}

class _LocalRefreshPercent extends StatelessWidget {
  const _LocalRefreshPercent({required this.value, required this.percent});

  final double value;
  final int percent;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 76,
      height: 76,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 76,
            height: 76,
            child: CircularProgressIndicator(
              value: value,
              strokeWidth: 16,
              strokeCap: StrokeCap.butt,
              backgroundColor: const Color(0x297e8b9a),
              color: LocalPageColors.accentStrong,
            ),
          ),
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xffeef4fc),
            ),
          ),
          Text(
            '$percent%',
            style: const TextStyle(
              color: LocalPageColors.textStrong,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _LocalRefreshStats extends StatelessWidget {
  const _LocalRefreshStats({required this.progress});

  final LocalFolderRefreshProgress progress;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0x94ffffff),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xb3ccd5e0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          _LocalRefreshStat(
            label: i18n.t('local.updateFolderProgressAdded'),
            value: progress.addedCount,
            valueColor: const Color(0xff059669),
          ),
          const _LocalRefreshDivider(),
          _LocalRefreshStat(
            label: i18n.t('local.updateFolderProgressUpdated'),
            value: progress.updatedCount,
            valueColor: LocalPageColors.accentStrong,
          ),
          const _LocalRefreshDivider(),
          _LocalRefreshStat(
            label: i18n.t('local.updateFolderProgressMissing'),
            value: progress.missingCount,
            valueColor: const Color(0xffdc2626),
          ),
        ],
      ),
    );
  }
}

class _LocalRefreshDivider extends StatelessWidget {
  const _LocalRefreshDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 42, color: const Color(0xb3ccd5e0));
  }
}

class _LocalRefreshStat extends StatelessWidget {
  const _LocalRefreshStat({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String label;
  final int value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    final unit = context.smPlayerI18n.t('local.updateFolderProgressSongUnit');
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          textBaseline: TextBaseline.alphabetic,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: LocalPageColors.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '$value',
              style: TextStyle(
                color: valueColor,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                unit,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: LocalPageColors.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
