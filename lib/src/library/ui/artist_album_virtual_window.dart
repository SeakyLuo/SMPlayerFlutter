part of 'artists_page_model.dart';

class ArtistAlbumVirtualWindow {
  const ArtistAlbumVirtualWindow({
    required this.startIndex,
    required this.endIndex,
    required this.topSpacerHeight,
    required this.bottomSpacerHeight,
  });

  final int startIndex;
  final int endIndex;
  final double topSpacerHeight;
  final double bottomSpacerHeight;
}
