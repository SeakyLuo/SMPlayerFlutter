part of 'headered_playlist_control.dart';

class HeaderedPlaylistCover extends StatelessWidget {
  const HeaderedPlaylistCover({
    super.key,
    required this.artworkUrls,
    required this.title,
    required this.type,
    this.size = 240,
    this.collapseProgress = 0,
  });

  final List<String> artworkUrls;
  final String title;
  final HeaderedPlaylistType type;
  final double size;
  final double collapseProgress;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width <= 720;
    final colors = HeaderedPlaylistThemeColors.of(context);
    final radius = compact ? 8.0 : lerpDouble(14, 8, collapseProgress)!;
    final decoration = BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
          color: colors.coverShadow,
          offset: Offset(0, compact ? 8 : 26),
          blurRadius: compact ? 18 : 58,
        ),
      ],
      border: Border.all(color: colors.coverInset),
    );

    final child =
        artworkUrls.length >= 3 && type != HeaderedPlaylistType.album
            ? GridView.count(
              crossAxisCount: 2,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              children: [
                for (final artworkUrl in artworkUrls.take(4))
                  _CoverImage(artworkUrl: artworkUrl),
                if (artworkUrls.length == 3) const _CoverMosaicFallback(),
              ],
            )
            : artworkUrls.isEmpty
            ? const _CoverFallback()
            : _CoverImage(artworkUrl: artworkUrls.first);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration:
          MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      child: DecoratedBox(
        decoration: decoration,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: SizedBox.square(dimension: size, child: child),
        ),
      ),
      builder:
          (context, progress, child) => Opacity(
            opacity: progress,
            child: Transform.translate(
              offset: Offset(0, 12 * (1 - progress)),
              child: Transform.scale(
                scale: 0.96 + 0.04 * progress,
                child: child,
              ),
            ),
          ),
    );
  }
}

class _CoverImage extends StatelessWidget {
  const _CoverImage({required this.artworkUrl});

  final String artworkUrl;

  @override
  Widget build(BuildContext context) {
    final file = File(artworkUrl);
    if (file.existsSync()) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
          return Image.file(
            file,
            fit: BoxFit.cover,
            cacheWidth: (constraints.maxWidth * devicePixelRatio).ceil(),
            cacheHeight: (constraints.maxHeight * devicePixelRatio).ceil(),
            gaplessPlayback: true,
          );
        },
      );
    }

    return const _CoverFallback();
  }
}

class _CoverFallback extends StatelessWidget {
  const _CoverFallback();

  @override
  Widget build(BuildContext context) {
    final colors = HeaderedPlaylistThemeColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: colors.coverFallbackGradient,
        color: colors.coverFallbackColor,
      ),
      child: const DefaultAlbumArtwork(logoOpacity: 0.9),
    );
  }
}

class _CoverMosaicFallback extends StatelessWidget {
  const _CoverMosaicFallback();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: Color(0xff11161c)),
      child: Image.asset(
        'assets/branding/colorful_bg_wide.png',
        fit: BoxFit.cover,
      ),
    );
  }
}
