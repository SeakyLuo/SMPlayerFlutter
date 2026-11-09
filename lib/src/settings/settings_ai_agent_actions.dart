part of 'settings_page.dart';

extension _SettingsAiAgentActions on _SettingsPageState {
  Future<void> _setAiAgentEnabled(bool enabled, SmPlayerI18n i18n) async {
    final previousSnapshot = _settingsController.snapshot;
    final update = AppSettingsUpdate(aiAgentEnabled: enabled);
    var updated = false;
    _updateSettingsPageState(() {
      _updatingAiAgent = true;
    });
    try {
      if (enabled) {
        await aiAgentRemoteController.start(port: previousSnapshot.aiAgentPort);
      } else {
        await aiAgentRemoteController.stop();
      }
      await _settingsController.updateSettings(update);
      updated = true;
    } on Object {
      _settingsController.restoreSnapshot(previousSnapshot);
      if (enabled) {
        await aiAgentRemoteController.stop();
      } else {
        await aiAgentRemoteController.start(port: previousSnapshot.aiAgentPort);
      }
      if (mounted) {
        _showMessage(i18n.t('settings.aiAgentUpdateFailed'));
      }
    } finally {
      if (mounted) {
        _updateSettingsPageState(() {
          _updatingAiAgent = false;
        });
      }
    }
    if (updated) {
      widget.onUpdateSettings?.call(update);
    }
  }

  Future<bool> _setAiAgentPort(int port, SmPlayerI18n i18n) async {
    final previousSnapshot = _settingsController.snapshot;
    final update = AppSettingsUpdate(aiAgentPort: port);
    var updated = false;
    _updateSettingsPageState(() {
      _updatingAiAgent = true;
    });
    try {
      if (previousSnapshot.aiAgentEnabled) {
        await aiAgentRemoteController.changePort(port);
      } else {
        aiAgentRemoteController.configurePort(port);
      }
      await _settingsController.updateSettings(update);
      updated = true;
    } on Object {
      _settingsController.restoreSnapshot(previousSnapshot);
      if (previousSnapshot.aiAgentEnabled) {
        if (aiAgentRemoteController.port != previousSnapshot.aiAgentPort) {
          await aiAgentRemoteController.changePort(
            previousSnapshot.aiAgentPort,
          );
        }
      } else {
        aiAgentRemoteController.configurePort(previousSnapshot.aiAgentPort);
      }
      if (mounted) {
        _showMessage(i18n.t('settings.aiAgentPortUpdateFailed'));
      }
    } finally {
      if (mounted) {
        _updateSettingsPageState(() {
          _updatingAiAgent = false;
        });
      }
    }
    if (updated) {
      widget.onUpdateSettings?.call(update);
    }
    return updated;
  }

  Future<void> _copyAiAgentPrompt(SmPlayerI18n i18n) async {
    await _copyAiAgentValue(
      i18n.t('settings.aiAgentPrompt', {
        'appName': i18n.t('app.shell'),
        'endpoint': aiAgentRemoteController.endpoint,
      }),
      i18n,
    );
  }

  Future<void> _copyAiAgentValue(String value, SmPlayerI18n i18n) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) {
      _showMessage(i18n.t('common.copied'));
    }
  }
}
