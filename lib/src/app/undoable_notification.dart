import 'dart:async';

import 'package:flutter/material.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';

const undoableNotificationDuration = Duration(seconds: 5);

Future<SnackBarClosedReason> showUndoableSnackBar({
  required BuildContext context,
  required SmPlayerI18n i18n,
  required String message,
  required FutureOr<void> Function() onUndo,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  return messenger
      .showSnackBar(
        SnackBar(
          duration: undoableNotificationDuration,
          content: Text(message),
          action: SnackBarAction(
            label: i18n.t('common.undo'),
            onPressed: () {
              unawaited(Future<void>.sync(onUndo));
            },
          ),
        ),
      )
      .closed;
}
