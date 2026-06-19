part of 'artist_split_review_panel.dart';

enum _ArtistSplitReviewVariant { split, merge }

class _ArtistSplitGroup extends StatefulWidget {
  const _ArtistSplitGroup({
    required this.title,
    required this.count,
    required this.items,
    required this.selectedSongIds,
    required this.artistEdits,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onToggle,
    required this.onSetGroupSelection,
    required this.onUpdateArtists,
    required this.compact,
    required this.artworkPathBySongId,
    this.disabled = false,
    this.variant = _ArtistSplitReviewVariant.split,
  });

  final String title;
  final int count;
  final List<ArtistSplitResultItem> items;
  final Set<int> selectedSongIds;
  final Map<int, List<String>> artistEdits;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final ValueChanged<int> onToggle;
  final void Function(List<ArtistSplitResultItem> items, bool selected)
  onSetGroupSelection;
  final void Function(int songId, List<String> artists) onUpdateArtists;
  final bool compact;
  final Map<int, String> artworkPathBySongId;
  final bool disabled;
  final _ArtistSplitReviewVariant variant;

  @override
  State<_ArtistSplitGroup> createState() => _ArtistSplitGroupState();
}

class _ArtistSplitGroupState extends State<_ArtistSplitGroup> {
  int? _editingSongId;

  @override
  Widget build(BuildContext context) {
    final selectedCount =
        widget.items
            .where((item) => widget.selectedSongIds.contains(item.songId))
            .length;
    final allSelected =
        widget.items.isNotEmpty && selectedCount == widget.items.length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: widget.compact ? 40 : 28,
            child:
                widget.compact
                    ? Row(
                      children: [
                        Expanded(child: _buildToggleButton(context)),
                        if (!widget.disabled) ...[
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 76,
                            child: _buildSelectButton(context, allSelected),
                          ),
                        ],
                      ],
                    )
                    : Row(
                      children: [
                        _buildToggleButton(context),
                        const Spacer(),
                        if (!widget.disabled)
                          _buildSelectButton(context, allSelected),
                      ],
                    ),
          ),
          if (widget.expanded) ...[
            const SizedBox(height: 8),
            for (final item in widget.items)
              _ArtistSplitTile(
                item: item,
                selected:
                    widget.disabled ||
                    widget.selectedSongIds.contains(item.songId),
                disabled: widget.disabled,
                editing: _editingSongId == item.songId,
                artists: widget.artistEdits[item.songId] ?? item.artists,
                variant: widget.variant,
                compact: widget.compact,
                artworkPath: widget.artworkPathBySongId[item.songId],
                onToggle: () => widget.onToggle(item.songId),
                onEdit: () {
                  setState(() {
                    _editingSongId = item.songId;
                  });
                },
                onSaveEdit: () {
                  setState(() {
                    _editingSongId = null;
                  });
                },
                onUpdateArtists:
                    (artists) => widget.onUpdateArtists(item.songId, artists),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildToggleButton(BuildContext context) {
    final colors = PopupDialogColors.resolve(context);
    return TextButton(
      style: TextButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        minimumSize: Size(0, widget.compact ? 40 : 28),
        padding: EdgeInsets.symmetric(horizontal: widget.compact ? 8 : 2),
        foregroundColor: colors.textStrong,
        backgroundColor:
            widget.compact ? Colors.white.withValues(alpha: 0.72) : null,
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          fontVariations: [FontVariation.weight(760)],
        ),
        shape:
            widget.compact
                ? RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: Color(0x9ebec8d6)),
                )
                : null,
      ).copyWith(
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      onPressed: widget.onToggleExpanded,
      child: Row(
        mainAxisSize: widget.compact ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment:
            widget.compact ? MainAxisAlignment.center : MainAxisAlignment.start,
        children: [
          Icon(
            widget.expanded
                ? FluentIcons.chevron_down_20_regular
                : FluentIcons.chevron_right_20_regular,
            size: 14,
            color: colors.textMuted,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              widget.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${widget.count}',
            style: TextStyle(
              color: colors.textMuted,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectButton(BuildContext context, bool allSelected) {
    final i18n = context.smPlayerI18n;
    final colors = PopupDialogColors.resolve(context);
    return TextButton(
      style: TextButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        minimumSize: Size(widget.compact ? 76 : 0, widget.compact ? 40 : 28),
        fixedSize: widget.compact ? const Size(76, 40) : null,
        padding: EdgeInsets.symmetric(horizontal: widget.compact ? 0 : 2),
        foregroundColor: colors.accentStrong,
        backgroundColor:
            widget.compact ? Colors.white.withValues(alpha: 0.72) : null,
        textStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          fontVariations: [FontVariation.weight(720)],
        ),
        shape:
            widget.compact
                ? RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: Color(0x9ebec8d6)),
                )
                : null,
      ).copyWith(
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      onPressed: () => widget.onSetGroupSelection(widget.items, !allSelected),
      child: Text(
        i18n.t(
          allSelected
              ? 'local.clearArtistSplitSelection'
              : 'local.selectAllArtistSplits',
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _ArtistSplitTile extends StatefulWidget {
  const _ArtistSplitTile({
    required this.item,
    required this.selected,
    required this.disabled,
    required this.editing,
    required this.artists,
    required this.variant,
    required this.onToggle,
    required this.onEdit,
    required this.onSaveEdit,
    required this.onUpdateArtists,
    required this.compact,
    required this.artworkPath,
  });

  final ArtistSplitResultItem item;
  final bool selected;
  final bool disabled;
  final bool editing;
  final List<String> artists;
  final _ArtistSplitReviewVariant variant;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onSaveEdit;
  final ValueChanged<List<String>> onUpdateArtists;
  final bool compact;
  final String? artworkPath;

  @override
  State<_ArtistSplitTile> createState() => _ArtistSplitTileState();
}

class _ArtistSplitTileState extends State<_ArtistSplitTile> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final colors = PopupDialogColors.resolve(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: MouseRegion(
        onEnter: (_) {
          setState(() {
            _hovered = true;
          });
        },
        onExit: (_) {
          setState(() {
            _hovered = false;
          });
        },
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: widget.disabled || widget.editing ? null : widget.onToggle,
          child: Container(
            constraints: BoxConstraints(minHeight: widget.editing ? 102 : 82),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color:
                  widget.selected
                      ? colors.accent.withValues(alpha: 0.12)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color:
                    widget.selected
                        ? colors.accent.withValues(alpha: 0.44)
                        : Colors.transparent,
              ),
            ),
            child: Row(
              crossAxisAlignment:
                  widget.editing
                      ? CrossAxisAlignment.start
                      : CrossAxisAlignment.center,
              children: [
                _ArtistSplitCheck(
                  selected: widget.selected,
                  disabled: widget.disabled,
                  onPressed: widget.onToggle,
                ),
                const SizedBox(width: 12),
                SizedBox.square(
                  dimension: 64,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.all(Radius.circular(7)),
                    child: SongArtwork(
                      artworkPath: widget.artworkPath,
                      fallback: const DefaultAlbumArtwork(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ArtistSplitCopy(
                    item: widget.item,
                    artists: widget.artists,
                    editing: widget.editing,
                    afterLabel:
                        widget.variant == _ArtistSplitReviewVariant.merge
                            ? i18n.t('local.artistMergeAfter')
                            : i18n.t('local.artistSplitAfter'),
                    merge: widget.variant == _ArtistSplitReviewVariant.merge,
                    onAddArtist: _addArtist,
                    onSaveEdit: widget.onSaveEdit,
                    onRemoveArtist: _removeArtist,
                    onUpdateArtist: _updateArtist,
                    compact: widget.compact,
                  ),
                ),
                const SizedBox(width: 12),
                AnimatedOpacity(
                  opacity: _hovered || widget.editing ? 1 : 0,
                  duration: const Duration(milliseconds: 140),
                  curve: Curves.easeOut,
                  child:
                      widget.editing
                          ? const SizedBox(width: 34, height: 34)
                          : _ArtistSplitIconButton(
                            icon: FluentIcons.edit_20_regular,
                            tooltip: i18n.t('common.edit'),
                            onPressed: widget.onEdit,
                          ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _addArtist() {
    if (widget.artists.length >= _maxArtistCells) {
      return;
    }
    widget.onUpdateArtists([...widget.artists, '']);
  }

  void _removeArtist(int index) {
    if (widget.artists.length > 1) {
      widget.onUpdateArtists([
        for (var i = 0; i < widget.artists.length; i += 1)
          if (i != index) widget.artists[i],
      ]);
      return;
    }
    widget.onUpdateArtists(['']);
  }

  void _updateArtist(int index, String value) {
    final nextArtists = widget.artists.toList();
    nextArtists[index] = value;
    widget.onUpdateArtists(nextArtists);
  }
}

class _ArtistSplitCheck extends StatelessWidget {
  const _ArtistSplitCheck({
    required this.selected,
    required this.disabled,
    required this.onPressed,
  });

  final bool selected;
  final bool disabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = PopupDialogColors.resolve(context);
    return Padding(
      padding: const EdgeInsets.only(top: 23),
      child: InkWell(
        borderRadius: BorderRadius.circular(5),
        onTap: disabled ? null : onPressed,
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
    required this.artists,
    required this.editing,
    required this.afterLabel,
    required this.merge,
    required this.onAddArtist,
    required this.onSaveEdit,
    required this.onRemoveArtist,
    required this.onUpdateArtist,
    required this.compact,
  });

  final ArtistSplitResultItem item;
  final List<String> artists;
  final bool editing;
  final String afterLabel;
  final bool merge;
  final VoidCallback onAddArtist;
  final VoidCallback onSaveEdit;
  final ValueChanged<int> onRemoveArtist;
  final void Function(int index, String value) onUpdateArtist;
  final bool compact;

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
          labelWidth: compact ? 44 : 48,
          child: Text(
            item.artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: colors.text, fontSize: 13),
          ),
        ),
        const SizedBox(height: 4),
        if (editing)
          _ArtistSplitEditingValue(
            label: afterLabel,
            labelWidth: compact ? 44 : 48,
            artists:
                (artists.isEmpty ? const [''] : artists)
                    .take(_maxArtistCells)
                    .toList(),
            canAdd: artists.length < _maxArtistCells,
            onAddArtist: onAddArtist,
            onSaveEdit: onSaveEdit,
            onRemoveArtist: onRemoveArtist,
            onUpdateArtist: onUpdateArtist,
          )
        else
          _ArtistSplitValueRow(
            label: afterLabel,
            labelWidth: compact ? 44 : 48,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final artist in _getEditedArtists(artists)) ...[
                    _ArtistSplitChip(label: artist, merge: merge),
                    const SizedBox(width: 5),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ArtistSplitEditingValue extends StatelessWidget {
  const _ArtistSplitEditingValue({
    required this.label,
    required this.labelWidth,
    required this.artists,
    required this.canAdd,
    required this.onAddArtist,
    required this.onSaveEdit,
    required this.onRemoveArtist,
    required this.onUpdateArtist,
  });

  final String label;
  final double labelWidth;
  final List<String> artists;
  final bool canAdd;
  final VoidCallback onAddArtist;
  final VoidCallback onSaveEdit;
  final ValueChanged<int> onRemoveArtist;
  final void Function(int index, String value) onUpdateArtist;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ArtistSplitValueRow(
          label: label,
          labelWidth: labelWidth,
          child: Row(
            children: [
              _ArtistSplitSmallIconButton(
                icon: FluentIcons.add_20_regular,
                tooltip: i18n.t('common.add'),
                onPressed: canAdd ? onAddArtist : null,
              ),
              const SizedBox(width: 5),
              _ArtistSplitSmallIconButton(
                icon: FluentIcons.checkmark_20_regular,
                tooltip: i18n.t('settings.save'),
                onPressed: onSaveEdit,
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: EdgeInsets.only(left: labelWidth + 8),
          child: _ArtistSplitEditor(
            artists: artists,
            onRemoveArtist: onRemoveArtist,
            onUpdateArtist: onUpdateArtist,
          ),
        ),
      ],
    );
  }
}

class _ArtistSplitValueRow extends StatelessWidget {
  const _ArtistSplitValueRow({
    required this.label,
    required this.child,
    required this.labelWidth,
  });

  final String label;
  final Widget child;
  final double labelWidth;

  @override
  Widget build(BuildContext context) {
    final colors = PopupDialogColors.resolve(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: labelWidth,
          child: Align(
            alignment: Alignment.centerLeft,
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
        ),
        const SizedBox(width: 8),
        Expanded(child: child),
      ],
    );
  }
}
