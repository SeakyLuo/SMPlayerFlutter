part of 'main_navigation_view.dart';

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
                Flexible(
                  fit: FlexFit.loose,
                  child: ListView(
                    key: const ValueKey('MainNavigationView.PlaylistScroll'),
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
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
            key: const ValueKey('MainNavigationView.PlaylistsHeadingItem'),
            item: _MainNavigationViewState._playlistsItem,
            label: _MainNavigationViewState._playlistsItem.labelFor(i18n),
            collapsed: false,
            active: active,
            onPressed: onOpen,
          ),
        ),
        const SizedBox(width: 6),
        _NavigationIconButton(
          key: const ValueKey('MainNavigationView.CreatePlaylistButton'),
          icon: FluentIcons.add_24_regular,
          tooltip: i18n.t('playlists.createNew'),
          size: 34,
          iconSize: 16,
          borderRadius: 10,
          useMutedForeground: true,
          onPressed: () {
            onCreatePlaylist?.call();
            if (!expanded) {
              onToggleExpanded();
            }
          },
        ),
        const SizedBox(width: 6),
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
          size: 34,
          iconSize: 16,
          borderRadius: 10,
          useMutedForeground: true,
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
  final _focusNode = FocusNode();
  var _hovered = false;
  var _focused = false;
  var _randomHovered = false;
  var _randomFocused = false;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = MainNavigationViewColors.of(context);
    final highlighted = widget.active || _hovered;
    final showRandomPlay =
        widget.onRandomPlay != null &&
        widget.playlist.songIds.isNotEmpty &&
        (_hovered || _focused || _randomFocused);
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
          child: Focus(
            focusNode: _focusNode,
            onFocusChange: (focused) {
              setState(() {
                _focused = focused;
              });
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                _focusNode.requestFocus();
                widget.onPressed();
              },
              onSecondaryTapDown: (details) {
                _focusNode.requestFocus();
                _showPlaylistMenu(context, details.globalPosition);
              },
              onLongPressStart: (details) {
                _focusNode.requestFocus();
                _showPlaylistMenu(context, details.globalPosition);
              },
              child: Opacity(
                opacity: widget.dragging ? 0.45 : 1,
                child: Container(
                  height: 40,
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color:
                        highlighted ? colors.accentHover : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    border: _dropIndicatorBorder(widget.dropPosition),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: Center(
                          child: SizedBox.square(
                            dimension: 19,
                            child: CustomPaint(
                              painter: _PlaylistNavigationIconPainter(
                                foreground,
                              ),
                            ),
                          ),
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
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            height: 1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 30,
                        child: IgnorePointer(
                          ignoring: !showRandomPlay,
                          child: Opacity(
                            opacity: showRandomPlay ? 1 : 0,
                            child: Tooltip(
                              message: widget.randomPlayLabel,
                              waitDuration: const Duration(milliseconds: 450),
                              child: Center(
                                child: SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: MouseRegion(
                                    cursor: SystemMouseCursors.click,
                                    onEnter: (_) {
                                      setState(() {
                                        _randomHovered = true;
                                      });
                                    },
                                    onExit: (_) {
                                      setState(() {
                                        _randomHovered = false;
                                      });
                                    },
                                    child: Focus(
                                      onFocusChange: (focused) {
                                        setState(() {
                                          _randomFocused = focused;
                                        });
                                      },
                                      child: GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: widget.onRandomPlay,
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            color:
                                                _randomHovered || _randomFocused
                                                    ? colors.iconButtonHover
                                                    : Colors.transparent,
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          child: Icon(
                                            FluentIcons
                                                .arrow_shuffle_20_regular,
                                            size: 18,
                                            color:
                                                _randomHovered || _randomFocused
                                                    ? colors.accentStrong
                                                    : foreground,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
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
