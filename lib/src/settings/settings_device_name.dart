part of 'settings_page.dart';

class _SettingsDeviceName extends ConsumerStatefulWidget {
  const _SettingsDeviceName();

  @override
  ConsumerState<_SettingsDeviceName> createState() =>
      _SettingsDeviceNameState();
}

class _SettingsDeviceNameState extends ConsumerState<_SettingsDeviceName> {
  final _name = TextEditingController();
  var _editing = false;
  var _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final value = _name.text.trim();
    final i18n = context.smPlayerI18n;
    if (value.isEmpty) {
      showAppNotification(
        context: context,
        message: i18n.t('share.nameRequired'),
      );
      return;
    }
    setState(() => _saving = true);
    final share = ref.read(musicShareProvider);
    await runMusicShareAction(context, () async {
      final previous = share.name;
      share.name = value;
      try {
        await share.save();
        share.localDataChanged('library');
      } catch (_) {
        share.name = previous;
        rethrow;
      }
      if (mounted) setState(() => _editing = false);
    });
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final share = ref.watch(musicShareProvider);
    final i18n = context.smPlayerI18n;
    final colors = SettingsPageColors.of(context);
    return _SettingsRowFrame(
      label: i18n.t('share.deviceName'),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.centerRight,
              decoration: BoxDecoration(
                color: colors.inputSurface,
                border: Border.all(color: colors.inputBorder),
                borderRadius: BorderRadius.circular(8),
              ),
              child:
                  _editing
                      ? TextField(
                        controller: _name,
                        autofocus: true,
                        enabled: !_saving,
                        maxLength: 80,
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          color: colors.textStrong,
                          fontSize: 14,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          counterText: '',
                          contentPadding: EdgeInsets.zero,
                        ),
                        onSubmitted: _saving ? null : (_) => _save(),
                      )
                      : Text(
                        share.initialized ? share.name : '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textStrong,
                          fontSize: 14,
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
                tooltip: i18n.t('settings.saveChanges'),
                onPressed: _saving ? null : () => unawaited(_save()),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox.square(
              dimension: 42,
              child: _SettingsIconButton(
                icon: FluentIcons.dismiss_20_regular,
                tooltip: i18n.t('common.cancel'),
                onPressed:
                    _saving ? null : () => setState(() => _editing = false),
              ),
            ),
          ] else
            SizedBox.square(
              dimension: 42,
              child: _SettingsIconButton(
                icon: FluentIcons.edit_20_regular,
                tooltip: i18n.t('common.edit'),
                onPressed:
                    !share.initialized
                        ? null
                        : () => setState(() {
                          _name.text = share.name;
                          _editing = true;
                        }),
              ),
            ),
        ],
      ),
    );
  }
}
