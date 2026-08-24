part of 'artists_page.dart';

class _ArtistAlbumSliverSection extends StatelessWidget {
  const _ArtistAlbumSliverSection({
    required this.album,
    required this.responsive,
    required this.multiSelect,
    required this.selectedSongIds,
    required this.i18n,
    required this.queueSongIds,
    required this.selectedTrackId,
    required this.isPlaying,
    required this.onPlaySongs,
    required this.onOpenAlbumMenu,
    required this.onPlayTrack,
    required this.onPlaySong,
    required this.onTogglePlayPause,
    required this.onPlayNext,
    required this.onToggleFavorite,
    required this.onOpenSongAddToMenu,
    required this.onToggleSongSelection,
    required this.onOpenSongContextMenu,
  });

  final AlbumGroup album;
  final bool responsive;
  final bool multiSelect;
  final Set<int> selectedSongIds;
  final SmPlayerI18n i18n;
  final List<int> queueSongIds;
  final int? selectedTrackId;
  final bool isPlaying;
  final VoidCallback onPlaySongs;
  final ValueChanged<Offset> onOpenAlbumMenu;
  final void Function(int songId, List<int> queueSongIds) onPlayTrack;
  final ValueChanged<int> onPlaySong;
  final VoidCallback onTogglePlayPause;
  final ValueChanged<int> onPlayNext;
  final void Function(int songId, bool favorite) onToggleFavorite;
  final FutureOr<void> Function(BuildContext context, LibrarySong song)
  onOpenSongAddToMenu;
  final ValueChanged<int> onToggleSongSelection;
  final FutureOr<void> Function(Offset position, LibrarySong song)
  onOpenSongContextMenu;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final compact = MediaQuery.sizeOf(context).width <= 720;
    final narrowSongRows = MediaQuery.sizeOf(context).width <= 1120;
    final songRowColors = _ArtistsColors.artistSongRowColors(brightness);
    final sectionRadius = compact ? 8.0 : 10.0;
    final horizontalPadding = 18.0;
    final bottomPadding = compact ? 12.0 : 22.0;
    final songRowTrailingPadding = compact ? 22.0 : 28.0;
    final sectionColor = _ArtistsColors.albumSection(brightness);
    final sectionBorder = _ArtistsColors.panelBorder(brightness);
    final songListBorder = _ArtistsColors.artistSongListBorder(brightness);
    final sectionShadow = BoxShadow(
      color: _ArtistsColors.albumShadow(brightness),
      offset: Offset(0, 16),
      blurRadius: 38,
    );

    return SliverPadding(
      key: ValueKey('Artists.AlbumSection.Padding.${album.name}'),
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        0,
        horizontalPadding,
        bottomPadding,
      ),
      sliver: DecoratedSliver(
        key: ValueKey('Artists.AlbumSection.Shadow.${album.name}'),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(sectionRadius),
          boxShadow: [sectionShadow],
        ),
        sliver: SliverMainAxisGroup(
          slivers: [
            SliverToBoxAdapter(
              child: DecoratedBox(
                key: ValueKey('Artists.AlbumSection.${album.name}'),
                decoration: BoxDecoration(
                  color: sectionColor,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(sectionRadius),
                  ),
                  border: Border(
                    top: BorderSide(color: sectionBorder),
                    left: BorderSide(color: sectionBorder),
                    right: BorderSide(color: sectionBorder),
                  ),
                ),
                child: ClipRRect(
                  key: ValueKey('Artists.AlbumSection.Clip.${album.name}'),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(sectionRadius),
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: _ArtistAlbumHeader(
                    album: album,
                    responsive: responsive,
                    i18n: i18n,
                    onPlaySongs: onPlaySongs,
                    onOpenAlbumMenu: onOpenAlbumMenu,
                  ),
                ),
              ),
            ),
            PlaylistControlSliver(
              entries: [
                for (var index = 0; index < album.songs.length; index += 1)
                  _albumSongEntry(
                    context: context,
                    song: album.songs[index],
                    queueSongIds: queueSongIds,
                    narrowSongRows: narrowSongRows,
                    songRowTrailingPadding: songRowTrailingPadding,
                    songRowColors: songRowColors,
                  ),
              ],
              itemShellBuilder: (context, index, child) {
                final first = index == 0;
                final last = index == album.songs.length - 1;
                return _ArtistAlbumSongRowShell(
                  key:
                      first
                          ? ValueKey('Artists.SongList.${album.name}')
                          : last
                          ? ValueKey('Artists.SongList.Last.${album.name}')
                          : null,
                  sectionColor: sectionColor,
                  sectionBorder: sectionBorder,
                  songListBorder: songListBorder,
                  first: first,
                  last: last,
                  radius: sectionRadius,
                  child: child,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  PlaylistControlEntry _albumSongEntry({
    required BuildContext context,
    required LibrarySong song,
    required List<int> queueSongIds,
    required bool narrowSongRows,
    required double songRowTrailingPadding,
    required PlaylistControlItemColors? songRowColors,
  }) {
    return PlaylistControlEntry(
      key: ValueKey('artist-song-${song.id}'),
      song: song,
      current: song.id == selectedTrackId,
      playing: song.id == selectedTrackId && isPlaying,
      selected: selectedSongIds.contains(song.id),
      selectionMode: multiSelect,
      showAlbum: false,
      variant: PlaylistControlItemVariant.compact,
      colors: songRowColors,
      showCompactPrimaryActions: true,
      collapseCompactPrimaryActions: narrowSongRows,
      compactDurationWidth: narrowSongRows ? 20 : 50,
      compactTrailingPadding: songRowTrailingPadding,
      favoriteAsHoverAction: true,
      keepFavoriteActionInCompact: true,
      keepAddToActionInCompact: true,
      playNextLabel: i18n.t('context.playNext'),
      addToPlaylistLabel: i18n.t('context.addToPlaylist'),
      favoriteLabel: i18n.t('common.favorite'),
      moreLabel: i18n.t('player.more'),
      onActivateRow: () {
        onPlayTrack(song.id, queueSongIds);
      },
      onPlayTrack: () {
        onPlaySong(song.id);
      },
      onTogglePlayPause: onTogglePlayPause,
      onToggleSelection: () {
        onToggleSongSelection(song.id);
      },
      onToggleFavoriteClick: () {
        onToggleFavorite(song.id, !song.favorite);
      },
      onAddToPlaylistClick: (buttonContext) {
        return onOpenSongAddToMenu(buttonContext, song);
      },
      onPlayNextClick: () {
        onPlayNext(song.id);
      },
      onOpenContextMenu: (position) {
        return onOpenSongContextMenu(position, song);
      },
      onSeeArtist: (artistName) {
        context.go('/artists?artist=${Uri.encodeQueryComponent(artistName)}');
      },
      onSeeAlbum: () {
        context.go(
          '/albums?album=${Uri.encodeQueryComponent(displayAlbum(song, i18n))}',
        );
      },
    );
  }
}
