import '../../i18n/app_i18n.dart';

String getQuickJumpTooltip({
  required String key,
  required bool enabled,
  required SmPlayerI18n i18n,
}) {
  final group =
      key == '#'
          ? i18n.t('quickJump.symbolGroup')
          : key == '他'
          ? i18n.t('quickJump.unclassifiedKanji')
          : i18n.t('quickJump.letterGroup', {'key': key});

  return i18n.t(
    enabled ? 'quickJump.enabled' : 'quickJump.disabled',
    {'group': group},
  );
}
