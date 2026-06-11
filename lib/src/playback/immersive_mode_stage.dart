import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/playback/media_control_model.dart';
import 'package:smplayer_flutter/src/playback/immersive_mode_constants.dart';
import 'package:smplayer_flutter/src/playback/immersive_mode_lyrics.dart';
import 'package:smplayer_flutter/src/playback/immersive_mode_song_info.dart';

class ImmersiveModeStage extends StatelessWidget {
  const ImmersiveModeStage({
    super.key,
    required this.song,
    required this.artworkPath,
    required this.mediaControlState,
    required this.i18n,
    required this.refreshRevision,
    required this.onSeekAndPlay,
    required this.compact,
  });

  final LibrarySong? song;
  final String artworkPath;
  final MediaControlState mediaControlState;
  final SmPlayerI18n i18n;
  final int refreshRevision;
  final ValueChanged<double> onSeekAndPlay;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return _CompactImmersiveModeStage(
        song: song,
        artworkPath: artworkPath,
        mediaControlState: mediaControlState,
        i18n: i18n,
        refreshRevision: refreshRevision,
        onSeekAndPlay: onSeekAndPlay,
      );
    }
    return _WideImmersiveModeStage(
      song: song,
      artworkPath: artworkPath,
      mediaControlState: mediaControlState,
      i18n: i18n,
      refreshRevision: refreshRevision,
      onSeekAndPlay: onSeekAndPlay,
    );
  }
}

class _WideImmersiveModeStage extends StatelessWidget {
  const _WideImmersiveModeStage({
    required this.song,
    required this.artworkPath,
    required this.mediaControlState,
    required this.i18n,
    required this.refreshRevision,
    required this.onSeekAndPlay,
  });

  final LibrarySong? song;
  final String artworkPath;
  final MediaControlState mediaControlState;
  final SmPlayerI18n i18n;
  final int refreshRevision;
  final ValueChanged<double> onSeekAndPlay;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final pageWidth = MediaQuery.sizeOf(context).width;
        final midCompact = pageWidth <= 1100;
        final artworkSize = _electronArtworkSizeForWidth(pageWidth);
        final stageHeight = _electronLyricStageHeightForWidth(pageWidth);
        final gap = midCompact ? 32.0 : clampDouble(pageWidth * 0.05, 40, 72);
        final lyricAnchorOffset =
            pageWidth <= immersiveModeImmersiveCompactBreakpoint
                ? null
                : artworkSize / 2;
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          child: Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.center,
                  child: Transform.translate(
                    offset: const Offset(0, -10),
                    child: SizedBox(
                      height: stageHeight,
                      child: OverflowBox(
                        maxHeight: double.infinity,
                        alignment: Alignment.center,
                        child: Center(
                          child: SizedBox(
                            width: artworkSize,
                            child: ImmersiveModeSongInfo(
                              song: song,
                              artworkPath: artworkPath,
                              artworkSize: artworkSize,
                              compact: false,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: gap),
              Expanded(
                child: Align(
                  alignment: Alignment.center,
                  child: SizedBox(
                    height: stageHeight,
                    child: ImmersiveModeLyrics(
                      song: song,
                      progressSeconds: mediaControlState.progressSeconds,
                      durationSeconds: mediaControlState.durationSeconds,
                      isPlaying: mediaControlState.isPlaying,
                      i18n: i18n,
                      onSeekAndPlay: onSeekAndPlay,
                      refreshRevision: refreshRevision,
                      compact: false,
                      midCompact: midCompact,
                      anchorOffset: lyricAnchorOffset,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CompactImmersiveModeStage extends StatelessWidget {
  const _CompactImmersiveModeStage({
    required this.song,
    required this.artworkPath,
    required this.mediaControlState,
    required this.i18n,
    required this.refreshRevision,
    required this.onSeekAndPlay,
  });

  final LibrarySong? song;
  final String artworkPath;
  final MediaControlState mediaControlState;
  final SmPlayerI18n i18n;
  final int refreshRevision;
  final ValueChanged<double> onSeekAndPlay;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final pageWidth = MediaQuery.sizeOf(context).width;
        final artworkSize = min(pageWidth * 0.58, 250.0);
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: SizedBox(
              height: constraints.maxHeight,
              child: Column(
                children: [
                  SizedBox(
                    width: artworkSize,
                    child: ImmersiveModeSongInfo(
                      song: song,
                      artworkPath: artworkPath,
                      artworkSize: artworkSize,
                      compact: true,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Expanded(
                    child: ImmersiveModeLyrics(
                      song: song,
                      progressSeconds: mediaControlState.progressSeconds,
                      durationSeconds: mediaControlState.durationSeconds,
                      isPlaying: mediaControlState.isPlaying,
                      i18n: i18n,
                      onSeekAndPlay: onSeekAndPlay,
                      refreshRevision: refreshRevision,
                      compact: true,
                      midCompact: false,
                      anchorOffset: null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

double _electronArtworkSizeForWidth(double width) {
  return clampDouble(width * 0.28, 220, 416);
}

double _electronLyricStageHeightForWidth(double width) {
  return _electronArtworkSizeForWidth(width) + 132;
}

EdgeInsets immersiveModeContentPadding(double width) {
  if (width <= immersiveModeLayoutCompactBreakpoint) {
    return const EdgeInsets.fromLTRB(18, 88, 18, 172);
  }
  if (width <= 1100) {
    return const EdgeInsets.fromLTRB(28, 72, 28, 128);
  }
  return const EdgeInsets.fromLTRB(76, 82, 76, 128);
}
