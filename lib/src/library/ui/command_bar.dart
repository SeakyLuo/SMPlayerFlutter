import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';

const multiSelectCommandBarScrollSpacer = 108.0;

class CommandBar extends StatelessWidget {
  const CommandBar({
    super.key,
    this.content,
    this.dynamicOverflow = true,
    this.overflowReserve = 0,
    this.overflowItems = const [],
    this.overflowLabel,
    required this.children,
  });

  final Widget? content;
  final bool dynamicOverflow;
  final double overflowReserve;
  final List<MenuFlyoutItem> overflowItems;
  final String? overflowLabel;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: CommandBarColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: CommandBarColors.border),
      ),
      child: Row(
        children: [
          if (content != null) Flexible(fit: FlexFit.loose, child: content!),
          if (content != null) const SizedBox(width: 8),
          Flexible(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final overflow = _resolveCommandBarOverflow(
                  context: context,
                  maxWidth: constraints.maxWidth,
                  dynamicOverflow: dynamicOverflow,
                  overflowReserve: overflowReserve,
                  overflowItems: overflowItems,
                  children: children,
                );
                final overflowMenuItems = [
                  ...overflow.overflowedChildren.map(_toMenuFlyoutItem),
                  ...overflowItems,
                ];

                return Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Flexible(
                      fit: FlexFit.loose,
                      child: ClipRect(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (final child in overflow.visibleChildren)
                                Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: child,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (overflowMenuItems.isNotEmpty)
                      Builder(
                        builder: (context) {
                          return CommandBarButton(
                            key: const ValueKey('CommandBar.MoreButton'),
                            icon: FluentIcons.more_horizontal_24_regular,
                            label: overflowLabel ?? 'More',
                            showLabel: false,
                            canOverflow: false,
                            onPressed: () {
                              showMenuFlyout(context, items: overflowMenuItems);
                            },
                          );
                        },
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class CommandBarButton extends StatelessWidget {
  const CommandBarButton({
    super.key,
    required this.icon,
    required this.label,
    this.active = false,
    this.canOverflow = true,
    this.disabled = false,
    this.overflowSubmenu = const [],
    this.showLabel = true,
    this.onOverflowPressed,
    this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool active;
  final bool canOverflow;
  final bool disabled;
  final List<MenuFlyoutItem> overflowSubmenu;
  final bool showLabel;
  final VoidCallback? onOverflowPressed;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final foreground =
        active ? CommandBarColors.accentStrong : CommandBarColors.text;
    final background =
        active ? CommandBarColors.accentSoft : Colors.transparent;

    return Tooltip(
      message: label,
      child: TextButton.icon(
        style: TextButton.styleFrom(
          minimumSize: Size(showLabel ? 0 : 40, 40),
          padding: EdgeInsets.symmetric(horizontal: showLabel ? 12 : 10),
          foregroundColor:
              disabled ? CommandBarColors.disabledText : foreground,
          backgroundColor: background,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        icon: Icon(icon, size: 18),
        label: showLabel ? Text(label) : const SizedBox.shrink(),
        onPressed: disabled ? null : onPressed,
      ),
    );
  }
}

class _CommandBarOverflowResult {
  const _CommandBarOverflowResult({
    required this.visibleChildren,
    required this.overflowedChildren,
  });

  final List<Widget> visibleChildren;
  final List<CommandBarButton> overflowedChildren;
}

_CommandBarOverflowResult _resolveCommandBarOverflow({
  required BuildContext context,
  required double maxWidth,
  required bool dynamicOverflow,
  required double overflowReserve,
  required List<MenuFlyoutItem> overflowItems,
  required List<Widget> children,
}) {
  if (!dynamicOverflow || maxWidth.isInfinite) {
    return _CommandBarOverflowResult(
      visibleChildren: children,
      overflowedChildren: const [],
    );
  }

  final itemWidths =
      children
          .map((child) => _estimateCommandBarItemWidth(context, child))
          .toList();
  final availableWidth = (maxWidth - overflowReserve).clamp(0, maxWidth);
  final moreWidth = _commandBarMoreButtonWidth;
  final overflowedIndexes = <int>{};
  var totalWidth = itemWidths.fold<double>(
    0,
    (total, width) => total + width + _commandBarItemGap,
  );
  final reservedMoreWidth =
      overflowItems.isNotEmpty || totalWidth > availableWidth ? moreWidth : 0;

  final overflowableIndexes = [
    for (var index = 0; index < children.length; index += 1)
      if (children[index] is CommandBarButton &&
          (children[index] as CommandBarButton).canOverflow)
        index,
  ];

  for (final index in overflowableIndexes.reversed) {
    if (totalWidth + reservedMoreWidth <= availableWidth) {
      break;
    }

    overflowedIndexes.add(index);
    totalWidth -= itemWidths[index] + _commandBarItemGap;
  }

  return _CommandBarOverflowResult(
    visibleChildren: [
      for (var index = 0; index < children.length; index += 1)
        if (!overflowedIndexes.contains(index)) children[index],
    ],
    overflowedChildren: [
      for (var index = 0; index < children.length; index += 1)
        if (overflowedIndexes.contains(index))
          children[index] as CommandBarButton,
    ],
  );
}

MenuFlyoutItem _toMenuFlyoutItem(CommandBarButton button) {
  return MenuFlyoutItem(
    key: 'commandbar-overflow-${button.label}',
    text: button.label,
    icon: button.icon,
    disabled: button.disabled,
    checked: button.active,
    submenu: button.disabled ? const [] : button.overflowSubmenu,
    onPressed:
        button.overflowSubmenu.isEmpty
            ? button.onOverflowPressed ?? button.onPressed
            : null,
  );
}

double _estimateCommandBarItemWidth(BuildContext context, Widget child) {
  if (child is! CommandBarButton) {
    return 80;
  }

  if (!child.showLabel) {
    return _commandBarMoreButtonWidth;
  }

  final labelStyle = DefaultTextStyle.of(
    context,
  ).style.copyWith(fontSize: 14, fontWeight: FontWeight.w700);
  final textPainter = TextPainter(
    text: TextSpan(text: child.label, style: labelStyle),
    textDirection: Directionality.of(context),
    maxLines: 1,
  )..layout();
  return (44 + 18 + 8 + textPainter.width).ceilToDouble();
}

const _commandBarItemGap = 4.0;
const _commandBarMoreButtonWidth = 44.0;

class MultiSelectCommandBar extends StatelessWidget {
  const MultiSelectCommandBar({
    super.key,
    required this.visible,
    required this.selectedCount,
    required this.onSelectAll,
    required this.onReverseSelection,
    required this.onClearSelection,
    required this.onCancel,
    this.showPlay = true,
    this.showAddTo = true,
    this.onPlay,
    this.addToSongIds = const [],
    this.includeNowPlayingInAddTo = false,
    this.includeFavoritesInAddTo = false,
    this.onAddToNowPlaying,
    this.onToggleFavorite,
    this.onCreatePlaylist,
    this.onAddToPlaylist,
    this.onRemove,
    this.removeLabel,
    this.currentPlaylistName,
    this.excludePlaylistName,
    this.extraActions = const [],
    this.hideAfterOperation = false,
    this.playlists = const [],
  });

  final bool visible;
  final int selectedCount;
  final bool showPlay;
  final bool showAddTo;
  final VoidCallback? onPlay;
  final List<int> addToSongIds;
  final bool includeNowPlayingInAddTo;
  final bool includeFavoritesInAddTo;
  final VoidCallback? onAddToNowPlaying;
  final VoidCallback? onToggleFavorite;
  final VoidCallback? onCreatePlaylist;
  final ValueChanged<int>? onAddToPlaylist;
  final VoidCallback? onRemove;
  final String? removeLabel;
  final String? currentPlaylistName;
  final String? excludePlaylistName;
  final List<MultiSelectCommandBarExtraAction> extraActions;
  final bool hideAfterOperation;
  final List<MultiSelectCommandBarPlaylist> playlists;
  final VoidCallback onSelectAll;
  final VoidCallback onReverseSelection;
  final VoidCallback onClearSelection;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final hasSelection = selectedCount > 0;

    void hideIfNeeded() {
      if (hideAfterOperation) {
        onClearSelection();
        onCancel();
      }
    }

    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        offset: visible ? Offset.zero : const Offset(0, 1.1),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 120),
          opacity: visible ? 1 : 0,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.fromLTRB(18, 0, 18, 14),
              constraints: const BoxConstraints(minHeight: 70),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: CommandBarColors.multiSelectSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: CommandBarColors.border),
                boxShadow: const [
                  BoxShadow(
                    color: CommandBarColors.multiSelectShadow,
                    blurRadius: 30,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 150,
                    child:
                        hasSelection
                            ? Row(
                              children: [
                                const Icon(
                                  FluentIcons.checkmark_20_regular,
                                  size: 18,
                                  color: CommandBarColors.accentStrong,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    i18n.t('albums.selectedCount', {
                                      'count': selectedCount,
                                    }),
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: CommandBarColors.textStrong,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            )
                            : const SizedBox.shrink(),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _MultiSelectAction(
                            icon: FluentIcons.dismiss_20_regular,
                            label: i18n.t('common.cancel'),
                            onPressed: onCancel,
                          ),
                          const _MultiSelectSeparator(),
                          if (showPlay && onPlay != null)
                            _MultiSelectAction(
                              icon: FluentIcons.play_20_regular,
                              label: i18n.t('albums.playSelected'),
                              disabled: !hasSelection,
                              onPressed: onPlay,
                            ),
                          if (showAddTo &&
                              (onAddToPlaylist != null ||
                                  onAddToNowPlaying != null ||
                                  onToggleFavorite != null ||
                                  onCreatePlaylist != null))
                            _MultiSelectAddToAction(
                              enabled: hasSelection,
                              songIds: addToSongIds,
                              playlists: playlists,
                              includeNowPlaying: includeNowPlayingInAddTo,
                              includeFavorites: includeFavoritesInAddTo,
                              currentPlaylistName: currentPlaylistName,
                              excludePlaylistName: excludePlaylistName,
                              onAddToNowPlaying: onAddToNowPlaying,
                              onToggleFavorite: onToggleFavorite,
                              onCreatePlaylist: onCreatePlaylist,
                              onAddToPlaylist: onAddToPlaylist,
                              onMenuItemSelected: hideIfNeeded,
                            ),
                          if (onRemove != null)
                            _MultiSelectAction(
                              icon: FluentIcons.delete_20_regular,
                              label:
                                  removeLabel ??
                                  i18n.t('context.removeFromList'),
                              disabled: !hasSelection,
                              onPressed: () {
                                onRemove?.call();
                                hideIfNeeded();
                              },
                            ),
                          for (final action in extraActions)
                            _MultiSelectAction(
                              icon: action.icon,
                              label: action.text,
                              disabled: action.disabled,
                              onPressed: () {
                                action.onPressed();
                                if (action.hideAfterClick) {
                                  hideIfNeeded();
                                }
                              },
                            ),
                          const _MultiSelectSeparator(),
                          _MultiSelectAction(
                            icon: FluentIcons.select_all_on_20_regular,
                            label: i18n.t('albums.selectAll'),
                            onPressed: onSelectAll,
                          ),
                          _MultiSelectAction(
                            icon: FluentIcons.select_all_off_20_regular,
                            label: i18n.t('albums.reverseSelection'),
                            onPressed: onReverseSelection,
                          ),
                          _MultiSelectAction(
                            icon: FluentIcons.dismiss_circle_20_regular,
                            label: i18n.t('albums.clearSelection'),
                            onPressed: onClearSelection,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Builder(
                    builder: (context) {
                      return IconButton(
                        tooltip: i18n.t('player.more'),
                        icon: const Icon(
                          FluentIcons.more_horizontal_24_regular,
                        ),
                        onPressed: () {
                          showMenuFlyout(
                            context,
                            items: [
                              if (onRemove != null)
                                MenuFlyoutItem(
                                  key: 'remove-selected',
                                  text:
                                      removeLabel ??
                                      i18n.t('context.removeFromList'),
                                  icon: FluentIcons.delete_20_regular,
                                  disabled: !hasSelection,
                                  onPressed: () {
                                    onRemove?.call();
                                    hideIfNeeded();
                                  },
                                ),
                              for (final action in extraActions)
                                MenuFlyoutItem(
                                  key: action.key,
                                  text: action.text,
                                  icon: action.icon,
                                  disabled: action.disabled,
                                  onPressed: () {
                                    action.onPressed();
                                    if (action.hideAfterClick) {
                                      hideIfNeeded();
                                    }
                                  },
                                ),
                              const MenuFlyoutItem.separator(
                                key: 'selection-separator',
                              ),
                              MenuFlyoutItem(
                                key: 'select-all',
                                text: i18n.t('albums.selectAll'),
                                icon: FluentIcons.select_all_on_20_regular,
                                onPressed: onSelectAll,
                              ),
                              MenuFlyoutItem(
                                key: 'reverse-selection',
                                text: i18n.t('albums.reverseSelection'),
                                icon: FluentIcons.select_all_off_20_regular,
                                onPressed: onReverseSelection,
                              ),
                              MenuFlyoutItem(
                                key: 'clear-selection',
                                text: i18n.t('albums.clearSelection'),
                                icon: FluentIcons.dismiss_circle_20_regular,
                                onPressed: onClearSelection,
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MultiSelectCommandBarPlaylist {
  const MultiSelectCommandBarPlaylist({
    required this.id,
    required this.name,
    this.songIds = const [],
  });

  final int id;
  final String name;
  final List<int> songIds;
}

class MultiSelectCommandBarExtraAction {
  const MultiSelectCommandBarExtraAction({
    required this.key,
    required this.text,
    required this.icon,
    required this.onPressed,
    this.disabled = false,
    this.hideAfterClick = false,
  });

  final String key;
  final String text;
  final IconData icon;
  final VoidCallback onPressed;
  final bool disabled;
  final bool hideAfterClick;
}

class MenuFlyoutFolder {
  const MenuFlyoutFolder({
    required this.id,
    required this.name,
    required this.path,
    required this.parentId,
  });

  final int id;
  final String name;
  final String path;
  final int parentId;
}

class MenuFlyoutItem {
  const MenuFlyoutItem({
    required this.key,
    required this.text,
    this.icon,
    this.disabled = false,
    this.checked = false,
    this.submenu = const [],
    this.onPressed,
    this.content,
    this.contentHeight = 42,
  }) : separator = false;

  const MenuFlyoutItem.separator({required this.key})
    : text = '',
      icon = null,
      disabled = false,
      checked = false,
      submenu = const [],
      onPressed = null,
      content = null,
      contentHeight = 42,
      separator = true;

  final String key;
  final String text;
  final IconData? icon;
  final bool disabled;
  final bool checked;
  final List<MenuFlyoutItem> submenu;
  final VoidCallback? onPressed;
  final Widget? content;
  final double contentHeight;
  final bool separator;
}

MenuFlyoutItem? buildAddToPlaylistMenuFlyoutItem({
  required SmPlayerI18n i18n,
  required List<int> songIds,
  required List<MultiSelectCommandBarPlaylist> playlists,
  bool includeNowPlaying = false,
  bool includeFavorites = false,
  String? currentPlaylistName,
  String? excludePlaylistName,
  VoidCallback? onAddToNowPlaying,
  VoidCallback? onToggleFavorite,
  VoidCallback? onCreatePlaylist,
  ValueChanged<int>? onAddToPlaylist,
  String key = 'add-to',
}) {
  final addablePlaylists =
      playlists.where((playlist) {
        if (playlist.name == (excludePlaylistName ?? currentPlaylistName)) {
          return false;
        }
        if (songIds.length != 1) {
          return true;
        }
        return !playlist.songIds.contains(songIds.first);
      }).toList();
  final submenu = <MenuFlyoutItem>[];

  if (includeNowPlaying && onAddToNowPlaying != null) {
    submenu.add(
      MenuFlyoutItem(
        key: '$key-now-playing',
        text: i18n.t('common.nowPlaying'),
        icon: FluentIcons.music_note_2_20_regular,
        disabled: songIds.isEmpty,
        onPressed: onAddToNowPlaying,
      ),
    );
  }

  if (includeFavorites && onToggleFavorite != null) {
    submenu.add(
      MenuFlyoutItem(
        key: '$key-favorites',
        text: i18n.t('common.myFavorites'),
        icon: FluentIcons.heart_20_regular,
        disabled: songIds.isEmpty,
        onPressed: onToggleFavorite,
      ),
    );
  }

  if (submenu.isNotEmpty &&
      (onCreatePlaylist != null || addablePlaylists.isNotEmpty)) {
    submenu.add(MenuFlyoutItem.separator(key: '$key-built-in-separator'));
  }

  if (onCreatePlaylist != null) {
    submenu.add(
      MenuFlyoutItem(
        key: '$key-new-playlist',
        text: i18n.t('playlists.newPlaylist'),
        icon: FluentIcons.add_20_regular,
        disabled: songIds.isEmpty,
        onPressed: onCreatePlaylist,
      ),
    );
  }

  submenu.addAll(
    addablePlaylists.map(
      (playlist) => MenuFlyoutItem(
        key: '$key-${playlist.id}',
        text: playlist.name,
        icon: FluentIcons.apps_list_detail_20_regular,
        disabled: songIds.isEmpty,
        onPressed: () {
          onAddToPlaylist?.call(playlist.id);
        },
      ),
    ),
  );

  if (submenu.isEmpty) {
    return null;
  }

  return MenuFlyoutItem(
    key: key,
    text: i18n.t('context.addToPlaylist'),
    icon: FluentIcons.add_20_regular,
    disabled: songIds.isEmpty,
    submenu: submenu,
  );
}

List<MenuFlyoutItem> buildMusicMenuFlyoutItems({
  required SmPlayerI18n i18n,
  required int songId,
  required bool isFavorite,
  required bool isCurrentTrack,
  required bool isPlaying,
  required List<MultiSelectCommandBarPlaylist> playlists,
  required VoidCallback onPlay,
  required VoidCallback onPause,
  required VoidCallback onPlayNext,
  required VoidCallback onAddToNowPlaying,
  required VoidCallback onCreatePlaylist,
  required ValueChanged<int> onAddToPlaylist,
  required VoidCallback onRemove,
  required VoidCallback onSelect,
  required VoidCallback onToggleFavorite,
  required ValueChanged<String> onSetPreference,
  required VoidCallback onSeeArtist,
  required VoidCallback onSeeAlbum,
  required VoidCallback onSeeMusicInfo,
  required VoidCallback onSeeLyrics,
  required VoidCallback onSeeAlbumArt,
  required VoidCallback onSeeLocal,
  String? currentPlaylistName,
  String? excludePlaylistName,
  int? currentTrackId,
  String songPath = '',
  String? preferenceLevel,
  VoidCallback? onUndoPreference,
  List<MenuFlyoutFolder> folders = const [],
  ValueChanged<String>? onMoveToFolder,
  VoidCallback? onDelete,
  VoidCallback? onHide,
  bool showRemove = false,
  String? removeLabel,
  bool showSeeArtistsAndSeeAlbum = true,
  bool showMusicProperties = true,
  bool showSelect = true,
  bool showDelete = true,
  bool showHideFile = false,
  bool showPreference = true,
  bool showMoveToFolder = false,
  bool showAlbumArt = true,
}) {
  final items = <MenuFlyoutItem>[
    if (isCurrentTrack && isPlaying)
      MenuFlyoutItem(
        key: 'pause',
        text: i18n.t('context.pause'),
        icon: FluentIcons.pause_20_regular,
        onPressed: onPause,
      )
    else
      MenuFlyoutItem(
        key: 'play',
        text: i18n.t('context.play'),
        icon: FluentIcons.play_20_regular,
        onPressed: onPlay,
      ),
  ];

  if (currentTrackId != null && !isCurrentTrack) {
    items.add(
      MenuFlyoutItem(
        key: 'play-next',
        text: i18n.t('context.playNext'),
        icon: FluentIcons.next_20_regular,
        onPressed: onPlayNext,
      ),
    );
  }

  final addToItem = buildAddToPlaylistMenuFlyoutItem(
    i18n: i18n,
    songIds: [songId],
    playlists: playlists,
    currentPlaylistName: currentPlaylistName,
    excludePlaylistName: excludePlaylistName ?? currentPlaylistName,
    includeNowPlaying: currentPlaylistName != i18n.t('common.nowPlaying'),
    includeFavorites:
        currentPlaylistName != i18n.t('common.myFavorites') && !isFavorite,
    onAddToNowPlaying: onAddToNowPlaying,
    onToggleFavorite: isFavorite ? null : onToggleFavorite,
    onCreatePlaylist: onCreatePlaylist,
    onAddToPlaylist: onAddToPlaylist,
  );
  if (addToItem != null) {
    items.add(addToItem);
  }

  if (showRemove) {
    items.add(
      MenuFlyoutItem(
        key: 'remove',
        text: removeLabel ?? i18n.t('context.removeFromList'),
        icon: FluentIcons.dismiss_20_regular,
        onPressed: onRemove,
      ),
    );
  }

  if (showSelect) {
    items.add(
      MenuFlyoutItem(
        key: 'select',
        text: i18n.t('context.select'),
        icon: FluentIcons.select_all_on_20_regular,
        onPressed: onSelect,
      ),
    );
  }

  if (showPreference) {
    items.add(
      MenuFlyoutItem(
        key: 'preference',
        text: i18n.t('settings.preferenceSettings'),
        icon: FluentIcons.star_20_regular,
        submenu: [
          if (preferenceLevel != null && onUndoPreference != null) ...[
            MenuFlyoutItem(
              key: 'preference-undo',
              text: i18n.t('preferences.undoPrefer'),
              icon: FluentIcons.arrow_undo_20_regular,
              onPressed: onUndoPreference,
            ),
            const MenuFlyoutItem.separator(key: 'preference-undo-separator'),
          ],
          for (final level in const [
            'do-not-appear',
            'dislike',
            'normal',
            'high',
            'higher',
            'very-high',
          ])
            MenuFlyoutItem(
              key: 'preference-$level',
              text: i18n.t('preferences.level.$level'),
              checked: preferenceLevel == level,
              onPressed: () {
                onSetPreference(level);
              },
            ),
        ],
      ),
    );
  }

  if (showMoveToFolder && folders.isNotEmpty && onMoveToFolder != null) {
    final moveToFolderItem = _buildMoveToFolderMenuFlyoutItem(
      i18n: i18n,
      folders: folders,
      songPath: songPath,
      onMoveToFolder: onMoveToFolder,
    );
    if (moveToFolderItem != null) {
      items.add(moveToFolderItem);
    }
  }

  if (showDelete && onDelete != null) {
    items.add(
      MenuFlyoutItem(
        key: 'delete',
        text: i18n.t('context.deleteFromDisk'),
        icon: FluentIcons.delete_20_regular,
        onPressed: onDelete,
      ),
    );
  }

  if (showHideFile && onHide != null) {
    items.add(
      MenuFlyoutItem(
        key: 'hide-file',
        text: i18n.t('context.hideFile'),
        icon: FluentIcons.dismiss_20_regular,
        onPressed: onHide,
      ),
    );
  }

  final viewItems = <MenuFlyoutItem>[];
  if (showSeeArtistsAndSeeAlbum) {
    viewItems.addAll([
      MenuFlyoutItem(
        key: 'see-artist',
        text: i18n.t('context.seeArtist'),
        icon: FluentIcons.person_20_regular,
        onPressed: onSeeArtist,
      ),
      MenuFlyoutItem(
        key: 'see-album',
        text: i18n.t('context.seeAlbum'),
        icon: FluentIcons.album_20_regular,
        onPressed: onSeeAlbum,
      ),
    ]);
  }
  if (showMusicProperties) {
    viewItems.addAll([
      MenuFlyoutItem(
        key: 'see-music-info',
        text: i18n.t('context.seeMusicInfo'),
        icon: FluentIcons.info_20_regular,
        onPressed: onSeeMusicInfo,
      ),
      MenuFlyoutItem(
        key: 'see-lyrics',
        text: i18n.t('context.seeLyrics'),
        icon: FluentIcons.text_grammar_wand_20_regular,
        onPressed: onSeeLyrics,
      ),
      if (showAlbumArt)
        MenuFlyoutItem(
          key: 'see-album-art',
          text: i18n.t('context.seeAlbumArt'),
          icon: FluentIcons.image_20_regular,
          onPressed: onSeeAlbumArt,
        ),
      MenuFlyoutItem(
        key: 'see-local',
        text: i18n.t('context.seeLocalFile'),
        icon: FluentIcons.folder_open_20_regular,
        onPressed: onSeeLocal,
      ),
    ]);
  }
  if (viewItems.isNotEmpty) {
    items.add(
      MenuFlyoutItem(
        key: 'view',
        text: i18n.t('context.view'),
        icon: FluentIcons.eye_20_regular,
        submenu: viewItems,
      ),
    );
  }

  return items;
}

MenuFlyoutItem? _buildMoveToFolderMenuFlyoutItem({
  required SmPlayerI18n i18n,
  required List<MenuFlyoutFolder> folders,
  required String songPath,
  required ValueChanged<String> onMoveToFolder,
}) {
  final currentFolderPath = _getFileParentPath(songPath);
  final childrenByParentId = <int, List<MenuFlyoutFolder>>{};
  for (final folder in folders) {
    childrenByParentId[folder.parentId] = [
      ...(childrenByParentId[folder.parentId] ?? const <MenuFlyoutFolder>[]),
      folder,
    ];
  }

  MenuFlyoutItem toTargetItem(MenuFlyoutFolder folder) {
    return MenuFlyoutItem(
      key: 'move-folder-${folder.id}-target',
      text: folder.name,
      icon: FluentIcons.folder_20_regular,
      onPressed: () {
        onMoveToFolder(folder.path);
      },
    );
  }

  MenuFlyoutItem? toItem(MenuFlyoutFolder folder) {
    final children =
        (childrenByParentId[folder.id] ?? const <MenuFlyoutFolder>[]).toList()
          ..sort((left, right) => left.name.compareTo(right.name));
    final childItems = [
      for (final child in children)
        if (toItem(child) case final item?) item,
    ];
    final isTargetFolder = currentFolderPath != folder.path;

    if (childItems.isEmpty) {
      return isTargetFolder ? toTargetItem(folder) : null;
    }

    return MenuFlyoutItem(
      key: 'move-folder-${folder.id}',
      text: folder.name,
      icon: FluentIcons.folder_20_regular,
      submenu:
          isTargetFolder
              ? [
                toTargetItem(folder),
                MenuFlyoutItem.separator(
                  key: 'move-folder-${folder.id}-separator',
                ),
                ...childItems,
              ]
              : childItems,
    );
  }

  final rootItems =
      [
        for (final folder
            in (folders
                .where(
                  (folder) =>
                      folder.parentId == 0 ||
                      !folders.any((item) => item.id == folder.parentId),
                )
                .toList()
              ..sort((left, right) => left.name.compareTo(right.name))))
          if (toItem(folder) case final item?) item,
      ].expand((item) => item.submenu.isEmpty ? [item] : item.submenu).toList();

  if (rootItems.isEmpty) {
    return null;
  }

  return MenuFlyoutItem(
    key: 'move-to-folder',
    text: i18n.t('context.moveToFolder'),
    icon: FluentIcons.folder_20_regular,
    submenu: rootItems,
  );
}

String _getFileParentPath(String filePath) {
  final separatorIndex = filePath.lastIndexOf(RegExp(r'[\\/]'));
  return separatorIndex > -1 ? filePath.substring(0, separatorIndex) : '';
}

Future<void> showMenuFlyout(
  BuildContext context, {
  required List<MenuFlyoutItem> items,
  Offset? position,
}) {
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
  final button = context.findRenderObject() as RenderBox;
  final resolvedPosition =
      position ?? button.localToGlobal(Offset(0, button.size.height + 4));

  return showMenu<void>(
    context: context,
    position: RelativeRect.fromRect(
      Rect.fromLTWH(resolvedPosition.dx, resolvedPosition.dy, 1, 1),
      Offset.zero & overlay.size,
    ),
    constraints: const BoxConstraints(minWidth: 212),
    items:
        items.map<PopupMenuEntry<void>>((item) {
          if (item.separator) {
            return const PopupMenuDivider(height: 12);
          }
          if (item.content != null) {
            return _MenuFlyoutContentEntry(
              height: item.contentHeight,
              child: item.content!,
            );
          }

          return PopupMenuItem<void>(
            enabled: !item.disabled,
            onTap:
                item.submenu.isEmpty
                    ? item.onPressed
                    : () {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        showMenuFlyout(
                          context,
                          items: item.submenu,
                          position: resolvedPosition + const Offset(196, 0),
                        );
                      });
                    },
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: item.icon == null ? null : Icon(item.icon, size: 18),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(item.text)),
                if (item.checked)
                  const Icon(FluentIcons.checkmark_20_regular, size: 18),
                if (item.submenu.isNotEmpty)
                  const Icon(FluentIcons.chevron_right_20_regular, size: 18),
              ],
            ),
          );
        }).toList(),
  );
}

class _MenuFlyoutContentEntry extends PopupMenuEntry<void> {
  const _MenuFlyoutContentEntry({required this.height, required this.child});

  @override
  final double height;
  final Widget child;

  @override
  bool represents(void value) => false;

  @override
  State<_MenuFlyoutContentEntry> createState() =>
      _MenuFlyoutContentEntryState();
}

class _MenuFlyoutContentEntryState extends State<_MenuFlyoutContentEntry> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(height: widget.height, child: widget.child);
  }
}

class _MultiSelectAction extends StatelessWidget {
  const _MultiSelectAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.disabled = false,
  });

  final IconData icon;
  final String label;
  final bool disabled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        foregroundColor:
            disabled ? CommandBarColors.disabledText : CommandBarColors.text,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      icon: Icon(icon, size: 18),
      label: Text(label),
      onPressed: disabled ? null : onPressed,
    );
  }
}

class _MultiSelectAddToAction extends StatelessWidget {
  const _MultiSelectAddToAction({
    required this.enabled,
    required this.songIds,
    required this.playlists,
    required this.includeNowPlaying,
    required this.includeFavorites,
    required this.currentPlaylistName,
    required this.excludePlaylistName,
    required this.onAddToNowPlaying,
    required this.onToggleFavorite,
    required this.onCreatePlaylist,
    required this.onAddToPlaylist,
    required this.onMenuItemSelected,
  });

  final bool enabled;
  final List<int> songIds;
  final List<MultiSelectCommandBarPlaylist> playlists;
  final bool includeNowPlaying;
  final bool includeFavorites;
  final String? currentPlaylistName;
  final String? excludePlaylistName;
  final VoidCallback? onAddToNowPlaying;
  final VoidCallback? onToggleFavorite;
  final VoidCallback? onCreatePlaylist;
  final ValueChanged<int>? onAddToPlaylist;
  final VoidCallback onMenuItemSelected;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;

    return Builder(
      builder: (buttonContext) {
        return _MultiSelectAction(
          icon: FluentIcons.add_20_regular,
          label: i18n.t('albums.addSelectedTo'),
          disabled: !enabled,
          onPressed: () {
            final menuSongIds =
                songIds.isEmpty && enabled ? const [-1] : songIds;
            final addToItem = buildAddToPlaylistMenuFlyoutItem(
              i18n: i18n,
              songIds: menuSongIds,
              playlists: playlists,
              currentPlaylistName: currentPlaylistName,
              excludePlaylistName: excludePlaylistName,
              includeNowPlaying: includeNowPlaying,
              includeFavorites: includeFavorites,
              onAddToNowPlaying:
                  onAddToNowPlaying == null
                      ? null
                      : () {
                        onAddToNowPlaying?.call();
                        onMenuItemSelected();
                      },
              onToggleFavorite:
                  onToggleFavorite == null
                      ? null
                      : () {
                        onToggleFavorite?.call();
                        onMenuItemSelected();
                      },
              onCreatePlaylist:
                  onCreatePlaylist == null
                      ? null
                      : () {
                        onCreatePlaylist?.call();
                        onMenuItemSelected();
                      },
              onAddToPlaylist: (playlistId) {
                onAddToPlaylist?.call(playlistId);
                onMenuItemSelected();
              },
            );
            if (addToItem == null) {
              return;
            }

            showMenuFlyout(buttonContext, items: addToItem.submenu);
          },
        );
      },
    );
  }
}

class _MultiSelectSeparator extends StatelessWidget {
  const _MultiSelectSeparator();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 26,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: CommandBarColors.separator,
    );
  }
}

class CommandBarColors {
  const CommandBarColors._();

  static const surface = Color(0xb8ffffff);
  static const multiSelectSurface = Color(0xf7ffffff);
  static const border = Color(0x2b64748b);
  static const separator = Color(0x2b64748b);
  static const text = Color(0xff344054);
  static const textStrong = Color(0xff111827);
  static const disabledText = Color(0x615b697a);
  static const accentStrong = Color(0xff0063b1);
  static const accentSoft = Color(0x1a0078d7);
  static const multiSelectShadow = Color(0x2e2f425c);
}
