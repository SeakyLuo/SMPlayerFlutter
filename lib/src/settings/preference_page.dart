part of 'settings_page.dart';

class PreferenceSettingsPage extends StatefulWidget {
  const PreferenceSettingsPage({
    super.key,
    required this.onClose,
    this.libraryRepository = const LibraryRepository(),
    this.initialSnapshot,
  });

  final VoidCallback onClose;
  final LibraryRepository libraryRepository;
  final PreferenceSettingsSnapshot? initialSnapshot;

  @override
  State<PreferenceSettingsPage> createState() => _PreferenceSettingsPageState();
}

class _PreferenceSettingsPageState extends State<PreferenceSettingsPage> {
  static const _preferenceSectionLimits = {
    PreferenceSectionKey.songs: 100,
    PreferenceSectionKey.artists: 50,
    PreferenceSectionKey.albums: 50,
    PreferenceSectionKey.playlists: 30,
    PreferenceSectionKey.folders: 30,
  };

  late PreferenceSettingsSnapshot _snapshot;
  final _preferenceScrollController = ScrollController();
  final _expandedSections = <PreferenceSectionKey>{};
  var _loading = false;
  var _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _snapshot = widget.initialSnapshot ?? PreferenceSettingsSnapshot.defaults();
    if (widget.initialSnapshot == null) {
      _loading = true;
      unawaited(_loadPreferenceSnapshot());
    }
  }

  @override
  void dispose() {
    _preferenceScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;

    return PopupDialog(
      className: 'preference-modal ContentDialog PreferenceDialog',
      navClassName: 'music-dialog-pivot PreferenceDialogPivot',
      overlayClassName: 'music-dialog-overlay PreferenceDialogOverlay',
      navLabel: i18n.t('settings.preferenceSettings'),
      ariaLabel: i18n.t('settings.preferenceSettings'),
      onClose: widget.onClose,
      closeOnBackdrop: true,
      width: 1080,
      height: 820,
      verticalInset: 96,
      navChildren: [PopupDialogTitle(i18n.t('settings.preferenceSettings'))],
      child: _PreferenceScrollFrame(
        controller: _preferenceScrollController,
        child:
            _loading
                ? _PreferenceLoading(message: i18n.t('preferences.loading'))
                : _loadFailed
                ? _PreferenceLoading(message: i18n.t('preferences.loadFailed'))
                : _buildPreferencePage(i18n),
      ),
    );
  }

  Widget _buildPreferencePage(SmPlayerI18n i18n) {
    return Column(
      children: [
        const _PreferenceInfo(),
        PreferenceSection(
          title: i18n.t('preferences.songs'),
          section: PreferenceSectionKey.songs,
          limit: _preferenceSectionLimits[PreferenceSectionKey.songs]!,
          enabled: _snapshot.enabled[PreferenceSectionKey.songs]!,
          items: _snapshot.songs,
          expanded: _expandedSections.contains(PreferenceSectionKey.songs),
          onToggleEnabled: _toggleEnabled,
          onToggleExpanded: _toggleExpanded,
          onUpdateItem: _updateItem,
          onRemoveItem: _removeItem,
          onClearInvalid: _clearInvalid,
        ),
        PreferenceSection(
          title: i18n.t('preferences.artists'),
          section: PreferenceSectionKey.artists,
          limit: _preferenceSectionLimits[PreferenceSectionKey.artists]!,
          enabled: _snapshot.enabled[PreferenceSectionKey.artists]!,
          items: _snapshot.artists,
          expanded: _expandedSections.contains(PreferenceSectionKey.artists),
          onToggleEnabled: _toggleEnabled,
          onToggleExpanded: _toggleExpanded,
          onUpdateItem: _updateItem,
          onRemoveItem: _removeItem,
          onClearInvalid: _clearInvalid,
        ),
        PreferenceSection(
          title: i18n.t('preferences.albums'),
          section: PreferenceSectionKey.albums,
          limit: _preferenceSectionLimits[PreferenceSectionKey.albums]!,
          enabled: _snapshot.enabled[PreferenceSectionKey.albums]!,
          items: _snapshot.albums,
          expanded: _expandedSections.contains(PreferenceSectionKey.albums),
          onToggleEnabled: _toggleEnabled,
          onToggleExpanded: _toggleExpanded,
          onUpdateItem: _updateItem,
          onRemoveItem: _removeItem,
          onClearInvalid: _clearInvalid,
        ),
        PreferenceSection(
          title: i18n.t('preferences.playlists'),
          section: PreferenceSectionKey.playlists,
          limit: _preferenceSectionLimits[PreferenceSectionKey.playlists]!,
          enabled: _snapshot.enabled[PreferenceSectionKey.playlists]!,
          items: _snapshot.playlists,
          expanded: _expandedSections.contains(PreferenceSectionKey.playlists),
          onToggleEnabled: _toggleEnabled,
          onToggleExpanded: _toggleExpanded,
          onUpdateItem: _updateItem,
          onRemoveItem: _removeItem,
          onClearInvalid: _clearInvalid,
        ),
        PreferenceSection(
          title: i18n.t('preferences.folders'),
          section: PreferenceSectionKey.folders,
          limit: _preferenceSectionLimits[PreferenceSectionKey.folders]!,
          enabled: _snapshot.enabled[PreferenceSectionKey.folders]!,
          items: _snapshot.folders,
          expanded: _expandedSections.contains(PreferenceSectionKey.folders),
          onToggleEnabled: _toggleEnabled,
          onToggleExpanded: _toggleExpanded,
          onUpdateItem: _updateItem,
          onRemoveItem: _removeItem,
          onClearInvalid: _clearInvalid,
        ),
        _PreferenceOthersSection(
          items: _snapshot.others,
          onUpdateItem: _updateItem,
          onRemoveItem: _removeItem,
        ),
      ],
    );
  }

  Future<void> _loadPreferenceSnapshot() async {
    try {
      final snapshot = await widget.libraryRepository.getPreferenceSettings();
      if (!mounted) {
        return;
      }
      setState(() {
        _snapshot = snapshot;
        _loading = false;
        _loadFailed = false;
      });
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  void _toggleEnabled(PreferenceSectionKey section, bool enabled) {
    setState(() {
      _snapshot = _snapshot.copyWith(
        enabled: {..._snapshot.enabled, section: enabled},
      );
    });
    unawaited(
      widget.libraryRepository.updatePreferenceSettings({section: enabled}),
    );
  }

  void _toggleExpanded(PreferenceSectionKey section) {
    setState(() {
      if (_expandedSections.contains(section)) {
        _expandedSections.remove(section);
      } else {
        _expandedSections.add(section);
      }
    });
  }

  void _updateItem(PreferenceItemSnapshot item, PreferenceItemSnapshot update) {
    setState(() {
      _snapshot = _snapshotWithUpdatedItems(
        _snapshot,
        _sectionForPreferenceType(item.type),
        (items) =>
            items
                .map(
                  (current) =>
                      _samePreferenceItem(current, item) ? update : current,
                )
                .toList(),
      );
    });
    unawaited(
      widget.libraryRepository.updatePreferenceItem(
        item.id,
        isEnabled: update.isEnabled,
        level: update.level,
      ),
    );
  }

  void _removeItem(PreferenceItemSnapshot item) {
    setState(() {
      _snapshot = _snapshotWithUpdatedItems(
        _snapshot,
        _sectionForPreferenceType(item.type),
        (items) =>
            items
                .where((current) => !_samePreferenceItem(current, item))
                .toList(),
      );
    });
    unawaited(widget.libraryRepository.removePreferenceItemById(item.id));
  }

  void _clearInvalid(PreferenceSectionKey section) {
    setState(() {
      _snapshot = _snapshotWithUpdatedItems(
        _snapshot,
        section,
        (items) => items.where((item) => item.isValid).toList(),
      );
    });
    unawaited(
      widget.libraryRepository.clearInvalidPreferenceItems(
        _preferenceEntityTypeForSection(section),
      ),
    );
  }
}

class PreferenceSection extends StatelessWidget {
  const PreferenceSection({
    super.key,
    required this.title,
    required this.section,
    required this.limit,
    required this.enabled,
    required this.items,
    required this.expanded,
    required this.onToggleEnabled,
    required this.onToggleExpanded,
    required this.onUpdateItem,
    required this.onRemoveItem,
    required this.onClearInvalid,
  });

  final String title;
  final PreferenceSectionKey section;
  final int limit;
  final bool enabled;
  final List<PreferenceItemSnapshot> items;
  final bool expanded;
  final void Function(PreferenceSectionKey section, bool enabled)
  onToggleEnabled;
  final ValueChanged<PreferenceSectionKey> onToggleExpanded;
  final void Function(
    PreferenceItemSnapshot item,
    PreferenceItemSnapshot update,
  )
  onUpdateItem;
  final ValueChanged<PreferenceItemSnapshot> onRemoveItem;
  final ValueChanged<PreferenceSectionKey> onClearInvalid;

  @override
  Widget build(BuildContext context) {
    final visibleItems = expanded ? items : items.take(5).toList();
    final hasInvalid = items.any((item) => !item.isValid);

    return _PreferenceSectionFrame(
      title: title,
      counter: '${items.length} / $limit',
      action: _PreferenceSectionHeaderActions(
        enabled: enabled,
        expanded: expanded,
        showExpand: items.length > 5,
        showClearInvalid: hasInvalid,
        onToggleEnabled: (checked) {
          onToggleEnabled(section, checked);
        },
        onToggleExpanded: () {
          onToggleExpanded(section);
        },
        onClearInvalid: () {
          onClearInvalid(section);
        },
      ),
      child:
          visibleItems.isEmpty
              ? const _PreferenceEmpty()
              : PreferenceItems(
                items: visibleItems,
                onUpdateItem: onUpdateItem,
                onRemoveItem: onRemoveItem,
              ),
    );
  }
}

class _PreferenceSectionHeaderActions extends StatelessWidget {
  const _PreferenceSectionHeaderActions({
    required this.enabled,
    required this.expanded,
    required this.showExpand,
    required this.showClearInvalid,
    required this.onToggleEnabled,
    required this.onToggleExpanded,
    required this.onClearInvalid,
  });

  final bool enabled;
  final bool expanded;
  final bool showExpand;
  final bool showClearInvalid;
  final ValueChanged<bool> onToggleEnabled;
  final VoidCallback onToggleExpanded;
  final VoidCallback onClearInvalid;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final colors = SettingsPageColors.of(context);
    final mobile =
        MediaQuery.sizeOf(context).width <= popupDialogMobileBreakpoint;
    final gap = mobile ? 8.0 : 14.0;

    return SizedBox(
      width: mobile ? 218 : 368,
      child: Row(
        children: [
          SizedBox(width: mobile ? 30 : 48),
          SizedBox(width: gap),
          SizedBox(
            width: mobile ? 44 : 142,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _PreferenceSwitch(
                checked: enabled,
                showLabel: !mobile,
                onChanged: onToggleEnabled,
              ),
            ),
          ),
          SizedBox(width: gap),
          SizedBox(
            width: mobile ? 128 : 150,
            child: Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4,
              runSpacing: 4,
              children: [
                if (showExpand)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      minimumSize: const Size(0, 28),
                      padding: EdgeInsets.symmetric(horizontal: mobile ? 2 : 6),
                      foregroundColor: colors.accent,
                    ),
                    onPressed: onToggleExpanded,
                    icon: Icon(
                      expanded
                          ? FluentIcons.chevron_up_16_regular
                          : FluentIcons.chevron_down_16_regular,
                      size: 14,
                    ),
                    label: Text(
                      expanded
                          ? i18n.t('preferences.collapse')
                          : i18n.t('preferences.expand'),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                if (showClearInvalid)
                  TextButton(
                    style: TextButton.styleFrom(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      minimumSize: const Size(0, 28),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      foregroundColor: colors.textStrong,
                      side: BorderSide(color: colors.cardBorder),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    onPressed: onClearInvalid,
                    child: Text(
                      i18n.t('preferences.clearInvalid'),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PreferenceItems extends StatelessWidget {
  const PreferenceItems({
    super.key,
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
    return Column(
      children: [
        for (final entry in items.indexed)
          _PreferenceItemRow(
            item: entry.$2,
            odd: entry.$1.isEven,
            onUpdateItem: onUpdateItem,
            onRemoveItem: onRemoveItem,
          ),
      ],
    );
  }
}

class _PreferenceItemRow extends StatefulWidget {
  const _PreferenceItemRow({
    required this.item,
    required this.odd,
    required this.onUpdateItem,
    required this.onRemoveItem,
  });

  final PreferenceItemSnapshot item;
  final bool odd;
  final void Function(
    PreferenceItemSnapshot item,
    PreferenceItemSnapshot update,
  )
  onUpdateItem;
  final ValueChanged<PreferenceItemSnapshot> onRemoveItem;

  @override
  State<_PreferenceItemRow> createState() => _PreferenceItemRowState();
}

class _PreferenceItemRowState extends State<_PreferenceItemRow> {
  var _hovered = false;
  var _removeFocused = false;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final colors = SettingsPageColors.of(context);
    final item = widget.item;

    final compact =
        MediaQuery.sizeOf(context).width <= popupDialogMobileBreakpoint;
    final showRemove = widget.item.canRemove && (_hovered || _removeFocused);
    final rowColor =
        _hovered
            ? colors.accentHover
            : widget.odd
            ? colors.preferenceBodySurface
            : colors.preferenceCardSurface;
    return MouseRegion(
      onEnter: (_) {
        setState(() {
          _hovered = true;
        });
      },
      onExit: (_) {
        setState(() {
          _hovered = false;
        });
      },
      child: Container(
        constraints: BoxConstraints(minHeight: compact ? 42 : 48),
        padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 14),
        decoration: BoxDecoration(color: rowColor),
        child: Row(
          children: [
            Expanded(
              child: Tooltip(
                message: item.tooltip,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _preferenceItemName(i18n, item),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textStrong,
                        fontSize: compact ? 13 : 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (!item.isValid)
                      Text(
                        i18n.t('preferences.invalid'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: SettingsPageColors.danger,
                          fontSize: compact ? 11 : 12,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(width: compact ? 8 : 14),
            SizedBox(
              width: compact ? 30 : 48,
              child:
                  item.canRemove
                      ? AnimatedSlide(
                        duration: const Duration(milliseconds: 140),
                        curve: Curves.easeOutCubic,
                        offset:
                            showRemove ? Offset.zero : const Offset(0.13, 0),
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 140),
                          opacity: showRemove ? 1 : 0,
                          child: Focus(
                            onFocusChange: (focused) {
                              setState(() {
                                _removeFocused = focused;
                              });
                            },
                            child: IconButton(
                              tooltip: i18n.t('playlists.removeSelected'),
                              icon: const Icon(FluentIcons.dismiss_20_regular),
                              iconSize: 14,
                              padding: EdgeInsets.zero,
                              constraints: BoxConstraints.tightFor(
                                width: compact ? 28 : 30,
                                height: compact ? 28 : 30,
                              ),
                              style: IconButton.styleFrom(
                                side: BorderSide(color: colors.cardBorder),
                                backgroundColor: colors.buttonSurface,
                                foregroundColor: colors.textMuted,
                              ),
                              onPressed: () {
                                widget.onRemoveItem(item);
                              },
                            ),
                          ),
                        ),
                      )
                      : const SizedBox.shrink(),
            ),
            SizedBox(width: compact ? 8 : 14),
            SizedBox(
              width: compact ? 44 : 142,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _PreferenceSwitch(
                  checked: item.isEnabled,
                  showLabel: !compact,
                  onChanged: (checked) {
                    widget.onUpdateItem(
                      item,
                      item.copyWith(isEnabled: checked),
                    );
                  },
                ),
              ),
            ),
            SizedBox(width: compact ? 8 : 14),
            SizedBox(
              width: compact ? 128 : 150,
              child: PreferenceLevelSelect(
                value: item.level,
                onChange: (level) {
                  widget.onUpdateItem(item, item.copyWith(level: level));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PreferenceLevelSelect extends StatelessWidget {
  const PreferenceLevelSelect({
    super.key,
    required this.value,
    required this.onChange,
  });

  final PreferenceLevel value;
  final ValueChanged<PreferenceLevel> onChange;

  static const _preferenceLevels = [
    PreferenceLevel.veryHigh,
    PreferenceLevel.higher,
    PreferenceLevel.high,
    PreferenceLevel.normal,
    PreferenceLevel.dislike,
    PreferenceLevel.doNotAppear,
  ];

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final mobile =
        MediaQuery.sizeOf(context).width <= popupDialogMobileBreakpoint;
    return _SettingsSelectControl<PreferenceLevel>(
      value: value,
      options:
          _preferenceLevels
              .map(
                (level) => SelectSettingOption<PreferenceLevel>(
                  value: level,
                  label: _preferenceLevelLabel(i18n, level),
                ),
              )
              .toList(),
      onChange: onChange,
      height: mobile ? 32 : 34,
      borderRadius: 9,
      horizontalPadding: 10,
      fontWeight: FontWeight.w600,
    );
  }
}
