import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:smplayer_flutter/src/app/app_interaction_colors.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/ui/multi_select_command_bar.dart';

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
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }

    return RecentScrollbar(
      builder:
          (controller) => ListView.builder(
            controller: controller,
            padding: EdgeInsets.fromLTRB(
              8,
              2,
              0,
              multiSelect ? multiSelectCommandBarScrollSpacer : 92,
            ),
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
  var _removeHovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = RecentSearchThemeColors.of(context);
    return Padding(
      key: ValueKey('Recent.SearchRow.${widget.entry.id}'),
      padding: const EdgeInsets.symmetric(vertical: 4),
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
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap:
                            widget.multiSelect
                                ? widget.onToggleSelection
                                : widget.onSearch,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 48),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(18, 0, 12, 0),
                            child: Row(
                              children: [
                                if (widget.multiSelect)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 10),
                                    child: _RecentSearchSelectionMark(
                                      selected: widget.selected,
                                      colors: colors,
                                    ),
                                  ),
                                Padding(
                                  padding: const EdgeInsets.only(right: 10),
                                  child: SizedBox.square(
                                    dimension: 20,
                                    child: Center(
                                      child: _RecentSearchTypeIcon(
                                        type: widget.entry.type,
                                        color: colors.textMuted,
                                      ),
                                    ),
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
                                      fontVariations: const [
                                        FontVariation('wght', 560),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  formatRecentDateTime(widget.entry.searchedAt),
                                  style: TextStyle(
                                    color: colors.timeText,
                                    fontSize: 13,
                                    fontVariations: const [
                                      FontVariation('wght', 520),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (!widget.multiSelect)
                    SizedBox(
                      width: 42,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Tooltip(
                          message: widget.i18n.t('sidebar.removeRecentSearch', {
                            'query': widget.entry.query,
                          }),
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            onEnter: (_) {
                              setState(() {
                                _removeHovered = true;
                              });
                            },
                            onExit: (_) {
                              setState(() {
                                _removeHovered = false;
                              });
                            },
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: widget.onRemove,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color:
                                      _removeHovered
                                          ? colors.removeHoverSurface
                                          : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: SizedBox.square(
                                  dimension: 32,
                                  child: Icon(
                                    FluentIcons.dismiss_16_regular,
                                    size: 15,
                                    color:
                                        _removeHovered
                                            ? colors.accentStrong
                                            : colors.textMuted,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 42),
                ],
              ),
            ),
            if (!widget.selected && !_hovered)
              Positioned(
                left: 1,
                top: 1,
                right: 1,
                height: 1,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.topHighlight,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(9),
                      ),
                    ),
                  ),
                ),
              ),
            if (_hovered && !widget.selected)
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: colors.hoverInnerBorder),
                    ),
                  ),
                ),
              ),
            if (widget.selected)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: IgnorePointer(
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
              ),
          ],
        ),
      ),
    );
  }
}

class _RecentSearchSelectionMark extends StatelessWidget {
  const _RecentSearchSelectionMark({
    required this.selected,
    required this.colors,
  });

  final bool selected;
  final RecentSearchThemeColors colors;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: selected ? Colors.transparent : colors.selectionMarkSurface,
        border: Border.all(color: colors.selectionMarkBorder),
        borderRadius: BorderRadius.circular(4),
      ),
      child: SizedBox.square(
        dimension: 16,
        child:
            selected
                ? Icon(
                  FluentIcons.checkmark_12_regular,
                  color: colors.selectionMarkText,
                  size: 12,
                )
                : null,
      ),
    );
  }
}

class _RecentSearchTypeIcon extends StatelessWidget {
  const _RecentSearchTypeIcon({required this.type, required this.color});

  final SearchHistoryType type;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final iconData = switch (type) {
      SearchHistoryType.sidebar => FluentIcons.search_20_regular,
      SearchHistoryType.artists => FluentIcons.people_20_regular,
      SearchHistoryType.songs => FluentIcons.music_note_2_20_regular,
      SearchHistoryType.folders => FluentIcons.folder_20_regular,
      SearchHistoryType.albums || SearchHistoryType.playlists => null,
    };

    if (iconData != null) {
      return Icon(iconData, size: 18, color: color);
    }

    return SizedBox.square(
      dimension: 18,
      child: CustomPaint(
        painter: _RecentSearchVectorIconPainter(type: type, color: color),
      ),
    );
  }
}

class _RecentSearchVectorIconPainter extends CustomPainter {
  const _RecentSearchVectorIconPainter({
    required this.type,
    required this.color,
  });

  final SearchHistoryType type;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 24;
    canvas.save();
    canvas.scale(scale);
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.35
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

    switch (type) {
      case SearchHistoryType.albums:
        canvas
          ..drawCircle(const Offset(12, 12), 8, paint)
          ..drawCircle(const Offset(12, 12), 3, paint);
        canvas.drawCircle(
          const Offset(12, 12),
          0.7,
          Paint()
            ..color = color
            ..style = PaintingStyle.fill,
        );
      case SearchHistoryType.playlists:
        canvas
          ..drawLine(const Offset(4, 6.5), const Offset(14, 6.5), paint)
          ..drawLine(const Offset(4, 11.5), const Offset(13, 11.5), paint)
          ..drawLine(const Offset(4, 16.5), const Offset(10, 16.5), paint)
          ..drawLine(const Offset(18, 8.5), const Offset(18, 16.5), paint)
          ..drawCircle(const Offset(16, 17), 2, paint);
      case SearchHistoryType.sidebar:
      case SearchHistoryType.artists:
      case SearchHistoryType.songs:
      case SearchHistoryType.folders:
        break;
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RecentSearchVectorIconPainter oldDelegate) {
    return oldDelegate.type != type || oldDelegate.color != color;
  }
}

class RecentSearchThemeColors extends ThemeExtension<RecentSearchThemeColors> {
  const RecentSearchThemeColors({
    required this.surface,
    required this.hoverSurface,
    required this.border,
    required this.hoverBorder,
    required this.hoverInnerBorder,
    required this.topHighlight,
    required this.shadow,
    required this.hoverShadow,
    required this.selectedShadow,
    required this.accent,
    required this.accentStrong,
    required this.textStrong,
    required this.textMuted,
    required this.timeText,
    required this.removeHoverSurface,
    required this.selectionMarkSurface,
    required this.selectionMarkBorder,
    required this.selectionMarkText,
  });

  final Color surface;
  final Color hoverSurface;
  final Color border;
  final Color hoverBorder;
  final Color hoverInnerBorder;
  final Color topHighlight;
  final List<BoxShadow> shadow;
  final List<BoxShadow> hoverShadow;
  final List<BoxShadow> selectedShadow;
  final Color accent;
  final Color accentStrong;
  final Color textStrong;
  final Color textMuted;
  final Color timeText;
  final Color removeHoverSurface;
  final Color selectionMarkSurface;
  final Color selectionMarkBorder;
  final Color selectionMarkText;

  static const light = RecentSearchThemeColors(
    surface: Color(0x9effffff),
    hoverSurface: GlobalUI.hoverBgColorDay,
    border: Color(0x1f7e8b9a),
    hoverBorder: GlobalUI.hoverBorderColorDay,
    hoverInnerBorder: GlobalUI.hoverBorderColorDay,
    topHighlight: Color(0x75ffffff),
    shadow: [
      BoxShadow(color: Color(0x0a273446), blurRadius: 18, offset: Offset(0, 8)),
    ],
    hoverShadow: [GlobalUI.hoverShadowDay],
    selectedShadow: [GlobalUI.selectedShadowDay],
    accent: Color(0xff0078d7),
    accentStrong: Color(0xff0063b1),
    textStrong: Color(0xff1f252b),
    textMuted: Color(0xff5f625f),
    timeText: Color(0xff5f625f),
    removeHoverSurface: Color(0x1f0078d7),
    selectionMarkSurface: Colors.transparent,
    selectionMarkBorder: Color(0x6b586474),
    selectionMarkText: Color(0xff0078d7),
  );

  static const dark = RecentSearchThemeColors(
    surface: Color(0x0cffffff),
    hoverSurface: GlobalUI.hoverBgColorNight,
    border: Color(0x1fd6e0ec),
    hoverBorder: GlobalUI.hoverBorderColorNight,
    hoverInnerBorder: GlobalUI.hoverBorderColorNight,
    topHighlight: Color(0x0cffffff),
    shadow: [
      BoxShadow(color: Color(0x24000000), blurRadius: 18, offset: Offset(0, 8)),
    ],
    hoverShadow: [],
    selectedShadow: [],
    accent: Color(0xff0078d7),
    accentStrong: Color(0xff459de2),
    textStrong: Color(0xeff6f9fc),
    textMuted: Color(0xadcbd5e1),
    timeText: Color(0x75cbd5e1),
    removeHoverSurface: Color(0x2e0078d7),
    selectionMarkSurface: Color(0x0effffff),
    selectionMarkBorder: Color(0x1fd6e0ec),
    selectionMarkText: Color(0xff459de2),
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
