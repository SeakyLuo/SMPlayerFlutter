import 'dart:async';
import 'dart:ui';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:smplayer_flutter/src/app/smplayer_vector_icons.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/ui/command_bar_colors.dart';
import 'package:smplayer_flutter/src/library/ui/menu_flyout.dart';
import 'package:smplayer_flutter/src/library/ui/menu_flyout_helpers.dart';

const multiSelectCommandBarScrollSpacer = 108.0;

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
    this.defaultPlaylistName,
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
  final String? defaultPlaylistName;
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
    if (!visible) {
      return const SizedBox.shrink();
    }
    final hasSelection = selectedCount > 0;

    void cancel() {
      onClearSelection();
      onCancel();
    }

    void hideIfNeeded() {
      if (hideAfterOperation) {
        cancel();
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                final viewportWidth = MediaQuery.sizeOf(context).width;
                final compactSelection = viewportWidth <= 760;
                final compactPhone = viewportWidth <= 520;

                List<MenuFlyoutItem> moreItems(BuildContext anchorContext) {
                  return [
                    if (onRemove != null)
                      MenuFlyoutItem(
                        key: 'remove-selected',
                        text: removeLabel ?? i18n.t('context.removeFromList'),
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
                          action.onPressedWithContext?.call(anchorContext) ??
                              action.onPressed();
                          if (action.hideAfterClick) {
                            hideIfNeeded();
                          }
                        },
                      ),
                    const MenuFlyoutItem.separator(key: 'command-separator'),
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
                  ];
                }

                return ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(17),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                    child: Container(
                      height: 64,
                      margin: EdgeInsets.zero,
                      padding: EdgeInsets.fromLTRB(
                        compactPhone
                            ? 12
                            : compactSelection
                            ? 18
                            : 26,
                        0,
                        compactPhone
                            ? 10
                            : compactSelection
                            ? 12
                            : 18,
                        0,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            CommandBarColors.multiSelectGradientTop,
                            CommandBarColors.multiSelectGradientBottom,
                          ],
                        ),
                        color: CommandBarColors.multiSelectSurface,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(17),
                        ),
                        border: Border.all(
                          color: CommandBarColors.multiSelectBorder,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: CommandBarColors.multiSelectShadow,
                            blurRadius: 44,
                            offset: Offset(0, -16),
                          ),
                          BoxShadow(
                            color: CommandBarColors.multiSelectInsetHighlight,
                            blurRadius: 0,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width:
                                compactPhone
                                    ? 96
                                    : compactSelection
                                    ? 112
                                    : 154,
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
                                              color:
                                                  CommandBarColors.accentStrong,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                    : const SizedBox.shrink(),
                          ),
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _MultiSelectAction(
                                      icon: FluentIcons.dismiss_20_regular,
                                      label: i18n.t('common.cancel'),
                                      hideLabel: compactPhone,
                                      onPressed: cancel,
                                    ),
                                    if (!compactPhone)
                                      const _MultiSelectSeparator(),
                                    if (showPlay && onPlay != null)
                                      _MultiSelectAction(
                                        icon: FluentIcons.play_20_regular,
                                        label: i18n.t('albums.playSelected'),
                                        disabled: !hasSelection,
                                        onPressed: () {
                                          onPlay?.call();
                                          hideIfNeeded();
                                        },
                                      ),
                                    if (showAddTo &&
                                        (onAddToPlaylist != null ||
                                            onAddToNowPlaying != null ||
                                            onToggleFavorite != null ||
                                            onCreatePlaylist != null))
                                      _MultiSelectAddToAction(
                                        enabled: hasSelection,
                                        compact: compactPhone,
                                        songIds: addToSongIds,
                                        defaultPlaylistName:
                                            defaultPlaylistName,
                                        playlists: playlists,
                                        includeNowPlaying:
                                            includeNowPlayingInAddTo,
                                        includeFavorites:
                                            includeFavoritesInAddTo,
                                        currentPlaylistName:
                                            currentPlaylistName,
                                        excludePlaylistName:
                                            excludePlaylistName,
                                        onAddToNowPlaying: onAddToNowPlaying,
                                        onToggleFavorite: onToggleFavorite,
                                        onCreatePlaylist: onCreatePlaylist,
                                        onAddToPlaylist: onAddToPlaylist,
                                        onMenuItemSelected: hideIfNeeded,
                                      ),
                                    if (!compactPhone && onRemove != null)
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
                                    if (!compactPhone)
                                      for (final action in extraActions)
                                        Builder(
                                          builder: (actionContext) {
                                            return _MultiSelectAction(
                                              icon: action.icon,
                                              label: action.text,
                                              disabled: action.disabled,
                                              onPressed: () {
                                                action.onPressedWithContext
                                                        ?.call(actionContext) ??
                                                    action.onPressed();
                                                if (action.hideAfterClick) {
                                                  hideIfNeeded();
                                                }
                                              },
                                            );
                                          },
                                        ),
                                    if (!compactSelection) ...[
                                      const _MultiSelectSeparator(),
                                      _MultiSelectAction(
                                        icon:
                                            FluentIcons
                                                .select_all_on_20_regular,
                                        label: i18n.t('albums.selectAll'),
                                        onPressed: onSelectAll,
                                      ),
                                      _MultiSelectAction(
                                        icon:
                                            FluentIcons
                                                .select_all_off_20_regular,
                                        label: i18n.t(
                                          'albums.reverseSelection',
                                        ),
                                        onPressed: onReverseSelection,
                                      ),
                                      _MultiSelectAction(
                                        icon:
                                            FluentIcons
                                                .dismiss_circle_20_regular,
                                        label: i18n.t('albums.clearSelection'),
                                        onPressed: onClearSelection,
                                      ),
                                    ],
                                    if (compactSelection)
                                      Builder(
                                        builder: (moreButtonContext) {
                                          return IconButton(
                                            tooltip: i18n.t('player.more'),
                                            icon:
                                                const SmPlayerMoreHorizontalIcon(
                                                  size: 16,
                                                ),
                                            style: _multiSelectMoreButtonStyle(
                                              compactPhone,
                                            ),
                                            onPressed: () {
                                              showMenuFlyout(
                                                moreButtonContext,
                                                position:
                                                    _menuFlyoutPositionAbove(
                                                      moreButtonContext,
                                                    ),
                                                items: moreItems(
                                                  moreButtonContext,
                                                ),
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
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class MultiSelectCommandBarExtraAction {
  const MultiSelectCommandBarExtraAction({
    required this.key,
    required this.text,
    required this.icon,
    required this.onPressed,
    this.onPressedWithContext,
    this.disabled = false,
    this.hideAfterClick = false,
  });

  final String key;
  final String text;
  final IconData icon;
  final VoidCallback onPressed;
  final FutureOr<void> Function(BuildContext context)? onPressedWithContext;
  final bool disabled;
  final bool hideAfterClick;
}

class _MultiSelectAction extends StatelessWidget {
  const _MultiSelectAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.disabled = false,
    this.hideLabel = false,
  });

  final IconData icon;
  final String label;
  final bool disabled;
  final bool hideLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? 0.46 : 1,
      child: TextButton.icon(
        style: TextButton.styleFrom(
          fixedSize: hideLabel ? const Size(40, 36) : null,
          minimumSize: Size(hideLabel ? 40 : 72, 36),
          maximumSize: hideLabel ? const Size(40, 36) : null,
          padding: EdgeInsets.symmetric(horizontal: hideLabel ? 10 : 12),
          foregroundColor: CommandBarColors.text,
          backgroundColor: CommandBarColors.actionSurface,
          disabledForegroundColor: CommandBarColors.text,
          disabledBackgroundColor: CommandBarColors.actionSurface,
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            height: 1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: CommandBarColors.actionBorder),
          ),
          elevation: 0,
          shadowColor: Colors.transparent,
        ),
        icon: Icon(icon, size: 16),
        label: hideLabel ? const SizedBox.shrink() : Text(label),
        onPressed: disabled ? null : onPressed,
      ),
    );
  }
}

ButtonStyle _multiSelectMoreButtonStyle(bool compactPhone) {
  return IconButton.styleFrom(
    fixedSize: Size(compactPhone ? 40 : 44, 36),
    minimumSize: Size(compactPhone ? 40 : 44, 36),
    padding: EdgeInsets.symmetric(horizontal: compactPhone ? 9 : 10),
    foregroundColor: CommandBarColors.text,
    backgroundColor: CommandBarColors.actionSurface,
    hoverColor: Colors.transparent,
    highlightColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: const BorderSide(color: CommandBarColors.actionBorder),
    ),
  );
}

class _MultiSelectAddToAction extends StatelessWidget {
  const _MultiSelectAddToAction({
    required this.enabled,
    required this.compact,
    required this.songIds,
    required this.defaultPlaylistName,
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
  final bool compact;
  final List<int> songIds;
  final String? defaultPlaylistName;
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
          hideLabel: compact,
          onPressed: () {
            final menuSongIds =
                songIds.isEmpty && enabled ? const [-1] : songIds;
            final addToItem = buildAddToPlaylistMenuFlyoutItem(
              i18n: i18n,
              songIds: menuSongIds,
              playlists: playlists,
              defaultPlaylistName: defaultPlaylistName,
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

            showMenuFlyout(
              buttonContext,
              position: _menuFlyoutPositionAbove(buttonContext),
              items: addToItem.submenu,
            );
          },
        );
      },
    );
  }
}

Offset _menuFlyoutPositionAbove(BuildContext context) {
  final box = context.findRenderObject() as RenderBox;
  return box.localToGlobal(Offset(0, -8));
}

class _MultiSelectSeparator extends StatelessWidget {
  const _MultiSelectSeparator();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 28,
      margin: const EdgeInsets.symmetric(horizontal: 9),
      color: CommandBarColors.separator,
    );
  }
}
