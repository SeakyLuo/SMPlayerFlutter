import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/playback/media_control_model.dart';
import 'package:smplayer_flutter/src/playback/now_playing_full_constants.dart';
import 'package:smplayer_flutter/src/playback/now_playing_full_lyrics.dart';
import 'package:smplayer_flutter/src/playback/now_playing_full_song_info.dart';

class NowPlayingFullStage extends StatelessWidget {
  const NowPlayingFullStage({
    super.key,
    required this.song,
    required this.artworkPath,
    required this.mediaControlState,
    required this.i18n,
    required this.refreshRevision,
    required this.onSeek,
    required this.onTogglePlayPause,
    required this.compact,
  });

  final LibrarySong? song;
  final String artworkPath;
  final MediaControlState mediaControlState;
  final SmPlayerI18n i18n;
  final int refreshRevision;
  final ValueChanged<double> onSeek;
  final VoidCallback onTogglePlayPause;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return _CompactNowPlayingFullStage(
        song: song,
        artworkPath: artworkPath,
        mediaControlState: mediaControlState,
        i18n: i18n,
        refreshRevision: refreshRevision,
        onSeek: onSeek,
        onTogglePlayPause: onTogglePlayPause,
      );
    }
    return _WideNowPlayingFullStage(
      song: song,
      artworkPath: artworkPath,
      mediaControlState: mediaControlState,
      i18n: i18n,
      refreshRevision: refreshRevision,
      onSeek: onSeek,
      onTogglePlayPause: onTogglePlayPause,
    );
  }
}

class _WideNowPlayingFullStage extends StatelessWidget {
  const _WideNowPlayingFullStage({
    required this.song,
    required this.artworkPath,
    required this.mediaControlState,
    required this.i18n,
    required this.refreshRevision,
    required this.onSeek,
    required this.onTogglePlayPause,
  });

  final LibrarySong? song;
  final String artworkPath;
  final MediaControlState mediaControlState;
  final SmPlayerI18n i18n;
  final int refreshRevision;
  final ValueChanged<double> onSeek;
  final VoidCallback onTogglePlayPause;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final pageWidth = MediaQuery.sizeOf(context).width;
        final midCompact = pageWidth <= 1100;
        final artworkSize =
            midCompact
                ? clampDouble(pageWidth * 0.28, 168, 250)
                : clampDouble(pageWidth * 0.28, 220, 416);
        final stageHeight = artworkSize + (midCompact ? 128 : 132);
        final gap = midCompact ? 32.0 : clampDouble(pageWidth * 0.05, 40, 72);
        final lyricAnchorOffset =
            pageWidth <= nowPlayingFullImmersiveCompactBreakpoint
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
                            child: NowPlayingFullSongInfo(
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
                    child: NowPlayingFullLyrics(
                      song: song,
                      progressSeconds: mediaControlState.progressSeconds,
                      durationSeconds: mediaControlState.durationSeconds,
                      isPlaying: mediaControlState.isPlaying,
                      i18n: i18n,
                      onSeek: onSeek,
                      onTogglePlayPause: onTogglePlayPause,
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

class _CompactNowPlayingFullStage extends StatelessWidget {
  const _CompactNowPlayingFullStage({
    required this.song,
    required this.artworkPath,
    required this.mediaControlState,
    required this.i18n,
    required this.refreshRevision,
    required this.onSeek,
    required this.onTogglePlayPause,
  });

  final LibrarySong? song;
  final String artworkPath;
  final MediaControlState mediaControlState;
  final SmPlayerI18n i18n;
  final int refreshRevision;
  final ValueChanged<double> onSeek;
  final VoidCallback onTogglePlayPause;

  @override
  Widget build(BuildContext context) {
    final pageWidth = MediaQuery.sizeOf(context).width;
    final artworkSize = min(pageWidth * 0.58, 250.0);
    final lyricStageHeight = min(
      MediaQuery.sizeOf(context).height * 0.44,
      320.0,
    );
    return SingleChildScrollView(
      clipBehavior: Clip.none,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: artworkSize,
                child: NowPlayingFullSongInfo(
                  song: song,
                  artworkPath: artworkPath,
                  artworkSize: artworkSize,
                  compact: true,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: lyricStageHeight,
                child: NowPlayingFullLyrics(
                  song: song,
                  progressSeconds: mediaControlState.progressSeconds,
                  durationSeconds: mediaControlState.durationSeconds,
                  isPlaying: mediaControlState.isPlaying,
                  i18n: i18n,
                  onSeek: onSeek,
                  onTogglePlayPause: onTogglePlayPause,
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
  }
}

EdgeInsets nowPlayingFullContentPadding(double width) {
  if (width <= nowPlayingFullLayoutCompactBreakpoint) {
    return const EdgeInsets.fromLTRB(18, 88, 18, 172);
  }
  if (width <= 1100) {
    return const EdgeInsets.fromLTRB(28, 72, 28, 128);
  }
  return const EdgeInsets.fromLTRB(76, 82, 76, 128);
}
