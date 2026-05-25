part of 'main_navigation_view.dart';

class _MainNavigationViewSearchBox extends StatefulWidget {
  const _MainNavigationViewSearchBox({
    required this.collapsed,
    required this.value,
    required this.i18n,
    required this.focusNode,
    required this.onChanged,
    required this.onSubmitted,
    required this.onCleared,
    required this.onFocusChanged,
    required this.onSearchHistoryRequested,
    required this.onSearchHistoryDismissed,
    required this.onCollapsedSearchPressed,
    required this.searchFieldLayerLink,
    this.onTooltipRequested,
    this.onTooltipDismissed,
  });

  final bool collapsed;
  final String value;
  final SmPlayerI18n i18n;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onCleared;
  final ValueChanged<bool> onFocusChanged;
  final VoidCallback onSearchHistoryRequested;
  final VoidCallback onSearchHistoryDismissed;
  final VoidCallback onCollapsedSearchPressed;
  final LayerLink searchFieldLayerLink;
  final _NavigationTooltipRequest? onTooltipRequested;
  final VoidCallback? onTooltipDismissed;

  @override
  State<_MainNavigationViewSearchBox> createState() =>
      _MainNavigationViewSearchBoxState();
}

class _MainNavigationViewSearchBoxState
    extends State<_MainNavigationViewSearchBox> {
  late final TextEditingController _controller;
  var _focused = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    widget.focusNode.addListener(_handleFocusChanged);
  }

  @override
  void didUpdateWidget(covariant _MainNavigationViewSearchBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller.text != widget.value) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_handleFocusChanged);
    _controller.dispose();
    super.dispose();
  }

  void _handleFocusChanged() {
    final focused = widget.focusNode.hasFocus;
    if (_focused != focused) {
      setState(() {
        _focused = focused;
      });
    }
    widget.onFocusChanged(focused);
  }

  @override
  Widget build(BuildContext context) {
    final colors = MainNavigationViewColors.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        if (widget.collapsed || constraints.maxWidth <= 64) {
          return _NavigationIconButton(
            key: const ValueKey('MainNavigationView.SearchButton'),
            icon: FluentIcons.search_24_regular,
            tooltip: widget.i18n.t('common.search'),
            collapsedContext: true,
            onPressed: widget.onCollapsedSearchPressed,
            onTooltipRequested: widget.onTooltipRequested,
            onTooltipDismissed: widget.onTooltipDismissed,
          );
        }

        return SizedBox(
          key: const ValueKey('MainNavigationView.SearchFieldShell'),
          height: 40,
          child: CompositedTransformTarget(
            link: widget.searchFieldLayerLink,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                DecoratedBox(
                  key: const ValueKey('MainNavigationView.SearchForm'),
                  decoration: BoxDecoration(
                    color:
                        _focused
                            ? colors.focusedSearchSurface
                            : colors.searchSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color:
                          _focused
                              ? colors.focusedSearchBorder
                              : colors.searchBorder,
                    ),
                    boxShadow:
                        _focused
                            ? [
                              BoxShadow(
                                color: colors.searchFocusRing,
                                blurRadius: 0,
                                spreadRadius: 3,
                              ),
                            ]
                            : [
                              BoxShadow(
                                color: colors.searchInsetHighlight,
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
                        width: 40,
                        height: 40,
                        child: SearchCommitIconButton(
                          tooltip: widget.i18n.t('common.search'),
                          foreground: SearchCommitIconButton.foregroundFor(
                            context,
                          ),
                          hoverForeground:
                              SearchCommitIconButton.hoverForegroundFor(
                                context,
                              ),
                          onPressed: () {
                            widget.onSubmitted(_controller.text);
                          },
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          key: const ValueKey(
                            'MainNavigationView.SearchTextField',
                          ),
                          controller: _controller,
                          focusNode: widget.focusNode,
                          onTapAlwaysCalled: true,
                          onTap: () {
                            setState(() {
                              _focused = true;
                            });
                            widget.onFocusChanged(true);
                            widget.onSearchHistoryRequested();
                          },
                          onTapOutside: (_) {
                            setState(() {
                              _focused = false;
                            });
                            widget.focusNode.unfocus();
                            widget.onSearchHistoryDismissed();
                          },
                          onChanged: widget.onChanged,
                          onSubmitted: widget.onSubmitted,
                          textInputAction: TextInputAction.search,
                          style: TextStyle(
                            fontSize: 14,
                            color: colors.textStrong,
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: widget.i18n.t('common.search'),
                            hintStyle: TextStyle(
                              color: colors.searchPlaceholder,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      if (widget.value.isNotEmpty)
                        SizedBox(
                          width: 24,
                          height: 40,
                          child: _SearchClearButton(
                            key: const ValueKey(
                              'MainNavigationView.ClearSearchButton',
                            ),
                            tooltip: widget.i18n.t('common.clear'),
                            onPressed: () {
                              widget.onChanged('');
                              widget.onCleared();
                            },
                          ),
                        ),
                      const SizedBox(width: 10),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SearchClearButton extends StatefulWidget {
  const _SearchClearButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
  });

  final String tooltip;
  final VoidCallback onPressed;

  @override
  State<_SearchClearButton> createState() => _SearchClearButtonState();
}

class _SearchClearButtonState extends State<_SearchClearButton> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = MainNavigationViewColors.of(context);
    return Tooltip(
      message: widget.tooltip,
      child: Center(
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
          child: Semantics(
            button: true,
            label: widget.tooltip,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onPressed,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color:
                      _hovered ? colors.clearButtonHover : colors.clearButton,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: SizedBox.square(
                  dimension: 24,
                  child: Icon(
                    FluentIcons.dismiss_16_regular,
                    size: 14,
                    color: colors.clearForeground,
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
