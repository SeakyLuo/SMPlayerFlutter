part of 'artists_page.dart';

class _ArtistDetailCompactCommandRow extends StatelessWidget {
  const _ArtistDetailCompactCommandRow({
    required this.artist,
    required this.i18n,
    required this.onPlaySongs,
    required this.onOpenArtistMenu,
    this.workspaceAppBarBottom = false,
  });

  final ArtistGroup artist;
  final SmPlayerI18n i18n;
  final VoidCallback onPlaySongs;
  final FutureOr<void> Function(Offset) onOpenArtistMenu;
  final bool workspaceAppBarBottom;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Padding(
      padding: EdgeInsets.fromLTRB(workspaceAppBarBottom ? 12 : 8, 0, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 32,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  key: const ValueKey('Artists.DetailHeader.Summary'),
                  _formatArtistSummary(
                    i18n,
                    artist.albumCount,
                    artist.songs.length,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(
                    color: _ArtistsColors.textMutedFor(brightness),
                    fontSize: 14,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(
            key: ValueKey('Artists.DetailHeader.CompactCommandGap'),
            width: 6,
          ),
          IconButton(
            key: const ValueKey('Artists.DetailHeader.Shuffle'),
            tooltip: i18n.t('nowPlaying.randomPlay'),
            icon: const ShuffleIcon(),
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            style: _artistHeaderActionButtonStyle(32, brightness),
            onPressed: onPlaySongs,
          ),
          const SizedBox(width: 4),
          Builder(
            builder: (buttonContext) {
              return GestureDetector(
                onSecondaryTapDown: (details) {
                  onOpenArtistMenu(details.globalPosition);
                },
                child: IconButton(
                  key: const ValueKey('Artists.DetailHeader.More'),
                  tooltip: i18n.t('player.more'),
                  icon: const SmPlayerMoreHorizontalIcon(size: 17),
                  constraints: const BoxConstraints.tightFor(
                    width: 32,
                    height: 32,
                  ),
                  style: _artistHeaderActionButtonStyle(32, brightness),
                  onPressed: () {
                    final button =
                        buttonContext.findRenderObject()! as RenderBox;
                    onOpenArtistMenu(
                      button.localToGlobal(Offset(0, button.size.height + 4)),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
