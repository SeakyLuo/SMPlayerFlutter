import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/ui/default_album_artwork.dart';
import 'package:smplayer_flutter/src/library/ui/song_artwork.dart';
import 'package:smplayer_flutter/src/library/ui/song_display_helpers.dart'
    as song_display;
import 'package:smplayer_flutter/src/playback/now_playing_full_theme.dart';

class NowPlayingFullSongInfo extends StatelessWidget {
  const NowPlayingFullSongInfo({
    super.key,
    required this.song,
    required this.artworkPath,
    required this.artworkSize,
    required this.compact,
  });

  final LibrarySong? song;
  final String artworkPath;
  final double artworkSize;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final colors = NowPlayingFullThemeColors.of(context);
    final night = colors.artworkShadowOpacity > 0.3;
    final artworkRadius = compact ? 16.0 : 18.0;
    final artworkShadows =
        compact
            ? [
              BoxShadow(
                color:
                    night ? const Color(0x52000000) : const Color(0x47665870),
                blurRadius: 88,
                offset: const Offset(0, 34),
              ),
              BoxShadow(
                color:
                    night ? const Color(0x2e000000) : const Color(0x29665870),
                blurRadius: 26,
                offset: const Offset(0, 12),
              ),
            ]
            : [
              BoxShadow(
                color:
                    night ? const Color(0x61000000) : const Color(0x38665870),
                blurRadius: night ? 86 : 76,
                offset: const Offset(0, 28),
              ),
            ];

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox.square(
          dimension: artworkSize,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(artworkRadius),
              boxShadow: artworkShadows,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(artworkRadius),
              child: SongArtwork(
                artworkPath: artworkPath,
                fallback: const DefaultAlbumArtwork(logoOpacity: 0.9),
              ),
            ),
          ),
        ),
        SizedBox(height: compact ? 22 : 28),
        Text(
          song?.title ?? i18n.t('nowPlaying.noActiveTrack'),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.start,
          style: TextStyle(
            color: colors.text,
            fontSize:
                compact
                    ? 28.48
                    : clampDouble(
                      MediaQuery.sizeOf(context).width * 0.0215,
                      24.8,
                      40,
                    ),
            fontWeight: const FontWeight(760),
            height: compact ? 1.14 : 1.16,
            shadows:
                night
                    ? const [
                      Shadow(
                        color: Color(0x70000000),
                        offset: Offset(0, 12),
                        blurRadius: 40,
                      ),
                    ]
                    : null,
          ),
        ),
        SizedBox(height: compact ? 7 : 8),
        Text(
          song == null
              ? i18n.t('common.artistUnknown')
              : song_display.displayArtists(song!, i18n),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.start,
          style: TextStyle(
            color: colors.muted,
            fontSize: compact ? 14 : 18,
            fontWeight: const FontWeight(550),
            height: compact ? 1.35 : 1.28,
          ),
        ),
        SizedBox(height: compact ? 7 : 8),
        Text(
          song == null
              ? i18n.t('common.albumUnknown')
              : song_display.displayAlbum(song!, i18n),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.start,
          style: TextStyle(
            color: colors.subtle,
            fontSize: compact ? 14 : 18,
            fontWeight: const FontWeight(550),
            height: compact ? 1.35 : 1.28,
          ),
        ),
      ],
    );
  }
}
