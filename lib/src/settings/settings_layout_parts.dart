part of 'settings_page.dart';

class _SettingsColumn extends StatelessWidget {
  const _SettingsColumn({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 16,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

class _SettingsRowFrame extends StatelessWidget {
  const _SettingsRowFrame({
    required this.label,
    required this.child,
    this.controlWidth = 300,
    this.keepInlineWhenNarrow = false,
  });

  final String label;
  final Widget child;
  final double controlWidth;
  final bool keepInlineWhenNarrow;

  @override
  Widget build(BuildContext context) {
    final colors = SettingsPageColors.of(context);
    final labelWidget = Text(
      label,
      style: TextStyle(
        color: colors.textStrong,
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 38),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 430 && !keepInlineWhenNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                labelWidget,
                const SizedBox(height: 8),
                SizedBox(width: double.infinity, child: child),
              ],
            );
          }
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: labelWidget),
              const SizedBox(width: 18),
              SizedBox(
                width: controlWidth,
                child: Align(
                  alignment: Alignment.centerRight,
                  widthFactor: 1,
                  child: SizedBox(width: controlWidth, child: child),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TimePicker extends StatefulWidget {
  const _TimePicker({required this.value, required this.onChange});

  static final _hours = List.generate(
    24,
    (index) => index.toString().padLeft(2, '0'),
  );
  static final _minutes = List.generate(
    60,
    (index) => index.toString().padLeft(2, '0'),
  );

  final String value;
  final ValueChanged<String> onChange;

  @override
  State<_TimePicker> createState() => _TimePickerState();
}

class _TimePickerState extends State<_TimePicker> {
  final _link = LayerLink();
  OverlayEntry? _overlayEntry;
  var _open = false;
  var _openUpward = false;

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = SettingsPageColors.of(context);

    return CompositedTransformTarget(
      link: _link,
      child: SizedBox(
        width: 112,
        height: 38,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            alignment: Alignment.centerLeft,
            backgroundColor:
                _open ? colors.selectOpenSurface : colors.inputSurface,
            foregroundColor: _open ? colors.accentStrong : colors.textStrong,
            side: BorderSide(
              color: _open ? colors.selectOpenBorder : colors.inputBorder,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10),
          ),
          onPressed: _toggleOpen,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(FluentIcons.clock_20_regular, size: 15),
            ],
          ),
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
    final parts = widget.value.split(':');
    final hour = parts.first;
    final minute = parts.last;
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
            child: _TimePickerPanel(
              hour: hour,
              minute: minute,
              onHourSelected: (nextHour) {
                widget.onChange('$nextHour:$minute');
                _overlayEntry?.markNeedsBuild();
              },
              onMinuteSelected: (nextMinute) {
                widget.onChange('$hour:$nextMinute');
                _close();
              },
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
    });
    _removeOverlay();
  }

  void _updateDropdownGeometry() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) {
      return;
    }
    final position = box.localToGlobal(Offset.zero);
    final viewportHeight = MediaQuery.sizeOf(context).height;
    final bottomBoundary = math.max(0.0, viewportHeight - 128.0);
    const desiredHeight = 236.0;
    final spaceBelow = math.max(
      0.0,
      bottomBoundary - position.dy - box.size.height - 8.0,
    );
    final spaceAbove = math.max(0.0, position.dy - 8.0);
    final nextOpenUpward =
        spaceBelow < desiredHeight && spaceAbove > spaceBelow;
    if (_openUpward == nextOpenUpward) {
      return;
    }
    setState(() {
      _openUpward = nextOpenUpward;
    });
    _overlayEntry?.markNeedsBuild();
  }
}

class _TimePickerPanel extends StatelessWidget {
  const _TimePickerPanel({
    required this.hour,
    required this.minute,
    required this.onHourSelected,
    required this.onMinuteSelected,
  });

  final String hour;
  final String minute;
  final ValueChanged<String> onHourSelected;
  final ValueChanged<String> onMinuteSelected;

  @override
  Widget build(BuildContext context) {
    final colors = SettingsPageColors.of(context);
    return Material(
      color: Colors.transparent,
      child: DecoratedBox(
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
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _TimePickerColumn(
                options: _TimePicker._hours,
                selectedValue: hour,
                onSelected: onHourSelected,
              ),
              const SizedBox(width: 6),
              _TimePickerColumn(
                options: _TimePicker._minutes,
                selectedValue: minute,
                onSelected: onMinuteSelected,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimePickerColumn extends StatefulWidget {
  const _TimePickerColumn({
    required this.options,
    required this.selectedValue,
    required this.onSelected,
  });

  final List<String> options;
  final String selectedValue;
  final ValueChanged<String> onSelected;

  @override
  State<_TimePickerColumn> createState() => _TimePickerColumnState();
}

class _TimePickerColumnState extends State<_TimePickerColumn> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController(
      initialScrollOffset: _initialScrollOffset(widget.selectedValue),
    );
  }

  @override
  void didUpdateWidget(covariant _TimePickerColumn oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedValue != widget.selectedValue) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) {
          return;
        }
        _scrollController.animateTo(
          _initialScrollOffset(widget.selectedValue),
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
        );
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = SettingsPageColors.of(context);
    return SizedBox(
      width: 58,
      height: 220,
      child: ListView(
        controller: _scrollController,
        padding: EdgeInsets.zero,
        children:
            widget.options.map((option) {
              final selected = option == widget.selectedValue;
              return TextButton(
                style: TextButton.styleFrom(
                  foregroundColor:
                      selected ? colors.accentStrong : colors.textStrong,
                  backgroundColor:
                      selected ? colors.accentHover : Colors.transparent,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size.fromHeight(32),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(7),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onPressed: () {
                  widget.onSelected(option);
                },
                child: Text(option),
              );
            }).toList(),
      ),
    );
  }

  double _initialScrollOffset(String value) {
    final index = widget.options.indexOf(value);
    if (index <= 0) {
      return 0;
    }
    return math.max(0, index * 32.0 - 94.0);
  }
}

class _SettingsIconButton extends StatelessWidget {
  const _SettingsIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.busy = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return _settingsNoTextScaling(
      context,
      SmPlayerTextIconButton(
        icon: icon,
        label: tooltip,
        loading: busy,
        showLabel: false,
        minWidth: 52,
        height: 42,
        iconSize: 24,
        onPressed: onPressed,
      ),
    );
  }
}

class _FeedbackActionButton extends StatefulWidget {
  const _FeedbackActionButton({
    required this.showOptions,
    required this.onToggle,
    required this.onDismiss,
    required this.onSelected,
  });

  final bool showOptions;
  final VoidCallback onToggle;
  final VoidCallback onDismiss;
  final ValueChanged<String> onSelected;

  @override
  State<_FeedbackActionButton> createState() => _FeedbackActionButtonState();
}

class _FeedbackActionButtonState extends State<_FeedbackActionButton> {
  final _link = LayerLink();
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  OverlayEntry? _overlayEntry;

  @override
  void dispose() {
    _removeOverlay();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _FeedbackActionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (widget.showOptions) {
        _showOverlay();
      } else {
        _removeOverlay();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;

    return CompositedTransformTarget(
      link: _link,
      child: SettingsActionButton(
        onClick: widget.onToggle,
        child: Text(i18n.t('settings.feedback')),
      ),
    );
  }

  void _showOverlay() {
    _removeOverlay();
    _overlayEntry = OverlayEntry(builder: _buildOverlay);
    Overlay.of(context, rootOverlay: true).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Widget _buildOverlay(BuildContext context) {
    final i18n = context.smPlayerI18n;
    return _settingsNoTextScaling(
      context,
      Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: widget.onDismiss,
              child: const SizedBox.expand(),
            ),
          ),
          CompositedTransformFollower(
            link: _link,
            targetAnchor: Alignment.topLeft,
            followerAnchor: Alignment.bottomLeft,
            offset: const Offset(0, -6),
            child: SizedBox(
              width: 170,
              child: _SettingsSelectOptionsPanel<String>(
                options: [
                  SelectSettingOption(
                    value: i18n.t('settings.viaEmail'),
                    label: i18n.t('settings.viaEmail'),
                    icon: FluentIcons.mail_20_regular,
                  ),
                  SelectSettingOption(
                    value: i18n.t('settings.viaWebBrowser'),
                    label: i18n.t('settings.viaWebBrowser'),
                    icon: FluentIcons.globe_20_regular,
                  ),
                ],
                maxHeight: 120,
                value: '',
                searchable: false,
                searchController: _searchController,
                searchFocusNode: _searchFocusNode,
                searchPlaceholder: null,
                emptyLabel: null,
                onSearchChanged: (_) {},
                onSelected: widget.onSelected,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsProgressOverlay extends StatelessWidget {
  const _SettingsProgressOverlay({required this.state});

  final DataTransferState state;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final colors = SettingsPageColors.of(context);
    final label = switch (state) {
      DataTransferState.openingImport => i18n.t('settings.openingImportData'),
      DataTransferState.openingExport => i18n.t('settings.openingExportData'),
      DataTransferState.importing => i18n.t('settings.importingData'),
      DataTransferState.exporting => i18n.t('settings.exportingData'),
      DataTransferState.reloading => i18n.t('settings.dataImported'),
      DataTransferState.idle => '',
    };

    return SettingsDialogOverlay(
      child: Container(
        width: 260,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: colors.dialogSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colors.cardBorder),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfirmSettingsDialog extends StatelessWidget {
  const _ConfirmSettingsDialog({
    required this.title,
    required this.message,
    required this.onCancel,
    required this.onConfirm,
    this.confirmText,
    this.busy = false,
    this.usePopupDialog = false,
  });

  final String title;
  final String message;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  final String? confirmText;
  final bool busy;
  final bool usePopupDialog;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final actionLabel =
        busy
            ? i18n.t('settings.smartMultiArtistFixPending')
            : confirmText ?? i18n.t('common.confirm');
    if (usePopupDialog) {
      return PopupDialog(
        className: 'settings-confirm-dialog ContentDialog',
        navClassName: 'settings-confirm-nav',
        overlayClassName: 'settings-confirm-overlay',
        navLabel: title,
        ariaLabel: title,
        width: 480,
        height: 210,
        onClose: busy ? () {} : onCancel,
        navChildren: [Expanded(child: PopupDialogTitle(title))],
        footer: PopupDialogActions(
          children: [
            PopupDialogActionButton(
              label: actionLabel,
              primary: true,
              loading: busy,
              onPressed: busy ? null : onConfirm,
            ),
            PopupDialogActionButton(
              label: i18n.t('common.cancel'),
              onPressed: busy ? null : onCancel,
            ),
          ],
        ),
        child: _SettingsConfirmMessageContent(message: message),
      );
    }
    return RemoveDialog(
      title: title,
      message: message,
      confirmText: confirmText,
      pendingText: i18n.t('settings.smartMultiArtistFixPending'),
      destructive: false,
      submitting: busy,
      onCancel: onCancel,
      onConfirm: onConfirm,
    );
  }
}

class _SettingsConfirmMessageContent extends StatelessWidget {
  const _SettingsConfirmMessageContent({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = PopupDialogColors.resolve(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 4, 32, 0),
      child: Align(
        alignment: Alignment.topLeft,
        child: Text(
          message,
          textAlign: TextAlign.start,
          style: TextStyle(
            color: colors.text,
            fontSize: 16,
            height: 1.45,
            fontWeight: FontWeight.w500,
            fontVariations: const [FontVariation.weight(540)],
          ),
        ),
      ),
    );
  }
}
