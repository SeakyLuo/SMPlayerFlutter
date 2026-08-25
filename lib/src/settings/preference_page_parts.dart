part of 'settings_page.dart';

class _PreferenceInfo extends StatelessWidget {
  const _PreferenceInfo();

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final colors = SettingsPageColors.of(context);
    final mobile =
        MediaQuery.sizeOf(context).width <= popupDialogMobileBreakpoint;

    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: mobile ? 28 : 34),
      margin: EdgeInsets.only(bottom: mobile ? 8 : 10),
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: mobile ? 16 : 18,
            height: mobile ? 16 : 18,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: colors.inputBorder),
              ),
              child: Center(
                child: Text(
                  'i',
                  style: TextStyle(
                    color: colors.textStrong,
                    fontSize: mobile ? 12 : 13,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: mobile ? 8 : 10),
          Expanded(
            child: Text(
              i18n.t('preferences.info'),
              style: TextStyle(
                color: colors.textMuted,
                fontSize: mobile ? 12 : 13,
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
    final mobile =
        MediaQuery.sizeOf(context).width <= popupDialogMobileBreakpoint;
    return Scrollbar(
      controller: controller,
      interactive: true,
      radius: const Radius.circular(999),
      thickness: 5,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: SingleChildScrollView(
          controller: controller,
          padding:
              mobile
                  ? const EdgeInsets.fromLTRB(10, 4, 10, 14)
                  : const EdgeInsets.fromLTRB(18, 6, 18, 20),
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
    final mobile =
        MediaQuery.sizeOf(context).width <= popupDialogMobileBreakpoint;
    final radius = mobile ? 10.0 : 12.0;
    return Container(
      margin: EdgeInsets.only(bottom: mobile ? 10 : 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: colors.cardShadow,
            offset: const Offset(0, 26),
            blurRadius: 70,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.preferenceCardSurface,
            border: Border.all(color: colors.preferenceCardBorder),
            borderRadius: BorderRadius.circular(radius),
          ),
          child: Column(
            children: [
              Container(
                constraints: BoxConstraints(minHeight: mobile ? 44 : 52),
                padding: EdgeInsets.symmetric(horizontal: mobile ? 10 : 14),
                decoration: BoxDecoration(
                  color: colors.preferenceHeader,
                  border: Border(
                    bottom: BorderSide(color: colors.preferenceCardBorder),
                  ),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = mobile;
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
                        SizedBox(
                          width:
                              MediaQuery.sizeOf(context).width <=
                                      popupDialogMobileBreakpoint
                                  ? 8
                                  : 14,
                        ),
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
    final mobile =
        MediaQuery.sizeOf(context).width <= popupDialogMobileBreakpoint;

    return ColoredBox(
      color: colors.preferenceBodySurface,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: mobile ? 40 : 44),
        child: Padding(
          padding: EdgeInsets.all(mobile ? 10 : 14),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              i18n.t('preferences.noItems'),
              style: TextStyle(
                color: colors.textMuted,
                fontSize: mobile ? 13 : 14,
              ),
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
            _PreferenceSwitchTrack(checked: checked, compact: !showLabel),
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
  const _PreferenceSwitchTrack({required this.checked, required this.compact});

  final bool checked;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = SettingsPageColors.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeInOutCubic,
      width: compact ? 42 : 44,
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      decoration: BoxDecoration(
        color: checked ? colors.accent : colors.buttonSurface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeInOutCubic,
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
