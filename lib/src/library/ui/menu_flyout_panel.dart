part of 'menu_flyout.dart';

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
    required _MenuFlyoutMetrics metrics,
  }) {
    final resolvedWidth = width.clamp(0.0, maxWidth);
    final height = _menuFlyoutItemsHeight(items, metrics);
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
    required this.metrics,
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
  final _MenuFlyoutMetrics metrics;
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
    final view = View.of(context);
    final viewSize = view.physicalSize / view.devicePixelRatio;
    final panelWidth =
        _menuFlyoutPanelWidth(
          context,
          widget.state.items,
          widget.metrics,
        ).clamp(0.0, viewSize.width - _menuFlyoutMargin * 2).toDouble();
    final maxHeight = (widget.boundaryBottom -
            widget.state.position.dy -
            _menuFlyoutMargin)
        .clamp(120.0, boundaryBottom - _menuFlyoutMargin);
    final itemsContentHeight = _menuFlyoutItemsContentHeight(
      widget.state.items,
      widget.metrics,
    );
    final scrollable =
        (widget.depth > 0 ||
            widget.scrollRoot ||
            widget.metrics.density == MenuFlyoutDensity.touch) &&
        itemsContentHeight > maxHeight;
    final showLeadingIconSpace = widget.state.items.any(
      _menuFlyoutItemHasLeadingIcon,
    );
    final itemWidgets = [
      for (var index = 0; index < widget.state.items.length; index += 1)
        _MenuFlyoutItemWidget(
          key: ValueKey(widget.state.items[index].key),
          item: widget.state.items[index],
          itemIndex: index,
          depth: widget.depth,
          showLeadingIconSpace: showLeadingIconSpace,
          activeItemIndexListenable: _activeItemIndex,
          anchorContext: widget.anchorContext,
          positionContext: widget.positionContext,
          metrics: widget.metrics,
          onClose: widget.onClose,
          onItemEntered: _handleItemEntered,
          onItemExited: _handleItemExited,
          onPassiveItemEntered: _handlePassiveItemEntered,
          onSubmenuEntered: _handleSubmenuEntered,
        ),
    ];
    final panel = ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: widget.metrics.minWidth,
        maxWidth: widget.metrics.maxWidth,
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
              padding: EdgeInsets.all(
                widget.metrics.padding + _menuFlyoutBorderWidth,
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
      child: SizedBox(width: panelWidth, child: panel),
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
