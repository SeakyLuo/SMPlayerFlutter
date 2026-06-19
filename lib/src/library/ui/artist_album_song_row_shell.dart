part of 'artists_page.dart';

class _ArtistAlbumSongRowShell extends StatelessWidget {
  const _ArtistAlbumSongRowShell({
    super.key,
    required this.sectionColor,
    required this.sectionBorder,
    required this.songListBorder,
    required this.first,
    required this.last,
    required this.radius,
    required this.child,
  });

  final Color sectionColor;
  final Color sectionBorder;
  final Color songListBorder;
  final bool first;
  final bool last;
  final double radius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (last) {
      final roundedChild = DecoratedBox(
        decoration: BoxDecoration(
          color: sectionColor,
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(radius)),
          border: Border(
            left: BorderSide(color: sectionBorder),
            right: BorderSide(color: sectionBorder),
            bottom: BorderSide(color: sectionBorder),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(radius)),
          clipBehavior: Clip.hardEdge,
          child: CustomPaint(
            foregroundPainter:
                first
                    ? _ArtistAlbumSongListTopBorderPainter(songListBorder)
                    : null,
            child: child,
          ),
        ),
      );
      return roundedChild;
    }

    final content = DecoratedBox(
      decoration: BoxDecoration(
        color: sectionColor,
        border: Border(
          top: first ? BorderSide(color: songListBorder) : BorderSide.none,
          left: BorderSide(color: sectionBorder),
          right: BorderSide(color: sectionBorder),
        ),
      ),
      child: child,
    );

    return content;
  }
}
