import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:smplayer_flutter/src/app/app_interaction_colors.dart';
import 'package:smplayer_flutter/src/app/smplayer_vector_icons.dart';
import 'package:smplayer_flutter/src/library/ui/artwork_floating_action_button.dart';
import 'package:smplayer_flutter/src/library/ui/song_artwork.dart';

class SearchArtistCard extends StatefulWidget {
  const SearchArtistCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.artworkPath,
    required this.selected,
    required this.multiSelect,
    required this.playTooltip,
    required this.onOpen,
    required this.onPlay,
    required this.onToggleSelection,
    required this.onOpenContextMenu,
  });

  final String title;
  final String subtitle;
  final String artworkPath;
  final bool selected;
  final bool multiSelect;
  final String playTooltip;
  final VoidCallback onOpen;
  final VoidCallback onPlay;
  final VoidCallback onToggleSelection;
  final ValueChanged<Offset> onOpenContextMenu;

  @override
  State<SearchArtistCard> createState() => _SearchArtistCardState();
}

class _SearchArtistCardState extends State<SearchArtistCard> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = _SearchArtistCardColors.forBrightness(
      Theme.of(context).brightness,
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
        onTap: widget.multiSelect ? widget.onToggleSelection : widget.onOpen,
        onSecondaryTapDown: (details) {
          widget.onOpenContextMenu(details.globalPosition);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 86),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color:
                widget.selected
                    ? colors.selectedSurface
                    : _hovered
                    ? colors.hoverSurface
                    : Colors.transparent,
            border: Border.all(
              color:
                  widget.selected ? colors.selectedBorder : Colors.transparent,
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow:
                widget.selected || _hovered
                    ? const [
                      BoxShadow(
                        color: Color(0x141e2a3a),
                        blurRadius: 30,
                        offset: Offset(0, 14),
                      ),
                    ]
                    : null,
          ),
          child: Stack(
            children: [
              Row(
                children: [
                  _SearchArtistArtwork(
                    artworkPath: widget.artworkPath,
                    elevated: _hovered,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.textStrong,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.textMuted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_hovered && !widget.multiSelect)
                Positioned(
                  left: 0,
                  top: 0,
                  width: 64,
                  height: 64,
                  child: Center(
                    child: ArtworkFloatingActionButton(
                      tooltip: widget.playTooltip,
                      size: 34,
                      iconSize: 17,
                      icon: const SmPlayerPlayIcon(
                        size: 17,
                        color: Colors.white,
                      ),
                      onPressed: widget.onPlay,
                    ),
                  ),
                ),
              if (widget.multiSelect || widget.selected)
                Positioned(
                  top: 9,
                  right: 9,
                  child: _SearchArtistSelectionMark(
                    selected: widget.selected,
                    colors: colors,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchArtistArtwork extends StatelessWidget {
  const _SearchArtistArtwork({
    required this.artworkPath,
    required this.elevated,
  });

  final String artworkPath;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow:
            elevated
                ? const [
                  BoxShadow(
                    color: Color(0x33322d3f),
                    blurRadius: 24,
                    offset: Offset(0, 12),
                  ),
                ]
                : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox.square(
          dimension: 64,
          child: SongArtwork(artworkPath: artworkPath),
        ),
      ),
    );
  }
}

class _SearchArtistSelectionMark extends StatelessWidget {
  const _SearchArtistSelectionMark({
    required this.selected,
    required this.colors,
  });

  final bool selected;
  final _SearchArtistCardColors colors;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: selected ? const Color(0xff0063b1) : colors.selectionSurface,
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? Colors.transparent : colors.selectionBorder,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1f485870),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: SizedBox.square(
        dimension: 23,
        child:
            selected
                ? const Icon(
                  FluentIcons.checkmark_16_regular,
                  color: Colors.white,
                  size: 16,
                )
                : null,
      ),
    );
  }
}

class _SearchArtistCardColors {
  const _SearchArtistCardColors({
    required this.textStrong,
    required this.textMuted,
    required this.hoverSurface,
    required this.selectedSurface,
    required this.selectedBorder,
    required this.selectionBorder,
    required this.selectionSurface,
  });

  final Color textStrong;
  final Color textMuted;
  final Color hoverSurface;
  final Color selectedSurface;
  final Color selectedBorder;
  final Color selectionBorder;
  final Color selectionSurface;

  static _SearchArtistCardColors forBrightness(Brightness brightness) {
    return brightness == Brightness.dark ? dark : light;
  }

  static const light = _SearchArtistCardColors(
    textStrong: Color(0xff111827),
    textMuted: Color(0xff5b697a),
    hoverSurface: SmPlayerInteractionColors.hoverSurface,
    selectedSurface: Color(0x1f0078d7),
    selectedBorder: Color(0x6b0078d7),
    selectionBorder: Color(0x52768499),
    selectionSurface: Colors.white,
  );

  static const dark = _SearchArtistCardColors(
    textStrong: Color(0xeff6f9fc),
    textMuted: Color(0xb8d8e2ef),
    hoverSurface: SmPlayerInteractionColors.hoverSurfaceDark,
    selectedSurface: Color(0x2e0078d7),
    selectedBorder: Color(0x6b0078d7),
    selectionBorder: Color(0x6bdce6f2),
    selectionSurface: Color(0xb812161d),
  );
}
