part of 'recent_page.dart';

class _RecentPlayedPage extends ConsumerWidget {
  const _RecentPlayedPage({
    required this.filter,
    required this.songs,
    required this.playlists,
    required this.albums,
    required this.artists,
    required this.i18n,
    required this.timelineLabel,
    required this.playedCount,
    required this.customPlaylists,
    required this.multiSelect,
    required this.selectedSongIds,
    required this.selectedCollectionKeys,
    required this.currentTrackId,
    required this.isPlaying,
    required this.onFilterChanged,
    required this.onToggleMultiSelect,
    required this.onClearSelection,
    required this.onPlaySongs,
    required this.onPlaySong,
    required this.onToggleSongSelection,
    required this.onToggleCollectionSelection,
    required this.onRecordCollectionPlayed,
    required this.onOpenSongContextMenu,
    required this.onPlayNext,
    required this.onOpenCollectionAddToMenu,
    required this.onOpenArtistContextMenu,
    required this.onTimelineLabelChange,
  });

  final RecentPlayedFilter filter;
  final List<RecentLibrarySong> songs;
  final List<RecentPlaylistView> playlists;
  final List<RecentAlbumView> albums;
  final List<RecentArtistView> artists;
  final SmPlayerI18n i18n;
  final String timelineLabel;
  final int playedCount;
  final List<MultiSelectCommandBarPlaylist> customPlaylists;
  final bool multiSelect;
  final Set<int> selectedSongIds;
  final Set<String> selectedCollectionKeys;
  final int? currentTrackId;
  final bool isPlaying;
  final ValueChanged<RecentPlayedFilter> onFilterChanged;
  final VoidCallback onToggleMultiSelect;
  final VoidCallback onClearSelection;
  final void Function(List<int> songIds) onPlaySongs;
  final void Function(
    LibrarySong song,
    List<int> queueSongIds, [
    int? queueIndex,
  ])
  onPlaySong;
  final ValueChanged<int> onToggleSongSelection;
  final ValueChanged<String> onToggleCollectionSelection;
  final void Function(
    Future<void> Function(LibraryRepository repository) record,
  )
  onRecordCollectionPlayed;
  final Future<void> Function(
    Offset position,
    LibrarySong song,
    List<int> queueSongIds,
    List<MultiSelectCommandBarPlaylist> customPlaylists,
  )
  onOpenSongContextMenu;
  final ValueChanged<int> onPlayNext;
  final void Function(
    Offset position,
    String defaultName,
    List<int> songIds,
    List<MultiSelectCommandBarPlaylist> customPlaylists,
  )
  onOpenCollectionAddToMenu;
  final Future<void> Function(
    Offset position,
    RecentArtistView artist,
    List<MultiSelectCommandBarPlaylist> customPlaylists,
  )
  onOpenArtistContextMenu;
  final ValueChanged<String> onTimelineLabelChange;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      spacing: 4,
      children: [
        _RecentPlayedFilterBar(
          i18n: i18n,
          activeFilter: filter,
          onChanged: onFilterChanged,
        ),
        CommandBar(
          overflowLabel: i18n.t('player.more'),
          content: _RecentCommandBarTimelineLabel(label: timelineLabel),
          children: [
            CommandBarButton(
              icon: FluentIcons.multiselect_ltr_20_regular,
              label: i18n.t('albums.multiSelect'),
              active: multiSelect,
              activeMatchesHover: true,
              tooltip:
                  multiSelect ? i18n.t('common.exitMultiSelectTooltip') : null,
              disabled: !_canSelectVisiblePlayedItems(),
              onPressed: onToggleMultiSelect,
            ),
            CommandBarButton(
              icon: FluentIcons.dismiss_20_regular,
              label: i18n.t('recent.clearHistory'),
              disabled: playedCount == 0,
              onPressed: () {
                unawaited(_confirmClearHistory(context, ref));
              },
            ),
          ],
        ),
        Expanded(
          child: _RecentPlayedPanel(
            filter: filter,
            songs: songs,
            playlists: playlists,
            albums: albums,
            artists: artists,
            multiSelect: multiSelect,
            selectedSongIds: selectedSongIds,
            selectedCollectionKeys: selectedCollectionKeys,
            currentTrackId: currentTrackId,
            isPlaying: isPlaying,
            onPlaySongs: onPlaySongs,
            onPlaySong: onPlaySong,
            onToggleSongSelection: onToggleSongSelection,
            onToggleCollectionSelection: onToggleCollectionSelection,
            onOpenAlbum: (albumName) {
              context.go(
                '/albums?album=${Uri.encodeQueryComponent(albumName)}',
              );
            },
            onOpenArtist: (artistName) {
              context.go(
                '/artists?artist=${Uri.encodeQueryComponent(artistName)}',
              );
            },
            onOpenPlaylist: (playlistId) {
              context.go('/playlists/$playlistId');
            },
            onRecordPlaylistPlayed: (playlistId) {
              onRecordCollectionPlayed(
                (repository) => repository.recordPlaylistPlayed(playlistId),
              );
            },
            onRecordAlbumPlayed: (albumName) {
              onRecordCollectionPlayed(
                (repository) => repository.recordAlbumPlayed(albumName),
              );
            },
            onRecordArtistPlayed: (artistName) {
              onRecordCollectionPlayed(
                (repository) => repository.recordArtistPlayed(artistName),
              );
            },
            onOpenSongContextMenu: (position, song, queueSongIds) {
              onOpenSongContextMenu(
                position,
                song,
                queueSongIds,
                customPlaylists,
              );
            },
            onPlayNext: onPlayNext,
            onOpenSongAddToMenu: (position, song) {
              onOpenCollectionAddToMenu(position, song.title, [
                song.id,
              ], customPlaylists);
            },
            onOpenAlbumAddMenu: (position, album) {
              onOpenCollectionAddToMenu(
                position,
                album.name,
                album.songIds,
                customPlaylists,
              );
            },
            onOpenArtistContextMenu: (position, artist) {
              unawaited(
                onOpenArtistContextMenu(position, artist, customPlaylists),
              );
            },
            onTimelineLabelChange: onTimelineLabelChange,
          ),
        ),
      ],
    );
  }

  bool _canSelectVisiblePlayedItems() {
    return switch (filter) {
      RecentPlayedFilter.songs => songs.isNotEmpty,
      RecentPlayedFilter.playlists => playlists.isNotEmpty,
      RecentPlayedFilter.albums => albums.isNotEmpty,
      RecentPlayedFilter.artists => artists.isNotEmpty,
    };
  }

  Future<void> _confirmClearHistory(BuildContext context, WidgetRef ref) async {
    final confirmed = await showPopupConfirmDialog(
      context: context,
      title: i18n.t('common.confirm'),
      message: i18n.t('recent.clearPlayedConfirm'),
      confirmLabel: i18n.t('common.confirm'),
      destructive: false,
    );
    if (!confirmed) {
      return;
    }
    ref.read(libraryRepositoryProvider).clearRecentPlayed();
    ref.invalidate(recentPageDataProvider);
    onClearSelection();
  }
}
