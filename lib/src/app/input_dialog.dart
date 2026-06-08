import 'dart:async';

import 'package:flutter/material.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/ui/popup_dialog.dart';

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
  return showPopupTextDialog(
    context: context,
    title: title,
    initialValue: defaultValue,
    confirmLabel: confirmText,
    i18n: i18n,
    placeholder: placeholder,
    validate: validate,
  );
}

Future<bool> showSmPlayerConfirmDialog({
  required BuildContext context,
  required SmPlayerI18n i18n,
  required String title,
  required String message,
  required String confirmText,
  bool destructive = true,
  FutureOr<void> Function()? onConfirm,
}) {
  return showPopupConfirmDialog(
    context: context,
    title: title,
    message: message,
    confirmLabel: confirmText,
    i18n: i18n,
    destructive: destructive,
    onConfirm:
        onConfirm == null
            ? null
            : () async {
              await onConfirm();
            },
  );
}
