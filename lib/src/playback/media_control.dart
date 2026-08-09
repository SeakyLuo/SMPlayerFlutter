import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:smplayer_flutter/src/app/app_interaction_colors.dart';
import 'package:smplayer_flutter/src/app/exit_fullscreen_icon.dart';
import 'package:smplayer_flutter/src/app/shell_models.dart';
import 'package:smplayer_flutter/src/app/smplayer_vector_icons.dart';
import 'package:smplayer_flutter/src/app/svg_icon.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/ui/menu_flyout.dart';
import 'package:smplayer_flutter/src/library/ui/menu_flyout_helpers.dart';
import 'package:smplayer_flutter/src/library/ui/default_album_artwork.dart';
import 'package:smplayer_flutter/src/library/ui/song_artwork.dart';
import 'package:smplayer_flutter/src/playback/hold_release_action.dart';
import 'package:smplayer_flutter/src/playback/media_control_model.dart';
import 'package:smplayer_flutter/src/playback/quick_play_model.dart';

part 'media_control_frame.dart';
part 'media_control_surface.dart';
part 'media_control_volume.dart';
part 'media_control_compact.dart';
part 'media_control_menus.dart';
part 'media_control_track.dart';
part 'media_control_utility.dart';
part 'media_control_progress.dart';
part 'media_control_buttons.dart';
part 'media_control_artwork.dart';
part 'media_control_colors.dart';

const _playerCompactBreakpoint = 800.0;
const _playerCondensedUtilityBreakpoint = 1200.0;
const _artworkColorMinValue = 10;
const _artworkColorMaxValue = 205;
const _artworkColorGridDivisions = 16;
const _defaultArtworkAccentColor = Color(0xff5b87b6);

EdgeInsets mediaControlPlayerPadding(double viewportWidth) {
  if (viewportWidth <= 520) {
    return const EdgeInsets.fromLTRB(12, 9, 12, 11);
  }
  if (viewportWidth <= _playerCompactBreakpoint) {
    return const EdgeInsets.fromLTRB(12, 8, 16, 10);
  }
  return const EdgeInsets.fromLTRB(12, 10, 16, 10);
}

double mediaControlPlayerColumnGap(double viewportWidth) {
  if (viewportWidth <= 520) {
    return 8;
  }
  if (viewportWidth <= _playerCompactBreakpoint) {
    return 10;
  }
  return 0;
}

double mediaControlPlayerSideWidth(
  double viewportWidth, {
  required double contentWidth,
}) {
  if (viewportWidth <= 520) {
    return 68;
  }
  if (viewportWidth <= _playerCompactBreakpoint) {
    return 80;
  }

  final minSide =
      viewportWidth <= _playerCondensedUtilityBreakpoint
          ? clampDouble(viewportWidth * 0.24, 200, 280)
          : 280;
  final minCenter =
      viewportWidth <= _playerCondensedUtilityBreakpoint
          ? clampDouble(viewportWidth * 0.40, 280, 420)
          : 420;
  final extra = max(0.0, contentWidth - minCenter - minSide * 2);
  return minSide + extra * 0.9 / 2.8;
}

String? resolvePlayerArtworkPath(
  MediaControlTrack track,
  LibrarySong? currentSong,
) {
  return currentSong == null ? track.artworkUrl : currentSong.thumbnailPath;
}

double resolvePlayerDurationSeconds(
  double durationSeconds,
  LibrarySong? currentSong,
) {
  return durationSeconds > 0
      ? durationSeconds
      : currentSong?.duration.toDouble() ?? 0;
}

typedef MediaControlLeadingBuilder =
    Widget Function(BuildContext context, bool compact);

class MediaControl extends StatelessWidget {
  const MediaControl({
    super.key,
    required this.track,
    required this.disabled,
    required this.isPlaying,
    required this.volume,
    required this.isMuted,
    required this.mode,
    required this.progressSeconds,
    required this.durationSeconds,
    this.previousButtonRestartsTrack = false,
    required this.onTogglePlayPause,
    required this.onPrevious,
    this.onForcePrevious,
    required this.onNext,
    required this.onSeek,
    required this.onBeginSeek,
    required this.onEndSeek,
    required this.onVolumeChange,
    required this.onToggleMute,
    required this.onToggleShuffle,
    required this.onToggleRepeat,
    required this.onToggleRepeatOne,
    required this.onToggleFavorite,
    this.desktopLyricsEnabled = false,
    this.onToggleDesktopLyrics,
    required this.onQuickPlay,
    required this.onOpenNowPlaying,
    this.onToggleWindowFullScreen,
    required this.isWindowFullScreen,
    this.onEnterMiniMode,
    this.onOpenVoiceAssistant,
    this.currentSong,
    this.nowPlayingSongIds = const [],
    this.librarySongs = const [],
    this.recentSongs = const [],
    this.playlists = const [],
    this.folders = const [],
    this.onPlaySongs,
    this.onPlayArtist,
    this.onPlayAlbum,
    this.playbackNoticeKey,
    this.currentLyricsLine,
    this.preferenceLevel,
    this.onResolvePreferenceLevel,
    this.onAddToNowPlaying,
    this.onCreatePlaylist,
    this.onAddToPlaylist,
    this.onUndoPreference,
    this.onSetPreference,
    this.onSeeArtist,
    this.onSeeAlbum,
    this.onSeeMusicInfo,
    this.onSeeLyrics,
    this.onSeeAlbumArt,
    this.onSeeLocal,
    this.onArtworkError,
    this.leadingBuilder,
    this.onMoreClick,
  });

  final MediaControlTrack track;
  final LibrarySong? currentSong;
  final List<int> nowPlayingSongIds;
  final List<LibrarySong> librarySongs;
  final List<LibrarySong> recentSongs;
  final List<LibraryPlaylist> playlists;
  final List<LibraryFolder> folders;
  final ValueChanged<List<int>>? onPlaySongs;
  final VoidCallback? onPlayArtist;
  final VoidCallback? onPlayAlbum;
  final bool disabled;
  final bool isPlaying;
  final int volume;
  final bool isMuted;
  final PlaybackMode mode;
  final double progressSeconds;
  final double durationSeconds;
  final bool previousButtonRestartsTrack;
  final String? playbackNoticeKey;
  final String? currentLyricsLine;
  final VoidCallback onTogglePlayPause;
  final VoidCallback onPrevious;
  final VoidCallback? onForcePrevious;
  final VoidCallback onNext;
  final ValueChanged<double> onSeek;
  final VoidCallback onBeginSeek;
  final VoidCallback onEndSeek;
  final ValueChanged<int> onVolumeChange;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleShuffle;
  final VoidCallback onToggleRepeat;
  final VoidCallback onToggleRepeatOne;
  final VoidCallback onToggleFavorite;
  final bool desktopLyricsEnabled;
  final VoidCallback? onToggleDesktopLyrics;
  final VoidCallback onQuickPlay;
  final VoidCallback onOpenNowPlaying;
  final VoidCallback? onToggleWindowFullScreen;
  final bool isWindowFullScreen;
  final VoidCallback? onEnterMiniMode;
  final VoidCallback? onOpenVoiceAssistant;
  final String? preferenceLevel;
  final FutureOr<String?> Function()? onResolvePreferenceLevel;
  final VoidCallback? onAddToNowPlaying;
  final ValueChanged<String>? onCreatePlaylist;
  final ValueChanged<int>? onAddToPlaylist;
  final VoidCallback? onUndoPreference;
  final ValueChanged<String>? onSetPreference;
  final VoidCallback? onSeeArtist;
  final VoidCallback? onSeeAlbum;
  final VoidCallback? onSeeMusicInfo;
  final VoidCallback? onSeeLyrics;
  final VoidCallback? onSeeAlbumArt;
  final VoidCallback? onSeeLocal;
  final VoidCallback? onArtworkError;
  final MediaControlLeadingBuilder? leadingBuilder;
  final ValueChanged<BuildContext>? onMoreClick;

  @override
  Widget build(BuildContext context) {
    final artworkPath = resolvePlayerArtworkPath(track, currentSong);
    final effectiveDurationSeconds = resolvePlayerDurationSeconds(
      durationSeconds,
      currentSong,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth <= _playerCompactBreakpoint;
        final leading = leadingBuilder?.call(context, compact);
        final condensedUtility =
            constraints.maxWidth <= _playerCondensedUtilityBreakpoint;
        final narrowCompact = constraints.maxWidth <= 520;
        final emptyTrack = track.id == null;
        final quickPlayTooltip = _mediaControlI18n(
          context,
        ).t('nowPlaying.quickPlay');
        final clampedVolume = clampVolumeValue(volume);
        final transportDisabled = disabled || emptyTrack;
        final playerPadding = mediaControlPlayerPadding(constraints.maxWidth);
        final sideWidth = mediaControlPlayerSideWidth(
          constraints.maxWidth,
          contentWidth: constraints.maxWidth - playerPadding.horizontal,
        );
        final sliderColors = MediaControlSliderColors.forBrightness(
          Theme.of(context).brightness,
        );
        final songsById = {for (final song in librarySongs) song.id: song};
        final queueSongs = [
          for (final songId in nowPlayingSongIds)
            if (songsById[songId] case final song?) song,
        ];
        final randomPlaySubmenu =
            onPlaySongs == null
                ? null
                : buildShuffleMenuFlyoutItems(
                  i18n: _mediaControlI18n(context),
                  songs: queueSongs,
                  librarySongs: librarySongs,
                  recentSongs: recentSongs,
                  playlists: playlists,
                  folders: folders,
                  randomLimit: quickPlayDefaultLimit,
                  onPlaySongs: onPlaySongs!,
                  includeQuickPlay: false,
                );

        return SizedBox(
          height: SmPlayerShellMetrics.playerHeight,
          child:
              compact
                  ? MediaControlPlayerFrame(
                    artworkPath: artworkPath,
                    preserveWideBackground: true,
                    child: Padding(
                      padding: playerPadding,
                      child: _CompactMediaControlLayout(
                        leading: leading,
                        onMoreClick: onMoreClick,
                        narrow: narrowCompact,
                        track: track,
                        disabled: transportDisabled,
                        isPlaying: isPlaying,
                        volume: clampedVolume,
                        isMuted: isMuted,
                        mode: mode,
                        progressSeconds: progressSeconds,
                        durationSeconds: effectiveDurationSeconds,
                        previousButtonRestartsTrack:
                            previousButtonRestartsTrack,
                        onTogglePlayPause: onTogglePlayPause,
                        playButtonDisabled: emptyTrack ? false : null,
                        playButtonTooltip: emptyTrack ? quickPlayTooltip : null,
                        onPlayButtonPressed: emptyTrack ? onQuickPlay : null,
                        onPrevious: onPrevious,
                        onForcePrevious: onForcePrevious,
                        onNext: onNext,
                        onSeek: onSeek,
                        onBeginSeek: onBeginSeek,
                        onEndSeek: onEndSeek,
                        onVolumeChange: onVolumeChange,
                        onToggleMute: onToggleMute,
                        onToggleShuffle: onToggleShuffle,
                        onToggleRepeat: onToggleRepeat,
                        onToggleRepeatOne: onToggleRepeatOne,
                        onToggleFavorite: onToggleFavorite,
                        desktopLyricsEnabled: desktopLyricsEnabled,
                        onToggleDesktopLyrics: onToggleDesktopLyrics,
                        onQuickPlay: onQuickPlay,
                        onOpenNowPlaying: onOpenNowPlaying,
                        onToggleWindowFullScreen: onToggleWindowFullScreen,
                        isWindowFullScreen: isWindowFullScreen,
                        onEnterMiniMode: onEnterMiniMode,
                        onOpenVoiceAssistant: onOpenVoiceAssistant,
                        playbackNoticeKey: playbackNoticeKey,
                        currentLyricsLine: currentLyricsLine,
                        currentSong: currentSong,
                        nowPlayingSongIds: nowPlayingSongIds,
                        randomPlaySubmenu: randomPlaySubmenu,
                        randomPlayDisabled:
                            nowPlayingSongIds.isEmpty && librarySongs.isEmpty,
                        onPlayArtist: onPlayArtist,
                        onPlayAlbum: onPlayAlbum,
                        onArtworkError: onArtworkError,
                        playlists: playlists,
                        preferenceLevel: preferenceLevel,
                        onResolvePreferenceLevel: onResolvePreferenceLevel,
                        onAddToNowPlaying: onAddToNowPlaying,
                        onCreatePlaylist: onCreatePlaylist,
                        onAddToPlaylist: onAddToPlaylist,
                        onUndoPreference: onUndoPreference,
                        onSetPreference: onSetPreference,
                        onSeeArtist: onSeeArtist ?? onOpenNowPlaying,
                        onSeeAlbum: onSeeAlbum ?? onOpenNowPlaying,
                        onSeeMusicInfo: onSeeMusicInfo ?? onOpenNowPlaying,
                        onSeeLyrics: onSeeLyrics ?? onOpenNowPlaying,
                        onSeeAlbumArt: onSeeAlbumArt ?? onOpenNowPlaying,
                        onSeeLocal: onSeeLocal ?? onOpenNowPlaying,
                      ),
                    ),
                  )
                  : MediaControlSurfaceBar(
                    artworkPath: artworkPath,
                    padding: playerPadding,
                    leadingWidth: sideWidth,
                    surfaceFlex: 1,
                    utilityWidth: sideWidth,
                    columnGap: mediaControlPlayerColumnGap(
                      constraints.maxWidth,
                    ),
                    preserveWideBackground: true,
                    leading:
                        leading ??
                        Align(
                          alignment: Alignment.centerLeft,
                          child: MediaControlTrackInfo(
                            track: track,
                            artworkPath: artworkPath,
                            currentLyricsLine: currentLyricsLine,
                            onArtworkError: onArtworkError,
                            disabled: track.id == null,
                            onPressed: onOpenNowPlaying,
                          ),
                        ),
                    trackId: track.id,
                    isLoading: track.isLoading,
                    favorite: track.favorite,
                    disabled: transportDisabled,
                    isPlaying: isPlaying,
                    volume: clampedVolume,
                    isMuted: isMuted,
                    mode: mode,
                    progressSeconds: progressSeconds,
                    durationSeconds: effectiveDurationSeconds,
                    previousButtonRestartsTrack: previousButtonRestartsTrack,
                    onTogglePlayPause: onTogglePlayPause,
                    playButtonDisabled: emptyTrack ? false : null,
                    playButtonTooltip: emptyTrack ? quickPlayTooltip : null,
                    onPlayButtonPressed: emptyTrack ? onQuickPlay : null,
                    onPrevious: onPrevious,
                    onForcePrevious: onForcePrevious,
                    onNext: onNext,
                    onSeek: onSeek,
                    onBeginSeek: onBeginSeek,
                    onEndSeek: onEndSeek,
                    onVolumeChange: onVolumeChange,
                    onToggleMute: onToggleMute,
                    onToggleShuffle: onToggleShuffle,
                    onToggleRepeat: onToggleRepeat,
                    onToggleRepeatOne: onToggleRepeatOne,
                    onToggleFavorite: onToggleFavorite,
                    desktopLyricsEnabled: desktopLyricsEnabled,
                    onToggleDesktopLyrics: onToggleDesktopLyrics,
                    onOpenVoiceAssistant: onOpenVoiceAssistant,
                    utilityCondensed: condensedUtility,
                    sliderActiveColor: sliderColors.progressActive,
                    sliderInactiveColor: sliderColors.progressInactive,
                    sliderThumbColor: sliderColors.progressThumb,
                    sliderThumbShadow: sliderColors.progressThumbShadow,
                    sliderOverlayColor: Colors.transparent,
                    volumeSliderActiveColor: sliderColors.volumeActive,
                    volumeSliderInactiveColor: sliderColors.volumeInactive,
                    volumeSliderThumbColor: sliderColors.volumeThumb,
                    volumeSliderThumbShadow:
                        MediaControlSliderColors.volumeThumbShadow,
                    volumeSliderOverlayColor: Colors.transparent,
                    onMoreClick:
                        onMoreClick ??
                        (moreButtonContext) {
                          _showPlayerMoreMenu(
                            moreButtonContext,
                            i18n: _mediaControlI18n(context),
                          );
                        },
                  ),
        );
      },
    );
  }

  Future<void> _showPlayerMoreMenu(
    BuildContext context, {
    required SmPlayerI18n i18n,
  }) async {
    final songsById = {for (final song in librarySongs) song.id: song};
    final queueSongs = [
      for (final songId in nowPlayingSongIds)
        if (songsById[songId] case final song?) song,
    ];
    await showMediaControlMoreMenu(
      context: context,
      i18n: i18n,
      isMuted: isMuted,
      volumeValue: clampVolumeValue(volume),
      onQuickPlay: onQuickPlay,
      alwaysShowQuickPlay: true,
      randomPlayDisabled: nowPlayingSongIds.isEmpty && librarySongs.isEmpty,
      randomPlaySubmenu:
          onPlaySongs == null
              ? null
              : buildShuffleMenuFlyoutItems(
                i18n: i18n,
                songs: queueSongs,
                librarySongs: librarySongs,
                recentSongs: recentSongs,
                playlists: playlists,
                folders: folders,
                randomLimit: quickPlayDefaultLimit,
                onPlaySongs: onPlaySongs!,
                includeQuickPlay: false,
              ),
      onVolumeChange: onVolumeChange,
      onToggleMute: onToggleMute,
      onToggleFavorite: onToggleFavorite,
      onToggleWindowFullScreen: onToggleWindowFullScreen,
      isWindowFullScreen: isWindowFullScreen,
      onEnterMiniMode: onEnterMiniMode,
      showFavoriteWhenUnavailable: true,
      currentSong: currentSong,
      nowPlayingSongIds: nowPlayingSongIds,
      playlists: playlists,
      preferenceLevel: preferenceLevel,
      onResolvePreferenceLevel: onResolvePreferenceLevel,
      onAddToNowPlaying: onAddToNowPlaying,
      onCreatePlaylist: onCreatePlaylist,
      onAddToPlaylist: onAddToPlaylist,
      onUndoPreference: onUndoPreference,
      onSetPreference: onSetPreference,
      onPlayArtist: onPlayArtist,
      onPlayAlbum: onPlayAlbum,
      onSeeArtist: onSeeArtist ?? onOpenNowPlaying,
      onSeeAlbum: onSeeAlbum ?? onOpenNowPlaying,
      onSeeMusicInfo: onSeeMusicInfo ?? onOpenNowPlaying,
      onSeeLyrics: onSeeLyrics ?? onOpenNowPlaying,
      onSeeAlbumArt: onSeeAlbumArt ?? onOpenNowPlaying,
      onSeeLocal: onSeeLocal ?? onOpenNowPlaying,
    );
  }
}
