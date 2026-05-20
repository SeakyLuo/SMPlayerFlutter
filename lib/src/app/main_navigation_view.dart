import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';

class MainNavigationView extends StatefulWidget {
  const MainNavigationView({
    super.key,
    required this.isPaneOpen,
    required this.currentPath,
    required this.searchText,
    required this.i18n,
    required this.onPaneToggle,
    required this.onSearchTextChanged,
    required this.onSearchCommitted,
    required this.onItemInvoked,
    this.canGoBack = false,
    this.playlists = const [],
    this.recentSearches = const [],
    this.onGoBack,
    this.onCreatePlaylist,
    this.onPlaylistRandomPlay,
    this.onRecentSearchRemove,
    this.onRecentSearchesClear,
  });

  final bool isPaneOpen;
  final String currentPath;
  final String searchText;
  final SmPlayerI18n i18n;
  final List<LibraryPlaylist> playlists;
  final List<SearchHistoryEntry> recentSearches;
  final bool canGoBack;
  final VoidCallback onPaneToggle;
  final ValueChanged<String> onSearchTextChanged;
  final ValueChanged<String> onSearchCommitted;
  final ValueChanged<String> onItemInvoked;
  final VoidCallback? onGoBack;
  final VoidCallback? onCreatePlaylist;
  final ValueChanged<int>? onPlaylistRandomPlay;
  final ValueChanged<int>? onRecentSearchRemove;
  final VoidCallback? onRecentSearchesClear;

  @override
  State<MainNavigationView> createState() => _MainNavigationViewState();
}

class _MainNavigationViewState extends State<MainNavigationView> {
  static const _musicLibraryItem = MainNavigationViewItem(
    name: 'MusicLibraryItem',
    target: '/songs',
    labelKey: 'library.title',
    icon: FluentIcons.library_24_regular,
  );
  static const _artistsItem = MainNavigationViewItem(
    name: 'ArtistsItem',
    target: '/artists',
    labelKey: 'common.artists',
    icon: FluentIcons.people_24_regular,
  );
  static const _albumsItem = MainNavigationViewItem(
    name: 'AlbumsItem',
    target: '/albums',
    labelKey: 'common.albums',
    icon: FluentIcons.album_24_regular,
  );
  static const _localItem = MainNavigationViewItem(
    name: 'LocalItem',
    target: '/local',
    labelKey: 'common.local',
    icon: FluentIcons.hard_drive_24_regular,
  );
  static const _recentItem = MainNavigationViewItem(
    name: 'RecentItem',
    target: '/recent',
    labelKey: 'common.recent',
    icon: FluentIcons.clock_24_regular,
  );
  static const _nowPlayingItem = MainNavigationViewItem(
    name: 'NowPlayingItem',
    target: '/now-playing',
    labelKey: 'common.nowPlaying',
    icon: FluentIcons.music_note_2_24_regular,
  );
  static const _myFavoritesItem = MainNavigationViewItem(
    name: 'MyFavoritesItem',
    target: '/favorites',
    labelKey: 'common.myFavorites',
    icon: FluentIcons.heart_24_regular,
  );
  static const _playlistsItem = MainNavigationViewItem(
    name: 'PlaylistsItem',
    target: '/playlists',
    labelKey: 'common.playlists',
    icon: FluentIcons.apps_list_detail_24_regular,
    exactActive: true,
  );
  static const _settingsItem = MainNavigationViewItem(
    name: 'SettingsItem',
    target: '/settings',
    labelKey: 'common.settings',
    icon: FluentIcons.settings_24_regular,
  );

  static const _libraryItems = [_musicLibraryItem, _artistsItem, _albumsItem];
  static const _playbackItems = [
    _localItem,
    _recentItem,
    _nowPlayingItem,
    _myFavoritesItem,
  ];

  final _searchFocusNode = FocusNode();
  var _focusSearchAfterPaneOpen = false;
  var _isSearchFocused = false;
  var _isPlaylistNavExpanded = false;

  @override
  void didUpdateWidget(covariant MainNavigationView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_focusSearchAfterPaneOpen && widget.isPaneOpen) {
      _focusSearchAfterPaneOpen = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _searchFocusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final collapsed = !widget.isPaneOpen;
    final visibleRecentSearches =
        widget.recentSearches
            .where((entry) => entry.type == SearchHistoryType.sidebar)
            .take(10)
            .toList();
    final customPlaylists =
        widget.playlists.where((playlist) => !playlist.isBuiltIn).toList();
    final showRecentSearches =
        !collapsed && _isSearchFocused && visibleRecentSearches.isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: ClipRect(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            crossAxisAlignment:
                collapsed
                    ? CrossAxisAlignment.center
                    : CrossAxisAlignment.start,
            children: [
              _MainNavigationViewTitle(
                collapsed: collapsed,
                appName: widget.i18n.t('app.shell'),
                canGoBack: widget.canGoBack,
                backLabel: widget.i18n.t('sidebar.back'),
                onGoBack: widget.onGoBack,
              ),
              const SizedBox(height: 8),
              _NavigationIconButton(
                key: const ValueKey('MainNavigationView.TogglePaneButton'),
                icon: FluentIcons.line_horizontal_3_24_regular,
                tooltip:
                    collapsed
                        ? widget.i18n.t('sidebar.expandNavigation')
                        : widget.i18n.t('sidebar.collapseNavigation'),
                onPressed: widget.onPaneToggle,
              ),
              const SizedBox(height: 8),
              _MainNavigationViewSearchBox(
                collapsed: collapsed,
                value: widget.searchText,
                i18n: widget.i18n,
                focusNode: _searchFocusNode,
                onChanged: widget.onSearchTextChanged,
                onSubmitted: widget.onSearchCommitted,
                onFocusChanged: (focused) {
                  setState(() {
                    _isSearchFocused = focused;
                  });
                },
                onCollapsedSearchPressed: () {
                  _focusSearchAfterPaneOpen = true;
                  widget.onPaneToggle();
                },
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    if (showRecentSearches)
                      _MainNavigationRecentSearches(
                        entries: visibleRecentSearches,
                        i18n: widget.i18n,
                        onSearchSelected: (entry) {
                          widget.onSearchTextChanged(entry.query);
                          widget.onSearchCommitted(entry.query);
                          setState(() {
                            _isSearchFocused = false;
                          });
                          _searchFocusNode.unfocus();
                        },
                        onSearchRemoved: widget.onRecentSearchRemove,
                        onClear: widget.onRecentSearchesClear,
                      ),
                    _MainNavigationSectionLabel(
                      collapsed: collapsed,
                      label: widget.i18n.t('sidebar.library'),
                    ),
                    _MainNavigationViewSection(
                      collapsed: collapsed,
                      items: _libraryItems,
                      i18n: widget.i18n,
                      currentPath: widget.currentPath,
                      onItemInvoked: widget.onItemInvoked,
                    ),
                    const _MainNavigationViewSeparator(),
                    _MainNavigationSectionLabel(
                      collapsed: collapsed,
                      label: widget.i18n.t('sidebar.playback'),
                    ),
                    _MainNavigationViewSection(
                      collapsed: collapsed,
                      items: _playbackItems,
                      i18n: widget.i18n,
                      currentPath: widget.currentPath,
                      onItemInvoked: widget.onItemInvoked,
                    ),
                    const _MainNavigationViewSeparator(),
                    _MainNavigationPlaylistSection(
                      collapsed: collapsed,
                      currentPath: widget.currentPath,
                      i18n: widget.i18n,
                      playlists: customPlaylists,
                      expanded: _isPlaylistNavExpanded,
                      onItemInvoked: widget.onItemInvoked,
                      onToggleExpanded: () {
                        setState(() {
                          _isPlaylistNavExpanded = !_isPlaylistNavExpanded;
                        });
                      },
                      onCreatePlaylist: widget.onCreatePlaylist,
                      onPlaylistRandomPlay: widget.onPlaylistRandomPlay,
                    ),
                    const _MainNavigationViewSeparator(),
                    _MainNavigationViewSection(
                      collapsed: collapsed,
                      items: const [_settingsItem],
                      i18n: widget.i18n,
                      currentPath: widget.currentPath,
                      onItemInvoked: widget.onItemInvoked,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

@immutable
class MainNavigationViewItem {
  const MainNavigationViewItem({
    required this.name,
    required this.target,
    required this.icon,
    this.label = '',
    this.labelKey,
    this.exactActive = false,
  });

  final String name;
  final String target;
  final String label;
  final String? labelKey;
  final IconData icon;
  final bool exactActive;

  String labelFor(SmPlayerI18n i18n) {
    final key = labelKey;
    if (key != null) {
      return i18n.t(key);
    }

    return label;
  }

  bool isActive(String currentPath) {
    if (exactActive) {
      return currentPath == target;
    }

    return currentPath == target || currentPath.startsWith('$target/');
  }
}

class _MainNavigationViewTitle extends StatelessWidget {
  const _MainNavigationViewTitle({
    required this.collapsed,
    required this.appName,
    required this.canGoBack,
    required this.backLabel,
    required this.onGoBack,
  });

  final bool collapsed;
  final String appName;
  final bool canGoBack;
  final String backLabel;
  final VoidCallback? onGoBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      width: double.infinity,
      child:
          collapsed
              ? Center(
                child:
                    canGoBack
                        ? _NavigationIconButton(
                          key: const ValueKey('MainNavigationView.BackButton'),
                          icon: FluentIcons.arrow_left_24_regular,
                          tooltip: backLabel,
                          onPressed: onGoBack ?? () {},
                        )
                        : const SizedBox.shrink(),
              )
              : Row(
                children: [
                  if (canGoBack) ...[
                    _NavigationIconButton(
                      key: const ValueKey('MainNavigationView.BackButton'),
                      icon: FluentIcons.arrow_left_24_regular,
                      tooltip: backLabel,
                      onPressed: onGoBack ?? () {},
                    ),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(
                      appName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: MainNavigationViewColors.textStrong,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
    );
  }
}

class _MainNavigationViewSearchBox extends StatefulWidget {
  const _MainNavigationViewSearchBox({
    required this.collapsed,
    required this.value,
    required this.i18n,
    required this.focusNode,
    required this.onChanged,
    required this.onSubmitted,
    required this.onFocusChanged,
    required this.onCollapsedSearchPressed,
  });

  final bool collapsed;
  final String value;
  final SmPlayerI18n i18n;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final ValueChanged<bool> onFocusChanged;
  final VoidCallback onCollapsedSearchPressed;

  @override
  State<_MainNavigationViewSearchBox> createState() =>
      _MainNavigationViewSearchBoxState();
}

class _MainNavigationViewSearchBoxState
    extends State<_MainNavigationViewSearchBox> {
  late final TextEditingController _controller;

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
    widget.onFocusChanged(widget.focusNode.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (widget.collapsed || constraints.maxWidth <= 64) {
          return _NavigationIconButton(
            key: const ValueKey('MainNavigationView.SearchButton'),
            icon: FluentIcons.search_24_regular,
            tooltip: widget.i18n.t('common.search'),
            onPressed: widget.onCollapsedSearchPressed,
          );
        }

        return SizedBox(
          height: 40,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: MainNavigationViewColors.searchSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: MainNavigationViewColors.searchBorder),
              boxShadow: const [
                BoxShadow(
                  color: MainNavigationViewColors.searchInsetHighlight,
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
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 40,
                      height: 40,
                    ),
                    style: IconButton.styleFrom(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(FluentIcons.search_24_regular, size: 19),
                    color: MainNavigationViewColors.textMuted,
                    tooltip: widget.i18n.t('common.search'),
                    onPressed: () {
                      widget.onSubmitted(widget.value);
                    },
                  ),
                ),
                Expanded(
                  child: TextField(
                    key: const ValueKey('MainNavigationView.SearchTextField'),
                    controller: _controller,
                    focusNode: widget.focusNode,
                    onChanged: widget.onChanged,
                    onSubmitted: widget.onSubmitted,
                    textInputAction: TextInputAction.search,
                    style: const TextStyle(
                      fontSize: 14,
                      color: MainNavigationViewColors.textStrong,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: widget.i18n.t('common.search'),
                      hintStyle: const TextStyle(
                        color: MainNavigationViewColors.searchPlaceholder,
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
                    child: IconButton(
                      key: const ValueKey(
                        'MainNavigationView.ClearSearchButton',
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: 24,
                        height: 24,
                      ),
                      style: IconButton.styleFrom(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        backgroundColor: MainNavigationViewColors.clearButton,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      icon: const Icon(
                        FluentIcons.dismiss_24_regular,
                        size: 14,
                      ),
                      color: MainNavigationViewColors.accentStrong,
                      tooltip: widget.i18n.t('common.clear'),
                      onPressed: () {
                        widget.onChanged('');
                      },
                    ),
                  ),
                const SizedBox(width: 10),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MainNavigationViewSection extends StatelessWidget {
  const _MainNavigationViewSection({
    required this.collapsed,
    required this.items,
    required this.i18n,
    required this.currentPath,
    required this.onItemInvoked,
  });

  final bool collapsed;
  final List<MainNavigationViewItem> items;
  final SmPlayerI18n i18n;
  final String currentPath;
  final ValueChanged<String> onItemInvoked;

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 8,
      children:
          items.map((item) {
            return _MainNavigationViewItemButton(
              key: ValueKey(item.name),
              item: item,
              label: item.labelFor(i18n),
              collapsed: collapsed,
              active: item.isActive(currentPath),
              onPressed: () {
                onItemInvoked(item.target);
              },
            );
          }).toList(),
    );
  }
}

class _MainNavigationSectionLabel extends StatelessWidget {
  const _MainNavigationSectionLabel({
    required this.collapsed,
    required this.label,
  });

  final bool collapsed;
  final String label;

  @override
  Widget build(BuildContext context) {
    if (collapsed) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: MainNavigationViewColors.sectionLabel,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MainNavigationPlaylistSection extends StatelessWidget {
  const _MainNavigationPlaylistSection({
    required this.collapsed,
    required this.currentPath,
    required this.i18n,
    required this.playlists,
    required this.expanded,
    required this.onItemInvoked,
    required this.onToggleExpanded,
    required this.onCreatePlaylist,
    required this.onPlaylistRandomPlay,
  });

  final bool collapsed;
  final String currentPath;
  final SmPlayerI18n i18n;
  final List<LibraryPlaylist> playlists;
  final bool expanded;
  final ValueChanged<String> onItemInvoked;
  final VoidCallback onToggleExpanded;
  final VoidCallback? onCreatePlaylist;
  final ValueChanged<int>? onPlaylistRandomPlay;

  @override
  Widget build(BuildContext context) {
    if (collapsed) {
      return _MainNavigationViewSection(
        collapsed: true,
        items: const [_MainNavigationViewState._playlistsItem],
        i18n: i18n,
        currentPath: currentPath,
        onItemInvoked: onItemInvoked,
      );
    }

    return Column(
      spacing: 8,
      children: [
        _MainNavigationPlaylistHeading(
          active: _MainNavigationViewState._playlistsItem.isActive(currentPath),
          expanded: expanded,
          i18n: i18n,
          onOpen: () {
            onItemInvoked(_MainNavigationViewState._playlistsItem.target);
          },
          onCreatePlaylist: onCreatePlaylist,
          onToggleExpanded: onToggleExpanded,
        ),
        if (expanded)
          ...playlists.map(
            (playlist) => _MainNavigationPlaylistItemButton(
              key: ValueKey('PlaylistItem.${playlist.id}'),
              playlist: playlist,
              randomPlayLabel: i18n.t('nowPlaying.randomPlay'),
              active: currentPath == '/playlists/${playlist.id}',
              onPressed: () {
                onItemInvoked('/playlists/${playlist.id}');
              },
              onRandomPlay:
                  onPlaylistRandomPlay == null
                      ? null
                      : () {
                        onPlaylistRandomPlay!(playlist.id);
                      },
            ),
          ),
      ],
    );
  }
}

class _MainNavigationPlaylistHeading extends StatelessWidget {
  const _MainNavigationPlaylistHeading({
    required this.active,
    required this.expanded,
    required this.i18n,
    required this.onOpen,
    required this.onCreatePlaylist,
    required this.onToggleExpanded,
  });

  final bool active;
  final bool expanded;
  final SmPlayerI18n i18n;
  final VoidCallback onOpen;
  final VoidCallback? onCreatePlaylist;
  final VoidCallback onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MainNavigationViewItemButton(
            item: _MainNavigationViewState._playlistsItem,
            label: _MainNavigationViewState._playlistsItem.labelFor(i18n),
            collapsed: false,
            active: active,
            onPressed: onOpen,
          ),
        ),
        _NavigationIconButton(
          key: const ValueKey('MainNavigationView.CreatePlaylistButton'),
          icon: FluentIcons.add_24_regular,
          tooltip: i18n.t('playlists.createNew'),
          onPressed: onCreatePlaylist ?? () {},
        ),
        _NavigationIconButton(
          key: const ValueKey('MainNavigationView.TogglePlaylistSectionButton'),
          icon:
              expanded
                  ? FluentIcons.chevron_up_24_regular
                  : FluentIcons.chevron_down_24_regular,
          tooltip:
              expanded
                  ? i18n.t('sidebar.collapseNavigation')
                  : i18n.t('sidebar.expandNavigation'),
          onPressed: onToggleExpanded,
        ),
      ],
    );
  }
}

class _MainNavigationPlaylistItemButton extends StatefulWidget {
  const _MainNavigationPlaylistItemButton({
    super.key,
    required this.playlist,
    required this.randomPlayLabel,
    required this.active,
    required this.onPressed,
    required this.onRandomPlay,
  });

  final LibraryPlaylist playlist;
  final String randomPlayLabel;
  final bool active;
  final VoidCallback onPressed;
  final VoidCallback? onRandomPlay;

  @override
  State<_MainNavigationPlaylistItemButton> createState() =>
      _MainNavigationPlaylistItemButtonState();
}

class _MainNavigationPlaylistItemButtonState
    extends State<_MainNavigationPlaylistItemButton> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final highlighted = widget.active || _hovered;
    final foreground =
        highlighted
            ? MainNavigationViewColors.accentStrong
            : MainNavigationViewColors.textMuted;

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
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 36,
          margin: const EdgeInsets.only(left: 8),
          padding: const EdgeInsets.only(left: 12, right: 4),
          decoration: BoxDecoration(
            color:
                highlighted
                    ? MainNavigationViewColors.accentHover
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(
                FluentIcons.apps_list_detail_20_regular,
                size: 18,
                color: foreground,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.playlist.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (widget.onRandomPlay != null)
                IconButton(
                  tooltip: widget.randomPlayLabel,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 28,
                    height: 28,
                  ),
                  icon: const Icon(
                    FluentIcons.arrow_shuffle_20_regular,
                    size: 16,
                  ),
                  color: foreground,
                  onPressed:
                      widget.playlist.songIds.isEmpty
                          ? null
                          : widget.onRandomPlay,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

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
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: MainNavigationViewColors.dropdownSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: MainNavigationViewColors.searchBorder),
          boxShadow: const [
            BoxShadow(
              color: MainNavigationViewColors.dropdownShadow,
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 6, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        i18n.t('sidebar.recentSearches'),
                        style: const TextStyle(
                          color: MainNavigationViewColors.textStrong,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: onClear,
                      child: Text(i18n.t('common.clear')),
                    ),
                  ],
                ),
              ),
              ...entries.map(
                (entry) => _MainNavigationRecentSearchItem(
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
              ),
            ],
          ),
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
    return SizedBox(
      height: 36,
      child: Row(
        children: [
          Expanded(
            child: TextButton.icon(
              style: TextButton.styleFrom(
                alignment: Alignment.centerLeft,
                foregroundColor: MainNavigationViewColors.textMuted,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(FluentIcons.search_20_regular, size: 16),
              label: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  entry.query,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              onPressed: onPressed,
            ),
          ),
          IconButton(
            tooltip: removeLabel,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            icon: const Icon(FluentIcons.dismiss_16_regular, size: 14),
            color: MainNavigationViewColors.textMuted,
            onPressed: onRemove,
          ),
          const SizedBox(width: 6),
        ],
      ),
    );
  }
}

class _MainNavigationViewItemButton extends StatefulWidget {
  const _MainNavigationViewItemButton({
    super.key,
    required this.item,
    required this.label,
    required this.collapsed,
    required this.active,
    required this.onPressed,
  });

  final MainNavigationViewItem item;
  final String label;
  final bool collapsed;
  final bool active;
  final VoidCallback onPressed;

  @override
  State<_MainNavigationViewItemButton> createState() =>
      _MainNavigationViewItemButtonState();
}

class _MainNavigationViewItemButtonState
    extends State<_MainNavigationViewItemButton> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final highlighted = widget.active || _hovered;
    final foreground =
        highlighted
            ? MainNavigationViewColors.accentStrong
            : MainNavigationViewColors.textMuted;
    final background =
        highlighted ? MainNavigationViewColors.accentHover : Colors.transparent;

    return Tooltip(
      message: widget.collapsed ? widget.label : '',
      waitDuration: const Duration(milliseconds: 500),
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
          selected: widget.active,
          label: widget.label,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onPressed,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
              width: widget.collapsed ? 40 : double.infinity,
              height: 40,
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(16),
                border:
                    widget.active && !widget.collapsed
                        ? Border.all(
                          color: MainNavigationViewColors.accentBorder,
                        )
                        : null,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (widget.collapsed || constraints.maxWidth <= 48) {
                    return Center(
                      child: Icon(
                        widget.item.icon,
                        size: 21,
                        color: foreground,
                      ),
                    );
                  }

                  return Row(
                    children: [
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: Icon(
                          widget.item.icon,
                          size: 21,
                          color: foreground,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          widget.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: foreground,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            height: 1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavigationIconButton extends StatefulWidget {
  const _NavigationIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  State<_NavigationIconButton> createState() => _NavigationIconButtonState();
}

class _NavigationIconButtonState extends State<_NavigationIconButton> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
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
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color:
                  _hovered
                      ? MainNavigationViewColors.accentHover
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              widget.icon,
              size: 20,
              color:
                  _hovered
                      ? MainNavigationViewColors.accentStrong
                      : MainNavigationViewColors.textStrong,
            ),
          ),
        ),
      ),
    );
  }
}

class _MainNavigationViewSeparator extends StatelessWidget {
  const _MainNavigationViewSeparator();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Divider(
        height: 1,
        thickness: 1,
        color: MainNavigationViewColors.sectionDivider,
      ),
    );
  }
}

class MainNavigationViewColors {
  const MainNavigationViewColors._();

  static const textStrong = Color(0xff1f252b);
  static const textMuted = Color(0xff5f625f);
  static const accentStrong = Color(0xff0063b1);
  static const accentHover = Color(0x1a0078d7);
  static const accentBorder = Color(0x140078d7);
  static const searchSurface = Color(0x090d1826);
  static const searchBorder = Color(0x24536379);
  static const searchInsetHighlight = Color(0x61ffffff);
  static const searchPlaceholder = Color(0x9e3d4958);
  static const clearButton = Color(0x140078d7);
  static const sectionDivider = Color(0x3d6c7580);
  static const sectionLabel = Color(0x8a5f625f);
  static const dropdownSurface = Color(0xf7ffffff);
  static const dropdownShadow = Color(0x1a273446);
}
