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
        duration: visible ? const Duration(milliseconds: 180) : Duration.zero,
        curve: Curves.easeOutCubic,
        offset: visible ? Offset.zero : const Offset(0, 1.1),
        child: AnimatedOpacity(
          duration: visible ? const Duration(milliseconds: 120) : Duration.zero,
          opacity: visible ? 1 : 0,
          child: Offstage(
            offstage: !visible,
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

                  final brightness = Theme.of(context).brightness;
                  final style = _MultiSelectCommandBarStyle.forBrightness(
                    brightness,
                  );
                  final actionGap =
                      compactPhone
                          ? 6.0
                          : compactSelection
                          ? 8.0
                          : 9.0;
                  final contentGap =
                      compactPhone
                          ? 8.0
                          : compactSelection
                          ? 12.0
                          : 18.0;
                  final actions = <Widget>[
                    _MultiSelectAction(
                      icon: FluentIcons.dismiss_20_regular,
                      label: i18n.t('common.cancel'),
                      hideLabel: compactPhone,
                      style: style,
                      onPressed: cancel,
                    ),
                    if (!compactPhone) _MultiSelectSeparator(style: style),
                    if (showPlay && onPlay != null)
                      _MultiSelectAction(
                        icon: FluentIcons.play_20_regular,
                        label: i18n.t('albums.playSelected'),
                        disabled: !hasSelection,
                        style: style,
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
                        compactPhone: compactPhone,
                        style: style,
                        songIds: addToSongIds,
                        defaultPlaylistName: defaultPlaylistName,
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
                    if (!compactPhone && onRemove != null)
                      _MultiSelectAction(
                        icon: FluentIcons.delete_20_regular,
                        label: removeLabel ?? i18n.t('context.removeFromList'),
                        disabled: !hasSelection,
                        style: style,
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
                              style: style,
                              onPressed: () {
                                action.onPressedWithContext?.call(
                                      actionContext,
                                    ) ??
                                    action.onPressed();
                                if (action.hideAfterClick) {
                                  hideIfNeeded();
                                }
                              },
                            );
                          },
                        ),
                    if (!compactSelection) ...[
                      _MultiSelectSeparator(style: style),
                      _MultiSelectAction(
                        icon: FluentIcons.select_all_on_20_regular,
                        label: i18n.t('albums.selectAll'),
                        style: style,
                        onPressed: onSelectAll,
                      ),
                      _MultiSelectAction(
                        icon: FluentIcons.select_all_off_20_regular,
                        label: i18n.t('albums.reverseSelection'),
                        style: style,
                        onPressed: onReverseSelection,
                      ),
                      _MultiSelectAction(
                        icon: FluentIcons.dismiss_circle_20_regular,
                        label: i18n.t('albums.clearSelection'),
                        style: style,
                        onPressed: onClearSelection,
                      ),
                    ],
                    if (compactSelection)
                      Builder(
                        builder: (moreButtonContext) {
                          return IconButton(
                            key: const ValueKey(
                              'MultiSelectCommandBar.MoreButton',
                            ),
                            tooltip: i18n.t('player.more'),
                            icon: const SmPlayerMoreHorizontalIcon(size: 16),
                            style: _multiSelectMoreButtonStyle(
                              compactPhone,
                              style,
                            ),
                            onPressed: () {
                              showMenuFlyout(
                                moreButtonContext,
                                position: _menuFlyoutPositionAbove(
                                  moreButtonContext,
                                ),
                                items: moreItems(moreButtonContext),
                              );
                            },
                          );
                        },
                      ),
                  ];

                  return ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(17),
                    ),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                      child: CustomPaint(
                        foregroundPainter: _MultiSelectCommandBarBorderPainter(
                          color: style.border,
                        ),
                        child: Container(
                          key: const ValueKey('MultiSelectCommandBar.Surface'),
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
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: style.gradient,
                            ),
                            color: style.surface,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(17),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: style.shadow,
                                blurRadius: 44,
                                offset: const Offset(0, -16),
                              ),
                              BoxShadow(
                                color: style.insetHighlight,
                                blurRadius: 0,
                                offset: const Offset(0, 1),
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
                                            Icon(
                                              FluentIcons.checkmark_20_regular,
                                              size: 16,
                                              color: style.accent,
                                            ),
                                            const SizedBox(width: 10),
                                            Flexible(
                                              child: Text(
                                                i18n.t('albums.selectedCount', {
                                                  'count': selectedCount,
                                                }),
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: style.accent,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700,
                                                  fontVariations: const [
                                                    FontVariation.weight(760),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        )
                                        : const SizedBox.shrink(),
                              ),
                              SizedBox(width: contentGap),
                              Expanded(
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: _withGaps(actions, actionGap),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
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
    required this.style,
    this.disabled = false,
    this.hideLabel = false,
    this.maxWidth,
    this.trailingIcon,
  });

  final IconData icon;
  final String label;
  final bool disabled;
  final bool hideLabel;
  final double? maxWidth;
  final IconData? trailingIcon;
  final _MultiSelectCommandBarStyle style;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final showLabel = !hideLabel;
    final fixedSize = hideLabel ? const Size(40, 36) : null;
    final minimumSize = Size(hideLabel ? 40 : 72, 36);
    final maximumSize =
        hideLabel
            ? const Size(40, 36)
            : maxWidth == null
            ? const Size(double.infinity, 36)
            : Size(maxWidth!, 36);

    return Opacity(
      opacity: disabled ? 0.46 : 1,
      child: TextButton(
        style: _multiSelectActionStyle(
          style,
          fixedSize: fixedSize,
          minimumSize: minimumSize,
          maximumSize: maximumSize,
          horizontalPadding: hideLabel ? 10 : 12,
        ),
        onPressed: disabled ? null : onPressed,
        child: DefaultTextStyle.merge(
          style: _multiSelectActionTextStyle,
          child: IconTheme.merge(
            data: const IconThemeData(size: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon),
                if (showLabel) ...[
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      softWrap: false,
                    ),
                  ),
                ],
                if (trailingIcon != null) ...[
                  const SizedBox(width: 7),
                  Icon(trailingIcon),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

const _multiSelectActionTextStyle = TextStyle(
  fontSize: 13,
  fontWeight: FontWeight.w600,
  fontVariations: [FontVariation.weight(640)],
  height: 1,
);

ButtonStyle _multiSelectActionStyle(
  _MultiSelectCommandBarStyle style, {
  required Size? fixedSize,
  required Size minimumSize,
  required Size maximumSize,
  required double horizontalPadding,
}) {
  return ButtonStyle(
    fixedSize: WidgetStatePropertyAll(fixedSize),
    minimumSize: WidgetStatePropertyAll(minimumSize),
    maximumSize: WidgetStatePropertyAll(maximumSize),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    visualDensity: VisualDensity.standard,
    padding: WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: horizontalPadding),
    ),
    foregroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.hovered) ||
          states.contains(WidgetState.focused)) {
        return style.actionHoverForeground;
      }
      return style.actionForeground;
    }),
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.hovered) ||
          states.contains(WidgetState.focused)) {
        return style.actionHoverSurface;
      }
      return style.actionSurface;
    }),
    side: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.hovered) ||
          states.contains(WidgetState.focused)) {
        return BorderSide(color: style.actionHoverBorder);
      }
      return BorderSide(color: style.actionBorder);
    }),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    elevation: const WidgetStatePropertyAll(0),
    shadowColor: const WidgetStatePropertyAll(Colors.transparent),
    surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
    overlayColor: const WidgetStatePropertyAll(Colors.transparent),
    splashFactory: NoSplash.splashFactory,
    animationDuration: Duration.zero,
    textStyle: const WidgetStatePropertyAll(_multiSelectActionTextStyle),
  );
}

ButtonStyle _multiSelectMoreButtonStyle(
  bool compactPhone,
  _MultiSelectCommandBarStyle style,
) {
  return _multiSelectActionStyle(
    style,
    fixedSize: Size(compactPhone ? 40 : 44, 36),
    minimumSize: Size(compactPhone ? 40 : 44, 36),
    maximumSize: Size(compactPhone ? 40 : 44, 36),
    horizontalPadding: compactPhone ? 9 : 10,
  );
}

class _MultiSelectAddToAction extends StatelessWidget {
  const _MultiSelectAddToAction({
    required this.enabled,
    required this.compactPhone,
    required this.style,
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
  final bool compactPhone;
  final _MultiSelectCommandBarStyle style;
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
          maxWidth: compactPhone ? 88 : null,
          trailingIcon:
              compactPhone ? null : FluentIcons.chevron_down_20_regular,
          style: style,
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
  const _MultiSelectSeparator({required this.style});

  final _MultiSelectCommandBarStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 28, color: style.separator);
  }
}

List<Widget> _withGaps(List<Widget> children, double gap) {
  if (children.length < 2) {
    return children;
  }
  return [
    for (var index = 0; index < children.length; index += 1) ...[
      if (index > 0) SizedBox(width: gap),
      _flexibleActionChild(children[index]),
    ],
  ];
}

Widget _flexibleActionChild(Widget child) {
  if (child is _MultiSelectSeparator) {
    return child;
  }
  return Flexible(fit: FlexFit.loose, child: child);
}

class _MultiSelectCommandBarStyle {
  const _MultiSelectCommandBarStyle({
    required this.surface,
    required this.gradient,
    required this.border,
    required this.insetHighlight,
    required this.shadow,
    required this.separator,
    required this.actionSurface,
    required this.actionHoverSurface,
    required this.actionBorder,
    required this.actionHoverBorder,
    required this.actionForeground,
    required this.actionHoverForeground,
    required this.accent,
  });

  final Color surface;
  final List<Color> gradient;
  final Color border;
  final Color insetHighlight;
  final Color shadow;
  final Color separator;
  final Color actionSurface;
  final Color actionHoverSurface;
  final Color actionBorder;
  final Color actionHoverBorder;
  final Color actionForeground;
  final Color actionHoverForeground;
  final Color accent;

  static const day = _MultiSelectCommandBarStyle(
    surface: CommandBarColors.multiSelectSurface,
    gradient: [
      CommandBarColors.multiSelectGradientTop,
      CommandBarColors.multiSelectGradientBottom,
    ],
    border: CommandBarColors.multiSelectBorder,
    insetHighlight: CommandBarColors.multiSelectInsetHighlight,
    shadow: CommandBarColors.multiSelectShadow,
    separator: CommandBarColors.separator,
    actionSurface: CommandBarColors.actionSurface,
    actionHoverSurface: CommandBarColors.actionHoverSurface,
    actionBorder: CommandBarColors.actionBorder,
    actionHoverBorder: CommandBarColors.actionHoverBorder,
    actionForeground: CommandBarColors.textStrong,
    actionHoverForeground: CommandBarColors.accentStrong,
    accent: CommandBarColors.accentStrong,
  );

  static const night = _MultiSelectCommandBarStyle(
    surface: CommandBarColors.multiSelectNightSurface,
    gradient: [
      CommandBarColors.multiSelectNightGradientTop,
      CommandBarColors.multiSelectNightGradientBottom,
    ],
    border: CommandBarColors.multiSelectNightBorder,
    insetHighlight: CommandBarColors.multiSelectNightInsetHighlight,
    shadow: CommandBarColors.multiSelectNightShadow,
    separator: CommandBarColors.separatorNight,
    actionSurface: CommandBarColors.actionNightSurface,
    actionHoverSurface: CommandBarColors.actionNightHoverSurface,
    actionBorder: CommandBarColors.actionNightBorder,
    actionHoverBorder: CommandBarColors.actionNightHoverBorder,
    actionForeground: CommandBarColors.textNight,
    actionHoverForeground: CommandBarColors.accentStrongNight,
    accent: CommandBarColors.accentStrongNight,
  );

  static _MultiSelectCommandBarStyle forBrightness(Brightness brightness) {
    return brightness == Brightness.dark ? night : day;
  }
}

class _MultiSelectCommandBarBorderPainter extends CustomPainter {
  const _MultiSelectCommandBarBorderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;
    final path =
        Path()
          ..moveTo(0.5, size.height)
          ..lineTo(0.5, 17)
          ..quadraticBezierTo(0.5, 0.5, 17, 0.5)
          ..lineTo(size.width - 17, 0.5)
          ..quadraticBezierTo(size.width - 0.5, 0.5, size.width - 0.5, 17)
          ..lineTo(size.width - 0.5, size.height);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(
    covariant _MultiSelectCommandBarBorderPainter oldDelegate,
  ) {
    return oldDelegate.color != color;
  }
}
