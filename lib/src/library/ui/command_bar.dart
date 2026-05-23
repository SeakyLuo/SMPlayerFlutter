import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smplayer_flutter/src/app/text_icon_button.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';

const multiSelectCommandBarScrollSpacer = 108.0;

enum CommandBarVariant {
  standard,
  playlistPage,
  headeredPlaylist,
  headeredPlaylistAppBar,
  appBar,
}

class CommandBar extends StatelessWidget {
  const CommandBar({
    super.key,
    this.content,
    this.variant = CommandBarVariant.standard,
    this.dynamicOverflow = true,
    this.overflowReserve = 0,
    this.overflowItems = const [],
    this.overflowLabel,
    required this.children,
  });

  final Widget? content;
  final CommandBarVariant variant;
  final bool dynamicOverflow;
  final double overflowReserve;
  final List<MenuFlyoutItem> overflowItems;
  final String? overflowLabel;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final style = _CommandBarStyleData.forVariant(
      variant,
      Theme.of(context).brightness == Brightness.dark,
    );
    final toolbar = ConstrainedBox(
      constraints: BoxConstraints(minHeight: style.toolbarMinHeight),
      child: Padding(
        padding: style.toolbarPadding,
        child: _CommandBarStyleScope(
          data: style,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (content != null)
                Flexible(
                  fit: FlexFit.loose,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: style.contentHorizontalPadding,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: content!,
                    ),
                  ),
                ),
              Expanded(
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
                      for (final entry in overflow.overflowedChildren.indexed)
                        _toMenuFlyoutItem(entry.$2, entry.$1),
                      ...overflowItems,
                    ];

                    return Row(
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
                                key: const ValueKey('CommandBar.MoreButton'),
                                icon: FluentIcons.more_horizontal_24_regular,
                                label: overflowLabel ?? 'More',
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
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (style.toolbarBackground == Colors.transparent &&
        style.toolbarBorderColor == Colors.transparent) {
      return toolbar;
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: style.toolbarBackground,
        borderRadius: BorderRadius.circular(style.toolbarRadius),
        border: Border.all(color: style.toolbarBorderColor),
      ),
      child: toolbar,
    );
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
  if (!dynamicOverflow || maxWidth.isInfinite || maxWidth <= 0) {
    return _CommandBarOverflowResult(
      visibleChildren: children,
      overflowedChildren: const [],
    );
  }

  final itemWidths =
      children
          .map((child) => _estimateCommandBarItemWidth(context, child))
          .toList();
  final style = _CommandBarStyleScope.of(context);
  final availableWidth = (maxWidth - overflowReserve).clamp(0, maxWidth);
  final moreWidth = style.iconOnlyOuterWidth;
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
    if (overflowedIndexes.length == overflowableIndexes.length - 1) {
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

MenuFlyoutItem _toMenuFlyoutItem(CommandBarButton button, int overflowIndex) {
  return MenuFlyoutItem(
    key: 'commandbar-overflow-$overflowIndex',
    text: button.label,
    icon: button.icon,
    disabled: button.disabled,
    submenu: button.disabled ? const [] : button.overflowSubmenu,
    onPressed: button.overflowSubmenu.isEmpty ? button.onOverflowPressed : null,
    onPressedWithContext:
        button.overflowSubmenu.isEmpty && button.onOverflowPressed == null
            ? button.onPressedWithContext ??
                (button.onPressed == null
                    ? null
                    : (_) {
                      button.onPressed!();
                    })
            : null,
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
    return scope?.data ??
        _CommandBarStyleData.forVariant(
          CommandBarVariant.standard,
          Theme.of(context).brightness == Brightness.dark,
        );
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
    required this.toolbarBackground,
    required this.toolbarBorderColor,
    required this.toolbarRadius,
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
  final Color toolbarBackground;
  final Color toolbarBorderColor;
  final double toolbarRadius;
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

  static _CommandBarStyleData forVariant(
    CommandBarVariant variant, [
    bool nightMode = false,
  ]) {
    switch (variant) {
      case CommandBarVariant.playlistPage:
        return const _CommandBarStyleData(
          toolbarMinHeight: 44,
          visibleRowHeight: 44,
          toolbarBackground: Colors.transparent,
          toolbarBorderColor: Colors.transparent,
          toolbarRadius: 0,
          toolbarPadding: EdgeInsets.zero,
          contentHorizontalPadding: 0,
          primaryAlignment: MainAxisAlignment.end,
          visibleAlignment: Alignment.centerRight,
          buttonMargin: EdgeInsets.only(right: 14),
          minWidth: 0,
          minHeight: 38,
          maxWidth: null,
          horizontalPadding: 13,
          borderRadius: 10,
          borderWidth: 1,
          borderColor: CommandBarColors.buttonBorder,
          surface: CommandBarColors.buttonSurface,
          hoverSurface: Color(0xc2ffffff),
          pressedSurface: CommandBarColors.buttonPressedSurface,
          foreground: CommandBarColors.textStrong,
          highlightColor: Color(0x61ffffff),
          shadow: [],
          disabledOpacity: 0.45,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          iconSize: 16,
          iconGap: 8,
          transparent: false,
        );
      case CommandBarVariant.headeredPlaylist:
        return _CommandBarStyleData(
          toolbarMinHeight: 48,
          visibleRowHeight: 48,
          toolbarBackground: Colors.transparent,
          toolbarBorderColor: Colors.transparent,
          toolbarRadius: 0,
          toolbarPadding: EdgeInsets.zero,
          contentHorizontalPadding: 12,
          primaryAlignment: MainAxisAlignment.start,
          visibleAlignment: Alignment.centerLeft,
          buttonMargin: EdgeInsets.symmetric(horizontal: 3, vertical: 4),
          minWidth: 0,
          minHeight: 40,
          maxWidth: null,
          horizontalPadding: 12,
          borderRadius: 10,
          borderWidth: 1,
          borderColor:
              nightMode ? const Color(0x1fd6e0ec) : const Color(0x2e768497),
          surface:
              nightMode ? const Color(0x0effffff) : const Color(0xa8ffffff),
          hoverSurface:
              nightMode ? const Color(0x17ffffff) : const Color(0xdbffffff),
          pressedSurface:
              nightMode ? const Color(0x1fffffff) : const Color(0xdbffffff),
          foreground:
              nightMode ? const Color(0xf0f6f9fc) : CommandBarColors.textStrong,
          highlightColor:
              nightMode ? const Color(0x0effffff) : const Color(0x9effffff),
          shadow: [
            BoxShadow(
              color:
                  nightMode ? const Color(0x38000000) : const Color(0x142d3a4c),
              offset: Offset(0, 10),
              blurRadius: 24,
            ),
          ],
          disabledOpacity: 0.54,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          iconSize: 17,
          iconGap: 8,
          transparent: false,
        );
      case CommandBarVariant.headeredPlaylistAppBar:
        return _CommandBarStyleData(
          toolbarMinHeight: 40,
          visibleRowHeight: 40,
          toolbarBackground: Colors.transparent,
          toolbarBorderColor: Colors.transparent,
          toolbarRadius: 0,
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
          borderColor: nightMode ? const Color(0x1fd6e0ec) : Colors.transparent,
          surface: Colors.transparent,
          hoverSurface:
              nightMode ? const Color(0x17ffffff) : const Color(0x12111827),
          pressedSurface:
              nightMode ? const Color(0x1fffffff) : const Color(0x12111827),
          foreground:
              nightMode ? const Color(0xf0f6f9fc) : CommandBarColors.textStrong,
          highlightColor: Colors.transparent,
          shadow: [],
          disabledOpacity: 0.45,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          iconSize: 19,
          iconGap: 7,
          transparent: true,
        );
      case CommandBarVariant.appBar:
        return const _CommandBarStyleData(
          toolbarMinHeight: 40,
          visibleRowHeight: 40,
          toolbarBackground: Colors.transparent,
          toolbarBorderColor: Colors.transparent,
          toolbarRadius: 0,
          toolbarPadding: EdgeInsets.zero,
          contentHorizontalPadding: 0,
          primaryAlignment: MainAxisAlignment.end,
          visibleAlignment: Alignment.centerRight,
          buttonMargin: EdgeInsets.zero,
          minWidth: 40,
          minHeight: 40,
          maxWidth: 40,
          horizontalPadding: 0,
          borderRadius: 10,
          borderWidth: 0,
          borderColor: Colors.transparent,
          surface: Colors.transparent,
          hoverSurface: Color(0x12111827),
          pressedSurface: Color(0x12111827),
          foreground: CommandBarColors.textStrong,
          highlightColor: Colors.transparent,
          shadow: [],
          disabledOpacity: 0.45,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          iconSize: 19,
          iconGap: 0,
          transparent: true,
        );
      case CommandBarVariant.standard:
        return const _CommandBarStyleData(
          toolbarMinHeight: 48,
          visibleRowHeight: 48,
          toolbarBackground: Colors.transparent,
          toolbarBorderColor: Colors.transparent,
          toolbarRadius: 0,
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
}

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
                                              fontWeight: FontWeight.w800,
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
                                            icon: const Icon(
                                              FluentIcons
                                                  .more_horizontal_24_regular,
                                              size: 16,
                                            ),
                                            style: _multiSelectMoreButtonStyle(
                                              compactPhone,
                                            ),
                                            onPressed: () {
                                              showMenuFlyout(
                                                moreButtonContext,
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
    this.pendingText,
    this.icon,
    this.iconColor,
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

List<MenuFlyoutItem> buildShuffleMenuFlyoutItems({
  required SmPlayerI18n i18n,
  required List<LibrarySong> songs,
  required List<LibrarySong> librarySongs,
  required List<LibrarySong> recentSongs,
  required List<LibraryPlaylist> playlists,
  required List<LibraryFolder> folders,
  required int randomLimit,
  required ValueChanged<List<int>> onPlaySongs,
  FutureOr<void> Function()? onQuickPlay,
}) {
  void playSongs(List<LibrarySong> sourceSongs) {
    onPlaySongs(_randomLibrary(sourceSongs, randomLimit));
  }

  void playAllSongs(List<LibrarySong> sourceSongs) {
    onPlaySongs(_shuffleSongIds(sourceSongs));
  }

  final playableFolders =
      folders
          .where(
            (folder) => librarySongs.any(
              (song) => _isSongDirectlyInFolder(song, folder.path),
            ),
          )
          .toList();
  final playablePlaylists =
      playlists.where((playlist) => playlist.songIds.isNotEmpty).toList();
  final items = <MenuFlyoutItem>[
    MenuFlyoutItem(
      key: 'quick',
      text: i18n.t('nowPlaying.quickPlay'),
      onPressed: onQuickPlay ?? () => playSongs(librarySongs),
    ),
  ];

  if (songs.isNotEmpty) {
    items.addAll([
      const MenuFlyoutItem.separator(key: 'now-playing-separator'),
      MenuFlyoutItem(
        key: 'now-playing',
        text: i18n.t('common.nowPlaying'),
        onPressed: () => playAllSongs(songs),
      ),
    ]);
  }

  if (librarySongs.isEmpty) {
    return items;
  }

  items.addAll([
    const MenuFlyoutItem.separator(key: 'shuffle-library-separator'),
    MenuFlyoutItem(
      key: 'library',
      text: i18n.t('random.musicLibrary'),
      onPressed: () => playSongs(librarySongs),
    ),
    MenuFlyoutItem(
      key: 'artist',
      text: i18n.t('common.artist'),
      onPressed: () => onPlaySongs(_randomArtist(librarySongs, randomLimit)),
    ),
    MenuFlyoutItem(
      key: 'album',
      text: i18n.t('common.album'),
      onPressed: () => onPlaySongs(_randomAlbum(librarySongs, randomLimit)),
    ),
  ]);

  if (playablePlaylists.isNotEmpty) {
    items.add(
      MenuFlyoutItem(
        key: 'playlist',
        text: i18n.t('common.playlist'),
        onPressed: () {
          onPlaySongs(
            _randomPlaylist(librarySongs, playablePlaylists, randomLimit),
          );
        },
      ),
    );
  }

  if (playableFolders.isNotEmpty) {
    items.add(
      MenuFlyoutItem(
        key: 'folder',
        text: i18n.t('random.localFolder'),
        onPressed: () {
          onPlaySongs(
            _randomFolder(librarySongs, playableFolders, randomLimit),
          );
        },
      ),
    );
  }

  items.add(
    MenuFlyoutItem(
      key: 'recent-added',
      text: i18n.t('common.recentAdded'),
      onPressed:
          () => onPlaySongs(_randomRecentAdded(librarySongs, randomLimit)),
    ),
  );

  if (recentSongs.isNotEmpty) {
    items.add(
      MenuFlyoutItem(
        key: 'recent-played',
        text: i18n.t('random.recentPlayed'),
        onPressed: () => onPlaySongs(_shuffleSongIds(recentSongs)),
      ),
    );
  }

  if (librarySongs.length > randomLimit) {
    items.addAll([
      const MenuFlyoutItem.separator(key: 'shuffle-history-separator'),
      MenuFlyoutItem(
        key: 'most-played',
        text: i18n.t('random.mostPlayed'),
        onPressed:
            () => onPlaySongs(_randomMostPlayed(librarySongs, randomLimit)),
      ),
      MenuFlyoutItem(
        key: 'least-played',
        text: i18n.t('random.leastPlayed'),
        onPressed:
            () => onPlaySongs(_randomLeastPlayed(librarySongs, randomLimit)),
      ),
    ]);
  }

  return items;
}

List<int> _randomLibrary(List<LibrarySong> songs, int randomLimit) {
  return _randomItems(songs, randomLimit).map((song) => song.id).toList();
}

List<int> _shuffleSongIds(List<LibrarySong> songs) {
  final shuffled = songs.toList()..shuffle(Random());
  return shuffled.map((song) => song.id).toList();
}

List<int> _randomArtist(List<LibrarySong> songs, int randomLimit) {
  final songsByArtist = <String, List<LibrarySong>>{};
  for (final song in songs) {
    final artists = song.artists.isEmpty ? [song.artist] : song.artists;
    for (final artist in artists) {
      songsByArtist[artist] = [...(songsByArtist[artist] ?? []), song];
    }
  }
  final group = _randomItem(songsByArtist.values.toList());
  return _randomItems(group, randomLimit).map((song) => song.id).toList();
}

List<int> _randomAlbum(List<LibrarySong> songs, int randomLimit) {
  return _randomItems(
    _randomSongGroup(songs, (song) => song.album),
    randomLimit,
  ).map((song) => song.id).toList();
}

List<int> _randomPlaylist(
  List<LibrarySong> songs,
  List<LibraryPlaylist> playlists,
  int randomLimit,
) {
  final songsById = {for (final song in songs) song.id: song};
  final playlist = _randomItem(playlists);
  final playlistSongs =
      playlist.songIds
          .map((songId) => songsById[songId])
          .whereType<LibrarySong>()
          .toList();
  return _randomItems(
    playlistSongs,
    randomLimit,
  ).map((song) => song.id).toList();
}

List<int> _randomFolder(
  List<LibrarySong> songs,
  List<LibraryFolder> folders,
  int randomLimit,
) {
  final playableFolders =
      folders
          .map(
            (folder) => (
              folder: folder,
              songs:
                  songs
                      .where(
                        (song) => _isSongDirectlyInFolder(song, folder.path),
                      )
                      .toList(),
            ),
          )
          .where((entry) => entry.songs.isNotEmpty)
          .toList();
  if (playableFolders.isEmpty) {
    return const [];
  }
  return _randomItems(
    _randomItem(playableFolders).songs,
    randomLimit,
  ).map((song) => song.id).toList();
}

List<int> _randomRecentAdded(List<LibrarySong> songs, int randomLimit) {
  final sorted =
      songs.toList()
        ..sort((left, right) => right.dateAdded.compareTo(left.dateAdded));
  return _randomItems(
    sorted.take(500).toList(),
    randomLimit,
  ).map((song) => song.id).toList();
}

List<int> _randomMostPlayed(List<LibrarySong> songs, int randomLimit) {
  return _shuffleSongIds(
    _playedSongs(songs, randomLimit, descending: true),
  ).take(randomLimit).toList();
}

List<int> _randomLeastPlayed(List<LibrarySong> songs, int randomLimit) {
  return _shuffleSongIds(
    _playedSongs(songs, randomLimit, descending: false),
  ).take(randomLimit).toList();
}

List<LibrarySong> _playedSongs(
  List<LibrarySong> songs,
  int randomLimit, {
  required bool descending,
}) {
  final songsByPlayCount = <int, List<LibrarySong>>{};
  for (final song in songs) {
    songsByPlayCount[song.playCount] = [
      ...(songsByPlayCount[song.playCount] ?? const <LibrarySong>[]),
      song,
    ];
  }

  final playCounts =
      songsByPlayCount.keys.toList()..sort(
        (left, right) =>
            descending ? right.compareTo(left) : left.compareTo(right),
      );
  final selectedSongs = <LibrarySong>[];
  for (final playCount in playCounts) {
    if (selectedSongs.length > randomLimit) {
      break;
    }
    selectedSongs.addAll(songsByPlayCount[playCount]!);
  }
  return selectedSongs;
}

List<LibrarySong> _randomSongGroup(
  List<LibrarySong> songs,
  String Function(LibrarySong song) getKey,
) {
  final groups = <String, List<LibrarySong>>{};
  for (final song in songs) {
    final key = getKey(song);
    groups[key] = [...(groups[key] ?? []), song];
  }
  return _randomItem(groups.values.toList()).toList()..shuffle(Random());
}

List<T> _randomItems<T>(List<T> items, int count) {
  if (items.length <= count) {
    return items.toList()..shuffle(Random());
  }

  final indices = <int>{};
  final random = Random();
  while (indices.length < count) {
    indices.add(random.nextInt(items.length));
  }
  return [for (final index in indices) items[index]];
}

T _randomItem<T>(List<T> items) {
  return items[Random().nextInt(items.length)];
}

bool _isSongDirectlyInFolder(LibrarySong song, String folderPath) {
  return _getFileParentPath(song.path) == folderPath;
}

String _getFileParentPath(String path) {
  final separatorIndex = max(path.lastIndexOf('\\'), path.lastIndexOf('/'));
  return separatorIndex > -1 ? path.substring(0, separatorIndex) : '';
}

const _preferenceLevels = [
  'do-not-appear',
  'dislike',
  'normal',
  'high',
  'higher',
  'very-high',
];

MenuFlyoutItem buildPreferenceMenuFlyoutItem({
  required SmPlayerI18n i18n,
  required String key,
  required String? preferenceLevel,
  FutureOr<void> Function()? onUndoPreference,
  required FutureOr<void> Function(String level) onSetPreference,
}) {
  return MenuFlyoutItem(
    key: key,
    text: i18n.t('settings.preferenceSettings'),
    icon: FluentIcons.star_20_regular,
    submenu: [
      if (preferenceLevel != null && onUndoPreference != null) ...[
        MenuFlyoutItem(
          key: '$key-undo',
          text: i18n.t('preferences.undoPrefer'),
          onPressed: onUndoPreference,
        ),
        MenuFlyoutItem.separator(key: '$key-undo-separator'),
      ],
      for (final level in _preferenceLevels)
        MenuFlyoutItem(
          key: '$key-$level',
          text: i18n.t('preferences.level.$level'),
          icon:
              preferenceLevel == level
                  ? FluentIcons.checkmark_20_regular
                  : null,
          onPressed: () => onSetPreference(level),
        ),
    ],
  );
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
  required FutureOr<void> Function() onSeeLocal,
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
      buildPreferenceMenuFlyoutItem(
        i18n: i18n,
        key: 'preference',
        preferenceLevel: preferenceLevel,
        onUndoPreference: onUndoPreference,
        onSetPreference: onSetPreference,
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
  if (showMusicProperties) {
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
    viewItems.addAll([
      MenuFlyoutItem(
        key: 'see-music-info',
        text: i18n.t('context.seeMusicInfo'),
        icon: FluentIcons.info_20_regular,
        keepOpen: true,
        onPressed: onSeeMusicInfo,
      ),
      MenuFlyoutItem(
        key: 'see-lyrics',
        text: i18n.t('context.seeLyrics'),
        icon: FluentIcons.text_grammar_wand_20_regular,
        keepOpen: true,
        onPressed: onSeeLyrics,
      ),
      if (showAlbumArt)
        MenuFlyoutItem(
          key: 'see-album-art',
          text: i18n.t('context.seeAlbumArt'),
          icon: FluentIcons.image_20_regular,
          keepOpen: true,
          onPressed: onSeeAlbumArt,
        ),
      MenuFlyoutItem(
        key: 'see-local',
        text: i18n.t('context.seeLocalFile'),
        icon: FluentIcons.folder_open_20_regular,
        pendingText: i18n.t('context.openingLocal'),
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

Future<void> showMenuFlyout(
  BuildContext context, {
  required List<MenuFlyoutItem> items,
  Offset? position,
  bool avoidPlayerBar = true,
  MenuFlyoutLayer layer = MenuFlyoutLayer.defaultLayer,
}) {
  final overlay = Overlay.of(
    context,
    rootOverlay: layer == MenuFlyoutLayer.dialog,
  );
  final button = context.findRenderObject() as RenderBox;
  final resolvedPosition =
      position ?? button.localToGlobal(Offset(0, button.size.height + 4));

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
          anchorContext: context,
          requestedPosition: resolvedPosition,
          avoidPlayerBar: avoidPlayerBar,
          onClose: close,
        ),
  );
  overlay.insert(entry);
  return completer.future;
}

const _menuFlyoutMargin = 8.0;
const _menuFlyoutWidth = 206.0;
const _menuFlyoutSubmenuWidth = 260.0;
const _menuFlyoutMaxWidth = 280.0;
const _menuFlyoutSubmenuMaxWidth = 380.0;
const _menuFlyoutPadding = 6.0;
const _menuFlyoutItemHeight = 34.0;
const _menuFlyoutSeparatorHeight = 13.0;
const _menuFlyoutPlayerBarHeight = 120.0;

class _MenuFlyoutOverlay extends StatefulWidget {
  const _MenuFlyoutOverlay({
    required this.items,
    required this.anchorContext,
    required this.requestedPosition,
    required this.avoidPlayerBar,
    required this.onClose,
  });

  final List<MenuFlyoutItem> items;
  final BuildContext anchorContext;
  final Offset requestedPosition;
  final bool avoidPlayerBar;
  final VoidCallback onClose;

  @override
  State<_MenuFlyoutOverlay> createState() => _MenuFlyoutOverlayState();
}

class _MenuFlyoutOverlayState extends State<_MenuFlyoutOverlay> {
  late List<_MenuFlyoutPanelState> _panels;
  final _focusNode = FocusNode(debugLabel: 'MenuFlyoutOverlay');

  @override
  void initState() {
    super.initState();
    _panels = [
      _MenuFlyoutPanelState(
        items: widget.items,
        position: widget.requestedPosition,
      ),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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

  List<_MenuFlyoutPanelState> _resolvedPanels(
    Size size,
    double boundaryBottom,
  ) {
    return [
      for (var index = 0; index < _panels.length; index++)
        _panels[index].resolve(
          size: size,
          boundaryBottom: boundaryBottom,
          width:
              index == 0
                  ? _menuFlyoutWidth.clamp(
                    0,
                    size.width - _menuFlyoutMargin * 2,
                  )
                  : _menuFlyoutSubmenuWidth.clamp(
                    0,
                    size.width - _menuFlyoutMargin * 2,
                  ),
          maxWidth:
              index == 0 ? _menuFlyoutMaxWidth : _menuFlyoutSubmenuMaxWidth,
        ),
    ];
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
    final panelWidth = _menuFlyoutSubmenuWidth.clamp(
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
    final colors = _MenuFlyoutColors.of(context);
    final maxHeight = boundaryBottom - _menuFlyoutMargin;
    return Positioned(
      left: state.position.dx,
      top: state.position.dy,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: depth == 0 ? _menuFlyoutWidth : _menuFlyoutSubmenuWidth,
          maxWidth:
              depth == 0 ? _menuFlyoutMaxWidth : _menuFlyoutSubmenuMaxWidth,
          maxHeight: maxHeight,
        ),
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
            child: ListView(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              children: [
                for (final item in state.items)
                  _MenuFlyoutItemWidget(
                    item: item,
                    depth: depth,
                    anchorContext: anchorContext,
                    onClose: onClose,
                    onItemEntered: onItemEntered,
                    onSubmenuEntered: onSubmenuEntered,
                  ),
              ],
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

    final colors = _MenuFlyoutColors.of(context);
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
                    item.icon == null
                        ? null
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
                  style: TextStyle(color: foreground, fontSize: 13, height: 1),
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
  return _menuFlyoutPadding * 2 +
      items.fold<double>(0, (height, item) {
        if (item.separator) {
          return height + _menuFlyoutSeparatorHeight;
        }
        if (item.content != null) {
          return height + item.contentHeight;
        }
        return height + _menuFlyoutItemHeight;
      });
}

class _MenuFlyoutColors {
  const _MenuFlyoutColors({
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

  static _MenuFlyoutColors of(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (dark) {
      return const _MenuFlyoutColors(
        surface: Color(0xfa181e26),
        border: Color(0x30d6e0ec),
        shadow: Color(0x5c000000),
        text: Colors.white,
        hoverText: Colors.white,
        disabledText: Color(0x8fffffff),
        hoverSurface: Color(0x2e0078d7),
        checked: Colors.white,
      );
    }
    return const _MenuFlyoutColors(
      surface: Color(0xffffffff),
      border: Color(0x337e8b9a),
      shadow: Color(0x2e263344),
      text: Color(0xff1f252b),
      hoverText: Color(0xff0063b1),
      disabledText: Color(0x751f252b),
      hoverSurface: Color(0x1a0078d7),
      checked: Color(0xff0063b1),
    );
  }
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
      height: 28,
      margin: const EdgeInsets.symmetric(horizontal: 9),
      color: CommandBarColors.separator,
    );
  }
}

class CommandBarColors {
  const CommandBarColors._();

  static const surface = Color(0xb8ffffff);
  static const buttonSurface = Color(0x8fffffff);
  static const buttonHoverSurface = Color(0xbdffffff);
  static const buttonPressedSurface = Color(0xdbffffff);
  static const buttonBorder = Color(0x24536379);
  static const buttonInsetHighlight = Color(0x6bffffff);
  static const multiSelectSurface = Color(0xadf6faff);
  static const multiSelectGradientTop = Color(0xc7f9fcff);
  static const multiSelectGradientBottom = Color(0x94eaf1f9);
  static const multiSelectBorder = Color(0x9effffff);
  static const multiSelectInsetHighlight = Color(0xc7ffffff);
  static const actionSurface = Color(0xb3ffffff);
  static const actionBorder = Color(0x2e7e8b9a);
  static const border = Color(0x2b64748b);
  static const separator = Color(0x385c6776);
  static const text = Color(0xff344054);
  static const textStrong = Color(0xff111827);
  static const disabledText = Color(0x615b697a);
  static const accentStrong = Color(0xff0063b1);
  static const accentSoft = Color(0x1a0078d7);
  static const accentBorder = Color(0x570078d7);
  static const multiSelectShadow = Color(0x2e2f425c);
}
