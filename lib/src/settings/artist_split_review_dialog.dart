import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/ui/default_album_artwork.dart';
import 'package:smplayer_flutter/src/library/ui/popup_dialog.dart';

List<ArtistSplitResultItem> _splitItems(ArtistSplitAnalysisResult result) {
  return [
    ...result.directSplits,
    ...result.possibleSplits,
    ...result.mergeSuggestions,
  ];
}

class ArtistSplitReviewDialog extends StatefulWidget {
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
  final ValueChanged<List<ArtistSplitResultItem>> onApply;

  @override
  State<ArtistSplitReviewDialog> createState() =>
      _ArtistSplitReviewDialogState();
}

class _ArtistSplitReviewDialogState extends State<ArtistSplitReviewDialog> {
  late final Set<int> _selectedSongIds;
  var _directExpanded = true;
  var _possibleExpanded = true;
  var _mergeExpanded = true;

  @override
  void initState() {
    super.initState();
    _selectedSongIds = {
      for (final item in widget.result.directSplits) item.songId,
    };
  }

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final splitItems = _splitItems(widget.result);
    final selectedSplits =
        splitItems
            .where((item) => _selectedSongIds.contains(item.songId))
            .toList();

    return PopupDialog(
      navLabel: i18n.t('local.startupArtistSplitSuggestionsTitle'),
      ariaLabel: i18n.t('local.startupArtistSplitSuggestionsTitle'),
      width: 760,
      height: 640,
      onClose: widget.applying ? () {} : widget.onCancel,
      navChildren: [
        Expanded(
          child: PopupDialogTitle(
            i18n.t('local.startupArtistSplitSuggestionsTitle'),
          ),
        ),
      ],
      footer: Padding(
        padding: const EdgeInsets.fromLTRB(28, 9, 28, 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            PopupDialogActionButton(
              label: i18n.t('local.keepArtistSplits'),
              onPressed: widget.applying ? null : widget.onCancel,
            ),
            const SizedBox(width: 10),
            PopupDialogActionButton(
              label:
                  widget.applying
                      ? i18n.t('local.applyingArtistSplits')
                      : i18n.t('local.applySelectedArtistSplits', {
                        'count': selectedSplits.length,
                      }),
              primary: true,
              loading: widget.applying,
              onPressed:
                  widget.applying || selectedSplits.isEmpty
                      ? null
                      : () => widget.onApply(selectedSplits),
            ),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 0, 28, 0),
        child: ClipRect(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(right: 4, bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.result.directSplits.isNotEmpty)
                  _ArtistSplitGroup(
                    title: i18n.t('local.directArtistSplitsTitle'),
                    count: widget.result.directSplits.length,
                    items: widget.result.directSplits,
                    selectedSongIds: _selectedSongIds,
                    expanded: _directExpanded,
                    onToggleExpanded:
                        () => setState(() {
                          _directExpanded = !_directExpanded;
                        }),
                    onToggle: _toggleSplit,
                    onSetGroupSelection: _setGroupSelection,
                  ),
                if (widget.result.possibleSplits.isNotEmpty)
                  _ArtistSplitGroup(
                    title: i18n.t('local.refreshArtistSplitSuggestionsTitle'),
                    count: widget.result.possibleSplits.length,
                    items: widget.result.possibleSplits,
                    selectedSongIds: _selectedSongIds,
                    expanded: _possibleExpanded,
                    onToggleExpanded:
                        () => setState(() {
                          _possibleExpanded = !_possibleExpanded;
                        }),
                    onToggle: _toggleSplit,
                    onSetGroupSelection: _setGroupSelection,
                  ),
                if (widget.result.mergeSuggestions.isNotEmpty)
                  _ArtistSplitGroup(
                    title: i18n.t('local.artistMergeSuggestionsTitle'),
                    count: widget.result.mergeSuggestions.length,
                    items: widget.result.mergeSuggestions,
                    selectedSongIds: _selectedSongIds,
                    expanded: _mergeExpanded,
                    variant: _ArtistSplitReviewVariant.merge,
                    onToggleExpanded:
                        () => setState(() {
                          _mergeExpanded = !_mergeExpanded;
                        }),
                    onToggle: _toggleSplit,
                    onSetGroupSelection: _setGroupSelection,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _toggleSplit(int songId) {
    setState(() {
      if (!_selectedSongIds.add(songId)) {
        _selectedSongIds.remove(songId);
      }
    });
  }

  void _setGroupSelection(List<ArtistSplitResultItem> items, bool selected) {
    setState(() {
      for (final item in items) {
        if (selected) {
          _selectedSongIds.add(item.songId);
        } else {
          _selectedSongIds.remove(item.songId);
        }
      }
    });
  }
}

enum _ArtistSplitReviewVariant { split, merge }

class _ArtistSplitGroup extends StatelessWidget {
  const _ArtistSplitGroup({
    required this.title,
    required this.count,
    required this.items,
    required this.selectedSongIds,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onToggle,
    required this.onSetGroupSelection,
    this.variant = _ArtistSplitReviewVariant.split,
  });

  final String title;
  final int count;
  final List<ArtistSplitResultItem> items;
  final Set<int> selectedSongIds;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final ValueChanged<int> onToggle;
  final void Function(List<ArtistSplitResultItem> items, bool selected)
  onSetGroupSelection;
  final _ArtistSplitReviewVariant variant;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final allSelected =
        items.isNotEmpty &&
        items.every((item) => selectedSongIds.contains(item.songId));

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              TextButton(
                style: TextButton.styleFrom(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  minimumSize: const Size(0, 32),
                  padding: EdgeInsets.zero,
                  foregroundColor:
                      PopupDialogColors.resolve(context).textStrong,
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ).copyWith(
                  overlayColor: const WidgetStatePropertyAll(
                    Colors.transparent,
                  ),
                ),
                onPressed: onToggleExpanded,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      expanded
                          ? FluentIcons.chevron_down_20_regular
                          : FluentIcons.chevron_right_20_regular,
                      size: 14,
                      color: PopupDialogColors.resolve(context).textMuted,
                    ),
                    const SizedBox(width: 7),
                    Text(title),
                    const SizedBox(width: 7),
                    Text(
                      '$count',
                      style: TextStyle(
                        color: PopupDialogColors.resolve(context).textMuted,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              TextButton(
                style: TextButton.styleFrom(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  minimumSize: const Size(0, 28),
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  foregroundColor:
                      PopupDialogColors.resolve(context).accentStrong,
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onPressed: () => onSetGroupSelection(items, !allSelected),
                child: Text(
                  i18n.t(
                    allSelected
                        ? 'local.clearArtistSplitSelection'
                        : 'local.selectAllArtistSplits',
                  ),
                ),
              ),
            ],
          ),
          if (expanded) ...[
            const SizedBox(height: 6),
            for (final item in items)
              _ArtistSplitTile(
                item: item,
                selected: selectedSongIds.contains(item.songId),
                variant: variant,
                onToggle: () => onToggle(item.songId),
              ),
          ],
        ],
      ),
    );
  }
}

class _ArtistSplitTile extends StatelessWidget {
  const _ArtistSplitTile({
    required this.item,
    required this.selected,
    required this.variant,
    required this.onToggle,
  });

  final ArtistSplitResultItem item;
  final bool selected;
  final _ArtistSplitReviewVariant variant;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final colors = PopupDialogColors.resolve(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onToggle,
        child: Container(
          constraints: const BoxConstraints(minHeight: 82),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color:
                selected
                    ? colors.accent.withValues(alpha: 0.12)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color:
                  selected
                      ? colors.accent.withValues(alpha: 0.44)
                      : Colors.transparent,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _ArtistSplitCheck(selected: selected, onPressed: onToggle),
              const SizedBox(width: 12),
              const SizedBox.square(
                dimension: 64,
                child: ClipRRect(
                  borderRadius: BorderRadius.all(Radius.circular(7)),
                  child: DefaultAlbumArtwork(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ArtistSplitCopy(
                  item: item,
                  afterLabel:
                      variant == _ArtistSplitReviewVariant.merge
                          ? i18n.t('local.artistMergeAfter')
                          : i18n.t('local.artistSplitAfter'),
                  merge: variant == _ArtistSplitReviewVariant.merge,
                ),
              ),
              const SizedBox(width: 12),
              _ArtistSplitIconButton(
                icon: FluentIcons.edit_20_regular,
                tooltip: i18n.t('common.edit'),
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArtistSplitCheck extends StatelessWidget {
  const _ArtistSplitCheck({required this.selected, required this.onPressed});

  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = PopupDialogColors.resolve(context);
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(5),
        onTap: onPressed,
        child: Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: selected ? colors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color:
                  selected
                      ? colors.accent.withValues(alpha: 0.92)
                      : const Color(0x7a7e8b9a),
            ),
          ),
          child:
              selected
                  ? const Icon(
                    FluentIcons.checkmark_16_regular,
                    size: 13,
                    color: Colors.white,
                  )
                  : null,
        ),
      ),
    );
  }
}

class _ArtistSplitCopy extends StatelessWidget {
  const _ArtistSplitCopy({
    required this.item,
    required this.afterLabel,
    required this.merge,
  });

  final ArtistSplitResultItem item;
  final String afterLabel;
  final bool merge;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final colors = PopupDialogColors.resolve(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          item.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: colors.textStrong,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        _ArtistSplitValueRow(
          label: i18n.t('local.artistSplitOriginal'),
          child: Text(
            item.artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: colors.text, fontSize: 13),
          ),
        ),
        const SizedBox(height: 4),
        _ArtistSplitValueRow(
          label: afterLabel,
          child: Wrap(
            spacing: 5,
            runSpacing: 4,
            children: [
              for (final artist in item.artists)
                _ArtistSplitChip(label: artist, merge: merge),
            ],
          ),
        ),
      ],
    );
  }
}

class _ArtistSplitValueRow extends StatelessWidget {
  const _ArtistSplitValueRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = PopupDialogColors.resolve(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 48,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: child),
      ],
    );
  }
}

class _ArtistSplitChip extends StatelessWidget {
  const _ArtistSplitChip({required this.label, required this.merge});

  final String label;
  final bool merge;

  @override
  Widget build(BuildContext context) {
    final colors = PopupDialogColors.resolve(context);
    final color = merge ? const Color(0xffdc2626) : colors.accentStrong;
    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: merge ? 0.14 : 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          fontStyle: FontStyle.normal,
        ),
      ),
    );
  }
}

class _ArtistSplitIconButton extends StatelessWidget {
  const _ArtistSplitIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = PopupDialogColors.resolve(context);
    return Tooltip(
      message: tooltip,
      child: IconButton(
        style: IconButton.styleFrom(
          fixedSize: const Size.square(34),
          padding: EdgeInsets.zero,
          foregroundColor: colors.textStrong,
          backgroundColor: Colors.white.withValues(alpha: 0.72),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Color(0x387e8b9a)),
          ),
        ),
        icon: Icon(icon, size: 15),
        onPressed: onPressed,
      ),
    );
  }
}
