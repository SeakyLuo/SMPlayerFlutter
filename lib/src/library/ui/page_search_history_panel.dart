import 'dart:ui';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';

import '../../i18n/app_i18n.dart';
import '../data/library_models.dart';
import 'command_bar_colors.dart';

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

class PageSearchField extends StatefulWidget {
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
    this.appBar = false,
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
  final bool appBar;
  final String? searchTooltip;
  final String? clearTooltip;

  @override
  State<PageSearchField> createState() => _PageSearchFieldState();
}

class _PageSearchFieldState extends State<PageSearchField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant PageSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = _PageSearchColors.resolve(context, appBar: widget.appBar);
    const borderRadius = 10.0;
    return SizedBox(
      height: widget.height,
      child: Focus(
        onFocusChange: widget.onFocusChanged,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color:
                widget.focused ? colors.focusedSurface : colors.searchSurface,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: widget.focused ? colors.focusedBorder : colors.border,
            ),
            boxShadow:
                widget.focused
                    ? [
                      BoxShadow(
                        color: colors.focusRing,
                        blurRadius: 0,
                        spreadRadius: 3,
                      ),
                    ]
                    : [
                      BoxShadow(
                        color: colors.insetHighlight,
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
                width: widget.height,
                height: widget.height,
                child: _PageSearchIconButton(
                  tooltip: widget.searchTooltip,
                  icon: FluentIcons.search_24_regular,
                  iconSize: 19,
                  borderRadius: 0,
                  foreground: colors.textMuted,
                  hoverBackground: colors.iconButtonHover,
                  onPressed: widget.onSubmitted,
                ),
              ),
              Expanded(
                child: TextField(
                  autofocus: widget.autofocus,
                  controller: _controller,
                  onTap: () {
                    widget.onFocusChanged(true);
                  },
                  onChanged: widget.onChanged,
                  onSubmitted: (_) {
                    widget.onSubmitted();
                  },
                  textInputAction: TextInputAction.search,
                  style: const TextStyle(
                    fontSize: 14,
                  ).copyWith(color: colors.textStrong),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: widget.hintText,
                    hintStyle: TextStyle(color: colors.placeholder),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              if (_controller.text.isNotEmpty)
                SizedBox(
                  width: 30,
                  height: widget.height,
                  child: _PageSearchIconButton(
                    tooltip: widget.clearTooltip,
                    icon: FluentIcons.dismiss_16_regular,
                    iconSize: 14,
                    borderRadius: 8,
                    hoverBackground: colors.iconButtonHover,
                    foreground: colors.textMuted,
                    hoverForeground: colors.accent,
                    onPressed: widget.onClear,
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

class AppBarPageSearchCloseButton extends StatefulWidget {
  const AppBarPageSearchCloseButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
  });

  final String tooltip;
  final VoidCallback onPressed;

  @override
  State<AppBarPageSearchCloseButton> createState() =>
      _AppBarPageSearchCloseButtonState();
}

class _AppBarPageSearchCloseButtonState
    extends State<AppBarPageSearchCloseButton> {
  var _hovered = false;
  var _pressed = false;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final foreground =
        dark
            ? CommandBarColors.appBarForegroundDark
            : CommandBarColors.appBarForeground;
    final hover =
        dark ? CommandBarColors.appBarHoverDark : CommandBarColors.appBarHover;
    final pressed =
        dark
            ? CommandBarColors.appBarPressedDark
            : CommandBarColors.appBarPressed;
    return Tooltip(
      message: widget.tooltip,
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
            _pressed = false;
          });
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) {
            setState(() {
              _pressed = true;
            });
          },
          onTapCancel: () {
            setState(() {
              _pressed = false;
            });
          },
          onTapUp: (_) {
            setState(() {
              _pressed = false;
            });
          },
          onTap: widget.onPressed,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color:
                  _pressed
                      ? pressed
                      : _hovered
                      ? hover
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: SizedBox.square(
              dimension: 36,
              child: Center(
                child: Icon(
                  FluentIcons.dismiss_20_regular,
                  size: 18,
                  color: foreground,
                ),
              ),
            ),
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
    final colors = _PageSearchColors.resolve(context, appBar: false);
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.dropdownSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.border),
            boxShadow: [
              BoxShadow(
                color: colors.dropdownShadow,
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
                                style: TextStyle(
                                  color: colors.header,
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
    final colors = _PageSearchColors.resolve(context, appBar: false);
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
                foregroundColor: colors.textStrong,
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
                foreground: colors.textMuted,
                hoverForeground: colors.accent,
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
    final colors = _PageSearchColors.resolve(context, appBar: false);
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
                color: _hovered && enabled ? colors.accent : colors.header,
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
    this.hoverBackground = Colors.transparent,
    this.foreground = const Color(0xff5f625f),
    this.hoverForeground = const Color(0xff0063b1),
  });

  final IconData icon;
  final double iconSize;
  final double borderRadius;
  final VoidCallback onPressed;
  final String? tooltip;
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
            color: _hovered ? widget.hoverBackground : Colors.transparent,
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
  const _PageSearchColors({
    required this.searchSurface,
    required this.focusedSurface,
    required this.border,
    required this.focusedBorder,
    required this.focusRing,
    required this.insetHighlight,
    required this.placeholder,
    required this.iconButtonHover,
    required this.dropdownSurface,
    required this.dropdownShadow,
    required this.header,
    required this.accent,
    required this.textStrong,
    required this.textMuted,
  });

  final Color searchSurface;
  final Color focusedSurface;
  final Color border;
  final Color focusedBorder;
  final Color focusRing;
  final Color insetHighlight;
  final Color placeholder;
  final Color iconButtonHover;
  final Color dropdownSurface;
  final Color dropdownShadow;
  final Color header;
  final Color accent;
  final Color textStrong;
  final Color textMuted;

  static const light = _PageSearchColors(
    searchSurface: Color(0x090d1826),
    focusedSurface: Color(0xffffffff),
    border: Color(0x24536379),
    focusedBorder: Color(0x7a0078d7),
    focusRing: Color(0x1a0078d7),
    insetHighlight: Color(0x61ffffff),
    placeholder: Color(0x9e3d4958),
    iconButtonHover: Color(0x120078d7),
    dropdownSurface: Color(0xf5f4f6f9),
    dropdownShadow: Color(0x2935495f),
    header: Color(0x945f625f),
    accent: Color(0xff0063b1),
    textStrong: Color(0xff1f252b),
    textMuted: Color(0xff5f625f),
  );

  static const darkAppBar = _PageSearchColors(
    searchSurface: Color(0x0effffff),
    focusedSurface: Color(0x240078d7),
    border: Colors.transparent,
    focusedBorder: Colors.transparent,
    focusRing: Color(0x240078d7),
    insetHighlight: Color(0x0effffff),
    placeholder: Color(0xadcbd5e1),
    iconButtonHover: Color(0x240078d7),
    dropdownSurface: Color(0xf5181e26),
    dropdownShadow: Color(0x57000000),
    header: Color(0xadCBD5E1),
    accent: Color(0xfff6f9fc),
    textStrong: Color(0xfff6f9fc),
    textMuted: Color(0xadcbd5e1),
  );

  static _PageSearchColors resolve(
    BuildContext context, {
    required bool appBar,
  }) {
    if (appBar && Theme.of(context).brightness == Brightness.dark) {
      return darkAppBar;
    }
    return light;
  }
}
