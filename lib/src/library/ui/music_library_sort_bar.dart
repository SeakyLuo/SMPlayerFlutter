part of 'music_library_page.dart';

class _CompactSortBar extends StatelessWidget {
  const _CompactSortBar({
    required this.sortCriterion,
    required this.sortDirection,
    required this.i18n,
    required this.onSort,
  });

  final MusicLibrarySortCriterion sortCriterion;
  final MusicLibrarySortDirection sortDirection;
  final SmPlayerI18n i18n;
  final ValueChanged<MusicLibrarySortCriterion> onSort;

  @override
  Widget build(BuildContext context) {
    final colors = _LibraryPalette.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: colors.panel,
        border: Border(bottom: BorderSide(color: colors.rowBorder)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          spacing: 6,
          children: [
            _CompactSortButton(
              label: i18n.t('musicLibrary.titleHeader'),
              criterion: MusicLibrarySortCriterion.title,
              activeCriterion: sortCriterion,
              direction: sortDirection,
              onSort: onSort,
            ),
            _CompactSortButton(
              label: i18n.t('common.artist'),
              criterion: MusicLibrarySortCriterion.artist,
              activeCriterion: sortCriterion,
              direction: sortDirection,
              onSort: onSort,
            ),
            _CompactSortButton(
              label: i18n.t('common.album'),
              criterion: MusicLibrarySortCriterion.album,
              activeCriterion: sortCriterion,
              direction: sortDirection,
              onSort: onSort,
            ),
            _CompactSortButton(
              label: i18n.t('common.duration'),
              criterion: MusicLibrarySortCriterion.duration,
              activeCriterion: sortCriterion,
              direction: sortDirection,
              onSort: onSort,
            ),
            _CompactSortButton(
              label: i18n.t('common.playCount'),
              criterion: MusicLibrarySortCriterion.playCount,
              activeCriterion: sortCriterion,
              direction: sortDirection,
              onSort: onSort,
            ),
            _CompactSortButton(
              label: i18n.t('common.dateAdded'),
              criterion: MusicLibrarySortCriterion.dateAdded,
              activeCriterion: sortCriterion,
              direction: sortDirection,
              onSort: onSort,
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactSortButton extends StatelessWidget {
  const _CompactSortButton({
    required this.label,
    required this.criterion,
    required this.activeCriterion,
    required this.direction,
    required this.onSort,
  });

  final String label;
  final MusicLibrarySortCriterion criterion;
  final MusicLibrarySortCriterion activeCriterion;
  final MusicLibrarySortDirection direction;
  final ValueChanged<MusicLibrarySortCriterion> onSort;

  @override
  Widget build(BuildContext context) {
    final colors = _LibraryPalette.of(context);
    final active = criterion == activeCriterion;
    return TextButton.icon(
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 36),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        foregroundColor: active ? colors.accentStrong : colors.textMuted,
        backgroundColor: active ? colors.accentSoft : Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      onPressed: () {
        onSort(criterion);
      },
      icon:
          active
              ? Icon(
                direction == MusicLibrarySortDirection.ascending
                    ? FluentIcons.chevron_up_16_regular
                    : FluentIcons.chevron_down_16_regular,
                size: 13,
              )
              : const SizedBox.shrink(),
      label: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}
