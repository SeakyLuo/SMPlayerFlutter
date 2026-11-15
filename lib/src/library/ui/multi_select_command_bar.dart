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

part 'multi_select_command_bar_actions.dart';
part 'multi_select_command_bar_styles.dart';

enum MultiSelectCommandBarDensity { standard, comfortable }

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
    this.loading = false,
    this.enabled = true,
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
    this.density = MultiSelectCommandBarDensity.standard,
  });

  final bool loading;
  final bool enabled;
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
  final FutureOr<void> Function()? onAddToNowPlaying;
  final FutureOr<void> Function()? onToggleFavorite;
  final FutureOr<void> Function()? onCreatePlaylist;
  final FutureOr<void> Function(int)? onAddToPlaylist;
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
  final MultiSelectCommandBarDensity density;
  final VoidCallback onSelectAll;
  final VoidCallback onReverseSelection;
  final VoidCallback onClearSelection;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final i18n = context.smPlayerI18n;
    final hasSelection = selectedCount > 0 && !loading && enabled;

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
                    final comfortable =
                        density == MultiSelectCommandBarDensity.comfortable;
                    final compactActionSize = comfortable ? 44.0 : 40.0;
                    final compactWideActionWidth = comfortable ? 92.0 : 88.0;
                    final actionHeight = comfortable ? 42.0 : 36.0;
                    final actionIconSize = comfortable ? 18.0 : 16.0;
                    final hostWidth =
                        constraints.maxWidth.isFinite
                            ? constraints.maxWidth
                            : MediaQuery.sizeOf(context).width;
                    final resolvedLeftBleed = leftBleed ?? horizontalBleed;
                    final resolvedRightBleed = rightBleed ?? horizontalBleed;
                    final commandBarWidth =
                        hostWidth + resolvedLeftBleed + resolvedRightBleed;
                    final contentWidth = commandBarWidth - resolvedRightBleed;
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
                        contentWidth - 26 - 18 - 154 - 18;
                    final compactSelection = !fullActionsFit;
                    final actionGap = compactPhone ? 6.0 : 8.0;
                    final actionAreaWidth =
                        contentWidth -
                        (compactPhone ? 10 + 12 + 96 + 8 : 12 + 18 + 112 + 12);
                    final compactCoreActionWidths = <double>[
                      compactPhone
                          ? compactActionSize
                          : _multiSelectActionNaturalWidth(
                            context,
                            i18n.t('common.cancel'),
                          ),
                      if (!compactPhone) 1,
                      if (showPlay && onPlay != null)
                        compactPhone
                            ? compactWideActionWidth
                            : _multiSelectActionNaturalWidth(
                              context,
                              i18n.t('albums.playSelected'),
                            ),
                      if (showAddTo && hasAddToTargets)
                        compactPhone
                            ? compactWideActionWidth
                            : _multiSelectActionNaturalWidth(
                              context,
                              i18n.t('albums.addSelectedTo'),
                              minWidth: 92,
                              horizontalPadding: 9,
                            ),
                      compactPhone ? compactActionSize : 44,
                    ];
                    final supplementalActionWidths = <double>[
                      if (onRemove != null)
                        compactPhone
                            ? compactActionSize
                            : _multiSelectActionNaturalWidth(
                              context,
                              removeLabel ?? i18n.t('context.removeFromList'),
                            ),
                      for (final action in resolvedExtraActions)
                        compactPhone
                            ? compactActionSize
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
                    final surfaceHeight =
                        (comfortable ? 72.0 : 64.0) + surfaceExtension;
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
                        minWidth: compactPhone ? compactActionSize : 72,
                        actionHeight: actionHeight,
                        iconSize: actionIconSize,
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
                          minWidth: compactPhone ? compactActionSize : 72,
                          maxWidth:
                              compactPhone ? compactWideActionWidth : null,
                          actionHeight: actionHeight,
                          iconSize: actionIconSize,
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
                          compactActionSize: compactActionSize,
                          compactWideActionWidth: compactWideActionWidth,
                          actionHeight: actionHeight,
                          iconSize: actionIconSize,
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
                          minWidth: compactPhone ? compactActionSize : 72,
                          maxWidth: compactPhone ? compactActionSize : null,
                          actionHeight: actionHeight,
                          iconSize: actionIconSize,
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
                              minWidth: compactPhone ? compactActionSize : 72,
                              maxWidth: compactPhone ? compactActionSize : null,
                              actionHeight: actionHeight,
                              iconSize: actionIconSize,
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
                                  minWidth:
                                      compactPhone ? compactActionSize : 44,
                                  maxWidth:
                                      compactPhone ? compactActionSize : 44,
                                  height: actionHeight,
                                  horizontalPadding: compactPhone ? 9 : 10,
                                  iconSize: actionIconSize,
                                  opacityWhenDisabled: 1,
                                  onPressed: () {
                                    showMenuFlyout(
                                      moreButtonContext,
                                      anchorPlacement:
                                          MenuFlyoutAnchorPlacement.above,
                                      anchorAlignment:
                                          MenuFlyoutAnchorAlignment.end,
                                      avoidPlayerBar: false,
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
                            : contentWidth - 26 - 18 - 154 - 18;
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
                                    resolvedRightBleed +
                                        (compactPhone
                                            ? 10
                                            : compactSelection
                                            ? 12
                                            : 18),
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
                                            selectedCount > 0
                                                ? Row(
                                                  mainAxisSize:
                                                      compactPhone
                                                          ? MainAxisSize.min
                                                          : MainAxisSize.max,
                                                  children: [
                                                    if (loading)
                                                      const SizedBox.square(
                                                        dimension: 16,
                                                        child:
                                                            CircularProgressIndicator(
                                                              strokeWidth: 2,
                                                            ),
                                                      )
                                                    else
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
