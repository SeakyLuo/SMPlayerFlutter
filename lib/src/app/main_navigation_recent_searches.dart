part of 'main_navigation_view.dart';

class _MainNavigationRecentSearches extends StatelessWidget {
  const _MainNavigationRecentSearches({
    required this.entries,
    required this.i18n,
    required this.onSearchSelected,
    required this.onSearchRemoved,
    required this.onClear,
  });

  final List<SearchHistoryEntry> entries;
  final SmPlayerI18n i18n;
  final ValueChanged<SearchHistoryEntry> onSearchSelected;
  final ValueChanged<int>? onSearchRemoved;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final colors = MainNavigationViewColors.of(context);
    return DecoratedBox(
      key: const ValueKey('MainNavigationView.SearchHistoryPanel'),
      decoration: BoxDecoration(
        color: colors.dropdownSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.searchBorder),
        boxShadow: [
          BoxShadow(
            color: colors.dropdownShadow,
            blurRadius: 36,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 30),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        i18n.t('sidebar.recentSearches'),
                        style: TextStyle(
                          color: colors.searchHistoryHeader,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0,
                          height: 1,
                        ),
                      ),
                    ),
                    _MainNavigationSearchHistoryTextButton(
                      label: i18n.t('common.clear'),
                      onPressed: onClear,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final entry in entries) ...[
                    _MainNavigationRecentSearchItem(
                      entry: entry,
                      removeLabel: i18n.t('sidebar.removeRecentSearch', {
                        'query': entry.query,
                      }),
                      onPressed: () {
                        onSearchSelected(entry);
                      },
                      onRemove:
                          onSearchRemoved == null
                              ? null
                              : () {
                                onSearchRemoved!(entry.id);
                              },
                    ),
                    if (entry != entries.last) const SizedBox(height: 2),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MainNavigationRecentSearchItem extends StatelessWidget {
  const _MainNavigationRecentSearchItem({
    required this.entry,
    required this.removeLabel,
    required this.onPressed,
    required this.onRemove,
  });

  final SearchHistoryEntry entry;
  final String removeLabel;
  final VoidCallback onPressed;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = MainNavigationViewColors.of(context);
    return _HoverContainer(
      borderRadius: BorderRadius.circular(10),
      builder: (context, hovered) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: hovered ? colors.searchHistoryItemHover : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: SizedBox(
            height: 38,
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onPressed,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          entry.query,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.textStrong,
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (onRemove != null)
                  _MainNavigationSearchHistoryIconButton(
                    tooltip: removeLabel,
                    onPressed: onRemove!,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MainNavigationSearchHistoryTextButton extends StatefulWidget {
  const _MainNavigationSearchHistoryTextButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  State<_MainNavigationSearchHistoryTextButton> createState() =>
      _MainNavigationSearchHistoryTextButtonState();
}

class _MainNavigationSearchHistoryTextButtonState
    extends State<_MainNavigationSearchHistoryTextButton> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = MainNavigationViewColors.of(context);
    final enabled = widget.onPressed != null;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: SizedBox(
            height: 30,
            child: Center(
              child: Text(
                widget.label,
                style: TextStyle(
                  color:
                      _hovered && enabled
                          ? colors.accentStrong
                          : colors.searchHistoryHeader,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MainNavigationSearchHistoryIconButton extends StatefulWidget {
  const _MainNavigationSearchHistoryIconButton({
    required this.tooltip,
    required this.onPressed,
  });

  final String tooltip;
  final VoidCallback onPressed;

  @override
  State<_MainNavigationSearchHistoryIconButton> createState() =>
      _MainNavigationSearchHistoryIconButtonState();
}

class _MainNavigationSearchHistoryIconButtonState
    extends State<_MainNavigationSearchHistoryIconButton> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = MainNavigationViewColors.of(context);
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
          });
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: SizedBox.square(
            dimension: 30,
            child: Center(
              child: Icon(
                FluentIcons.dismiss_16_regular,
                size: 14,
                color:
                    _hovered
                        ? colors.accentStrong
                        : colors.searchHistoryHeader,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
