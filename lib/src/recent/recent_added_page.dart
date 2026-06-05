part of 'recent_page.dart';

class _RecentAddedPage extends StatelessWidget {
  const _RecentAddedPage({
    required this.songs,
    required this.i18n,
    required this.timelineLabel,
    required this.customPlaylists,
    required this.selectedSongIds,
    required this.multiSelect,
    required this.mediaControlState,
    required this.onToggleMultiSelect,
    required this.onPlaySong,
    required this.onToggleSelection,
    required this.onOpenSongAddToMenu,
    required this.onOpenSongContextMenu,
    required this.onPlayNext,
    required this.onTimelineLabelChange,
  });

  final List<LibrarySong> songs;
  final SmPlayerI18n i18n;
  final String timelineLabel;
  final List<MultiSelectCommandBarPlaylist> customPlaylists;
  final Set<int> selectedSongIds;
  final bool multiSelect;
  final MediaControlState mediaControlState;
  final VoidCallback onToggleMultiSelect;
  final void Function(
    LibrarySong song,
    List<int> queueSongIds, [
    int? queueIndex,
  ])
  onPlaySong;
  final ValueChanged<int> onToggleSelection;
  final void Function(
    Offset position,
    String defaultName,
    List<int> songIds,
    List<MultiSelectCommandBarPlaylist> customPlaylists,
  )
  onOpenSongAddToMenu;
  final Future<void> Function(
    Offset position,
    LibrarySong song,
    List<int> queueSongIds,
    List<MultiSelectCommandBarPlaylist> customPlaylists,
  )
  onOpenSongContextMenu;
  final ValueChanged<int> onPlayNext;
  final ValueChanged<String> onTimelineLabelChange;

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 4,
      children: [
        CommandBar(
          overflowLabel: i18n.t('player.more'),
          content: _RecentCommandBarTimelineLabel(label: timelineLabel),
          children: [
            CommandBarButton(
              icon: FluentIcons.multiselect_ltr_20_regular,
              label: i18n.t('albums.multiSelect'),
              active: multiSelect,
              disabled: songs.isEmpty,
              onPressed: onToggleMultiSelect,
            ),
          ],
        ),
        Expanded(
          child: _RecentSongGrid(
            songs: songs,
            queueSongIds: songs.map((song) => song.id).toList(),
            selectedSongIds: selectedSongIds,
            multiSelect: multiSelect,
            mediaControlState: mediaControlState,
            getTimelineDate: (song) => song.dateAdded,
            getDetailLabel: (song) => formatRecentDateTime(song.dateAdded),
            onPlaySong: onPlaySong,
            onToggleSelection: onToggleSelection,
            onOpenAddToMenu: (position, song) {
              onOpenSongAddToMenu(position, song.title, [
                song.id,
              ], customPlaylists);
            },
            onOpenContextMenu: (position, song, queueSongIds) {
              onOpenSongContextMenu(
                position,
                song,
                queueSongIds,
                customPlaylists,
              );
            },
            onPlayNext: onPlayNext,
            onOpenMoreMenu: (position, song, queueSongIds) {
              onOpenSongContextMenu(
                position,
                song,
                queueSongIds,
                customPlaylists,
              );
            },
            onTimelineLabelChange: onTimelineLabelChange,
          ),
        ),
      ],
    );
  }
}
