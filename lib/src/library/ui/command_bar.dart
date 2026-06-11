import 'dart:async';
import 'package:flutter/material.dart';
import 'package:smplayer_flutter/src/app/smplayer_vector_icons.dart';
import 'package:smplayer_flutter/src/app/text_icon_button.dart';
import 'package:smplayer_flutter/src/library/ui/command_bar_colors.dart';
import 'package:smplayer_flutter/src/library/ui/menu_flyout.dart';

enum CommandBarStyleVariant { standard, appBar, headeredPlaylist }

enum CommandBarPrimaryAlignment { start, end, center }

enum CommandBarContentSizing { flexible, intrinsic }

class CommandBar extends StatefulWidget {
  const CommandBar({
    super.key,
    this.content,
    this.contentSizing = CommandBarContentSizing.flexible,
    this.style = CommandBarStyleVariant.standard,
    this.dynamicOverflow = true,
    this.overflowReserve = 0,
    this.overflowItems = const [],
    this.overflowLabel,
    this.primaryAlignment = CommandBarPrimaryAlignment.end,
    required this.children,
  });

  final Widget? content;
  final CommandBarContentSizing contentSizing;
  final CommandBarStyleVariant style;
  final bool dynamicOverflow;
  final double overflowReserve;
  final List<MenuFlyoutItem> overflowItems;
  final String? overflowLabel;
  final CommandBarPrimaryAlignment primaryAlignment;
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
    final compact = MediaQuery.sizeOf(context).width <= 720;
    final style = switch (widget.style) {
      CommandBarStyleVariant.standard => _CommandBarStyleData.standard(
        compact: compact,
      ),
      CommandBarStyleVariant.appBar => _CommandBarStyleData.appBar(
        Theme.of(context).brightness,
      ),
      CommandBarStyleVariant.headeredPlaylist =>
        _CommandBarStyleData.headeredPlaylist(compact: compact),
    };
    _scheduleMeasure();
    final contentWidget =
        widget.content == null
            ? null
            : Padding(
              padding: EdgeInsets.symmetric(
                horizontal: style.contentHorizontalPadding,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: widget.content!,
              ),
            );
    final toolbar = ConstrainedBox(
      constraints: BoxConstraints(minHeight: style.toolbarMinHeight),
      child: Padding(
        padding: style.toolbarPadding,
        child: _CommandBarStyleScope(
          data: style,
          child: _CommandBarTextIconTheme(
            enabled: true,
            style: style,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (contentWidget != null)
                  if (widget.contentSizing == CommandBarContentSizing.intrinsic)
                    contentWidget
                  else
                    Flexible(fit: FlexFit.loose, child: contentWidget),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final maxWidth =
                          constraints.maxWidth.isFinite &&
                                  constraints.maxWidth > 0
                              ? constraints.maxWidth
                              : MediaQuery.sizeOf(context).width;
                      final overflow = _resolveCommandBarOverflow(
                        context: context,
                        maxWidth: maxWidth,
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
                      final measurementLayer = Positioned(
                        left: -100000,
                        top: 0,
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
                                    iconWidget:
                                        const SmPlayerMoreHorizontalIcon(),
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
                      );

                      Widget moreButton() {
                        return _CommandBarMoreButton(
                          label: widget.overflowLabel ?? 'More',
                          items: overflowMenuItems,
                        );
                      }

                      Widget visibleRow({required bool includeMore}) {
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final child in overflow.visibleChildren) child,
                            if (includeMore && overflowMenuItems.isNotEmpty)
                              moreButton(),
                          ],
                        );
                      }

                      final primaryRow =
                          widget.primaryAlignment !=
                                  CommandBarPrimaryAlignment.end
                              ? ClipRect(
                                child: Align(
                                  alignment:
                                      widget.primaryAlignment ==
                                              CommandBarPrimaryAlignment.center
                                          ? Alignment.center
                                          : Alignment.centerLeft,
                                  child: OverflowBox(
                                    minWidth: 0,
                                    maxWidth: double.infinity,
                                    minHeight: 0,
                                    maxHeight: style.visibleRowHeight,
                                    alignment:
                                        widget.primaryAlignment ==
                                                CommandBarPrimaryAlignment
                                                    .center
                                            ? Alignment.center
                                            : Alignment.centerLeft,
                                    child: visibleRow(includeMore: true),
                                  ),
                                ),
                              )
                              : Row(
                                mainAxisSize: MainAxisSize.max,
                                mainAxisAlignment: style.primaryAlignment,
                                children: [
                                  Expanded(
                                    child: ClipRect(
                                      child: Align(
                                        alignment: style.visibleAlignment,
                                        child: OverflowBox(
                                          minWidth: 0,
                                          maxWidth: double.infinity,
                                          minHeight: 0,
                                          maxHeight: style.visibleRowHeight,
                                          alignment: style.visibleAlignment,
                                          child: visibleRow(includeMore: false),
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (overflowMenuItems.isNotEmpty)
                                    moreButton(),
                                ],
                              );

                      return SizedBox(
                        width: maxWidth,
                        height: style.visibleRowHeight,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [measurementLayer, primaryRow],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
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
    required this.label,
    this.icon,
    this.iconWidget,
    this.useShuffleIcon = false,
    this.active = false,
    this.activeSurface = true,
    this.canOverflow = true,
    this.disabled = false,
    this.overflowSubmenu = const [],
    this.showLabel = true,
    this.minWidth,
    this.maxWidth,
    this.horizontalPadding,
    this.onOverflowPressed,
    this.onOverflowPressedWithContext,
    this.onPressed,
    this.onPressedWithContext,
  });

  final IconData? icon;
  final Widget? iconWidget;
  final bool useShuffleIcon;
  final String label;
  final bool active;
  final bool activeSurface;
  final bool canOverflow;
  final bool disabled;
  final List<MenuFlyoutItem> overflowSubmenu;
  final bool showLabel;
  final double? minWidth;
  final double? maxWidth;
  final double? horizontalPadding;
  final VoidCallback? onOverflowPressed;
  final FutureOr<void> Function(BuildContext context)?
  onOverflowPressedWithContext;
  final VoidCallback? onPressed;
  final FutureOr<void> Function(BuildContext context)? onPressedWithContext;

  @override
  State<CommandBarButton> createState() => _CommandBarButtonState();
}

class _CommandBarButtonState extends State<CommandBarButton> {
  @override
  Widget build(BuildContext context) {
    final style = _CommandBarStyleScope.of(context);
    return Padding(
      padding: style.buttonMargin,
      child: SmPlayerTextIconButton(
        icon: widget.icon,
        iconWidget: widget.iconWidget,
        label: widget.label,
        active: widget.active,
        activeSurface: widget.activeSurface,
        disabled: widget.disabled,
        showLabel: widget.showLabel,
        tooltip: widget.showLabel ? null : widget.label,
        minWidth: widget.minWidth ?? style.minWidth,
        maxWidth: widget.maxWidth ?? style.maxWidth,
        height: style.minHeight,
        horizontalPadding: widget.horizontalPadding ?? style.horizontalPadding,
        iconSize: style.iconSize,
        iconGap: style.iconGap,
        opacityWhenDisabled: style.disabledOpacity,
        borderRadius: style.borderRadius,
        fontSize: style.fontSize,
        fontWeight: style.fontWeight,
        fontVariations: style.fontVariations,
        onPressed: () {
          _activate(context);
        },
      ),
    );
  }

  void _activate(BuildContext context) {
    widget.onPressedWithContext?.call(context) ?? widget.onPressed?.call();
  }
}

class _CommandBarMoreButton extends StatelessWidget {
  const _CommandBarMoreButton({required this.label, required this.items});

  final String label;
  final List<MenuFlyoutItem> items;

  @override
  Widget build(BuildContext context) {
    return CommandBarButton(
      key: const ValueKey('CommandBar.MoreButton'),
      iconWidget: const SmPlayerMoreHorizontalIcon(),
      label: label,
      showLabel: false,
      canOverflow: false,
      onPressedWithContext: (buttonContext) {
        showMenuFlyout(buttonContext, items: items);
      },
    );
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
    useShuffleIcon: button.useShuffleIcon,
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
    return scope?.data ?? _CommandBarStyleData.standard(compact: false);
  }

  @override
  bool updateShouldNotify(covariant _CommandBarStyleScope oldWidget) {
    return oldWidget.data != data;
  }
}

class _CommandBarTextIconTheme extends StatelessWidget {
  const _CommandBarTextIconTheme({
    required this.enabled,
    required this.style,
    required this.child,
  });

  final bool enabled;
  final _CommandBarStyleData style;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return child;
    }
    final brightness = Theme.of(context).brightness;
    final dark = brightness == Brightness.dark;
    final baseColors = SmPlayerTextIconButtonColors.of(context);
    final hoverForeground =
        style.transparent
            ? dark
                ? CommandBarColors.appBarHoverForegroundDark
                : CommandBarColors.appBarHoverForeground
            : baseColors.commandTextHover;
    return SmPlayerTextIconButtonTheme(
      colors: baseColors.copyWith(
        commandText:
            !style.transparent && dark
                ? baseColors.commandText
                : style.foreground,
        commandTextHover: hoverForeground,
        control:
            !style.transparent && dark ? baseColors.control : style.surface,
        controlHover:
            !style.transparent ? baseColors.controlHover : style.hoverSurface,
        controlHoverBorder:
            !style.transparent
                ? baseColors.controlHoverBorder
                : style.borderColor,
        controlActive: CommandBarColors.accentSoft,
        controlBorder:
            !style.transparent && dark
                ? baseColors.controlBorder
                : style.borderColor,
        accentStrong: CommandBarColors.accentStrong,
      ),
      child: child,
    );
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
    required this.fontVariations,
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
  final List<FontVariation> fontVariations;
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

  static _CommandBarStyleData standard({required bool compact}) {
    return _CommandBarStyleData(
      toolbarMinHeight: compact ? 44 : 48,
      visibleRowHeight: compact ? 46 : 48,
      toolbarPadding: EdgeInsets.zero,
      contentHorizontalPadding: compact ? 8 : 12,
      primaryAlignment: MainAxisAlignment.end,
      visibleAlignment: Alignment.centerRight,
      buttonMargin: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
      minWidth: 44,
      minHeight: compact ? 38 : 40,
      maxWidth: null,
      horizontalPadding: compact ? 10 : 14,
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
      fontVariations: [FontVariation.weight(720)],
      iconSize: 20,
      iconGap: 8,
      transparent: false,
    );
  }

  static _CommandBarStyleData appBar(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return _CommandBarStyleData(
      toolbarMinHeight: 40,
      visibleRowHeight: 40,
      toolbarPadding: EdgeInsets.zero,
      contentHorizontalPadding: 0,
      primaryAlignment: MainAxisAlignment.end,
      visibleAlignment: Alignment.centerRight,
      buttonMargin: EdgeInsets.zero,
      minWidth: 40,
      minHeight: 40,
      maxWidth: 132,
      horizontalPadding: 10,
      borderRadius: 10,
      borderWidth: 0,
      borderColor: Colors.transparent,
      surface: Colors.transparent,
      hoverSurface:
          dark
              ? CommandBarColors.appBarHoverDark
              : CommandBarColors.appBarHover,
      pressedSurface:
          dark
              ? CommandBarColors.appBarPressedDark
              : CommandBarColors.appBarPressed,
      foreground:
          dark
              ? CommandBarColors.appBarForegroundDark
              : CommandBarColors.appBarForeground,
      highlightColor: Colors.transparent,
      shadow: const [],
      disabledOpacity: 0.45,
      fontSize: 14,
      fontWeight: FontWeight.w600,
      fontVariations: [FontVariation.weight(650)],
      iconSize: 19,
      iconGap: 7,
      transparent: true,
    );
  }

  static _CommandBarStyleData headeredPlaylist({required bool compact}) {
    return _CommandBarStyleData(
      toolbarMinHeight: compact ? 44 : 48,
      visibleRowHeight: compact ? 46 : 48,
      toolbarPadding: EdgeInsets.zero,
      contentHorizontalPadding: compact ? 8 : 12,
      primaryAlignment: MainAxisAlignment.start,
      visibleAlignment: Alignment.centerLeft,
      buttonMargin: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
      minWidth: 44,
      minHeight: compact ? 38 : 40,
      maxWidth: null,
      horizontalPadding: compact ? 10 : 12,
      borderRadius: 10,
      borderWidth: 1,
      borderColor: CommandBarColors.buttonBorder,
      surface: CommandBarColors.buttonSurface,
      hoverSurface: CommandBarColors.buttonHoverSurface,
      pressedSurface: CommandBarColors.buttonPressedSurface,
      foreground: CommandBarColors.textStrong,
      highlightColor: CommandBarColors.buttonInsetHighlight,
      shadow: const [],
      disabledOpacity: 0.45,
      fontSize: 14,
      fontWeight: FontWeight.w700,
      fontVariations: const [FontVariation.weight(720)],
      iconSize: 20,
      iconGap: 8,
      transparent: false,
    );
  }
}
