import 'dart:io';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';

import '../data/library_models.dart';

class AlbumTileData {
  const AlbumTileData({
    required this.name,
    required this.artist,
    required this.songs,
    required this.duration,
    this.artworkSong,
  });

  final String name;
  final String artist;
  final List<LibrarySong> songs;
  final int duration;
  final LibrarySong? artworkSong;

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
  final VoidCallback onAddAlbum;
  final VoidCallback onToggleSelection;
  final ValueChanged<Offset>? onOpenContextMenu;

  @override
  State<AlbumTile> createState() => _AlbumTileState();
}

class _AlbumTileState extends State<AlbumTile> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
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
          duration: const Duration(milliseconds: 120),
          width: 180,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color:
                widget.selected || _hovered
                    ? _AlbumTileColors.hoverSurface
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            boxShadow:
                widget.selected
                    ? const [
                      BoxShadow(
                        color: _AlbumTileColors.selectedShadow,
                        blurRadius: 18,
                        offset: Offset(0, 10),
                      ),
                    ]
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
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _AlbumTileColors.textStrong,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.album.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _AlbumTileColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              if (_hovered && !widget.multiSelect)
                Positioned(
                  top: 100,
                  right: 8,
                  child: Row(
                    children: [
                      _AlbumHoverAction(
                        icon: FluentIcons.play_20_filled,
                        onPressed: widget.onPlayAlbum,
                      ),
                      const SizedBox(width: 6),
                      _AlbumHoverAction(
                        icon: FluentIcons.add_20_regular,
                        onPressed: widget.onAddAlbum,
                      ),
                    ],
                  ),
                ),
              if (widget.multiSelect || widget.selected)
                Positioned(
                  top: 8,
                  right: 8,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color:
                          widget.selected
                              ? _AlbumTileColors.accentStrong
                              : _AlbumTileColors.selectSurface,
                      shape: BoxShape.circle,
                    ),
                    child: SizedBox.square(
                      dimension: 24,
                      child:
                          widget.selected
                              ? const Icon(
                                FluentIcons.checkmark_16_regular,
                                color: Colors.white,
                                size: 16,
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
  const AlbumArtControl({super.key, required this.album});

  final AlbumTileData album;

  @override
  Widget build(BuildContext context) {
    final firstSong = album.artworkSong ?? getAlbumArtworkSong(album.songs);
    final file =
        firstSong.thumbnailPath.isEmpty ? null : File(firstSong.thumbnailPath);

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox.square(
        dimension: 156,
        child:
            file != null && file.existsSync()
                ? Image.file(file, fit: BoxFit.cover)
                : const DecoratedBox(
                  decoration: BoxDecoration(color: _AlbumTileColors.artwork),
                  child: Icon(
                    FluentIcons.album_24_regular,
                    color: _AlbumTileColors.artworkIcon,
                    size: 42,
                  ),
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
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 34,
      child: IconButton(
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          backgroundColor: _AlbumTileColors.actionSurface,
          foregroundColor: Colors.white,
          shape: const CircleBorder(),
        ),
        icon: Icon(icon, size: 17),
        onPressed: onPressed,
      ),
    );
  }
}

class _AlbumTileColors {
  const _AlbumTileColors._();

  static const hoverSurface = Color(0xffffffff);
  static const selectedShadow = Color(0x1f1f2a38);
  static const accentStrong = Color(0xff0063b1);
  static const selectSurface = Color(0xdfffffff);
  static const actionSurface = Color(0xb81e2228);
  static const textStrong = Color(0xff111827);
  static const textMuted = Color(0xff5b697a);
  static const artwork = Color(0xffe8eef5);
  static const artworkIcon = Color(0xff607085);
}
