part of 'recent_page.dart';

class _RecentNowPlayingGrid extends StatelessWidget {
  const _RecentNowPlayingGrid({
    required this.entries,
    required this.multiSelect,
    required this.selectedKeys,
    required this.onToggleSelection,
    required this.onPlay,
    required this.onTimelineLabelChange,
  });

  final List<RecentNowPlayingView> entries;
  final bool multiSelect;
  final Set<String> selectedKeys;
  final ValueChanged<String> onToggleSelection;
  final ValueChanged<RecentNowPlayingView> onPlay;
  final ValueChanged<String> onTimelineLabelChange;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    return _RecentCollectionGrid<RecentNowPlayingView>(
      items: entries,
      playedAt: (entry) => entry.createdAt,
      onTimelineLabelChange: onTimelineLabelChange,
      itemBuilder: (context, entry) {
        final key = 'nowPlaying:${entry.id}';
        final playlist = LibraryPlaylist(
          id: entry.playlistId,
          name: recentNowPlayingTitle(i18n, entry),
          priority: 0,
          songCount: entry.songs.length,
          songIds: entry.songIds,
          sortCriterion: PlaylistSortCriterion.title,
          isBuiltIn: true,
        );
        return GridViewHolder(
          playlist: playlist,
          songs: entry.songs,
          subtitle: formatRecentDateTime(entry.createdAt),
          playTooltip: i18n.t('context.play'),
          selected: selectedKeys.contains(key),
          selectionMode: multiSelect,
          showDragHandle: false,
          onOpen: () {
            if (multiSelect) {
              onToggleSelection(key);
            } else {
              context.go('/recent/now-playing/${entry.id}');
            }
          },
          onPlay: () => onPlay(entry),
        );
      },
    );
  }
}

String recentNowPlayingTitle(SmPlayerI18n i18n, RecentNowPlayingView entry) {
  return entry.songs.length == 1
      ? entry.songs.first.title
      : i18n.t('recent.nowPlayingQueueTitle', {
        'title': entry.songs.first.title,
        'count': entry.songs.length,
      });
}
