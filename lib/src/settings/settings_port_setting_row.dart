part of 'settings_page.dart';

typedef _PortConfirmCallback = Future<bool> Function(int port);

class _PortSettingRow extends StatefulWidget {
  const _PortSettingRow({
    required this.label,
    required this.value,
    required this.editTooltip,
    required this.confirmTooltip,
    required this.cancelTooltip,
    required this.onConfirm,
    required this.onInvalid,
    required this.onEditingChanged,
    this.enabled = true,
  });

  final String label;
  final int value;
  final String editTooltip;
  final String confirmTooltip;
  final String cancelTooltip;
  final _PortConfirmCallback onConfirm;
  final VoidCallback onInvalid;
  final ValueChanged<bool> onEditingChanged;
  final bool enabled;

  @override
  State<_PortSettingRow> createState() => _PortSettingRowState();
}

class _PortSettingRowState extends State<_PortSettingRow> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  var _editing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value.toString());
    _focusNode = FocusNode(canRequestFocus: false);
  }

  @override
  void didUpdateWidget(_PortSettingRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value && !_editing) {
      _controller.text = widget.value.toString();
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _beginEdit() {
    _controller.text = widget.value.toString();
    _focusNode.canRequestFocus = true;
    setState(() {
      _editing = true;
    });
    widget.onEditingChanged(true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _focusNode.requestFocus();
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
    });
  }

  Future<void> _confirm() async {
    if (!widget.enabled) {
      return;
    }
    final port = int.tryParse(_controller.text);
    if (port == null || port < 1 || port > 65535) {
      widget.onInvalid();
      return;
    }
    if (port != widget.value && !await widget.onConfirm(port)) {
      return;
    }
    if (mounted) {
      _finishEditing();
    }
  }

  void _cancel() {
    if (!widget.enabled) {
      return;
    }
    _controller.text = widget.value.toString();
    _finishEditing();
  }

  void _finishEditing() {
    _focusNode
      ..unfocus()
      ..canRequestFocus = false;
    setState(() {
      _editing = false;
    });
    widget.onEditingChanged(false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = SettingsPageColors.of(context);
    return _SettingsRowFrame(
      label: widget.label,
      controlWidth: 238,
      child: Row(
        children: [
          Expanded(
            child: CallbackShortcuts(
              bindings:
                  widget.enabled
                      ? {
                        const SingleActivator(LogicalKeyboardKey.escape):
                            _cancel,
                      }
                      : const {},
              child: IgnorePointer(
                ignoring: !_editing || !widget.enabled,
                child: AnimatedBuilder(
                  animation: _focusNode,
                  builder: (context, child) {
                    return Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: colors.inputSurface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color:
                              _focusNode.hasFocus
                                  ? colors.accent
                                  : colors.inputBorder,
                          width: _focusNode.hasFocus ? 1.5 : 1,
                        ),
                      ),
                      child: child,
                    );
                  },
                  child:
                      _editing
                          ? Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Center(
                              child: SizedBox(
                                width: double.infinity,
                                height: 18,
                                child: EditableText(
                                  controller: _controller,
                                  focusNode: _focusNode,
                                  readOnly: !widget.enabled,
                                  keyboardType: TextInputType.number,
                                  textInputAction: TextInputAction.done,
                                  textAlign: TextAlign.end,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(5),
                                  ],
                                  onSubmitted:
                                      widget.enabled
                                          ? (_) => unawaited(_confirm())
                                          : null,
                                  style: TextStyle(
                                    color: colors.textStrong,
                                    fontSize: 14,
                                    height: 1,
                                  ),
                                  strutStyle: const StrutStyle(
                                    fontSize: 14,
                                    height: 1,
                                    forceStrutHeight: true,
                                  ),
                                  cursorColor: colors.accent,
                                  cursorHeight: 18,
                                  backgroundCursorColor: colors.inputSurface,
                                  selectionColor: colors.accent.withValues(
                                    alpha: 0.28,
                                  ),
                                  keyboardAppearance:
                                      Theme.of(context).brightness,
                                ),
                              ),
                            ),
                          )
                          : Align(
                            alignment: Alignment.centerRight,
                            child: Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: Text(
                                widget.value.toString(),
                                style: TextStyle(
                                  color: colors.textStrong,
                                  fontSize: 14,
                                  height: 1,
                                ),
                              ),
                            ),
                          ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (_editing) ...[
            SizedBox.square(
              dimension: 42,
              child: _SettingsIconButton(
                icon: FluentIcons.checkmark_20_regular,
                tooltip: widget.confirmTooltip,
                onPressed: widget.enabled ? () => unawaited(_confirm()) : null,
              ),
            ),
            const SizedBox(width: 8),
            SizedBox.square(
              dimension: 42,
              child: _SettingsIconButton(
                icon: FluentIcons.dismiss_20_regular,
                tooltip: widget.cancelTooltip,
                onPressed: widget.enabled ? _cancel : null,
              ),
            ),
          ] else
            SizedBox.square(
              dimension: 42,
              child: _SettingsIconButton(
                icon: FluentIcons.edit_20_regular,
                tooltip: widget.editTooltip,
                onPressed: widget.enabled ? _beginEdit : null,
              ),
            ),
        ],
      ),
    );
  }
}
