import 'dart:io';
import 'dart:math' as math;

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_repository.dart';
import 'package:smplayer_flutter/src/settings/settings_colors.dart';
import 'package:smplayer_flutter/src/settings/settings_dialog_shell.dart';

const _lyricsBatchDetailResultOrder = [
  LyricsBatchDetailResult.overwritten,
  LyricsBatchDetailResult.saved,
  LyricsBatchDetailResult.skipped,
  LyricsBatchDetailResult.missing,
  LyricsBatchDetailResult.failed,
];

class LyricsBatchDetailsDialog extends StatefulWidget {
  const LyricsBatchDetailsDialog({
    super.key,
    required this.result,
    required this.onClose,
  });

  final LyricsBatchResult result;
  final VoidCallback onClose;

  @override
  State<LyricsBatchDetailsDialog> createState() =>
      _LyricsBatchDetailsDialogState();
}

class _LyricsBatchDetailsDialogState extends State<LyricsBatchDetailsDialog> {
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

    return SettingsDialogOverlay(
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
                  child: SettingsDialogHeader(
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
