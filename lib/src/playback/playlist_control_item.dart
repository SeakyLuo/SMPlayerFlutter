import 'dart:io';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/recent/recent_page_model.dart';

class PlaylistControlItem extends StatefulWidget {
  const PlaylistControlItem({
    super.key,
    required this.song,
    required this.current,
    required this.playing,
    required this.selected,
    required this.selectionMode,
    required this.onPlayTrack,
    required this.onTogglePlayPause,
    required this.onToggleSelection,
    required this.onPlayNextClick,
    this.onRemoveFromListClick,
    this.showAlbum = true,
    this.playNextLabel,
    this.removeLabel,
    this.addToPlaylistLabel,
    this.favoriteLabel,
    this.moreLabel,
    this.onToggleFavoriteClick,
    this.onAddToPlaylistClick,
    this.onSeeAlbum,
    this.onSeeArtist,
    this.onOpenContextMenu,
  });

  final LibrarySong song;
  final bool current;
  final bool playing;
  final bool selected;
  final bool selectionMode;
  final VoidCallback onPlayTrack;
  final VoidCallback onTogglePlayPause;
  final VoidCallback onToggleSelection;
  final VoidCallback onPlayNextClick;
  final VoidCallback? onRemoveFromListClick;
  final bool showAlbum;
  final String? playNextLabel;
  final String? removeLabel;
  final String? addToPlaylistLabel;
  final String? favoriteLabel;
  final String? moreLabel;
  final VoidCallback? onToggleFavoriteClick;
  final ValueChanged<BuildContext>? onAddToPlaylistClick;
  final VoidCallback? onSeeAlbum;
  final ValueChanged<String>? onSeeArtist;
  final ValueChanged<Offset>? onOpenContextMenu;

  @override
  State<PlaylistControlItem> createState() => _PlaylistControlItemState();
}

class _PlaylistControlItemState extends State<PlaylistControlItem> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final hasAlbumColumn = widget.showAlbum && widget.song.album.isNotEmpty;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
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
      child: InkWell(
        onTap:
            widget.selectionMode
                ? widget.onToggleSelection
                : widget.current
                ? widget.onTogglePlayPause
                : widget.onPlayTrack,
        onSecondaryTapDown: (details) {
          widget.onOpenContextMenu?.call(details.globalPosition);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 82,
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.fromLTRB(18, 10, 22, 10),
          decoration: BoxDecoration(
            color:
                widget.current
                    ? _PlaylistControlItemColors.current
                    : widget.selected || _hovered
                    ? _PlaylistControlItemColors.hover
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: const Border(
              bottom: BorderSide(color: _PlaylistControlItemColors.border),
            ),
            boxShadow:
                widget.selected
                    ? const [
                      BoxShadow(
                        color: _PlaylistControlItemColors.selectedInset,
                        offset: Offset(3, 0),
                      ),
                    ]
                    : null,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth <= 720;
              return Row(
                children: [
                  _QueueArtwork(
                    song: widget.song,
                    current: widget.current,
                    playing: widget.playing,
                    hovered: _hovered,
                    selectionMode: widget.selectionMode,
                    selected: widget.selected,
                    onPlayTrack: widget.onPlayTrack,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    flex: compact ? 1 : 12,
                    child: _QueueCopy(
                      song: widget.song,
                      current: widget.current,
                      showAlbum: widget.showAlbum,
                      onSeeAlbum: widget.onSeeAlbum,
                      onSeeArtist: widget.onSeeArtist,
                    ),
                  ),
                  if (!compact && hasAlbumColumn) ...[
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 5,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(4),
                        onTap: widget.onSeeAlbum,
                        child: Text(
                          displayAlbum(widget.song),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color:
                                widget.current
                                    ? _PlaylistControlItemColors.accentStrong
                                    : _PlaylistControlItemColors.textMuted,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 14),
                  _QueueActions(
                    favorite: widget.song.favorite,
                    compact: compact,
                    playNextLabel: widget.playNextLabel,
                    removeLabel: widget.removeLabel,
                    addToPlaylistLabel: widget.addToPlaylistLabel,
                    favoriteLabel: widget.favoriteLabel,
                    moreLabel: widget.moreLabel,
                    onToggleFavoriteClick: widget.onToggleFavoriteClick,
                    onAddToPlaylistClick: widget.onAddToPlaylistClick,
                    onPlayNextClick: widget.onPlayNextClick,
                    onRemoveFromListClick: widget.onRemoveFromListClick,
                    onOpenContextMenu: widget.onOpenContextMenu,
                  ),
                  const SizedBox(width: 18),
                  SizedBox(
                    width: 42,
                    child: Text(
                      formatDuration(widget.song.duration),
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        color:
                            widget.current
                                ? _PlaylistControlItemColors.accentStrong
                                : _PlaylistControlItemColors.textStrong,
                        fontSize: 13,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              );
            },
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
  });

  final LibrarySong song;
  final bool current;
  final bool playing;
  final bool hovered;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onPlayTrack;

  @override
  Widget build(BuildContext context) {
    final file = song.thumbnailPath.isEmpty ? null : File(song.thumbnailPath);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox.square(
            dimension: 56,
            child:
                file != null && file.existsSync()
                    ? Image.file(file, fit: BoxFit.cover)
                    : const DecoratedBox(
                      decoration: BoxDecoration(
                        color: _PlaylistControlItemColors.artwork,
                      ),
                      child: Icon(
                        FluentIcons.music_note_2_24_regular,
                        color: _PlaylistControlItemColors.artworkIcon,
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
        else if (current && playing && !hovered)
          const Positioned.fill(child: _QueuePlayingOverlay())
        else if (hovered)
          Positioned.fill(
            child: Center(
              child: IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: _PlaylistControlItemColors.overlay,
                  foregroundColor: Colors.white,
                  shape: const CircleBorder(),
                ),
                icon: const Icon(FluentIcons.play_20_filled, size: 17),
                onPressed: onPlayTrack,
              ),
            ),
          ),
      ],
    );
  }
}

class _QueuePlayingOverlay extends StatelessWidget {
  const _QueuePlayingOverlay();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: _PlaylistControlItemColors.overlay,
          shape: BoxShape.circle,
        ),
        child: SizedBox.square(
          dimension: 38,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              _PlayingBar(height: 7),
              _PlayingBar(height: 12),
              _PlayingBar(height: 15),
              _PlayingBar(height: 9),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayingBar extends StatelessWidget {
  const _PlayingBar({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 2,
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _QueueCopy extends StatelessWidget {
  const _QueueCopy({
    required this.song,
    required this.current,
    required this.showAlbum,
    required this.onSeeAlbum,
    required this.onSeeArtist,
  });

  final LibrarySong song;
  final bool current;
  final bool showAlbum;
  final VoidCallback? onSeeAlbum;
  final ValueChanged<String>? onSeeArtist;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          song.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color:
                current
                    ? _PlaylistControlItemColors.accentStrong
                    : _PlaylistControlItemColors.textStrong,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        _QueueMetadata(
          song: song,
          current: current,
          showAlbum: showAlbum,
          onSeeAlbum: onSeeAlbum,
          onSeeArtist: onSeeArtist,
        ),
      ],
    );
  }
}

class _QueueMetadata extends StatelessWidget {
  const _QueueMetadata({
    required this.song,
    required this.current,
    required this.showAlbum,
    required this.onSeeAlbum,
    required this.onSeeArtist,
  });

  final LibrarySong song;
  final bool current;
  final bool showAlbum;
  final VoidCallback? onSeeAlbum;
  final ValueChanged<String>? onSeeArtist;

  @override
  Widget build(BuildContext context) {
    final color =
        current
            ? _PlaylistControlItemColors.accentStrong
            : _PlaylistControlItemColors.textMuted;
    final artistNames =
        song.artists.isEmpty ? <String>[displayArtists(song)] : song.artists;
    final children = <Widget>[];
    for (var index = 0; index < artistNames.length; index += 1) {
      final artist = artistNames[index];
      if (index > 0) {
        children.add(Text(' / ', style: TextStyle(color: color, fontSize: 13)));
      }
      children.add(
        InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap:
              onSeeArtist == null
                  ? null
                  : () {
                    onSeeArtist!(artist);
                  },
          child: Text(
            artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: color, fontSize: 13),
          ),
        ),
      );
    }

    if (showAlbum && song.album.isNotEmpty) {
      children
        ..add(Text(' - ', style: TextStyle(color: color, fontSize: 13)))
        ..add(
          InkWell(
            borderRadius: BorderRadius.circular(4),
            onTap: onSeeAlbum,
            child: Text(
              displayAlbum(song),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontSize: 13),
            ),
          ),
        );
    }

    return SizedBox(
      height: 18,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        child: Row(children: children),
      ),
    );
  }
}

class _QueueActions extends StatelessWidget {
  const _QueueActions({
    required this.favorite,
    required this.compact,
    this.playNextLabel,
    this.removeLabel,
    this.addToPlaylistLabel,
    this.favoriteLabel,
    this.moreLabel,
    this.onToggleFavoriteClick,
    this.onAddToPlaylistClick,
    required this.onPlayNextClick,
    this.onRemoveFromListClick,
    this.onOpenContextMenu,
  });

  final bool favorite;
  final bool compact;
  final String? playNextLabel;
  final String? removeLabel;
  final String? addToPlaylistLabel;
  final String? favoriteLabel;
  final String? moreLabel;
  final VoidCallback? onToggleFavoriteClick;
  final ValueChanged<BuildContext>? onAddToPlaylistClick;
  final VoidCallback onPlayNextClick;
  final VoidCallback? onRemoveFromListClick;
  final ValueChanged<Offset>? onOpenContextMenu;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (!compact && onToggleFavoriteClick != null)
          IconButton(
            tooltip: favoriteLabel,
            icon: Icon(
              favorite
                  ? FluentIcons.heart_20_filled
                  : FluentIcons.heart_20_regular,
              size: 18,
            ),
            color:
                favorite
                    ? _PlaylistControlItemColors.favorite
                    : _PlaylistControlItemColors.textMuted,
            onPressed: onToggleFavoriteClick,
          ),
        if (!compact && onToggleFavoriteClick == null && favorite)
          const Icon(
            FluentIcons.heart_20_filled,
            size: 18,
            color: _PlaylistControlItemColors.favorite,
          ),
        if (!compact) const SizedBox(width: 4),
        if (onAddToPlaylistClick != null)
          Builder(
            builder:
                (buttonContext) => IconButton(
                  tooltip: addToPlaylistLabel,
                  icon: const Icon(FluentIcons.add_20_regular, size: 18),
                  color: _PlaylistControlItemColors.textMuted,
                  onPressed: () {
                    onAddToPlaylistClick!(buttonContext);
                  },
                ),
          ),
        IconButton(
          tooltip: playNextLabel,
          icon: const Icon(FluentIcons.next_20_regular, size: 18),
          color: _PlaylistControlItemColors.textMuted,
          onPressed: onPlayNextClick,
        ),
        if (onRemoveFromListClick != null)
          IconButton(
            tooltip: removeLabel,
            icon: const Icon(FluentIcons.dismiss_20_regular, size: 18),
            color: _PlaylistControlItemColors.textMuted,
            onPressed: onRemoveFromListClick,
          ),
        if (onOpenContextMenu != null)
          Builder(
            builder:
                (buttonContext) => IconButton(
                  tooltip: moreLabel,
                  icon: const Icon(
                    FluentIcons.more_horizontal_20_regular,
                    size: 18,
                  ),
                  color: _PlaylistControlItemColors.textMuted,
                  onPressed: () {
                    final box = buttonContext.findRenderObject() as RenderBox;
                    final offset = box.localToGlobal(
                      Offset(0, box.size.height + 8),
                    );
                    onOpenContextMenu!(offset);
                  },
                ),
          ),
      ],
    );
  }
}

class _PlaylistControlItemColors {
  const _PlaylistControlItemColors._();

  static const border = Color(0x297e8b9a);
  static const hover = Color(0x140078d7);
  static const current = Color(0x1f0078d7);
  static const selectedInset = Color(0xff0078d7);
  static const accentStrong = Color(0xff0063b1);
  static const textStrong = Color(0xff111827);
  static const textMuted = Color(0xff5b697a);
  static const favorite = Color(0xffd13438);
  static const artwork = Color(0xffe8eef5);
  static const artworkIcon = Color(0xff607085);
  static const overlay = Color(0xb81e2228);
}
