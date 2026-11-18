part of 'settings_page.dart';

final _backgroundSharingAvailableProvider = FutureProvider<bool>(
  (ref) => MusicShareBackgroundPlatform.available(),
);

class _SettingsBackgroundSharing extends ConsumerWidget {
  const _SettingsBackgroundSharing();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!MusicShareBackgroundPlatform.supported) return const SizedBox.shrink();
    if (ref.watch(_backgroundSharingAvailableProvider).valueOrNull != true) {
      return const SizedBox.shrink();
    }
    final share = ref.watch(musicShareProvider);
    final i18n = context.smPlayerI18n;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: ToggleSettingRow(
        label: i18n.t('share.backgroundSharing'),
        hint: i18n.t(
          Platform.isAndroid
              ? 'share.backgroundSharingAndroidHint'
              : 'share.backgroundSharingDesktopHint',
        ),
        checked: share.backgroundSharing,
        enabled:
            share.initialized &&
            share.sharing &&
            !share.busy &&
            !share.updatingBackgroundSharing,
        onChange: (enabled) async {
          try {
            await share.setBackgroundSharing(enabled);
          } catch (error, stack) {
            SystemLog.error('Background sharing setting failed', error, stack);
            if (!context.mounted) return;
            final approval =
                error is PlatformException &&
                (error.code == 'background_approval_required' ||
                    error.code == 'background_notifications_required');
            final notifications =
                error is PlatformException &&
                error.code == 'background_notifications_required';
            showAppNotification(
              context: context,
              message: i18n.t(
                notifications
                    ? 'share.backgroundNotificationsRequired'
                    : approval
                    ? 'share.backgroundApprovalRequired'
                    : 'share.backgroundOperationFailed',
              ),
              actionLabel: approval ? i18n.t('settings.title') : null,
              onAction:
                  approval
                      ? () =>
                          unawaited(MusicShareBackgroundPlatform.openSettings())
                      : null,
            );
          }
        },
      ),
    );
  }
}
