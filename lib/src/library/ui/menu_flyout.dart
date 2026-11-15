import 'dart:async';
import '../../app/undoable_notification.dart';
import '../../i18n/app_i18n.dart';
import '../../remote/music_share_models.dart';
import 'dart:math' as math;

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:smplayer_flutter/src/app/app_interaction_colors.dart';
import 'package:smplayer_flutter/src/app/exit_fullscreen_icon.dart';
import 'package:smplayer_flutter/src/app/smplayer_vector_icons.dart';
import 'package:smplayer_flutter/src/app/touch_context_menu.dart';
import 'package:smplayer_flutter/src/app/uniform_multi_select_icon.dart';

part 'menu_flyout_panel.dart';
part 'menu_flyout_item.dart';
part 'menu_flyout_theme.dart';

class MenuFlyoutItem {
  const MenuFlyoutItem({
    required this.key,
    required this.text,
    this.pendingText,
    this.icon,
    this.iconWidget,
    this.iconColor,
    this.useAlbumIcon = false,
    this.usePlaylistIcon = false,
    this.usePlayNextIcon = false,
    this.useShuffleIcon = false,
    this.useFullscreenIcon = false,
    this.useExitFullscreenIcon = false,
    this.disabled = false,
    this.checked = false,
    this.tooltip,
    this.submenu = const [],
    this.loadSubmenu,
    this.onPressed,
    this.onPressedWithContext,
    this.onSecondaryTapDown,
    this.onWillAcceptDrop,
    this.onAcceptDrop,
    this.content,
    this.contentHeight = 42,
    this.keepOpen = false,
  }) : separator = false;

  const MenuFlyoutItem.separator({required this.key})
    : text = '',
      pendingText = null,
      icon = null,
      iconWidget = null,
      iconColor = null,
      useAlbumIcon = false,
      usePlaylistIcon = false,
      usePlayNextIcon = false,
      useShuffleIcon = false,
      useFullscreenIcon = false,
      useExitFullscreenIcon = false,
      disabled = false,
      checked = false,
      tooltip = null,
      submenu = const [],
      loadSubmenu = null,
      onPressed = null,
      onPressedWithContext = null,
      onSecondaryTapDown = null,
      onWillAcceptDrop = null,
      onAcceptDrop = null,
      content = null,
      contentHeight = 42,
      keepOpen = false,
      separator = true;

  final String key;
  final String text;
  final String? pendingText;
  final IconData? icon;
  final Widget? iconWidget;
  final Color? iconColor;
  final bool useAlbumIcon;
  final bool usePlaylistIcon;
  final bool usePlayNextIcon;
  final bool useShuffleIcon;
  final bool useFullscreenIcon;
  final bool useExitFullscreenIcon;
  final bool disabled;
  final bool checked;
  final String? tooltip;
  final List<MenuFlyoutItem> submenu;
  final Future<List<MenuFlyoutItem>> Function(BuildContext)? loadSubmenu;
  final FutureOr<void> Function()? onPressed;
  final FutureOr<void> Function(BuildContext context)? onPressedWithContext;
  final ValueChanged<Offset>? onSecondaryTapDown;
  final bool Function(Object payload)? onWillAcceptDrop;
  final void Function(Object payload)? onAcceptDrop;
  final Widget? content;
  final double contentHeight;
  final bool keepOpen;
  final bool separator;
}

enum MenuFlyoutLayer { defaultLayer, dialog }

enum MenuFlyoutAnchorPlacement { below, above }

enum MenuFlyoutDensity { compact, touch }

enum MenuFlyoutAnchorAlignment { start, end }

final _openMenuFlyoutClosers = <VoidCallback>{};

void closeOpenMenuFlyouts() {
  _closeOpenMenuFlyouts();
}

void _closeOpenMenuFlyouts() {
  for (final close in _openMenuFlyoutClosers.toList()) {
    close();
  }
}

Future<void> showMenuFlyout(
  BuildContext context, {
  required List<MenuFlyoutItem> items,
  ValueListenable<List<MenuFlyoutItem>>? itemsListenable,
  Offset? position,
  MenuFlyoutAnchorPlacement anchorPlacement = MenuFlyoutAnchorPlacement.below,
  MenuFlyoutAnchorAlignment anchorAlignment = MenuFlyoutAnchorAlignment.start,
  bool avoidPlayerBar = true,
  bool scrollRoot = false,
  MenuFlyoutLayer layer = MenuFlyoutLayer.defaultLayer,
  MenuFlyoutDensity? density,
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  final overlayBox = overlay.context.findRenderObject() as RenderBox;
  final resolvedPosition =
      position == null
          ? () {
            final button = context.findRenderObject() as RenderBox;
            return button.localToGlobal(
              Offset(0, button.size.height + 4),
              ancestor: overlayBox,
            );
          }()
          : overlayBox.globalToLocal(position);
  final hasExplicitPosition = position != null;
  final touchInvocation =
      takeTouchContextMenuInvocation() || usesTouchMenuDensity;
  final resolvedDensity =
      density ??
      (touchInvocation ? MenuFlyoutDensity.touch : MenuFlyoutDensity.compact);

  final completer = Completer<void>();
  late final OverlayEntry entry;
  var closed = false;
  void close() {
    if (closed) {
      return;
    }
    closed = true;
    _openMenuFlyoutClosers.remove(close);

    void removeEntry() {
      if (entry.mounted) {
        entry.remove();
      }
      if (!completer.isCompleted) {
        completer.complete();
      }
    }

    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        removeEntry();
      });
      return;
    }
    removeEntry();
  }

  entry = OverlayEntry(
    builder:
        (overlayContext) => Positioned.fill(
          child: _MenuFlyoutOverlay(
            items: items,
            itemsListenable: itemsListenable,
            anchorContext: context,
            positionContext: overlay.context,
            requestedPosition: resolvedPosition,
            hasExplicitPosition: hasExplicitPosition,
            anchorPlacement: anchorPlacement,
            anchorAlignment: anchorAlignment,
            avoidPlayerBar: avoidPlayerBar,
            scrollRoot: scrollRoot,
            metrics: _MenuFlyoutMetrics.forDensity(resolvedDensity),
            onClose: close,
          ),
        ),
  );
  _openMenuFlyoutClosers.add(close);
  overlay.insert(entry);
  return completer.future;
}

const _menuFlyoutMargin = 8.0;
const _menuFlyoutBorderWidth = 1.0;
const _menuFlyoutPlayerBarHeight = 120.0;

class _MenuFlyoutMetrics {
  const _MenuFlyoutMetrics({
    required this.density,
    required this.minWidth,
    required this.maxWidth,
    required this.padding,
    required this.itemHeight,
    required this.separatorHeight,
    required this.horizontalPadding,
    required this.leadingWidth,
    required this.iconSize,
    required this.trailingIconSize,
    required this.contentGap,
    required this.fontSize,
    required this.textWidthSlack,
  });

  static const compact = _MenuFlyoutMetrics(
    density: MenuFlyoutDensity.compact,
    minWidth: 206,
    maxWidth: 480,
    padding: 6,
    itemHeight: 34,
    separatorHeight: 13,
    horizontalPadding: 10,
    leadingWidth: 20,
    iconSize: 18,
    trailingIconSize: 16,
    contentGap: 10,
    fontSize: 13,
    textWidthSlack: 56,
  );

  static const touch = _MenuFlyoutMetrics(
    density: MenuFlyoutDensity.touch,
    minWidth: 240,
    maxWidth: 520,
    padding: 8,
    itemHeight: 46,
    separatorHeight: 15,
    horizontalPadding: 14,
    leadingWidth: 22,
    iconSize: 20,
    trailingIconSize: 18,
    contentGap: 12,
    fontSize: 14,
    textWidthSlack: 68,
  );

  final MenuFlyoutDensity density;
  final double minWidth;
  final double maxWidth;
  final double padding;
  final double itemHeight;
  final double separatorHeight;
  final double horizontalPadding;
  final double leadingWidth;
  final double iconSize;
  final double trailingIconSize;
  final double contentGap;
  final double fontSize;
  final double textWidthSlack;

  static _MenuFlyoutMetrics forDensity(MenuFlyoutDensity density) {
    return switch (density) {
      MenuFlyoutDensity.compact => compact,
      MenuFlyoutDensity.touch => touch,
    };
  }

  double contentHeight(MenuFlyoutItem item) {
    return density == MenuFlyoutDensity.touch
        ? math.max(item.contentHeight, itemHeight)
        : item.contentHeight;
  }
}

class _MenuFlyoutOverlay extends StatefulWidget {
  const _MenuFlyoutOverlay({
    required this.items,
    required this.itemsListenable,
    required this.anchorContext,
    required this.positionContext,
    required this.requestedPosition,
    required this.hasExplicitPosition,
    required this.anchorPlacement,
    required this.anchorAlignment,
    required this.avoidPlayerBar,
    required this.scrollRoot,
    required this.metrics,
    required this.onClose,
  });

  final List<MenuFlyoutItem> items;
  final ValueListenable<List<MenuFlyoutItem>>? itemsListenable;
  final BuildContext anchorContext;
  final BuildContext positionContext;
  final Offset requestedPosition;
  final bool hasExplicitPosition;
  final MenuFlyoutAnchorPlacement anchorPlacement;
  final MenuFlyoutAnchorAlignment anchorAlignment;
  final bool avoidPlayerBar;
  final bool scrollRoot;
  final _MenuFlyoutMetrics metrics;
  final VoidCallback onClose;

  @override
  State<_MenuFlyoutOverlay> createState() => _MenuFlyoutOverlayState();
}

class _MenuFlyoutOverlayState extends State<_MenuFlyoutOverlay>
    with WidgetsBindingObserver {
  late List<_MenuFlyoutPanelState> _panels;
  final _focusNode = FocusNode(debugLabel: 'MenuFlyoutOverlay');
  ScrollPosition? _anchorScrollPosition;
  var _positionUpdateScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _panels = [
      _MenuFlyoutPanelState(
        items: widget.items,
        position: widget.requestedPosition,
      ),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
        _attachAnchorScrollListener();
      }
    });
  }

  @override
  void didUpdateWidget(_MenuFlyoutOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items == widget.items) {
      return;
    }
    setState(() {
      _panels = [
        _MenuFlyoutPanelState(
          items: widget.items,
          position: _panels.first.position,
        ),
      ];
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _anchorScrollPosition?.removeListener(_requestPositionUpdate);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    _requestPositionUpdate();
  }

  @override
  Widget build(BuildContext context) {
    final itemsListenable = widget.itemsListenable;
    if (itemsListenable != null) {
      return ValueListenableBuilder<List<MenuFlyoutItem>>(
        valueListenable: itemsListenable,
        builder:
            (context, items, _) =>
                _buildOverlay(context, items == widget.items ? null : items),
      );
    }
    return _buildOverlay(context, null);
  }

  Widget _buildOverlay(BuildContext context, List<MenuFlyoutItem>? liveItems) {
    if (liveItems != null && _panels.first.items != liveItems) {
      _panels = [
        _MenuFlyoutPanelState(
          items: liveItems,
          position: _panels.first.position,
        ),
      ];
    }
    return Material(
      type: MaterialType.transparency,
      child: KeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: (event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.escape) {
            widget.onClose();
          }
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            final view = View.of(context);
            final viewSize = view.physicalSize / view.devicePixelRatio;
            final size = Size(
              math.min(constraints.biggest.width, viewSize.width),
              math.min(constraints.biggest.height, viewSize.height),
            );
            final boundaryBottom = _boundaryBottom(size);
            final panels = _resolvedPanels(context, size, boundaryBottom);
            return Stack(
              children: [
                ModalBarrier(
                  color: Colors.transparent,
                  dismissible: true,
                  onDismiss: widget.onClose,
                ),
                for (var index = 0; index < panels.length; index++)
                  _MenuFlyoutPanel(
                    key: ValueKey(
                      'MenuFlyoutPanel.$index.${panels[index].items.length}',
                    ),
                    state: panels[index],
                    depth: index,
                    anchorContext: widget.anchorContext,
                    positionContext: widget.positionContext,
                    boundaryBottom: boundaryBottom,
                    scrollRoot: widget.scrollRoot,
                    metrics: widget.metrics,
                    onClose: widget.onClose,
                    onItemEntered: _clearSubmenusAfter,
                    onPassiveItemEntered: _clearSubmenusAfter,
                    onSubmenuEntered: _showSubmenu,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  double _boundaryBottom(Size size) {
    if (!widget.avoidPlayerBar) {
      return size.height - _menuFlyoutMargin;
    }
    final playerTop = size.height - _menuFlyoutPlayerBarHeight;
    return playerTop - _menuFlyoutMargin;
  }

  void _attachAnchorScrollListener() {
    if (widget.hasExplicitPosition || !widget.anchorContext.mounted) {
      return;
    }
    final scrollable = Scrollable.maybeOf(widget.anchorContext);
    final position = scrollable?.position;
    if (position == null || identical(position, _anchorScrollPosition)) {
      return;
    }
    _anchorScrollPosition?.removeListener(_requestPositionUpdate);
    _anchorScrollPosition = position..addListener(_requestPositionUpdate);
  }

  void _requestPositionUpdate() {
    if (!mounted || _positionUpdateScheduled) {
      return;
    }
    _positionUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _positionUpdateScheduled = false;
      if (!mounted) {
        return;
      }
      setState(() {
        _panels = _panels.take(1).toList();
      });
    });
  }

  List<_MenuFlyoutPanelState> _resolvedPanels(
    BuildContext context,
    Size size,
    double boundaryBottom,
  ) {
    return [
      for (var index = 0; index < _panels.length; index++)
        () {
          final panel = _panels[index];
          final width =
              _menuFlyoutPanelWidth(
                context,
                panel.items,
                widget.metrics,
              ).clamp(0, size.width - _menuFlyoutMargin * 2).toDouble();
          final anchorPosition =
              index == 0 ? _resolvedRequestedPosition() : panel.position;
          final position =
              index == 0 &&
                      widget.anchorAlignment == MenuFlyoutAnchorAlignment.end
                  ? Offset(anchorPosition.dx - width, anchorPosition.dy)
                  : anchorPosition;
          return panel
              .copyWith(position: position)
              .resolve(
                size: size,
                boundaryBottom: boundaryBottom,
                width: width,
                maxWidth: widget.metrics.maxWidth,
                metrics: widget.metrics,
              );
        }(),
    ];
  }

  Offset _resolvedRequestedPosition() {
    if (widget.hasExplicitPosition) {
      if (!widget.anchorContext.mounted) {
        return widget.requestedPosition;
      }
      final renderObject = widget.anchorContext.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.attached) {
        return widget.requestedPosition;
      }
      final positionObject = widget.positionContext.findRenderObject();
      if (positionObject is! RenderBox || !positionObject.attached) {
        return widget.requestedPosition;
      }
      final anchorTop =
          renderObject.localToGlobal(Offset.zero, ancestor: positionObject).dy;
      if (widget.requestedPosition.dy < anchorTop) {
        return Offset(
          widget.requestedPosition.dx,
          anchorTop -
              _menuFlyoutItemsHeight(_panels.first.items, widget.metrics) -
              8,
        );
      }
      return widget.requestedPosition;
    }
    if (!widget.anchorContext.mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onClose();
        }
      });
      return widget.requestedPosition;
    }
    final renderObject = widget.anchorContext.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.attached) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onClose();
        }
      });
      return widget.requestedPosition;
    }
    final positionObject = widget.positionContext.findRenderObject();
    if (positionObject is! RenderBox || !positionObject.attached) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onClose();
        }
      });
      return widget.requestedPosition;
    }
    final anchorOffset = switch (widget.anchorPlacement) {
      MenuFlyoutAnchorPlacement.below => Offset(
        widget.anchorAlignment == MenuFlyoutAnchorAlignment.end
            ? renderObject.size.width
            : 0,
        renderObject.size.height + 4,
      ),
      MenuFlyoutAnchorPlacement.above => Offset(
        widget.anchorAlignment == MenuFlyoutAnchorAlignment.end
            ? renderObject.size.width
            : 0,
        -_menuFlyoutItemsHeight(_panels.first.items, widget.metrics) - 8,
      ),
    };
    return renderObject.localToGlobal(anchorOffset, ancestor: positionObject);
  }

  void _clearSubmenusAfter(int depth) {
    if (_panels.length == depth + 1) {
      return;
    }
    setState(() {
      _panels = _panels.take(depth + 1).toList();
    });
  }

  void _showSubmenu({
    required int depth,
    required Rect triggerRect,
    required List<MenuFlyoutItem> items,
  }) {
    final size = MediaQuery.sizeOf(context);
    final boundaryBottom = _boundaryBottom(size);
    final panelWidth = _menuFlyoutPanelWidth(
      context,
      items,
      widget.metrics,
    ).clamp(0.0, size.width - _menuFlyoutMargin * 2);
    final fullHeight = _menuFlyoutItemsHeight(items, widget.metrics);
    var left = triggerRect.right + _menuFlyoutMargin;
    if (left + panelWidth > size.width - _menuFlyoutMargin) {
      left = triggerRect.left - panelWidth - _menuFlyoutMargin;
    }
    left = left.clamp(
      _menuFlyoutMargin,
      size.width - panelWidth - _menuFlyoutMargin,
    );
    final panelHeight = fullHeight.clamp(
      120.0,
      boundaryBottom - _menuFlyoutMargin,
    );
    final top = (triggerRect.top - 6).clamp(
      _menuFlyoutMargin,
      boundaryBottom - panelHeight,
    );
    final nextPanel = _MenuFlyoutPanelState(
      items: items,
      position: Offset(left, top),
    );
    setState(() {
      _panels = [..._panels.take(depth + 1), nextPanel];
    });
  }
}
