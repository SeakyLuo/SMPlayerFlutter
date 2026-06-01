part of 'search_page.dart';

class _SearchFilterTabs extends StatelessWidget {
  const _SearchFilterTabs({
    required this.i18n,
    required this.activeFilter,
    required this.results,
    required this.onChanged,
  });

  final SmPlayerI18n i18n;
  final SearchFilterKey activeFilter;
  final SearchResults results;
  final ValueChanged<SearchFilterKey> onChanged;

  @override
  Widget build(BuildContext context) {
    final tabs = <({SearchFilterKey key, String label, int count, int order})>[
      (
        key: SearchFilterKey.all,
        label: i18n.t('common.all'),
        count:
            results.artists.length +
            results.albums.length +
            results.songs.length +
            results.playlists.length +
            results.folders.length,
        order: 0,
      ),
      (
        key: SearchFilterKey.artists,
        label: i18n.t('common.artists'),
        count: results.artists.length,
        order: 1,
      ),
      (
        key: SearchFilterKey.albums,
        label: i18n.t('common.albums'),
        count: results.albums.length,
        order: 2,
      ),
      (
        key: SearchFilterKey.songs,
        label: i18n.t('common.songs'),
        count: results.songs.length,
        order: 3,
      ),
      (
        key: SearchFilterKey.playlists,
        label: i18n.t('common.playlists'),
        count: results.playlists.length,
        order: 4,
      ),
      (
        key: SearchFilterKey.folders,
        label: i18n.t('common.folders'),
        count: results.folders.length,
        order: 5,
      ),
    ];
    final orderedTabs = [
      tabs.first,
      ...tabs.skip(1).toList()..sort((left, right) {
        final leftEmpty = left.count == 0;
        final rightEmpty = right.count == 0;
        if (leftEmpty != rightEmpty) {
          return leftEmpty ? 1 : -1;
        }
        return left.order.compareTo(right.order);
      }),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 38),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(2, 4, 2, 8),
          child: Row(
            children: [
              for (final tab in orderedTabs) ...[
                _SearchFilterTab(
                  label: tab.label,
                  count: tab.count,
                  selected: tab.key == activeFilter,
                  enabled: tab.key == SearchFilterKey.all || tab.count > 0,
                  onPressed: () {
                    onChanged(tab.key);
                  },
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchFilterTab extends StatelessWidget {
  const _SearchFilterTab({
    required this.label,
    required this.count,
    required this.selected,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final int count;
  final bool selected;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = SearchPageThemeColors.of(context);
    final foreground =
        selected
            ? Colors.white
            : enabled
            ? colors.textStrong
            : colors.textStrong.withValues(alpha: 0.46);

    return Opacity(
      opacity: enabled ? 1 : 0.46,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: enabled ? onPressed : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          constraints: const BoxConstraints(minHeight: 30),
          padding: const EdgeInsets.symmetric(horizontal: 13),
          decoration: BoxDecoration(
            gradient:
                selected
                    ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xff2584dd), _SearchColors.accent],
                    )
                    : null,
            color: selected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? Colors.transparent : colors.controlBorder,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(width: 7),
              Text(
                '$count',
                style: TextStyle(
                  color: foreground,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
