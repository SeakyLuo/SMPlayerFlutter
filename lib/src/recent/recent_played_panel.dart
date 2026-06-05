part of 'recent_page.dart';

class _RecentPlayedPanel extends StatelessWidget {
  const _RecentPlayedPanel({
    required this.filter,
    required this.songs,
    required this.playlists,
    required this.albums,
    required this.artists,
    required this.multiSelect,
    required this.selectedSongIds,
    required this.selectedCollectionKeys,
    required this.mediaControlState,
    required this.onPlaySongs,
    required this.onPlaySong,
    required this.onToggleSongSelection,
    required this.onToggleCollectionSelection,
    required this.onOpenAlbum,
    required this.onOpenArtist,
    required this.onOpenPlaylist,
    required this.onRecordPlaylistPlayed,
    required this.onRecordAlbumPlayed,
    required this.onRecordArtistPlayed,
    required this.onTimelineLabelChange,
    required this.onOpenSongAddToMenu,
    required this.onOpenSongContextMenu,
    required this.onPlayNext,
    required this.onOpenAlbumAddMenu,
    required this.onOpenArtistContextMenu,
  });

  final RecentPlayedFilter filter;
  final List<RecentLibrarySong> songs;
  final List<RecentPlaylistView> playlists;
  final List<RecentAlbumView> albums;
  final List<RecentArtistView> artists;
  final bool multiSelect;
  final Set<int> selectedSongIds;
  final Set<String> selectedCollectionKeys;
  final MediaControlState mediaControlState;
  final ValueChanged<List<int>> onPlaySongs;
  final void Function(
    LibrarySong song,
    List<int> queueSongIds, [
    int? queueIndex,
  ])
  onPlaySong;
  final ValueChanged<int> onToggleSongSelection;
  final ValueChanged<String> onToggleCollectionSelection;
  final ValueChanged<String> onOpenAlbum;
  final ValueChanged<String> onOpenArtist;
  final ValueChanged<int> onOpenPlaylist;
  final ValueChanged<int> onRecordPlaylistPlayed;
  final ValueChanged<String> onRecordAlbumPlayed;
  final ValueChanged<String> onRecordArtistPlayed;
  final ValueChanged<String> onTimelineLabelChange;
  final void Function(Offset position, LibrarySong song) onOpenSongAddToMenu;
  final void Function(Offset position, LibrarySong song, List<int> queueSongIds)
  onOpenSongContextMenu;
  final ValueChanged<int> onPlayNext;
  final void Function(Offset position, RecentAlbumView album)
  onOpenAlbumAddMenu;
  final void Function(Offset position, RecentArtistView artist)
  onOpenArtistContextMenu;

  @override
  Widget build(BuildContext context) {
    return switch (filter) {
      RecentPlayedFilter.songs => _RecentSongGrid(
        songs: songs,
        queueSongIds: songs.map((song) => song.id).toList(),
        selectedSongIds: selectedSongIds,
        multiSelect: multiSelect,
        mediaControlState: mediaControlState,
        getTimelineDate: (song) => (song as RecentLibrarySong).playedAt,
        getDetailLabel:
            (song) =>
                formatRecentDateTime((song as RecentLibrarySong).playedAt),
        onPlaySong: onPlaySong,
        onToggleSelection: onToggleSongSelection,
        onOpenAddToMenu: onOpenSongAddToMenu,
        onOpenContextMenu: onOpenSongContextMenu,
        onPlayNext: onPlayNext,
        onOpenMoreMenu: onOpenSongContextMenu,
        onTimelineLabelChange: onTimelineLabelChange,
      ),
      RecentPlayedFilter.playlists => _RecentPlaylistGrid(
        playlists: playlists,
        multiSelect: multiSelect,
        selectedKeys: selectedCollectionKeys,
        onOpen: onOpenPlaylist,
        onPlay: (playlist) {
          onRecordPlaylistPlayed(playlist.playlist.id);
          onPlaySongs(playlist.songs.map((song) => song.id).toList());
        },
        onToggleSelection: onToggleCollectionSelection,
        onTimelineLabelChange: onTimelineLabelChange,
      ),
      RecentPlayedFilter.albums => _RecentAlbumGrid(
        albums: albums,
        multiSelect: multiSelect,
        selectedKeys: selectedCollectionKeys,
        onOpen: onOpenAlbum,
        onPlay: (album) {
          onRecordAlbumPlayed(album.name);
          onPlaySongs(album.songIds);
        },
        onToggleSelection: onToggleCollectionSelection,
        onTimelineLabelChange: onTimelineLabelChange,
        onOpenContextMenu: (position, album) {
          onOpenAlbumAddMenu(position, album);
        },
      ),
      RecentPlayedFilter.artists => _RecentArtistList(
        artists: artists,
        multiSelect: multiSelect,
        selectedKeys: selectedCollectionKeys,
        onOpen: onOpenArtist,
        onPlay: (artist) {
          onRecordArtistPlayed(artist.name);
          onPlaySongs(artist.songs.map((song) => song.id).toList()..shuffle());
        },
        onToggleSelection: onToggleCollectionSelection,
        onTimelineLabelChange: onTimelineLabelChange,
        onOpenContextMenu: (position, artist) {
          onOpenArtistContextMenu(position, artist);
        },
      ),
    };
  }
}
