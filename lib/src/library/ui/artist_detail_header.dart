part of 'artists_page.dart';

class _ArtistDetailHeader extends StatelessWidget {
  const _ArtistDetailHeader({
    required this.artist,
    required this.compact,
    required this.responsive,
    required this.i18n,
    required this.onPlaySongs,
    required this.onOpenArtistMenu,
  });

  final ArtistGroup artist;
  final bool compact;
  final bool responsive;
  final SmPlayerI18n i18n;
  final VoidCallback onPlaySongs;
  final ValueChanged<Offset> onOpenArtistMenu;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    if (compact) {
      return DecoratedBox(
        key: const ValueKey('Artists.DetailHeader'),
        decoration: _ArtistsColors.compactDetailHeaderDecoration(brightness),
        child: _ArtistDetailCompactCommandRow(
          artist: artist,
          i18n: i18n,
          onPlaySongs: onPlaySongs,
          onOpenArtistMenu: onOpenArtistMenu,
        ),
      );
    }

    return DecoratedBox(
      key: const ValueKey('Artists.DetailHeader'),
      decoration: _ArtistsColors.detailHeaderDecoration(brightness),
      child: ClipRect(
        child: BackdropFilter(
          key: const ValueKey('Artists.DetailHeader.Blur'),
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: ColorFiltered(
            key: const ValueKey('Artists.DetailHeader.Saturate120'),
            colorFilter: _artistsBackdropSaturate120,
            child: Padding(
              key: const ValueKey('Artists.DetailHeader.Padding'),
              padding:
                  responsive
                      ? const EdgeInsets.all(18)
                      : const EdgeInsets.fromLTRB(28, 22, 28, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _ArtistsOverflowTooltipText(
                              key: const ValueKey('Artists.DetailHeader.Title'),
                              text: artist.name,
                              style: TextStyle(
                                color: _ArtistsColors.textStrongFor(brightness),
                                fontSize: 28,
                                height: 1.2,
                                fontWeight: FontWeight.w600,
                                fontVariations: const [
                                  FontVariation.weight(650),
                                ],
                                letterSpacing: 0,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              key: const ValueKey(
                                'Artists.DetailHeader.Summary',
                              ),
                              _formatArtistSummary(
                                i18n,
                                artist.albumCount,
                                artist.songs.length,
                              ),
                              textScaler: TextScaler.noScaling,
                              style: TextStyle(
                                color: _ArtistsColors.detailSummaryFor(
                                  brightness,
                                ),
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        key: const ValueKey('Artists.DetailHeader.Shuffle'),
                        tooltip: i18n.t('nowPlaying.randomPlay'),
                        icon: const ShuffleIcon(),
                        constraints: const BoxConstraints.tightFor(
                          width: 38,
                          height: 38,
                        ),
                        style: _artistHeaderActionButtonStyle(38, brightness),
                        onPressed: onPlaySongs,
                      ),
                      const SizedBox(width: 6),
                      Builder(
                        builder: (buttonContext) {
                          return GestureDetector(
                            onSecondaryTapDown: (details) {
                              onOpenArtistMenu(details.globalPosition);
                            },
                            child: IconButton(
                              key: const ValueKey('Artists.DetailHeader.More'),
                              tooltip: i18n.t('player.more'),
                              icon: const SmPlayerMoreHorizontalIcon(size: 20),
                              constraints: const BoxConstraints.tightFor(
                                width: 38,
                                height: 38,
                              ),
                              style: _artistHeaderActionButtonStyle(
                                38,
                                brightness,
                              ),
                              onPressed: () {
                                final button =
                                    buttonContext.findRenderObject()!
                                        as RenderBox;
                                onOpenArtistMenu(
                                  button.localToGlobal(
                                    Offset(0, button.size.height + 4),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
