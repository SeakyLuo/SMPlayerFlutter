part of 'music_dialog.dart';

class _MusicDialogCommandBar extends StatefulWidget {
  const _MusicDialogCommandBar({required this.children, this.showBusy});

  final List<Widget> children;
  final bool? showBusy;

  @override
  State<_MusicDialogCommandBar> createState() => _MusicDialogCommandBarState();
}

class _MusicDialogCommandBarState extends State<_MusicDialogCommandBar> {
  late List<GlobalKey> _itemKeys;
  final _moreKey = GlobalKey();
  var _itemWidths = <double>[];
  double? _measuredMoreWidth;
  var _measureScheduled = false;

  @override
  void initState() {
    super.initState();
    _itemKeys = _newCommandBarItemKeys(widget.children.length);
    _itemWidths = List.filled(widget.children.length, 0);
  }

  @override
  void didUpdateWidget(covariant _MusicDialogCommandBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.children.length != widget.children.length) {
      _itemKeys = _newCommandBarItemKeys(widget.children.length);
      _itemWidths = List.filled(widget.children.length, 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mobile =
        MediaQuery.sizeOf(context).width <= popupDialogMobileBreakpoint;
    final showBusy =
        widget.showBusy ?? _inferMusicDialogCommandBarBusy(widget.children);
    _scheduleMeasure();
    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding:
            mobile
                ? const EdgeInsets.fromLTRB(12, 0, 12, 12)
                : const EdgeInsets.fromLTRB(28, 0, 28, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final maxWidth =
                      constraints.maxWidth.isFinite && constraints.maxWidth > 0
                          ? constraints.maxWidth
                          : MediaQuery.sizeOf(context).width;
                  final overflow = _resolveMusicDialogCommandBarOverflow(
                    context: context,
                    maxWidth: maxWidth,
                    children: widget.children,
                    measuredItemWidths: _itemWidths,
                    measuredMoreWidth: _measuredMoreWidth,
                  );
                  final overflowMenuItems = [
                    for (final entry in overflow.overflowedChildren)
                      _musicDialogCommandButtonToMenuFlyoutItem(
                        entry.$2,
                        entry.$1,
                      ),
                  ];
                  const rowHeight = 48.0;
                  const measurementLayer = SizedBox.shrink();

                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Align(
                            alignment: Alignment.centerRight,
                            child: SizedBox(
                              width: constraints.maxWidth,
                              height: rowHeight,
                              child: OverflowBox(
                                minWidth: 0,
                                maxWidth: double.infinity,
                                minHeight: rowHeight,
                                maxHeight: rowHeight,
                                alignment: Alignment.centerRight,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    for (final child
                                        in overflow.visibleChildren)
                                      _asMusicDialogCommandBarChild(child),
                                    if (showBusy)
                                      const _MusicDialogSaveProgress(),
                                    if (overflowMenuItems.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 4,
                                        ),
                                        child: _MusicDialogMoreCommandButton(
                                          label: context.smPlayerI18n.t(
                                            'player.more',
                                          ),
                                          items: overflowMenuItems,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      measurementLayer,
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _scheduleMeasure() {
    if (_measureScheduled) {
      return;
    }
    _measureScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _measureScheduled = false;
      var changed = false;
      final nextWidths = List<double>.from(_itemWidths);
      for (var index = 0; index < _itemKeys.length; index += 1) {
        final width = _outerWidthForKey(_itemKeys[index]);
        if (width == null) {
          continue;
        }
        if (index >= nextWidths.length) {
          nextWidths.add(width);
          changed = true;
          continue;
        }
        if ((nextWidths[index] - width).abs() > 0.5) {
          nextWidths[index] = width;
          changed = true;
        }
      }
      final moreWidth = _outerWidthForKey(_moreKey);
      if (moreWidth != null &&
          ((_measuredMoreWidth ?? 0) - moreWidth).abs() > 0.5) {
        _measuredMoreWidth = moreWidth;
        changed = true;
      }
      if (changed) {
        setState(() {
          _itemWidths = nextWidths;
        });
      }
    });
  }
}

bool _inferMusicDialogCommandBarBusy(List<Widget> children) {
  return children.any(
    (child) =>
        child is _MusicDialogCommandButton && child.primary && child.disabled,
  );
}

class _MusicDialogCommandBarOverflowResult {
  const _MusicDialogCommandBarOverflowResult({
    required this.visibleChildren,
    required this.overflowedChildren,
  });

  final List<Widget> visibleChildren;
  final List<(int, _MusicDialogCommandButton)> overflowedChildren;
}

_MusicDialogCommandBarOverflowResult _resolveMusicDialogCommandBarOverflow({
  required BuildContext context,
  required double maxWidth,
  required List<Widget> children,
  required List<double> measuredItemWidths,
  required double? measuredMoreWidth,
}) {
  if (maxWidth.isInfinite || maxWidth <= 0) {
    return _MusicDialogCommandBarOverflowResult(
      visibleChildren: children,
      overflowedChildren: const [],
    );
  }

  final overflowableIndexes = <int>[];
  var totalWidth = 0.0;
  for (var index = 0; index < children.length; index += 1) {
    totalWidth += _musicDialogCommandBarItemOverflowWidth(
      context: context,
      child: children[index],
      measuredItemWidths: measuredItemWidths,
      index: index,
    );
    final child = children[index];
    if (child is _MusicDialogCommandButton && child.canOverflow) {
      overflowableIndexes.add(index);
    }
  }

  final effectiveMaxWidth = math.max(0.0, maxWidth);
  if (children.any((child) => child is _LyricsTimestampToggle)) {
    final estimatedTotalWidth = children.fold<double>(
      0,
      (total, child) =>
          total +
          _estimateMusicDialogCommandBarItemWidth(context, child) +
          (child is _MusicDialogCommandButton ? 6 : 0),
    );
    if (estimatedTotalWidth <= effectiveMaxWidth || effectiveMaxWidth >= 616) {
      return _MusicDialogCommandBarOverflowResult(
        visibleChildren: children,
        overflowedChildren: const [],
      );
    }
  }
  final moreWidth = measuredMoreWidth ?? 52.0;
  final overflowedIndexes = <int>{};
  final reservedMoreWidth = totalWidth > effectiveMaxWidth ? moreWidth : 0.0;
  for (final index in overflowableIndexes.reversed) {
    if (totalWidth + reservedMoreWidth <= effectiveMaxWidth) {
      break;
    }
    overflowedIndexes.add(index);
    totalWidth -= _musicDialogCommandBarItemOverflowWidth(
      context: context,
      child: children[index],
      measuredItemWidths: measuredItemWidths,
      index: index,
    );
  }
  return _MusicDialogCommandBarOverflowResult(
    visibleChildren: [
      for (var index = 0; index < children.length; index += 1)
        if (!overflowedIndexes.contains(index)) children[index],
    ],
    overflowedChildren: [
      for (final index in overflowableIndexes)
        if (overflowedIndexes.contains(index))
          (index, children[index] as _MusicDialogCommandButton),
    ],
  );
}

double _musicDialogCommandBarItemOverflowWidth({
  required BuildContext context,
  required Widget child,
  required List<double> measuredItemWidths,
  required int index,
}) {
  final estimated = _estimateMusicDialogCommandBarItemWidth(context, child);
  if (child is _MusicDialogCommandButton || child is _LyricsTimestampToggle) {
    return estimated;
  }
  final measured =
      index < measuredItemWidths.length && measuredItemWidths[index] > 0
          ? measuredItemWidths[index]
          : 0.0;
  return measured > 0 ? measured : estimated;
}

MenuFlyoutItem _musicDialogCommandButtonToMenuFlyoutItem(
  _MusicDialogCommandButton button,
  int overflowIndex,
) {
  return MenuFlyoutItem(
    key: 'music-dialog-commandbar-overflow-$overflowIndex',
    text: button.label,
    icon: button.icon,
    iconWidget: button.iconWidget,
    disabled: button.disabled,
    onPressed: button.disabled ? null : button.onPressed,
  );
}

Widget _asMusicDialogCommandBarChild(Widget child) {
  late final Widget result;
  if (child is! _MusicDialogCommandButton || child.commandBar) {
    result = child;
  } else {
    result = _MusicDialogCommandButton(
      key: child.key,
      icon: child.icon,
      iconWidget: child.iconWidget,
      label: child.label,
      primary: child.primary,
      disabled: child.disabled,
      commandBar: true,
      compact: child.compact,
      showLabel: child.showLabel,
      canOverflow: child.canOverflow,
      onPressed: child.onPressed,
    );
  }
  if (child is _MusicDialogCommandButton || child is _ArtworkSourceButton) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: result,
    );
  }
  return result;
}

double _estimateMusicDialogCommandBarItemWidth(
  BuildContext context,
  Widget child,
) {
  if (child is! _MusicDialogCommandButton) {
    if (child is _ArtworkSourceButton) {
      final labelPainter = TextPainter(
        text: TextSpan(
          text: context.smPlayerI18n.t('song.changeArtwork'),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            fontVariations: [FontVariation.weight(720)],
          ),
        ),
        maxLines: 1,
        textDirection: Directionality.of(context),
      )..layout();
      return (28 + 20 + 8 + labelPainter.width).ceilToDouble();
    }
    if (child is _LyricsTimestampToggle) {
      final labelPainter = TextPainter(
        text: TextSpan(
          text: context.smPlayerI18n.t('song.showLyricsTimestamps'),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            fontVariations: [FontVariation.weight(650)],
          ),
        ),
        maxLines: 1,
        textDirection: Directionality.of(context),
      )..layout();
      return (24 + 18 + 8 + labelPainter.width).ceilToDouble();
    }
    return 300;
  }
  if (!child.showLabel) {
    return 50;
  }
  final mobile =
      MediaQuery.sizeOf(context).width <= popupDialogMobileBreakpoint;
  final labelPainter = TextPainter(
    text: TextSpan(
      text: child.label,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        fontVariations: [FontVariation.weight(720)],
      ),
    ),
    maxLines: 1,
    textDirection: Directionality.of(context),
  )..layout();
  final iconWidth = child.icon == null && child.iconWidget == null ? 0.0 : 20.0;
  final iconGap = iconWidth == 0 ? 0.0 : 8.0;
  final horizontalPadding = mobile ? 20.0 : 28.0;
  return (horizontalPadding + iconGap + iconWidth + labelPainter.width)
      .ceilToDouble();
}

List<GlobalKey> _newCommandBarItemKeys(int count) {
  return List.generate(count, (_) => GlobalKey());
}

double? _outerWidthForKey(GlobalKey key) {
  final box = key.currentContext?.findRenderObject() as RenderBox?;
  if (box == null || !box.hasSize) {
    return null;
  }
  return box.size.width;
}

class _MusicDialogSaveProgress extends StatefulWidget {
  const _MusicDialogSaveProgress();

  @override
  State<_MusicDialogSaveProgress> createState() =>
      _MusicDialogSaveProgressState();
}

class _MusicDialogSaveProgressState extends State<_MusicDialogSaveProgress>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1050),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = PopupDialogColors.resolve(context);
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: SizedBox(
          key: const ValueKey('MusicDialog.SaveProgress'),
          height: 3,
          width: 0,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.accent.withValues(alpha: 0.12),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                return AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return Stack(
                      clipBehavior: Clip.hardEdge,
                      children: [
                        Positioned(
                          left: (-0.36 + 1.368 * _controller.value) * width,
                          top: 0,
                          bottom: 0,
                          width: width * 0.36,
                          child: child!,
                        ),
                      ],
                    );
                  },
                  child: ColoredBox(color: colors.accent),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _SongDialogLoading extends StatelessWidget {
  const _SongDialogLoading();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportHeight = MediaQuery.sizeOf(context).height;
        return Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: EdgeInsets.only(top: math.min(180, viewportHeight * 0.28)),
            child: const _SongDialogLoadingIndicator(),
          ),
        );
      },
    );
  }
}

class _SongDialogLoadingIndicator extends StatelessWidget {
  const _SongDialogLoadingIndicator();

  @override
  Widget build(BuildContext context) {
    final colors = PopupDialogColors.resolve(context);
    return SizedBox.square(
      key: const ValueKey('MusicDialog.LoadingSpinner'),
      dimension: 38,
      child: CircularProgressIndicator(
        strokeWidth: 3,
        color: colors.accent,
        backgroundColor: colors.accent.withValues(alpha: 0.16),
      ),
    );
  }
}

class _SongDialogScrollableBody extends StatefulWidget {
  const _SongDialogScrollableBody({required this.child, required this.padding});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  State<_SongDialogScrollableBody> createState() =>
      _SongDialogScrollableBodyState();
}

class _SongDialogScrollableBodyState extends State<_SongDialogScrollableBody> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SongDialogScrollbarHost(
      controller: _controller,
      right: 5,
      bottom: 0,
      child: SingleChildScrollView(
        controller: _controller,
        padding: widget.padding,
        child: widget.child,
      ),
    );
  }
}

class _SongDialogScrollbarHost extends StatefulWidget {
  const _SongDialogScrollbarHost({
    required this.controller,
    required this.child,
    required this.right,
    this.bottom = 0,
    this.trackWidth = 9,
    this.normalThumbLeft = 2,
    this.normalThumbRight = 2,
    this.hoverThumbLeft = 1,
    this.hoverThumbRight = 1,
    this.frameKey,
    this.positionKey = const ValueKey('MusicDialog.BodyScrollbar.Position'),
    this.thumbKey = const ValueKey('MusicDialog.BodyScrollbar.Thumb'),
  });

  final ScrollController controller;
  final Widget child;
  final double right;
  final double bottom;
  final double trackWidth;
  final double normalThumbLeft;
  final double normalThumbRight;
  final double hoverThumbLeft;
  final double hoverThumbRight;
  final Key? frameKey;
  final Key positionKey;
  final Key thumbKey;

  @override
  State<_SongDialogScrollbarHost> createState() =>
      _SongDialogScrollbarHostState();
}

class _SongDialogScrollbarHostState extends State<_SongDialogScrollbarHost> {
  var _hovered = false;
  var _dragging = false;
  var _refreshScheduled = false;

  @override
  void initState() {
    super.initState();
    _scheduleLayoutRefresh();
  }

  @override
  void didUpdateWidget(covariant _SongDialogScrollbarHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleLayoutRefresh();
  }

  void _scheduleLayoutRefresh() {
    if (_refreshScheduled) {
      return;
    }
    _refreshScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshScheduled = false;
      if (!mounted) {
        return;
      }
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        setState(() {
          _hovered = true;
        });
      },
      onExit: (_) {
        if (_dragging) {
          return;
        }
        setState(() {
          _hovered = false;
        });
      },
      child: Stack(
        key: widget.frameKey,
        clipBehavior: Clip.none,
        children: [
          widget.child,
          Positioned(
            key: widget.positionKey,
            top: 0,
            right: widget.right,
            bottom: widget.bottom,
            width: widget.trackWidth,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return AnimatedBuilder(
                  animation: widget.controller,
                  builder: (context, _) {
                    if (!widget.controller.hasClients ||
                        widget.controller.positions.length != 1) {
                      return const SizedBox.shrink();
                    }
                    final position = widget.controller.position;
                    final maxScrollTop = position.maxScrollExtent;
                    if (maxScrollTop <= 1) {
                      return const SizedBox.shrink();
                    }

                    final trackHeight = constraints.maxHeight;
                    final scrollHeight = trackHeight + maxScrollTop;
                    final thumbHeight = math.max(
                      38.0,
                      (trackHeight / scrollHeight) * trackHeight,
                    );
                    final thumbTop =
                        (position.pixels / maxScrollTop) *
                        math.max(0.0, trackHeight - thumbHeight);
                    final expanded = _hovered || _dragging;
                    final brightness = Theme.of(context).brightness;
                    final thumbColor =
                        expanded
                            ? _songDialogScrollbarThumbHover(brightness)
                            : _songDialogScrollbarThumb(brightness);

                    return AnimatedOpacity(
                      opacity: expanded ? 1 : 0,
                      duration: const Duration(milliseconds: 140),
                      curve: Curves.easeOut,
                      child: Stack(
                        children: [
                          Positioned(
                            key: widget.thumbKey,
                            top: thumbTop.clamp(0.0, trackHeight - thumbHeight),
                            left:
                                expanded
                                    ? widget.hoverThumbLeft
                                    : widget.normalThumbLeft,
                            right:
                                expanded
                                    ? widget.hoverThumbRight
                                    : widget.normalThumbRight,
                            height: thumbHeight,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onVerticalDragStart: (_) {
                                setState(() {
                                  _dragging = true;
                                });
                              },
                              onVerticalDragUpdate: (details) {
                                final trackRange = math.max(
                                  1.0,
                                  trackHeight - thumbHeight,
                                );
                                final scrollDelta =
                                    details.delta.dy *
                                    (maxScrollTop / trackRange);
                                widget.controller.jumpTo(
                                  (position.pixels + scrollDelta).clamp(
                                    0.0,
                                    maxScrollTop,
                                  ),
                                );
                              },
                              onVerticalDragEnd: (_) {
                                setState(() {
                                  _dragging = false;
                                  _hovered = false;
                                });
                              },
                              onVerticalDragCancel: () {
                                setState(() {
                                  _dragging = false;
                                  _hovered = false;
                                });
                              },
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: thumbColor,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

Color _songDialogScrollbarThumb(Brightness brightness) {
  return brightness == Brightness.dark
      ? const Color(0x7396a4b6)
      : const Color(0x805b697a);
}

Color _songDialogScrollbarThumbHover(Brightness brightness) {
  return brightness == Brightness.dark
      ? const Color(0x9ebccadc)
      : const Color(0xad435060);
}

class _MusicDialogCommandButton extends StatelessWidget {
  const _MusicDialogCommandButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.iconWidget,
    this.primary = false,
    this.disabled = false,
    this.commandBar = false,
    this.compact = false,
    this.showLabel = true,
    this.canOverflow = true,
  });

  final String label;
  final IconData? icon;
  final Widget? iconWidget;
  final bool primary;
  final bool disabled;
  final bool commandBar;
  final bool compact;
  final bool showLabel;
  final bool canOverflow;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = PopupDialogColors.resolve(context);
    final nightMode = Theme.of(context).brightness == Brightness.dark;
    final commandBarSurface =
        nightMode ? const Color(0x0effffff) : CommandBarColors.buttonSurface;
    final commandBarHoverSurface =
        nightMode
            ? GlobalUI.buttonHoverBgColorNight
            : GlobalUI.buttonHoverBgColorDay;
    final commandBarBorder =
        nightMode ? colors.buttonBorder : CommandBarColors.buttonBorder;
    final primaryDisabledForeground =
        nightMode ? const Color(0xb8e2e8f0) : const Color(0xb85e6773);
    final primaryDisabledBackground =
        nightMode ? const Color(0x24ffffff) : const Color(0xc7e6ebf3);
    final primaryDisabledBorder =
        nightMode ? const Color(0x2e94a3b8) : const Color(0x619ba6b6);
    final commandBarDisabled = commandBar && disabled;
    final foreground =
        disabled
            ? primary
                ? primaryDisabledForeground
                : commandBar
                ? colors.textStrong
                : colors.buttonText
            : primary
            ? Colors.white
            : commandBar
            ? colors.textStrong
            : colors.buttonText;
    final hoverForeground = primary ? foreground : foreground;
    final background =
        disabled
            ? primary
                ? primaryDisabledBackground
                : commandBar
                ? commandBarSurface
                : colors.buttonSurface
            : primary
            ? colors.accent
            : commandBar
            ? commandBarSurface
            : colors.buttonSurface;
    final hoverBackground =
        primary || disabled
            ? background
            : commandBar
            ? commandBarHoverSurface
            : nightMode
            ? GlobalUI.buttonHoverBgColorNight
            : colors.buttonHoverSurface;
    final borderColor =
        primary && disabled
            ? primaryDisabledBorder
            : primary
            ? colors.accent.withValues(alpha: 0.52)
            : commandBar
            ? commandBarBorder
            : colors.buttonBorder;
    final shadow =
        primary && !disabled
            ? [
              BoxShadow(
                color: colors.accent.withValues(alpha: 0.26),
                offset: const Offset(0, 10),
                blurRadius: 22,
              ),
            ]
            : commandBar
            ? const <BoxShadow>[]
            : colors.buttonShadow;
    final buttonHeight = compact ? 38.0 : 40.0;
    final buttonMinWidth = commandBar ? 44.0 : 0.0;
    final mobile =
        MediaQuery.sizeOf(context).width <= popupDialogMobileBreakpoint;
    final horizontalPadding =
        !showLabel
            ? 0.0
            : (compact ? 12.0 : (commandBar ? (mobile ? 10.0 : 14.0) : 18.0));

    final button = TextButton(
      style: TextButton.styleFrom(
        minimumSize: Size(buttonMinWidth, buttonHeight),
        fixedSize:
            !showLabel && commandBar
                ? Size(buttonMinWidth, buttonHeight)
                : null,
        maximumSize: Size(double.infinity, buttonHeight),
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: foreground,
        disabledForegroundColor: foreground,
        backgroundColor: background,
        disabledBackgroundColor: background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(commandBar ? 10 : 8),
          side: BorderSide(color: borderColor),
        ),
      ).copyWith(
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return foreground;
          }
          if (states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.focused)) {
            return hoverForeground;
          }
          return foreground;
        }),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.focused)) {
            return hoverBackground;
          }
          return background;
        }),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      onPressed: disabled ? null : onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon case final IconData icon) ...[
            Icon(icon, size: 20),
            if (showLabel) const SizedBox(width: 8),
          ],
          if (iconWidget case final Widget iconWidget) ...[
            iconWidget,
            if (showLabel) const SizedBox(width: 8),
          ],
          if (showLabel)
            Text(
              label,
              style: TextStyle(
                fontSize: commandBar ? 14 : 16,
                fontWeight: commandBar ? FontWeight.w700 : FontWeight.w600,
                fontVariations: [FontVariation.weight(commandBar ? 720 : 650)],
              ),
            ),
        ],
      ),
    );
    final styledButton = button
        .withCommandButtonInsetHighlight(
          commandBar && !primary && !disabled && !nightMode
              ? const Color(0x6bffffff)
              : null,
          radius: commandBar ? 10 : 8,
        )
        .withDialogButtonShadow(shadow, radius: commandBar ? 10 : 8);
    final resolvedButton =
        commandBarDisabled
            ? Opacity(opacity: 0.45, child: styledButton)
            : styledButton;
    if (commandBar) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: resolvedButton,
      );
    }
    return resolvedButton;
  }
}

class _MusicDialogButtonInsetHighlight extends StatelessWidget {
  const _MusicDialogButtonInsetHighlight({
    required this.child,
    required this.color,
    required this.radius,
  });

  final Widget child;
  final Color color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned(
          left: 1,
          right: 1,
          top: 1,
          height: 1,
          child: IgnorePointer(
            child: DecoratedBox(
              key: const ValueKey('MusicDialog.CommandButtonInsetHighlight'),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(radius - 1),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

extension _MusicDialogButtonShadow on Widget {
  Widget withCommandButtonInsetHighlight(
    Color? color, {
    required double radius,
  }) {
    if (color == null) {
      return this;
    }
    return _MusicDialogButtonInsetHighlight(
      color: color,
      radius: radius,
      child: this,
    );
  }

  Widget withDialogButtonShadow(
    List<BoxShadow> shadow, {
    required double radius,
  }) {
    if (shadow.isEmpty) {
      return this;
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: shadow,
      ),
      child: this,
    );
  }
}

class _MusicInfoPropertyList extends StatelessWidget {
  const _MusicInfoPropertyList({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final mobile =
        MediaQuery.sizeOf(context).width <= popupDialogMobileBreakpoint;
    return Column(
      key: const ValueKey('MusicDialog.PropertyList'),
      children: [
        for (final (index, child) in children.indexed) ...[
          if (index > 0) SizedBox(height: mobile ? 6 : 10),
          child,
        ],
      ],
    );
  }
}

class _PropertyRow extends StatelessWidget {
  const _PropertyRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = PopupDialogColors.resolve(context);
    final mobile =
        MediaQuery.sizeOf(context).width <= popupDialogMobileBreakpoint;
    final labelWidget = Padding(
      padding: EdgeInsets.zero,
      child: SizedBox(
        width: mobile ? double.infinity : 110,
        height: mobile ? null : 42,
        child: Align(
          alignment: mobile ? Alignment.topLeft : Alignment.centerLeft,
          child: Text(
            label,
            style: TextStyle(
              color: colors.textMuted,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
    if (mobile) {
      return Column(
        key: ValueKey('MusicDialog.PropertyRow.$label'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [labelWidget, const SizedBox(height: 6), child],
      );
    }
    return Row(
      key: ValueKey('MusicDialog.PropertyRow.$label'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        labelWidget,
        const SizedBox(width: 18),
        Expanded(child: child),
      ],
    );
  }
}

class _DialogField extends StatelessWidget {
  const _DialogField({
    super.key,
    required this.controller,
    this.readOnly = false,
    this.contentPadding,
  });

  final TextEditingController controller;
  final bool readOnly;
  final EdgeInsetsGeometry? contentPadding;

  @override
  Widget build(BuildContext context) {
    final colors = PopupDialogColors.resolve(context);
    return _DialogTextFieldFrame(
      readOnly: readOnly,
      emphasizeReadOnly: true,
      childBuilder: (context, focusNode) {
        return TextField(
          focusNode: focusNode,
          controller: controller,
          readOnly: readOnly,
          showCursor: !readOnly,
          enableInteractiveSelection: true,
          minLines: 1,
          maxLines: 1,
          cursorColor: colors.accentStrong,
          style: TextStyle(
            color: readOnly ? colors.fieldDisabledText : colors.text,
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
          decoration: _dialogFieldDecoration(
            context,
            readOnly: readOnly,
            contentPadding: contentPadding,
          ),
        );
      },
    );
  }
}

class _MusicDialogMoreCommandButton extends StatelessWidget {
  const _MusicDialogMoreCommandButton({
    required this.label,
    required this.items,
  });

  final String label;
  final List<MenuFlyoutItem> items;

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder:
          (buttonContext) => _MusicDialogCommandButton(
            key: const ValueKey('MusicDialog.CommandBar.MoreButton'),
            iconWidget: const SmPlayerMoreHorizontalIcon(size: 20),
            label: label,
            commandBar: true,
            showLabel: false,
            canOverflow: false,
            onPressed: () {
              showMenuFlyout(
                buttonContext,
                layer: MenuFlyoutLayer.dialog,
                items: items,
              );
            },
          ),
    );
  }
}

class _DialogTextFieldFrame extends StatefulWidget {
  const _DialogTextFieldFrame({
    required this.readOnly,
    required this.childBuilder,
    this.emphasizeReadOnly = true,
  });

  final bool readOnly;
  final bool emphasizeReadOnly;
  final Widget Function(BuildContext context, FocusNode focusNode) childBuilder;

  @override
  State<_DialogTextFieldFrame> createState() => _DialogTextFieldFrameState();
}

class _DialogTextFieldFrameState extends State<_DialogTextFieldFrame> {
  late final FocusNode _focusNode;
  var _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(_handleFocusChanged);
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_handleFocusChanged)
      ..dispose();
    super.dispose();
  }

  void _handleFocusChanged() {
    if (_focused == _focusNode.hasFocus) {
      return;
    }
    setState(() {
      _focused = _focusNode.hasFocus;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = PopupDialogColors.resolve(context);
    final brightness = Theme.of(context).brightness;
    final insetTopHighlight = _fieldInsetTopHighlight(
      brightness,
      readOnly: widget.readOnly,
      emphasizeReadOnly: widget.emphasizeReadOnly,
    );
    return AnimatedContainer(
      key: const ValueKey('MusicDialog.DialogTextFieldFrame'),
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow:
            widget.readOnly
                ? _readOnlyFieldBoxShadow(
                  brightness,
                  emphasizeReadOnly: widget.emphasizeReadOnly,
                )
                : _fieldBoxShadow(colors),
      ),
      child: Stack(
        children: [
          TextSelectionTheme(
            key: const ValueKey('MusicDialog.TextSelectionTheme'),
            data: TextSelectionThemeData(
              selectionColor: colors.accent.withValues(alpha: 0.22),
            ),
            child: widget.childBuilder(context, _focusNode),
          ),
          if (insetTopHighlight != null)
            Positioned(
              left: 1,
              right: 1,
              top: 1,
              height: 1,
              child: IgnorePointer(
                child: DecoratedBox(
                  key: const ValueKey('MusicDialog.FieldInsetTopHighlight'),
                  decoration: BoxDecoration(
                    color: insetTopHighlight,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(7),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<BoxShadow> _fieldBoxShadow(PopupDialogResolvedColors colors) {
    return [
      if (_focused) BoxShadow(color: colors.focusRing, spreadRadius: 3),
      const BoxShadow(
        color: Color(0x0a253143),
        offset: Offset(0, 8),
        blurRadius: 18,
      ),
    ];
  }

  List<BoxShadow> _readOnlyFieldBoxShadow(
    Brightness brightness, {
    required bool emphasizeReadOnly,
  }) {
    if (!emphasizeReadOnly) {
      if (brightness == Brightness.dark) {
        return const [
          BoxShadow(
            color: Color(0x22000000),
            offset: Offset(0, 1),
            blurRadius: 0,
          ),
        ];
      }
      return const [];
    }
    if (brightness == Brightness.dark) {
      return const [
        BoxShadow(
          color: Color(0x18000000),
          offset: Offset(0, 0),
          blurRadius: 0,
        ),
      ];
    }
    return const [];
  }
}

Color? _fieldInsetTopHighlight(
  Brightness brightness, {
  required bool readOnly,
  required bool emphasizeReadOnly,
}) {
  if (readOnly && emphasizeReadOnly) {
    return brightness == Brightness.dark
        ? GlobalUI.readOnlyFieldInsetHighlightNight
        : GlobalUI.readOnlyFieldInsetHighlightDay;
  }
  if (readOnly) {
    if (brightness == Brightness.light) {
      return null;
    }
    return const Color(0x0effffff);
  }
  return brightness == Brightness.dark
      ? const Color(0x0effffff)
      : const Color(0xa6ffffff);
}

class _ArtistFieldGrid extends StatelessWidget {
  const _ArtistFieldGrid({
    required this.controllers,
    required this.saving,
    required this.onAddArtistCell,
    required this.onRemoveArtistCell,
  });

  final List<TextEditingController> controllers;
  final bool saving;
  final VoidCallback onAddArtistCell;
  final ValueChanged<int> onRemoveArtistCell;

  @override
  Widget build(BuildContext context) {
    final mobile =
        MediaQuery.sizeOf(context).width <= popupDialogMobileBreakpoint;
    final grid = LayoutBuilder(
      builder: (context, constraints) {
        final columns =
            !mobile && controllers.length > 1 && constraints.maxWidth >= 420
                ? 2
                : 1;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in controllers.indexed)
              SizedBox(
                width:
                    columns == 2
                        ? (constraints.maxWidth - 8) / 2
                        : constraints.maxWidth,
                child: Stack(
                  alignment: Alignment.centerRight,
                  children: [
                    _DialogField(
                      controller: entry.$2,
                      contentPadding: const EdgeInsets.fromLTRB(12, 0, 34, 0),
                    ),
                    if (controllers.length > 1)
                      Positioned(
                        top: 7,
                        right: 7,
                        child: _ArtistRemoveButton(
                          disabled: saving,
                          onPressed:
                              saving
                                  ? null
                                  : () {
                                    onRemoveArtistCell(entry.$1);
                                  },
                        ),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
    final addButton =
        controllers.length >= _MusicDialogState.maxArtistCells
            ? null
            : _MusicDialogIconButton(
              iconWidget: const _ElectronIcon(_ElectronIconName.plus, size: 18),
              tooltip: context.smPlayerI18n.t('common.add'),
              size: 42,
              iconSize: 16,
              disabled: saving,
              onPressed: onAddArtistCell,
            );
    if (mobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          grid,
          if (addButton != null) ...[const SizedBox(height: 8), addButton],
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: grid),
        if (addButton != null) ...[const SizedBox(width: 8), addButton],
      ],
    );
  }
}

class _ArtistRemoveButton extends StatelessWidget {
  const _ArtistRemoveButton({required this.disabled, required this.onPressed});

  final bool disabled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = PopupDialogColors.resolve(context);
    final nightMode = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      style: IconButton.styleFrom(
        fixedSize: const Size(28, 28),
        minimumSize: const Size(28, 28),
        padding: EdgeInsets.zero,
        disabledForegroundColor: colors.textMuted.withValues(alpha: 0.48),
        disabledBackgroundColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ).copyWith(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.focused)) {
            return nightMode
                ? GlobalUI.buttonHoverBgColorNight
                : GlobalUI.buttonHoverBgColorDay;
          }
          return Colors.transparent;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return colors.textMuted.withValues(alpha: 0.48);
          }
          if (states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.focused)) {
            return colors.text;
          }
          return colors.textMuted;
        }),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      icon: const _ElectronIcon(_ElectronIconName.close, size: 14),
      onPressed: disabled ? null : onPressed,
    );
  }
}

class _MusicDialogIconButton extends StatelessWidget {
  const _MusicDialogIconButton({
    super.key,
    required this.onPressed,
    required this.iconWidget,
    this.tooltip,
    this.size = 42,
    this.iconSize = 16,
    this.disabled = false,
  });

  final Widget iconWidget;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final double iconSize;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final colors = PopupDialogColors.resolve(context);
    final nightMode = Theme.of(context).brightness == Brightness.dark;
    final foreground =
        disabled ? colors.textMuted.withValues(alpha: 0.48) : colors.text;
    final background = disabled ? colors.buttonSurface : colors.buttonSurface;
    final hoverBackground =
        disabled
            ? background
            : nightMode
            ? GlobalUI.buttonHoverBgColorNight
            : GlobalUI.buttonHoverBgColorDay;
    final button = IconButton(
      style: IconButton.styleFrom(
        fixedSize: Size(size, size == 42 ? 40 : size),
        minimumSize: Size(size, size == 42 ? 40 : size),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: foreground,
        disabledForegroundColor: foreground,
        backgroundColor: background,
        disabledBackgroundColor: background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: colors.buttonBorder),
        ),
        shadowColor: Colors.transparent,
      ).copyWith(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.focused)) {
            return hoverBackground;
          }
          return background;
        }),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      icon: iconWidget,
      onPressed: disabled ? null : onPressed,
    ).withDialogButtonShadow(colors.buttonShadow, radius: 8);
    final message = tooltip;
    if (message == null) {
      return button;
    }
    return Tooltip(message: message, child: button);
  }
}

class _LyricsTimestampToggle extends StatelessWidget {
  const _LyricsTimestampToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = PopupDialogColors.resolve(context);
    return SizedBox(
      key: const ValueKey('MusicDialog.LyricsTimestampToggle'),
      height: 48,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              key: const ValueKey('MusicDialog.LyricsTimestampCheckboxBox'),
              dimension: 18,
              child: Checkbox(
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: const VisualDensity(
                  horizontal: -4,
                  vertical: -4,
                ),
                value: value,
                onChanged:
                    onChanged == null
                        ? null
                        : (value) {
                          onChanged!(value ?? false);
                        },
              ),
            ),
            const SizedBox(width: 8),
            Text(
              context.smPlayerI18n.t('song.showLyricsTimestamps'),
              style: TextStyle(
                color: colors.textStrong,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontVariations: const [FontVariation.weight(650)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArtworkSourceButton extends StatelessWidget {
  const _ArtworkSourceButton({
    required this.disabled,
    required this.onChangeArtwork,
    required this.onChooseArtworkFromLibrary,
  });

  final bool disabled;
  final VoidCallback onChangeArtwork;
  final VoidCallback? onChooseArtworkFromLibrary;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;

    return Builder(
      builder:
          (buttonContext) => _MusicDialogCommandButton(
            iconWidget: const _ElectronIcon(_ElectronIconName.edit, size: 20),
            label: i18n.t('song.changeArtwork'),
            commandBar: true,
            disabled: disabled,
            onPressed:
                disabled
                    ? null
                    : () {
                      final button =
                          buttonContext.findRenderObject()! as RenderBox;
                      showMenuFlyout(
                        buttonContext,
                        layer: MenuFlyoutLayer.dialog,
                        position: button.localToGlobal(
                          Offset(0, button.size.height + 6),
                        ),
                        items: [
                          MenuFlyoutItem(
                            key: 'local',
                            text: i18n.t('song.chooseArtworkFromLocal'),
                            iconWidget: const _ElectronIcon(
                              _ElectronIconName.pictures,
                              size: 18,
                            ),
                            onPressed: onChangeArtwork,
                          ),
                          MenuFlyoutItem(
                            key: 'library',
                            text: i18n.t('song.chooseArtworkFromLibrary'),
                            iconWidget: const _ElectronIcon(
                              _ElectronIconName.musicLibrary,
                              size: 18,
                            ),
                            disabled: onChooseArtworkFromLibrary == null,
                            onPressed: onChooseArtworkFromLibrary,
                          ),
                        ],
                      );
                    },
          ),
    );
  }
}

enum _ElectronIconName {
  close,
  info,
  lyrics,
  pictures,
  play,
  pause,
  save,
  undo,
  search,
  import,
  edit,
  rename,
  refresh,
  trash,
  musicLibrary,
  plus,
  folder,
}

class _ElectronIcon extends StatelessWidget {
  const _ElectronIcon(this.name, {this.size = 18});

  final _ElectronIconName name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color =
        IconTheme.of(context).color ??
        DefaultTextStyle.of(context).style.color ??
        Colors.black;
    return SvgIcon(
      key: ValueKey('MusicDialog.ElectronIcon.${name.name}'),
      svg: _electronIconSvg(name),
      size: size,
      color: color,
    );
  }
}

String _electronIconSvg(_ElectronIconName name) {
  final path = switch (name) {
    _ElectronIconName.close =>
      'm4.09 4.22.06-.07a.5.5 0 0 1 .63-.06l.07.06L10 9.29l5.15-5.14a.5.5 0 0 1 .63-.06l.07.06c.18.17.2.44.06.63l-.06.07L10.71 10l5.14 5.15c.18.17.2.44.06.63l-.06.07a.5.5 0 0 1-.63.06l-.07-.06L10 10.71l-5.15 5.14a.5.5 0 0 1-.63.06l-.07-.06a.5.5 0 0 1-.06-.63l.06-.07L9.29 10 4.15 4.85a.5.5 0 0 1-.06-.63l.06-.07-.06.07Z',
    _ElectronIconName.info =>
      'M10.5 8.91a.5.5 0 0 0-1 .09v4.6a.5.5 0 0 0 1-.1V8.91Zm.3-2.16a.75.75 0 1 0-1.5 0 .75.75 0 0 0 1.5 0ZM18 10a8 8 0 1 0-16 0 8 8 0 0 0 16 0ZM3 10a7 7 0 1 1 14 0 7 7 0 0 1-14 0Z',
    _ElectronIconName.lyrics =>
      'M15.4 13.84h-4.92L6.21 17H6.2v-3.16H4.6c-.9 0-1.6-.71-1.6-1.56V5.57C3 4.7 3.7 4 4.6 4h10.8c.9 0 1.6.71 1.6 1.57v6.7c0 .86-.7 1.57-1.6 1.57Zm-10 3.76a1 1 0 0 0 1.4.2l4.01-2.96h4.59c1.44 0 2.6-1.15 2.6-2.56V5.57A2.58 2.58 0 0 0 15.4 3H4.6A2.58 2.58 0 0 0 2 5.57v6.7a2.58 2.58 0 0 0 2.6 2.57h.6v2.17c0 .22.07.42.2.6ZM9.5 10H15a.5.5 0 0 0 0-1H9.5a.5.5 0 0 0 0 1Zm-2-1H5a.5.5 0 0 0 0 1h2.5a.5.5 0 0 0 0-1ZM5 11a.5.5 0 0 0 0 1h5.5a.5.5 0 0 0 0-1H5Zm7.5 1a.5.5 0 0 1 0-1H15a.5.5 0 0 1 0 1h-2.5Z',
    _ElectronIconName.pictures =>
      'M14 7.5a1.5 1.5 0 1 1-3 0 1.5 1.5 0 0 1 3 0Zm-1 0a.5.5 0 1 0-1 0 .5.5 0 0 0 1 0ZM3 6a3 3 0 0 1 3-3h8a3 3 0 0 1 3 3v8a3 3 0 0 1-3 3H6a3 3 0 0 1-3-3V6Zm3-2a2 2 0 0 0-2 2v8c0 .37.1.72.28 1.02l4.67-4.59a1.5 1.5 0 0 1 2.1 0l4.67 4.59c.18-.3.28-.65.28-1.02V6a2 2 0 0 0-2-2H6Zm0 12h8a2 2 0 0 0 1.01-.27l-4.66-4.58a.5.5 0 0 0-.7 0l-4.66 4.58A2 2 0 0 0 6 16Z',
    _ElectronIconName.play =>
      'M17.22 8.69a1.5 1.5 0 0 1 0 2.62l-10 5.5A1.5 1.5 0 0 1 5 15.5v-11A1.5 1.5 0 0 1 7.22 3.2l10 5.5Zm-.48 1.75a.5.5 0 0 0 0-.88l-10-5.5A.5.5 0 0 0 6 4.5v11c0 .38.4.62.74.44l10-5.5Z',
    _ElectronIconName.pause =>
      'M5 2a2 2 0 0 0-2 2v12c0 1.1.9 2 2 2h2a2 2 0 0 0 2-2V4a2 2 0 0 0-2-2H5ZM4 4a1 1 0 0 1 1-1h2a1 1 0 0 1 1 1v12a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V4Zm9-2a2 2 0 0 0-2 2v12c0 1.1.9 2 2 2h2a2 2 0 0 0 2-2V4a2 2 0 0 0-2-2h-2Zm-1 2a1 1 0 0 1 1-1h2a1 1 0 0 1 1 1v12a1 1 0 0 1-1 1h-2a1 1 0 0 1-1-1V4Z',
    _ElectronIconName.save =>
      'M3 5c0-1.1.9-2 2-2h8.38a2 2 0 0 1 1.41.59l1.62 1.62A2 2 0 0 1 17 6.62V15a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5Zm2-1a1 1 0 0 0-1 1v10a1 1 0 0 0 1 1v-4.5c0-.83.67-1.5 1.5-1.5h7c.83 0 1.5.67 1.5 1.5V16a1 1 0 0 0 1-1V6.62a1 1 0 0 0-.3-.7L14.1 4.28a1 1 0 0 0-.71-.29H13v2.5c0 .83-.67 1.5-1.5 1.5h-4A1.5 1.5 0 0 1 6 6.5V4H5Zm2 0v2.5c0 .28.22.5.5.5h4a.5.5 0 0 0 .5-.5V4H7Zm7 12v-4.5a.5.5 0 0 0-.5-.5h-7a.5.5 0 0 0-.5.5V16h8Z',
    _ElectronIconName.undo =>
      'M5 2.5a.5.5 0 0 0-1 0v4.9c0 .33.27.6.6.6h4.9a.5.5 0 0 0 0-1H5.9l3.48-3.02a4 4 0 0 1 5.25 6.04l-8.17 7.1a.5.5 0 0 0 .65.76l8.17-7.1a5 5 0 0 0-6.56-7.55L5 6.46V2.5Z',
    _ElectronIconName.search =>
      'M13.73 14.44a6.5 6.5 0 1 1 .7-.7l3.42 3.4a.5.5 0 0 1-.63.77l-.07-.06-3.42-3.41Zm-.71-.71A5.54 5.54 0 0 0 15 9.5a5.5 5.5 0 1 0-1.98 4.23Z',
    _ElectronIconName.import =>
      'M15.5 17a.5.5 0 0 1 .09 1H4.5a.5.5 0 0 1-.09-1H15.5ZM10 2a.5.5 0 0 1 .5.41V14.3l3.64-3.65a.5.5 0 0 1 .64-.06l.07.06c.17.17.2.44.06.63l-.06.07-4.5 4.5a.5.5 0 0 1-.25.14L10 16a.5.5 0 0 1-.4-.2l-4.46-4.45a.5.5 0 0 1 .64-.76l.07.06 3.65 3.64V2.5c0-.27.22-.5.5-.5Z',
    _ElectronIconName.edit =>
      'M17.18 2.93a2.97 2.97 0 0 0-4.26-.06l-9.37 9.38c-.33.33-.56.74-.66 1.2l-.88 3.94a.5.5 0 0 0 .6.6l3.93-.87c.46-.1.9-.34 1.23-.68l9.36-9.36a2.97 2.97 0 0 0 .05-4.15Zm-3.55.65a1.97 1.97 0 1 1 2.8 2.8l-.68.66-2.8-2.79.68-.67Zm-1.38 1.38 2.8 2.8-7.99 7.97c-.2.2-.46.35-.74.41l-3.16.7.7-3.18c.07-.27.2-.51.4-.7l8-8Z',
    _ElectronIconName.rename =>
      'M17.18 2.93a2.97 2.97 0 0 0-4.26-.06l-9.37 9.38c-.33.33-.56.74-.66 1.2l-.88 3.94a.5.5 0 0 0 .6.6l3.93-.87c.46-.1.9-.34 1.23-.68l9.36-9.36a2.97 2.97 0 0 0 .05-4.15Zm-3.55.65a1.97 1.97 0 1 1 2.8 2.8l-.68.66-2.8-2.79.68-.67Zm-1.38 1.38 2.8 2.8-7.99 7.97c-.2.2-.46.35-.74.41l-3.16.7.7-3.18c.07-.27.2-.51.4-.7l8-8Z',
    _ElectronIconName.refresh =>
      'M4.97 4.97a7 7 0 0 1 9.9-.01L16 6.09V3.5a.5.5 0 0 1 1 0v3.8c0 .39-.31.7-.7.7h-3.8a.5.5 0 0 1 0-1h2.8l-1.13-1.13a6 6 0 0 0-9.5 1.27.5.5 0 1 1-.86-.5c.3-.61.69-1.17 1.16-1.67Zm10.56 7.39a.5.5 0 1 1 .86.5 7 7 0 0 1-11.26 2.18L4 13.91v2.59a.5.5 0 0 1-1 0v-3.8c0-.39.31-.7.7-.7h3.8a.5.5 0 0 1 0 1H4.7l1.13 1.13a6 6 0 0 0 9.7-1.77Z',
    _ElectronIconName.trash =>
      'M8.5 4h3a1.5 1.5 0 0 0-3 0Zm-1 0a2.5 2.5 0 0 1 5 0h5a.5.5 0 0 1 0 1h-1.05l-1.2 10.34A3 3 0 0 1 12.27 18H7.73a3 3 0 0 1-2.98-2.66L3.55 5H2.5a.5.5 0 0 1 0-1h5ZM5.74 15.23A2 2 0 0 0 7.73 17h4.54a2 2 0 0 0 1.99-1.77L15.44 5H4.56l1.18 10.23ZM8.5 7.5c.28 0 .5.22.5.5v6a.5.5 0 0 1-1 0V8c0-.28.22-.5.5-.5ZM12 8a.5.5 0 0 0-1 0v6a.5.5 0 0 0 1 0V8Z',
    _ElectronIconName.musicLibrary =>
      'M2 3.5C2 2.67 2.67 2 3.5 2h1C5.33 2 6 2.67 6 3.5v12.98c0 .83-.67 1.5-1.5 1.5h-1a1.5 1.5 0 0 1-1.5-1.5V3.5ZM3.5 3a.5.5 0 0 0-.5.5v12.98c0 .28.22.5.5.5h1a.5.5 0 0 0 .5-.5V3.5a.5.5 0 0 0-.5-.5h-1Zm3.5.5C7 2.67 7.67 2 8.5 2h1c.83 0 1.5.67 1.5 1.5v12.98c0 .83-.67 1.5-1.5 1.5h-1a1.5 1.5 0 0 1-1.5-1.5V3.5ZM8.5 3a.5.5 0 0 0-.5.5v12.98c0 .28.22.5.5.5h1a.5.5 0 0 0 .5-.5V3.5a.5.5 0 0 0-.5-.5h-1Zm7.22 3.16a1.5 1.5 0 0 0-1.87-1.1l-.75.2A1.5 1.5 0 0 0 12.04 7l2 9.8c.18.84 1.02 1.36 1.84 1.15l.99-.25c.79-.2 1.27-1 1.1-1.78l-2.25-9.76ZM14.12 6a.5.5 0 0 1 .62.37L17 16.14a.5.5 0 0 1-.37.6l-.98.25a.5.5 0 0 1-.61-.39l-2-9.8a.5.5 0 0 1 .35-.58l.74-.2Z',
    _ElectronIconName.plus =>
      'M10 2.5c.28 0 .5.22.5.5v6.5H17a.5.5 0 0 1 0 1h-6.5V17a.5.5 0 0 1-1 0v-6.5H3a.5.5 0 0 1 0-1h6.5V3c0-.28.22-.5.5-.5Z',
    _ElectronIconName.folder =>
      'M4.5 3A2.5 2.5 0 0 0 2 5.5v9A2.5 2.5 0 0 0 4.5 17h11a2.5 2.5 0 0 0 2.5-2.5v-7A2.5 2.5 0 0 0 15.5 5h-4.09L10.15 3.73A2.5 2.5 0 0 0 8.38 3H4.5ZM3 5.5C3 4.67 3.67 4 4.5 4h3.88c.4 0 .78.16 1.06.44l1.41 1.41c.1.1.22.15.36.15h4.29c.54 0 1.02.3 1.28.73H3V5.5ZM3 7.73h14v6.77c0 .83-.67 1.5-1.5 1.5h-11A1.5 1.5 0 0 1 3 14.5V7.73Z',
  };
  return '<svg viewBox="0 0 20 20" fill="currentColor" xmlns="http://www.w3.org/2000/svg"><path d="$path"/></svg>';
}

class _AlbumArtRecommendationText extends StatelessWidget {
  const _AlbumArtRecommendationText({
    required this.recommendation,
    required this.onApply,
    this.showFallbackLabel = true,
  });

  final AlbumArtRecommendation recommendation;
  final ValueChanged<AlbumArtRecommendation> onApply;
  final bool showFallbackLabel;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final colors = PopupDialogColors.resolve(context);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 500),
      child: Column(
        key: const ValueKey('MusicDialog.AlbumArtRecommendation'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: 8,
        children: [
          if (showFallbackLabel)
            Text(
              i18n.t('song.noAlbumArt'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.text,
                fontSize: 16,
                fontWeight: FontWeight.w400,
                height: 1.35,
              ),
            ),
          SizedBox(
            width: 500,
            height: 40,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final prefix = i18n.t('song.albumArtRecommendationPrefix', {
                  'artist': recommendation.artistName,
                });
                final label = i18n.t('song.albumArtRecommendationTitle', {
                  'title': recommendation.song.title,
                });
                final normalStyle = TextStyle(
                  color: colors.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  height: 1.35,
                );
                final lineText =
                    '$prefix$label${i18n.t('song.albumArtRecommendationSuffix')}';
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        width: math.min(220, constraints.maxWidth),
                        height: 40,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            lineText,
                            key: const ValueKey(
                              'MusicDialog.AlbumArtRecommendationLine',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                            style: normalStyle,
                          ),
                        ),
                      ),
                    ),
                    const Positioned(
                      left: 196.5390625,
                      top: 0,
                      child: SizedBox(
                        width: 281.4921875,
                        height: 40,
                        child: _AlbumArtRecommendationButtonHost(),
                      ),
                    ),
                    Positioned(
                      left: 196.5390625,
                      top: 0,
                      child: _AlbumArtRecommendationButton(
                        recommendation: recommendation,
                        onApply: onApply,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AlbumArtRecommendationButton extends StatefulWidget {
  const _AlbumArtRecommendationButton({
    required this.recommendation,
    required this.onApply,
  });

  final AlbumArtRecommendation recommendation;
  final ValueChanged<AlbumArtRecommendation> onApply;

  @override
  State<_AlbumArtRecommendationButton> createState() =>
      _AlbumArtRecommendationButtonState();
}

class _AlbumArtRecommendationButtonState
    extends State<_AlbumArtRecommendationButton> {
  var _hovered = false;
  var _focused = false;

  void _setHovered(bool value) {
    if (_hovered == value) {
      return;
    }
    setState(() {
      _hovered = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final visible = _hovered || _focused;
    return MouseRegion(
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      cursor: SystemMouseCursors.click,
      child: Focus(
        onFocusChange: (focused) {
          setState(() {
            _focused = focused;
          });
        },
        child: SizedBox(
          key: const ValueKey('MusicDialog.AlbumArtRecommendationButton'),
          width: 281.4921875,
          height: 40,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: GestureDetector(
                  key: const ValueKey(
                    'MusicDialog.AlbumArtRecommendationButtonHitTarget',
                  ),
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    widget.onApply(widget.recommendation);
                  },
                ),
              ),
              Positioned(
                left: 192.234375,
                bottom: 0,
                child: _AlbumArtRecommendationPreview(
                  recommendation: widget.recommendation,
                  visible: visible,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlbumArtRecommendationButtonHost extends StatelessWidget {
  const _AlbumArtRecommendationButtonHost();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.expand(
      key: ValueKey('MusicDialog.AlbumArtRecommendationButtonChrome'),
    );
  }
}

class _AlbumArtRecommendationPreview extends StatelessWidget {
  const _AlbumArtRecommendationPreview({
    required this.recommendation,
    required this.visible,
  });

  final AlbumArtRecommendation recommendation;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    final colors = PopupDialogColors.resolve(context);
    final nightMode = Theme.of(context).brightness == Brightness.dark;
    return IgnorePointer(
      child: AnimatedOpacity(
        key: const ValueKey('MusicDialog.AlbumArtRecommendationPreview'),
        duration: const Duration(milliseconds: 120),
        opacity: visible ? 1 : 0,
        child: Transform.translate(
          offset: Offset(0, visible ? 0 : 6),
          child: SizedBox.square(
            dimension: 128,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: nightMode ? const Color(0xf51c222b) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: nightMode ? colors.border : const Color(0x337e8b9a),
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                        nightMode
                            ? const Color(0x5c000000)
                            : const Color(0x38332644),
                    offset: const Offset(0, 18),
                    blurRadius: 44,
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: _ArtworkImage(
                  url: recommendation.artworkUrl,
                  size: 112,
                  borderRadius: 8,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

InputDecoration _dialogFieldDecoration(
  BuildContext context, {
  required bool readOnly,
  bool emphasizeReadOnly = true,
  bool multiline = false,
  String hintText = '',
  EdgeInsetsGeometry? contentPadding,
}) {
  final colors = PopupDialogColors.resolve(context);
  final nightMode = Theme.of(context).brightness == Brightness.dark;
  final readOnlyBorderColor =
      emphasizeReadOnly
          ? nightMode
              ? GlobalUI.readOnlyFieldBorderColorNight
              : GlobalUI.readOnlyFieldBorderColorDay
          : nightMode
          ? const Color(0x1fd6e0ec)
          : const Color(0x6bbec8d6);
  final readOnlyFillColor =
      emphasizeReadOnly
          ? nightMode
              ? GlobalUI.readOnlyFieldBgColorNight
              : GlobalUI.readOnlyFieldBgColorDay
          : colors.fieldDisabledSurface;
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide(color: colors.inputBorder),
  );
  final readOnlyBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide(color: readOnlyBorderColor),
  );
  return InputDecoration(
    isDense: false,
    constraints:
        multiline ? null : const BoxConstraints(minHeight: 42, maxHeight: 42),
    contentPadding:
        contentPadding ??
        (multiline
            ? const EdgeInsets.all(12)
            : const EdgeInsets.symmetric(horizontal: 12)),
    hintText: hintText,
    hintStyle: TextStyle(color: colors.textMuted),
    border: border,
    enabledBorder: readOnly ? readOnlyBorder : border,
    disabledBorder: readOnlyBorder,
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(
        color:
            readOnly
                ? readOnlyBorderColor
                : colors.accent.withValues(alpha: 0.72),
      ),
    ),
    filled: true,
    fillColor: readOnly ? readOnlyFillColor : colors.fieldSurface,
  );
}
