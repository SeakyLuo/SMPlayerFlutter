import 'dart:math';
import 'dart:ui';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/playback/media_control_model.dart';
import 'package:smplayer_flutter/src/playback/immersive_mode_constants.dart';
import 'package:smplayer_flutter/src/playback/immersive_mode_lyrics.dart';
import 'package:smplayer_flutter/src/playback/immersive_mode_song_info.dart';
import 'package:smplayer_flutter/src/playback/immersive_mode_theme.dart';

class ImmersiveModeStage extends StatelessWidget {
  const ImmersiveModeStage({
    super.key,
    required this.song,
    required this.songInfoKey,
    required this.lyricsKey,
    required this.artworkPath,
    required this.mediaControlState,
    required this.i18n,
    required this.refreshRevision,
    required this.onSeekAndPlay,
    required this.compact,
    required this.entranceAnimation,
  });

  final LibrarySong? song;
  final Key songInfoKey;
  final Key lyricsKey;
  final String artworkPath;
  final MediaControlState mediaControlState;
  final SmPlayerI18n i18n;
  final int refreshRevision;
  final ValueChanged<double> onSeekAndPlay;
  final bool compact;
  final Animation<double> entranceAnimation;

  @override
  Widget build(BuildContext context) {
    if (song == null) {
      return _ImmersiveModeEmptyState(i18n: i18n, compact: compact);
    }
    if (compact) {
      return _CompactImmersiveModeStage(
        song: song,
        songInfoKey: songInfoKey,
        lyricsKey: lyricsKey,
        artworkPath: artworkPath,
        mediaControlState: mediaControlState,
        i18n: i18n,
        refreshRevision: refreshRevision,
        onSeekAndPlay: onSeekAndPlay,
        entranceAnimation: entranceAnimation,
      );
    }
    return _WideImmersiveModeStage(
      song: song,
      songInfoKey: songInfoKey,
      lyricsKey: lyricsKey,
      artworkPath: artworkPath,
      mediaControlState: mediaControlState,
      i18n: i18n,
      refreshRevision: refreshRevision,
      onSeekAndPlay: onSeekAndPlay,
      entranceAnimation: entranceAnimation,
    );
  }
}

class _ImmersiveModeEmptyState extends StatelessWidget {
  const _ImmersiveModeEmptyState({required this.i18n, required this.compact});

  final SmPlayerI18n i18n;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = ImmersiveModeThemeColors.of(context);
    final iconSurfaceSize = compact ? 96.0 : 112.0;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: compact ? 24 : 32),
          child: Column(
            key: const ValueKey('ImmersiveMode.EmptyState'),
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                key: const ValueKey('ImmersiveMode.EmptyStateIcon'),
                width: iconSurfaceSize,
                height: iconSurfaceSize,
                decoration: BoxDecoration(
                  color: colors.topButtonBackground,
                  border: Border.all(color: colors.border),
                  borderRadius: BorderRadius.circular(compact ? 24 : 28),
                ),
                alignment: Alignment.center,
                child: Icon(
                  FluentIcons.music_note_2_24_regular,
                  size: compact ? 42 : 48,
                  color: colors.muted.withValues(alpha: 0.78),
                ),
              ),
              SizedBox(height: compact ? 24 : 28),
              Text(
                i18n.t('nowPlaying.noActiveTrack'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.text,
                  fontSize: compact ? 28 : 38,
                  fontWeight: const FontWeight(760),
                  height: 1.16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WideImmersiveModeStage extends StatelessWidget {
  const _WideImmersiveModeStage({
    required this.song,
    required this.songInfoKey,
    required this.lyricsKey,
    required this.artworkPath,
    required this.mediaControlState,
    required this.i18n,
    required this.refreshRevision,
    required this.onSeekAndPlay,
    required this.entranceAnimation,
  });

  final LibrarySong? song;
  final Key songInfoKey;
  final Key lyricsKey;
  final String artworkPath;
  final MediaControlState mediaControlState;
  final SmPlayerI18n i18n;
  final int refreshRevision;
  final ValueChanged<double> onSeekAndPlay;
  final Animation<double> entranceAnimation;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final pageWidth = MediaQuery.sizeOf(context).width;
        final pageHeight = MediaQuery.sizeOf(context).height;
        final midCompact = pageWidth <= 1100;
        final gap = midCompact ? 32.0 : clampDouble(pageWidth * 0.05, 40, 72);
        final availableColumnWidth = (constraints.maxWidth - 48 - gap) / 2;
        final artworkSize = min(
          immersiveModeWideArtworkSize,
          availableColumnWidth,
        );
        final stageHeight = artworkSize + 132;
        final contentPadding = immersiveModeContentPadding(pageWidth);
        final lyricStageHeight = min(stageHeight, constraints.maxHeight - 8);
        final lyricAnchorOffset = lyricStageHeight / 2;
        final lyricsVerticalCorrection =
            (contentPadding.bottom + 8 - contentPadding.top) / 2;
        final rowWidth = constraints.maxWidth - 48;
        final columnWidth = (rowWidth - gap) / 2;
        final stageTop =
            contentPadding.top +
            max(0.0, (constraints.maxHeight - stageHeight) / 2) -
            10;
        final songInfoFinalX =
            contentPadding.left + 24 + (columnWidth - artworkSize) / 2;
        final songInfoStartOffset =
            Offset(24, pageHeight - 98) - Offset(songInfoFinalX, stageTop);
        final lyricsFinalX = contentPadding.left + 24 + columnWidth + gap;
        final lyricsStageTop =
            contentPadding.top +
            max(0.0, (constraints.maxHeight - 8 - lyricStageHeight) / 2) +
            lyricsVerticalCorrection;
        final lyricsStartOffset =
            Offset(112, pageHeight - 54) - Offset(lyricsFinalX, lyricsStageTop);
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
                          child: _ImmersiveEntranceMotion(
                            motionKey: const ValueKey(
                              'ImmersiveMode.SongInfoEntrance',
                            ),
                            animation: entranceAnimation,
                            startOffset: songInfoStartOffset,
                            startScale: 72 / artworkSize,
                            startOpacity: 1,
                            child: SizedBox(
                              width: artworkSize,
                              child: ImmersiveModeSongInfo(
                                key: songInfoKey,
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
              ),
              SizedBox(width: gap),
              Expanded(
                child: Align(
                  alignment: Alignment.center,
                  child: Transform.translate(
                    offset: Offset(0, lyricsVerticalCorrection),
                    child: SizedBox(
                      height: lyricStageHeight,
                      child: _ImmersiveEntranceMotion(
                        motionKey: const ValueKey(
                          'ImmersiveMode.LyricsEntrance',
                        ),
                        animation: entranceAnimation,
                        startOffset: lyricsStartOffset,
                        startScale: 0.78,
                        startOpacity: 0,
                        intervalStart: 0.08,
                        child: ImmersiveModeLyrics(
                          key: lyricsKey,
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
    required this.songInfoKey,
    required this.lyricsKey,
    required this.artworkPath,
    required this.mediaControlState,
    required this.i18n,
    required this.refreshRevision,
    required this.onSeekAndPlay,
    required this.entranceAnimation,
  });

  final LibrarySong? song;
  final Key songInfoKey;
  final Key lyricsKey;
  final String artworkPath;
  final MediaControlState mediaControlState;
  final SmPlayerI18n i18n;
  final int refreshRevision;
  final ValueChanged<double> onSeekAndPlay;
  final Animation<double> entranceAnimation;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final pageWidth = MediaQuery.sizeOf(context).width;
        final pageHeight = MediaQuery.sizeOf(context).height;
        final artworkSize = _compactArtworkSize(
          width: pageWidth,
          height: constraints.maxHeight,
        );
        final contentPadding = immersiveModeContentPadding(pageWidth);
        final songInfoFinalX = (pageWidth - artworkSize) / 2;
        final songInfoStartOffset =
            Offset(24, pageHeight - 98) -
            Offset(songInfoFinalX, contentPadding.top);
        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: Column(
              children: [
                Center(
                  child: _ImmersiveEntranceMotion(
                    motionKey: const ValueKey('ImmersiveMode.SongInfoEntrance'),
                    animation: entranceAnimation,
                    startOffset: songInfoStartOffset,
                    startScale: 68 / artworkSize,
                    startOpacity: 1,
                    child: SizedBox(
                      width: artworkSize,
                      child: ImmersiveModeSongInfo(
                        key: songInfoKey,
                        song: song,
                        artworkPath: artworkPath,
                        artworkSize: artworkSize,
                        compact: true,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: FadeTransition(
                    key: const ValueKey('ImmersiveMode.LyricsEntrance'),
                    opacity: entranceAnimation,
                    child: ImmersiveModeLyrics(
                      key: lyricsKey,
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
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ImmersiveEntranceMotion extends StatelessWidget {
  const _ImmersiveEntranceMotion({
    required this.motionKey,
    required this.animation,
    required this.startOffset,
    required this.startScale,
    required this.startOpacity,
    required this.child,
    this.intervalStart = 0,
  });

  final Key motionKey;
  final Animation<double> animation;
  final Offset startOffset;
  final double startScale;
  final double startOpacity;
  final double intervalStart;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final intervalProgress = Interval(
          intervalStart,
          1,
          curve: Curves.easeInOutCubic,
        ).transform(animation.value);
        return Opacity(
          opacity: lerpDouble(startOpacity, 1, intervalProgress)!,
          child: Transform.translate(
            offset: Offset.lerp(startOffset, Offset.zero, intervalProgress)!,
            child: Transform.scale(
              scale: lerpDouble(startScale, 1, intervalProgress)!,
              alignment: Alignment.topLeft,
              child: KeyedSubtree(key: motionKey, child: child!),
            ),
          ),
        );
      },
    );
  }
}

double _compactArtworkSize({required double width, required double height}) {
  const compactTextReserve = 197.0;
  const stageGap = 18.0;
  const minLyricsHeight = 30.0;
  const minArtworkSize = 96.0;
  final widthBasedSize = min(width * 0.58, 250.0);
  final heightBasedSize =
      height - compactTextReserve - stageGap - minLyricsHeight;
  return min(widthBasedSize, max(minArtworkSize, heightBasedSize));
}

EdgeInsets immersiveModeContentPadding(double width) {
  if (width <= immersiveModeLayoutCompactBreakpoint) {
    return const EdgeInsets.fromLTRB(18, 88, 18, 128);
  }
  if (width <= 1100) {
    return const EdgeInsets.fromLTRB(28, 72, 28, 128);
  }
  return const EdgeInsets.fromLTRB(76, 82, 76, 128);
}
