import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';

import 'recent_page_model.dart';
import 'recent_scrollbar.dart';

class RecentSearchList extends StatelessWidget {
  const RecentSearchList({
    super.key,
    required this.entries,
    required this.i18n,
    required this.multiSelect,
    required this.selectedEntryIds,
    required this.onSearch,
    required this.onToggleSelection,
    required this.onRemove,
  });

  final List<SearchHistoryEntry> entries;
  final SmPlayerI18n i18n;
  final bool multiSelect;
  final Set<int> selectedEntryIds;
  final ValueChanged<SearchHistoryEntry> onSearch;
  final ValueChanged<int> onToggleSelection;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = RecentSearchThemeColors.of(context);
    if (entries.isEmpty) {
      return Center(
        child: Text(
          i18n.t('recent.noSearches'),
          style: TextStyle(color: colors.textMuted),
        ),
      );
    }

    return RecentScrollbar(
      builder:
          (controller) => ListView.builder(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(8, 2, 22, 88),
            itemExtent: 56,
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              return _RecentSearchRow(
                entry: entry,
                i18n: i18n,
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
              );
            },
          ),
    );
  }
}

class _RecentSearchRow extends StatefulWidget {
  const _RecentSearchRow({
    required this.entry,
    required this.i18n,
    required this.selected,
    required this.multiSelect,
    required this.onSearch,
    required this.onToggleSelection,
    required this.onRemove,
  });

  final SearchHistoryEntry entry;
  final SmPlayerI18n i18n;
  final bool selected;
  final bool multiSelect;
  final VoidCallback onSearch;
  final VoidCallback onToggleSelection;
  final VoidCallback onRemove;

  @override
  State<_RecentSearchRow> createState() => _RecentSearchRowState();
}

class _RecentSearchRowState extends State<_RecentSearchRow> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = RecentSearchThemeColors.of(context);
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
        child: Stack(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color:
                    widget.selected || _hovered
                        ? colors.hoverSurface
                        : colors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color:
                      widget.selected || _hovered
                          ? colors.hoverBorder
                          : colors.border,
                ),
                boxShadow:
                    widget.selected
                        ? colors.selectedShadow
                        : _hovered
                        ? colors.hoverShadow
                        : colors.shadow,
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
                                          ? colors.accentStrong
                                          : colors.textMuted,
                                  size: 20,
                                ),
                              )
                            else
                              Padding(
                                padding: const EdgeInsets.only(right: 10),
                                child: Icon(
                                  _searchHistoryTypeIcon(widget.entry.type),
                                  size: 18,
                                  color: colors.textMuted,
                                ),
                              ),
                            Expanded(
                              child: Text(
                                widget.entry.query,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: colors.textStrong,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              searchHistoryTypeLabel(
                                widget.entry.type,
                                widget.i18n,
                              ),
                              style: TextStyle(
                                color: colors.textMuted,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              formatRecentDateTime(widget.entry.searchedAt),
                              style: TextStyle(
                                color: colors.textSoft,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: widget.i18n.t('context.removeFromList'),
                    icon: const Icon(FluentIcons.dismiss_16_regular, size: 15),
                    color: colors.textMuted,
                    hoverColor: colors.removeHoverSurface,
                    onPressed: widget.onRemove,
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
            if (widget.selected)
              Positioned(
                left: 0,
                top: 1,
                bottom: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.accent,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(10),
                    ),
                  ),
                  child: const SizedBox(width: 3),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

IconData _searchHistoryTypeIcon(SearchHistoryType type) {
  return switch (type) {
    SearchHistoryType.sidebar => FluentIcons.search_20_regular,
    SearchHistoryType.artists => FluentIcons.people_20_regular,
    SearchHistoryType.albums => FluentIcons.album_20_regular,
    SearchHistoryType.songs => FluentIcons.music_note_2_20_regular,
    SearchHistoryType.playlists => FluentIcons.apps_list_detail_20_regular,
    SearchHistoryType.folders => FluentIcons.folder_20_regular,
  };
}

class RecentSearchThemeColors extends ThemeExtension<RecentSearchThemeColors> {
  const RecentSearchThemeColors({
    required this.surface,
    required this.hoverSurface,
    required this.border,
    required this.hoverBorder,
    required this.shadow,
    required this.hoverShadow,
    required this.selectedShadow,
    required this.accent,
    required this.accentStrong,
    required this.textStrong,
    required this.textMuted,
    required this.textSoft,
    required this.removeHoverSurface,
  });

  final Color surface;
  final Color hoverSurface;
  final Color border;
  final Color hoverBorder;
  final List<BoxShadow> shadow;
  final List<BoxShadow> hoverShadow;
  final List<BoxShadow> selectedShadow;
  final Color accent;
  final Color accentStrong;
  final Color textStrong;
  final Color textMuted;
  final Color textSoft;
  final Color removeHoverSurface;

  static const light = RecentSearchThemeColors(
    surface: Color(0x9effffff),
    hoverSurface: Color(0x1f0078d7),
    border: Color(0x1f7e8b9a),
    hoverBorder: Color(0x3d0078d7),
    shadow: [
      BoxShadow(color: Color(0x0a273446), blurRadius: 18, offset: Offset(0, 8)),
    ],
    hoverShadow: [
      BoxShadow(
        color: Color(0x210078d7),
        blurRadius: 26,
        offset: Offset(0, 12),
      ),
    ],
    selectedShadow: [
      BoxShadow(
        color: Color(0x0f273446),
        blurRadius: 22,
        offset: Offset(0, 10),
      ),
    ],
    accent: Color(0xff0078d7),
    accentStrong: Color(0xff0063b1),
    textStrong: Color(0xff111827),
    textMuted: Color(0xff5b697a),
    textSoft: Color(0xff8290a1),
    removeHoverSurface: Color(0x1a0078d7),
  );

  static const dark = RecentSearchThemeColors(
    surface: Color(0x0cffffff),
    hoverSurface: Color(0x210078d7),
    border: Color(0x1fd6e0ec),
    hoverBorder: Color(0x470078d7),
    shadow: [
      BoxShadow(color: Color(0x24000000), blurRadius: 18, offset: Offset(0, 8)),
    ],
    hoverShadow: [
      BoxShadow(color: Color(0x290078d7), blurRadius: 0, spreadRadius: 1),
    ],
    selectedShadow: [],
    accent: Color(0xff0078d7),
    accentStrong: Color(0xff7fc4ff),
    textStrong: Color(0xebffffff),
    textMuted: Color(0xc7ffffff),
    textSoft: Color(0x94ffffff),
    removeHoverSurface: Color(0x2e0078d7),
  );

  static RecentSearchThemeColors of(BuildContext context) {
    return Theme.of(context).extension<RecentSearchThemeColors>()!;
  }

  @override
  RecentSearchThemeColors copyWith() {
    return this;
  }

  @override
  RecentSearchThemeColors lerp(
    ThemeExtension<RecentSearchThemeColors>? other,
    double t,
  ) {
    return t < 0.5 || other is! RecentSearchThemeColors ? this : other;
  }
}
