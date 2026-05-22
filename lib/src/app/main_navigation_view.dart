import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/ui/command_bar.dart';

typedef MainNavigationSearchCommit =
    void Function(String value, [SearchHistoryType type]);
typedef _NavigationTooltipRequest = void Function(String label, Rect target);

enum _PlaylistDropPosition { before, after }

class _NavigationFloatingTooltipState {
  const _NavigationFloatingTooltipState({
    required this.label,
    required this.left,
    required this.top,
  });

  final String label;
  final double left;
  final double top;
}

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
    required this.onSearchCleared,
    required this.onItemInvoked,
    this.canGoBack = false,
    this.playlists = const [],
    this.recentSearches = const [],
    this.onGoBack,
    this.onCreatePlaylist,
    this.onDuplicatePlaylist,
    this.onRenamePlaylist,
    this.onDeletePlaylist,
    this.onReorderPlaylists,
    this.onPlaylistRandomPlay,
    this.onRecentSearchRemove,
    this.onRecentSearchesClear,
    this.onWindowDragStart,
    this.onWindowDragEnd,
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
  final MainNavigationSearchCommit onSearchCommitted;
  final VoidCallback onSearchCleared;
  final ValueChanged<String> onItemInvoked;
  final VoidCallback? onGoBack;
  final VoidCallback? onCreatePlaylist;
  final ValueChanged<LibraryPlaylist>? onDuplicatePlaylist;
  final ValueChanged<LibraryPlaylist>? onRenamePlaylist;
  final ValueChanged<LibraryPlaylist>? onDeletePlaylist;
  final ValueChanged<List<int>>? onReorderPlaylists;
  final ValueChanged<int>? onPlaylistRandomPlay;
  final ValueChanged<int>? onRecentSearchRemove;
  final VoidCallback? onRecentSearchesClear;
  final VoidCallback? onWindowDragStart;
  final VoidCallback? onWindowDragEnd;

  @override
  State<MainNavigationView> createState() => _MainNavigationViewState();
}

class _MainNavigationViewState extends State<MainNavigationView> {
  final _rootKey = GlobalKey();
  _NavigationFloatingTooltipState? _floatingTooltip;

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
  int? _draggingPlaylistId;
  ({int playlistId, _PlaylistDropPosition position})? _playlistDropIndicator;

  @override
  void initState() {
    super.initState();
    _syncPlaylistExpansionWithRoute();
  }

  @override
  void didUpdateWidget(covariant MainNavigationView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPlaylistExpansionWithRoute();
    if (oldWidget.isPaneOpen != widget.isPaneOpen && widget.isPaneOpen) {
      _floatingTooltip = null;
    }
    if (_focusSearchAfterPaneOpen && widget.isPaneOpen) {
      _focusSearchAfterPaneOpen = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _searchFocusNode.requestFocus();
      });
    }
  }

  void _syncPlaylistExpansionWithRoute() {
    if (widget.isPaneOpen && widget.currentPath.startsWith('/playlists')) {
      _isPlaylistNavExpanded = true;
    }
  }

  void _clearPlaylistDragState() {
    setState(() {
      _draggingPlaylistId = null;
      _playlistDropIndicator = null;
    });
  }

  void _closeSearchHistory() {
    if (!_isSearchFocused) {
      return;
    }
    setState(() {
      _isSearchFocused = false;
    });
    _searchFocusNode.unfocus();
  }

  void _invokeNavigationItem(String target) {
    _closeSearchHistory();
    _hideFloatingTooltip();
    widget.onItemInvoked(target);
  }

  void _showFloatingTooltip(String label, Rect target) {
    final rootBox = _rootKey.currentContext?.findRenderObject() as RenderBox?;
    if (rootBox == null || label.isEmpty || !mounted) {
      return;
    }
    final localRight = rootBox.globalToLocal(Offset(target.right + 10, 0)).dx;
    final localCenterY = rootBox.globalToLocal(Offset(0, target.center.dy)).dy;
    setState(() {
      _floatingTooltip = _NavigationFloatingTooltipState(
        label: label,
        left: localRight,
        top: localCenterY,
      );
    });
  }

  void _hideFloatingTooltip() {
    if (_floatingTooltip == null) {
      return;
    }
    setState(() {
      _floatingTooltip = null;
    });
  }

  void _reorderDraggedPlaylist(int targetPlaylistId, bool insertAfter) {
    final draggedPlaylistId = _draggingPlaylistId;
    if (draggedPlaylistId == null || draggedPlaylistId == targetPlaylistId) {
      _clearPlaylistDragState();
      return;
    }

    final customPlaylistIds =
        widget.playlists
            .where((playlist) => !playlist.isBuiltIn)
            .map((playlist) => playlist.id)
            .where((playlistId) => playlistId != draggedPlaylistId)
            .toList();
    final targetIndex = customPlaylistIds.indexOf(targetPlaylistId);
    customPlaylistIds.insert(
      targetIndex + (insertAfter ? 1 : 0),
      draggedPlaylistId,
    );
    _clearPlaylistDragState();
    widget.onReorderPlaylists?.call(customPlaylistIds);
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
    final playlistSection = _MainNavigationPlaylistSection(
      collapsed: collapsed,
      currentPath: widget.currentPath,
      i18n: widget.i18n,
      playlists: customPlaylists,
      expanded: _isPlaylistNavExpanded,
      onItemInvoked: _invokeNavigationItem,
      onToggleExpanded: () {
        setState(() {
          _isPlaylistNavExpanded = !_isPlaylistNavExpanded;
        });
      },
      onCreatePlaylist: widget.onCreatePlaylist,
      onDuplicatePlaylist: widget.onDuplicatePlaylist,
      onRenamePlaylist: widget.onRenamePlaylist,
      onDeletePlaylist: widget.onDeletePlaylist,
      onPlaylistRandomPlay: widget.onPlaylistRandomPlay,
      onTooltipRequested: collapsed ? _showFloatingTooltip : null,
      onTooltipDismissed: _hideFloatingTooltip,
      draggingPlaylistId: _draggingPlaylistId,
      dropIndicator: _playlistDropIndicator,
      onPlaylistDragStarted: (playlistId) {
        setState(() {
          _draggingPlaylistId = playlistId;
        });
      },
      onPlaylistDragHover: (playlistId, position) {
        setState(() {
          _playlistDropIndicator = (playlistId: playlistId, position: position);
        });
      },
      onPlaylistDragLeave: (playlistId) {
        if (_playlistDropIndicator?.playlistId != playlistId) {
          return;
        }
        setState(() {
          _playlistDropIndicator = null;
        });
      },
      onPlaylistDragDropped: (playlistId, insertAfter) {
        _reorderDraggedPlaylist(playlistId, insertAfter);
      },
      onPlaylistDragEnded: _clearPlaylistDragState,
    );

    return Material(
      key: _rootKey,
      color: Colors.transparent,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRect(
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
                    onWindowDragStart: widget.onWindowDragStart,
                    onWindowDragEnd: widget.onWindowDragEnd,
                    onTooltipRequested: collapsed ? _showFloatingTooltip : null,
                    onTooltipDismissed: _hideFloatingTooltip,
                  ),
                  const SizedBox(height: 8),
                  _NavigationIconButton(
                    key: const ValueKey('MainNavigationView.TogglePaneButton'),
                    icon: FluentIcons.line_horizontal_3_24_regular,
                    tooltip:
                        collapsed
                            ? widget.i18n.t('sidebar.expandNavigation')
                            : widget.i18n.t('sidebar.collapseNavigation'),
                    collapsedContext: collapsed,
                    onPressed: () {
                      _hideFloatingTooltip();
                      widget.onPaneToggle();
                    },
                    onTooltipRequested: collapsed ? _showFloatingTooltip : null,
                    onTooltipDismissed: _hideFloatingTooltip,
                  ),
                  const SizedBox(height: 8),
                  _MainNavigationViewSearchBox(
                    collapsed: collapsed,
                    value: widget.searchText,
                    i18n: widget.i18n,
                    focusNode: _searchFocusNode,
                    onChanged: widget.onSearchTextChanged,
                    onSubmitted: widget.onSearchCommitted,
                    onCleared: widget.onSearchCleared,
                    onFocusChanged: (focused) {
                      setState(() {
                        _isSearchFocused = focused;
                      });
                    },
                    onCollapsedSearchPressed: () {
                      _hideFloatingTooltip();
                      _focusSearchAfterPaneOpen = true;
                      widget.onPaneToggle();
                    },
                    onTooltipRequested: collapsed ? _showFloatingTooltip : null,
                    onTooltipDismissed: _hideFloatingTooltip,
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final libraryAndPlayback = <Widget>[
                              _MainNavigationSectionLabel(
                                collapsed: collapsed,
                                label: widget.i18n.t('sidebar.library'),
                              ),
                              _MainNavigationViewSection(
                                collapsed: collapsed,
                                items: _libraryItems,
                                i18n: widget.i18n,
                                currentPath: widget.currentPath,
                                onItemInvoked: _invokeNavigationItem,
                                onTooltipRequested:
                                    collapsed ? _showFloatingTooltip : null,
                                onTooltipDismissed: _hideFloatingTooltip,
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
                                onItemInvoked: _invokeNavigationItem,
                                onTooltipRequested:
                                    collapsed ? _showFloatingTooltip : null,
                                onTooltipDismissed: _hideFloatingTooltip,
                              ),
                              const _MainNavigationViewSeparator(),
                            ];
                            if (constraints.maxHeight < 440) {
                              return ListView(
                                padding: EdgeInsets.zero,
                                children: [
                                  ...libraryAndPlayback,
                                  playlistSection,
                                ],
                              );
                            }
                            return Column(
                              children: [
                                ...libraryAndPlayback,
                                Expanded(child: playlistSection),
                              ],
                            );
                          },
                        ),
                        if (showRecentSearches)
                          Positioned.fill(
                            child: GestureDetector(
                              key: const ValueKey(
                                'MainNavigationView.SearchDismissLayer',
                              ),
                              behavior: HitTestBehavior.translucent,
                              onTap: _closeSearchHistory,
                              child: const SizedBox.expand(),
                            ),
                          ),
                        if (showRecentSearches)
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: _MainNavigationRecentSearches(
                              entries: visibleRecentSearches,
                              i18n: widget.i18n,
                              onSearchSelected: (entry) {
                                widget.onSearchTextChanged(entry.query);
                                widget.onSearchCommitted(
                                  entry.query,
                                  entry.type,
                                );
                                setState(() {
                                  _isSearchFocused = false;
                                });
                                _searchFocusNode.unfocus();
                              },
                              onSearchRemoved: widget.onRecentSearchRemove,
                              onClear: widget.onRecentSearchesClear,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  _MainNavigationViewSection(
                    collapsed: collapsed,
                    items: const [_settingsItem],
                    i18n: widget.i18n,
                    currentPath: widget.currentPath,
                    onItemInvoked: _invokeNavigationItem,
                    onTooltipRequested: collapsed ? _showFloatingTooltip : null,
                    onTooltipDismissed: _hideFloatingTooltip,
                  ),
                ],
              ),
            ),
          ),
          if (_floatingTooltip != null)
            _MainNavigationFloatingTooltip(tooltip: _floatingTooltip!),
        ],
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
    required this.onWindowDragStart,
    required this.onWindowDragEnd,
    required this.onTooltipRequested,
    required this.onTooltipDismissed,
  });

  final bool collapsed;
  final String appName;
  final bool canGoBack;
  final String backLabel;
  final VoidCallback? onGoBack;
  final VoidCallback? onWindowDragStart;
  final VoidCallback? onWindowDragEnd;
  final _NavigationTooltipRequest? onTooltipRequested;
  final VoidCallback onTooltipDismissed;

  @override
  Widget build(BuildContext context) {
    final colors = MainNavigationViewColors.of(context);
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
                          collapsedContext: true,
                          onTooltipRequested: onTooltipRequested,
                          onTooltipDismissed: onTooltipDismissed,
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
                      onTooltipDismissed: onTooltipDismissed,
                    ),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: _WindowDragRegion(
                      onWindowDragStart: onWindowDragStart,
                      onWindowDragEnd: onWindowDragEnd,
                      child: Text(
                        appName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textStrong,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
    );
  }
}

class _WindowDragRegion extends StatelessWidget {
  const _WindowDragRegion({
    required this.child,
    required this.onWindowDragStart,
    required this.onWindowDragEnd,
  });

  final Widget child;
  final VoidCallback? onWindowDragStart;
  final VoidCallback? onWindowDragEnd;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (event) {
        if (event.buttons == 1) {
          onWindowDragStart?.call();
        }
      },
      onPointerUp: (_) => onWindowDragEnd?.call(),
      onPointerCancel: (_) => onWindowDragEnd?.call(),
      child: Align(alignment: Alignment.centerLeft, child: child),
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
    required this.onCleared,
    required this.onFocusChanged,
    required this.onCollapsedSearchPressed,
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
  final VoidCallback onCollapsedSearchPressed;
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
          height: 40,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color:
                  _focused ? colors.focusedSearchSurface : colors.searchSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color:
                    _focused ? colors.focusedSearchBorder : colors.searchBorder,
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
                  child: _SearchCommitButton(
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
                    style: TextStyle(fontSize: 14, color: colors.textStrong),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: widget.i18n.t('common.search'),
                      hintStyle: TextStyle(color: colors.searchPlaceholder),
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
                        backgroundColor: colors.clearButton,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      icon: const Icon(
                        FluentIcons.dismiss_24_regular,
                        size: 14,
                      ),
                      color: colors.clearForeground,
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
    this.onTooltipRequested,
    this.onTooltipDismissed,
  });

  final bool collapsed;
  final List<MainNavigationViewItem> items;
  final SmPlayerI18n i18n;
  final String currentPath;
  final ValueChanged<String> onItemInvoked;
  final _NavigationTooltipRequest? onTooltipRequested;
  final VoidCallback? onTooltipDismissed;

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
              onTooltipRequested: onTooltipRequested,
              onTooltipDismissed: onTooltipDismissed,
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
    return const SizedBox.shrink();
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
    required this.onDuplicatePlaylist,
    required this.onRenamePlaylist,
    required this.onDeletePlaylist,
    required this.onPlaylistRandomPlay,
    required this.draggingPlaylistId,
    required this.dropIndicator,
    required this.onPlaylistDragStarted,
    required this.onPlaylistDragHover,
    required this.onPlaylistDragLeave,
    required this.onPlaylistDragDropped,
    required this.onPlaylistDragEnded,
    this.onTooltipRequested,
    this.onTooltipDismissed,
  });

  final bool collapsed;
  final String currentPath;
  final SmPlayerI18n i18n;
  final List<LibraryPlaylist> playlists;
  final bool expanded;
  final ValueChanged<String> onItemInvoked;
  final VoidCallback onToggleExpanded;
  final VoidCallback? onCreatePlaylist;
  final ValueChanged<LibraryPlaylist>? onDuplicatePlaylist;
  final ValueChanged<LibraryPlaylist>? onRenamePlaylist;
  final ValueChanged<LibraryPlaylist>? onDeletePlaylist;
  final ValueChanged<int>? onPlaylistRandomPlay;
  final int? draggingPlaylistId;
  final ({int playlistId, _PlaylistDropPosition position})? dropIndicator;
  final ValueChanged<int> onPlaylistDragStarted;
  final void Function(int playlistId, _PlaylistDropPosition position)
  onPlaylistDragHover;
  final ValueChanged<int> onPlaylistDragLeave;
  final void Function(int playlistId, bool insertAfter) onPlaylistDragDropped;
  final VoidCallback onPlaylistDragEnded;
  final _NavigationTooltipRequest? onTooltipRequested;
  final VoidCallback? onTooltipDismissed;

  @override
  Widget build(BuildContext context) {
    if (collapsed) {
      return _MainNavigationViewSection(
        collapsed: true,
        items: const [_MainNavigationViewState._playlistsItem],
        i18n: i18n,
        currentPath: currentPath,
        onItemInvoked: onItemInvoked,
        onTooltipRequested: onTooltipRequested,
        onTooltipDismissed: onTooltipDismissed,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final playlistItems =
            playlists
                .map(
                  (playlist) => _MainNavigationPlaylistItemButton(
                    key: ValueKey('PlaylistItem.${playlist.id}'),
                    playlist: playlist,
                    i18n: i18n,
                    randomPlayLabel: i18n.t('nowPlaying.randomPlay'),
                    active: currentPath == '/playlists/${playlist.id}',
                    dragging: draggingPlaylistId == playlist.id,
                    dropPosition:
                        dropIndicator?.playlistId == playlist.id
                            ? dropIndicator!.position
                            : null,
                    onPressed: () {
                      onItemInvoked('/playlists/${playlist.id}');
                    },
                    onDuplicate: onDuplicatePlaylist,
                    onRename: onRenamePlaylist,
                    onDelete: onDeletePlaylist,
                    onRandomPlay:
                        onPlaylistRandomPlay == null
                            ? null
                            : () {
                              onPlaylistRandomPlay!(playlist.id);
                            },
                    onDragStarted: () => onPlaylistDragStarted(playlist.id),
                    onDragHover: (position) {
                      onPlaylistDragHover(playlist.id, position);
                    },
                    onDragLeave: () => onPlaylistDragLeave(playlist.id),
                    onDropped: (insertAfter) {
                      onPlaylistDragDropped(playlist.id, insertAfter);
                    },
                    onDragEnded: onPlaylistDragEnded,
                  ),
                )
                .toList();
        return Column(
          spacing: 8,
          children: [
            _MainNavigationPlaylistHeading(
              active: _MainNavigationViewState._playlistsItem.isActive(
                currentPath,
              ),
              expanded: expanded,
              i18n: i18n,
              onOpen: () {
                onItemInvoked(_MainNavigationViewState._playlistsItem.target);
              },
              onCreatePlaylist: onCreatePlaylist,
              onToggleExpanded: onToggleExpanded,
            ),
            if (expanded)
              if (constraints.hasBoundedHeight)
                Expanded(
                  child: ListView(
                    key: const ValueKey('MainNavigationView.PlaylistScroll'),
                    padding: EdgeInsets.zero,
                    children: playlistItems,
                  ),
                )
              else
                ...playlistItems,
          ],
        );
      },
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
          onPressed: () {
            onCreatePlaylist?.call();
            if (!expanded) {
              onToggleExpanded();
            }
          },
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
    required this.i18n,
    required this.randomPlayLabel,
    required this.active,
    required this.dragging,
    required this.dropPosition,
    required this.onPressed,
    required this.onDuplicate,
    required this.onRename,
    required this.onDelete,
    required this.onRandomPlay,
    required this.onDragStarted,
    required this.onDragHover,
    required this.onDragLeave,
    required this.onDropped,
    required this.onDragEnded,
  });

  final LibraryPlaylist playlist;
  final SmPlayerI18n i18n;
  final String randomPlayLabel;
  final bool active;
  final bool dragging;
  final _PlaylistDropPosition? dropPosition;
  final VoidCallback onPressed;
  final ValueChanged<LibraryPlaylist>? onDuplicate;
  final ValueChanged<LibraryPlaylist>? onRename;
  final ValueChanged<LibraryPlaylist>? onDelete;
  final VoidCallback? onRandomPlay;
  final VoidCallback onDragStarted;
  final ValueChanged<_PlaylistDropPosition> onDragHover;
  final VoidCallback onDragLeave;
  final ValueChanged<bool> onDropped;
  final VoidCallback onDragEnded;

  @override
  State<_MainNavigationPlaylistItemButton> createState() =>
      _MainNavigationPlaylistItemButtonState();
}

class _MainNavigationPlaylistItemButtonState
    extends State<_MainNavigationPlaylistItemButton> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = MainNavigationViewColors.of(context);
    final highlighted = widget.active || _hovered;
    final foreground = highlighted ? colors.highlightText : colors.textMuted;

    return DragTarget<int>(
      onMove: (details) {
        final box = context.findRenderObject() as RenderBox;
        final localOffset = box.globalToLocal(details.offset);
        widget.onDragHover(
          localOffset.dy > box.size.height / 2
              ? _PlaylistDropPosition.after
              : _PlaylistDropPosition.before,
        );
      },
      onLeave: (_) => widget.onDragLeave(),
      onAcceptWithDetails: (details) {
        final box = context.findRenderObject() as RenderBox;
        final localOffset = box.globalToLocal(details.offset);
        widget.onDropped(localOffset.dy > box.size.height / 2);
      },
      builder: (context, _, __) {
        final child = MouseRegion(
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
            onSecondaryTapDown: (details) {
              _showPlaylistMenu(context, details.globalPosition);
            },
            onLongPressStart: (details) {
              _showPlaylistMenu(context, details.globalPosition);
            },
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 120),
              opacity: widget.dragging ? 0.45 : 1,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                height: 40,
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: highlighted ? colors.accentHover : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  border: _dropIndicatorBorder(widget.dropPosition),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: Icon(
                        FluentIcons.apps_list_detail_20_regular,
                        size: 19,
                        color: foreground,
                      ),
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
                      IgnorePointer(
                        ignoring: !_hovered || widget.playlist.songIds.isEmpty,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 120),
                          opacity:
                              _hovered && widget.playlist.songIds.isNotEmpty
                                  ? 1
                                  : 0,
                          child: IconButton(
                            tooltip: widget.randomPlayLabel,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints.tightFor(
                              width: 28,
                              height: 28,
                            ),
                            icon: const Icon(
                              FluentIcons.arrow_shuffle_20_regular,
                              size: 18,
                            ),
                            color: foreground,
                            onPressed: widget.onRandomPlay,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );

        return Draggable<int>(
          data: widget.playlist.id,
          feedback: Material(
            color: Colors.transparent,
            child: ConstrainedBox(
              constraints: const BoxConstraints.tightFor(
                width: 220,
                height: 40,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.dropdownSurface,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: colors.dropdownShadow,
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      widget.playlist.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textStrong,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          onDragStarted: widget.onDragStarted,
          onDragEnd: (_) => widget.onDragEnded(),
          onDraggableCanceled: (_, _) => widget.onDragEnded(),
          childWhenDragging: child,
          child: child,
        );
      },
    );
  }

  Border? _dropIndicatorBorder(_PlaylistDropPosition? position) {
    return switch (position) {
      _PlaylistDropPosition.before => const Border(
        top: BorderSide(color: MainNavigationViewColors.accentStrong, width: 2),
      ),
      _PlaylistDropPosition.after => const Border(
        bottom: BorderSide(
          color: MainNavigationViewColors.accentStrong,
          width: 2,
        ),
      ),
      null => null,
    };
  }

  void _showPlaylistMenu(BuildContext context, Offset position) {
    showMenuFlyout(
      context,
      position: position,
      items: [
        MenuFlyoutItem(
          key: 'rename-playlist',
          text: widget.i18n.t('playlists.rename'),
          icon: FluentIcons.edit_20_regular,
          onPressed: () => widget.onRename?.call(widget.playlist),
        ),
        MenuFlyoutItem(
          key: 'duplicate-playlist',
          text: widget.i18n.t('playlists.duplicate'),
          icon: FluentIcons.copy_20_regular,
          onPressed: () => widget.onDuplicate?.call(widget.playlist),
        ),
        MenuFlyoutItem(
          key: 'delete-playlist',
          text: widget.i18n.t('playlists.delete'),
          icon: FluentIcons.delete_20_regular,
          onPressed: () => widget.onDelete?.call(widget.playlist),
        ),
      ],
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
    final colors = MainNavigationViewColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: DecoratedBox(
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        i18n.t('sidebar.recentSearches'),
                        style: TextStyle(
                          color: colors.sectionLabel,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: colors.textMuted,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        minimumSize: const Size(0, 30),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        textStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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
    final colors = MainNavigationViewColors.of(context);
    return SizedBox(
      height: 38,
      child: _HoverContainer(
        borderRadius: BorderRadius.circular(10),
        builder: (context, hovered) {
          return DecoratedBox(
            decoration: BoxDecoration(
              color: hovered ? colors.accentHover : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      foregroundColor: colors.textStrong,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      minimumSize: const Size(0, 38),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
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
                  constraints: const BoxConstraints.tightFor(
                    width: 30,
                    height: 30,
                  ),
                  icon: const Icon(FluentIcons.dismiss_16_regular, size: 14),
                  color: colors.textMuted,
                  onPressed: onRemove,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HoverContainer extends StatefulWidget {
  const _HoverContainer({required this.borderRadius, required this.builder});

  final BorderRadius borderRadius;
  final Widget Function(BuildContext context, bool hovered) builder;

  @override
  State<_HoverContainer> createState() => _HoverContainerState();
}

class _HoverContainerState extends State<_HoverContainer> {
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

class _MainNavigationViewItemButton extends StatefulWidget {
  const _MainNavigationViewItemButton({
    super.key,
    required this.item,
    required this.label,
    required this.collapsed,
    required this.active,
    required this.onPressed,
    this.onTooltipRequested,
    this.onTooltipDismissed,
  });

  final MainNavigationViewItem item;
  final String label;
  final bool collapsed;
  final bool active;
  final VoidCallback onPressed;
  final _NavigationTooltipRequest? onTooltipRequested;
  final VoidCallback? onTooltipDismissed;

  @override
  State<_MainNavigationViewItemButton> createState() =>
      _MainNavigationViewItemButtonState();
}

class _MainNavigationViewItemButtonState
    extends State<_MainNavigationViewItemButton> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = MainNavigationViewColors.of(context);
    final highlighted = widget.active || _hovered;
    final foreground = highlighted ? colors.highlightText : colors.textMuted;
    final background =
        highlighted
            ? widget.collapsed
                ? colors.collapsedHover
                : colors.accentHover
            : Colors.transparent;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        setState(() {
          _hovered = true;
        });
        _requestTooltip();
      },
      onExit: (_) {
        setState(() {
          _hovered = false;
        });
        widget.onTooltipDismissed?.call();
      },
      child: SizedBox(
        width: widget.collapsed ? 40 : double.infinity,
        height: 40,
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
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(16),
                border:
                    widget.active && !widget.collapsed
                        ? Border.all(color: colors.accentBorder)
                        : null,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (widget.collapsed || constraints.maxWidth <= 48) {
                    return Center(
                      child: _MainNavigationItemIcon(
                        item: widget.item,
                        color: foreground,
                      ),
                    );
                  }

                  return Row(
                    children: [
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: _MainNavigationItemIcon(
                          item: widget.item,
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

  void _requestTooltip() {
    final callback = widget.onTooltipRequested;
    final box = context.findRenderObject() as RenderBox?;
    if (callback == null || box == null) {
      return;
    }
    callback(widget.label, box.localToGlobal(Offset.zero) & box.size);
  }
}

class _SearchCommitButton extends StatefulWidget {
  const _SearchCommitButton({required this.tooltip, required this.onPressed});

  final String tooltip;
  final VoidCallback onPressed;

  @override
  State<_SearchCommitButton> createState() => _SearchCommitButtonState();
}

class _SearchCommitButtonState extends State<_SearchCommitButton> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = MainNavigationViewColors.of(context);
    return Semantics(
      button: true,
      label: widget.tooltip,
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
          child: Icon(
            FluentIcons.search_24_regular,
            size: 19,
            color: _hovered ? colors.accentStrong : colors.textMuted,
          ),
        ),
      ),
    );
  }
}

class _MainNavigationItemIcon extends StatelessWidget {
  const _MainNavigationItemIcon({required this.item, required this.color});

  final MainNavigationViewItem item;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (item.name == 'AlbumsItem') {
      return Center(
        child: Transform.translate(
          offset: const Offset(0, -1),
          child: SizedBox.square(
            dimension: 21,
            child: CustomPaint(
              key: const ValueKey('MainNavigationView.AlbumsConcentricIcon'),
              painter: _AlbumNavigationIconPainter(color),
            ),
          ),
        ),
      );
    }
    return Icon(item.icon, size: 21, color: color);
  }
}

class _AlbumNavigationIconPainter extends CustomPainter {
  const _AlbumNavigationIconPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 24;
    final center = Offset(size.width / 2, size.height / 2);
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8 * scale;
    canvas.drawCircle(center, 8 * scale, paint);
    canvas.drawCircle(center, 3 * scale, paint);
    canvas.drawCircle(
      center,
      1 * scale,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _AlbumNavigationIconPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _NavigationIconButton extends StatefulWidget {
  const _NavigationIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.collapsedContext = false,
    this.onTooltipRequested,
    this.onTooltipDismissed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool collapsedContext;
  final _NavigationTooltipRequest? onTooltipRequested;
  final VoidCallback? onTooltipDismissed;

  @override
  State<_NavigationIconButton> createState() => _NavigationIconButtonState();
}

class _NavigationIconButtonState extends State<_NavigationIconButton> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = MainNavigationViewColors.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        setState(() {
          _hovered = true;
        });
        _requestTooltip();
      },
      onExit: (_) {
        setState(() {
          _hovered = false;
        });
        widget.onTooltipDismissed?.call();
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
                    ? widget.collapsedContext
                        ? colors.collapsedHover
                        : colors.iconButtonHover
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            widget.icon,
            size: 20,
            color: _hovered ? colors.highlightText : colors.textStrong,
          ),
        ),
      ),
    );
  }

  void _requestTooltip() {
    final callback = widget.onTooltipRequested;
    final box = context.findRenderObject() as RenderBox?;
    if (callback == null || box == null) {
      return;
    }
    callback(widget.tooltip, box.localToGlobal(Offset.zero) & box.size);
  }
}

class _MainNavigationFloatingTooltip extends StatelessWidget {
  const _MainNavigationFloatingTooltip({required this.tooltip});

  final _NavigationFloatingTooltipState tooltip;

  @override
  Widget build(BuildContext context) {
    final colors = MainNavigationViewColors.of(context);
    return Positioned(
      left: tooltip.left,
      top: tooltip.top,
      child: FractionalTranslation(
        translation: const Offset(0, -0.5),
        child: IgnorePointer(
          child: Material(
            color: Colors.transparent,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: -4,
                  top: 13,
                  child: Transform.rotate(
                    angle: 0.7853981633974483,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: colors.dropdownSurface,
                        border: Border(
                          left: BorderSide(color: colors.searchBorder),
                          bottom: BorderSide(color: colors.searchBorder),
                        ),
                      ),
                    ),
                  ),
                ),
                Container(
                  constraints: const BoxConstraints(maxWidth: 220),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: colors.dropdownSurface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: colors.searchBorder),
                    boxShadow: [
                      BoxShadow(
                        color: colors.dropdownShadow,
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Text(
                    tooltip.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.textStrong,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.25,
                    ),
                  ),
                ),
              ],
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
    final colors = MainNavigationViewColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Divider(height: 1, thickness: 1, color: colors.sectionDivider),
    );
  }
}

class MainNavigationViewColors {
  const MainNavigationViewColors._();

  static const textStrong = Color(0xff1f252b);
  static const textMuted = Color(0xff5f625f);
  static const accentStrong = Color(0xff0063b1);
  static const accentHover = Color(0x1a0078d7);
  static const iconButtonHover = Color(0x1f0078d7);
  static const collapsedHover = Color(0x210078d7);
  static const accentBorder = Color(0x140078d7);
  static const searchSurface = Color(0x090d1826);
  static const focusedSearchSurface = Color(0xffffffff);
  static const searchBorder = Color(0x24536379);
  static const focusedSearchBorder = Color(0x7a0078d7);
  static const searchFocusRing = Color(0x1a0078d7);
  static const searchInsetHighlight = Color(0x61ffffff);
  static const searchPlaceholder = Color(0x9e3d4958);
  static const clearButton = Color(0x140078d7);
  static const sectionDivider = Color(0x3d6c7580);
  static const sectionLabel = Color(0x8a5f625f);
  static const dropdownSurface = Color(0xf7ffffff);
  static const dropdownShadow = Color(0x1a273446);

  static MainNavigationPalette of(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (!dark) {
      return const MainNavigationPalette(
        textStrong: textStrong,
        textMuted: textMuted,
        highlightText: accentStrong,
        accentStrong: accentStrong,
        accentHover: accentHover,
        iconButtonHover: iconButtonHover,
        collapsedHover: collapsedHover,
        accentBorder: accentBorder,
        searchSurface: searchSurface,
        focusedSearchSurface: focusedSearchSurface,
        searchBorder: searchBorder,
        focusedSearchBorder: focusedSearchBorder,
        searchFocusRing: searchFocusRing,
        searchInsetHighlight: searchInsetHighlight,
        searchPlaceholder: searchPlaceholder,
        clearButton: clearButton,
        clearForeground: accentStrong,
        sectionDivider: sectionDivider,
        sectionLabel: sectionLabel,
        dropdownSurface: dropdownSurface,
        dropdownShadow: dropdownShadow,
      );
    }
    return const MainNavigationPalette(
      textStrong: Color(0xebffffff),
      textMuted: Color(0xc7ffffff),
      highlightText: Color(0xffffffff),
      accentStrong: Color(0xff7fc4ff),
      accentHover: Color(0x2e0078d7),
      iconButtonHover: Color(0x2e0078d7),
      collapsedHover: Color(0x330078d7),
      accentBorder: Color(0x330078d7),
      searchSurface: Color(0x0cffffff),
      focusedSearchSurface: Color(0x240078d7),
      searchBorder: Color(0x1fd6e0ec),
      focusedSearchBorder: Color(0x570078d7),
      searchFocusRing: Color(0x290078d7),
      searchInsetHighlight: Color(0x00ffffff),
      searchPlaceholder: Color(0x94ffffff),
      clearButton: Color(0x290078d7),
      clearForeground: Color(0xffffffff),
      sectionDivider: Color(0x1fd6e0ec),
      sectionLabel: Color(0x94ffffff),
      dropdownSurface: Color(0xfa1d232b),
      dropdownShadow: Color(0x5c000000),
    );
  }
}

class MainNavigationPalette {
  const MainNavigationPalette({
    required this.textStrong,
    required this.textMuted,
    required this.highlightText,
    required this.accentStrong,
    required this.accentHover,
    required this.iconButtonHover,
    required this.collapsedHover,
    required this.accentBorder,
    required this.searchSurface,
    required this.focusedSearchSurface,
    required this.searchBorder,
    required this.focusedSearchBorder,
    required this.searchFocusRing,
    required this.searchInsetHighlight,
    required this.searchPlaceholder,
    required this.clearButton,
    required this.clearForeground,
    required this.sectionDivider,
    required this.sectionLabel,
    required this.dropdownSurface,
    required this.dropdownShadow,
  });

  final Color textStrong;
  final Color textMuted;
  final Color highlightText;
  final Color accentStrong;
  final Color accentHover;
  final Color iconButtonHover;
  final Color collapsedHover;
  final Color accentBorder;
  final Color searchSurface;
  final Color focusedSearchSurface;
  final Color searchBorder;
  final Color focusedSearchBorder;
  final Color searchFocusRing;
  final Color searchInsetHighlight;
  final Color searchPlaceholder;
  final Color clearButton;
  final Color clearForeground;
  final Color sectionDivider;
  final Color sectionLabel;
  final Color dropdownSurface;
  final Color dropdownShadow;
}
