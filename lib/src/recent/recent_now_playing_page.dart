part of 'recent_page.dart';

class _RecentNowPlayingGrid extends StatelessWidget {
  const _RecentNowPlayingGrid({
    required this.entries,
    required this.onPlay,
    required this.onTimelineLabelChange,
  });

  final List<RecentNowPlayingView> entries;
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
        final playlist = LibraryPlaylist(
          id: entry.id,
          name:
              entry.songs.length == 1
                  ? entry.songs.first.title
                  : i18n.t('recent.nowPlayingQueueTitle', {
                    'title': entry.songs.first.title,
                    'count': entry.songs.length,
                  }),
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
          selected: false,
          selectionMode: false,
          showDragHandle: false,
          onOpen: () => onPlay(entry),
          onPlay: () => onPlay(entry),
        );
      },
    );
  }
}
