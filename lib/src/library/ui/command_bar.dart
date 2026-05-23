import 'dart:async';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smplayer_flutter/src/app/text_icon_button.dart';
import 'package:smplayer_flutter/src/library/ui/command_bar_colors.dart';
import 'package:smplayer_flutter/src/library/ui/menu_flyout.dart';

class CommandBar extends StatefulWidget {
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
  State<CommandBar> createState() => _CommandBarState();
}

class _CommandBarState extends State<CommandBar> {
  late List<GlobalKey> _itemKeys;
  final _moreKey = GlobalKey();
  var _itemWidths = <double>[];
  double? _measuredMoreWidth;
  var _measureScheduled = false;

  @override
  void initState() {
    super.initState();
    _itemKeys = _newItemKeys(widget.children.length);
    _itemWidths = List.filled(widget.children.length, 0);
  }

  @override
  void didUpdateWidget(covariant CommandBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.children.length != widget.children.length) {
      _itemKeys = _newItemKeys(widget.children.length);
      _itemWidths = List.filled(widget.children.length, 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = _CommandBarStyleData.standard();
    _scheduleMeasure();
    final toolbar = ConstrainedBox(
      constraints: BoxConstraints(minHeight: style.toolbarMinHeight),
      child: Padding(
        padding: style.toolbarPadding,
        child: _CommandBarStyleScope(
          data: style,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (widget.content != null)
                Flexible(
                  fit: FlexFit.loose,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: style.contentHorizontalPadding,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: widget.content!,
                    ),
                  ),
                ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final overflow = _resolveCommandBarOverflow(
                      context: context,
                      maxWidth: constraints.maxWidth,
                      dynamicOverflow: widget.dynamicOverflow,
                      overflowReserve: widget.overflowReserve,
                      overflowItems: widget.overflowItems,
                      children: widget.children,
                      measuredItemWidths: _itemWidths,
                      measuredMoreWidth: _measuredMoreWidth,
                    );
                    final overflowMenuItems = [
                      for (final entry in overflow.overflowedChildren)
                        _toMenuFlyoutItem(entry.$2, entry.$1),
                      ...widget.overflowItems,
                    ];

                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          left: -100000,
                          top: 0,
                          width: 10000,
                          height: style.visibleRowHeight,
                          child: Offstage(
                            child: SizedBox(
                              height: style.visibleRowHeight,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (
                                    var index = 0;
                                    index < widget.children.length;
                                    index += 1
                                  )
                                    KeyedSubtree(
                                      key: _itemKeys[index],
                                      child: widget.children[index],
                                    ),
                                  KeyedSubtree(
                                    key: _moreKey,
                                    child: CommandBarButton(
                                      icon:
                                          FluentIcons
                                              .more_horizontal_24_regular,
                                      label: widget.overflowLabel ?? 'More',
                                      showLabel: false,
                                      canOverflow: false,
                                      onPressed: () {},
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: style.primaryAlignment,
                          children: [
                            Flexible(
                              fit: FlexFit.loose,
                              child: SizedBox(
                                height: style.visibleRowHeight,
                                child: ClipRect(
                                  child: Align(
                                    alignment: style.visibleAlignment,
                                    child: OverflowBox(
                                      minWidth: 0,
                                      maxWidth: double.infinity,
                                      minHeight: 0,
                                      maxHeight: style.visibleRowHeight,
                                      alignment: style.visibleAlignment,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          for (final child
                                              in overflow.visibleChildren)
                                            child,
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (overflowMenuItems.isNotEmpty)
                              Builder(
                                builder: (context) {
                                  return CommandBarButton(
                                    key: const ValueKey(
                                      'CommandBar.MoreButton',
                                    ),
                                    icon:
                                        FluentIcons.more_horizontal_24_regular,
                                    label: widget.overflowLabel ?? 'More',
                                    showLabel: false,
                                    canOverflow: false,
                                    onPressed: () {
                                      showMenuFlyout(
                                        context,
                                        items: overflowMenuItems,
                                      );
                                    },
                                  );
                                },
                              ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return toolbar;
  }

  List<GlobalKey> _newItemKeys(int length) {
    return List.generate(length, (_) => GlobalKey());
  }

  void _scheduleMeasure() {
    if (_measureScheduled) {
      return;
    }
    _measureScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureScheduled = false;
      if (!mounted) {
        return;
      }
      final nextWidths = [
        for (final key in _itemKeys) _renderBoxWidth(key) ?? 0,
      ];
      final nextMoreWidth = _renderBoxWidth(_moreKey);
      if (_doubleListsEqual(_itemWidths, nextWidths) &&
          _measuredMoreWidth == nextMoreWidth) {
        return;
      }
      setState(() {
        _itemWidths = nextWidths;
        _measuredMoreWidth = nextMoreWidth;
      });
    });
  }

  double? _renderBoxWidth(GlobalKey key) {
    final renderObject = key.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return null;
    }
    return renderObject.size.width.ceilToDouble();
  }

  bool _doubleListsEqual(List<double> left, List<double> right) {
    if (left.length != right.length) {
      return false;
    }
    for (var index = 0; index < left.length; index += 1) {
      if (left[index] != right[index]) {
        return false;
      }
    }
    return true;
  }
}

class CommandBarButton extends StatefulWidget {
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
    this.onOverflowPressedWithContext,
    this.onPressed,
    this.onPressedWithContext,
  });

  final IconData icon;
  final String label;
  final bool active;
  final bool canOverflow;
  final bool disabled;
  final List<MenuFlyoutItem> overflowSubmenu;
  final bool showLabel;
  final VoidCallback? onOverflowPressed;
  final FutureOr<void> Function(BuildContext context)?
  onOverflowPressedWithContext;
  final VoidCallback? onPressed;
  final FutureOr<void> Function(BuildContext context)? onPressedWithContext;

  @override
  State<CommandBarButton> createState() => _CommandBarButtonState();
}

class _CommandBarButtonState extends State<CommandBarButton> {
  var _hovered = false;
  var _focused = false;
  var _pressed = false;

  @override
  Widget build(BuildContext context) {
    final style = _CommandBarStyleScope.of(context);
    final enabled = !widget.disabled;
    if (widget.showLabel) {
      return Padding(
        padding: style.buttonMargin,
        child: SmPlayerTextIconButton(
          icon: widget.icon,
          label: widget.label,
          active: widget.active,
          disabled: widget.disabled,
          tooltip: widget.label,
          minWidth: style.minWidth,
          maxWidth: style.maxWidth,
          height: style.minHeight,
          horizontalPadding: style.horizontalPadding,
          iconSize: style.iconSize,
          iconGap: style.iconGap,
          opacityWhenDisabled: style.disabledOpacity,
          fontSize: style.fontSize,
          fontWeight: style.fontWeight,
          fontVariations: const [FontVariation.weight(720)],
          onPressed: () {
            _activate(context);
          },
        ),
      );
    }
    final foreground =
        widget.active ? CommandBarColors.accentStrong : style.foreground;
    final surface = _resolveSurface(style);
    final borderColor =
        widget.active ? CommandBarColors.accentBorder : style.borderColor;
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(widget.icon, size: style.iconSize, color: foreground),
        if (widget.showLabel) ...[
          SizedBox(width: style.iconGap),
          if (style.maxWidth == null)
            Text(
              widget.label,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: TextStyle(
                color: foreground,
                fontSize: style.fontSize,
                fontWeight: style.fontWeight,
                height: 1,
              ),
            )
          else
            Flexible(
              child: Text(
                widget.label,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: TextStyle(
                  color: foreground,
                  fontSize: style.fontSize,
                  fontWeight: style.fontWeight,
                  height: 1,
                ),
              ),
            ),
        ],
      ],
    );

    return Tooltip(
      message: widget.label,
      child: Padding(
        padding: style.buttonMargin,
        child: Opacity(
          opacity: enabled ? 1 : style.disabledOpacity,
          child: FocusableActionDetector(
            enabled: enabled,
            mouseCursor:
                enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
            shortcuts: const {
              SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
              SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
            },
            actions: {
              ActivateIntent: CallbackAction<ActivateIntent>(
                onInvoke: (_) {
                  if (enabled) {
                    widget.onPressedWithContext?.call(context) ??
                        widget.onPressed?.call();
                  }
                  return null;
                },
              ),
            },
            onShowHoverHighlight: (value) {
              if (_hovered != value) {
                setState(() {
                  _hovered = value;
                });
              }
            },
            onShowFocusHighlight: (value) {
              if (_focused != value) {
                setState(() {
                  _focused = value;
                });
              }
            },
            child: Semantics(
              button: true,
              enabled: enabled,
              label: widget.showLabel ? null : widget.label,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: enabled ? (_) => _setPressed(true) : null,
                onTapCancel: enabled ? () => _setPressed(false) : null,
                onTapUp: enabled ? (_) => _setPressed(false) : null,
                onTap: enabled ? () => _activate(context) : null,
                child: Container(
                  width: style.fixedButtonSize(widget.showLabel)?.width,
                  height: style.minHeight,
                  constraints: BoxConstraints(
                    minWidth: style.minWidth,
                    minHeight: style.minHeight,
                    maxWidth:
                        widget.showLabel
                            ? style.maxWidth ?? double.infinity
                            : style.minWidth,
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: widget.showLabel ? style.horizontalPadding : 0,
                  ),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(style.borderRadius),
                    border:
                        borderColor == Colors.transparent ||
                                style.borderWidth == 0
                            ? null
                            : Border.all(
                              color: borderColor,
                              width: style.borderWidth,
                            ),
                    boxShadow: style.shadow,
                  ),
                  alignment: Alignment.center,
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (style.highlightColor != Colors.transparent)
                        Positioned(
                          left: 0,
                          top: 0,
                          right: 0,
                          child: ColoredBox(
                            color: style.highlightColor,
                            child: const SizedBox(height: 1),
                          ),
                        ),
                      Center(
                        child:
                            widget.showLabel
                                ? content
                                : Icon(
                                  widget.icon,
                                  size: style.iconSize,
                                  color: foreground,
                                ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _activate(BuildContext context) {
    widget.onPressedWithContext?.call(context) ?? widget.onPressed?.call();
  }

  void _setPressed(bool value) {
    if (_pressed == value) {
      return;
    }
    setState(() {
      _pressed = value;
    });
  }

  Color _resolveSurface(_CommandBarStyleData style) {
    if (widget.active) {
      return CommandBarColors.accentSoft;
    }
    if (style.transparent && !_pressed && !_hovered && !_focused) {
      return Colors.transparent;
    }
    if (_pressed) {
      return style.pressedSurface;
    }
    if (_hovered || _focused) {
      return style.hoverSurface;
    }
    return style.surface;
  }
}

class _CommandBarOverflowResult {
  const _CommandBarOverflowResult({
    required this.visibleChildren,
    required this.overflowedChildren,
  });

  final List<Widget> visibleChildren;
  final List<(int, CommandBarButton)> overflowedChildren;
}

_CommandBarOverflowResult _resolveCommandBarOverflow({
  required BuildContext context,
  required double maxWidth,
  required bool dynamicOverflow,
  required double overflowReserve,
  required List<MenuFlyoutItem> overflowItems,
  required List<Widget> children,
  required List<double> measuredItemWidths,
  required double? measuredMoreWidth,
}) {
  if (!dynamicOverflow || maxWidth.isInfinite || maxWidth <= 0) {
    return _CommandBarOverflowResult(
      visibleChildren: children,
      overflowedChildren: const [],
    );
  }

  final itemWidths =
      children.indexed
          .map(
            (entry) =>
                measuredItemWidths.length > entry.$1 &&
                        measuredItemWidths[entry.$1] > 0
                    ? measuredItemWidths[entry.$1]
                    : _estimateCommandBarItemWidth(context, entry.$2),
          )
          .toList();
  final style = _CommandBarStyleScope.of(context);
  final availableWidth = (maxWidth - overflowReserve).clamp(0, maxWidth);
  final moreWidth = measuredMoreWidth ?? style.iconOnlyOuterWidth;
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
          (index, children[index] as CommandBarButton),
    ],
  );
}

MenuFlyoutItem _toMenuFlyoutItem(CommandBarButton button, int overflowIndex) {
  final hasSubmenu = !button.disabled && button.overflowSubmenu.isNotEmpty;
  return MenuFlyoutItem(
    key: 'commandbar-overflow-$overflowIndex',
    text: button.label,
    icon: button.icon,
    disabled: button.disabled,
    submenu: hasSubmenu ? button.overflowSubmenu : const [],
    onPressedWithContext:
        button.disabled || hasSubmenu
            ? null
            : button.onOverflowPressedWithContext ??
                (button.onOverflowPressed == null
                    ? button.onPressedWithContext ??
                        (button.onPressed == null
                            ? null
                            : (_) {
                              button.onPressed!();
                            })
                    : (_) {
                      button.onOverflowPressed!();
                    }),
  );
}

double _estimateCommandBarItemWidth(BuildContext context, Widget child) {
  if (child is! CommandBarButton) {
    return 80;
  }

  final style = _CommandBarStyleScope.of(context);
  if (!child.showLabel) {
    return style.iconOnlyOuterWidth;
  }

  final labelPainter = TextPainter(
    text: TextSpan(
      text: child.label,
      style: TextStyle(
        fontSize: style.fontSize,
        fontWeight: style.fontWeight,
        fontVariations: const [FontVariation.weight(650)],
      ),
    ),
    maxLines: 1,
    textDirection: Directionality.of(context),
  )..layout();
  final labelWidth = labelPainter.width;
  return (style.iconSize +
          style.iconGap +
          labelWidth +
          style.horizontalPadding * 2 +
          style.borderWidth * 2 +
          style.buttonMargin.horizontal)
      .ceilToDouble();
}

const _commandBarItemGap = 0.0;

class _CommandBarStyleScope extends InheritedWidget {
  const _CommandBarStyleScope({required this.data, required super.child});

  final _CommandBarStyleData data;

  static _CommandBarStyleData of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<_CommandBarStyleScope>();
    return scope?.data ?? _CommandBarStyleData.standard();
  }

  @override
  bool updateShouldNotify(covariant _CommandBarStyleScope oldWidget) {
    return oldWidget.data != data;
  }
}

class _CommandBarStyleData {
  const _CommandBarStyleData({
    required this.toolbarMinHeight,
    required this.visibleRowHeight,
    required this.toolbarPadding,
    required this.contentHorizontalPadding,
    required this.primaryAlignment,
    required this.visibleAlignment,
    required this.buttonMargin,
    required this.minWidth,
    required this.minHeight,
    required this.maxWidth,
    required this.horizontalPadding,
    required this.borderRadius,
    required this.borderWidth,
    required this.borderColor,
    required this.surface,
    required this.hoverSurface,
    required this.pressedSurface,
    required this.foreground,
    required this.highlightColor,
    required this.shadow,
    required this.disabledOpacity,
    required this.fontSize,
    required this.fontWeight,
    required this.iconSize,
    required this.iconGap,
    required this.transparent,
  });

  final double toolbarMinHeight;
  final double visibleRowHeight;
  final EdgeInsets toolbarPadding;
  final double contentHorizontalPadding;
  final MainAxisAlignment primaryAlignment;
  final Alignment visibleAlignment;
  final EdgeInsets buttonMargin;
  final double minWidth;
  final double minHeight;
  final double? maxWidth;
  final double horizontalPadding;
  final double borderRadius;
  final double borderWidth;
  final Color borderColor;
  final Color surface;
  final Color hoverSurface;
  final Color pressedSurface;
  final Color foreground;
  final Color highlightColor;
  final List<BoxShadow> shadow;
  final double disabledOpacity;
  final double fontSize;
  final FontWeight fontWeight;
  final double iconSize;
  final double iconGap;
  final bool transparent;

  double get iconOnlyOuterWidth =>
      minWidth + buttonMargin.horizontal + borderWidth * 2;

  Size? fixedButtonSize(bool showLabel) {
    if (showLabel || maxWidth != minWidth) {
      return null;
    }
    return Size(minWidth, minHeight);
  }

  Size minimumButtonSize(bool showLabel) {
    return Size(showLabel ? minWidth : minWidth, minHeight);
  }

  Size maximumButtonSize(bool showLabel) {
    if (showLabel && maxWidth != null) {
      return Size(maxWidth!, minHeight);
    }
    if (!showLabel) {
      return Size(minWidth, minHeight);
    }
    return const Size(double.infinity, double.infinity);
  }

  static _CommandBarStyleData standard() {
    return const _CommandBarStyleData(
      toolbarMinHeight: 48,
      visibleRowHeight: 48,
      toolbarPadding: EdgeInsets.zero,
      contentHorizontalPadding: 12,
      primaryAlignment: MainAxisAlignment.end,
      visibleAlignment: Alignment.centerRight,
      buttonMargin: EdgeInsets.symmetric(horizontal: 3, vertical: 4),
      minWidth: 44,
      minHeight: 40,
      maxWidth: null,
      horizontalPadding: 14,
      borderRadius: 10,
      borderWidth: 1,
      borderColor: CommandBarColors.buttonBorder,
      surface: CommandBarColors.buttonSurface,
      hoverSurface: CommandBarColors.buttonHoverSurface,
      pressedSurface: CommandBarColors.buttonPressedSurface,
      foreground: CommandBarColors.textStrong,
      highlightColor: CommandBarColors.buttonInsetHighlight,
      shadow: [],
      disabledOpacity: 0.45,
      fontSize: 14,
      fontWeight: FontWeight.w700,
      iconSize: 20,
      iconGap: 8,
      transparent: false,
    );
  }
}
