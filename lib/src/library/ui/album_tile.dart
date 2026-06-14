import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:smplayer_flutter/src/app/app_interaction_colors.dart';
import 'package:smplayer_flutter/src/app/smplayer_vector_icons.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/ui/artwork_floating_action_button.dart';

import '../data/library_models.dart';
import 'selected_collection_card_style.dart';
import 'song_artwork.dart';

class AlbumTileData {
  const AlbumTileData({
    required this.name,
    required this.artist,
    required this.songs,
    required this.duration,
    this.artworkSong,
    this.subtitle,
  });

  final String name;
  final String artist;
  final List<LibrarySong> songs;
  final int duration;
  final LibrarySong? artworkSong;
  final String? subtitle;

  List<int> get songIds => songs.map((song) => song.id).toList();
}

class AlbumTile extends StatefulWidget {
  const AlbumTile({
    super.key,
    required this.album,
    required this.multiSelect,
    required this.selected,
    required this.onOpenAlbum,
    required this.onPlayAlbum,
    required this.onAddAlbum,
    required this.onToggleSelection,
    this.onOpenContextMenu,
  });

  final AlbumTileData album;
  final bool multiSelect;
  final bool selected;
  final VoidCallback onOpenAlbum;
  final VoidCallback onPlayAlbum;
  final ValueChanged<Offset> onAddAlbum;
  final VoidCallback onToggleSelection;
  final ValueChanged<Offset>? onOpenContextMenu;

  @override
  State<AlbumTile> createState() => _AlbumTileState();
}

class _AlbumTileState extends State<AlbumTile> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final colors = _AlbumTileColors.forBrightness(brightness);
    final selectedStyle = SelectedCollectionCardStyle.forBrightness(brightness);
    final hoverStyle = SelectedCollectionCardStyle.hoverForBrightness(
      brightness,
    );
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
      child: GestureDetector(
        onTap:
            widget.multiSelect ? widget.onToggleSelection : widget.onOpenAlbum,
        onSecondaryTapDown: (details) {
          widget.onOpenContextMenu?.call(details.globalPosition);
        },
        child: AnimatedContainer(
          key: const ValueKey('AlbumTile.Container'),
          duration: const Duration(milliseconds: 120),
          width: 180,
          constraints: const BoxConstraints(minHeight: 232),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color:
                widget.selected
                    ? selectedStyle.background
                    : _hovered
                    ? hoverStyle.background
                    : hoverStyle.transparentBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  widget.selected
                      ? selectedStyle.border
                      : _hovered
                      ? hoverStyle.border
                      : hoverStyle.transparentBorder,
            ),
            boxShadow:
                widget.selected
                    ? [selectedStyle.shadow]
                    : _hovered
                    ? [hoverStyle.shadow]
                    : null,
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AlbumArtControl(album: widget.album),
                  const SizedBox(height: 12),
                  Text(
                    widget.album.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color:
                          widget.selected
                              ? selectedStyle.foreground
                              : colors.textStrong,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    widget.album.subtitle ?? widget.album.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color:
                          widget.selected
                              ? selectedStyle.muted
                              : colors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
              if (_hovered && !widget.multiSelect)
                Positioned(
                  left: 0,
                  right: 0,
                  top: 56,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _AlbumHoverAction(
                        icon: FluentIcons.play_20_regular,
                        onPressed: (_) => widget.onPlayAlbum(),
                      ),
                      const SizedBox(width: 10),
                      _AlbumHoverAction(
                        icon: FluentIcons.add_20_regular,
                        onPressed: widget.onAddAlbum,
                      ),
                    ],
                  ),
                ),
              if (widget.multiSelect || widget.selected)
                Positioned(
                  top: 2,
                  right: 2,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color:
                          widget.selected
                              ? colors.accent
                              : colors.selectSurface,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: colors.selectBorder),
                    ),
                    child: SizedBox.square(
                      dimension: 18,
                      child:
                          widget.selected
                              ? const Icon(
                                FluentIcons.checkmark_16_regular,
                                color: Colors.white,
                                size: 13,
                              )
                              : null,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class AlbumArtControl extends StatelessWidget {
  const AlbumArtControl({super.key, required this.album, this.dimension = 160});

  final AlbumTileData album;
  final double dimension;

  @override
  Widget build(BuildContext context) {
    final firstSong = album.artworkSong ?? getAlbumArtworkSong(album.songs);
    final brightness = Theme.of(context).brightness;
    final colors = _AlbumTileColors.forBrightness(brightness);
    final radius = BorderRadius.circular(8);

    return SizedBox.square(
      dimension: dimension,
      child: DecoratedBox(
        key: const ValueKey('AlbumTile.ArtworkSurface'),
        decoration: BoxDecoration(
          color: colors.artworkSurface,
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: colors.artworkShadow,
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: SongArtwork(artworkPath: firstSong.thumbnailPath),
        ),
      ),
    );
  }
}

LibrarySong getAlbumArtworkSong(List<LibrarySong> songs) {
  return songs.any((song) => song.thumbnailPath.isNotEmpty)
      ? songs.firstWhere((song) => song.thumbnailPath.isNotEmpty)
      : songs.first;
}

class _AlbumHoverAction extends StatelessWidget {
  const _AlbumHoverAction({required this.icon, required this.onPressed});

  final IconData icon;
  final ValueChanged<Offset> onPressed;

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (buttonContext) {
        final isPlay = icon == FluentIcons.play_20_regular;
        return ArtworkFloatingActionButton(
          tooltip:
              isPlay
                  ? context.smPlayerI18n.t('detail.playAlbum')
                  : context.smPlayerI18n.t('context.addToPlaylist'),
          icon:
              isPlay
                  ? const SmPlayerPlayIcon(size: 20, color: Colors.white)
                  : const _AlbumAddIcon(),
          onPressed: () {
            final box = buttonContext.findRenderObject() as RenderBox;
            onPressed(box.localToGlobal(Offset(0, box.size.height + 6)));
          },
        );
      },
    );
  }
}

class _AlbumAddIcon extends StatelessWidget {
  const _AlbumAddIcon();

  @override
  Widget build(BuildContext context) {
    return const Icon(
      FluentIcons.add_20_regular,
      color: Colors.white,
      size: 20,
    );
  }
}

class _AlbumTileColors {
  const _AlbumTileColors._();

  static _AlbumTileColorSet forBrightness(Brightness brightness) {
    return brightness == Brightness.dark ? dark : light;
  }

  static const light = _AlbumTileColorSet(
    hoverSurface: GlobalUI.hoverBgColorDay,
    hoverOutline: GlobalUI.hoverBorderColorDay,
    cardShadow: Color(0x1f1e2a3a),
    artworkSurface: Color(0xb8ffffff),
    artworkShadow: Color(0x21202d3f),
    accent: Color(0xff0078d7),
    selectSurface: Color(0xd1ffffff),
    selectBorder: Color(0x6b586474),
    textStrong: Color(0xff1f252b),
    textMuted: Color(0xff5f625f),
  );

  static const dark = _AlbumTileColorSet(
    hoverSurface: GlobalUI.hoverBgColorNight,
    hoverOutline: GlobalUI.hoverBorderColorNight,
    cardShadow: Color(0x3d000000),
    artworkSurface: Color(0x14ffffff),
    artworkShadow: Color(0x4d000000),
    accent: Color(0xff0078d7),
    selectSurface: Color(0xb80c1016),
    selectBorder: Color(0x6b586474),
    textStrong: Color(0xf0f6f9fc),
    textMuted: Color(0xadcbd5e1),
  );
}

class _AlbumTileColorSet {
  const _AlbumTileColorSet({
    required this.hoverSurface,
    required this.hoverOutline,
    required this.cardShadow,
    required this.artworkSurface,
    required this.artworkShadow,
    required this.accent,
    required this.selectSurface,
    required this.selectBorder,
    required this.textStrong,
    required this.textMuted,
  });

  final Color hoverSurface;
  final Color hoverOutline;
  final Color cardShadow;
  final Color artworkSurface;
  final Color artworkShadow;
  final Color accent;
  final Color selectSurface;
  final Color selectBorder;
  final Color textStrong;
  final Color textMuted;
}
