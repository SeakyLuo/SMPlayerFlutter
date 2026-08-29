import 'dart:io';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:smplayer_flutter/src/app/clipped_rounded_surface.dart';
import 'package:smplayer_flutter/src/app/smplayer_auto_hide_scrollbar.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_repository.dart';
import 'package:smplayer_flutter/src/library/ui/popup_dialog.dart';

part 'lyrics_batch_details_dialog_colors.dart';

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
    this.onClear,
  });

  final LyricsBatchResult result;
  final VoidCallback onClose;
  final VoidCallback? onClear;

  @override
  State<LyricsBatchDetailsDialog> createState() =>
      _LyricsBatchDetailsDialogState();
}

class _LyricsBatchDetailsDialogState extends State<LyricsBatchDetailsDialog> {
  String? _selectedDetailId;
  final _collapsedResults = <LyricsBatchDetailResult>{};
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

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
      borderRadius: 18,
      onClose: widget.onClose,
      navChildren: [
        _LyricsBatchDialogTitle(i18n.t('settings.lyricsBatchTaskDetails')),
      ],
      footer:
          widget.onClear == null
              ? null
              : _LyricsBatchDetailsFooter(
                label: i18n.t('common.clear'),
                onClear: widget.onClear!,
              ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final mobile = constraints.maxWidth <= popupDialogMobileBreakpoint;
          final scrollbarGutter = mobile ? 16.0 : 28.0;
          return Padding(
            key: const ValueKey('lyrics-detail-dialog-content'),
            padding:
                mobile
                    ? const EdgeInsets.fromLTRB(16, 14, 0, 0)
                    : const EdgeInsets.fromLTRB(28, 18, 0, 28),
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(
                context,
              ).copyWith(scrollbars: false),
              child: SmPlayerAutoHideScrollbar(
                controller: _scrollController,
                crossAxisMargin: (scrollbarGutter - 7) / 2,
                child: Padding(
                  padding: EdgeInsets.only(right: scrollbarGutter),
                  child: ListView.separated(
                    controller: _scrollController,
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
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemCount: groups.length,
                  ),
                ),
              ),
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
    final colors = PopupDialogColors.resolve(context);
    final detailColors = _LyricsBatchDetailsColors.resolve(context);
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
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _LyricsBatchHeaderCountPill(
                result: result,
                count: details.length,
              ),
            ],
          ),
        ),
        if (!collapsed) const SizedBox(height: 8),
        if (!collapsed)
          SmPlayerClippedRoundedSurface(
            color: detailColors.listSurface,
            radius: 14,
            borderSide: BorderSide(color: detailColors.listBorder),
            child: Column(
              children: [
                for (var index = 0; index < details.length; index++) ...[
                  _LyricsBatchDetailTile(
                    detail: details[index],
                    expanded:
                        selectedDetailId == _lyricsBatchDetailId(result, index),
                    onToggle:
                        () =>
                            onToggleDetail(_lyricsBatchDetailId(result, index)),
                  ),
                  if (index != details.length - 1)
                    Divider(height: 1, color: detailColors.rowBorder),
                ],
              ],
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
    final colors = _LyricsBatchDetailsColors.resolve(context);
    final reason = _lyricsBatchReasonLabel(i18n, detail.reason);
    final overwritten = detail.result == LyricsBatchDetailResult.overwritten;
    return DecoratedBox(
      decoration: const BoxDecoration(),
      child: Column(
        children: [
          ColoredBox(
            color: colors.rowSurface,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onToggle,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 76),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        _LyricsBatchArtwork(
                          thumbnailPath: detail.thumbnailPath,
                        ),
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
                                style: TextStyle(
                                  color: colors.title,
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
                                    color: colors.subtitle,
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
                              color: colors.chevron,
                            ),
                          ],
                        ),
                      ],
                    ),
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

class _LyricsBatchInlinePanel extends StatelessWidget {
  const _LyricsBatchInlinePanel({
    required this.overwritten,
    required this.child,
  });

  final bool overwritten;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = _LyricsBatchDetailsColors.resolve(context);
    return DecoratedBox(
      key: const ValueKey('lyrics-detail-inline-panel'),
      decoration: BoxDecoration(
        color: overwritten ? colors.overwrittenInlinePanel : colors.inlinePanel,
      ),
      child: Padding(
        padding:
            overwritten
                ? const EdgeInsets.fromLTRB(12, 14, 12, 12)
                : const EdgeInsets.fromLTRB(16, 16, 16, 20),
        child: child,
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
      return _LyricsBatchOverwriteDetail(source: source, target: target);
    }

    return _LyricsTextPreview(
      title:
          target.trim().isNotEmpty
              ? i18n.t('settings.lyricsBatchDetailWrittenLyrics')
              : i18n.t('settings.lyricsBatchCurrentLyrics'),
      text: target.trim().isNotEmpty ? target : source,
      plain: true,
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
    final colors = _LyricsBatchDetailsColors.resolve(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth <= popupDialogMobileBreakpoint;
        return Column(
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: colors.overwriteBannerBackground,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colors.overwriteBannerBorder),
              ),
              child: Row(
                children: [
                  Icon(
                    FluentIcons.info_24_regular,
                    size: 16,
                    color: colors.overwriteBannerIcon,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      i18n.t('settings.lyricsBatchOverwriteWarning'),
                      style: TextStyle(
                        color: colors.overwriteBannerText,
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
                              ? colors.overwriteCanceledText
                              : colors.overwriteButtonText,
                      backgroundColor:
                          _canceled
                              ? colors.overwriteCanceledBackground
                              : colors.overwriteButtonBackground,
                      side: BorderSide(
                        color:
                            _canceled
                                ? colors.overwriteCanceledBorder
                                : colors.overwriteButtonBorder,
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
                            title: i18n.t('settings.lyricsBatchCurrentLyrics'),
                            badge: i18n.t('settings.lyricsBatchOldVersion'),
                            text: widget.source,
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: CircleAvatar(
                              radius: 15,
                              backgroundColor: colors.compareArrowBackground,
                              child: Icon(
                                FluentIcons.arrow_down_20_regular,
                                size: 16,
                                color: colors.compareArrow,
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
                              badge: i18n.t('settings.lyricsBatchOldVersion'),
                              text: widget.source,
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 72,
                            ),
                            child: CircleAvatar(
                              radius: 15,
                              backgroundColor: colors.compareArrowBackground,
                              child: Icon(
                                FluentIcons.arrow_right_20_regular,
                                size: 16,
                                color: colors.compareArrow,
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
    this.plain = false,
  });

  final String title;
  final String text;
  final String? badge;
  final bool newBadge;
  final bool plain;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final popupColors = PopupDialogColors.resolve(context);
    final colors = _LyricsBatchDetailsColors.resolve(context);
    return DecoratedBox(
      key: const ValueKey('lyrics-detail-text-preview'),
      decoration: BoxDecoration(
        color: plain ? Colors.transparent : colors.previewBackground,
        borderRadius: BorderRadius.circular(plain ? 0 : 12),
        border: plain ? null : Border.all(color: colors.previewBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding:
                plain
                    ? const EdgeInsets.fromLTRB(12, 0, 12, 8)
                    : const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: popupColors.textStrong,
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
                              ? colors.newBadgeBackground
                              : colors.oldBadgeBackground,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      badge,
                      style: TextStyle(
                        color:
                            newBadge
                                ? colors.newBadgeText
                                : colors.oldBadgeText,
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
              padding:
                  plain
                      ? const EdgeInsets.fromLTRB(12, 8, 12, 4)
                      : const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Text(
                text.trim().isEmpty
                    ? i18n.t('settings.lyricsBatchDetailNoLyrics')
                    : text,
                style: TextStyle(
                  color: popupColors.textStrong,
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
