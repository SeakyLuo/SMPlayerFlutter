part of 'settings_page.dart';

class _SettingsDownloadLocation extends ConsumerStatefulWidget {
  const _SettingsDownloadLocation();

  @override
  ConsumerState<_SettingsDownloadLocation> createState() =>
      _SettingsDownloadLocationState();
}

class _SettingsDownloadLocationState
    extends ConsumerState<_SettingsDownloadLocation> {
  var _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await _read(action);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _read(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (!mounted) return;
      showAppNotification(
        context: context,
        message: context.smPlayerI18n.t(
          error is MusicShareException
              ? error.messageKey
              : 'share.downloadSettingsFailed',
        ),
      );
    }
  }

  Future<void> _choose(MusicShareDownloadSettings settings) => _run(() async {
    final i18n = context.smPlayerI18n;
    final path =
        Platform.isMacOS || Platform.isWindows
            ? await pickDirectoryFromDesktopShell(
              title: i18n.t('share.downloadLocation'),
              buttonLabel: i18n.t('library.chooseFolder'),
              defaultPath: settings.customDirectory,
              locale: i18n.locale,
            )
            : await FilePicker.getDirectoryPath(
              dialogTitle: i18n.t('share.downloadLocation'),
            );
    if (path != null) await settings.setDirectory(path);
  });

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(musicShareDownloadSettingsProvider);
    final i18n = context.smPlayerI18n;
    final colors = SettingsPageColors.of(context);
    final enabled = settings.initialized && !settings.saving && !_busy;
    return Material(
      type: MaterialType.transparency,
      child: Column(
        spacing: 6,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            i18n.t('share.downloadLocation'),
            style: TextStyle(
              color: colors.textStrong,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          RadioGroup<MusicShareDownloadLocation>(
            groupValue: settings.location,
            onChanged: (value) {
              if (value != null && enabled) {
                unawaited(_run(() => settings.setLocation(value)));
              }
            },
            child: Row(
              children: [
                for (final location in MusicShareDownloadLocation.values)
                  Expanded(
                    child: RadioListTile<MusicShareDownloadLocation>(
                      value: location,
                      enabled: enabled,
                      activeColor: colors.accent,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      title: Text(
                        i18n.t(
                          location == MusicShareDownloadLocation.library
                              ? 'library.title'
                              : 'share.downloadCustomDirectory',
                        ),
                        style: TextStyle(
                          fontSize: 14,
                          color: colors.textStrong,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (settings.location == MusicShareDownloadLocation.directory)
            _SettingsLibraryFolderField(
              path: settings.customDirectory ?? i18n.t('share.systemDownloads'),
              busy: _busy,
              enabled: enabled,
              onChoose: () => unawaited(_choose(settings)),
              onCopy:
                  () => unawaited(
                    _read(() async {
                      final path = await settings.resolveDirectory(
                        libraryRoot: '',
                      );
                      await Clipboard.setData(ClipboardData(text: path));
                    }),
                  ),
              onOpen:
                  () => unawaited(
                    _read(() async {
                      final path = await settings.resolveDirectory(
                        libraryRoot: '',
                      );
                      await openFolderInShell(path);
                    }),
                  ),
            ),
        ],
      ),
    );
  }
}
