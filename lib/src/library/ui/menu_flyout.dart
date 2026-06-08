import 'dart:async';
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
import 'package:smplayer_flutter/src/app/uniform_multi_select_icon.dart';

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
    this.submenu = const [],
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
      submenu = const [],
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
  final List<MenuFlyoutItem> submenu;
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

final _openMenuFlyoutClosers = <VoidCallback>{};

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
  bool avoidPlayerBar = true,
  bool scrollRoot = false,
  MenuFlyoutLayer layer = MenuFlyoutLayer.defaultLayer,
}) {
  final overlay = Overlay.of(
    context,
    rootOverlay: layer == MenuFlyoutLayer.dialog,
  );
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
        (overlayContext) => _MenuFlyoutOverlay(
          items: items,
          itemsListenable: itemsListenable,
          anchorContext: context,
          positionContext: overlay.context,
          requestedPosition: resolvedPosition,
          hasExplicitPosition: hasExplicitPosition,
          avoidPlayerBar: avoidPlayerBar,
          scrollRoot: scrollRoot,
          onClose: close,
        ),
  );
  _openMenuFlyoutClosers.add(close);
  overlay.insert(entry);
  return completer.future;
}

const _menuFlyoutMargin = 8.0;
const _menuFlyoutWidth = 206.0;
const _menuFlyoutMaxWidth = 280.0;
const _menuFlyoutPadding = 6.0;
const _menuFlyoutBorderWidth = 1.0;
const _menuFlyoutItemHeight = 34.0;
const _menuFlyoutSeparatorHeight = 13.0;
const _menuFlyoutPlayerBarHeight = 120.0;

class _MenuFlyoutOverlay extends StatefulWidget {
  const _MenuFlyoutOverlay({
    required this.items,
    required this.itemsListenable,
    required this.anchorContext,
    required this.positionContext,
    required this.requestedPosition,
    required this.hasExplicitPosition,
    required this.avoidPlayerBar,
    required this.scrollRoot,
    required this.onClose,
  });

  final List<MenuFlyoutItem> items;
  final ValueListenable<List<MenuFlyoutItem>>? itemsListenable;
  final BuildContext anchorContext;
  final BuildContext positionContext;
  final Offset requestedPosition;
  final bool hasExplicitPosition;
  final bool avoidPlayerBar;
  final bool scrollRoot;
  final VoidCallback onClose;

  @override
  State<_MenuFlyoutOverlay> createState() => _MenuFlyoutOverlayState();
}

class _MenuFlyoutOverlayState extends State<_MenuFlyoutOverlay>
    with WidgetsBindingObserver {
  late List<_MenuFlyoutPanelState> _panels;
  final _focusNode = FocusNode(debugLabel: 'MenuFlyoutOverlay');
  ScrollPosition? _anchorScrollPosition;

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
                Positioned.fill(
                  child: Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: (_) => widget.onClose(),
                    child: const SizedBox.expand(),
                  ),
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
    if (widget.requestedPosition.dy >= playerTop) {
      return size.height - _menuFlyoutMargin;
    }
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
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  List<_MenuFlyoutPanelState> _resolvedPanels(
    BuildContext context,
    Size size,
    double boundaryBottom,
  ) {
    return [
      for (var index = 0; index < _panels.length; index++)
        _panels[index]
            .copyWith(
              position:
                  index == 0
                      ? _resolvedRequestedPosition()
                      : _panels[index].position,
            )
            .resolve(
              size: size,
              boundaryBottom: boundaryBottom,
              width: _menuFlyoutPanelWidth(
                context,
                _panels[index].items,
              ).clamp(0, size.width - _menuFlyoutMargin * 2),
              maxWidth: _menuFlyoutMaxWidth,
            ),
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
      final positionBox =
          widget.positionContext.findRenderObject() as RenderBox;
      final anchorTop =
          renderObject.localToGlobal(Offset.zero, ancestor: positionBox).dy;
      if (widget.requestedPosition.dy < anchorTop) {
        return Offset(
          widget.requestedPosition.dx,
          anchorTop - _menuFlyoutItemsHeight(_panels.first.items) - 8,
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
    final positionBox = widget.positionContext.findRenderObject() as RenderBox;
    return renderObject.localToGlobal(
      Offset(0, renderObject.size.height + 4),
      ancestor: positionBox,
    );
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
    ).clamp(0.0, size.width - _menuFlyoutMargin * 2);
    final fullHeight = _menuFlyoutItemsHeight(items);
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

class _MenuFlyoutPanelState {
  const _MenuFlyoutPanelState({required this.items, required this.position});

  final List<MenuFlyoutItem> items;
  final Offset position;

  _MenuFlyoutPanelState copyWith({Offset? position}) {
    return _MenuFlyoutPanelState(
      items: items,
      position: position ?? this.position,
    );
  }

  _MenuFlyoutPanelState resolve({
    required Size size,
    required double boundaryBottom,
    required double width,
    required double maxWidth,
  }) {
    final resolvedWidth = width.clamp(0.0, maxWidth);
    final height = _menuFlyoutItemsHeight(items);
    final left = position.dx.clamp(
      _menuFlyoutMargin,
      size.width - resolvedWidth - _menuFlyoutMargin,
    );
    final top = position.dy.clamp(
      _menuFlyoutMargin,
      boundaryBottom - height.clamp(0.0, boundaryBottom - _menuFlyoutMargin),
    );
    return _MenuFlyoutPanelState(items: items, position: Offset(left, top));
  }
}

class _MenuFlyoutPanel extends StatefulWidget {
  const _MenuFlyoutPanel({
    super.key,
    required this.state,
    required this.depth,
    required this.anchorContext,
    required this.positionContext,
    required this.boundaryBottom,
    required this.scrollRoot,
    required this.onClose,
    required this.onItemEntered,
    required this.onPassiveItemEntered,
    required this.onSubmenuEntered,
  });

  final _MenuFlyoutPanelState state;
  final int depth;
  final BuildContext anchorContext;
  final BuildContext positionContext;
  final double boundaryBottom;
  final bool scrollRoot;
  final VoidCallback onClose;
  final ValueChanged<int> onItemEntered;
  final ValueChanged<int> onPassiveItemEntered;
  final void Function({
    required int depth,
    required Rect triggerRect,
    required List<MenuFlyoutItem> items,
  })
  onSubmenuEntered;

  @override
  State<_MenuFlyoutPanel> createState() => _MenuFlyoutPanelWidgetState();
}

class _MenuFlyoutPanelWidgetState extends State<_MenuFlyoutPanel> {
  final ValueNotifier<int?> _activeItemIndex = ValueNotifier<int?>(null);

  @override
  void didUpdateWidget(_MenuFlyoutPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.items != widget.state.items) {
      _setActiveItem(null);
    }
  }

  @override
  void dispose() {
    _activeItemIndex.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = MenuFlyoutThemeColors.of(context);
    final maxHeight = (widget.boundaryBottom -
            widget.state.position.dy -
            _menuFlyoutMargin)
        .clamp(120.0, boundaryBottom - _menuFlyoutMargin);
    final itemsContentHeight = _menuFlyoutItemsContentHeight(
      widget.state.items,
    );
    final scrollable =
        (widget.depth > 0 || widget.scrollRoot) &&
        itemsContentHeight > maxHeight;
    final itemWidgets = [
      for (var index = 0; index < widget.state.items.length; index += 1)
        _MenuFlyoutItemWidget(
          key: ValueKey(widget.state.items[index].key),
          item: widget.state.items[index],
          itemIndex: index,
          depth: widget.depth,
          activeItemIndexListenable: _activeItemIndex,
          anchorContext: widget.anchorContext,
          positionContext: widget.positionContext,
          onClose: widget.onClose,
          onItemEntered: _handleItemEntered,
          onItemExited: _handleItemExited,
          onPassiveItemEntered: _handlePassiveItemEntered,
          onSubmenuEntered: _handleSubmenuEntered,
        ),
    ];
    final panel = ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: _menuFlyoutWidth,
        maxWidth: _menuFlyoutMaxWidth,
        maxHeight: scrollable ? maxHeight : double.infinity,
      ),
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(child: _MenuFlyoutGlassPanel(colors: colors)),
            Padding(
              padding: const EdgeInsets.all(
                _menuFlyoutPadding + _menuFlyoutBorderWidth,
              ),
              child:
                  scrollable
                      ? ListView(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        children: itemWidgets,
                      )
                      : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: itemWidgets,
                      ),
            ),
          ],
        ),
      ),
    );
    return Positioned(
      left: widget.state.position.dx,
      top: widget.state.position.dy,
      child: scrollable ? panel : IntrinsicWidth(child: panel),
    );
  }

  double get boundaryBottom => widget.boundaryBottom;

  void _handleItemEntered(int itemIndex) {
    _setActiveItem(itemIndex);
    widget.onItemEntered(widget.depth);
  }

  void _handleItemExited(int itemIndex) {
    if (_activeItemIndex.value == itemIndex) {
      _setActiveItem(null);
    }
  }

  void _handlePassiveItemEntered() {
    _setActiveItem(null);
    widget.onPassiveItemEntered(widget.depth);
  }

  void _handleSubmenuEntered({
    required int itemIndex,
    required Rect triggerRect,
    required List<MenuFlyoutItem> items,
  }) {
    _setActiveItem(itemIndex);
    widget.onSubmenuEntered(
      depth: widget.depth,
      triggerRect: triggerRect,
      items: items,
    );
  }

  void _setActiveItem(int? itemIndex) {
    if (_activeItemIndex.value == itemIndex) {
      return;
    }
    _activeItemIndex.value = itemIndex;
  }
}

class _MenuFlyoutGlassPanel extends StatelessWidget {
  const _MenuFlyoutGlassPanel({required this.colors});

  static const _radius = 10.0;

  final MenuFlyoutThemeColors colors;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_radius),
        boxShadow: [
          BoxShadow(
            color: colors.shadow,
            offset: const Offset(0, 18),
            blurRadius: 44,
          ),
        ],
      ),
      child: GlassContainer(
        key: const ValueKey('MenuFlyout.GlassPanel'),
        useOwnLayer: true,
        quality: GlassQuality.minimal,
        clipBehavior: Clip.hardEdge,
        shape: const LiquidRoundedRectangle(borderRadius: _radius),
        settings: LiquidGlassSettings(
          blur: 46,
          thickness: 20,
          refractiveIndex: 1.06,
          saturation: 1.65,
          chromaticAberration: 0,
          lightIntensity: 0.1,
          ambientStrength: 0.08,
          glowIntensity: 0.04,
          glassColor: colors.surface,
          standardOpacityMultiplier: 0.24,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_radius),
            border: Border.all(color: colors.border),
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _MenuFlyoutItemWidget extends StatefulWidget {
  const _MenuFlyoutItemWidget({
    super.key,
    required this.item,
    required this.itemIndex,
    required this.depth,
    required this.activeItemIndexListenable,
    required this.anchorContext,
    required this.positionContext,
    required this.onClose,
    required this.onItemEntered,
    required this.onItemExited,
    required this.onPassiveItemEntered,
    required this.onSubmenuEntered,
  });

  final MenuFlyoutItem item;
  final int itemIndex;
  final int depth;
  final ValueListenable<int?> activeItemIndexListenable;
  final BuildContext anchorContext;
  final BuildContext positionContext;
  final VoidCallback onClose;
  final ValueChanged<int> onItemEntered;
  final ValueChanged<int> onItemExited;
  final VoidCallback onPassiveItemEntered;
  final void Function({
    required int itemIndex,
    required Rect triggerRect,
    required List<MenuFlyoutItem> items,
  })
  onSubmenuEntered;

  @override
  State<_MenuFlyoutItemWidget> createState() => _MenuFlyoutItemWidgetState();
}

class _MenuFlyoutItemWidgetState extends State<_MenuFlyoutItemWidget> {
  late bool _active;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _active = widget.activeItemIndexListenable.value == widget.itemIndex;
    widget.activeItemIndexListenable.addListener(_handleActiveItemChanged);
  }

  @override
  void didUpdateWidget(_MenuFlyoutItemWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeItemIndexListenable !=
        widget.activeItemIndexListenable) {
      oldWidget.activeItemIndexListenable.removeListener(
        _handleActiveItemChanged,
      );
      widget.activeItemIndexListenable.addListener(_handleActiveItemChanged);
    }
    final active = widget.activeItemIndexListenable.value == widget.itemIndex;
    if (_active != active) {
      _active = active;
    }
  }

  @override
  void dispose() {
    widget.activeItemIndexListenable.removeListener(_handleActiveItemChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    if (item.separator) {
      return MouseRegion(
        onEnter: (_) => widget.onPassiveItemEntered(),
        child: const SizedBox(
          height: _menuFlyoutSeparatorHeight,
          child: Center(
            child: Divider(height: 1, thickness: 1, indent: 8, endIndent: 8),
          ),
        ),
      );
    }
    if (item.content != null) {
      return MouseRegion(
        onEnter: (_) => widget.onPassiveItemEntered(),
        child: SizedBox(height: item.contentHeight, child: item.content),
      );
    }

    final colors = MenuFlyoutThemeColors.of(context);
    final hasSubmenu = item.submenu.isNotEmpty && !item.disabled;
    final active = _active && !item.disabled && !_busy;
    final foreground =
        item.disabled
            ? colors.disabledText
            : active
            ? colors.hoverText
            : colors.text;
    Widget itemContent = MouseRegion(
      cursor:
          item.disabled || _busy
              ? SystemMouseCursors.basic
              : SystemMouseCursors.click,
      onEnter: (_) {
        if (hasSubmenu) {
          _openSubmenu(item);
        } else {
          widget.onItemEntered(widget.itemIndex);
        }
      },
      onExit: (_) {
        if (!hasSubmenu) {
          widget.onItemExited(widget.itemIndex);
        }
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onSecondaryTapDown:
            item.onSecondaryTapDown == null
                ? null
                : (details) {
                  _closeOpenMenuFlyouts();
                  item.onSecondaryTapDown!(details.globalPosition);
                },
        onTap:
            item.disabled || _busy
                ? null
                : () async {
                  if (hasSubmenu) {
                    _openSubmenu(item);
                    return;
                  }
                  if (!item.keepOpen) {
                    _closeOpenMenuFlyouts();
                    final result =
                        item.onPressedWithContext?.call(widget.anchorContext) ??
                        item.onPressed?.call();
                    if (result is Future<void>) {
                      unawaited(result);
                    }
                    return;
                  }
                  final result =
                      item.onPressedWithContext?.call(widget.anchorContext) ??
                      item.onPressed?.call();
                  if (result is Future<void>) {
                    setState(() {
                      _busy = true;
                    });
                    try {
                      await result;
                    } finally {
                      if (mounted) {
                        setState(() {
                          _busy = false;
                        });
                      }
                    }
                    return;
                  }
                },
        child: Semantics(
          button: true,
          enabled: !item.disabled && !_busy,
          checked: item.checked,
          child: Container(
            height: _menuFlyoutItemHeight,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: active ? colors.hoverSurface : Colors.transparent,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  child:
                      item.icon == FluentIcons.play_20_regular
                          ? Center(
                            child: SizedBox.square(
                              dimension: 18,
                              child: SmPlayerPlayIcon(
                                size: 18,
                                color:
                                    item.disabled
                                        ? foreground
                                        : item.iconColor ?? foreground,
                              ),
                            ),
                          )
                          : item.useAlbumIcon
                          ? Center(
                            child: SizedBox.square(
                              dimension: 18,
                              child: SmPlayerAlbumIcon(
                                size: 18,
                                color:
                                    item.disabled
                                        ? foreground
                                        : item.iconColor ?? foreground,
                              ),
                            ),
                          )
                          : item.usePlaylistIcon
                          ? Center(
                            child: SizedBox.square(
                              dimension: 18,
                              child: SmPlayerPlaylistIcon(
                                size: 18,
                                color:
                                    item.disabled
                                        ? foreground
                                        : item.iconColor ?? foreground,
                              ),
                            ),
                          )
                          : item.usePlayNextIcon
                          ? Center(
                            child: SizedBox.square(
                              dimension: 18,
                              child: SmPlayerPlayNextIcon(
                                size: 18,
                                color:
                                    item.disabled
                                        ? foreground
                                        : item.iconColor ?? foreground,
                              ),
                            ),
                          )
                          : item.useShuffleIcon
                          ? Center(
                            child: SizedBox.square(
                              dimension: 18,
                              child: ShuffleIcon(
                                color:
                                    item.disabled
                                        ? foreground
                                        : item.iconColor ?? foreground,
                              ),
                            ),
                          )
                          : item.useFullscreenIcon
                          ? Center(
                            child: SizedBox.square(
                              dimension: 18,
                              child: SmPlayerFullscreenIcon(
                                size: 18,
                                color:
                                    item.disabled
                                        ? foreground
                                        : item.iconColor ?? foreground,
                              ),
                            ),
                          )
                          : item.useExitFullscreenIcon
                          ? Center(
                            child: SizedBox.square(
                              dimension: 18,
                              child: ExitFullscreenIcon(
                                size: 18,
                                color:
                                    item.disabled
                                        ? foreground
                                        : item.iconColor ?? foreground,
                              ),
                            ),
                          )
                          : item.iconWidget != null
                          ? Center(
                            child: SizedBox.square(
                              dimension: 18,
                              child: IconTheme(
                                data: IconThemeData(
                                  color:
                                      item.disabled
                                          ? foreground
                                          : item.iconColor ?? foreground,
                                ),
                                child: item.iconWidget!,
                              ),
                            ),
                          )
                          : item.icon == null
                          ? null
                          : isMultiSelectIcon(item.icon!)
                          ? Center(
                            child: SizedBox.square(
                              dimension: 18,
                              child: UniformMultiSelectIcon(
                                size: 18,
                                color:
                                    item.disabled
                                        ? foreground
                                        : item.iconColor ?? foreground,
                                strokeWidth: 1.35,
                              ),
                            ),
                          )
                          : Icon(
                            item.icon,
                            size: 18,
                            color:
                                item.disabled
                                    ? foreground
                                    : item.iconColor ?? foreground,
                          ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _busy ? item.pendingText ?? item.text : item.text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: foreground,
                      fontSize: 13,
                      height: 1,
                    ),
                  ),
                ),
                if (item.checked)
                  Icon(
                    FluentIcons.checkmark_20_regular,
                    size: 16,
                    color: colors.checked,
                  )
                else if (hasSubmenu)
                  Icon(
                    FluentIcons.chevron_right_20_regular,
                    size: 16,
                    color: foreground,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    if (item.onAcceptDrop == null) {
      return itemContent;
    }
    return DragTarget<Object>(
      onWillAcceptWithDetails:
          item.onWillAcceptDrop == null
              ? null
              : (details) => item.onWillAcceptDrop!(details.data),
      onAcceptWithDetails: (details) {
        _closeOpenMenuFlyouts();
        item.onAcceptDrop!(details.data);
      },
      builder: (context, candidateData, rejectedData) => itemContent,
    );
  }

  void _openSubmenu(MenuFlyoutItem item) {
    final box = context.findRenderObject() as RenderBox;
    final positionBox = widget.positionContext.findRenderObject() as RenderBox;
    widget.onSubmenuEntered(
      itemIndex: widget.itemIndex,
      triggerRect:
          box.localToGlobal(Offset.zero, ancestor: positionBox) & box.size,
      items: item.submenu,
    );
  }

  void _handleActiveItemChanged() {
    final active = widget.activeItemIndexListenable.value == widget.itemIndex;
    if (_active == active) {
      return;
    }
    setState(() {
      _active = active;
    });
  }
}

double _menuFlyoutItemsHeight(List<MenuFlyoutItem> items) {
  return (_menuFlyoutPadding + _menuFlyoutBorderWidth) * 2 +
      _menuFlyoutItemsContentHeight(items);
}

double _menuFlyoutPanelWidth(BuildContext context, List<MenuFlyoutItem> items) {
  final textDirection = Directionality.of(context);
  final textScaler = MediaQuery.textScalerOf(context);
  var width = _menuFlyoutWidth;
  for (final item in items) {
    if (item.separator || item.content != null) {
      continue;
    }
    final painter = TextPainter(
      text: TextSpan(
        text: item.pendingText ?? item.text,
        style: const TextStyle(fontSize: 13, height: 1),
      ),
      maxLines: 1,
      textDirection: textDirection,
      textScaler: textScaler,
    )..layout();
    final trailingWidth =
        item.checked || item.submenu.isNotEmpty && !item.disabled ? 16.0 : 0.0;
    final itemWidth =
        (_menuFlyoutPadding + _menuFlyoutBorderWidth) * 2 +
        20 +
        10 +
        20 +
        painter.width +
        trailingWidth;
    width = math.max(width, itemWidth);
  }
  return width.clamp(_menuFlyoutWidth, _menuFlyoutMaxWidth).toDouble();
}

double _menuFlyoutItemsContentHeight(List<MenuFlyoutItem> items) {
  return items.fold<double>(0, (height, item) {
    if (item.separator) {
      return height + _menuFlyoutSeparatorHeight;
    }
    if (item.content != null) {
      return height + item.contentHeight;
    }
    return height + _menuFlyoutItemHeight;
  });
}

class MenuFlyoutThemeColors extends ThemeExtension<MenuFlyoutThemeColors> {
  const MenuFlyoutThemeColors({
    required this.surface,
    required this.border,
    required this.shadow,
    required this.text,
    required this.hoverText,
    required this.disabledText,
    required this.hoverSurface,
    required this.checked,
  });

  final Color surface;
  final Color border;
  final Color shadow;
  final Color text;
  final Color hoverText;
  final Color disabledText;
  final Color hoverSurface;
  final Color checked;

  static const light = MenuFlyoutThemeColors(
    surface: Color(0x48ffffff),
    border: Color(0x337e8b9a),
    shadow: Color(0x2e263344),
    text: Color(0xff1f252b),
    hoverText: Color(0xff0063b1),
    disabledText: Color(0x751f252b),
    hoverSurface: GlobalUI.selectedBgColorDay,
    checked: Color(0xff0063b1),
  );

  static const dark = MenuFlyoutThemeColors(
    surface: Color(0x54181e26),
    border: Color(0x30d6e0ec),
    shadow: Color(0x5c000000),
    text: Colors.white,
    hoverText: Colors.white,
    disabledText: Color(0x8fffffff),
    hoverSurface: GlobalUI.selectedBgColorNight,
    checked: Colors.white,
  );

  static MenuFlyoutThemeColors of(BuildContext context) {
    return Theme.of(context).extension<MenuFlyoutThemeColors>() ?? light;
  }

  @override
  MenuFlyoutThemeColors copyWith() {
    return this;
  }

  @override
  MenuFlyoutThemeColors lerp(
    ThemeExtension<MenuFlyoutThemeColors>? other,
    double t,
  ) {
    return t < 0.5 || other is! MenuFlyoutThemeColors ? this : other;
  }
}
