import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:smplayer_flutter/src/app/smplayer_vector_icons.dart';
import 'package:smplayer_flutter/src/app/text_icon_button.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/ui/command_bar_colors.dart';
import 'package:smplayer_flutter/src/library/ui/batch_song_properties_dialog.dart';
import 'package:smplayer_flutter/src/library/ui/menu_flyout.dart';
import 'package:smplayer_flutter/src/library/ui/menu_flyout_helpers.dart';

const multiSelectCommandBarScrollSpacer = 108.0;
const multiSelectCommandBarShellBottomInset = 17.0;
const multiSelectCommandBarHiddenSlideFraction = 16.0 / 64.0;
const multiSelectCommandBarLayoutAnimationDuration = Duration(
  milliseconds: 160,
);
const multiSelectCommandBarVisibilityAnimationDuration = Duration(
  milliseconds: 180,
);
const multiSelectCommandBarBackdropSaturation = 1.65;
const multiSelectCommandBarBackdropSaturationMatrix = <double>[
  1.51155,
  -0.46475,
  -0.0468,
  0,
  0,
  -0.13845,
  1.18525,
  -0.0468,
  0,
  0,
  -0.13845,
  -0.46475,
  1.6032,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
];
final multiSelectCommandBarBackdropFilter = ImageFilter.compose(
  outer: const ColorFilter.matrix(
    multiSelectCommandBarBackdropSaturationMatrix,
  ),
  inner: ImageFilter.blur(sigmaX: 46, sigmaY: 46),
);
const multiSelectCommandBarGlassOverlayOpacity = 0.08;

class MultiSelectCommandBar extends ConsumerWidget {
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
    this.nowPlayingSongIds = const [],
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
    this.addToMenuPosition = MultiSelectCommandBarAddToMenuPosition.aboveButton,
    this.extraActions = const [],
    this.hideAfterOperation = false,
    this.playlists = const [],
    this.bottomInset = 0,
    this.horizontalBleed = 0,
    this.leftBleed,
    this.rightBleed,
  });

  final bool visible;
  final int selectedCount;
  final bool showPlay;
  final bool showAddTo;
  final VoidCallback? onPlay;
  final List<int> addToSongIds;
  final List<int> nowPlayingSongIds;
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
  final MultiSelectCommandBarAddToMenuPosition addToMenuPosition;
  final List<MultiSelectCommandBarExtraAction> extraActions;
  final bool hideAfterOperation;
  final List<MultiSelectCommandBarPlaylist> playlists;
  final double bottomInset;
  final double horizontalBleed;
  final double? leftBleed;
  final double? rightBleed;
  final VoidCallback onSelectAll;
  final VoidCallback onReverseSelection;
  final VoidCallback onClearSelection;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    final resolvedExtraActions = [
      if (addToSongIds.isNotEmpty)
        MultiSelectCommandBarExtraAction(
          key: 'edit-song-info',
          text: i18n.t('song.batchEditAction'),
          icon: FluentIcons.edit_20_regular,
          hideAfterClick: false,
          onPressed: () {
            unawaited(() async {
              final changed = await showBatchSongPropertiesDialog(
                context: context,
                ref: ref,
                songIds: addToSongIds,
              );
              if (changed) {
                hideIfNeeded();
              }
            }());
          },
        ),
      ...extraActions,
    ];

    return ExcludeSemantics(
      excluding: !visible,
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedSlide(
          duration: multiSelectCommandBarVisibilityAnimationDuration,
          curve: Curves.ease,
          offset:
              visible
                  ? Offset.zero
                  : const Offset(0, multiSelectCommandBarHiddenSlideFraction),
          child: AnimatedOpacity(
            duration: multiSelectCommandBarVisibilityAnimationDuration,
            opacity: visible ? 1 : 0,
            child: AnimatedPadding(
              duration: multiSelectCommandBarLayoutAnimationDuration,
              curve: Curves.ease,
              padding: EdgeInsets.zero,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final hostWidth =
                        constraints.maxWidth.isFinite
                            ? constraints.maxWidth
                            : MediaQuery.sizeOf(context).width;
                    final resolvedLeftBleed = leftBleed ?? horizontalBleed;
                    final resolvedRightBleed = rightBleed ?? horizontalBleed;
                    final commandBarWidth =
                        hostWidth + resolvedLeftBleed + resolvedRightBleed;
                    final compactPhone = commandBarWidth <= 520;
                    final hasAddToTargets = _hasAddToTargets(
                      i18n: i18n,
                      songIds: addToSongIds,
                      nowPlayingSongIds: nowPlayingSongIds,
                      playlists: playlists,
                      includeNowPlaying: includeNowPlayingInAddTo,
                      includeFavorites: includeFavoritesInAddTo,
                      currentPlaylistName: currentPlaylistName,
                      excludePlaylistName: excludePlaylistName,
                      onAddToNowPlaying: onAddToNowPlaying,
                      onToggleFavorite: onToggleFavorite,
                      onCreatePlaylist: onCreatePlaylist,
                      onAddToPlaylist: onAddToPlaylist,
                    );
                    final fullActionWidths = <double>[
                      _multiSelectActionNaturalWidth(
                        context,
                        i18n.t('common.cancel'),
                      ),
                      1,
                      if (showPlay && onPlay != null)
                        _multiSelectActionNaturalWidth(
                          context,
                          i18n.t('albums.playSelected'),
                        ),
                      if (showAddTo && hasAddToTargets)
                        _multiSelectActionNaturalWidth(
                          context,
                          i18n.t('albums.addSelectedTo'),
                          minWidth: 92,
                          horizontalPadding: 9,
                        ),
                      if (onRemove != null)
                        _multiSelectActionNaturalWidth(
                          context,
                          removeLabel ?? i18n.t('context.removeFromList'),
                        ),
                      for (final action in resolvedExtraActions)
                        _multiSelectActionNaturalWidth(context, action.text),
                      1,
                      _multiSelectActionNaturalWidth(
                        context,
                        i18n.t('albums.selectAll'),
                      ),
                      _multiSelectActionNaturalWidth(
                        context,
                        i18n.t('albums.reverseSelection'),
                      ),
                      _multiSelectActionNaturalWidth(
                        context,
                        i18n.t('albums.clearSelection'),
                      ),
                    ];
                    final fullActionsFit =
                        _multiSelectActionsWidth(fullActionWidths, 9) <=
                        commandBarWidth - 26 - 18 - 154 - 18;
                    final compactSelection = !fullActionsFit;
                    final actionGap = compactPhone ? 6.0 : 8.0;
                    final actionAreaWidth =
                        commandBarWidth -
                        (compactPhone ? 10 + 12 + 96 + 8 : 12 + 18 + 112 + 12);
                    final compactCoreActionWidths = <double>[
                      compactPhone
                          ? 40
                          : _multiSelectActionNaturalWidth(
                            context,
                            i18n.t('common.cancel'),
                          ),
                      if (!compactPhone) 1,
                      if (showPlay && onPlay != null)
                        compactPhone
                            ? 88
                            : _multiSelectActionNaturalWidth(
                              context,
                              i18n.t('albums.playSelected'),
                            ),
                      if (showAddTo && hasAddToTargets)
                        compactPhone
                            ? 88
                            : _multiSelectActionNaturalWidth(
                              context,
                              i18n.t('albums.addSelectedTo'),
                              minWidth: 92,
                              horizontalPadding: 9,
                            ),
                      compactPhone ? 40 : 44,
                    ];
                    final supplementalActionWidths = <double>[
                      if (onRemove != null)
                        compactPhone
                            ? 40
                            : _multiSelectActionNaturalWidth(
                              context,
                              removeLabel ?? i18n.t('context.removeFromList'),
                            ),
                      for (final action in resolvedExtraActions)
                        compactPhone
                            ? 40
                            : _multiSelectActionNaturalWidth(
                              context,
                              action.text,
                            ),
                    ];
                    var visibleSupplementalActionCount =
                        compactSelection ? 0 : supplementalActionWidths.length;
                    if (compactSelection) {
                      var occupiedWidth = _multiSelectActionsWidth(
                        compactCoreActionWidths,
                        actionGap,
                      );
                      for (final width in supplementalActionWidths) {
                        final nextWidth = occupiedWidth + actionGap + width;
                        if (nextWidth > actionAreaWidth) {
                          break;
                        }
                        occupiedWidth = nextWidth;
                        visibleSupplementalActionCount += 1;
                      }
                    }
                    final visibleRemove =
                        onRemove != null && visibleSupplementalActionCount > 0;
                    final visibleExtraActionCount = math.max(
                      0,
                      visibleSupplementalActionCount -
                          (onRemove == null ? 0 : 1),
                    );
                    final visibleExtraActions = resolvedExtraActions.take(
                      visibleExtraActionCount,
                    );
                    final overflowedExtraActions = resolvedExtraActions.skip(
                      visibleExtraActionCount,
                    );
                    final removeOverflowed = onRemove != null && !visibleRemove;

                    List<MenuFlyoutItem> moreItems(BuildContext anchorContext) {
                      return [
                        if (removeOverflowed)
                          MenuFlyoutItem(
                            key: 'remove-selected',
                            text:
                                removeLabel ?? i18n.t('context.removeFromList'),
                            icon: FluentIcons.delete_20_regular,
                            disabled: !hasSelection,
                            onPressed: () {
                              onRemove?.call();
                              hideIfNeeded();
                            },
                          ),
                        for (final action in overflowedExtraActions)
                          MenuFlyoutItem(
                            key: action.key,
                            text: action.text,
                            icon: action.icon,
                            disabled: action.disabled,
                            onPressed: () {
                              action.onPressedWithContext?.call(
                                    anchorContext,
                                  ) ??
                                  action.onPressed();
                              if (action.hideAfterClick) {
                                hideIfNeeded();
                              }
                            },
                          ),
                        if (removeOverflowed ||
                            overflowedExtraActions.isNotEmpty)
                          const MenuFlyoutItem.separator(
                            key: 'command-separator',
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
                          icon: FluentIcons.broom_20_regular,
                          onPressed: onClearSelection,
                        ),
                      ];
                    }

                    final brightness = Theme.of(context).brightness;
                    final style = _MultiSelectCommandBarStyle.forBrightness(
                      brightness,
                    );
                    final resolvedActionGap =
                        compactSelection ? actionGap : 9.0;
                    final surfaceExtension = bottomInset;
                    final surfaceHeight = 64.0 + surfaceExtension;
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
                        minWidth: compactPhone ? 40 : 72,
                        style: style,
                        onPressed: cancel,
                      ),
                      if (!compactPhone)
                        _MultiSelectSeparator(
                          style: style,
                          height: compactSelection ? 26 : 28,
                        ),
                      if (showPlay && onPlay != null)
                        _MultiSelectAction(
                          icon: FluentIcons.play_20_regular,
                          label: i18n.t('albums.playSelected'),
                          disabled: !hasSelection,
                          minWidth: compactPhone ? 40 : 72,
                          maxWidth: compactPhone ? 88 : null,
                          style: style,
                          onPressed: () {
                            onPlay?.call();
                            hideIfNeeded();
                          },
                        ),
                      if (showAddTo && hasAddToTargets)
                        _MultiSelectAddToAction(
                          enabled: hasSelection,
                          compactSelection: compactSelection,
                          compactPhone: compactPhone,
                          style: style,
                          songIds: addToSongIds,
                          nowPlayingSongIds: nowPlayingSongIds,
                          defaultPlaylistName: defaultPlaylistName,
                          playlists: playlists,
                          includeNowPlaying: includeNowPlayingInAddTo,
                          includeFavorites: includeFavoritesInAddTo,
                          currentPlaylistName: currentPlaylistName,
                          excludePlaylistName: excludePlaylistName,
                          menuPosition: addToMenuPosition,
                          onAddToNowPlaying: onAddToNowPlaying,
                          onToggleFavorite: onToggleFavorite,
                          onCreatePlaylist: onCreatePlaylist,
                          onAddToPlaylist: onAddToPlaylist,
                          onMenuItemSelected: hideIfNeeded,
                        ),
                      if (visibleRemove)
                        _MultiSelectAction(
                          icon: FluentIcons.delete_20_regular,
                          label:
                              removeLabel ?? i18n.t('context.removeFromList'),
                          disabled: !hasSelection,
                          hideLabel: compactPhone,
                          minWidth: compactPhone ? 40 : 72,
                          maxWidth: compactPhone ? 40 : null,
                          style: style,
                          onPressed: () {
                            onRemove?.call();
                            hideIfNeeded();
                          },
                        ),
                      for (final action in visibleExtraActions)
                        Builder(
                          builder: (actionContext) {
                            return _MultiSelectAction(
                              icon: action.icon,
                              label: action.text,
                              disabled: action.disabled,
                              hideLabel: compactPhone,
                              minWidth: compactPhone ? 40 : 72,
                              maxWidth: compactPhone ? 40 : null,
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
                          preserveLabel: true,
                          style: style,
                          onPressed: onSelectAll,
                        ),
                        _MultiSelectAction(
                          icon: FluentIcons.select_all_off_20_regular,
                          label: i18n.t('albums.reverseSelection'),
                          preserveLabel: true,
                          style: style,
                          onPressed: onReverseSelection,
                        ),
                        _MultiSelectAction(
                          icon: FluentIcons.broom_20_regular,
                          label: i18n.t('albums.clearSelection'),
                          preserveLabel: true,
                          style: style,
                          onPressed: onClearSelection,
                        ),
                      ],
                      if (compactSelection)
                        Builder(
                          builder: (moreButtonContext) {
                            return _MultiSelectActionShadow(
                              style: style,
                              child: SmPlayerTextIconButtonTheme(
                                colors: _multiSelectTextIconButtonColors(style),
                                child: SmPlayerTextIconButton(
                                  key: const ValueKey(
                                    'MultiSelectCommandBar.MoreButton',
                                  ),
                                  label: i18n.t('player.more'),
                                  tooltip: i18n.t('player.more'),
                                  iconWidget:
                                      const SmPlayerMoreHorizontalIcon(),
                                  showLabel: false,
                                  minWidth: compactPhone ? 40 : 44,
                                  maxWidth: compactPhone ? 40 : 44,
                                  height: 36,
                                  horizontalPadding: compactPhone ? 9 : 10,
                                  iconSize: 16,
                                  opacityWhenDisabled: 1,
                                  onPressed: () {
                                    showMenuFlyout(
                                      moreButtonContext,
                                      position: _menuFlyoutPositionAbove(
                                        moreButtonContext,
                                      ),
                                      items: moreItems(moreButtonContext),
                                    );
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                    ];
                    final visibleActionWidths =
                        compactSelection
                            ? <double>[
                              ...compactCoreActionWidths.take(
                                compactCoreActionWidths.length - 1,
                              ),
                              ...supplementalActionWidths.take(
                                visibleSupplementalActionCount,
                              ),
                              compactCoreActionWidths.last,
                            ]
                            : fullActionWidths;
                    final resolvedActionAreaWidth =
                        compactSelection
                            ? actionAreaWidth
                            : commandBarWidth - 26 - 18 - 154 - 18;
                    final visibleActionsFit =
                        _multiSelectActionsWidth(
                          visibleActionWidths,
                          resolvedActionGap,
                        ) <=
                        resolvedActionAreaWidth;

                    final surface = DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(17),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: style.shadow,
                            blurRadius: 44,
                            offset: const Offset(0, -16),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(17),
                        ),
                        child: BackdropFilter(
                          filter: multiSelectCommandBarBackdropFilter,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Opacity(
                                opacity:
                                    multiSelectCommandBarGlassOverlayOpacity,
                                child: GlassContainer(
                                  key: const ValueKey(
                                    'MultiSelectCommandBar.Glass',
                                  ),
                                  useOwnLayer: true,
                                  quality: GlassQuality.minimal,
                                  clipBehavior: Clip.hardEdge,
                                  allowElevation: false,
                                  shape: const LiquidRoundedRectangle(
                                    borderRadius: 0,
                                  ),
                                  settings: LiquidGlassSettings(
                                    blur: 46,
                                    thickness: 20,
                                    refractiveIndex: 1.06,
                                    saturation:
                                        multiSelectCommandBarBackdropSaturation,
                                    chromaticAberration: 0,
                                    lightIntensity: 0.1,
                                    ambientStrength: 0.08,
                                    glowIntensity: 0.04,
                                    glassColor: style.surface,
                                    standardOpacityMultiplier: 0.24,
                                  ),
                                  child: const SizedBox.expand(),
                                ),
                              ),
                              CustomPaint(
                                foregroundPainter:
                                    _MultiSelectCommandBarBorderPainter(
                                      color: style.border,
                                    ),
                                child: Container(
                                  key: const ValueKey(
                                    'MultiSelectCommandBar.Surface',
                                  ),
                                  height: surfaceHeight,
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
                                    surfaceExtension,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: style.gradient,
                                    ),
                                    color: style.surface,
                                    boxShadow: [
                                      BoxShadow(
                                        color: style.insetHighlight,
                                        blurRadius: 0,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      ConstrainedBox(
                                        constraints: BoxConstraints(
                                          minWidth:
                                              compactPhone
                                                  ? 0
                                                  : compactSelection
                                                  ? 112
                                                  : 154,
                                          maxWidth:
                                              compactPhone
                                                  ? 96
                                                  : compactSelection
                                                  ? 112
                                                  : 154,
                                        ),
                                        child:
                                            hasSelection
                                                ? Row(
                                                  mainAxisSize:
                                                      compactPhone
                                                          ? MainAxisSize.min
                                                          : MainAxisSize.max,
                                                  children: [
                                                    Icon(
                                                      FluentIcons
                                                          .checkmark_20_regular,
                                                      size: 16,
                                                      color: style.accent,
                                                    ),
                                                    SizedBox(
                                                      width:
                                                          compactPhone ? 7 : 10,
                                                    ),
                                                    Flexible(
                                                      child: Text(
                                                        i18n.t(
                                                          'albums.selectedCount',
                                                          {
                                                            'count':
                                                                selectedCount,
                                                          },
                                                        ),
                                                        overflow:
                                                            TextOverflow
                                                                .ellipsis,
                                                        style: TextStyle(
                                                          color: style.accent,
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          fontVariations: const [
                                                            FontVariation.weight(
                                                              760,
                                                            ),
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
                                            mainAxisAlignment:
                                                MainAxisAlignment.end,
                                            children: _withGaps(
                                              actions,
                                              resolvedActionGap,
                                              flexible: !visibleActionsFit,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                    final resolvedSurface = Container(
                      width: commandBarWidth,
                      height: surfaceHeight,
                      transform: Matrix4.translationValues(
                        (resolvedRightBleed - resolvedLeftBleed) / 2,
                        0,
                        0,
                      ),
                      child: surface,
                    );
                    if (resolvedLeftBleed == 0 && resolvedRightBleed == 0) {
                      return resolvedSurface;
                    }
                    return OverflowBox(
                      alignment: Alignment.bottomCenter,
                      minWidth: commandBarWidth,
                      maxWidth: commandBarWidth,
                      minHeight: surfaceHeight,
                      maxHeight: surfaceHeight,
                      child: resolvedSurface,
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum MultiSelectCommandBarAddToMenuPosition { aboveButton, pointer }

bool _hasAddToTargets({
  required SmPlayerI18n i18n,
  required List<int> songIds,
  required List<int> nowPlayingSongIds,
  required List<MultiSelectCommandBarPlaylist> playlists,
  required bool includeNowPlaying,
  required bool includeFavorites,
  required String? currentPlaylistName,
  required String? excludePlaylistName,
  required VoidCallback? onAddToNowPlaying,
  required VoidCallback? onToggleFavorite,
  required VoidCallback? onCreatePlaylist,
  required ValueChanged<int>? onAddToPlaylist,
}) {
  if (includeNowPlaying &&
      onAddToNowPlaying != null &&
      shouldShowNowPlayingAddToTarget(
        songIds: songIds,
        nowPlayingSongIds: nowPlayingSongIds,
        isNowPlayingContext: currentPlaylistName == i18n.t('common.nowPlaying'),
      )) {
    return true;
  }
  if (includeFavorites && onToggleFavorite != null) {
    return true;
  }
  if (onCreatePlaylist != null) {
    return true;
  }
  if (onAddToPlaylist == null) {
    return false;
  }
  return playlists.any((playlist) {
    if (playlist.name == (excludePlaylistName ?? currentPlaylistName)) {
      return false;
    }
    if (songIds.length != 1) {
      return true;
    }
    return !playlist.songIds.contains(songIds.first);
  });
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
    this.minWidth = 72,
    this.maxWidth,
    this.preserveLabel = false,
    this.horizontalPadding = 12,
  });

  final IconData icon;
  final String label;
  final bool disabled;
  final bool hideLabel;
  final double minWidth;
  final double? maxWidth;
  final bool preserveLabel;
  final double horizontalPadding;
  final _MultiSelectCommandBarStyle style;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final showLabel = !hideLabel;
    return Opacity(
      opacity: disabled ? 0.46 : 1,
      child: _MultiSelectActionShadow(
        style: style,
        disabled: disabled,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final canShowLabel = showLabel && constraints.maxWidth >= 40;
            final resolvedMaxWidth =
                canShowLabel ? maxWidth ?? double.infinity : 40.0;
            final controlWidthLimit = math.min(
              constraints.maxWidth,
              resolvedMaxWidth,
            );
            final reservedWidth = horizontalPadding * 2 + 16 + 7;
            final labelPainter = TextPainter(
              text: TextSpan(
                text: label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontVariations: [FontVariation.weight(640)],
                ),
              ),
              maxLines: 1,
              textDirection: Directionality.of(context),
              textScaler: MediaQuery.textScalerOf(context),
              locale: Localizations.maybeLocaleOf(context),
            )..layout();
            final labelTruncated =
                canShowLabel &&
                controlWidthLimit.isFinite &&
                labelPainter.width >
                    math.max(0, controlWidthLimit - reservedWidth);
            return SmPlayerTextIconButtonTheme(
              colors: _multiSelectTextIconButtonColors(style),
              child: SmPlayerTextIconButton(
                label: label,
                tooltip: labelTruncated ? label : null,
                iconWidget: _multiSelectActionIcon(icon),
                showLabel: canShowLabel,
                disabled: disabled,
                onPressed: onPressed,
                minWidth: canShowLabel ? minWidth : 40,
                maxWidth: hideLabel ? 40 : resolvedMaxWidth,
                height: 36,
                horizontalPadding: canShowLabel ? horizontalPadding : 0,
                iconSize: 16,
                iconGap: 7,
                opacityWhenDisabled: 1,
                borderRadius: 8,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontVariations: const [FontVariation.weight(640)],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MultiSelectActionShadow extends StatefulWidget {
  const _MultiSelectActionShadow({
    required this.style,
    required this.child,
    this.disabled = false,
  });

  final _MultiSelectCommandBarStyle style;
  final Widget child;
  final bool disabled;

  @override
  State<_MultiSelectActionShadow> createState() =>
      _MultiSelectActionShadowState();
}

class _MultiSelectActionShadowState extends State<_MultiSelectActionShadow> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final shadow =
        widget.disabled
            ? widget.style.actionDisabledShadow
            : _hovered
            ? widget.style.actionHoverShadow
            : widget.style.actionShadow;

    return MouseRegion(
      onEnter: (_) {
        if (!_hovered) {
          setState(() {
            _hovered = true;
          });
        }
      },
      onExit: (_) {
        if (_hovered) {
          setState(() {
            _hovered = false;
          });
        }
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          boxShadow: shadow,
        ),
        child: widget.child,
      ),
    );
  }
}

SmPlayerTextIconButtonColors _multiSelectTextIconButtonColors(
  _MultiSelectCommandBarStyle style,
) {
  return SmPlayerTextIconButtonColors(
    commandText: style.actionForeground,
    commandTextHover: style.actionHoverForeground,
    control: style.actionSurface,
    controlHover: style.actionHoverSurface,
    controlHoverBorder: style.actionHoverBorder,
    controlActive: style.actionHoverSurface,
    controlBorder: style.actionBorder,
    accentStrong: style.accent,
  );
}

class _MultiSelectAddToAction extends StatefulWidget {
  const _MultiSelectAddToAction({
    required this.enabled,
    required this.compactSelection,
    required this.compactPhone,
    required this.style,
    required this.songIds,
    required this.nowPlayingSongIds,
    required this.defaultPlaylistName,
    required this.playlists,
    required this.includeNowPlaying,
    required this.includeFavorites,
    required this.currentPlaylistName,
    required this.excludePlaylistName,
    required this.menuPosition,
    required this.onAddToNowPlaying,
    required this.onToggleFavorite,
    required this.onCreatePlaylist,
    required this.onAddToPlaylist,
    required this.onMenuItemSelected,
  });

  final bool enabled;
  final bool compactSelection;
  final bool compactPhone;
  final _MultiSelectCommandBarStyle style;
  final List<int> songIds;
  final List<int> nowPlayingSongIds;
  final String? defaultPlaylistName;
  final List<MultiSelectCommandBarPlaylist> playlists;
  final bool includeNowPlaying;
  final bool includeFavorites;
  final String? currentPlaylistName;
  final String? excludePlaylistName;
  final MultiSelectCommandBarAddToMenuPosition menuPosition;
  final VoidCallback? onAddToNowPlaying;
  final VoidCallback? onToggleFavorite;
  final VoidCallback? onCreatePlaylist;
  final ValueChanged<int>? onAddToPlaylist;
  final VoidCallback onMenuItemSelected;

  @override
  State<_MultiSelectAddToAction> createState() =>
      _MultiSelectAddToActionState();
}

class _MultiSelectAddToActionState extends State<_MultiSelectAddToAction> {
  Offset? _lastPointerDownPosition;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;

    return Builder(
      builder: (buttonContext) {
        return Listener(
          onPointerDown: (event) {
            _lastPointerDownPosition = event.position;
          },
          child: _MultiSelectAction(
            icon: FluentIcons.add_20_regular,
            label: i18n.t('albums.addSelectedTo'),
            disabled: !widget.enabled,
            minWidth: widget.compactPhone ? 40 : 92,
            maxWidth: widget.compactPhone ? 88 : null,
            preserveLabel: !widget.compactSelection,
            horizontalPadding: widget.compactPhone ? 12 : 9,
            style: widget.style,
            onPressed: () {
              final menuSongIds =
                  widget.songIds.isEmpty && widget.enabled
                      ? const [-1]
                      : widget.songIds;
              final addToItem = buildAddToPlaylistMenuFlyoutItem(
                i18n: i18n,
                songIds: menuSongIds,
                playlists: widget.playlists,
                defaultPlaylistName: widget.defaultPlaylistName,
                currentPlaylistName: widget.currentPlaylistName,
                excludePlaylistName: widget.excludePlaylistName,
                includeNowPlaying:
                    widget.includeNowPlaying &&
                    shouldShowNowPlayingAddToTarget(
                      songIds: menuSongIds,
                      nowPlayingSongIds: widget.nowPlayingSongIds,
                      isNowPlayingContext:
                          widget.currentPlaylistName ==
                          i18n.t('common.nowPlaying'),
                    ),
                includeFavorites: widget.includeFavorites,
                onAddToNowPlaying:
                    widget.onAddToNowPlaying == null
                        ? null
                        : () {
                          widget.onAddToNowPlaying?.call();
                          widget.onMenuItemSelected();
                        },
                onToggleFavorite:
                    widget.onToggleFavorite == null
                        ? null
                        : () {
                          widget.onToggleFavorite?.call();
                          widget.onMenuItemSelected();
                        },
                onCreatePlaylist:
                    widget.onCreatePlaylist == null
                        ? null
                        : () {
                          widget.onCreatePlaylist?.call();
                          widget.onMenuItemSelected();
                        },
                onAddToPlaylist: (playlistId) {
                  widget.onAddToPlaylist?.call(playlistId);
                  widget.onMenuItemSelected();
                },
              );
              if (addToItem == null) {
                return;
              }

              showMenuFlyout(
                buttonContext,
                position: _addToMenuFlyoutPosition(buttonContext),
                items: addToItem.submenu,
              );
            },
          ),
        );
      },
    );
  }

  Offset _addToMenuFlyoutPosition(BuildContext buttonContext) {
    if (widget.menuPosition == MultiSelectCommandBarAddToMenuPosition.pointer) {
      final pointerPosition = _lastPointerDownPosition;
      _lastPointerDownPosition = null;
      return pointerPosition ?? _menuFlyoutPositionAbove(buttonContext);
    }
    return _menuFlyoutPositionAbove(buttonContext);
  }
}

Offset _menuFlyoutPositionAbove(BuildContext context) {
  final box = context.findRenderObject() as RenderBox;
  return box.localToGlobal(Offset(0, -8));
}

Widget _multiSelectActionIcon(IconData icon) {
  return SizedBox.square(
    dimension: 16,
    child: Center(child: Icon(icon, size: 16)),
  );
}

class _MultiSelectSeparator extends StatelessWidget {
  const _MultiSelectSeparator({required this.style, this.height = 28});

  final _MultiSelectCommandBarStyle style;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: height, color: style.separator);
  }
}

double _multiSelectActionNaturalWidth(
  BuildContext context,
  String label, {
  double minWidth = 72,
  double horizontalPadding = 12,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        fontVariations: [FontVariation.weight(640)],
      ),
    ),
    maxLines: 1,
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    locale: Localizations.maybeLocaleOf(context),
  )..layout();
  return math.max(minWidth, horizontalPadding * 2 + 16 + 7 + painter.width);
}

double _multiSelectActionsWidth(List<double> widths, double gap) {
  return widths.reduce((sum, width) => sum + width) + gap * (widths.length - 1);
}

List<Widget> _withGaps(
  List<Widget> children,
  double gap, {
  required bool flexible,
}) {
  if (children.length < 2) {
    return children;
  }
  return [
    for (var index = 0; index < children.length; index += 1) ...[
      if (index > 0) SizedBox(width: gap),
      flexible ? _flexibleActionChild(children[index]) : children[index],
    ],
  ];
}

Widget _flexibleActionChild(Widget child) {
  if (child is _MultiSelectSeparator) {
    return child;
  }
  if (child is _MultiSelectAction && child.preserveLabel) {
    return child;
  }
  if (child is _MultiSelectAddToAction && !child.compactSelection) {
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
    required this.actionShadow,
    required this.actionHoverShadow,
    required this.actionDisabledShadow,
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
  final List<BoxShadow> actionShadow;
  final List<BoxShadow> actionHoverShadow;
  final List<BoxShadow> actionDisabledShadow;
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
    actionShadow: [
      BoxShadow(color: Color(0x0d182230), blurRadius: 2, offset: Offset(0, 1)),
      BoxShadow(color: Color(0xb3ffffff), blurRadius: 0, offset: Offset(0, 1)),
    ],
    actionHoverShadow: [
      BoxShadow(color: Color(0x1a3a5376), blurRadius: 10, offset: Offset(0, 3)),
      BoxShadow(color: Color(0xc7ffffff), blurRadius: 0, offset: Offset(0, 1)),
    ],
    actionDisabledShadow: [
      BoxShadow(color: Color(0x9effffff), blurRadius: 0, offset: Offset(0, 1)),
    ],
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
    actionShadow: [
      BoxShadow(color: Color(0x0effffff), blurRadius: 0, offset: Offset(0, 1)),
    ],
    actionHoverShadow: [],
    actionDisabledShadow: [
      BoxShadow(color: Color(0x0effffff), blurRadius: 0, offset: Offset(0, 1)),
    ],
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
