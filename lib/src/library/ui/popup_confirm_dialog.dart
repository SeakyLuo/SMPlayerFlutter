part of 'popup_dialog.dart';

Future<bool> showPopupConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmLabel,
  SmPlayerI18n? i18n,
  bool destructive = true,
  Future<void> Function()? onConfirm,
}) async {
  final confirmed =
      await showDialog<bool>(
        context: context,
        barrierColor: Colors.transparent,
        barrierDismissible: false,
        builder: (dialogContext) {
          final dialogI18n =
              dialogContext.maybeSmPlayerI18n ??
              i18n ??
              const SmPlayerI18n(locale: smPlayerFallbackLocale, messages: {});
          var submitting = false;

          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              Future<void> submit() async {
                if (submitting) {
                  return;
                }
                final callback = onConfirm;
                if (callback == null) {
                  Navigator.of(dialogContext).pop(true);
                  return;
                }
                setDialogState(() {
                  submitting = true;
                });
                await SchedulerBinding.instance.endOfFrame;
                await callback();
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop(true);
                }
              }

              return _InputDialogShell(
                ariaLabel: title,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _InputDialogTitle(title),
                    const SizedBox(height: 18),
                    PopupDialogMessageContent(
                      message: message,
                      padding: EdgeInsets.zero,
                    ),
                    PopupDialogActions(
                      compact: true,
                      children: [
                        PopupDialogActionButton(
                          label: confirmLabel,
                          primary: true,
                          destructive: destructive,
                          loading: submitting,
                          onPressed:
                              submitting ? null : () => unawaited(submit()),
                        ),
                        PopupDialogActionButton(
                          label: dialogI18n.t('common.cancel'),
                          onPressed:
                              submitting
                                  ? null
                                  : () {
                                    Navigator.of(dialogContext).pop(false);
                                  },
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ) ??
      false;
  if (confirmed) {
    await Future<void>.delayed(popupConfirmDialogDismissDelay);
  }
  return confirmed;
}
