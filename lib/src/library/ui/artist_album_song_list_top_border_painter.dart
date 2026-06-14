part of 'artists_page.dart';

class _ArtistAlbumSongListTopBorderPainter extends CustomPainter {
  const _ArtistAlbumSongListTopBorderPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..strokeWidth = 1
          ..style = PaintingStyle.stroke;
    canvas.drawLine(const Offset(0, 0.5), Offset(size.width, 0.5), paint);
  }

  @override
  bool shouldRepaint(_ArtistAlbumSongListTopBorderPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
