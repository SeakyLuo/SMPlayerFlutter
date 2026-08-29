import 'dart:ui' show ImageFilter;

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:smplayer_flutter/src/app/clipped_rounded_surface.dart';

import '../../i18n/app_i18n.dart';
import '../data/library_models.dart';
import 'local_folder_model.dart';
import 'local_page_quick_jump.dart';

class ScanProgressOverlay extends StatefulWidget {
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
  State<ScanProgressOverlay> createState() => _ScanProgressOverlayState();
}

class _ScanProgressOverlayState extends State<ScanProgressOverlay> {
  final _overlayController = OverlayPortalController(
    debugLabel: 'ScanProgressOverlay',
  );

  String get title => widget.title;
  LocalFolderRefreshProgress get progress => widget.progress;
  VoidCallback? get onCancel => widget.onCancel;

  @override
  void initState() {
    super.initState();
    _overlayController.show();
  }

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      controller: _overlayController,
      overlayLocation: OverlayChildLocation.rootOverlay,
      overlayChildBuilder: _buildOverlay,
      child: const SizedBox.shrink(),
    );
  }

  Widget _buildOverlay(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final colors = LocalPageColors.of(context);
    final nightMode = Theme.of(context).brightness == Brightness.dark;
    final stageValue =
        (progress.current / progress.total).clamp(0, 1).toDouble();
    final value = switch (progress.stage) {
      LocalFolderRefreshStage.checking => stageValue * 0.90,
      LocalFolderRefreshStage.reading => 0.90 + stageValue * 0.08,
      LocalFolderRefreshStage.updating => 0.98 + stageValue * 0.02,
    };
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

    return Positioned.fill(
      child: FocusScope(
        autofocus: true,
        child: Material(
          color: Colors.transparent,
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: ColoredBox(
                color:
                    nightMode
                        ? const Color(0x7004080d)
                        : const Color(0x47181e26),
                child: Semantics(
                  label: title,
                  namesRoute: true,
                  scopesRoute: true,
                  explicitChildNodes: true,
                  child: SafeArea(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          padding: const EdgeInsets.fromLTRB(34, 28, 34, 26),
                          decoration: BoxDecoration(
                            color:
                                nightMode
                                    ? const Color(0xf0161c24)
                                    : const Color(0xf0ffffff),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color:
                                  nightMode
                                      ? const Color(0x24d6e0ec)
                                      : const Color(0xb3ccd5e0),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    nightMode
                                        ? const Color(0x7a000000)
                                        : const Color(0x3d1a2738),
                                blurRadius: 80,
                                offset: const Offset(0, 26),
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
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: colors.accentSoft,
                                    ),
                                    child: _LocalRefreshSpinner(
                                      color: colors.accentStrong,
                                    ),
                                  ),
                                  const SizedBox(width: 18),
                                  Expanded(
                                    child: Text(
                                      title,
                                      style: TextStyle(
                                        color: colors.textStrong,
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
                                padding: const EdgeInsets.fromLTRB(
                                  22,
                                  20,
                                  22,
                                  20,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      nightMode
                                          ? const Color(0xb8121820)
                                          : const Color(0x94ffffff),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color:
                                        nightMode
                                            ? const Color(0x24d6e0ec)
                                            : const Color(0xb8ccd5e0),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        _LocalRefreshPercent(
                                          value: value,
                                          percent: percent,
                                        ),
                                        const SizedBox(width: 18),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                stageText,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: colors.textStrong,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              const SizedBox(height: 7),
                                              Text(
                                                _progressDescription(i18n),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: colors.textMuted,
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
                                      onPressed:
                                          progress.canCancel ? onCancel : null,
                                      style: OutlinedButton.styleFrom(
                                        minimumSize: const Size(160, 48),
                                        foregroundColor: const Color(
                                          0xffdc2626,
                                        ),
                                        disabledForegroundColor: const Color(
                                          0x9e5b697a,
                                        ),
                                        side: const BorderSide(
                                          color: Color(0x3ddc2626),
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        textStyle: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      child: Text(
                                        i18n.t(
                                          'local.updateFolderProgressStop',
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
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

class _LocalRefreshSpinner extends StatefulWidget {
  const _LocalRefreshSpinner({required this.color});

  final Color color;

  @override
  State<_LocalRefreshSpinner> createState() => _LocalRefreshSpinnerState();
}

class _LocalRefreshSpinnerState extends State<_LocalRefreshSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: Icon(
        FluentIcons.arrow_sync_24_regular,
        color: widget.color,
        size: 30,
      ),
    );
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
    final colors = LocalPageColors.of(context);
    final nightMode = Theme.of(context).brightness == Brightness.dark;
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
              backgroundColor:
                  nightMode ? const Color(0x24d6e0ec) : const Color(0x297e8b9a),
              color: colors.accentStrong,
            ),
          ),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:
                  nightMode ? const Color(0xff19212c) : const Color(0xffeef4fc),
            ),
          ),
          Text(
            '$percent%',
            style: TextStyle(
              color: colors.textStrong,
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
    final colors = LocalPageColors.of(context);
    final nightMode = Theme.of(context).brightness == Brightness.dark;
    return SmPlayerClippedRoundedSurface(
      color: nightMode ? const Color(0x12ffffff) : const Color(0x94ffffff),
      radius: 8,
      borderSide: BorderSide(
        color: nightMode ? const Color(0x24d6e0ec) : const Color(0xb3ccd5e0),
      ),
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
            valueColor: colors.accentStrong,
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
    final nightMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 1,
      height: 42,
      color: nightMode ? const Color(0x24d6e0ec) : const Color(0xb3ccd5e0),
    );
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
    final colors = LocalPageColors.of(context);
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
                style: TextStyle(
                  color: colors.textMuted,
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
                style: TextStyle(
                  color: colors.textMuted,
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
