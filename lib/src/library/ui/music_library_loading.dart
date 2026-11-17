part of 'music_library_page.dart';

class _MusicLibraryLoadingState extends StatelessWidget {
  const _MusicLibraryLoadingState({
    required this.i18n,
    required this.columnWidths,
    required this.sortCriterion,
    required this.sortDirection,
  });
  final SmPlayerI18n i18n;
  final Map<_LibraryColumn, double> columnWidths;
  final MusicLibrarySortCriterion sortCriterion;
  final MusicLibrarySortDirection sortDirection;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact =
          constraints.maxWidth < 720 &&
          WorkspaceNavigationAppBarScope.of(context);
      final colors = _LibraryPalette.of(context);
      return IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.panel,
            borderRadius: BorderRadius.circular(compact ? 10 : 14),
            border: Border.all(color: colors.panelBorder),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(compact ? 10 : 14),
            child: Padding(
              padding: compact ? EdgeInsets.zero : const EdgeInsets.all(10),
              child: Row(
                children: [
                  if (!compact)
                    _QuickJumpRail(
                      activeKey: '',
                      keys: _quickJumpKeys,
                      enabledKeys: const {},
                      targetName: i18n.t('common.songs'),
                      basisName: i18n.t('musicLibrary.titleHeader'),
                      i18n: i18n,
                      onJump: (_) {},
                    ),
                  Expanded(
                    child:
                        compact
                            ? Column(
                              children: [
                                _CompactSortBar(
                                  sortCriterion: sortCriterion,
                                  sortDirection: sortDirection,
                                  i18n: i18n,
                                  onSort: (_) {},
                                ),
                                const Expanded(
                                  child: SmPlayerLoadingState(compact: true),
                                ),
                              ],
                            )
                            : SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SizedBox(
                                width: _tableWidth(columnWidths),
                                child: Column(
                                  children: [
                                    _TableHeader(
                                      sortCriterion: sortCriterion,
                                      sortDirection: sortDirection,
                                      i18n: i18n,
                                      columnWidths: columnWidths,
                                      onSort: (_) {},
                                      onResizeColumn: (_, _) {},
                                    ),
                                    Expanded(
                                      child: ListView.builder(
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        itemExtent: _wideVirtualRowHeight,
                                        itemBuilder:
                                            (_, _) => _SongWindowPlaceholder(
                                              columnWidths: columnWidths,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
