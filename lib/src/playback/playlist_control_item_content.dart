part of 'playlist_control_item.dart';

class _QueueDropIndicator extends StatelessWidget {
  const _QueueDropIndicator();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const ValueKey('PlaylistControlItem.DropIndicator'),
      decoration: BoxDecoration(
        color: _PlaylistControlItemColors.accentStrong,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: _PlaylistControlItemColors.accentStrong.withValues(
              alpha: 0.14,
            ),
            spreadRadius: 3,
          ),
        ],
      ),
      child: const SizedBox(height: 3),
    );
  }
}

class _QueueSwipeActionRail extends StatelessWidget {
  const _QueueSwipeActionRail({required this.width, required this.actions});

  final double width;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: double.infinity,
      child: Row(
        children: [for (final action in actions) Expanded(child: action)],
      ),
    );
  }
}

class _QueueSwipeAction extends StatelessWidget {
  const _QueueSwipeAction({
    required this.label,
    required this.icon,
    required this.foregroundColor,
    required this.backgroundColor,
    required this.onPressed,
    this.active = false,
    this.toggled,
  });

  final String label;
  final Widget icon;
  final Color foregroundColor;
  final Color backgroundColor;
  final VoidCallback onPressed;
  final bool active;
  final bool? toggled;

  @override
  Widget build(BuildContext context) {
    final effectiveBackground =
        active
            ? Color.alphaBlend(
              Colors.white.withValues(alpha: 0.16),
              backgroundColor,
            )
            : backgroundColor;
    return Semantics(
      excludeSemantics: true,
      button: true,
      label: label,
      toggled: toggled,
      child: Material(
        color: effectiveBackground,
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconTheme(
                  data: IconThemeData(color: foregroundColor, size: 20),
                  child: SizedBox(height: 22, child: Center(child: icon)),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: foregroundColor,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    height: 1.1,
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

class _QueueDuration extends StatelessWidget {
  const _QueueDuration({
    required this.song,
    required this.current,
    required this.compactVariant,
    required this.width,
    required this.colors,
  });

  final LibrarySong song;
  final bool current;
  final bool compactVariant;
  final double width;
  final PlaylistControlItemColors colors;

  @override
  Widget build(BuildContext context) {
    final color = current ? colors.currentForeground : colors.textStrong;
    if (compactVariant) {
      return SizedBox(
        key: const ValueKey('PlaylistControlItem.Duration'),
        width: width,
        child: Align(
          alignment: Alignment.centerRight,
          child: Text(
            formatDuration(song.duration.toDouble()),
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.visible,
            textAlign: TextAlign.end,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      );
    }
    return SizedBox(
      key: const ValueKey('PlaylistControlItem.Duration'),
      width: width,
      child: Align(
        alignment: Alignment.centerRight,
        child: OverflowBox(
          alignment: Alignment.centerRight,
          minWidth: 0,
          maxWidth: max(width, 50),
          child: SizedBox(
            width: max(width, 50),
            child: Text(
              formatDuration(song.duration.toDouble()),
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QueueArtwork extends StatelessWidget {
  const _QueueArtwork({
    required this.song,
    required this.current,
    required this.playing,
    required this.hovered,
    required this.selectionMode,
    required this.selected,
    required this.onPlayTrack,
    required this.onTogglePlayPause,
    required this.colors,
  });

  final LibrarySong song;
  final bool current;
  final bool playing;
  final bool hovered;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onPlayTrack;
  final VoidCallback onTogglePlayPause;
  final PlaylistControlItemColors colors;

  @override
  Widget build(BuildContext context) {
    final artworkShadowVisible = hovered;
    final artworkShadow = BoxShadow(
      color: const Color(0xff202d3f).withValues(alpha: 0.24),
      offset: const Offset(0, 8),
      blurRadius: 18,
    );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        AnimatedContainer(
          key: const ValueKey('PlaylistControlItem.ArtworkShadow'),
          duration: const Duration(milliseconds: 140),
          curve: Curves.ease,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            boxShadow: artworkShadowVisible ? [artworkShadow] : const [],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox.square(
              dimension: 56,
              child: ColoredBox(
                color: colors.artworkBackground,
                child: SongArtwork(artworkPath: song.thumbnailPath),
              ),
            ),
          ),
        ),
        if (selectionMode)
          Positioned(
            top: -5,
            right: -5,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: _PlaylistControlItemColors.accentStrong,
                shape: BoxShape.circle,
              ),
              child: SizedBox.square(
                dimension: 24,
                child:
                    selected
                        ? const Icon(
                          FluentIcons.checkmark_16_regular,
                          color: Colors.white,
                          size: 14,
                        )
                        : null,
              ),
            ),
          )
        else if (current)
          Positioned.fill(
            key: const ValueKey('PlaylistControlItem.PlayingOverlay'),
            child: _QueuePlayingOverlay(playing: playing),
          ),
        if (!selectionMode && hovered)
          Positioned.fill(
            child: Center(
              child: _QueuePlayOverlayButton(
                tooltip:
                    current && playing
                        ? context.smPlayerI18n.t('player.pause')
                        : context.smPlayerI18n.t('context.play'),
                icon:
                    current && playing
                        ? const SmPlayerPauseIcon(size: 17, color: Colors.white)
                        : const SmPlayerPlayIcon(size: 17, color: Colors.white),
                onPressed: current ? onTogglePlayPause : onPlayTrack,
              ),
            ),
          ),
      ],
    );
  }
}

class _QueueCopy extends StatelessWidget {
  const _QueueCopy({
    required this.song,
    required this.searchQuery,
    required this.current,
    required this.showAlbum,
    required this.compactVariant,
    required this.onSeeAlbum,
    required this.onSeeArtist,
    required this.colors,
  });

  final LibrarySong song;
  final String searchQuery;
  final bool current;
  final bool showAlbum;
  final bool compactVariant;
  final VoidCallback? onSeeAlbum;
  final ValueChanged<String>? onSeeArtist;
  final PlaylistControlItemColors colors;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SearchMatchText(
          key: const ValueKey('PlaylistControlItem.Title'),
          text: song.title,
          query: searchQuery,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: current ? colors.currentForeground : colors.textStrong,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            fontVariations: [FontVariation.weight(compactVariant ? 760 : 720)],
            height: 1.3,
          ),
        ),
        const SizedBox(height: 5),
        _QueueMetadata(
          song: song,
          searchQuery: searchQuery,
          current: current,
          showAlbum: showAlbum,
          onSeeAlbum: onSeeAlbum,
          onSeeArtist: onSeeArtist,
          colors: colors,
        ),
      ],
    );
  }
}

class _QueueMetadata extends StatelessWidget {
  const _QueueMetadata({
    required this.song,
    required this.searchQuery,
    required this.current,
    required this.showAlbum,
    required this.onSeeAlbum,
    required this.onSeeArtist,
    required this.colors,
  });

  final LibrarySong song;
  final String searchQuery;
  final bool current;
  final bool showAlbum;
  final VoidCallback? onSeeAlbum;
  final ValueChanged<String>? onSeeArtist;
  final PlaylistControlItemColors colors;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final color = current ? colors.currentMuted : colors.textMuted;
    final hoverColor = colors.currentForeground;
    final artistNames = songArtists(song);
    final effectiveArtistNames =
        artistNames.isEmpty ? [i18n.t('common.artistUnknown')] : artistNames;
    final children = <Widget>[];
    for (var index = 0; index < effectiveArtistNames.length; index += 1) {
      final artist = effectiveArtistNames[index];
      if (index > 0) {
        children.add(
          Text(
            i18n.t('common.artistSeparator'),
            style: TextStyle(color: color, fontSize: 13),
          ),
        );
      }
      children.add(
        _QueueMetadataLink(
          text: artist,
          searchQuery: searchQuery,
          foregroundColor: color,
          hoverColor: hoverColor,
          onTap:
              onSeeArtist == null
                  ? null
                  : () {
                    onSeeArtist!(artist);
                  },
        ),
      );
    }

    if (showAlbum) {
      children
        ..add(Text(' · ', style: TextStyle(color: color, fontSize: 13)))
        ..add(
          _QueueMetadataLink(
            key: const ValueKey('PlaylistControlItem.InlineAlbum'),
            text: displayAlbum(song, i18n),
            searchQuery: searchQuery,
            foregroundColor: color,
            hoverColor: hoverColor,
            onTap: onSeeAlbum,
          ),
        );
    }

    return SizedBox(
      key: const ValueKey('PlaylistControlItem.Metadata'),
      height: 18,
      child: _QueueMetadataRow(children: children),
    );
  }
}

class _QueueMetadataLink extends StatefulWidget {
  const _QueueMetadataLink({
    super.key,
    required this.text,
    required this.foregroundColor,
    required this.hoverColor,
    required this.onTap,
    this.searchQuery = '',
  });

  final String text;
  final Color foregroundColor;
  final Color hoverColor;
  final VoidCallback? onTap;
  final String searchQuery;

  @override
  State<_QueueMetadataLink> createState() => _QueueMetadataLinkState();
}

class _QueueMetadataLinkState extends State<_QueueMetadataLink> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final interactive = widget.onTap != null;
    final color =
        interactive && _hovered ? widget.hoverColor : widget.foregroundColor;
    return MouseRegion(
      cursor: interactive ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) {
        if (interactive) {
          setState(() {
            _hovered = true;
          });
        }
      },
      onHover: (_) {
        if (interactive && !_hovered) {
          setState(() {
            _hovered = true;
          });
        }
      },
      onExit: (_) {
        if (interactive) {
          setState(() {
            _hovered = false;
          });
        }
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: interactive ? widget.onTap : null,
        child: ColoredBox(
          color: Colors.transparent,
          child: SearchMatchText(
            text: widget.text,
            query: widget.searchQuery,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: color, fontSize: 13),
          ),
        ),
      ),
    );
  }
}
