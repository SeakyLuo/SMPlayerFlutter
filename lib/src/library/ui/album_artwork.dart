part of 'artists_page.dart';

class AlbumArtwork extends StatelessWidget {
  const AlbumArtwork({super.key, required this.album, required this.dimension});

  final AlbumGroup album;
  final double dimension;

  @override
  Widget build(BuildContext context) {
    final firstSong = getAlbumArtworkSong(album.songs);
    final brightness = Theme.of(context).brightness;
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox.square(
        key: ValueKey('Artists.AlbumArtwork.${album.name}'),
        dimension: dimension,
        child: DecoratedBox(
          key: ValueKey('Artists.AlbumArtwork.Background.${album.name}'),
          decoration: BoxDecoration(
            color: _ArtistsColors.albumArtworkBackground(brightness),
          ),
          child: SongArtwork(artworkPath: firstSong.thumbnailPath),
        ),
      ),
    );
  }
}
