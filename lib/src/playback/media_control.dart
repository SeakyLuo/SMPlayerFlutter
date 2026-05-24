import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:smplayer_flutter/src/app/app_interaction_colors.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/ui/menu_flyout.dart';
import 'package:smplayer_flutter/src/library/ui/menu_flyout_helpers.dart';
import 'package:smplayer_flutter/src/library/ui/default_album_artwork.dart';
import 'package:smplayer_flutter/src/playback/media_control_model.dart';

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

@visibleForTesting
String? resolvePlayerArtworkPath(
  MediaControlTrack track,
  LibrarySong? currentSong,
) {
  return currentSong == null ? track.artworkUrl : currentSong.thumbnailPath;
}

@visibleForTesting
double resolvePlayerDurationSeconds(
  double durationSeconds,
  LibrarySong? currentSong,
) {
  return durationSeconds > 0
      ? durationSeconds
      : currentSong?.duration.toDouble() ?? 0;
}

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
    required this.onTogglePlayPause,
    required this.onPrevious,
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
    required this.onQuickPlay,
    required this.onOpenNowPlaying,
    required this.onToggleWindowFullScreen,
    required this.isWindowFullScreen,
    required this.onEnterMiniMode,
    this.onOpenVoiceAssistant,
    this.currentSong,
    this.playlists = const [],
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
  });

  final MediaControlTrack track;
  final LibrarySong? currentSong;
  final List<LibraryPlaylist> playlists;
  final bool disabled;
  final bool isPlaying;
  final int volume;
  final bool isMuted;
  final PlaybackMode mode;
  final double progressSeconds;
  final double durationSeconds;
  final String? playbackNoticeKey;
  final String? currentLyricsLine;
  final VoidCallback onTogglePlayPause;
  final VoidCallback onPrevious;
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
  final VoidCallback onQuickPlay;
  final VoidCallback onOpenNowPlaying;
  final VoidCallback onToggleWindowFullScreen;
  final bool isWindowFullScreen;
  final VoidCallback onEnterMiniMode;
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

  @override
  Widget build(BuildContext context) {
    final artworkPath = resolvePlayerArtworkPath(track, currentSong);
    final effectiveDurationSeconds = resolvePlayerDurationSeconds(
      durationSeconds,
      currentSong,
    );

    return Material(
      color: Colors.transparent,
      child: LayoutBuilder(
        builder: (context, outerConstraints) {
          final outerCompact =
              outerConstraints.maxWidth <= _playerCompactBreakpoint;
          return _PlayerBarShadowFrame(
            compact: outerCompact,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
              child: _PlayerLiquidGlassFrame(
                child: _PlayerTintedFrame(
                  artworkPath: artworkPath,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final compact =
                          constraints.maxWidth <= _playerCompactBreakpoint;
                      final condensedUtility =
                          constraints.maxWidth <=
                          _playerCondensedUtilityBreakpoint;
                      final narrowCompact = constraints.maxWidth <= 520;
                      final clampedVolume = clampVolumeValue(volume);
                      final transportDisabled = disabled || track.id == null;
                      final playerPadding =
                          compact
                              ? narrowCompact
                                  ? const EdgeInsets.fromLTRB(12, 9, 12, 11)
                                  : const EdgeInsets.fromLTRB(16, 8, 16, 10)
                              : const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              );

                      if (compact) {
                        return Padding(
                          padding: playerPadding,
                          child: _CompactMediaControlLayout(
                            narrow: narrowCompact,
                            track: track,
                            disabled: transportDisabled,
                            isPlaying: isPlaying,
                            volume: clampedVolume,
                            isMuted: isMuted,
                            mode: mode,
                            progressSeconds: progressSeconds,
                            durationSeconds: effectiveDurationSeconds,
                            onTogglePlayPause: onTogglePlayPause,
                            onPrevious: onPrevious,
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
                            onQuickPlay: onQuickPlay,
                            onOpenNowPlaying: onOpenNowPlaying,
                            onToggleWindowFullScreen: onToggleWindowFullScreen,
                            isWindowFullScreen: isWindowFullScreen,
                            onEnterMiniMode: onEnterMiniMode,
                            onOpenVoiceAssistant: onOpenVoiceAssistant,
                            playbackNoticeKey: playbackNoticeKey,
                            currentLyricsLine: currentLyricsLine,
                            currentSong: currentSong,
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
                        );
                      }

                      return Padding(
                        padding: playerPadding,
                        child: Row(
                          children: [
                            Expanded(
                              flex: 9,
                              child: _PlayerTrack(
                                track: track,
                                artworkPath: artworkPath,
                                currentLyricsLine: currentLyricsLine,
                                onArtworkError: onArtworkError,
                                disabled: track.id == null,
                                onOpenNowPlaying: onOpenNowPlaying,
                              ),
                            ),
                            Expanded(
                              flex: 19,
                              child: MediaControlSurface(
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
                                onTogglePlayPause: onTogglePlayPause,
                                onPrevious: onPrevious,
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
                                onOpenVoiceAssistant: onOpenVoiceAssistant,
                                utilityCondensed: condensedUtility,
                                onMoreClick: (moreButtonContext) {
                                  _showPlayerMoreMenu(
                                    moreButtonContext,
                                    i18n: _mediaControlI18n(context),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showPlayerMoreMenu(
    BuildContext context, {
    required SmPlayerI18n i18n,
  }) async {
    final resolvedPreferenceLevel =
        await onResolvePreferenceLevel?.call() ?? preferenceLevel;
    if (!context.mounted) {
      return;
    }
    return showMenuFlyout(
      context,
      position: _menuFlyoutPositionAboveAnchor(context),
      avoidPlayerBar: false,
      items: _buildPlayerMoreMenuItems(
        i18n: i18n,
        disabled: disabled || track.id == null,
        trackId: track.id,
        mode: mode,
        isMuted: isMuted,
        volumeValue: clampVolumeValue(volume),
        onQuickPlay: onQuickPlay,
        onVolumeChange: onVolumeChange,
        onToggleMute: onToggleMute,
        onToggleShuffle: onToggleShuffle,
        onToggleRepeat: onToggleRepeat,
        onToggleRepeatOne: onToggleRepeatOne,
        onToggleFavorite: onToggleFavorite,
        onOpenNowPlaying: onOpenNowPlaying,
        onToggleWindowFullScreen: onToggleWindowFullScreen,
        isWindowFullScreen: isWindowFullScreen,
        onEnterMiniMode: onEnterMiniMode,
        isCompact: false,
        currentSong: currentSong,
        playlists: playlists,
        preferenceLevel: resolvedPreferenceLevel,
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
    );
  }
}
