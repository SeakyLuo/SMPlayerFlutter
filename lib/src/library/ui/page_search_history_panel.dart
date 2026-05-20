import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';

import '../../i18n/app_i18n.dart';
import '../data/library_models.dart';

class PageSearchHistoryPanel extends StatelessWidget {
  const PageSearchHistoryPanel({
    super.key,
    required this.entries,
    required this.i18n,
    required this.onSelect,
    required this.onRemove,
    required this.onClear,
  });

  final List<SearchHistoryEntry> entries;
  final SmPlayerI18n i18n;
  final ValueChanged<String> onSelect;
  final ValueChanged<int> onRemove;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return SearchHistoryPanel<SearchHistoryEntry>(
      title: i18n.t('sidebar.recentSearches'),
      clearLabel: i18n.t('common.clear'),
      items: [
        for (final entry in entries)
          SearchHistoryPanelItem(
            key: entry.id.toString(),
            label: entry.query,
            value: entry,
          ),
      ],
      onClear: onClear,
      onSelect: (item) {
        onSelect(item.value.query);
      },
      onRemove: (item) {
        onRemove(item.value.id);
      },
      getRemoveLabel:
          (item) =>
              i18n.t('sidebar.removeRecentSearch', {'query': item.value.query}),
    );
  }
}

class PageSearchSuggestionPanel extends StatelessWidget {
  const PageSearchSuggestionPanel({
    super.key,
    required this.labels,
    required this.onSelect,
  });

  final List<String> labels;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return SearchHistoryPanel<String>(
      title: '',
      items: [
        for (final label in labels)
          SearchHistoryPanelItem(key: label, label: label, value: label),
      ],
      onSelect: (item) {
        onSelect(item.value);
      },
    );
  }
}

class SearchHistoryPanelItem<TValue> {
  const SearchHistoryPanelItem({
    required this.key,
    required this.label,
    required this.value,
  });

  final String key;
  final String label;
  final TValue value;
}

class SearchHistoryPanel<TValue> extends StatelessWidget {
  const SearchHistoryPanel({
    super.key,
    required this.items,
    required this.title,
    required this.onSelect,
    this.clearLabel,
    this.onClear,
    this.onRemove,
    this.getRemoveLabel,
  });

  final List<SearchHistoryPanelItem<TValue>> items;
  final String title;
  final ValueChanged<SearchHistoryPanelItem<TValue>> onSelect;
  final String? clearLabel;
  final VoidCallback? onClear;
  final ValueChanged<SearchHistoryPanelItem<TValue>>? onRemove;
  final String Function(SearchHistoryPanelItem<TValue> item)? getRemoveLabel;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _PageSearchColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _PageSearchColors.border),
          boxShadow: const [
            BoxShadow(
              color: _PageSearchColors.shadow,
              blurRadius: 24,
              offset: Offset(0, 14),
            ),
          ],
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 280),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (title.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 8, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: _PageSearchColors.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (onClear != null && clearLabel != null)
                        TextButton(
                          style: TextButton.styleFrom(
                            minimumSize: const Size(0, 28),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            foregroundColor: _PageSearchColors.accent,
                          ),
                          onPressed: onClear,
                          child: Text(clearLabel!),
                        ),
                    ],
                  ),
                ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(6, 4, 6, 6),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _SearchHistoryPanelRow<TValue>(
                      item: item,
                      onSelect: onSelect,
                      onRemove: onRemove,
                      removeLabel:
                          getRemoveLabel == null ? null : getRemoveLabel!(item),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchHistoryPanelRow<TValue> extends StatelessWidget {
  const _SearchHistoryPanelRow({
    required this.item,
    required this.onSelect,
    required this.onRemove,
    required this.removeLabel,
  });

  final SearchHistoryPanelItem<TValue> item;
  final ValueChanged<SearchHistoryPanelItem<TValue>> onSelect;
  final ValueChanged<SearchHistoryPanelItem<TValue>>? onRemove;
  final String? removeLabel;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: Row(
        children: [
          Expanded(
            child: TextButton(
              key: ValueKey('PageSearchHistoryPanel.Item.${item.label}'),
              style: TextButton.styleFrom(
                alignment: Alignment.centerLeft,
                foregroundColor: _PageSearchColors.textStrong,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
              onPressed: () {
                onSelect(item);
              },
              child: Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          if (onRemove != null && removeLabel != null)
            IconButton(
              tooltip: removeLabel,
              icon: const Icon(FluentIcons.dismiss_16_regular, size: 15),
              color: _PageSearchColors.textMuted,
              onPressed: () {
                onRemove!(item);
              },
            ),
        ],
      ),
    );
  }
}

class _PageSearchColors {
  const _PageSearchColors._();

  static const surface = Color(0xf7ffffff);
  static const border = Color(0x267e8b9a);
  static const shadow = Color(0x1a1d2939);
  static const accent = Color(0xff0063b1);
  static const textStrong = Color(0xff172033);
  static const textMuted = Color(0xff5f6f84);
}
