part of 'popup_dialog.dart';

Future<String?> showPopupTextDialog({
  required BuildContext context,
  required String title,
  required String initialValue,
  required String confirmLabel,
  SmPlayerI18n? i18n,
  String? placeholder,
  String Function(String value)? validate,
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
  });

  final SmPlayerI18n i18n;
  final String title;
  final String initialValue;
  final String confirmLabel;
  final String? placeholder;
  final String Function(String value)? validate;

  @override
  State<_PopupTextDialog> createState() => _PopupTextDialogState();
}

class _PopupTextDialogState extends State<_PopupTextDialog> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  var _errorText = '';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _focusNode = FocusNode();
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
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _InputDialogShell(
      ariaLabel: widget.title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _InputDialogTitle(widget.title),
          const SizedBox(height: 18),
          PopupDialogTextField(
            controller: _controller,
            focusNode: _focusNode,
            autofocus: true,
            placeholder: widget.placeholder,
            errorText: _errorText,
            onChanged: (_) {
              if (_errorText.isNotEmpty) {
                setState(() {
                  _errorText = '';
                });
              }
            },
            onSubmitted: (_) {
              _submit();
            },
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
}
