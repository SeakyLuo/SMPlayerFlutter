import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';

import 'recent_page_model.dart';

class RecentSearchList extends StatelessWidget {
  const RecentSearchList({
    super.key,
    required this.entries,
    required this.multiSelect,
    required this.selectedEntryIds,
    required this.onSearch,
    required this.onToggleSelection,
    required this.onRemove,
    required this.onOpenContextMenu,
  });

  final List<SearchHistoryEntry> entries;
  final bool multiSelect;
  final Set<int> selectedEntryIds;
  final ValueChanged<SearchHistoryEntry> onSearch;
  final ValueChanged<int> onToggleSelection;
  final ValueChanged<int> onRemove;
  final void Function(Offset position, SearchHistoryEntry entry)
  onOpenContextMenu;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Center(
        child: Text(
          '没有最近搜索',
          style: TextStyle(color: _RecentSearchColors.textMuted),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 2, 22, 88),
      itemExtent: 56,
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return _RecentSearchRow(
          entry: entry,
          selected: selectedEntryIds.contains(entry.id),
          multiSelect: multiSelect,
          onSearch: () {
            onSearch(entry);
          },
          onToggleSelection: () {
            onToggleSelection(entry.id);
          },
          onRemove: () {
            onRemove(entry.id);
          },
          onOpenContextMenu: (position) {
            onOpenContextMenu(position, entry);
          },
        );
      },
    );
  }
}

class _RecentSearchRow extends StatefulWidget {
  const _RecentSearchRow({
    required this.entry,
    required this.selected,
    required this.multiSelect,
    required this.onSearch,
    required this.onToggleSelection,
    required this.onRemove,
    required this.onOpenContextMenu,
  });

  final SearchHistoryEntry entry;
  final bool selected;
  final bool multiSelect;
  final VoidCallback onSearch;
  final VoidCallback onToggleSelection;
  final VoidCallback onRemove;
  final ValueChanged<Offset> onOpenContextMenu;

  @override
  State<_RecentSearchRow> createState() => _RecentSearchRowState();
}

class _RecentSearchRowState extends State<_RecentSearchRow> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
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
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onSecondaryTapDown: (details) {
            widget.onOpenContextMenu(details.globalPosition);
          },
          child: DecoratedBox(
            decoration: BoxDecoration(
              color:
                  widget.selected || _hovered
                      ? _RecentSearchColors.hoverSurface
                      : _RecentSearchColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _RecentSearchColors.border),
              boxShadow: const [
                BoxShadow(
                  color: _RecentSearchColors.shadow,
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap:
                        widget.multiSelect
                            ? widget.onToggleSelection
                            : widget.onSearch,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 0, 12, 0),
                      child: Row(
                        children: [
                          if (widget.multiSelect)
                            Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: Icon(
                                widget.selected
                                    ? FluentIcons.checkmark_circle_20_filled
                                    : FluentIcons.circle_20_regular,
                                color:
                                    widget.selected
                                        ? _RecentSearchColors.accentStrong
                                        : _RecentSearchColors.textMuted,
                                size: 20,
                              ),
                            )
                          else
                            const Padding(
                              padding: EdgeInsets.only(right: 10),
                              child: Icon(
                                FluentIcons.search_20_regular,
                                size: 18,
                                color: _RecentSearchColors.textMuted,
                              ),
                            ),
                          Expanded(
                            child: Text(
                              widget.entry.query,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _RecentSearchColors.textStrong,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            searchHistoryTypeLabel(widget.entry.type),
                            style: const TextStyle(
                              color: _RecentSearchColors.textMuted,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            formatRecentDateTime(widget.entry.searchedAt),
                            style: const TextStyle(
                              color: _RecentSearchColors.textSoft,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '移除',
                  icon: const Icon(FluentIcons.dismiss_16_regular, size: 15),
                  color: _RecentSearchColors.textMuted,
                  onPressed: widget.onRemove,
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecentSearchColors {
  const _RecentSearchColors._();

  static const surface = Color(0x9effffff);
  static const hoverSurface = Color(0x1f0078d7);
  static const border = Color(0x1f7e8b9a);
  static const shadow = Color(0x0a273446);
  static const accentStrong = Color(0xff0063b1);
  static const textStrong = Color(0xff111827);
  static const textMuted = Color(0xff5b697a);
  static const textSoft = Color(0xff8290a1);
}
