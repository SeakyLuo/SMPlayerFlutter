import 'dart:async';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smplayer_flutter/src/app/app_interaction_colors.dart';
import 'package:smplayer_flutter/src/app/smplayer_vector_icons.dart';
import 'package:smplayer_flutter/src/app/uniform_multi_select_icon.dart';

class MenuFlyoutItem {
  const MenuFlyoutItem({
    required this.key,
    required this.text,
    this.pendingText,
    this.icon,
    this.iconColor,
    this.useAlbumIcon = false,
    this.usePlaylistIcon = false,
    this.usePlayNextIcon = false,
    this.disabled = false,
    this.checked = false,
    this.submenu = const [],
    this.onPressed,
    this.onPressedWithContext,
    this.content,
    this.contentHeight = 42,
    this.keepOpen = false,
  }) : separator = false;

  const MenuFlyoutItem.separator({required this.key})
    : text = '',
      pendingText = null,
      icon = null,
      iconColor = null,
      useAlbumIcon = false,
      usePlaylistIcon = false,
      usePlayNextIcon = false,
      disabled = false,
      checked = false,
      submenu = const [],
      onPressed = null,
      onPressedWithContext = null,
      content = null,
      contentHeight = 42,
      keepOpen = false,
      separator = true;

  final String key;
  final String text;
  final String? pendingText;
  final IconData? icon;
  final Color? iconColor;
  final bool useAlbumIcon;
  final bool usePlaylistIcon;
  final bool usePlayNextIcon;
  final bool disabled;
  final bool checked;
  final List<MenuFlyoutItem> submenu;
  final FutureOr<void> Function()? onPressed;
  final FutureOr<void> Function(BuildContext context)? onPressedWithContext;
  final Widget? content;
  final double contentHeight;
  final bool keepOpen;
  final bool separator;
}

enum MenuFlyoutLayer { defaultLayer, dialog }

Future<void> showMenuFlyout(
  BuildContext context, {
  required List<MenuFlyoutItem> items,
  ValueListenable<List<MenuFlyoutItem>>? itemsListenable,
  Offset? position,
  bool avoidPlayerBar = true,
  MenuFlyoutLayer layer = MenuFlyoutLayer.defaultLayer,
}) {
  final overlay = Overlay.of(
    context,
    rootOverlay: layer == MenuFlyoutLayer.dialog,
  );
  final resolvedPosition =
      position ??
      () {
        final button = context.findRenderObject() as RenderBox;
        return button.localToGlobal(Offset(0, button.size.height + 4));
      }();
  final hasExplicitPosition = position != null;

  final completer = Completer<void>();
  late final OverlayEntry entry;
  void close() {
    if (entry.mounted) {
      entry.remove();
    }
    if (!completer.isCompleted) {
      completer.complete();
    }
  }

  entry = OverlayEntry(
    builder:
        (overlayContext) => _MenuFlyoutOverlay(
          items: items,
          itemsListenable: itemsListenable,
          anchorContext: context,
          requestedPosition: resolvedPosition,
          hasExplicitPosition: hasExplicitPosition,
          avoidPlayerBar: avoidPlayerBar,
          onClose: close,
        ),
  );
  overlay.insert(entry);
  return completer.future;
}

const _menuFlyoutMargin = 8.0;
const _menuFlyoutWidth = 206.0;
const _menuFlyoutMaxWidth = 280.0;
const _menuFlyoutPadding = 6.0;
const _menuFlyoutItemHeight = 34.0;
const _menuFlyoutSeparatorHeight = 13.0;
const _menuFlyoutPlayerBarHeight = 120.0;

class _MenuFlyoutOverlay extends StatefulWidget {
  const _MenuFlyoutOverlay({
    required this.items,
    required this.itemsListenable,
    required this.anchorContext,
    required this.requestedPosition,
    required this.hasExplicitPosition,
    required this.avoidPlayerBar,
    required this.onClose,
  });

  final List<MenuFlyoutItem> items;
  final ValueListenable<List<MenuFlyoutItem>>? itemsListenable;
  final BuildContext anchorContext;
  final Offset requestedPosition;
  final bool hasExplicitPosition;
  final bool avoidPlayerBar;
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
    final size = MediaQuery.sizeOf(context);
    final boundaryBottom = _boundaryBottom(size);
    final panels = _resolvedPanels(size, boundaryBottom);
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
        child: Stack(
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
                boundaryBottom: boundaryBottom,
                onClose: widget.onClose,
                onItemEntered: _clearSubmenusAfter,
                onSubmenuEntered: _showSubmenu,
              ),
          ],
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
              width: _menuFlyoutMaxWidth.clamp(
                0,
                size.width - _menuFlyoutMargin * 2,
              ),
              maxWidth: _menuFlyoutMaxWidth,
            ),
    ];
  }

  Offset _resolvedRequestedPosition() {
    if (widget.hasExplicitPosition) {
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
    return renderObject.localToGlobal(Offset(0, renderObject.size.height + 4));
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
    final panelWidth = _menuFlyoutMaxWidth.clamp(
      0.0,
      size.width - _menuFlyoutMargin * 2,
    );
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

class _MenuFlyoutPanel extends StatelessWidget {
  const _MenuFlyoutPanel({
    super.key,
    required this.state,
    required this.depth,
    required this.anchorContext,
    required this.boundaryBottom,
    required this.onClose,
    required this.onItemEntered,
    required this.onSubmenuEntered,
  });

  final _MenuFlyoutPanelState state;
  final int depth;
  final BuildContext anchorContext;
  final double boundaryBottom;
  final VoidCallback onClose;
  final ValueChanged<int> onItemEntered;
  final void Function({
    required int depth,
    required Rect triggerRect,
    required List<MenuFlyoutItem> items,
  })
  onSubmenuEntered;

  @override
  Widget build(BuildContext context) {
    final colors = MenuFlyoutThemeColors.of(context);
    final maxHeight = (boundaryBottom - state.position.dy - _menuFlyoutMargin)
        .clamp(120.0, boundaryBottom - _menuFlyoutMargin);
    final itemsContentHeight = _menuFlyoutItemsContentHeight(state.items);
    final maxContentHeight = maxHeight - _menuFlyoutPadding * 2;
    final scrollable = depth > 0 && itemsContentHeight > maxContentHeight;
    final itemWidgets = [
      for (final item in state.items)
        _MenuFlyoutItemWidget(
          item: item,
          depth: depth,
          anchorContext: anchorContext,
          onClose: onClose,
          onItemEntered: onItemEntered,
          onSubmenuEntered: onSubmenuEntered,
        ),
    ];
    return Positioned(
      left: state.position.dx,
      top: state.position.dy,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: _menuFlyoutWidth,
          maxWidth: _menuFlyoutMaxWidth,
          maxHeight: scrollable ? maxHeight : double.infinity,
        ),
        child: Semantics(
          container: true,
          explicitChildNodes: true,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colors.border),
              boxShadow: [
                BoxShadow(
                  color: colors.shadow,
                  offset: const Offset(0, 18),
                  blurRadius: 44,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(_menuFlyoutPadding),
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
          ),
        ),
      ),
    );
  }
}

class _MenuFlyoutItemWidget extends StatefulWidget {
  const _MenuFlyoutItemWidget({
    required this.item,
    required this.depth,
    required this.anchorContext,
    required this.onClose,
    required this.onItemEntered,
    required this.onSubmenuEntered,
  });

  final MenuFlyoutItem item;
  final int depth;
  final BuildContext anchorContext;
  final VoidCallback onClose;
  final ValueChanged<int> onItemEntered;
  final void Function({
    required int depth,
    required Rect triggerRect,
    required List<MenuFlyoutItem> items,
  })
  onSubmenuEntered;

  @override
  State<_MenuFlyoutItemWidget> createState() => _MenuFlyoutItemWidgetState();
}

class _MenuFlyoutItemWidgetState extends State<_MenuFlyoutItemWidget> {
  var _hovered = false;
  var _busy = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    if (item.separator) {
      return MouseRegion(
        onEnter: (_) => widget.onItemEntered(widget.depth),
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
        onEnter: (_) => widget.onItemEntered(widget.depth),
        child: SizedBox(height: item.contentHeight, child: item.content),
      );
    }

    final colors = MenuFlyoutThemeColors.of(context);
    final hasSubmenu = item.submenu.isNotEmpty && !item.disabled;
    final active = _hovered && !item.disabled && !_busy;
    final foreground =
        item.disabled
            ? colors.disabledText
            : active
            ? colors.hoverText
            : colors.text;
    return MouseRegion(
      cursor:
          item.disabled || _busy
              ? SystemMouseCursors.basic
              : SystemMouseCursors.click,
      onEnter: (_) {
        setState(() {
          _hovered = true;
        });
        if (hasSubmenu) {
          _openSubmenu(item);
        } else {
          widget.onItemEntered(widget.depth);
        }
      },
      onExit: (_) {
        setState(() {
          _hovered = false;
        });
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap:
            item.disabled || _busy
                ? null
                : () async {
                  if (hasSubmenu) {
                    _openSubmenu(item);
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
                      if (!item.keepOpen && mounted) {
                        widget.onClose();
                      }
                    }
                    return;
                  }
                  if (!item.keepOpen && mounted) {
                    widget.onClose();
                  }
                },
        child: Semantics(
          button: true,
          enabled: !item.disabled && !_busy,
          checked: item.checked,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
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
  }

  void _openSubmenu(MenuFlyoutItem item) {
    final box = context.findRenderObject() as RenderBox;
    widget.onSubmenuEntered(
      depth: widget.depth,
      triggerRect: box.localToGlobal(Offset.zero) & box.size,
      items: item.submenu,
    );
  }
}

double _menuFlyoutItemsHeight(List<MenuFlyoutItem> items) {
  return _menuFlyoutPadding * 2 + _menuFlyoutItemsContentHeight(items);
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
    surface: Color(0xffffffff),
    border: Color(0x337e8b9a),
    shadow: Color(0x2e263344),
    text: Color(0xff1f252b),
    hoverText: Color(0xff0063b1),
    disabledText: Color(0x751f252b),
    hoverSurface: SmPlayerInteractionColors.hoverSurface,
    checked: Color(0xff0063b1),
  );

  static const dark = MenuFlyoutThemeColors(
    surface: Color(0xfa181e26),
    border: Color(0x30d6e0ec),
    shadow: Color(0x5c000000),
    text: Colors.white,
    hoverText: Colors.white,
    disabledText: Color(0x8fffffff),
    hoverSurface: SmPlayerInteractionColors.hoverSurfaceDark,
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
