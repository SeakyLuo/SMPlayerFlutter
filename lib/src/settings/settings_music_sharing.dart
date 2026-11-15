part of 'settings_page.dart';

class _SettingsMusicSharing extends ConsumerStatefulWidget {
  const _SettingsMusicSharing();

  @override
  ConsumerState<_SettingsMusicSharing> createState() =>
      _SettingsMusicSharingState();
}

class _SettingsMusicSharingState extends ConsumerState<_SettingsMusicSharing> {
  var _editingPort = false;
  final _connectionInfoButtonKey = GlobalKey();

  Rect? _connectionInfoCloseTarget() {
    if (!mounted) return null;
    final buttonContext = _connectionInfoButtonKey.currentContext;
    if (buttonContext == null) return null;
    final box = buttonContext.findRenderObject()! as RenderBox;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    final viewport = Offset.zero & MediaQuery.sizeOf(context);
    return viewport.overlaps(rect) ? rect : null;
  }

  @override
  Widget build(BuildContext context) {
    final share = ref.watch(musicShareProvider);
    final i18n = context.smPlayerI18n;
    final running = share.initialized && share.server.running;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ToggleSettingRow(
          label: i18n.t('share.shareLibrary'),
          hint: i18n.t('share.sharingHint'),
          checked: running,
          enabled: share.initialized && !share.busy && !_editingPort,
          onChange:
              (enabled) => runMusicShareAction(context, () async {
                await share.setSharing(enabled);
                if (enabled && context.mounted) {
                  await WidgetsBinding.instance.endOfFrame;
                  if (context.mounted) {
                    await showMusicShareConnectionInfo(
                      context,
                      closeTarget: _connectionInfoCloseTarget,
                    );
                  }
                }
              }),
        ),
        const SizedBox(height: 16),
        if (share.initialized)
          _PortSettingRow(
            label: i18n.t('share.port'),
            value: share.port,
            enabled: !share.busy,
            editTooltip: i18n.t('common.edit'),
            confirmTooltip: i18n.t('settings.saveChanges'),
            cancelTooltip: i18n.t('common.cancel'),
            onEditingChanged:
                (editing) => setState(() => _editingPort = editing),
            onInvalid:
                () => showAppNotification(
                  context: context,
                  message: i18n.t('settings.aiAgentPortInvalid'),
                ),
            onConfirm: (port) async {
              try {
                await share.setPort(port);
                return true;
              } catch (_) {
                if (context.mounted) {
                  showAppNotification(
                    context: context,
                    message: i18n.t('share.portUpdateFailed'),
                  );
                }
                return false;
              }
            },
          ),
        const SizedBox(height: 16),
        SettingsButtonRow(
          children: [
            SettingsActionButton(
              icon: FluentIcons.plug_connected_24_regular,
              onClick: () => showMusicShareDialog(context),
              child: Text(i18n.t('share.connectComputer')),
            ),
            SettingsActionButton(
              icon: FluentIcons.desktop_24_regular,
              disabled: !share.initialized,
              onClick: () => showMusicShareAuthorizedDevices(context),
              child: Text(i18n.t('share.authorizedDevices')),
            ),
            if (running)
              SettingsActionButton(
                key: _connectionInfoButtonKey,
                icon: FluentIcons.qr_code_24_regular,
                onClick:
                    () => showMusicShareConnectionInfo(
                      context,
                      closeTarget: _connectionInfoCloseTarget,
                    ),
                child: Text(i18n.t('share.connectionInfo')),
              ),
          ],
        ),
      ],
    );
  }
}
