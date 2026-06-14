part of 'artists_page.dart';

class ArtistListArtwork extends StatefulWidget {
  const ArtistListArtwork({
    super.key,
    required this.artist,
    required this.onPlay,
    required this.brightness,
    required this.revealPlay,
  });

  final ArtistGroup artist;
  final VoidCallback onPlay;
  final Brightness brightness;
  final bool revealPlay;

  @override
  State<ArtistListArtwork> createState() => _ArtistListArtworkState();
}

class _ArtistListArtworkState extends State<ArtistListArtwork> {
  var _hovered = false;
  var _playFocused = false;

  @override
  Widget build(BuildContext context) {
    final revealPlay = widget.revealPlay || _hovered || _playFocused;
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
      child: SizedBox.square(
        key: ValueKey('Artists.ArtworkShell.${widget.artist.name}'),
        dimension: 48,
        child: DecoratedBox(
          key: ValueKey('Artists.ArtworkDecoration.${widget.artist.name}'),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              _ArtistsColors.artistArtworkShadow(
                widget.brightness,
                elevated: revealPlay,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(
                  color: _ArtistsColors.artistArtworkBackground(
                    widget.brightness,
                    hasArtwork: song.thumbnailPath.isNotEmpty,
                  ),
                  child: SongArtwork(artworkPath: song.thumbnailPath),
                ),
                IgnorePointer(
                  ignoring: !revealPlay,
                  child: AnimatedOpacity(
                    key: ValueKey(
                      'Artists.ArtworkPlay.Opacity.${widget.artist.name}',
                    ),
                    duration: const Duration(milliseconds: 120),
                    opacity: revealPlay ? 1 : 0,
                    child: Center(
                      child: FocusableActionDetector(
                        shortcuts: const {
                          SingleActivator(LogicalKeyboardKey.enter):
                              ActivateIntent(),
                          SingleActivator(LogicalKeyboardKey.space):
                              ActivateIntent(),
                        },
                        actions: {
                          ActivateIntent: CallbackAction<ActivateIntent>(
                            onInvoke: (_) {
                              widget.onPlay();
                              return null;
                            },
                          ),
                        },
                        onShowFocusHighlight: (focused) {
                          setState(() {
                            _playFocused = focused;
                          });
                        },
                        child: ArtworkFloatingActionButton(
                          key: ValueKey(
                            'Artists.ArtworkPlay.${widget.artist.name}',
                          ),
                          scaleKey: ValueKey(
                            'Artists.ArtworkPlay.Scale.${widget.artist.name}',
                          ),
                          tooltip: context.smPlayerI18n.t(
                            'nowPlaying.randomPlay',
                          ),
                          size: 44,
                          iconSize: 19,
                          icon: const SmPlayerPlayIcon(
                            color: Colors.white,
                            size: 19,
                          ),
                          onPressed: widget.onPlay,
                        ),
                      ),
                    ),
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
