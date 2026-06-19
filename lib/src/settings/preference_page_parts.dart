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
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.fromBorderSide(
                  BorderSide(color: SettingsPageColors.inputBorder),
                ),
              ),
              child: Center(
                child: Text('i', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
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

class _PreferenceScrollFrame extends StatelessWidget {
  const _PreferenceScrollFrame({required this.controller, required this.child});

  final ScrollController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: controller,
      interactive: true,
      radius: const Radius.circular(999),
      thickness: 5,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: SingleChildScrollView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 20),
          child: child,
        ),
      ),
    );
  }
}

class _PreferenceLoading extends StatelessWidget {
  const _PreferenceLoading({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = SettingsPageColors.of(context);
    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Text(
          message,
          style: TextStyle(color: colors.textMuted, fontSize: 14),
        ),
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
            constraints: const BoxConstraints(minHeight: 52),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            color: colors.preferenceHeader,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 620;
                return Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: compact ? 14 : 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: compact ? 7 : 9,
                              vertical: compact ? 2 : 3,
                            ),
                            decoration: BoxDecoration(
                              color: colors.accentHover,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              counter,
                              style: TextStyle(
                                color: colors.accent,
                                fontSize: compact ? 11 : 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    action,
                  ],
                );
              },
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
  const _PreferenceSwitch({
    required this.checked,
    required this.onChanged,
    this.showLabel = true,
  });

  final bool checked;
  final ValueChanged<bool> onChanged;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final colors = SettingsPageColors.of(context);
    final label =
        checked
            ? i18n.t('preferences.enabled')
            : i18n.t('preferences.disabled');

    return Semantics(
      button: true,
      toggled: checked,
      label: label,
      child: TextButton(
        style: TextButton.styleFrom(
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          minimumSize: Size(showLabel ? 132 : 44, 32),
          fixedSize: Size(showLabel ? 132 : 44, 32),
          padding: EdgeInsets.zero,
          foregroundColor: colors.textStrong,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ).copyWith(
          overlayColor: WidgetStatePropertyAll(colors.accentHover),
          backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
        onPressed: () {
          onChanged(!checked);
        },
        child: Row(
          mainAxisAlignment:
              showLabel ? MainAxisAlignment.start : MainAxisAlignment.center,
          children: [
            _PreferenceSwitchTrack(checked: checked),
            if (showLabel) ...[
              const SizedBox(width: 10),
              SizedBox(
                width: 58,
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PreferenceSwitchTrack extends StatelessWidget {
  const _PreferenceSwitchTrack({required this.checked});

  final bool checked;

  @override
  Widget build(BuildContext context) {
    final colors = SettingsPageColors.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 44,
      height: 20,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: checked ? colors.accent : colors.inputBorder,
        borderRadius: BorderRadius.circular(999),
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        alignment: checked ? Alignment.centerRight : Alignment.centerLeft,
        child: const DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: SizedBox.square(dimension: 14),
        ),
      ),
    );
  }
}
