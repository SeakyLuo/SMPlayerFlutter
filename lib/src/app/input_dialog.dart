import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../i18n/app_i18n.dart';

typedef SmPlayerInputValidator = String Function(String value);

Future<String?> showSmPlayerInputDialog({
  required BuildContext context,
  required SmPlayerI18n i18n,
  required String title,
  required String defaultValue,
  required String confirmText,
  String? placeholder,
  SmPlayerInputValidator? validate,
}) {
  return showDialog<String>(
    context: context,
    builder:
        (dialogContext) => _SmPlayerInputDialog(
          i18n: i18n,
          title: title,
          defaultValue: defaultValue,
          placeholder: placeholder,
          confirmText: confirmText,
          validate: validate,
        ),
  );
}

Future<bool> showSmPlayerConfirmDialog({
  required BuildContext context,
  required SmPlayerI18n i18n,
  required String title,
  required String message,
  required String confirmText,
  String? pendingText,
  bool destructive = true,
  FutureOr<void> Function()? onConfirm,
}) async {
  return await showDialog<bool>(
        context: context,
        builder:
            (dialogContext) => _SmPlayerConfirmDialog(
              i18n: i18n,
              title: title,
              message: message,
              confirmText: confirmText,
              pendingText: pendingText,
              destructive: destructive,
              onConfirm: onConfirm,
            ),
      ) ??
      false;
}

class _SmPlayerInputDialog extends StatefulWidget {
  const _SmPlayerInputDialog({
    required this.i18n,
    required this.title,
    required this.defaultValue,
    required this.confirmText,
    this.placeholder,
    this.validate,
  });

  final SmPlayerI18n i18n;
  final String title;
  final String defaultValue;
  final String confirmText;
  final String? placeholder;
  final SmPlayerInputValidator? validate;

  @override
  State<_SmPlayerInputDialog> createState() => _SmPlayerInputDialogState();
}

class _SmPlayerInputDialogState extends State<_SmPlayerInputDialog> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  var _errorText = '';
  var _submitting = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.defaultValue);
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
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (!_submitting) {
            Navigator.of(context).pop();
          }
        },
      },
      child: AlertDialog(
        title: Text(widget.title),
        content: TextField(
          controller: _controller,
          focusNode: _focusNode,
          enabled: !_submitting,
          autofocus: true,
          decoration: InputDecoration(
            hintText: widget.placeholder,
            errorText: _errorText.isEmpty ? null : _errorText,
          ),
          onChanged: (_) {
            if (_errorText.isNotEmpty) {
              setState(() {
                _errorText = '';
              });
            }
          },
          onSubmitted: (_) {
            unawaited(_confirm());
          },
        ),
        actions: [
          TextButton(
            onPressed: _submitting ? null : () => Navigator.of(context).pop(),
            child: Text(widget.i18n.t('common.cancel')),
          ),
          FilledButton(
            onPressed: _submitting ? null : () => unawaited(_confirm()),
            child:
                _submitting
                    ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : Text(widget.confirmText),
          ),
        ],
      ),
    );
  }

  Future<void> _confirm() async {
    if (_submitting) {
      return;
    }
    final value = _controller.text.trim();
    final validation = widget.validate?.call(value) ?? '';
    if (validation.isNotEmpty) {
      setState(() {
        _errorText = validation;
      });
      return;
    }
    setState(() {
      _submitting = true;
    });
    Navigator.of(context).pop(value);
  }
}

class _SmPlayerConfirmDialog extends StatefulWidget {
  const _SmPlayerConfirmDialog({
    required this.i18n,
    required this.title,
    required this.message,
    required this.confirmText,
    required this.destructive,
    this.pendingText,
    this.onConfirm,
  });

  final SmPlayerI18n i18n;
  final String title;
  final String message;
  final String confirmText;
  final String? pendingText;
  final bool destructive;
  final FutureOr<void> Function()? onConfirm;

  @override
  State<_SmPlayerConfirmDialog> createState() => _SmPlayerConfirmDialogState();
}

class _SmPlayerConfirmDialogState extends State<_SmPlayerConfirmDialog> {
  var _submitting = false;

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (!_submitting) {
            Navigator.of(context).pop(false);
          }
        },
      },
      child: AlertDialog(
        title: Text(widget.title),
        content: Text(widget.message),
        actions: [
          TextButton(
            onPressed:
                _submitting ? null : () => Navigator.of(context).pop(false),
            child: Text(widget.i18n.t('common.cancel')),
          ),
          FilledButton.icon(
            style:
                widget.destructive
                    ? FilledButton.styleFrom(
                      backgroundColor: const Color(0xffb3261e),
                    )
                    : null,
            onPressed: _submitting ? null : () => unawaited(_confirm()),
            icon:
                _submitting
                    ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const SizedBox.shrink(),
            label: Text(
              _submitting
                  ? widget.pendingText ?? widget.confirmText
                  : widget.confirmText,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirm() async {
    if (_submitting) {
      return;
    }
    final onConfirm = widget.onConfirm;
    if (onConfirm == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _submitting = true;
    });
    await onConfirm();
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }
}
