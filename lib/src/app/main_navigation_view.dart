import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:smplayer_flutter/src/app/app_interaction_colors.dart';
import 'package:smplayer_flutter/src/app/smplayer_vector_icons.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/ui/page_search_history_panel.dart';
import 'package:smplayer_flutter/src/library/ui/search_commit_icon_button.dart';

import '../library/ui/menu_flyout.dart';

part 'main_navigation_models.dart';
part 'main_navigation_search.dart';
part 'main_navigation_sections.dart';
part 'main_navigation_recent_searches.dart';
part 'main_navigation_controls.dart';
part 'main_navigation_colors.dart';

typedef MainNavigationSearchCommit =
    void Function(String value, [SearchHistoryType type]);
typedef _NavigationTooltipRequest = void Function(String label, Rect target);

enum _PlaylistDropPosition { before, after }

const _expandedNavigationContentMinWidth = 220.0;

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
    this.showTitlebar = true,
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
    this.searchHistoryDismissEpoch = 0,
    this.onSearchHistoryOpenChanged,
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
  final bool showTitlebar;
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
  final int searchHistoryDismissEpoch;
  final ValueChanged<bool>? onSearchHistoryOpenChanged;
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
  final _searchFieldLayerLink = LayerLink();
  var _focusSearchAfterPaneOpen = false;
  var _isSearchHistoryOpen = false;
  var _isPlaylistNavExpanded = true;
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
    if (oldWidget.searchHistoryDismissEpoch !=
        widget.searchHistoryDismissEpoch) {
      _closeSearchHistory();
      return;
    }
    if (_focusSearchAfterPaneOpen && widget.isPaneOpen) {
      _focusSearchAfterPaneOpen = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _searchFocusNode.requestFocus();
      });
    }
    if (!_isSearchHistoryOpen &&
        _searchFocusNode.hasFocus &&
        widget.recentSearches.any(
          (entry) => entry.type == SearchHistoryType.sidebar,
        )) {
      _setSearchHistoryOpen(true);
    }
  }

  void _setSearchHistoryOpen(bool open) {
    if (_isSearchHistoryOpen == open) {
      return;
    }
    _isSearchHistoryOpen = open;
    widget.onSearchHistoryOpenChanged?.call(open);
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
    if (!_isSearchHistoryOpen && !_searchFocusNode.hasFocus) {
      return;
    }
    setState(() {
      _setSearchHistoryOpen(false);
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

  _MainNavigationPlaylistSection _buildPlaylistSection({
    required bool collapsed,
    required List<LibraryPlaylist> customPlaylists,
  }) {
    return _MainNavigationPlaylistSection(
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
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final collapsed = !widget.isPaneOpen;
    final visibleRecentSearches = latestSearchHistoryEntries(
      widget.recentSearches,
      SearchHistoryType.sidebar,
    );
    final customPlaylists =
        widget.playlists
            .where(
              (playlist) =>
                  !playlist.isBuiltIn &&
                  playlist.name != widget.i18n.t('common.nowPlaying') &&
                  playlist.name != 'Now Playing',
            )
            .toList();
    final resolvedAppName = _navigationAppName(
      widget.i18n,
      View.of(context).platformDispatcher.locale,
    );
    final topPadding = widget.showTitlebar ? 8.0 : 0.0;

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
              padding: EdgeInsets.fromLTRB(12, topPadding, 12, 8),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final contentCollapsed =
                      collapsed ||
                      constraints.maxWidth < _expandedNavigationContentMinWidth;
                  final showRecentSearches =
                      !contentCollapsed &&
                      _isSearchHistoryOpen &&
                      visibleRecentSearches.isNotEmpty;
                  final playlistSection = _buildPlaylistSection(
                    collapsed: contentCollapsed,
                    customPlaylists: customPlaylists,
                  );
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Column(
                        crossAxisAlignment:
                            contentCollapsed
                                ? CrossAxisAlignment.center
                                : CrossAxisAlignment.start,
                        children: [
                          if (widget.showTitlebar) ...[
                            _MainNavigationViewTitle(
                              collapsed: contentCollapsed,
                              hideAppName:
                                  defaultTargetPlatform == TargetPlatform.macOS,
                              appName: resolvedAppName,
                              titlebarLeadingInset:
                                  defaultTargetPlatform == TargetPlatform.macOS
                                      ? _desktopTitlebarButtonInset
                                      : 0,
                              canGoBack:
                                  defaultTargetPlatform == TargetPlatform.macOS
                                      ? false
                                      : widget.canGoBack,
                              backLabel: widget.i18n.t('sidebar.back'),
                              onGoBack: widget.onGoBack,
                              onWindowDragStart: widget.onWindowDragStart,
                              onWindowDragEnd: widget.onWindowDragEnd,
                              onTooltipRequested:
                                  contentCollapsed
                                      ? _showFloatingTooltip
                                      : null,
                              onTooltipDismissed: _hideFloatingTooltip,
                            ),
                            const SizedBox(height: 8),
                          ],
                          _NavigationIconButton(
                            key: const ValueKey(
                              'MainNavigationView.TogglePaneButton',
                            ),
                            icon: FluentIcons.line_horizontal_3_24_regular,
                            tooltip:
                                contentCollapsed
                                    ? widget.i18n.t('sidebar.expandNavigation')
                                    : widget.i18n.t(
                                      'sidebar.collapseNavigation',
                                    ),
                            collapsedContext: contentCollapsed,
                            onPressed: () {
                              _hideFloatingTooltip();
                              widget.onPaneToggle();
                            },
                            onTooltipRequested:
                                contentCollapsed ? _showFloatingTooltip : null,
                            onTooltipDismissed: _hideFloatingTooltip,
                          ),
                          const SizedBox(height: 8),
                          _MainNavigationViewSearchBox(
                            collapsed: contentCollapsed,
                            value: widget.searchText,
                            i18n: widget.i18n,
                            focusNode: _searchFocusNode,
                            onChanged: widget.onSearchTextChanged,
                            onSubmitted: (value) {
                              widget.onSearchCommitted(value);
                              setState(() {
                                _setSearchHistoryOpen(false);
                              });
                              _searchFocusNode.unfocus();
                            },
                            onCleared: widget.onSearchCleared,
                            onFocusChanged: (focused) {
                              if (focused) {
                                setState(() {
                                  _setSearchHistoryOpen(true);
                                });
                              }
                            },
                            onSearchHistoryRequested: () {
                              setState(() {
                                _setSearchHistoryOpen(true);
                              });
                            },
                            onSearchHistoryDismissed: _closeSearchHistory,
                            onCollapsedSearchPressed: () {
                              _hideFloatingTooltip();
                              _focusSearchAfterPaneOpen = true;
                              widget.onPaneToggle();
                            },
                            searchFieldLayerLink: _searchFieldLayerLink,
                            onTooltipRequested:
                                contentCollapsed ? _showFloatingTooltip : null,
                            onTooltipDismissed: _hideFloatingTooltip,
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final libraryAndPlayback = <Widget>[
                                  _MainNavigationSectionLabel(
                                    collapsed: contentCollapsed,
                                    label: widget.i18n.t('sidebar.library'),
                                  ),
                                  _MainNavigationViewSection(
                                    collapsed: contentCollapsed,
                                    items: _libraryItems,
                                    i18n: widget.i18n,
                                    currentPath: widget.currentPath,
                                    onItemInvoked: _invokeNavigationItem,
                                    onTooltipRequested:
                                        contentCollapsed
                                            ? _showFloatingTooltip
                                            : null,
                                    onTooltipDismissed: _hideFloatingTooltip,
                                  ),
                                  const _MainNavigationViewSeparator(),
                                  _MainNavigationSectionLabel(
                                    collapsed: contentCollapsed,
                                    label: widget.i18n.t('sidebar.playback'),
                                  ),
                                  _MainNavigationViewSection(
                                    collapsed: contentCollapsed,
                                    items: _playbackItems,
                                    i18n: widget.i18n,
                                    currentPath: widget.currentPath,
                                    onItemInvoked: _invokeNavigationItem,
                                    onTooltipRequested:
                                        contentCollapsed
                                            ? _showFloatingTooltip
                                            : null,
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
                          ),
                          const SizedBox(height: 8),
                          _MainNavigationViewSection(
                            collapsed: contentCollapsed,
                            items: const [_settingsItem],
                            i18n: widget.i18n,
                            currentPath: widget.currentPath,
                            onItemInvoked: _invokeNavigationItem,
                            onTooltipRequested:
                                contentCollapsed ? _showFloatingTooltip : null,
                            onTooltipDismissed: _hideFloatingTooltip,
                          ),
                        ],
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
                          left: 0,
                          right: 0,
                          top: 0,
                          child: CompositedTransformFollower(
                            link: _searchFieldLayerLink,
                            showWhenUnlinked: false,
                            offset: const Offset(0, 48),
                            child: TextFieldTapRegion(
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
                                    _setSearchHistoryOpen(false);
                                  });
                                  _searchFocusNode.unfocus();
                                },
                                onSearchRemoved: widget.onRecentSearchRemove,
                                onClear: widget.onRecentSearchesClear,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
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
