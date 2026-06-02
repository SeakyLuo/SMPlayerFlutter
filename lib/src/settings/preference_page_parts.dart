part of 'settings_page.dart';

class _PreferenceInfo extends StatelessWidget {
  const _PreferenceInfo();

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final colors = SettingsPageColors.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 9,
            backgroundColor: Colors.transparent,
            child: Text('i', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              i18n.t('preferences.info'),
              style: TextStyle(color: colors.textMuted, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreferenceSectionFrame extends StatelessWidget {
  const _PreferenceSectionFrame({
    required this.title,
    required this.counter,
    required this.action,
    required this.child,
  });

  final String title;
  final String counter;
  final Widget action;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = SettingsPageColors.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.cardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.cardBorder),
      ),
      child: Column(
        children: [
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            color: colors.preferenceHeader,
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: colors.accentHover,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          counter,
                          style: const TextStyle(
                            color: SettingsPageColors.accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                action,
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _PreferenceOthersSection extends StatelessWidget {
  const _PreferenceOthersSection({
    required this.items,
    required this.onUpdateItem,
    required this.onRemoveItem,
  });

  final List<PreferenceItemSnapshot> items;
  final void Function(
    PreferenceItemSnapshot item,
    PreferenceItemSnapshot update,
  )
  onUpdateItem;
  final ValueChanged<PreferenceItemSnapshot> onRemoveItem;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;

    return _PreferenceSectionFrame(
      title: i18n.t('settings.others'),
      counter: '${items.length}',
      action: const SizedBox.shrink(),
      child: PreferenceItems(
        items: items,
        onUpdateItem: onUpdateItem,
        onRemoveItem: onRemoveItem,
      ),
    );
  }
}

class _PreferenceEmpty extends StatelessWidget {
  const _PreferenceEmpty();

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final colors = SettingsPageColors.of(context);

    return SizedBox(
      height: 44,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Text(
          i18n.t('preferences.noItems'),
          style: TextStyle(color: colors.textMuted),
        ),
      ),
    );
  }
}

class _PreferenceSwitch extends StatelessWidget {
  const _PreferenceSwitch({required this.checked, required this.onChanged});

  final bool checked;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Switch(
      value: checked,
      // ignore: deprecated_member_use
      activeColor: SettingsPageColors.accent,
      onChanged: onChanged,
    );
  }
}
