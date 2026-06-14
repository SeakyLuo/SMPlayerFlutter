part of 'page_search_history_panel.dart';

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
    this.backdropKey,
    this.panelKey,
    this.headerKey,
    this.listKey,
    this.itemKeyBuilder,
    this.selectKeyBuilder,
    this.removeKeyBuilder,
    this.includeBorderInset = false,
    this.useElectronPanelStyle = false,
  });

  final List<SearchHistoryPanelItem<TValue>> items;
  final String title;
  final ValueChanged<SearchHistoryPanelItem<TValue>> onSelect;
  final String? clearLabel;
  final VoidCallback? onClear;
  final ValueChanged<SearchHistoryPanelItem<TValue>>? onRemove;
  final String Function(SearchHistoryPanelItem<TValue> item)? getRemoveLabel;
  final Key? backdropKey;
  final Key? panelKey;
  final Key? headerKey;
  final Key? listKey;
  final Key Function(SearchHistoryPanelItem<TValue> item)? itemKeyBuilder;
  final Key Function(SearchHistoryPanelItem<TValue> item)? selectKeyBuilder;
  final Key Function(SearchHistoryPanelItem<TValue> item)? removeKeyBuilder;
  final bool includeBorderInset;
  final bool useElectronPanelStyle;

  @override
  Widget build(BuildContext context) {
    final colors = _PageSearchColors.resolve(context, appBar: false);
    const radius = 14.0;
    if (useElectronPanelStyle) {
      final panelColors = _ElectronSearchHistoryPanelColors.resolve(context);
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: DecoratedBox(
          key: panelKey,
          decoration: BoxDecoration(
            color: panelColors.background,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: panelColors.border),
            boxShadow: [
              BoxShadow(
                color: panelColors.shadow,
                blurRadius: 36,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: BackdropFilter(
            key: backdropKey,
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: _SearchHistoryPanelContent<TValue>(
              items: items,
              title: title,
              onSelect: onSelect,
              clearLabel: clearLabel,
              onClear: onClear,
              onRemove: onRemove,
              getRemoveLabel: getRemoveLabel,
              headerKey: headerKey,
              listKey: listKey,
              itemKeyBuilder: itemKeyBuilder,
              selectKeyBuilder: selectKeyBuilder,
              removeKeyBuilder: removeKeyBuilder,
              includeBorderInset: includeBorderInset,
            ),
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: GlassContainer(
        key: panelKey,
        useOwnLayer: true,
        quality: GlassQuality.minimal,
        clipBehavior: Clip.hardEdge,
        shape: const LiquidRoundedRectangle(borderRadius: radius),
        settings: LiquidGlassSettings(
          blur: 46,
          thickness: 20,
          refractiveIndex: 1.06,
          saturation: 1.65,
          chromaticAberration: 0,
          lightIntensity: 0.1,
          ambientStrength: 0.08,
          glowIntensity: 0.04,
          glassColor: colors.dropdownSurface,
          standardOpacityMultiplier: 0.32,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            boxShadow: [
              BoxShadow(
                color: colors.dropdownShadow,
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: colors.dropdownBorder),
            ),
            child: BackdropFilter(
              key: backdropKey,
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: _SearchHistoryPanelContent<TValue>(
                items: items,
                title: title,
                onSelect: onSelect,
                clearLabel: clearLabel,
                onClear: onClear,
                onRemove: onRemove,
                getRemoveLabel: getRemoveLabel,
                headerKey: headerKey,
                listKey: listKey,
                itemKeyBuilder: itemKeyBuilder,
                selectKeyBuilder: selectKeyBuilder,
                removeKeyBuilder: removeKeyBuilder,
                includeBorderInset: includeBorderInset,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchHistoryPanelContent<TValue> extends StatelessWidget {
  const _SearchHistoryPanelContent({
    required this.items,
    required this.title,
    required this.onSelect,
    required this.clearLabel,
    required this.onClear,
    required this.onRemove,
    required this.getRemoveLabel,
    required this.headerKey,
    required this.listKey,
    required this.itemKeyBuilder,
    required this.selectKeyBuilder,
    required this.removeKeyBuilder,
    required this.includeBorderInset,
  });

  final List<SearchHistoryPanelItem<TValue>> items;
  final String title;
  final ValueChanged<SearchHistoryPanelItem<TValue>> onSelect;
  final String? clearLabel;
  final VoidCallback? onClear;
  final ValueChanged<SearchHistoryPanelItem<TValue>>? onRemove;
  final String Function(SearchHistoryPanelItem<TValue> item)? getRemoveLabel;
  final Key? headerKey;
  final Key? listKey;
  final Key Function(SearchHistoryPanelItem<TValue> item)? itemKeyBuilder;
  final Key Function(SearchHistoryPanelItem<TValue> item)? selectKeyBuilder;
  final Key Function(SearchHistoryPanelItem<TValue> item)? removeKeyBuilder;
  final bool includeBorderInset;

  @override
  Widget build(BuildContext context) {
    final colors = _PageSearchColors.resolve(context, appBar: false);
    return Padding(
      padding: EdgeInsets.all(includeBorderInset ? 9 : 8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title.isNotEmpty) ...[
              SizedBox(
                key: headerKey,
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
              child: SingleChildScrollView(
                child: Column(
                  key: listKey,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final item in items) ...[
                      _SearchHistoryPanelRow<TValue>(
                        item: item,
                        itemKey:
                            itemKeyBuilder == null
                                ? ValueKey(
                                  'PageSearchHistoryPanel.Item.${item.label}',
                                )
                                : itemKeyBuilder!(item),
                        selectKey:
                            selectKeyBuilder == null
                                ? null
                                : selectKeyBuilder!(item),
                        removeKey:
                            removeKeyBuilder == null
                                ? null
                                : removeKeyBuilder!(item),
                        onSelect: onSelect,
                        onRemove: onRemove,
                        removeLabel:
                            getRemoveLabel == null
                                ? null
                                : getRemoveLabel!(item),
                      ),
                      if (item != items.last) const SizedBox(height: 2),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchHistoryPanelRow<TValue> extends StatelessWidget {
  const _SearchHistoryPanelRow({
    required this.item,
    required this.itemKey,
    required this.selectKey,
    required this.removeKey,
    required this.onSelect,
    required this.onRemove,
    required this.removeLabel,
  });

  final SearchHistoryPanelItem<TValue> item;
  final Key itemKey;
  final Key? selectKey;
  final Key? removeKey;
  final ValueChanged<SearchHistoryPanelItem<TValue>> onSelect;
  final ValueChanged<SearchHistoryPanelItem<TValue>>? onRemove;
  final String? removeLabel;

  @override
  Widget build(BuildContext context) {
    final colors = _PageSearchColors.resolve(context, appBar: false);
    final removeTooltip = removeLabel;
    return _SearchHistoryHoverContainer(
      borderRadius: BorderRadius.circular(10),
      builder: (context, hovered) {
        return AnimatedContainer(
          key: itemKey,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: hovered ? colors.rowHover : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: SizedBox(
            height: 38,
            child: Row(
              spacing: onRemove == null ? 0 : 4,
              children: [
                Expanded(
                  child: _SearchHistorySelectButton(
                    key: selectKey,
                    label: item.label,
                    onPressed: () {
                      onSelect(item);
                    },
                  ),
                ),
                if (onRemove != null && removeTooltip != null)
                  _SearchHistoryRemoveButton(
                    key: removeKey,
                    tooltip: removeTooltip,
                    onPressed: () {
                      onRemove!(item);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SearchHistoryHoverContainer extends StatefulWidget {
  const _SearchHistoryHoverContainer({
    required this.borderRadius,
    required this.builder,
  });

  final BorderRadius borderRadius;
  final Widget Function(BuildContext context, bool hovered) builder;

  @override
  State<_SearchHistoryHoverContainer> createState() =>
      _SearchHistoryHoverContainerState();
}

class _SearchHistoryHoverContainerState
    extends State<_SearchHistoryHoverContainer> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
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
      child: ClipRRect(
        borderRadius: widget.borderRadius,
        child: widget.builder(context, _hovered),
      ),
    );
  }
}

class _SearchHistorySelectButton extends StatelessWidget {
  const _SearchHistorySelectButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = _PageSearchColors.resolve(context, appBar: false);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Semantics(
        button: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: SizedBox(
            height: 38,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  label,
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
      ),
    );
  }
}

class _SearchHistoryRemoveButton extends StatefulWidget {
  const _SearchHistoryRemoveButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
  });

  final String tooltip;
  final VoidCallback onPressed;

  @override
  State<_SearchHistoryRemoveButton> createState() =>
      _SearchHistoryRemoveButtonState();
}

class _SearchHistoryRemoveButtonState
    extends State<_SearchHistoryRemoveButton> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = _PageSearchColors.resolve(context, appBar: false);
    return Semantics(
      label: widget.tooltip,
      button: true,
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
                color: _hovered ? colors.accent : colors.header,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
