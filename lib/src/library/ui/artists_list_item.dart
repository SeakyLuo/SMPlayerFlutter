part of 'artists_page.dart';

class _ArtistListItem extends StatelessWidget {
  const _ArtistListItem({
    required this.artist,
    required this.active,
    required this.i18n,
    required this.onPressed,
    required this.onPlay,
    required this.onOpenContextMenu,
  });

  final ArtistGroup artist;
  final bool active;
  final SmPlayerI18n i18n;
  final VoidCallback onPressed;
  final VoidCallback onPlay;
  final ValueChanged<Offset> onOpenContextMenu;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPressed,
        onSecondaryTapDown: (details) {
          onOpenContextMenu(details.globalPosition);
        },
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: active ? _ArtistsColors.accentSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                ArtistListArtwork(artist: artist, onPlay: onPlay),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        artist.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _ArtistsColors.textStrong,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        _formatArtistSummary(
                          i18n,
                          artist.albumCount,
                          artist.songs.length,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _ArtistsColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ArtistListArtwork extends StatefulWidget {
  const ArtistListArtwork({
    super.key,
    required this.artist,
    required this.onPlay,
  });

  final ArtistGroup artist;
  final VoidCallback onPlay;

  @override
  State<ArtistListArtwork> createState() => _ArtistListArtworkState();
}

class _ArtistListArtworkState extends State<ArtistListArtwork> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final song = widget.artist.songs.firstWhere(
      (song) => song.id == widget.artist.artworkSongId,
    );
    return MouseRegion(
      onEnter: (_) {
        setState(() {
          _hovered = true;
        });
      },
      onExit: (_) {
        setState(() {
          _hovered = false;
        });
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox.square(
          dimension: 48,
          child: Stack(
            fit: StackFit.expand,
            children: [
              SongArtwork(
                artworkPath: song.thumbnailPath,
                fallback: const DecoratedBox(
                  decoration: BoxDecoration(color: _ArtistsColors.artwork),
                  child: Icon(
                    FluentIcons.person_24_regular,
                    color: _ArtistsColors.artworkIcon,
                  ),
                ),
              ),
              IgnorePointer(
                ignoring: !_hovered,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 120),
                  opacity: _hovered ? 1 : 0,
                  child: Center(
                    child: ArtworkFloatingActionButton(
                      key: ValueKey(
                        'Artists.ArtworkPlay.${widget.artist.name}',
                      ),
                      tooltip: context.smPlayerI18n.t('context.play'),
                      size: 34,
                      iconSize: 18,
                      icon: const SmPlayerPlayIcon(
                        color: Colors.white,
                        size: 18,
                      ),
                      onPressed: widget.onPlay,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
