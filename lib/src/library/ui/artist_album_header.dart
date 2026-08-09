part of 'artists_page.dart';

class _ArtistAlbumHeader extends StatelessWidget {
  const _ArtistAlbumHeader({
    required this.album,
    required this.responsive,
    required this.i18n,
    required this.onPlaySongs,
    required this.onOpenAlbumMenu,
  });

  final AlbumGroup album;
  final bool responsive;
  final SmPlayerI18n i18n;
  final VoidCallback onPlaySongs;
  final ValueChanged<Offset> onOpenAlbumMenu;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final compact = MediaQuery.sizeOf(context).width <= 720;
    final headerMinHeight = compact ? 88.0 : 112.0;
    final headerPadding =
        compact
            ? const EdgeInsets.symmetric(horizontal: 16, vertical: 12)
            : const EdgeInsets.symmetric(horizontal: 18, vertical: 16);
    final headerGap = compact ? 14.0 : 16.0;
    final expandedActionWidth =
        compact
            ? 72.0
            : responsive
            ? 36.0
            : 84.0;
    final actionButtonSize = compact ? 32.0 : 38.0;
    final actionIconSize = compact ? 14.0 : 20.0;
    final shuffleIconSize = compact ? 13.0 : 18.0;
    return ConstrainedBox(
      key: ValueKey('Artists.AlbumHeader.${album.name}'),
      constraints: BoxConstraints(minHeight: headerMinHeight),
      child: Padding(
        key: ValueKey('Artists.AlbumHeader.Padding.${album.name}'),
        padding: headerPadding,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final artworkDimension = responsive ? 64.0 : 80.0;
            final compactActions =
                constraints.maxWidth <
                artworkDimension + headerGap + expandedActionWidth + 24;
            final showArtwork = constraints.maxWidth >= actionButtonSize + 56;
            final actionWidth =
                compactActions ? actionButtonSize : expandedActionWidth;
            final actionGap = compactActions ? 8.0 : headerGap;
            return Row(
              children: [
                if (showArtwork) ...[
                  AlbumArtwork(album: album, dimension: artworkDimension),
                  SizedBox(width: actionGap),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ArtistAlbumTitleLink(
                        albumName: album.name,
                        brightness: brightness,
                        compact: compact,
                      ),
                      SizedBox(
                        key: ValueKey('Artists.AlbumSummary.Gap.${album.name}'),
                        height: compact ? 6 : 8,
                      ),
                      Text(
                        key: ValueKey('Artists.AlbumSummary.${album.name}'),
                        i18n.t('artists.albumSummary', {
                          'songs': album.songs.length,
                          'duration': formatDuration(album.duration),
                        }),
                        style: TextStyle(
                          color: _ArtistsColors.textMutedFor(brightness),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  key: ValueKey('Artists.AlbumActions.${album.name}'),
                  width: actionWidth,
                  height: actionButtonSize,
                  child: OverflowBox(
                    minWidth: 0,
                    maxWidth: 84,
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (!compactActions) ...[
                          IconButton(
                            key: ValueKey('Artists.AlbumShuffle.${album.name}'),
                            tooltip: i18n.t('nowPlaying.randomPlay'),
                            icon: ShuffleIcon(size: shuffleIconSize),
                            constraints: BoxConstraints.tightFor(
                              width: actionButtonSize,
                              height: actionButtonSize,
                            ),
                            style: _artistHeaderActionButtonStyle(
                              actionButtonSize,
                              brightness,
                            ),
                            onPressed: onPlaySongs,
                          ),
                          SizedBox(width: compact ? 4 : 6),
                        ],
                        Builder(
                          builder: (buttonContext) {
                            return GestureDetector(
                              onSecondaryTapDown: (details) {
                                onOpenAlbumMenu(details.globalPosition);
                              },
                              child: IconButton(
                                key: ValueKey(
                                  'Artists.AlbumMore.${album.name}',
                                ),
                                tooltip: i18n.t('player.more'),
                                icon: SmPlayerMoreHorizontalIcon(
                                  size: actionIconSize,
                                ),
                                constraints: BoxConstraints.tightFor(
                                  width: actionButtonSize,
                                  height: actionButtonSize,
                                ),
                                style: _artistHeaderActionButtonStyle(
                                  actionButtonSize,
                                  brightness,
                                ),
                                onPressed: () {
                                  final button =
                                      buttonContext.findRenderObject()!
                                          as RenderBox;
                                  onOpenAlbumMenu(
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
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
