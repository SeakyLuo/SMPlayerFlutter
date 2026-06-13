part of 'settings_page.dart';

class ToggleSettingRow extends StatelessWidget {
  const ToggleSettingRow({
    super.key,
    required this.label,
    required this.checked,
    required this.onChange,
    this.hint,
  });

  final String label;
  final String? hint;
  final bool checked;
  final ValueChanged<bool> onChange;

  @override
  Widget build(BuildContext context) {
    final colors = SettingsPageColors.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 38),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          onChange(!checked);
        },
        child: Row(
          children: [
            _ElectronSwitch(value: checked, onChanged: onChange),
            const SizedBox(width: 14),
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: colors.textStrong,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (hint != null) ...[
                    const SizedBox(width: 8),
                    Tooltip(
                      message: hint!,
                      child: Icon(
                        FluentIcons.info_24_regular,
                        size: 16,
                        color: colors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ElectronSwitch extends StatelessWidget {
  const _ElectronSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = SettingsPageColors.of(context);
    return Semantics(
      checked: value,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          onChanged(!value);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          width: 48,
          height: 26,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: value ? colors.accent : colors.buttonSurface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: value ? Colors.transparent : const Color(0x52535e6a),
            ),
          ),
          child: Align(
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOutCubic,
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: value ? Colors.white : const Color(0xff767c83),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SelectSettingOption<T> {
  const SelectSettingOption({required this.value, required this.label});

  final T value;
  final String label;
}

class SelectSettingRow<T> extends StatelessWidget {
  const SelectSettingRow({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChange,
    this.searchable = false,
    this.searchPlaceholder,
    this.emptyLabel,
  });

  final String label;
  final T value;
  final List<SelectSettingOption<T>> options;
  final ValueChanged<T> onChange;
  final bool searchable;
  final String? searchPlaceholder;
  final String? emptyLabel;

  @override
  Widget build(BuildContext context) {
    return _InlineSelectSettingRow<T>(
      label: label,
      value: value,
      options: options,
      searchable: searchable,
      searchPlaceholder: searchPlaceholder,
      emptyLabel: emptyLabel,
      onChange: onChange,
    );
  }
}

class _InlineSelectSettingRow<T> extends StatefulWidget {
  const _InlineSelectSettingRow({
    required this.label,
    required this.value,
    required this.options,
    required this.searchable,
    required this.searchPlaceholder,
    required this.emptyLabel,
    required this.onChange,
  });

  final String label;
  final T value;
  final List<SelectSettingOption<T>> options;
  final bool searchable;
  final String? searchPlaceholder;
  final String? emptyLabel;
  final ValueChanged<T> onChange;

  @override
  State<_InlineSelectSettingRow<T>> createState() =>
      _InlineSelectSettingRowState<T>();
}

class _InlineSelectSettingRowState<T>
    extends State<_InlineSelectSettingRow<T>> {
  final _link = LayerLink();
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  BuildContext? _targetContext;
  OverlayEntry? _overlayEntry;
  var _open = false;
  var _openUpward = false;
  var _query = '';
  double? _dropdownMaxHeight;

  @override
  void dispose() {
    _removeOverlay();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = SettingsPageColors.of(context);
    final selectedOption = widget.options.firstWhere(
      (option) => option.value == widget.value,
    );
    return _SettingsRowFrame(
      label: widget.label,
      controlWidth: 210,
      child: CompositedTransformTarget(
        link: _link,
        child: Builder(
          builder: (targetContext) {
            _targetContext = targetContext;
            return SizedBox(
              height: 38,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  backgroundColor:
                      _open ? colors.selectOpenSurface : colors.inputSurface,
                  foregroundColor:
                      _open ? colors.accentStrong : colors.textStrong,
                  side: BorderSide(
                    color: _open ? colors.selectOpenBorder : colors.inputBorder,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                onPressed: _toggleOpen,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        selectedOption.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(
                      _open
                          ? FluentIcons.chevron_up_20_regular
                          : FluentIcons.chevron_down_20_regular,
                      size: 16,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _toggleOpen() {
    if (_open) {
      _close();
      return;
    }
    setState(() {
      _open = true;
    });
    _showOverlay();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _open) {
        _updateDropdownGeometry();
      }
    });
  }

  void _showOverlay() {
    _removeOverlay();
    _overlayEntry = OverlayEntry(builder: _buildOverlay);
    Overlay.of(context).insert(_overlayEntry!);
  }

  Widget _buildOverlay(BuildContext context) {
    final normalizedQuery = _query.toLowerCase();
    final visibleOptions =
        normalizedQuery.isEmpty
            ? widget.options
            : widget.options
                .where(
                  (option) =>
                      option.label.toLowerCase().contains(normalizedQuery),
                )
                .toList();
    return _settingsNoTextScaling(
      context,
      Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _close,
              child: const SizedBox.expand(),
            ),
          ),
          CompositedTransformFollower(
            link: _link,
            targetAnchor:
                _openUpward ? Alignment.topRight : Alignment.bottomRight,
            followerAnchor:
                _openUpward ? Alignment.bottomRight : Alignment.topRight,
            offset: Offset(0, _openUpward ? -6 : 6),
            child: SizedBox(
              width: _overlayWidth(),
              child: _SettingsSelectOptionsPanel<T>(
                options: visibleOptions,
                maxHeight: _dropdownMaxHeight,
                value: widget.value,
                searchable: widget.searchable,
                searchController: _searchController,
                searchFocusNode: _searchFocusNode,
                searchPlaceholder: widget.searchPlaceholder,
                emptyLabel: widget.emptyLabel,
                onSearchChanged: (value) {
                  setState(() {
                    _query = value;
                  });
                  _overlayEntry?.markNeedsBuild();
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && _open) {
                      _updateDropdownGeometry();
                    }
                  });
                },
                onSelected: (value) {
                  widget.onChange(value);
                  _close();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _close() {
    if (!_open && _overlayEntry == null) {
      return;
    }
    setState(() {
      _open = false;
      _query = '';
    });
    _searchController.clear();
    _removeOverlay();
  }

  double _overlayWidth() {
    final box = _targetBox();
    final triggerWidth = box?.size.width ?? 210;
    final contentWidth = widget.searchable ? 240.0 : 210.0;
    return math.min(320.0, math.max(triggerWidth, contentWidth));
  }

  void _updateDropdownGeometry() {
    final box = _targetBox();
    if (box == null) {
      return;
    }
    final position = box.localToGlobal(Offset.zero);
    final viewportHeight = MediaQuery.sizeOf(context).height;
    final bottomBoundary = math.max(0.0, viewportHeight - 128.0);
    final optionHeight = widget.searchable ? 48.0 : 0.0;
    final desiredHeight = math.max(
      120.0,
      math.min(320.0, optionHeight + (_visibleOptionCount() * 38.0) + 12.0),
    );
    final spaceBelow = math.max(
      0.0,
      bottomBoundary - position.dy - box.size.height - 8.0,
    );
    final spaceAbove = math.max(0.0, position.dy - 8.0);
    final nextOpenUpward =
        spaceBelow < desiredHeight && spaceAbove > spaceBelow;
    final availableSpace = nextOpenUpward ? spaceAbove : spaceBelow;
    final nextMaxHeight = math.min(
      desiredHeight,
      math.max(120.0, availableSpace),
    );
    setState(() {
      _openUpward = nextOpenUpward;
      _dropdownMaxHeight = nextMaxHeight;
    });
    _overlayEntry?.markNeedsBuild();
  }

  int _visibleOptionCount() {
    final normalizedQuery = _query.toLowerCase();
    if (normalizedQuery.isEmpty) {
      return widget.options.length;
    }
    return widget.options
        .where((option) => option.label.toLowerCase().contains(normalizedQuery))
        .length;
  }

  RenderBox? _targetBox() {
    final targetContext = _targetContext;
    if (targetContext == null || !targetContext.mounted) {
      return null;
    }
    return targetContext.findRenderObject() as RenderBox?;
  }
}

class _SettingsSelectOptionsPanel<T> extends StatelessWidget {
  const _SettingsSelectOptionsPanel({
    required this.options,
    required this.maxHeight,
    required this.value,
    required this.searchable,
    required this.searchController,
    required this.searchFocusNode,
    required this.searchPlaceholder,
    required this.emptyLabel,
    required this.onSearchChanged,
    required this.onSelected,
  });

  final List<SelectSettingOption<T>> options;
  final double? maxHeight;
  final T value;
  final bool searchable;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final String? searchPlaceholder;
  final String? emptyLabel;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = SettingsPageColors.of(context);
    return Material(
      color: Colors.transparent,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: colors.dropdownSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colors.inputBorder),
          boxShadow: [
            BoxShadow(
              color: colors.dropdownShadow,
              offset: const Offset(0, 18),
              blurRadius: 44,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (searchable)
              Container(
                height: 46,
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                decoration: BoxDecoration(
                  color: colors.dropdownSurface,
                  border: Border(bottom: BorderSide(color: colors.cardBorder)),
                ),
                child: SizedBox(
                  height: 34,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 20,
                        child: Icon(
                          FluentIcons.search_20_regular,
                          color: colors.textMuted,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ClipRect(
                          child: SizedBox(
                            height: 18,
                            child: Stack(
                              alignment: Alignment.centerLeft,
                              children: [
                                if (searchController.text.isEmpty)
                                  IgnorePointer(
                                    child: Text(
                                      searchPlaceholder ?? '',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: colors.textMuted,
                                        fontSize: 13,
                                        height: 1,
                                      ),
                                    ),
                                  ),
                                EditableText(
                                  controller: searchController,
                                  focusNode: searchFocusNode,
                                  autofocus: true,
                                  maxLines: 1,
                                  cursorHeight: 15,
                                  cursorColor: colors.accent,
                                  backgroundCursorColor: Colors.transparent,
                                  selectionColor: colors.accentHover,
                                  style: TextStyle(
                                    color: colors.textStrong,
                                    fontSize: 13,
                                    height: 1,
                                  ),
                                  onChanged: onSearchChanged,
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
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight ?? 260),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(6),
                child:
                    options.isEmpty
                        ? Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 12,
                          ),
                          child: Text(
                            emptyLabel ?? '',
                            style: TextStyle(
                              color: colors.textMuted,
                              fontSize: 13,
                            ),
                          ),
                        )
                        : Column(
                          mainAxisSize: MainAxisSize.min,
                          children:
                              options.indexed.map((entry) {
                                final index = entry.$1;
                                final option = entry.$2;
                                final selected = option.value == value;
                                return Padding(
                                  padding: EdgeInsets.only(
                                    bottom: index == options.length - 1 ? 0 : 4,
                                  ),
                                  child: _SettingsSelectOptionButton(
                                    selected: selected,
                                    label: option.label,
                                    onPressed: () {
                                      onSelected(option.value);
                                    },
                                  ),
                                );
                              }).toList(),
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSelectOptionButton extends StatelessWidget {
  const _SettingsSelectOptionButton({
    required this.selected,
    required this.label,
    required this.onPressed,
  });

  final bool selected;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = SettingsPageColors.of(context);
    final foreground = selected ? colors.accentStrong : colors.textStrong;
    return Tooltip(
      message: label,
      waitDuration: const Duration(milliseconds: 350),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(7),
          hoverColor: colors.accentHover,
          onTap: onPressed,
          child: Ink(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: selected ? colors.accentHover : Colors.transparent,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  child:
                      selected
                          ? Icon(
                            FluentIcons.checkmark_20_regular,
                            size: 16,
                            color: foreground,
                          )
                          : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: foreground, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TimeSettingRow extends StatelessWidget {
  const TimeSettingRow({
    super.key,
    required this.label,
    required this.startLabel,
    required this.endLabel,
    required this.startValue,
    required this.endValue,
    required this.onStartChange,
    required this.onEndChange,
  });

  final String label;
  final String startLabel;
  final String endLabel;
  final String startValue;
  final String endValue;
  final ValueChanged<String> onStartChange;
  final ValueChanged<String> onEndChange;

  @override
  Widget build(BuildContext context) {
    final colors = SettingsPageColors.of(context);
    return _SettingsRowFrame(
      label: label,
      controlWidth: 300,
      child: Row(
        children: [
          Text(startLabel, style: TextStyle(color: colors.textMuted)),
          const SizedBox(width: 8),
          Expanded(
            child: _TimePicker(value: startValue, onChange: onStartChange),
          ),
          const SizedBox(width: 12),
          Text(endLabel, style: TextStyle(color: colors.textMuted)),
          const SizedBox(width: 8),
          Expanded(child: _TimePicker(value: endValue, onChange: onEndChange)),
        ],
      ),
    );
  }
}

class RangeSettingRow extends StatelessWidget {
  const RangeSettingRow({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.valueLabel,
    required this.onChange,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final int step;
  final String valueLabel;
  final ValueChanged<int> onChange;

  @override
  Widget build(BuildContext context) {
    final colors = SettingsPageColors.of(context);
    return _SettingsRowFrame(
      label: label,
      controlWidth: 290,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                activeTrackColor: colors.accent,
                inactiveTrackColor: const Color(0x2e323e4e),
                thumbColor: colors.accent,
                overlayShape: SliderComponentShape.noOverlay,
                tickMarkShape: SliderTickMarkShape.noTickMark,
                showValueIndicator: ShowValueIndicator.never,
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 9,
                  elevation: 2,
                  pressedElevation: 3,
                ),
              ),
              child: SizedBox(
                height: 18,
                child: Slider(
                  value: value.toDouble(),
                  min: min.toDouble(),
                  max: max.toDouble(),
                  divisions: ((max - min) / step).round(),
                  onChanged: (nextValue) {
                    onChange(nextValue.round());
                  },
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 58,
            child: Text(
              valueLabel,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: colors.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ColorSettingRow extends StatefulWidget {
  const ColorSettingRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChange,
    this.onPickColor,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChange;
  final SettingsPickColorCallback? onPickColor;

  @override
  State<ColorSettingRow> createState() => _ColorSettingRowState();
}

class _ColorSettingRowState extends State<ColorSettingRow> {
  @override
  Widget build(BuildContext context) {
    final colors = SettingsPageColors.of(context);
    final normalized = widget.value.toUpperCase();
    return _SettingsRowFrame(
      label: widget.label,
      controlWidth: 112,
      keepInlineWhenNarrow: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: _pickColor,
        child: SizedBox(
          height: 34,
          width: 112,
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: _parseHexColor(widget.value),
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.inputBorder),
                  boxShadow: [
                    BoxShadow(
                      color: colors.colorSwatchInset,
                      blurStyle: BlurStyle.inner,
                      blurRadius: 0,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const SizedBox.square(dimension: 28),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 74,
                child: Text(
                  normalized,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  softWrap: false,
                  style: TextStyle(
                    color: colors.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickColor() async {
    final picked = await _pickNativeColor();
    if (picked == null) {
      return;
    }
    widget.onChange(picked);
  }

  Future<String?> _pickNativeColor() async {
    final picker = widget.onPickColor ?? pickDesktopColor;
    final picked = await picker(widget.value);
    if (picked == null) {
      return null;
    }
    return RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(picked)
        ? picked.toLowerCase()
        : null;
  }

  Color _parseHexColor(String value) {
    return Color(0xff000000 + int.parse(value.substring(1), radix: 16));
  }
}

class SettingsSectionCard extends StatelessWidget {
  const SettingsSectionCard({
    super.key,
    required this.title,
    this.id,
    this.headerAction,
    this.children,
  });

  final String title;
  final String? id;
  final Widget? headerAction;
  final List<Widget>? children;

  @override
  Widget build(BuildContext context) {
    final colors = SettingsPageColors.of(context);
    return Container(
      key: id == null ? null : ValueKey(id),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: BoxDecoration(
        color: colors.cardSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: colors.cardShadow,
            offset: const Offset(0, 18),
            blurRadius: 42,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: colors.textStrong,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (headerAction != null) headerAction!,
            ],
          ),
          if (children != null) ...[
            const SizedBox(height: 14),
            for (var index = 0; index < children!.length; index++) ...[
              children![index],
              if (index != children!.length - 1) const SizedBox(height: 12),
            ],
          ],
        ],
      ),
    );
  }
}

class SettingsCard extends SettingsSectionCard {
  const SettingsCard({
    super.key,
    required super.title,
    super.id,
    super.headerAction,
    super.children,
  });
}

class SettingsActionButton extends StatelessWidget {
  const SettingsActionButton({
    super.key,
    required this.child,
    this.icon,
    this.primary = false,
    this.compact = false,
    this.disabled = false,
    this.tooltip,
    this.onClick,
  });

  final Widget child;
  final IconData? icon;
  final bool primary;
  final bool compact;
  final bool disabled;
  final String? tooltip;
  final VoidCallback? onClick;

  @override
  Widget build(BuildContext context) {
    final label =
        tooltip ??
        switch (child) {
          Text(:final data?) => data,
          _ => '',
        };
    final button = _settingsNoTextScaling(
      context,
      SmPlayerTextIconButton(
        icon: icon,
        label: label,
        disabled: disabled,
        active: primary,
        minWidth: compact ? 0 : 0,
        height: 40,
        horizontalPadding: compact ? 12 : 14,
        iconSize: compact ? 16 : 18,
        onPressed: onClick,
        child: child,
      ),
    );
    return button;
  }
}

class SettingsButtonRow extends StatelessWidget {
  const SettingsButtonRow({
    super.key,
    required this.children,
    this.stretchSingle = false,
  });

  final List<Widget> children;
  final bool stretchSingle;

  @override
  Widget build(BuildContext context) {
    if (stretchSingle && children.length == 1) {
      return SizedBox(width: double.infinity, child: children.single);
    }
    return Wrap(spacing: 12, runSpacing: 12, children: children);
  }
}
