import '../../i18n/app_i18n.dart';

String getQuickJumpTooltip({
  required String key,
  required bool enabled,
  required String targetName,
  required String basisName,
  required SmPlayerI18n i18n,
}) {
  final group =
      key == '#'
          ? i18n.t('quickJump.symbolGroup')
          : i18n.t('quickJump.letterGroup', {'key': key});

  return enabled
      ? i18n.t('quickJump.enabled', {
        'target': targetName,
        'basis': basisName,
        'group': group,
      })
      : i18n.t('quickJump.disabled', {
        'target': targetName,
        'basis': basisName,
        'group': group,
      });
}
