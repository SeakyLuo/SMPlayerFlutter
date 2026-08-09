part of 'albums_page.dart';

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
          overlayLocation: OverlayChildLocation.rootOverlay,
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
            activeMatchesHover: true,
            tooltip:
                widget.multiSelect
                    ? widget.i18n.t('common.exitMultiSelectTooltip')
                    : null,
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
