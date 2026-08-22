part of 'recent_page.dart';

class _RecentBrowsesPage extends StatelessWidget {
  const _RecentBrowsesPage({
    required this.entries,
    required this.allEntryIds,
    required this.i18n,
    required this.multiSelect,
    required this.selectedEntryIds,
    required this.onOpen,
    required this.onToggleMultiSelect,
    required this.onClearSelection,
    required this.onToggleSelection,
    required this.onRemove,
    required this.onClear,
  });

  final List<RecentBrowseView> entries;
  final List<int> allEntryIds;
  final SmPlayerI18n i18n;
  final bool multiSelect;
  final Set<int> selectedEntryIds;
  final ValueChanged<RecentBrowseView> onOpen;
  final VoidCallback onToggleMultiSelect;
  final VoidCallback onClearSelection;
  final ValueChanged<int> onToggleSelection;
  final ValueChanged<int> onRemove;
  final ValueChanged<List<int>> onClear;

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 4,
      children: [
        CommandBar(
          overflowLabel: i18n.t('player.more'),
          content: const _RecentCommandBarTimelineLabel(label: ''),
          children: [
            CommandBarButton(
              icon: FluentIcons.multiselect_ltr_20_regular,
              label: i18n.t('albums.multiSelect'),
              active: multiSelect,
              activeMatchesHover: true,
              tooltip:
                  multiSelect ? i18n.t('common.exitMultiSelectTooltip') : null,
              disabled: entries.isEmpty,
              onPressed: onToggleMultiSelect,
            ),
            CommandBarButton(
              icon: FluentIcons.broom_20_regular,
              label: i18n.t('recent.clearHistory'),
              disabled: allEntryIds.isEmpty,
              onPressed: () {
                unawaited(_confirmClearHistory(context));
              },
            ),
          ],
        ),
        Expanded(
          child: _RecentBrowseList(
            entries: entries,
            i18n: i18n,
            multiSelect: multiSelect,
            selectedEntryIds: selectedEntryIds,
            onOpen: onOpen,
            onToggleSelection: onToggleSelection,
            onRemove: onRemove,
          ),
        ),
      ],
    );
  }

  Future<void> _confirmClearHistory(BuildContext context) async {
    final confirmed = await showPopupConfirmDialog(
      context: context,
      title: i18n.t('common.confirm'),
      message: i18n.t('recent.clearBrowsesConfirm'),
      confirmLabel: i18n.t('common.confirm'),
      destructive: false,
    );
    if (!confirmed) {
      return;
    }
    onClear(allEntryIds);
    onClearSelection();
  }
}
