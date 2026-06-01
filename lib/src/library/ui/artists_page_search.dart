part of 'artists_page.dart';

class _ArtistsAppBarSearchActions extends StatefulWidget {
  const _ArtistsAppBarSearchActions({
    required this.searchOpen,
    required this.artistSearch,
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
  });

  final bool searchOpen;
  final String artistSearch;
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

  @override
  State<_ArtistsAppBarSearchActions> createState() =>
      _ArtistsAppBarSearchActionsState();
}

class _ArtistsAppBarSearchActionsState
    extends State<_ArtistsAppBarSearchActions> {
  final _dropdownController = OverlayPortalController();

  bool get _showSuggestions =>
      widget.searchFocused && widget.searchSuggestions.isNotEmpty;

  bool get _showHistory =>
      widget.searchFocused &&
      widget.artistSearch.trim().isEmpty &&
      widget.searchHistoryEntries.isNotEmpty;

  bool get _showDropdown => _showSuggestions || _showHistory;

  @override
  void didUpdateWidget(covariant _ArtistsAppBarSearchActions oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncDropdown();
  }

  void _syncDropdown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (_showDropdown && !_dropdownController.isShowing) {
        _dropdownController.show();
      } else if (!_showDropdown && _dropdownController.isShowing) {
        _dropdownController.hide();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.searchOpen) {
      return CommandBar(
        style: CommandBarStyleVariant.appBar,
        overflowLabel: widget.i18n.t('player.more'),
        children: [
          CommandBarButton(
            key: const ValueKey('Artists.AppBar.Search'),
            icon: FluentIcons.search_20_regular,
            label: widget.i18n.t('common.search'),
            active: false,
            activeSurface: false,
            showLabel: false,
            canOverflow: false,
            onPressed: widget.onOpenSearch,
          ),
        ],
      );
    }
    _syncDropdown();
    return OverlayPortal.overlayChildLayoutBuilder(
      controller: _dropdownController,
      overlayChildBuilder: (context, info) {
        final origin = MatrixUtils.transformPoint(
          info.childPaintTransform,
          Offset.zero,
        );
        return Positioned(
          left: origin.dx,
          top: origin.dy + 42,
          width: max(0, info.childSize.width - 40),
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
        height: 36,
        width: double.infinity,
        child: Row(
          children: [
            Expanded(
              child: Focus(
                onKeyEvent: (node, event) {
                  if (event is KeyDownEvent &&
                      event.logicalKey == LogicalKeyboardKey.escape) {
                    widget.onCloseSearch();
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: PageSearchField(
                  key: const ValueKey('Artists.AppBar.SearchField'),
                  value: widget.artistSearch,
                  hintText: widget.i18n.t('artists.searchArtistsPlaceholder'),
                  focused: widget.searchFocused,
                  autofocus: true,
                  height: 36,
                  appBar: true,
                  onChanged: widget.onSearchChanged,
                  onFocusChanged: widget.onSearchFocusChanged,
                  onSubmitted: widget.onSearchSubmitted,
                  onClear: widget.onClearSearch,
                  searchTooltip: widget.i18n.t('common.search'),
                  clearTooltip: widget.i18n.t('common.clear'),
                ),
              ),
            ),
            const SizedBox(width: 4),
            AppBarPageSearchCloseButton(
              tooltip: widget.i18n.t('common.close'),
              onPressed: widget.onCloseSearch,
            ),
          ],
        ),
      ),
    );
  }
}

class _ArtistsSearchBox extends StatefulWidget {
  const _ArtistsSearchBox({
    required this.artistSearch,
    required this.i18n,
    required this.searchFocused,
    required this.searchSuggestions,
    required this.searchHistoryEntries,
    required this.onChanged,
    required this.onFocusChanged,
    required this.onSubmitted,
    required this.onSelectSearchSuggestion,
    required this.onRemoveRecentSearch,
    required this.onClearRecentSearches,
  });

  final String artistSearch;
  final SmPlayerI18n i18n;
  final bool searchFocused;
  final List<String> searchSuggestions;
  final List<SearchHistoryEntry> searchHistoryEntries;
  final ValueChanged<String> onChanged;
  final ValueChanged<bool> onFocusChanged;
  final VoidCallback onSubmitted;
  final ValueChanged<String> onSelectSearchSuggestion;
  final ValueChanged<int> onRemoveRecentSearch;
  final VoidCallback onClearRecentSearches;

  @override
  State<_ArtistsSearchBox> createState() => _ArtistsSearchBoxState();
}

class _ArtistsSearchBoxState extends State<_ArtistsSearchBox> {
  final _dropdownController = OverlayPortalController();

  bool get _showSuggestions =>
      widget.searchFocused && widget.searchSuggestions.isNotEmpty;

  bool get _showHistory =>
      widget.searchFocused &&
      widget.artistSearch.trim().isEmpty &&
      widget.searchHistoryEntries.isNotEmpty;

  bool get _showDropdown => _showSuggestions || _showHistory;

  @override
  void didUpdateWidget(covariant _ArtistsSearchBox oldWidget) {
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
    return OverlayPortal.overlayChildLayoutBuilder(
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
        height: 40,
        child: PageSearchField(
          value: widget.artistSearch,
          hintText: widget.i18n.t('artists.searchArtistsPlaceholder'),
          focused: widget.searchFocused,
          onChanged: widget.onChanged,
          onFocusChanged: widget.onFocusChanged,
          onSubmitted: widget.onSubmitted,
          onClear: () {
            widget.onChanged('');
          },
          searchTooltip: widget.i18n.t('common.search'),
          clearTooltip: widget.i18n.t('common.clear'),
        ),
      ),
    );
  }
}
