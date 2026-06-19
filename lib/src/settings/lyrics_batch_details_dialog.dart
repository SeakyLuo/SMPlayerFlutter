import 'dart:io';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_repository.dart';
import 'package:smplayer_flutter/src/library/ui/popup_dialog.dart';

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

    return PopupDialog(
      overlayClassName: 'lyrics-detail-popup-overlay',
      className: 'lyrics-detail-dialog ContentDialog',
      navClassName: 'lyrics-detail-dialog-nav',
      navLabel: i18n.t('settings.lyricsBatchTaskDetails'),
      ariaLabel: i18n.t('settings.lyricsBatchTaskDetails'),
      width: 1180,
      height: 860,
      horizontalInset: 64,
      verticalInset: 64,
      onClose: widget.onClose,
      navChildren: [
        _LyricsBatchDialogTitle(i18n.t('settings.lyricsBatchTaskDetails')),
      ],
      child: LayoutBuilder(
        builder: (context, constraints) {
          final mobile = constraints.maxWidth <= popupDialogMobileBreakpoint;
          return Padding(
            key: const ValueKey('lyrics-detail-dialog-content'),
            padding:
                mobile
                    ? const EdgeInsets.fromLTRB(16, 14, 16, 0)
                    : const EdgeInsets.fromLTRB(28, 18, 28, 28),
            child: ListView.separated(
              itemBuilder: (context, index) {
                final group = groups[index];
                final collapsed = _collapsedResults.contains(group.result);
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
                      _selectedDetailId = _selectedDetailId == id ? null : id;
                    });
                  },
                );
              },
              separatorBuilder: (_, _) => SizedBox(height: mobile ? 0 : 12),
              itemCount: groups.length,
            ),
          );
        },
      ),
    );
  }
}

class _LyricsBatchDialogTitle extends StatelessWidget {
  const _LyricsBatchDialogTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = PopupDialogColors.resolve(context);
    final mobile =
        MediaQuery.sizeOf(context).width <= popupDialogMobileBreakpoint;
    return Text(
      text,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: colors.textStrong,
        fontSize: mobile ? 18 : 28,
        fontWeight: FontWeight.w700,
        height: 1.2,
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
    final colors = PopupDialogColors.resolve(context);
    final mobile =
        MediaQuery.sizeOf(context).width <= popupDialogMobileBreakpoint;
    return Column(
      children: [
        SizedBox(
          height: mobile ? 30 : 36,
          child: Row(
            children: [
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: colors.textStrong,
                  padding: EdgeInsets.symmetric(horizontal: mobile ? 6 : 8),
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
        if (!collapsed) SizedBox(height: mobile ? 0 : 8),
        if (!collapsed)
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surface.withValues(alpha: 0.72),
                border: Border.all(color: colors.border),
              ),
              child: Column(
                children: [
                  for (var index = 0; index < details.length; index++) ...[
                    _LyricsBatchDetailTile(
                      detail: details[index],
                      expanded:
                          selectedDetailId ==
                          _lyricsBatchDetailId(result, index),
                      onToggle:
                          () => onToggleDetail(
                            _lyricsBatchDetailId(result, index),
                          ),
                    ),
                    if (index != details.length - 1)
                      Divider(height: 1, color: colors.border),
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
    final colors = PopupDialogColors.resolve(context);
    final reason = _lyricsBatchReasonLabel(i18n, detail.reason);
    final overwritten = detail.result == LyricsBatchDetailResult.overwritten;
    return DecoratedBox(
      decoration: const BoxDecoration(),
      child: Column(
        children: [
          Material(
            color:
                expanded && !overwritten
                    ? colors.accent.withValues(alpha: 0.10)
                    : Colors.transparent,
            child: InkWell(
              onTap: onToggle,
              hoverColor: const Color(0xebf4f8fd),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 76),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      _LyricsBatchArtwork(thumbnailPath: detail.thumbnailPath),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              detail.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xff111827),
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
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
                                  height: 1.3,
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
                            color: const Color(0xff94a3b8),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (expanded)
            _LyricsBatchInlinePanel(
              overwritten: overwritten,
              child: _LyricsBatchExpandedDetail(detail: detail),
            ),
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
    final colors = PopupDialogColors.resolve(context);
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
        decoration: BoxDecoration(color: colors.fieldSurface),
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
      key: ValueKey('lyrics-detail-status-${result.name}'),
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

class _LyricsBatchInlinePanel extends StatelessWidget {
  const _LyricsBatchInlinePanel({
    required this.overwritten,
    required this.child,
  });

  final bool overwritten;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const ValueKey('lyrics-detail-inline-panel'),
      decoration: BoxDecoration(
        color: overwritten ? Colors.white : const Color(0xfffbfdff),
      ),
      child: Padding(
        padding:
            overwritten
                ? const EdgeInsets.fromLTRB(12, 0, 12, 12)
                : const EdgeInsets.fromLTRB(14, 0, 14, 16),
        child: child,
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
      key: ValueKey('lyrics-detail-group-count-${result.name}'),
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

    return _LyricsBatchExpandedPanel(
      overwritten: false,
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

class _LyricsBatchExpandedPanel extends StatelessWidget {
  const _LyricsBatchExpandedPanel({
    required this.overwritten,
    required this.child,
  });

  final bool overwritten;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = PopupDialogColors.resolve(context);
    return DecoratedBox(
      key: const ValueKey('lyrics-detail-expanded-panel'),
      decoration: BoxDecoration(
        color: overwritten ? Colors.transparent : colors.surface,
        borderRadius: BorderRadius.circular(overwritten ? 0 : 14),
        border: overwritten ? null : Border.all(color: const Color(0xffd6e0ee)),
      ),
      child: child,
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth <= popupDialogMobileBreakpoint;
        return _LyricsBatchExpandedPanel(
          overwritten: true,
          child: DecoratedBox(
            decoration: const BoxDecoration(color: Colors.transparent),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Color(0xfffff7ed),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0x73fdba74)),
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
                  padding: EdgeInsets.zero,
                  child:
                      mobile
                          ? Column(
                            children: [
                              _LyricsTextPreview(
                                title: i18n.t(
                                  'settings.lyricsBatchCurrentLyrics',
                                ),
                                badge: i18n.t('settings.lyricsBatchOldVersion'),
                                text: widget.source,
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: CircleAvatar(
                                  radius: 15,
                                  backgroundColor: Color(0xffeff6ff),
                                  child: Icon(
                                    FluentIcons.arrow_down_20_regular,
                                    size: 16,
                                    color: Color(0xff2563eb),
                                  ),
                                ),
                              ),
                              _LyricsTextPreview(
                                title: i18n.t('settings.lyricsBatchNewLyrics'),
                                badge: i18n.t('settings.lyricsBatchNewVersion'),
                                newBadge: true,
                                text: widget.target,
                              ),
                            ],
                          )
                          : Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _LyricsTextPreview(
                                  title: i18n.t(
                                    'settings.lyricsBatchCurrentLyrics',
                                  ),
                                  badge: i18n.t(
                                    'settings.lyricsBatchOldVersion',
                                  ),
                                  text: widget.source,
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 72,
                                ),
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
                                  title: i18n.t(
                                    'settings.lyricsBatchNewLyrics',
                                  ),
                                  badge: i18n.t(
                                    'settings.lyricsBatchNewVersion',
                                  ),
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
      },
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
    final colors = PopupDialogColors.resolve(context);
    return DecoratedBox(
      key: const ValueKey('lyrics-detail-text-preview'),
      decoration: BoxDecoration(
        color: const Color(0xb8f8fafc),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xffd6e0ee)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: colors.textStrong,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (badge case final badge?)
                  Container(
                    constraints: const BoxConstraints(minHeight: 24),
                    padding: const EdgeInsets.symmetric(horizontal: 9),
                    decoration: BoxDecoration(
                      color:
                          newBadge
                              ? const Color(0xffdbeafe)
                              : const Color(0xffe2e8f0),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    alignment: Alignment.center,
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
              ],
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 120, maxHeight: 360),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Text(
                text.trim().isEmpty
                    ? i18n.t('settings.lyricsBatchDetailNoLyrics')
                    : text,
                style: TextStyle(
                  color: newBadge ? const Color(0xff1f3b64) : colors.textStrong,
                  fontFamily: 'monospace',
                  fontSize: 13,
                  height: 1.75,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _lyricsBatchDetailId(LyricsBatchDetailResult result, int index) {
  return '${result.index}-$index';
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
