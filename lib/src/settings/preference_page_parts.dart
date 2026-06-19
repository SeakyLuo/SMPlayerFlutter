part of 'settings_page.dart';

class _PreferenceInfo extends StatelessWidget {
  const _PreferenceInfo();

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final colors = SettingsPageColors.of(context);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colors.cardSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: colors.inputBorder),
              ),
              child: Center(
                child: Text(
                  'i',
                  style: TextStyle(
                    color: colors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              i18n.t('preferences.info'),
              style: TextStyle(
                color: colors.textMuted,
                fontSize: 13,
                height: 1.35,
              ),
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
    required this.action,
    required this.child,
    this.counter,
  });

  final String title;
  final String? counter;
  final Widget action;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = SettingsPageColors.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: colors.cardShadow,
            offset: const Offset(0, 10),
            blurRadius: 30,
            spreadRadius: -8,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.preferenceCardSurface,
            border: Border.all(color: colors.preferenceCardBorder, width: 1.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Container(
                constraints: const BoxConstraints(minHeight: 52),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: colors.preferenceHeader,
                  border: Border(
                    bottom: BorderSide(
                      color: colors.preferenceCardBorder,
                      width: 1.5,
                    ),
                  ),
                ),
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
                              if (counter != null) ...[
                                const SizedBox(width: 10),
                                Text(
                                  counter!,
                                  style: TextStyle(
                                    color: colors.textMuted,
                                    fontSize: compact ? 12 : 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
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
        ),
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

    return ColoredBox(
      color: colors.preferenceBodySurface,
      child: SizedBox(
        width: double.infinity,
        height: 72,
        child: Center(
          child: Text(
            i18n.t('preferences.noItems'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.textMuted,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
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
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
        onPressed: () {
          onChanged(!checked);
        },
        child: Row(
          mainAxisAlignment:
              showLabel ? MainAxisAlignment.start : MainAxisAlignment.center,
          children: [
            SmPlayerSwitch(value: checked, onChanged: onChanged),
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
