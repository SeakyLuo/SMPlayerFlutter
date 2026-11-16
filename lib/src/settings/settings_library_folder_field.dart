part of 'settings_page.dart';

class _SettingsLibraryFolderField extends StatelessWidget {
  const _SettingsLibraryFolderField({
    required this.path,
    required this.busy,
    required this.enabled,
    required this.onChoose,
    required this.onCopy,
    required this.onOpen,
  });

  final String path;
  final bool busy;
  final bool enabled;
  final VoidCallback onChoose;
  final VoidCallback onCopy;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = SettingsPageColors.of(context);
    final i18n = context.smPlayerI18n;
    final hasPath = path.isNotEmpty;
    final desktop = Platform.isMacOS || Platform.isWindows || Platform.isLinux;
    return _settingsNoTextScaling(
      context,
      Row(
        children: [
          Expanded(
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: colors.inputSurface,
                border: Border.all(color: colors.inputBorder),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Tooltip(
                message: hasPath ? path : i18n.t('library.chooseFolder'),
                child: TextButton(
                  onPressed: enabled ? onChoose : null,
                  style: TextButton.styleFrom(
                    foregroundColor: colors.textStrong,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    minimumSize: const Size(0, 42),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Row(
                    children: [
                      if (busy)
                        const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        const Icon(FluentIcons.folder_20_regular, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          hasPath ? path : i18n.t('library.chooseFolder'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        FluentIcons.chevron_right_20_regular,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (hasPath) ...[
            const SizedBox(width: 6),
            IconButton(
              tooltip: i18n.t('common.copy'),
              onPressed: onCopy,
              icon: const Icon(FluentIcons.copy_20_regular, size: 20),
              color: colors.textStrong,
              constraints: const BoxConstraints.tightFor(width: 38, height: 40),
              padding: EdgeInsets.zero,
            ),
            if (desktop)
              IconButton(
                tooltip: i18n.t('local.openInFileManager'),
                onPressed: onOpen,
                icon: const Icon(FluentIcons.folder_open_20_regular, size: 20),
                color: colors.textStrong,
                constraints: const BoxConstraints.tightFor(
                  width: 38,
                  height: 40,
                ),
                padding: EdgeInsets.zero,
              ),
          ],
        ],
      ),
    );
  }
}
