part of 'artists_page.dart';

class _ArtistAlbumTitleLink extends StatefulWidget {
  const _ArtistAlbumTitleLink({
    required this.albumName,
    required this.brightness,
    required this.compact,
  });

  final String albumName;
  final Brightness brightness;
  final bool compact;

  @override
  State<_ArtistAlbumTitleLink> createState() => _ArtistAlbumTitleLinkState();
}

class _ArtistAlbumTitleLinkState extends State<_ArtistAlbumTitleLink> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color =
        _hovered
            ? _ArtistsColors.albumTitleHoverForeground(widget.brightness)
            : _ArtistsColors.textStrongFor(widget.brightness);
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      splashFactory: NoSplash.splashFactory,
      onHover: (hovered) {
        if (_hovered == hovered) {
          return;
        }
        setState(() {
          _hovered = hovered;
        });
      },
      onTap: () {
        context.go(
          '/albums?album=${Uri.encodeQueryComponent(widget.albumName)}',
        );
      },
      child: Text(
        key: ValueKey('Artists.AlbumTitle.${widget.albumName}'),
        widget.albumName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: widget.compact ? 17 : 18,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
