part of 'albums_page.dart';

class _AlbumGridDelegate extends SliverGridDelegate {
  const _AlbumGridDelegate({
    required this.crossAxisCount,
    required this.crossAxisExtent,
    required this.mainAxisExtent,
    required this.crossAxisSpacing,
  });

  final int crossAxisCount;
  final double crossAxisExtent;
  final double mainAxisExtent;
  final double crossAxisSpacing;

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    return SliverGridRegularTileLayout(
      crossAxisCount: crossAxisCount,
      mainAxisStride: mainAxisExtent,
      crossAxisStride: crossAxisExtent + crossAxisSpacing,
      childMainAxisExtent: mainAxisExtent,
      childCrossAxisExtent: crossAxisExtent,
      reverseCrossAxis: axisDirectionIsReversed(constraints.crossAxisDirection),
    );
  }

  @override
  bool shouldRelayout(_AlbumGridDelegate oldDelegate) {
    return oldDelegate.crossAxisCount != crossAxisCount ||
        oldDelegate.crossAxisExtent != crossAxisExtent ||
        oldDelegate.mainAxisExtent != mainAxisExtent ||
        oldDelegate.crossAxisSpacing != crossAxisSpacing;
  }
}

class _AlbumsToolbar extends StatefulWidget {
  const _AlbumsToolbar({
    required this.searchDraft,
    required this.searchHasText,
    required this.sortCriterion,
    required this.multiSelect,
    required this.i18n,
    required this.searchFocused,
    required this.searchSuggestions,
    required this.searchHistoryEntries,
    required this.onSearchChanged,
    required this.onSearchFocusChanged,
    required this.onSearchSubmitted,
    required this.onClearSearch,
    required this.onSelectSearchSuggestion,
    required this.onRemoveRecentSearch,
    required this.onClearRecentSearches,
    required this.onChangeAlbumSort,
    required this.onToggleMultiSelect,
  });

  final String searchDraft;
  final bool searchHasText;
  final AlbumSortCriterion sortCriterion;
  final bool multiSelect;
  final SmPlayerI18n i18n;
  final bool searchFocused;
  final List<String> searchSuggestions;
  final List<SearchHistoryEntry> searchHistoryEntries;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<bool> onSearchFocusChanged;
  final VoidCallback onSearchSubmitted;
  final VoidCallback onClearSearch;
  final ValueChanged<String> onSelectSearchSuggestion;
  final ValueChanged<int> onRemoveRecentSearch;
  final VoidCallback onClearRecentSearches;
  final ValueChanged<AlbumSortCriterion> onChangeAlbumSort;
  final VoidCallback onToggleMultiSelect;

  @override
  State<_AlbumsToolbar> createState() => _AlbumsToolbarState();
}

class _AlbumsToolbarState extends State<_AlbumsToolbar> {
  final _dropdownController = OverlayPortalController();

  bool get _showSuggestions =>
      widget.searchFocused && widget.searchSuggestions.isNotEmpty;

  bool get _showHistory =>
      widget.searchFocused &&
      widget.searchDraft.trim().isEmpty &&
      widget.searchHistoryEntries.isNotEmpty;

  bool get _showDropdown => _showSuggestions || _showHistory;

  @override
  void didUpdateWidget(covariant _AlbumsToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncDropdown();
  }

  void _syncDropdown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (_showDropdown) {
        _dropdownController.show();
      } else {
        _dropdownController.hide();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    _syncDropdown();
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 12),
      child: CommandBar(
        overflowLabel: widget.i18n.t('player.more'),
        content: OverlayPortal.overlayChildLayoutBuilder(
          controller: _dropdownController,
          overlayChildBuilder: (context, info) {
            final origin = MatrixUtils.transformPoint(
              info.childPaintTransform,
              Offset.zero,
            );
            return Positioned(
              left: origin.dx,
              top: origin.dy + info.childSize.height + 8,
              width: info.childSize.width,
              child:
                  _showSuggestions
                      ? PageSearchSuggestionPanel(
                        labels: widget.searchSuggestions,
                        onSelect: widget.onSelectSearchSuggestion,
                      )
                      : PageSearchHistoryPanel(
                        entries: widget.searchHistoryEntries,
                        i18n: widget.i18n,
                        onSelect: widget.onSelectSearchSuggestion,
                        onRemove: widget.onRemoveRecentSearch,
                        onClear: widget.onClearRecentSearches,
                      ),
            );
          },
          child: SizedBox(
            width: 360,
            height: 40,
            child: PageSearchField(
              value: widget.searchDraft,
              hintText: widget.i18n.t('albums.searchAlbumPlaceholder'),
              focused: widget.searchFocused,
              onChanged: widget.onSearchChanged,
              onFocusChanged: widget.onSearchFocusChanged,
              onSubmitted: widget.onSearchSubmitted,
              onClear: widget.onClearSearch,
              searchTooltip: widget.i18n.t('common.search'),
              clearTooltip: widget.i18n.t('common.clear'),
            ),
          ),
        ),
        children: [
          CommandBarButton(
            icon: FluentIcons.multiselect_ltr_24_regular,
            label: widget.i18n.t('common.multiSelect'),
            active: widget.multiSelect,
            onPressed: widget.onToggleMultiSelect,
          ),
          Builder(
            builder: (context) {
              final sortItems = _albumSortMenuItems(
                widget.i18n,
                widget.sortCriterion,
                widget.onChangeAlbumSort,
              );
              return CommandBarButton(
                icon: FluentIcons.arrow_sort_24_regular,
                label: _albumSortLabel(widget.i18n, widget.sortCriterion),
                onPressed: () {
                  showMenuFlyout(context, items: sortItems);
                },
                onOverflowPressedWithContext: (buttonContext) {
                  unawaited(showMenuFlyout(buttonContext, items: sortItems));
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AlbumsAppBarActions extends StatelessWidget {
  const _AlbumsAppBarActions({
    required this.searchOpen,
    required this.searchDraft,
    required this.searchHasText,
    required this.sortCriterion,
    required this.i18n,
    required this.searchFocused,
    required this.searchSuggestions,
    required this.searchHistoryEntries,
    required this.onOpenSearch,
    required this.onCloseSearch,
    required this.onSearchChanged,
    required this.onSearchFocusChanged,
    required this.onSearchSubmitted,
    required this.onClearSearch,
    required this.onSelectSearchSuggestion,
    required this.onRemoveRecentSearch,
    required this.onClearRecentSearches,
    required this.onChangeAlbumSort,
  });

  final bool searchOpen;
  final String searchDraft;
  final bool searchHasText;
  final AlbumSortCriterion sortCriterion;
  final SmPlayerI18n i18n;
  final bool searchFocused;
  final List<String> searchSuggestions;
  final List<SearchHistoryEntry> searchHistoryEntries;
  final VoidCallback onOpenSearch;
  final VoidCallback onCloseSearch;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<bool> onSearchFocusChanged;
  final VoidCallback onSearchSubmitted;
  final VoidCallback onClearSearch;
  final ValueChanged<String> onSelectSearchSuggestion;
  final ValueChanged<int> onRemoveRecentSearch;
  final VoidCallback onClearRecentSearches;
  final ValueChanged<AlbumSortCriterion> onChangeAlbumSort;

  @override
  Widget build(BuildContext context) {
    final showSuggestions = searchFocused && searchSuggestions.isNotEmpty;
    final showHistory =
        searchFocused &&
        searchDraft.trim().isEmpty &&
        searchHistoryEntries.isNotEmpty;
    final panel = Material(
      key: const ValueKey('Albums.AppBarActions'),
      color: Colors.transparent,
      child: Padding(
        padding: EdgeInsets.zero,
        child:
            searchOpen
                ? SizedBox(
                  height: 36,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Focus(
                              onKeyEvent: (node, event) {
                                if (event is KeyDownEvent &&
                                    event.logicalKey ==
                                        LogicalKeyboardKey.escape) {
                                  onCloseSearch();
                                  return KeyEventResult.handled;
                                }
                                return KeyEventResult.ignored;
                              },
                              child: PageSearchField(
                                key: const ValueKey(
                                  'Albums.AppBar.SearchField',
                                ),
                                value: searchDraft,
                                hintText: i18n.t(
                                  'albums.searchAlbumPlaceholder',
                                ),
                                focused: searchFocused,
                                autofocus: true,
                                height: 36,
                                appBar: true,
                                onChanged: onSearchChanged,
                                onFocusChanged: onSearchFocusChanged,
                                onSubmitted: onSearchSubmitted,
                                onClear: onClearSearch,
                                searchTooltip: i18n.t('common.search'),
                                clearTooltip: i18n.t('common.clear'),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          AppBarPageSearchCloseButton(
                            tooltip: i18n.t('common.close'),
                            onPressed: onCloseSearch,
                          ),
                        ],
                      ),
                      if (showSuggestions || showHistory)
                        Positioned(
                          top: 42,
                          left: 0,
                          right: 40,
                          child:
                              showSuggestions
                                  ? PageSearchSuggestionPanel(
                                    labels: searchSuggestions,
                                    onSelect: onSelectSearchSuggestion,
                                  )
                                  : PageSearchHistoryPanel(
                                    entries: searchHistoryEntries,
                                    i18n: i18n,
                                    onSelect: onSelectSearchSuggestion,
                                    onRemove: onRemoveRecentSearch,
                                    onClear: onClearRecentSearches,
                                  ),
                        ),
                    ],
                  ),
                )
                : CommandBar(
                  style: CommandBarStyleVariant.appBar,
                  overflowLabel: i18n.t('player.more'),
                  children: [
                    CommandBarButton(
                      key: const ValueKey('Albums.AppBar.Search'),
                      icon: FluentIcons.search_20_regular,
                      label: i18n.t('common.search'),
                      active: searchHasText,
                      showLabel: false,
                      canOverflow: false,
                      onPressed: onOpenSearch,
                    ),
                    Builder(
                      builder: (context) {
                        return CommandBarButton(
                          key: const ValueKey('Albums.AppBar.Sort'),
                          icon: FluentIcons.arrow_sort_20_regular,
                          label: _albumSortLabel(i18n, sortCriterion),
                          showLabel: false,
                          canOverflow: false,
                          onPressed: () {
                            showMenuFlyout(
                              context,
                              items: _albumSortMenuItems(
                                i18n,
                                sortCriterion,
                                onChangeAlbumSort,
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
      ),
    );
    return panel;
  }
}

class _AlbumsQuickJump extends StatelessWidget {
  const _AlbumsQuickJump({
    required this.activeKey,
    required this.enabledKeys,
    required this.i18n,
    required this.onJump,
  });

  final String activeKey;
  final Set<String> enabledKeys;
  final SmPlayerI18n i18n;
  final ValueChanged<String> onJump;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      width: _albumQuickJumpWidth,
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 18),
      child: Column(
        children:
            artistQuickJumpKeys.map((key) {
              final enabled = enabledKeys.contains(key);
              final active = activeKey == key;
              return Expanded(
                child: Tooltip(
                  message: getQuickJumpTooltip(
                    key: key,
                    enabled: enabled,
                    targetName: i18n.t('common.albums'),
                    basisName: i18n.t('common.album'),
                    i18n: i18n,
                  ),
                  child: TextButton(
                    key: ValueKey('Albums.QuickJump.$key'),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(20, 0),
                      foregroundColor:
                          enabled
                              ? active
                                  ? _AlbumsColors.quickJumpActiveForeground(
                                    brightness,
                                  )
                                  : _AlbumsColors.quickJumpForeground(
                                    brightness,
                                  )
                              : _AlbumsColors.quickJumpDisabled(brightness),
                      backgroundColor:
                          active
                              ? _AlbumsColors.quickJumpActiveBackground(
                                brightness,
                              )
                              : Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    onPressed:
                        enabled
                            ? () {
                              onJump(key);
                            }
                            : null,
                    child: Text(
                      key,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }
}

class _AlbumsProgress extends StatefulWidget {
  const _AlbumsProgress({super.key});

  @override
  State<_AlbumsProgress> createState() => _AlbumsProgressState();
}

class _AlbumsProgressState extends State<_AlbumsProgress>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Transform.translate(
        offset: const Offset(0, -6),
        child: Container(
          height: 3,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: _AlbumsColors.accentProgressTrackFor(brightness),
            borderRadius: BorderRadius.circular(999),
          ),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final offset = lerpDouble(-1.2, 3.4, _controller.value)!;
              return FractionalTranslation(
                translation: Offset(offset, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(widthFactor: 0.34, child: child),
                ),
              );
            },
            child: ColoredBox(color: _AlbumsColors.accentFor(brightness)),
          ),
        ),
      ),
    );
  }
}

class _AlbumsPagePanel extends StatelessWidget {
  const _AlbumsPagePanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
      child: SizedBox.expand(child: child),
    );
  }
}

class _AlbumsEmptyState extends StatelessWidget {
  const _AlbumsEmptyState({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return DecoratedBox(
      key: const ValueKey('Albums.EmptyState'),
      decoration: BoxDecoration(
        color: _AlbumsColors.emptyStateSurfaceFor(brightness),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _AlbumsColors.emptyStateBorderFor(brightness),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: _AlbumsColors.textStrongFor(brightness),
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Text(
                message,
                style: TextStyle(
                  color: _AlbumsColors.textMutedFor(brightness),
                  fontSize: 14,
                  height: 1.65,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
