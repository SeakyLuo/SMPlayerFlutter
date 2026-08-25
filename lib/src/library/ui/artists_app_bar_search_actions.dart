part of 'artists_page.dart';

class _ArtistsAppBarSearchActions extends StatefulWidget {
  const _ArtistsAppBarSearchActions({
    required this.searchOpen,
    required this.artistSearch,
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
    required this.onChangeArtistSort,
  });

  final bool searchOpen;
  final String artistSearch;
  final ArtistSortCriterion sortCriterion;
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
  final ValueChanged<ArtistSortCriterion> onChangeArtistSort;

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
          CommandBarButton(
            key: const ValueKey('Artists.AppBar.Sort'),
            icon: FluentIcons.arrow_sort_20_regular,
            label: artistSortLabel(widget.i18n, widget.sortCriterion),
            showLabel: false,
            canOverflow: false,
            onPressedWithContext: (context) {
              showMenuFlyout(
                context,
                items: artistSortMenuItems(
                  widget.i18n,
                  widget.sortCriterion,
                  widget.onChangeArtistSort,
                ),
              );
            },
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

class _ArtistsOverflowTooltipText extends StatelessWidget {
  const _ArtistsOverflowTooltipText({
    super.key,
    required this.text,
    required this.style,
  });

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: text, style: style),
          maxLines: 1,
          textDirection: Directionality.of(context),
          textScaler: TextScaler.noScaling,
          locale: Localizations.maybeLocaleOf(context),
        )..layout(maxWidth: constraints.maxWidth);
        final label = Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textScaler: TextScaler.noScaling,
          style: style,
        );
        return painter.didExceedMaxLines
            ? Tooltip(message: text, child: label)
            : label;
      },
    );
  }
}
