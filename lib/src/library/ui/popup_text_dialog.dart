part of 'popup_dialog.dart';

Future<String?> showPopupTextDialog({
  required BuildContext context,
  required String title,
  required String initialValue,
  required String confirmLabel,
  SmPlayerI18n? i18n,
  String? placeholder,
  String Function(String value)? validate,
  List<SearchHistoryEntry> searchHistoryEntries = const [],
  ValueChanged<String>? onSearchHistorySelected,
  ValueChanged<int>? onRemoveSearchHistory,
  VoidCallback? onClearSearchHistory,
}) {
  return showDialog<String>(
    context: context,
    barrierColor: Colors.transparent,
    barrierDismissible: false,
    builder: (dialogContext) {
      final dialogI18n =
          dialogContext.maybeSmPlayerI18n ??
          i18n ??
          const SmPlayerI18n(locale: smPlayerFallbackLocale, messages: {});
      return _PopupTextDialog(
        i18n: dialogI18n,
        title: title,
        initialValue: initialValue,
        confirmLabel: confirmLabel,
        placeholder: placeholder,
        validate: validate,
        searchHistoryEntries: searchHistoryEntries,
        onSearchHistorySelected: onSearchHistorySelected,
        onRemoveSearchHistory: onRemoveSearchHistory,
        onClearSearchHistory: onClearSearchHistory,
      );
    },
  );
}

class _PopupTextDialog extends StatefulWidget {
  const _PopupTextDialog({
    required this.i18n,
    required this.title,
    required this.initialValue,
    required this.confirmLabel,
    this.placeholder,
    this.validate,
    this.searchHistoryEntries = const [],
    this.onSearchHistorySelected,
    this.onRemoveSearchHistory,
    this.onClearSearchHistory,
  });

  final SmPlayerI18n i18n;
  final String title;
  final String initialValue;
  final String confirmLabel;
  final String? placeholder;
  final String Function(String value)? validate;
  final List<SearchHistoryEntry> searchHistoryEntries;
  final ValueChanged<String>? onSearchHistorySelected;
  final ValueChanged<int>? onRemoveSearchHistory;
  final VoidCallback? onClearSearchHistory;

  @override
  State<_PopupTextDialog> createState() => _PopupTextDialogState();
}

class _PopupTextDialogState extends State<_PopupTextDialog> {
  final _historyDropdownController = OverlayPortalController();
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  late List<SearchHistoryEntry> _searchHistoryEntries;
  var _errorText = '';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _focusNode = FocusNode();
    _focusNode.addListener(_handleFocusChanged);
    _searchHistoryEntries = widget.searchHistoryEntries.toList();
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

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChanged);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _syncHistoryDropdown();
    return _InputDialogShell(
      ariaLabel: widget.title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _InputDialogTitle(widget.title),
          const SizedBox(height: 18),
          OverlayPortal.overlayChildLayoutBuilder(
            controller: _historyDropdownController,
            overlayChildBuilder: (context, info) {
              final origin = MatrixUtils.transformPoint(
                info.childPaintTransform,
                Offset.zero,
              );
              return Positioned(
                left: origin.dx,
                top: origin.dy + info.childSize.height + 10,
                width: info.childSize.width,
                child: TextFieldTapRegion(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 260),
                    child: PageSearchHistoryPanel(
                      entries: _searchHistoryEntries,
                      i18n: widget.i18n,
                      onSelect: _submitSearchHistory,
                      onRemove: _removeSearchHistory,
                      onClear: _clearSearchHistory,
                    ),
                  ),
                ),
              );
            },
            child: PopupDialogTextField(
              controller: _controller,
              focusNode: _focusNode,
              autofocus: true,
              placeholder: widget.placeholder,
              errorText: _errorText,
              onChanged: (_) {
                setState(() {
                  if (_errorText.isNotEmpty) {
                    _errorText = '';
                  }
                });
              },
              onSubmitted: (_) {
                _submit();
              },
              onTapOutside: (_) {
                _focusNode.unfocus();
              },
            ),
          ),
          PopupDialogActions(
            compact: true,
            children: [
              PopupDialogActionButton(
                label: widget.confirmLabel,
                primary: true,
                onPressed: _submit,
              ),
              PopupDialogActionButton(
                label: widget.i18n.t('common.cancel'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _syncHistoryDropdown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (_focusNode.hasFocus &&
          _controller.text.trim().isEmpty &&
          _searchHistoryEntries.isNotEmpty) {
        _historyDropdownController.show();
      } else {
        _historyDropdownController.hide();
      }
    });
  }

  void _handleFocusChanged() {
    setState(() {});
  }

  void _submit() {
    final value = _controller.text.trim();
    final validation = widget.validate?.call(value) ?? '';
    if (validation.isNotEmpty) {
      setState(() {
        _errorText = validation;
      });
      return;
    }
    Navigator.of(context).pop(value);
  }

  void _submitSearchHistory(String query) {
    widget.onSearchHistorySelected?.call(query);
    Navigator.of(context).pop(query);
  }

  void _removeSearchHistory(int entryId) {
    widget.onRemoveSearchHistory?.call(entryId);
    setState(() {
      _searchHistoryEntries =
          _searchHistoryEntries.where((entry) => entry.id != entryId).toList();
    });
  }

  void _clearSearchHistory() {
    widget.onClearSearchHistory?.call();
    setState(() {
      _searchHistoryEntries = [];
    });
  }
}
