import 'dart:ui';

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

class PageSearchField extends StatelessWidget {
  const PageSearchField({
    super.key,
    required this.value,
    required this.hintText,
    required this.focused,
    required this.onChanged,
    required this.onFocusChanged,
    required this.onSubmitted,
    required this.onClear,
    this.autofocus = false,
    this.height = 40,
    this.searchTooltip,
    this.clearTooltip,
  });

  final String value;
  final String hintText;
  final bool focused;
  final ValueChanged<String> onChanged;
  final ValueChanged<bool> onFocusChanged;
  final VoidCallback onSubmitted;
  final VoidCallback onClear;
  final bool autofocus;
  final double height;
  final String? searchTooltip;
  final String? clearTooltip;

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController(text: value)
      ..selection = TextSelection.collapsed(offset: value.length);
    return SizedBox(
      height: height,
      child: Focus(
        onFocusChange: onFocusChanged,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color:
                focused
                    ? _PageSearchColors.focusedSurface
                    : _PageSearchColors.searchSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color:
                  focused
                      ? _PageSearchColors.focusedBorder
                      : _PageSearchColors.border,
            ),
            boxShadow:
                focused
                    ? const [
                      BoxShadow(
                        color: _PageSearchColors.focusRing,
                        blurRadius: 0,
                        spreadRadius: 3,
                      ),
                    ]
                    : const [
                      BoxShadow(
                        color: _PageSearchColors.insetHighlight,
                        offset: Offset(0, 1),
                        blurRadius: 0,
                        spreadRadius: 0,
                        blurStyle: BlurStyle.inner,
                      ),
                    ],
          ),
          child: Row(
            children: [
              SizedBox(
                width: height,
                height: height,
                child: _PageSearchIconButton(
                  tooltip: searchTooltip,
                  icon: FluentIcons.search_24_regular,
                  iconSize: 19,
                  borderRadius: 0,
                  hoverBackground: _PageSearchColors.clearButton,
                  onPressed: onSubmitted,
                ),
              ),
              Expanded(
                child: TextField(
                  autofocus: autofocus,
                  controller: controller,
                  onTap: () {
                    onFocusChanged(true);
                  },
                  onChanged: onChanged,
                  onSubmitted: (_) {
                    onSubmitted();
                  },
                  textInputAction: TextInputAction.search,
                  style: const TextStyle(
                    color: _PageSearchColors.textStrong,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: hintText,
                    hintStyle: const TextStyle(
                      color: _PageSearchColors.placeholder,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              if (value.isNotEmpty)
                SizedBox(
                  width: 24,
                  height: height,
                  child: _PageSearchIconButton(
                    tooltip: clearTooltip,
                    icon: FluentIcons.dismiss_16_regular,
                    iconSize: 14,
                    borderRadius: 6,
                    background: _PageSearchColors.clearButton,
                    hoverBackground: _PageSearchColors.clearButtonHover,
                    foreground: _PageSearchColors.accent,
                    onPressed: onClear,
                  ),
                ),
              const SizedBox(width: 10),
            ],
          ),
        ),
      ),
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _PageSearchColors.dropdownSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _PageSearchColors.border),
            boxShadow: const [
              BoxShadow(
                color: _PageSearchColors.dropdownShadow,
                blurRadius: 36,
                offset: Offset(0, 18),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (title.isNotEmpty) ...[
                    SizedBox(
                      height: 30,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _PageSearchColors.header,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0,
                                  height: 1,
                                ),
                              ),
                            ),
                            if (onClear != null && clearLabel != null)
                              _PageSearchTextButton(
                                label: clearLabel!,
                                onPressed: onClear,
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: items.length,
                      separatorBuilder:
                          (context, index) => const SizedBox(height: 2),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return _SearchHistoryPanelRow<TValue>(
                          item: item,
                          onSelect: onSelect,
                          onRemove: onRemove,
                          removeLabel:
                              getRemoveLabel == null
                                  ? null
                                  : getRemoveLabel!(item),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
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
      height: 38,
      child: Row(
        children: [
          Expanded(
            child: TextButton(
              key: ValueKey('PageSearchHistoryPanel.Item.${item.label}'),
              style: TextButton.styleFrom(
                alignment: Alignment.centerLeft,
                minimumSize: const Size(0, 38),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                foregroundColor: _PageSearchColors.textStrong,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: const TextStyle(fontSize: 14),
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
            SizedBox.square(
              dimension: 30,
              child: _PageSearchIconButton(
                tooltip: removeLabel,
                icon: FluentIcons.dismiss_16_regular,
                iconSize: 14,
                borderRadius: 8,
                foreground: _PageSearchColors.textMuted,
                hoverForeground: _PageSearchColors.accent,
                onPressed: () {
                  onRemove!(item);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _PageSearchTextButton extends StatefulWidget {
  const _PageSearchTextButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  State<_PageSearchTextButton> createState() => _PageSearchTextButtonState();
}

class _PageSearchTextButtonState extends State<_PageSearchTextButton> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
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
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        child: SizedBox(
          height: 30,
          child: Center(
            child: Text(
              widget.label,
              style: TextStyle(
                color:
                    _hovered && enabled
                        ? _PageSearchColors.accent
                        : _PageSearchColors.header,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PageSearchIconButton extends StatefulWidget {
  const _PageSearchIconButton({
    required this.icon,
    required this.iconSize,
    required this.borderRadius,
    required this.onPressed,
    this.tooltip,
    this.background = Colors.transparent,
    this.hoverBackground = Colors.transparent,
    this.foreground = _PageSearchColors.textMuted,
    this.hoverForeground = _PageSearchColors.accent,
  });

  final IconData icon;
  final double iconSize;
  final double borderRadius;
  final VoidCallback onPressed;
  final String? tooltip;
  final Color background;
  final Color hoverBackground;
  final Color foreground;
  final Color hoverForeground;

  @override
  State<_PageSearchIconButton> createState() => _PageSearchIconButtonState();
}

class _PageSearchIconButtonState extends State<_PageSearchIconButton> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final button = MouseRegion(
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
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _hovered ? widget.hoverBackground : widget.background,
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
          child: Center(
            child: Icon(
              widget.icon,
              size: widget.iconSize,
              color: _hovered ? widget.hoverForeground : widget.foreground,
            ),
          ),
        ),
      ),
    );
    if (widget.tooltip == null) {
      return button;
    }
    return Tooltip(message: widget.tooltip!, child: button);
  }
}

class _PageSearchColors {
  const _PageSearchColors._();

  static const searchSurface = Color(0x090d1826);
  static const focusedSurface = Color(0xffffffff);
  static const border = Color(0x24536379);
  static const focusedBorder = Color(0x7a0078d7);
  static const focusRing = Color(0x1a0078d7);
  static const insetHighlight = Color(0x61ffffff);
  static const placeholder = Color(0x9e3d4958);
  static const clearButton = Color(0x1a0078d7);
  static const clearButtonHover = Color(0x1f0078d7);
  static const dropdownSurface = Color(0xf5f4f6f9);
  static const dropdownShadow = Color(0x2935495f);
  static const header = Color(0x945f625f);
  static const accent = Color(0xff0063b1);
  static const textStrong = Color(0xff1f252b);
  static const textMuted = Color(0xff5f625f);
}
