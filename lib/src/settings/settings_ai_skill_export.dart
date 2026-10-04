part of 'settings_page.dart';

// ignore_for_file: invalid_use_of_protected_member

extension _SettingsAiSkillExport on _SettingsPageState {
  Future<void> _exportAiSkill(SmPlayerI18n i18n) async {
    setState(() => _exportingAiSkill = true);
    try {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      final bytes = buildAiAgentSkillArchive(aiAgentRemoteController.endpoint);
      final path = await FilePicker.saveFile(
        dialogTitle: i18n.t('settings.aiAgentExportSkill'),
        fileName: 'smplayer-control.zip',
        type: FileType.custom,
        allowedExtensions: ['zip'],
        bytes: bytes,
      );
      if (path != null && mounted) {
        _showMessage(i18n.t('settings.aiAgentSkillExported'));
      }
    } on Object {
      if (mounted) {
        _showMessage(i18n.t('settings.aiAgentSkillExportFailed'));
      }
    } finally {
      if (mounted) {
        setState(() => _exportingAiSkill = false);
      }
    }
  }
}
