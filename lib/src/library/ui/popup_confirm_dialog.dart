part of 'popup_dialog.dart';

Future<bool> showPopupConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmLabel,
  String? cancelLabel,
  bool cancelIsPrimary = false,
  SmPlayerI18n? i18n,
  bool destructive = true,
  Future<void> Function()? onConfirm,
  VoidCallback? onCancel,
}) async {
  final confirmed =
      await showScopedPopupDialog<bool>(
        context: context,
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
                try {
                  await callback();
                } finally {
                  if (dialogContext.mounted) {
                    setDialogState(() => submitting = false);
                  }
                }
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop(true);
                }
              }

              return _InputDialogShell(
                ariaLabel: title,
                onClose: () => Navigator.of(dialogContext).pop(false),
                canClose: !submitting,
                footer: PopupDialogActions(
                  children: [
                    if (cancelIsPrimary)
                      PopupDialogActionButton(
                        label: cancelLabel ?? dialogI18n.t('common.cancel'),
                        primary: true,
                        onPressed:
                            submitting
                                ? null
                                : () {
                                  onCancel?.call();
                                  Navigator.of(dialogContext).pop(false);
                                },
                      ),
                    PopupDialogActionButton(
                      label: confirmLabel,
                      primary: !cancelIsPrimary,
                      destructive: destructive,
                      loading: submitting,
                      onPressed: submitting ? null : () => unawaited(submit()),
                    ),
                    if (!cancelIsPrimary)
                      PopupDialogActionButton(
                        label: cancelLabel ?? dialogI18n.t('common.cancel'),
                        onPressed:
                            submitting
                                ? null
                                : () {
                                  onCancel?.call();
                                  Navigator.of(dialogContext).pop(false);
                                },
                      ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PopupDialogMessageContent(
                      message: message,
                      padding: EdgeInsets.zero,
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
