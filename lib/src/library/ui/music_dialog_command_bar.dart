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
  final disabled = button.disabled || button.loading;
  return MenuFlyoutItem(
    key: 'music-dialog-commandbar-overflow-$overflowIndex',
    text: button.label,
    icon: button.loading ? null : button.icon,
    iconWidget:
        button.loading
            ? const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
            : button.iconWidget,
    disabled: disabled,
    onPressed: disabled ? null : button.onPressed,
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
      loading: child.loading,
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
  final iconWidth =
      !child.loading && child.icon == null && child.iconWidget == null
          ? 0.0
          : 20.0;
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
