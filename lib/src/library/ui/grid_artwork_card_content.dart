import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:smplayer_flutter/src/app/smplayer_vector_icons.dart';
import 'package:smplayer_flutter/src/library/ui/artwork_floating_action_button.dart';
import 'package:smplayer_flutter/src/library/ui/song_artwork.dart';

class GridArtworkAction {
  const GridArtworkAction({
    required this.title,
    required this.onPressed,
    this.icon = const SmPlayerPlayIcon(size: 20, color: Colors.white),
  });

  final String title;
  final VoidCallback? onPressed;
  final Widget icon;
}

class GridArtworkCardContent extends StatelessWidget {
  const GridArtworkCardContent({
    super.key,
    required this.title,
    required this.subtitle,
    required this.artworkUrls,
    required this.fallback,
    required this.actions,
    required this.showActions,
    required this.textStrongColor,
    required this.textMutedColor,
    this.artworkKey,
    this.selectedMark,
  });

  final String title;
  final String subtitle;
  final List<String> artworkUrls;
  final Widget fallback;
  final List<GridArtworkAction> actions;
  final bool showActions;
  final Color textStrongColor;
  final Color textMutedColor;
  final Key? artworkKey;
  final Widget? selectedMark;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox.square(
                key: artworkKey,
                dimension: 160,
                child: GridArtworkCover(
                  artworkUrls: artworkUrls,
                  fallback: fallback,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: 160,
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textStrongColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ),
            const SizedBox(height: 3),
            SizedBox(
              width: 160,
              child: Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textMutedColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
        if (showActions && actions.isNotEmpty)
          Positioned.fill(
            top: 56,
            child: Align(
              alignment: Alignment.topCenter,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final action in actions)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: ArtworkFloatingActionButton(
                        tooltip: action.title,
                        icon: action.icon,
                        onPressed: action.onPressed,
                      ),
                    ),
                ],
              ),
            ),
          ),
        if (selectedMark != null) selectedMark!,
      ],
    );
  }
}

class GridArtworkCover extends StatelessWidget {
  const GridArtworkCover({
    super.key,
    required this.artworkUrls,
    required this.fallback,
  });

  final List<String> artworkUrls;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    if (artworkUrls.isEmpty) {
      return fallback;
    }

    if (artworkUrls.length <= 2) {
      return SongArtwork(artworkPath: artworkUrls.first, fallback: fallback);
    }

    return GridView.count(
      crossAxisCount: 2,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (final artworkUrl in artworkUrls.take(4))
          SongArtwork(artworkPath: artworkUrl, fallback: fallback),
        if (artworkUrls.length == 3) fallback,
      ],
    );
  }
}

class GridViewSelectionMark extends StatelessWidget {
  const GridViewSelectionMark({
    super.key,
    required this.selected,
    this.circular = false,
  });

  final bool selected;
  final bool circular;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: circular ? 8 : 2,
      right: circular ? 8 : 2,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? const Color(0xff0078d7) : const Color(0xd1ffffff),
          shape: circular ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: circular ? null : BorderRadius.circular(5),
          border: Border.all(color: const Color(0x6b586474)),
        ),
        child: SizedBox.square(
          dimension: circular ? 24 : 18,
          child:
              selected
                  ? Icon(
                    FluentIcons.checkmark_16_regular,
                    color: Colors.white,
                    size: circular ? 16 : 13,
                  )
                  : null,
        ),
      ),
    );
  }
}
