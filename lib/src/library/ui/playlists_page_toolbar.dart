part of 'playlists_page.dart';

class _PlaylistsToolbar extends StatefulWidget {
  const _PlaylistsToolbar({
    required this.searchDraft,
    required this.searchHasText,
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
    required this.onCreatePlaylist,
  });

  final String searchDraft;
  final bool searchHasText;
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
  final VoidCallback onCreatePlaylist;

  @override
  State<_PlaylistsToolbar> createState() => _PlaylistsToolbarState();
}

class _PlaylistsToolbarState extends State<_PlaylistsToolbar> {
  final _dropdownController = OverlayPortalController();

  bool get _showSuggestions =>
      widget.searchFocused && widget.searchSuggestions.isNotEmpty;

  bool get _showHistory =>
      widget.searchFocused &&
      widget.searchDraft.trim().isEmpty &&
      widget.searchHistoryEntries.isNotEmpty;

  bool get _showDropdown => _showSuggestions || _showHistory;

  @override
  void didUpdateWidget(covariant _PlaylistsToolbar oldWidget) {
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

  void _dismissDropdown() {
    FocusManager.instance.primaryFocus?.unfocus();
    widget.onSearchFocusChanged(false);
    _dropdownController.hide();
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
            return Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: origin.dy + info.childSize.height,
                  bottom: 0,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _dismissDropdown,
                    child: const SizedBox.expand(),
                  ),
                ),
                Positioned(
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
                ),
              ],
            );
          },
          child: SizedBox(
            width: 360,
            height: 40,
            child: PageSearchField(
              value: widget.searchDraft,
              hintText: widget.i18n.t('playlists.searchPlaylistPlaceholder'),
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
            icon: FluentIcons.add_20_regular,
            label: widget.i18n.t('playlists.newName'),
            canOverflow: false,
            onPressed: widget.onCreatePlaylist,
          ),
        ],
      ),
    );
  }
}
