part of 'playlists_page.dart';

class _PlaylistsAppBarActions extends StatefulWidget {
  const _PlaylistsAppBarActions({
    required this.searchOpen,
    required this.searchDraft,
    required this.searchHasText,
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
    required this.onCreatePlaylist,
  });

  final bool searchOpen;
  final String searchDraft;
  final bool searchHasText;
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
  final VoidCallback onCreatePlaylist;

  @override
  State<_PlaylistsAppBarActions> createState() =>
      _PlaylistsAppBarActionsState();
}

class _PlaylistsAppBarActionsState extends State<_PlaylistsAppBarActions> {
  final _dropdownController = OverlayPortalController();

  bool get _showSuggestions =>
      widget.searchFocused && widget.searchSuggestions.isNotEmpty;

  bool get _showHistory =>
      widget.searchFocused &&
      widget.searchDraft.trim().isEmpty &&
      widget.searchHistoryEntries.isNotEmpty;

  bool get _showDropdown => _showSuggestions || _showHistory;

  @override
  void didUpdateWidget(covariant _PlaylistsAppBarActions oldWidget) {
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

  void _dismissDropdown() {
    FocusManager.instance.primaryFocus?.unfocus();
    widget.onSearchFocusChanged(false);
    _dropdownController.hide();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.searchOpen) {
      return Material(
        key: const ValueKey('Playlists.AppBarActions'),
        color: Colors.transparent,
        child: CommandBar(
          style: CommandBarStyleVariant.appBar,
          overflowLabel: widget.i18n.t('player.more'),
          children: [
            CommandBarButton(
              key: const ValueKey('Playlists.AppBar.Search'),
              icon: FluentIcons.search_20_regular,
              label: widget.i18n.t('common.search'),
              active: widget.searchHasText,
              showLabel: false,
              canOverflow: false,
              onPressed: widget.onOpenSearch,
            ),
            CommandBarButton(
              key: const ValueKey('Playlists.AppBar.Create'),
              icon: FluentIcons.add_20_regular,
              label: widget.i18n.t('playlists.newName'),
              showLabel: false,
              canOverflow: false,
              onPressed: widget.onCreatePlaylist,
            ),
          ],
        ),
      );
    }
    _syncDropdown();
    return Material(
      key: const ValueKey('Playlists.AppBarActions'),
      color: Colors.transparent,
      child: Align(
        alignment: Alignment.center,
        child: OverlayPortal.overlayChildLayoutBuilder(
          controller: _dropdownController,
          overlayLocation: OverlayChildLocation.rootOverlay,
          overlayChildBuilder: (context, info) {
            final origin = MatrixUtils.transformPoint(
              info.childPaintTransform,
              Offset.zero,
            );
            return Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: origin.dy + 42,
                  bottom: 0,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _dismissDropdown,
                    child: const SizedBox.expand(),
                  ),
                ),
                Positioned(
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
                ),
              ],
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
                      key: const ValueKey('Playlists.AppBar.SearchField'),
                      value: widget.searchDraft,
                      hintText: widget.i18n.t(
                        'playlists.searchPlaylistPlaceholder',
                      ),
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
        ),
      ),
    );
  }
}
