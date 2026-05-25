part of 'artists_page.dart';

class _ArtistsDetail extends StatelessWidget {
  const _ArtistsDetail({
    required this.selectedArtist,
    required this.scrollController,
    required this.multiSelect,
    required this.selectedSongIds,
    required this.i18n,
    required this.onPlaySongs,
    required this.onOpenArtistMenu,
    required this.onOpenAlbumMenu,
    required this.selectedTrackId,
    required this.isPlaying,
    required this.onPlayTrack,
    required this.onTogglePlayPause,
    required this.onPlayNext,
    required this.onToggleFavorite,
    required this.onOpenSongAddToMenu,
    required this.onToggleSongSelection,
    required this.onOpenSongContextMenu,
    this.compact = false,
    this.onReturnToArtistList,
  });

  final ArtistGroup? selectedArtist;
  final ScrollController scrollController;
  final bool multiSelect;
  final Set<int> selectedSongIds;
  final SmPlayerI18n i18n;
  final void Function(
    List<int> songIds, {
    String? artistName,
    String? albumName,
  })
  onPlaySongs;
  final void Function(
    Offset position,
    ArtistGroup artist, {
    required bool showLocateArtist,
  })
  onOpenArtistMenu;
  final void Function(Offset position, AlbumGroup album) onOpenAlbumMenu;
  final int? selectedTrackId;
  final bool isPlaying;
  final void Function(int songId, List<int> queueSongIds) onPlayTrack;
  final VoidCallback onTogglePlayPause;
  final ValueChanged<int> onPlayNext;
  final void Function(int songId, bool favorite) onToggleFavorite;
  final void Function(BuildContext context, LibrarySong song)
  onOpenSongAddToMenu;
  final ValueChanged<int> onToggleSongSelection;
  final void Function(Offset position, LibrarySong song) onOpenSongContextMenu;
  final bool compact;
  final VoidCallback? onReturnToArtistList;

  @override
  Widget build(BuildContext context) {
    final artist = selectedArtist;
    if (artist == null) {
      return _ArtistsEmptyState(
        title: i18n.t('artists.selectArtist'),
        message: '',
        detail: true,
      );
    }

    final albums = buildAlbumGroups(artist.songs, i18n);
    return ColoredBox(
      color: _ArtistsColors.detailBackground,
      child: CustomScrollView(
        controller: scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: _ArtistDetailHeader(
              artist: artist,
              compact: compact,
              i18n: i18n,
              onReturnToArtistList: onReturnToArtistList,
              onPlaySongs: () {
                onPlaySongs(
                  artist.songs.map((song) => song.id).toList(),
                  artistName: artist.name,
                );
              },
              onOpenArtistMenu: (position) {
                onOpenArtistMenu(position, artist, showLocateArtist: true);
              },
            ),
          ),
          SliverList.builder(
            itemCount: albums.length,
            itemBuilder: (context, index) {
              final album = albums[index];
              return _ArtistAlbumSection(
                album: album,
                multiSelect: multiSelect,
                selectedSongIds: selectedSongIds,
                i18n: i18n,
                queueSongIds: artist.songs.map((song) => song.id).toList(),
                selectedTrackId: selectedTrackId,
                isPlaying: isPlaying,
                onPlaySongs: () {
                  onPlaySongs(
                    album.songs.map((song) => song.id).toList(),
                    albumName: album.name,
                  );
                },
                onOpenAlbumMenu: (position) {
                  onOpenAlbumMenu(position, album);
                },
                onPlayTrack: onPlayTrack,
                onTogglePlayPause: onTogglePlayPause,
                onPlayNext: onPlayNext,
                onToggleFavorite: onToggleFavorite,
                onOpenSongAddToMenu: onOpenSongAddToMenu,
                onToggleSongSelection: onToggleSongSelection,
                onOpenSongContextMenu: onOpenSongContextMenu,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ArtistDetailHeader extends StatelessWidget {
  const _ArtistDetailHeader({
    required this.artist,
    required this.compact,
    required this.i18n,
    required this.onReturnToArtistList,
    required this.onPlaySongs,
    required this.onOpenArtistMenu,
  });

  final ArtistGroup artist;
  final bool compact;
  final SmPlayerI18n i18n;
  final VoidCallback? onReturnToArtistList;
  final VoidCallback onPlaySongs;
  final ValueChanged<Offset> onOpenArtistMenu;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(compact ? 12 : 28, 22, 28, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (compact)
            IconButton(
              tooltip: i18n.t('sidebar.back'),
              icon: const Icon(FluentIcons.arrow_left_24_regular),
              onPressed: onReturnToArtistList,
            ),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      artist.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _ArtistsColors.textStrong,
                        fontSize: 30,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatArtistSummary(
                        i18n,
                        artist.albumCount,
                        artist.songs.length,
                      ),
                      style: const TextStyle(
                        color: _ArtistsColors.textMuted,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: i18n.t('nowPlaying.randomPlay'),
                icon: const Icon(FluentIcons.arrow_shuffle_24_regular),
                onPressed: onPlaySongs,
              ),
              Builder(
                builder: (buttonContext) {
                  return IconButton(
                    tooltip: i18n.t('player.more'),
                    icon: const Icon(FluentIcons.more_horizontal_24_regular),
                    onPressed: () {
                      final button =
                          buttonContext.findRenderObject()! as RenderBox;
                      onOpenArtistMenu(
                        button.localToGlobal(Offset(0, button.size.height + 4)),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ArtistAlbumSection extends StatelessWidget {
  const _ArtistAlbumSection({
    required this.album,
    required this.multiSelect,
    required this.selectedSongIds,
    required this.i18n,
    required this.queueSongIds,
    required this.selectedTrackId,
    required this.isPlaying,
    required this.onPlaySongs,
    required this.onOpenAlbumMenu,
    required this.onPlayTrack,
    required this.onTogglePlayPause,
    required this.onPlayNext,
    required this.onToggleFavorite,
    required this.onOpenSongAddToMenu,
    required this.onToggleSongSelection,
    required this.onOpenSongContextMenu,
  });

  final AlbumGroup album;
  final bool multiSelect;
  final Set<int> selectedSongIds;
  final SmPlayerI18n i18n;
  final List<int> queueSongIds;
  final int? selectedTrackId;
  final bool isPlaying;
  final VoidCallback onPlaySongs;
  final ValueChanged<Offset> onOpenAlbumMenu;
  final void Function(int songId, List<int> queueSongIds) onPlayTrack;
  final VoidCallback onTogglePlayPause;
  final ValueChanged<int> onPlayNext;
  final void Function(int songId, bool favorite) onToggleFavorite;
  final void Function(BuildContext context, LibrarySong song)
  onOpenSongAddToMenu;
  final ValueChanged<int> onToggleSongSelection;
  final void Function(Offset position, LibrarySong song) onOpenSongContextMenu;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 22),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _ArtistsColors.albumSection,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _ArtistsColors.panelBorder),
          boxShadow: const [
            BoxShadow(
              color: _ArtistsColors.albumShadow,
              offset: Offset(0, 16),
              blurRadius: 38,
            ),
          ],
        ),
        child: Column(
          children: [
            _ArtistAlbumHeader(
              album: album,
              i18n: i18n,
              onPlaySongs: onPlaySongs,
              onOpenAlbumMenu: onOpenAlbumMenu,
            ),
            ...album.songs.map(
              (song) => PlaylistControlItem(
                key: ValueKey('artist-song-${song.id}'),
                song: song,
                current: song.id == selectedTrackId,
                playing: song.id == selectedTrackId && isPlaying,
                selected: selectedSongIds.contains(song.id),
                selectionMode: multiSelect,
                showAlbum: false,
                playNextLabel: i18n.t('context.playNext'),
                addToPlaylistLabel: i18n.t('context.addToPlaylist'),
                favoriteLabel: i18n.t('common.favorite'),
                moreLabel: i18n.t('player.more'),
                onPlayTrack: () {
                  onPlayTrack(song.id, queueSongIds);
                },
                onTogglePlayPause: onTogglePlayPause,
                onToggleSelection: () {
                  onToggleSongSelection(song.id);
                },
                onToggleFavoriteClick: () {
                  onToggleFavorite(song.id, !song.favorite);
                },
                onAddToPlaylistClick: (buttonContext) {
                  onOpenSongAddToMenu(buttonContext, song);
                },
                onPlayNextClick: () {
                  onPlayNext(song.id);
                },
                onOpenContextMenu: (position) {
                  onOpenSongContextMenu(position, song);
                },
                onSeeAlbum: () {
                  context.go(
                    '/albums?album=${Uri.encodeQueryComponent(displayAlbum(song, i18n))}',
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArtistAlbumHeader extends StatelessWidget {
  const _ArtistAlbumHeader({
    required this.album,
    required this.i18n,
    required this.onPlaySongs,
    required this.onOpenAlbumMenu,
  });

  final AlbumGroup album;
  final SmPlayerI18n i18n;
  final VoidCallback onPlaySongs;
  final ValueChanged<Offset> onOpenAlbumMenu;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          AlbumArtwork(album: album),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () {
                    context.go(
                      '/albums?album=${Uri.encodeQueryComponent(album.name)}',
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      album.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _ArtistsColors.textStrong,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  i18n.t('artists.albumSummary', {
                    'songs': album.songs.length,
                    'duration': formatDuration(album.duration),
                  }),
                  style: const TextStyle(
                    color: _ArtistsColors.textMuted,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: i18n.t('nowPlaying.randomPlay'),
            icon: const Icon(FluentIcons.arrow_shuffle_24_regular),
            onPressed: onPlaySongs,
          ),
          Builder(
            builder: (buttonContext) {
              return IconButton(
                tooltip: i18n.t('player.more'),
                icon: const Icon(FluentIcons.more_horizontal_24_regular),
                onPressed: () {
                  final button = buttonContext.findRenderObject()! as RenderBox;
                  onOpenAlbumMenu(
                    button.localToGlobal(Offset(0, button.size.height + 4)),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class AlbumArtwork extends StatelessWidget {
  const AlbumArtwork({super.key, required this.album});

  final AlbumGroup album;

  @override
  Widget build(BuildContext context) {
    final firstSong = getAlbumArtworkSong(album.songs);
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox.square(
        dimension: 72,
        child: SongArtwork(artworkPath: firstSong.thumbnailPath),
      ),
    );
  }
}
