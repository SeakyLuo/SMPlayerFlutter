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
    final i18n = context.smPlayerI18n;
    final visibleItems = expanded ? items : items.take(5).toList();
    final hasInvalid = items.any((item) => !item.isValid);

    return _PreferenceSectionFrame(
      title: title,
      counter: '${items.length}/$limit',
      action: Builder(
        builder: (context) {
          final mobile =
              MediaQuery.sizeOf(context).width <= popupDialogMobileBreakpoint;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PreferenceSwitch(
                checked: enabled,
                showLabel: !mobile,
                onChanged: (checked) {
                  onToggleEnabled(section, checked);
                },
              ),
              if (items.length > 5) ...[
                SizedBox(width: mobile ? 4 : 8),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    minimumSize: const Size(0, 28),
                    padding: EdgeInsets.symmetric(horizontal: mobile ? 4 : 8),
                    foregroundColor: SettingsPageColors.of(context).accent,
                  ),
                  onPressed: () {
                    onToggleExpanded(section);
                  },
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
              ],
              if (hasInvalid) ...[
                SizedBox(width: mobile ? 4 : 8),
                TextButton(
                  style: TextButton.styleFrom(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    minimumSize: const Size(0, 28),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    foregroundColor: SettingsPageColors.of(context).textStrong,
                    side: BorderSide(
                      color: SettingsPageColors.of(context).cardBorder,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  onPressed: () {
                    onClearInvalid(section);
                  },
                  child: Text(
                    i18n.t('preferences.clearInvalid'),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          );
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
    final i18n = context.smPlayerI18n;
    final colors = SettingsPageColors.of(context);

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

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 620;
        final showRemove =
            widget.item.canRemove && (_hovered || _removeFocused);
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
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: colors.cardBorder)),
              color:
                  _hovered
                      ? colors.accentHover
                      : widget.odd
                      ? colors.cardSurface
                      : colors.dialogSurface,
            ),
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
                          ? AnimatedOpacity(
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
                                icon: const Icon(
                                  FluentIcons.dismiss_20_regular,
                                ),
                                iconSize: 18,
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
                          )
                          : const SizedBox.shrink(),
                ),
                SizedBox(width: compact ? 8 : 14),
                _PreferenceSwitch(
                  checked: item.isEnabled,
                  showLabel: !compact,
                  onChanged: (checked) {
                    widget.onUpdateItem(
                      item,
                      item.copyWith(isEnabled: checked),
                    );
                  },
                ),
                SizedBox(width: compact ? 8 : 14),
                SizedBox(
                  width: compact ? 124 : 150,
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
      },
    );
  }
}

class PreferenceLevelSelect extends StatefulWidget {
  const PreferenceLevelSelect({
    super.key,
    required this.value,
    required this.onChange,
  });

  final PreferenceLevel value;
  final ValueChanged<PreferenceLevel> onChange;

  @override
  State<PreferenceLevelSelect> createState() => _PreferenceLevelSelectState();
}

class _PreferenceLevelSelectState extends State<PreferenceLevelSelect> {
  static const _preferenceLevels = [
    PreferenceLevel.veryHigh,
    PreferenceLevel.higher,
    PreferenceLevel.high,
    PreferenceLevel.normal,
    PreferenceLevel.dislike,
    PreferenceLevel.doNotAppear,
  ];

  final _link = LayerLink();
  OverlayEntry? _overlayEntry;
  var _open = false;
  var _openUpward = false;

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final colors = SettingsPageColors.of(context);

    return CompositedTransformTarget(
      link: _link,
      child: SizedBox(
        height: 36,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            alignment: Alignment.centerLeft,
            backgroundColor:
                _open ? colors.selectOpenSurface : colors.inputSurface,
            foregroundColor: _open ? colors.accentStrong : colors.textStrong,
            side: BorderSide(
              color: _open ? colors.selectOpenBorder : colors.inputBorder,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(9),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10),
          ),
          onPressed: _toggleOpen,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _preferenceLevelLabel(i18n, widget.value),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(
                _open
                    ? FluentIcons.chevron_up_20_regular
                    : FluentIcons.chevron_down_20_regular,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleOpen() {
    if (_open) {
      _close();
      return;
    }
    setState(() {
      _open = true;
    });
    _showOverlay();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _open) {
        _updateDropdownGeometry();
      }
    });
  }

  void _showOverlay() {
    _removeOverlay();
    _overlayEntry = OverlayEntry(builder: _buildOverlay);
    Overlay.of(context).insert(_overlayEntry!);
  }

  Widget _buildOverlay(BuildContext context) {
    return _settingsNoTextScaling(
      context,
      Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _close,
              child: const SizedBox.expand(),
            ),
          ),
          CompositedTransformFollower(
            link: _link,
            targetAnchor:
                _openUpward ? Alignment.topRight : Alignment.bottomRight,
            followerAnchor:
                _openUpward ? Alignment.bottomRight : Alignment.topRight,
            offset: Offset(0, _openUpward ? -6 : 6),
            child: SizedBox(
              width: 170,
              child: _PreferenceLevelMenu(
                value: widget.value,
                levels: _preferenceLevels,
                onSelected: (level) {
                  widget.onChange(level);
                  _close();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _close() {
    if (!_open && _overlayEntry == null) {
      return;
    }
    setState(() {
      _open = false;
    });
    _removeOverlay();
  }

  void _updateDropdownGeometry() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) {
      return;
    }
    final position = box.localToGlobal(Offset.zero);
    final viewportHeight = MediaQuery.sizeOf(context).height;
    final bottomBoundary = math.max(0.0, viewportHeight - 128.0);
    final desiredHeight = (_preferenceLevels.length * 38.0) + 16.0;
    final spaceBelow = math.max(
      0.0,
      bottomBoundary - position.dy - box.size.height - 8.0,
    );
    final spaceAbove = math.max(0.0, position.dy - 8.0);
    final nextOpenUpward =
        spaceBelow < desiredHeight && spaceAbove > spaceBelow;
    if (_openUpward == nextOpenUpward) {
      return;
    }
    setState(() {
      _openUpward = nextOpenUpward;
    });
    _overlayEntry?.markNeedsBuild();
  }
}

class _PreferenceLevelMenu extends StatelessWidget {
  const _PreferenceLevelMenu({
    required this.value,
    required this.levels,
    required this.onSelected,
  });

  final PreferenceLevel value;
  final List<PreferenceLevel> levels;
  final ValueChanged<PreferenceLevel> onSelected;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final colors = SettingsPageColors.of(context);
    return Material(
      color: Colors.transparent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.dropdownSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colors.inputBorder),
          boxShadow: [
            BoxShadow(
              color: colors.dropdownShadow,
              offset: const Offset(0, 18),
              blurRadius: 44,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children:
                levels.map((level) {
                  final selected = level == value;
                  return TextButton(
                    style: TextButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      foregroundColor:
                          selected ? colors.accentStrong : colors.textStrong,
                      backgroundColor:
                          selected ? colors.accentHover : Colors.transparent,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      minimumSize: const Size.fromHeight(34),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onPressed: () {
                      onSelected(level);
                    },
                    child: Text(
                      _preferenceLevelLabel(i18n, level),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
          ),
        ),
      ),
    );
  }
}
