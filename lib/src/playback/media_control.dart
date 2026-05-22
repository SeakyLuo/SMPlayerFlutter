import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/ui/command_bar.dart';
import 'package:smplayer_flutter/src/playback/media_control_model.dart';

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
  final VoidCallback? onCreatePlaylist;
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
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: _PlayerTintedFrame(
            artworkPath: artworkPath,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact =
                      constraints.maxWidth <= _playerCompactBreakpoint;
                  final condensedUtility =
                      constraints.maxWidth <= _playerCondensedUtilityBreakpoint;
                  final narrowCompact = constraints.maxWidth <= 520;
                  final clampedVolume = clampVolumeValue(volume);
                  final surfaceVolume = disabled ? 0 : clampedVolume;

                  if (compact) {
                    return _CompactMediaControlLayout(
                      narrow: narrowCompact,
                      track: track,
                      disabled: disabled,
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
                    );
                  }

                  return Row(
                    children: [
                      Expanded(
                        flex: 9,
                        child: _PlayerTrack(
                          track: track,
                          artworkPath: artworkPath,
                          playbackNoticeKey: playbackNoticeKey,
                          currentLyricsLine: currentLyricsLine,
                          onArtworkError: onArtworkError,
                          disabled: track.id == null,
                          onOpenNowPlaying: onOpenNowPlaying,
                        ),
                      ),
                      Expanded(
                        flex: 10,
                        child: MediaControlSurface(
                          trackId: track.id,
                          isLoading: track.isLoading,
                          favorite: track.favorite,
                          disabled: disabled,
                          isPlaying: isPlaying,
                          volume: surfaceVolume,
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
                          onMoreClick: () {
                            _showPlayerMoreMenu(
                              context,
                              i18n: _mediaControlI18n(context),
                            );
                          },
                        ),
                      ),
                      Expanded(
                        flex: 9,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: _PlayerUtilityRows(
                            trackId: track.id,
                            favorite: track.favorite,
                            disabled: disabled,
                            volumeValue: surfaceVolume,
                            isMuted: isMuted,
                            mode: mode,
                            onVolumeChange: onVolumeChange,
                            onToggleMute: onToggleMute,
                            onToggleShuffle: onToggleShuffle,
                            onToggleRepeat: onToggleRepeat,
                            onToggleRepeatOne: onToggleRepeatOne,
                            onToggleFavorite: onToggleFavorite,
                            onOpenVoiceAssistant: onOpenVoiceAssistant,
                            condensed: condensedUtility,
                            onMoreClick: () {
                              _showPlayerMoreMenu(
                                context,
                                i18n: _mediaControlI18n(context),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
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
      items: _buildPlayerMoreMenuItems(
        i18n: i18n,
        disabled: disabled,
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

class _PlayerTintedFrame extends StatefulWidget {
  const _PlayerTintedFrame({required this.artworkPath, required this.child});

  final String? artworkPath;
  final Widget child;

  @override
  State<_PlayerTintedFrame> createState() => _PlayerTintedFrameState();
}

class _PlayerTintedFrameState extends State<_PlayerTintedFrame> {
  var _accentColor = _defaultArtworkAccentColor;
  var _loadSerial = 0;

  @override
  void initState() {
    super.initState();
    _loadArtworkAccentColor();
  }

  @override
  void didUpdateWidget(covariant _PlayerTintedFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.artworkPath != widget.artworkPath) {
      _loadArtworkAccentColor();
    }
  }

  @override
  Widget build(BuildContext context) {
    final night = MediaControlColors.isNight(context);
    final coverWash = _accentColor.withValues(alpha: 0.24);
    final nightCoverWash = _accentColor.withValues(alpha: 0.22);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: MediaControlColors.playerBorderFor(night)),
          left: BorderSide(color: MediaControlColors.playerBorderFor(night)),
          right: BorderSide(color: MediaControlColors.playerBorderFor(night)),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors:
              night
                  ? [
                    MediaControlColors.nightPlayerHighlight,
                    nightCoverWash,
                    MediaControlColors.nightPlayerSurface,
                  ]
                  : [
                    MediaControlColors.playerSurface,
                    coverWash,
                    MediaControlColors.playerSurfaceSolid,
                  ],
          stops: const [0, 0.52, 1],
        ),
        boxShadow: [
          BoxShadow(
            color: MediaControlColors.playerShadowFor(night),
            offset: const Offset(0, -18),
            blurRadius: 48,
          ),
        ],
      ),
      child: widget.child,
    );
  }

  void _loadArtworkAccentColor() {
    final loadSerial = _loadSerial + 1;
    _loadSerial = loadSerial;
    final artworkPath = widget.artworkPath ?? '';
    if (artworkPath.isEmpty) {
      _setAccentColor(_defaultArtworkAccentColor);
      return;
    }

    unawaited(
      extractPlayerArtworkAccentColor(artworkPath).then((color) {
        if (!mounted || loadSerial != _loadSerial) {
          return;
        }
        _setAccentColor(color);
      }),
    );
  }

  void _setAccentColor(Color color) {
    if (_accentColor == color) {
      return;
    }
    setState(() {
      _accentColor = color;
    });
  }
}

class MediaControlSurface extends StatefulWidget {
  const MediaControlSurface({
    super.key,
    required this.trackId,
    required this.isLoading,
    required this.favorite,
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
    this.onOpenVoiceAssistant,
    this.condensed = false,
    required this.onMoreClick,
  });

  final int? trackId;
  final bool isLoading;
  final bool favorite;
  final bool disabled;
  final bool isPlaying;
  final int volume;
  final bool isMuted;
  final PlaybackMode mode;
  final double progressSeconds;
  final double durationSeconds;
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
  final VoidCallback? onOpenVoiceAssistant;
  final bool condensed;
  final VoidCallback onMoreClick;

  @override
  State<MediaControlSurface> createState() => _MediaControlSurfaceState();
}

class _MediaControlSurfaceState extends State<MediaControlSurface> {
  var _isProgressSeeking = false;
  var _draftProgressSeconds = 0.0;

  @override
  Widget build(BuildContext context) {
    final progressSeconds =
        _isProgressSeeking ? _draftProgressSeconds : widget.progressSeconds;
    final progressMax =
        widget.durationSeconds > 0 ? widget.durationSeconds : 0.0;
    final progressValue =
        widget.disabled || progressMax <= 0
            ? 0.0
            : progressSeconds.clamp(0, progressMax).toDouble();

    return MediaControlButtons(
      trackId: widget.trackId,
      isLoading: widget.isLoading,
      favorite: widget.favorite,
      disabled: widget.disabled,
      isPlaying: widget.isPlaying,
      volumeValue: widget.disabled ? 0 : clampVolumeValue(widget.volume),
      mode: widget.mode,
      progressSeconds: progressValue,
      progressValue: progressValue,
      progressMax: progressMax,
      durationSeconds: widget.durationSeconds,
      onTogglePlayPause: widget.onTogglePlayPause,
      onPrevious: widget.onPrevious,
      onNext: widget.onNext,
      onSeekChange: (value) {
        setState(() {
          _draftProgressSeconds = value;
        });
      },
      onSeekBegin: () {
        setState(() {
          _isProgressSeeking = true;
          _draftProgressSeconds = progressValue;
        });
        widget.onBeginSeek();
      },
      onSeekEnd: (value) {
        if (!_isProgressSeeking) {
          return;
        }
        widget.onSeek(value);
        widget.onEndSeek();
        setState(() {
          _isProgressSeeking = false;
        });
      },
      onVolumeChange: widget.onVolumeChange,
      onToggleMute: widget.onToggleMute,
      onToggleShuffle: widget.onToggleShuffle,
      onToggleRepeat: widget.onToggleRepeat,
      onToggleRepeatOne: widget.onToggleRepeatOne,
      onToggleFavorite: widget.onToggleFavorite,
      onOpenVoiceAssistant: widget.onOpenVoiceAssistant,
      isMuted: widget.isMuted,
      onMoreClick: widget.onMoreClick,
    );
  }
}

class MediaControlButtons extends StatelessWidget {
  const MediaControlButtons({
    super.key,
    required this.trackId,
    required this.isLoading,
    required this.favorite,
    required this.disabled,
    required this.isPlaying,
    required this.volumeValue,
    required this.mode,
    required this.progressSeconds,
    required this.progressValue,
    required this.progressMax,
    required this.durationSeconds,
    required this.onTogglePlayPause,
    required this.onPrevious,
    required this.onNext,
    required this.onSeekChange,
    required this.onSeekBegin,
    required this.onSeekEnd,
    required this.onVolumeChange,
    required this.onToggleMute,
    required this.onToggleShuffle,
    required this.onToggleRepeat,
    required this.onToggleRepeatOne,
    required this.onToggleFavorite,
    this.onOpenVoiceAssistant,
    required this.isMuted,
    required this.onMoreClick,
  });

  final int? trackId;
  final bool isLoading;
  final bool favorite;
  final bool disabled;
  final bool isPlaying;
  final int volumeValue;
  final PlaybackMode mode;
  final double progressSeconds;
  final double progressValue;
  final double progressMax;
  final double durationSeconds;
  final VoidCallback onTogglePlayPause;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<double> onSeekChange;
  final VoidCallback onSeekBegin;
  final ValueChanged<double> onSeekEnd;
  final ValueChanged<int> onVolumeChange;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleShuffle;
  final VoidCallback onToggleRepeat;
  final VoidCallback onToggleRepeatOne;
  final VoidCallback onToggleFavorite;
  final VoidCallback? onOpenVoiceAssistant;
  final bool isMuted;
  final VoidCallback onMoreClick;

  @override
  Widget build(BuildContext context) {
    final i18n = _mediaControlI18n(context);
    final textMuted = MediaControlColors.textMutedFor(context);
    final playTitle =
        isPlaying ? i18n.t('player.pause') : i18n.t('player.play');

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          height: 52,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _PlayerIconButton(
                key: const ValueKey('MediaControl.PreviousButton'),
                tooltip: i18n.t('player.previous'),
                icon: Icons.skip_previous_rounded,
                disabled: disabled,
                onPressed: onPrevious,
              ),
              const SizedBox(width: 26),
              _PlayerIconButton(
                key: const ValueKey('MediaControl.PlayPauseButton'),
                tooltip: playTitle,
                icon:
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                primary: true,
                loading: isLoading,
                disabled: disabled,
                onPressed: onTogglePlayPause,
              ),
              const SizedBox(width: 26),
              _PlayerIconButton(
                key: const ValueKey('MediaControl.NextButton'),
                tooltip: i18n.t('player.next'),
                icon: Icons.skip_next_rounded,
                disabled: disabled,
                onPressed: onNext,
              ),
            ],
          ),
        ),
        SizedBox(
          height: 36,
          child: Row(
            children: [
              SizedBox(
                width: 44,
                child: Text(
                  formatDuration(progressSeconds),
                  style: const TextStyle(
                    fontSize: 13,
                  ).copyWith(color: textMuted),
                ),
              ),
              Expanded(
                child:
                    isLoading
                        ? const _MediaProgressLoading()
                        : _MediaProgressSlider(
                          value: progressValue,
                          max: progressMax,
                          disabled: disabled || durationSeconds <= 0,
                          onChanged: onSeekChange,
                          onChangeStart: (_) {
                            onSeekBegin();
                          },
                          onChangeEnd: onSeekEnd,
                        ),
              ),
              SizedBox(
                width: 44,
                child: Text(
                  formatDuration(durationSeconds),
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    fontSize: 13,
                  ).copyWith(color: textMuted),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

enum VolumeSliderOrientation { horizontal, vertical }

int clampVolumeValue(num value) => value.round().clamp(0, 100);

IconData playerVolumeIcon(int volume, bool isMuted) {
  if (isMuted) {
    return Icons.volume_mute_rounded;
  }
  if (volume <= 0) {
    return Icons.volume_off_rounded;
  }
  if (volume < 34) {
    return Icons.volume_down_rounded;
  }
  if (volume < 67) {
    return Icons.volume_down_rounded;
  }
  return Icons.volume_up_rounded;
}

class VolumeSlider extends StatefulWidget {
  const VolumeSlider({
    super.key,
    required this.value,
    required this.disabled,
    required this.onChange,
    this.orientation = VolumeSliderOrientation.horizontal,
    this.showTooltipOnMount = false,
    this.activeTrackColor = MediaControlColors.accent,
    this.inactiveTrackColor = MediaControlColors.sliderInactive,
    this.thumbColor = MediaControlColors.accent,
    this.overlayColor = MediaControlColors.accentHover,
    this.tooltipBackgroundColor = const Color(0xe60d1726),
    this.tooltipForegroundColor = Colors.white,
  });

  final int value;
  final bool disabled;
  final ValueChanged<int> onChange;
  final VolumeSliderOrientation orientation;
  final bool showTooltipOnMount;
  final Color activeTrackColor;
  final Color inactiveTrackColor;
  final Color thumbColor;
  final Color overlayColor;
  final Color tooltipBackgroundColor;
  final Color tooltipForegroundColor;

  @override
  State<VolumeSlider> createState() => _VolumeSliderState();
}

class _VolumeSliderState extends State<VolumeSlider> {
  late var _liveValue = clampVolumeValue(widget.value).toDouble();
  late var _lastEmittedValue = clampVolumeValue(widget.value);
  Timer? _tooltipTimer;
  var _tooltipActive = false;
  var _dragging = false;

  @override
  void initState() {
    super.initState();
    if (widget.showTooltipOnMount && !widget.disabled) {
      _tooltipActive = true;
      _tooltipTimer = Timer(const Duration(milliseconds: 900), () {
        if (mounted && !_dragging) {
          setState(() {
            _tooltipActive = false;
          });
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant VolumeSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextValue = clampVolumeValue(widget.value);
    if (!_dragging && _liveValue.round() != nextValue) {
      _liveValue = nextValue.toDouble();
      _lastEmittedValue = nextValue;
    }
    if (widget.disabled && _tooltipActive) {
      _tooltipTimer?.cancel();
      _tooltipActive = false;
    }
  }

  @override
  void dispose() {
    _tooltipTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.disabled ? 0.0 : _liveValue.clamp(0, 100).toDouble();
    final inactiveTrackColor =
        widget.inactiveTrackColor == MediaControlColors.sliderInactive
            ? MediaControlColors.sliderInactiveFor(context)
            : widget.inactiveTrackColor;
    final slider = SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 2,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
        activeTrackColor: widget.activeTrackColor,
        inactiveTrackColor: inactiveTrackColor,
        thumbColor: widget.thumbColor,
        overlayColor: widget.overlayColor,
      ),
      child: Focus(
        onFocusChange: (focused) {
          if (focused) {
            _showTooltip();
          } else if (!_dragging) {
            _hideTooltip();
          }
        },
        child: MouseRegion(
          onEnter: (_) => _showTooltip(persistent: true),
          onExit: (_) {
            if (!_dragging) {
              _hideTooltip();
            }
          },
          child: Slider(
            value: value,
            min: 0,
            max: 100,
            onChangeStart:
                widget.disabled
                    ? null
                    : (_) {
                      _dragging = true;
                      _showTooltip(persistent: true);
                    },
            onChangeEnd:
                widget.disabled
                    ? null
                    : (_) {
                      _dragging = false;
                      _showTooltip();
                    },
            onChanged: widget.disabled ? null : _handleSliderChanged,
          ),
        ),
      ),
    );

    return SizedBox(
      height: widget.orientation == VolumeSliderOrientation.vertical ? 156 : 44,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          if (widget.orientation == VolumeSliderOrientation.vertical)
            RotatedBox(
              quarterTurns: -1,
              child: SizedBox(width: 132, child: slider),
            )
          else
            slider,
          if (_tooltipActive && !widget.disabled)
            _VolumeSliderTooltip(
              value: value.round(),
              orientation: widget.orientation,
              backgroundColor: widget.tooltipBackgroundColor,
              foregroundColor: widget.tooltipForegroundColor,
            ),
        ],
      ),
    );
  }

  void _handleSliderChanged(double value) {
    final nextValue = clampVolumeValue(value);
    setState(() {
      _liveValue = nextValue.toDouble();
    });
    if (_lastEmittedValue == nextValue) {
      return;
    }
    _lastEmittedValue = nextValue;
    widget.onChange(nextValue);
  }

  void _showTooltip({bool persistent = false}) {
    if (widget.disabled) {
      return;
    }
    _tooltipTimer?.cancel();
    if (!_tooltipActive) {
      setState(() {
        _tooltipActive = true;
      });
    }
    if (!persistent) {
      _tooltipTimer = Timer(const Duration(milliseconds: 900), () {
        if (mounted && !_dragging) {
          setState(() {
            _tooltipActive = false;
          });
        }
      });
    }
  }

  void _hideTooltip() {
    _tooltipTimer?.cancel();
    if (_tooltipActive) {
      setState(() {
        _tooltipActive = false;
      });
    }
  }
}

class _VolumeSliderTooltip extends StatelessWidget {
  const _VolumeSliderTooltip({
    required this.value,
    required this.orientation,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final int value;
  final VolumeSliderOrientation orientation;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    final tooltip = DecoratedBox(
      key: const ValueKey('VolumeSlider.Tooltip'),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: const Color(0x33ffffff)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          '$value',
          style: TextStyle(
            color: foregroundColor,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
      ),
    );

    if (orientation == VolumeSliderOrientation.vertical) {
      return Positioned(right: -4, top: 8, child: tooltip);
    }
    return Positioned(top: -4, child: tooltip);
  }
}

class _CompactMediaControlLayout extends StatelessWidget {
  const _CompactMediaControlLayout({
    required this.narrow,
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
    this.playbackNoticeKey,
    this.currentLyricsLine,
    this.currentSong,
    this.onArtworkError,
    this.playlists = const [],
    this.preferenceLevel,
    this.onResolvePreferenceLevel,
    this.onAddToNowPlaying,
    this.onCreatePlaylist,
    this.onAddToPlaylist,
    this.onUndoPreference,
    this.onSetPreference,
    required this.onSeeArtist,
    required this.onSeeAlbum,
    required this.onSeeMusicInfo,
    required this.onSeeLyrics,
    required this.onSeeAlbumArt,
    required this.onSeeLocal,
  });

  final bool narrow;
  final MediaControlTrack track;
  final bool disabled;
  final bool isPlaying;
  final int volume;
  final bool isMuted;
  final PlaybackMode mode;
  final double progressSeconds;
  final double durationSeconds;
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
  final String? playbackNoticeKey;
  final String? currentLyricsLine;
  final LibrarySong? currentSong;
  final VoidCallback? onArtworkError;
  final List<LibraryPlaylist> playlists;
  final String? preferenceLevel;
  final FutureOr<String?> Function()? onResolvePreferenceLevel;
  final VoidCallback? onAddToNowPlaying;
  final VoidCallback? onCreatePlaylist;
  final ValueChanged<int>? onAddToPlaylist;
  final VoidCallback? onUndoPreference;
  final ValueChanged<String>? onSetPreference;
  final VoidCallback onSeeArtist;
  final VoidCallback onSeeAlbum;
  final VoidCallback onSeeMusicInfo;
  final VoidCallback onSeeLyrics;
  final VoidCallback onSeeAlbumArt;
  final VoidCallback onSeeLocal;

  @override
  Widget build(BuildContext context) {
    final i18n = _mediaControlI18n(context);
    final primarySize = narrow ? 48.0 : 52.0;
    final primaryPadding = narrow ? 12.0 : 13.0;
    final utilitySize = narrow ? 34.0 : 36.0;
    final utilityPadding = narrow ? 5.0 : 6.0;

    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: _PlayerTrack(
                  track: track,
                  artworkPath: resolvePlayerArtworkPath(track, currentSong),
                  playbackNoticeKey: playbackNoticeKey,
                  currentLyricsLine: currentLyricsLine,
                  onArtworkError: onArtworkError,
                  disabled: track.id == null,
                  compact: true,
                  onOpenNowPlaying: onOpenNowPlaying,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _PlayerIconButton(
                    tooltip: i18n.t('player.previous'),
                    icon: Icons.skip_previous_rounded,
                    disabled: disabled,
                    onPressed: onPrevious,
                  ),
                  const SizedBox(width: 16),
                  _PlayerIconButton(
                    key: const ValueKey('MediaControl.PlayPauseButton'),
                    tooltip:
                        isPlaying
                            ? i18n.t('player.pause')
                            : i18n.t('player.play'),
                    icon:
                        isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                    primary: true,
                    buttonSize: primarySize,
                    padding: primaryPadding,
                    iconSize: narrow ? 24 : 26,
                    loading: track.isLoading,
                    disabled: disabled,
                    onPressed: onTogglePlayPause,
                  ),
                  const SizedBox(width: 16),
                  _PlayerIconButton(
                    tooltip: i18n.t('player.next'),
                    icon: Icons.skip_next_rounded,
                    disabled: disabled,
                    onPressed: onNext,
                  ),
                ],
              ),
              SizedBox(
                width: 80,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (onOpenVoiceAssistant == null)
                      Builder(
                        builder: (modeButtonContext) {
                          return _PlayerIconButton(
                            key: const ValueKey(
                              'MediaControl.CompactModeButton',
                            ),
                            tooltip:
                                '${i18n.t('player.playbackMode')}: ${_playbackModeName(i18n, mode)}',
                            icon: _playbackModeIcon(mode),
                            buttonSize: utilitySize,
                            padding: utilityPadding,
                            iconSize: narrow ? 20 : 22,
                            active: mode != PlaybackMode.once,
                            disabled: disabled,
                            onPressed: () {
                              switch (getNextPlaybackMode(mode)) {
                                case PlaybackMode.shuffle:
                                  onToggleShuffle();
                                case PlaybackMode.repeat:
                                  onToggleRepeat();
                                case PlaybackMode.repeatOne:
                                  onToggleRepeatOne();
                                case PlaybackMode.once:
                                  if (mode == PlaybackMode.shuffle) {
                                    onToggleShuffle();
                                  } else if (mode == PlaybackMode.repeat) {
                                    onToggleRepeat();
                                  } else {
                                    onToggleRepeatOne();
                                  }
                              }
                            },
                            onLongPress: () {
                              _showCompactPlaybackModeMenu(
                                modeButtonContext,
                                i18n: i18n,
                                mode: mode,
                                onToggleShuffle: onToggleShuffle,
                                onToggleRepeat: onToggleRepeat,
                                onToggleRepeatOne: onToggleRepeatOne,
                              );
                            },
                          );
                        },
                      )
                    else
                      _PlayerIconButton(
                        tooltip: i18n.t('player.voiceAssistant'),
                        icon: Icons.mic_rounded,
                        buttonSize: utilitySize,
                        padding: utilityPadding,
                        iconSize: narrow ? 20 : 22,
                        disabled: false,
                        onPressed: onOpenVoiceAssistant!,
                      ),
                    _PlayerIconButton(
                      tooltip: i18n.t('player.more'),
                      icon: Icons.more_horiz_rounded,
                      buttonSize: utilitySize,
                      padding: utilityPadding,
                      iconSize: narrow ? 20 : 22,
                      onPressed: () {
                        _showCompactMoreMenu(
                          context,
                          i18n: i18n,
                          disabled: disabled,
                          trackId: track.id,
                          mode: mode,
                          isMuted: isMuted,
                          volumeValue: volume,
                          onQuickPlay: onQuickPlay,
                          onToggleMute: onToggleMute,
                          onToggleShuffle: onToggleShuffle,
                          onToggleRepeat: onToggleRepeat,
                          onToggleRepeatOne: onToggleRepeatOne,
                          onOpenNowPlaying: onOpenNowPlaying,
                          onToggleWindowFullScreen: onToggleWindowFullScreen,
                          isWindowFullScreen: isWindowFullScreen,
                          onEnterMiniMode: onEnterMiniMode,
                          currentSong: currentSong,
                          playlists: playlists,
                          preferenceLevel: preferenceLevel,
                          onResolvePreferenceLevel: onResolvePreferenceLevel,
                          onAddToNowPlaying: onAddToNowPlaying,
                          onCreatePlaylist: onCreatePlaylist,
                          onAddToPlaylist: onAddToPlaylist,
                          onUndoPreference: onUndoPreference,
                          onSetPreference: onSetPreference,
                          onSeeArtist: onSeeArtist,
                          onSeeAlbum: onSeeAlbum,
                          onSeeMusicInfo: onSeeMusicInfo,
                          onSeeLyrics: onSeeLyrics,
                          onSeeAlbumArt: onSeeAlbumArt,
                          onSeeLocal: onSeeLocal,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        _CompactMediaProgressRow(
          isLoading: track.isLoading,
          disabled: disabled,
          progressSeconds: progressSeconds,
          durationSeconds: durationSeconds,
          onSeek: onSeek,
          onBeginSeek: onBeginSeek,
          onEndSeek: onEndSeek,
        ),
      ],
    );
  }

  Future<void> _showCompactMoreMenu(
    BuildContext context, {
    required SmPlayerI18n i18n,
    required bool disabled,
    required int? trackId,
    required PlaybackMode mode,
    required bool isMuted,
    required int volumeValue,
    required VoidCallback onQuickPlay,
    required VoidCallback onToggleMute,
    required VoidCallback onToggleShuffle,
    required VoidCallback onToggleRepeat,
    required VoidCallback onToggleRepeatOne,
    required VoidCallback onOpenNowPlaying,
    required VoidCallback onToggleWindowFullScreen,
    required bool isWindowFullScreen,
    required VoidCallback onEnterMiniMode,
    LibrarySong? currentSong,
    List<LibraryPlaylist> playlists = const [],
    String? preferenceLevel,
    FutureOr<String?> Function()? onResolvePreferenceLevel,
    VoidCallback? onAddToNowPlaying,
    VoidCallback? onCreatePlaylist,
    ValueChanged<int>? onAddToPlaylist,
    VoidCallback? onUndoPreference,
    ValueChanged<String>? onSetPreference,
    required VoidCallback onSeeArtist,
    required VoidCallback onSeeAlbum,
    required VoidCallback onSeeMusicInfo,
    required VoidCallback onSeeLyrics,
    required VoidCallback onSeeAlbumArt,
    required VoidCallback onSeeLocal,
  }) async {
    final resolvedPreferenceLevel =
        await onResolvePreferenceLevel?.call() ?? preferenceLevel;
    if (!context.mounted) {
      return;
    }
    showMenuFlyout(
      context,
      items: _buildPlayerMoreMenuItems(
        i18n: i18n,
        disabled: disabled,
        trackId: trackId,
        mode: mode,
        isMuted: isMuted,
        volumeValue: volumeValue,
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
        isCompact: true,
        currentSong: currentSong,
        playlists: playlists,
        preferenceLevel: resolvedPreferenceLevel,
        onAddToNowPlaying: onAddToNowPlaying,
        onCreatePlaylist: onCreatePlaylist,
        onAddToPlaylist: onAddToPlaylist,
        onUndoPreference: onUndoPreference,
        onSetPreference: onSetPreference,
        onSeeArtist: onSeeArtist,
        onSeeAlbum: onSeeAlbum,
        onSeeMusicInfo: onSeeMusicInfo,
        onSeeLyrics: onSeeLyrics,
        onSeeAlbumArt: onSeeAlbumArt,
        onSeeLocal: onSeeLocal,
      ),
    );
  }

  void _showCompactPlaybackModeMenu(
    BuildContext context, {
    required SmPlayerI18n i18n,
    required PlaybackMode mode,
    required VoidCallback onToggleShuffle,
    required VoidCallback onToggleRepeat,
    required VoidCallback onToggleRepeatOne,
  }) {
    _showPlaybackModeMenu(
      context,
      i18n: i18n,
      mode: mode,
      onToggleShuffle: onToggleShuffle,
      onToggleRepeat: onToggleRepeat,
      onToggleRepeatOne: onToggleRepeatOne,
    );
  }
}

void _showPlaybackModeMenu(
  BuildContext context, {
  required SmPlayerI18n i18n,
  required PlaybackMode mode,
  required VoidCallback onToggleShuffle,
  required VoidCallback onToggleRepeat,
  required VoidCallback onToggleRepeatOne,
}) {
  showMenuFlyout(
    context,
    items: _buildPlaybackModeMenuItems(
      i18n: i18n,
      mode: mode,
      onToggleShuffle: onToggleShuffle,
      onToggleRepeat: onToggleRepeat,
      onToggleRepeatOne: onToggleRepeatOne,
    ),
  );
}

class _CompactMediaProgressRow extends StatefulWidget {
  const _CompactMediaProgressRow({
    required this.isLoading,
    required this.disabled,
    required this.progressSeconds,
    required this.durationSeconds,
    required this.onSeek,
    required this.onBeginSeek,
    required this.onEndSeek,
  });

  final bool isLoading;
  final bool disabled;
  final double progressSeconds;
  final double durationSeconds;
  final ValueChanged<double> onSeek;
  final VoidCallback onBeginSeek;
  final VoidCallback onEndSeek;

  @override
  State<_CompactMediaProgressRow> createState() =>
      _CompactMediaProgressRowState();
}

class _CompactMediaProgressRowState extends State<_CompactMediaProgressRow> {
  var _isProgressSeeking = false;
  var _draftProgressSeconds = 0.0;

  @override
  Widget build(BuildContext context) {
    final progressMax =
        widget.durationSeconds > 0 ? widget.durationSeconds : 0.0;
    final textMuted = MediaControlColors.textMutedFor(context);
    final displayProgressSeconds =
        _isProgressSeeking ? _draftProgressSeconds : widget.progressSeconds;
    final progressValue =
        widget.disabled || progressMax <= 0
            ? 0.0
            : displayProgressSeconds.clamp(0, progressMax).toDouble();

    return SizedBox(
      height: 28,
      child: Row(
        children: [
          SizedBox(
            width: 42,
            child: Text(
              formatDuration(progressValue),
              style: const TextStyle(fontSize: 12).copyWith(color: textMuted),
            ),
          ),
          Expanded(
            child:
                widget.isLoading
                    ? const _MediaProgressLoading()
                    : _MediaProgressSlider(
                      value: progressValue,
                      max: progressMax,
                      disabled: widget.disabled || widget.durationSeconds <= 0,
                      onChanged: (value) {
                        setState(() {
                          _draftProgressSeconds = value;
                        });
                      },
                      onChangeStart: (_) {
                        setState(() {
                          _isProgressSeeking = true;
                          _draftProgressSeconds = progressValue;
                        });
                        widget.onBeginSeek();
                      },
                      onChangeEnd: (value) {
                        if (!_isProgressSeeking) {
                          return;
                        }
                        widget.onSeek(value);
                        widget.onEndSeek();
                        setState(() {
                          _isProgressSeeking = false;
                        });
                      },
                    ),
          ),
          SizedBox(
            width: 42,
            child: Text(
              formatDuration(widget.durationSeconds),
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 12).copyWith(color: textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

List<MenuFlyoutItem> _buildPlaybackModeMenuItems({
  required SmPlayerI18n i18n,
  required PlaybackMode mode,
  required VoidCallback onToggleShuffle,
  required VoidCallback onToggleRepeat,
  required VoidCallback onToggleRepeatOne,
}) {
  return [
    MenuFlyoutItem(
      key: 'playback-mode-list',
      text: i18n.t('player.playbackModeList'),
      icon: Icons.queue_music_rounded,
      checked: mode == PlaybackMode.once,
      onPressed: () {
        _setPlaybackMode(
          currentMode: mode,
          targetMode: PlaybackMode.once,
          onToggleShuffle: onToggleShuffle,
          onToggleRepeat: onToggleRepeat,
          onToggleRepeatOne: onToggleRepeatOne,
        );
      },
    ),
    MenuFlyoutItem(
      key: 'playback-mode-shuffle',
      text: i18n.t('player.playbackModeShuffle'),
      icon: Icons.shuffle_rounded,
      checked: mode == PlaybackMode.shuffle,
      onPressed: () {
        _setPlaybackMode(
          currentMode: mode,
          targetMode: PlaybackMode.shuffle,
          onToggleShuffle: onToggleShuffle,
          onToggleRepeat: onToggleRepeat,
          onToggleRepeatOne: onToggleRepeatOne,
        );
      },
    ),
    MenuFlyoutItem(
      key: 'playback-mode-repeat',
      text: i18n.t('player.playbackModeRepeat'),
      icon: Icons.repeat_rounded,
      checked: mode == PlaybackMode.repeat,
      onPressed: () {
        _setPlaybackMode(
          currentMode: mode,
          targetMode: PlaybackMode.repeat,
          onToggleShuffle: onToggleShuffle,
          onToggleRepeat: onToggleRepeat,
          onToggleRepeatOne: onToggleRepeatOne,
        );
      },
    ),
    MenuFlyoutItem(
      key: 'playback-mode-repeat-one',
      text: i18n.t('player.playbackModeRepeatOne'),
      icon: Icons.repeat_one_rounded,
      checked: mode == PlaybackMode.repeatOne,
      onPressed: () {
        _setPlaybackMode(
          currentMode: mode,
          targetMode: PlaybackMode.repeatOne,
          onToggleShuffle: onToggleShuffle,
          onToggleRepeat: onToggleRepeat,
          onToggleRepeatOne: onToggleRepeatOne,
        );
      },
    ),
  ];
}

List<MenuFlyoutItem> _buildPlayerMoreMenuItems({
  required SmPlayerI18n i18n,
  required bool disabled,
  required int? trackId,
  required PlaybackMode mode,
  required bool isMuted,
  required int volumeValue,
  required VoidCallback onQuickPlay,
  required ValueChanged<int> onVolumeChange,
  required VoidCallback onToggleMute,
  required VoidCallback onToggleShuffle,
  required VoidCallback onToggleRepeat,
  required VoidCallback onToggleRepeatOne,
  required VoidCallback onToggleFavorite,
  required VoidCallback onOpenNowPlaying,
  required VoidCallback onToggleWindowFullScreen,
  required bool isWindowFullScreen,
  required VoidCallback onEnterMiniMode,
  bool isCompact = false,
  LibrarySong? currentSong,
  List<LibraryPlaylist> playlists = const [],
  String? preferenceLevel,
  VoidCallback? onAddToNowPlaying,
  VoidCallback? onCreatePlaylist,
  ValueChanged<int>? onAddToPlaylist,
  VoidCallback? onUndoPreference,
  ValueChanged<String>? onSetPreference,
  required VoidCallback onSeeArtist,
  required VoidCallback onSeeAlbum,
  required VoidCallback onSeeMusicInfo,
  required VoidCallback onSeeLyrics,
  required VoidCallback onSeeAlbumArt,
  required VoidCallback onSeeLocal,
}) {
  final items = [
    MenuFlyoutItem(
      key: 'quick',
      text: i18n.t('nowPlaying.quickPlay'),
      icon: Icons.play_arrow_rounded,
      onPressed: onQuickPlay,
    ),
    if (isCompact) ...[
      MenuFlyoutItem(
        key: 'playback-mode',
        text:
            '${i18n.t('player.playbackMode')}: ${_playbackModeName(i18n, mode)}',
        icon: _playbackModeIcon(mode),
        submenu: _buildPlaybackModeMenuItems(
          i18n: i18n,
          mode: mode,
          onToggleShuffle: onToggleShuffle,
          onToggleRepeat: onToggleRepeat,
          onToggleRepeatOne: onToggleRepeatOne,
        ),
      ),
      MenuFlyoutItem(
        key: 'player-volume',
        text: i18n.t('player.volume'),
        icon: playerVolumeIcon(volumeValue, isMuted),
        checked: isMuted,
        contentHeight: 52,
        content: _PlayerVolumeMenuItem(
          label: i18n.t('player.volume'),
          muted: isMuted,
          volumeValue: volumeValue,
          disabled: false,
          onToggleMute: onToggleMute,
          onVolumeChange: onVolumeChange,
        ),
      ),
      MenuFlyoutItem(
        key: 'player-favorite',
        text:
            currentSong?.favorite == true
                ? i18n.t('player.unlike')
                : i18n.t('player.like'),
        icon:
            currentSong?.favorite == true
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
        disabled: currentSong == null,
        onPressed: onToggleFavorite,
      ),
    ],
  ];

  if (currentSong == null) {
    return items;
  }

  final customPlaylists =
      playlists
          .where((playlist) => !playlist.isBuiltIn)
          .map(
            (playlist) => MultiSelectCommandBarPlaylist(
              id: playlist.id,
              name: playlist.name,
              songIds: playlist.songIds,
            ),
          )
          .toList();
  final addToItem = buildAddToPlaylistMenuFlyoutItem(
    i18n: i18n,
    songIds: [currentSong.id],
    playlists: customPlaylists,
    includeFavorites: !isCompact && !currentSong.favorite,
    onToggleFavorite: currentSong.favorite ? null : onToggleFavorite,
    onCreatePlaylist: onCreatePlaylist,
    onAddToPlaylist: onAddToPlaylist,
  );
  if (addToItem != null) {
    items.add(addToItem);
  }

  if (onSetPreference != null) {
    items.add(
      MenuFlyoutItem(
        key: 'preference',
        text: i18n.t('settings.preferenceSettings'),
        icon: Icons.star_border_rounded,
        submenu: [
          if (preferenceLevel != null && onUndoPreference != null) ...[
            MenuFlyoutItem(
              key: 'preference-undo',
              text: i18n.t('preferences.undoPrefer'),
              icon: Icons.undo_rounded,
              onPressed: onUndoPreference,
            ),
            const MenuFlyoutItem.separator(key: 'preference-undo-separator'),
          ],
          for (final level in const [
            'do-not-appear',
            'dislike',
            'normal',
            'high',
            'higher',
            'very-high',
          ])
            MenuFlyoutItem(
              key: 'preference-$level',
              text: i18n.t('preferences.level.$level'),
              checked: preferenceLevel == level,
              onPressed: () {
                onSetPreference(level);
              },
            ),
        ],
      ),
    );
  }

  items.addAll([
    MenuFlyoutItem(
      key: 'view',
      text: i18n.t('context.view'),
      icon: Icons.visibility_outlined,
      submenu: [
        MenuFlyoutItem(
          key: 'see-artist',
          text: i18n.t('context.seeArtist'),
          icon: Icons.groups_rounded,
          onPressed: onSeeArtist,
        ),
        MenuFlyoutItem(
          key: 'see-album',
          text: i18n.t('context.seeAlbum'),
          icon: Icons.album_rounded,
          onPressed: onSeeAlbum,
        ),
        MenuFlyoutItem(
          key: 'see-music-info',
          text: i18n.t('context.seeMusicInfo'),
          icon: Icons.info_outline_rounded,
          onPressed: onSeeMusicInfo,
        ),
        MenuFlyoutItem(
          key: 'see-lyrics',
          text: i18n.t('context.seeLyrics'),
          icon: Icons.lyrics_rounded,
          onPressed: onSeeLyrics,
        ),
        MenuFlyoutItem(
          key: 'see-album-art',
          text: i18n.t('context.seeAlbumArt'),
          icon: Icons.image_rounded,
          onPressed: onSeeAlbumArt,
        ),
        MenuFlyoutItem(
          key: 'see-local-file',
          text: i18n.t('context.seeLocalFile'),
          icon: Icons.folder_open_rounded,
          onPressed: onSeeLocal,
        ),
      ],
    ),
    MenuFlyoutItem(
      key: isWindowFullScreen ? 'exit-full-screen' : 'full-screen',
      text:
          isWindowFullScreen
              ? i18n.t('nowPlaying.exitFullScreenItem')
              : i18n.t('nowPlaying.fullScreen'),
      icon:
          isWindowFullScreen
              ? Icons.fullscreen_exit_rounded
              : Icons.fullscreen_rounded,
      onPressed: onToggleWindowFullScreen,
    ),
    MenuFlyoutItem(
      key: 'mini-mode',
      text: i18n.t('player.miniMode'),
      icon: Icons.picture_in_picture_alt_rounded,
      onPressed: onEnterMiniMode,
    ),
  ]);

  return items;
}

void _setPlaybackMode({
  required PlaybackMode currentMode,
  required PlaybackMode targetMode,
  required VoidCallback onToggleShuffle,
  required VoidCallback onToggleRepeat,
  required VoidCallback onToggleRepeatOne,
}) {
  if (currentMode == targetMode) {
    return;
  }

  switch (targetMode) {
    case PlaybackMode.shuffle:
      onToggleShuffle();
    case PlaybackMode.repeat:
      onToggleRepeat();
    case PlaybackMode.repeatOne:
      onToggleRepeatOne();
    case PlaybackMode.once:
      switch (currentMode) {
        case PlaybackMode.shuffle:
          onToggleShuffle();
        case PlaybackMode.repeat:
          onToggleRepeat();
        case PlaybackMode.repeatOne:
          onToggleRepeatOne();
        case PlaybackMode.once:
          return;
      }
  }
}

String _playbackModeName(SmPlayerI18n i18n, PlaybackMode mode) {
  return switch (mode) {
    PlaybackMode.once => i18n.t('player.playbackModeList'),
    PlaybackMode.shuffle => i18n.t('player.playbackModeShuffle'),
    PlaybackMode.repeat => i18n.t('player.playbackModeRepeat'),
    PlaybackMode.repeatOne => i18n.t('player.playbackModeRepeatOne'),
  };
}

SmPlayerI18n _mediaControlI18n(BuildContext context) {
  return context.maybeSmPlayerI18n ??
      const SmPlayerI18n(locale: smPlayerFallbackLocale, messages: {});
}

class _PlayerTrack extends StatefulWidget {
  const _PlayerTrack({
    required this.track,
    required this.artworkPath,
    required this.disabled,
    required this.onOpenNowPlaying,
    this.compact = false,
    this.playbackNoticeKey,
    this.currentLyricsLine,
    this.onArtworkError,
  });

  final MediaControlTrack track;
  final String? artworkPath;
  final bool disabled;
  final bool compact;
  final String? playbackNoticeKey;
  final String? currentLyricsLine;
  final VoidCallback? onArtworkError;
  final VoidCallback onOpenNowPlaying;

  @override
  State<_PlayerTrack> createState() => _PlayerTrackState();
}

class _PlayerTrackState extends State<_PlayerTrack> {
  var _hovered = false;
  var _focused = false;

  @override
  Widget build(BuildContext context) {
    final noticeKey = widget.playbackNoticeKey;
    final textStrong = MediaControlColors.textStrongFor(context);
    final textMuted = MediaControlColors.textMutedFor(context);
    final noticeText =
        noticeKey == null ? null : _mediaControlI18n(context).t(noticeKey);
    final lyricsText =
        noticeText == null && widget.currentLyricsLine?.isNotEmpty == true
            ? widget.currentLyricsLine
            : null;
    final overlayVisible = !widget.disabled && (_hovered || _focused);
    final trackCopyMaxWidth =
        widget.compact
            ? double.infinity
            : min(360.0, MediaQuery.sizeOf(context).width * 0.24);
    return MouseRegion(
      cursor:
          widget.disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
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
      child: Focus(
        onFocusChange: (focused) {
          setState(() {
            _focused = focused;
          });
        },
        child: TextButton(
          style: TextButton.styleFrom(
            foregroundColor: textStrong,
            disabledForegroundColor: textStrong,
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: widget.disabled ? null : widget.onOpenNowPlaying,
          child: Row(
            children: [
              Container(
                width: widget.compact ? 68 : 72,
                height: widget.compact ? 68 : 72,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: const [
                    BoxShadow(
                      color: MediaControlColors.artworkShadow,
                      offset: Offset(0, 10),
                      blurRadius: 24,
                    ),
                  ],
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _PlayerArtwork(
                      artworkPath: widget.artworkPath,
                      onError: widget.onArtworkError,
                    ),
                    AnimatedOpacity(
                      key: const ValueKey('MediaControl.ArtworkOverlay'),
                      duration: const Duration(milliseconds: 140),
                      opacity: overlayVisible ? 1 : 0,
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: const Color(
                              0xff0c1118,
                            ).withValues(alpha: 0.44),
                          ),
                          child: const Icon(
                            Icons.fullscreen_rounded,
                            color: Colors.white,
                            size: 36,
                            shadows: [
                              Shadow(
                                color: Color(0x57000000),
                                offset: Offset(0, 2),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Flexible(
                child: ConstrainedBox(
                  key: const ValueKey('MediaControl.TrackCopy'),
                  constraints: BoxConstraints(
                    minWidth: widget.compact ? 0 : 120,
                    maxWidth: trackCopyMaxWidth,
                  ),
                  child: SizedBox(
                    height: widget.compact ? 68 : 72,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: textStrong,
                            fontSize: widget.compact ? 15 : 17,
                            fontWeight: FontWeight.w600,
                            height: 1.08,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          widget.track.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: textMuted,
                            fontSize: widget.compact ? 12 : 14,
                            fontWeight: FontWeight.w600,
                            height: 1.1,
                          ),
                        ),
                        if (noticeText != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.info_outline_rounded,
                                size: 14,
                                color: MediaControlColors.accent,
                              ),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  noticeText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: MediaControlColors.accent,
                                    fontSize: widget.compact ? 11 : 12,
                                    fontWeight: FontWeight.w700,
                                    height: 1.1,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ] else if (lyricsText != null) ...[
                          const SizedBox(height: 4),
                          _PlayerTrackLyrics(
                            line: lyricsText,
                            compact: widget.compact,
                          ),
                        ],
                      ],
                    ),
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

class _PlayerTrackLyrics extends StatelessWidget {
  const _PlayerTrackLyrics({required this.line, required this.compact});

  final String line;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey('MediaControl.CurrentLyricsContainer'),
      height: 17,
      child: ClipRect(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
          switchInCurve: const Cubic(0.22, 1, 0.36, 1),
          switchOutCurve: Curves.easeOutCubic,
          transitionBuilder: (child, animation) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            );
          },
          child: Align(
            key: ValueKey(line),
            alignment: Alignment.centerLeft,
            child: Text(
              line,
              key: const ValueKey('MediaControl.CurrentLyricsLine'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: MediaControlColors.accent,
                fontSize: compact ? 11 : 13,
                fontWeight: FontWeight.w600,
                height: 1.0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayerUtilityRows extends StatelessWidget {
  const _PlayerUtilityRows({
    required this.trackId,
    required this.favorite,
    required this.disabled,
    required this.volumeValue,
    required this.isMuted,
    required this.mode,
    required this.onVolumeChange,
    required this.onToggleMute,
    required this.onToggleShuffle,
    required this.onToggleRepeat,
    required this.onToggleRepeatOne,
    required this.onToggleFavorite,
    this.onOpenVoiceAssistant,
    this.condensed = false,
    required this.onMoreClick,
  });

  final int? trackId;
  final bool favorite;
  final bool disabled;
  final int volumeValue;
  final bool isMuted;
  final PlaybackMode mode;
  final ValueChanged<int> onVolumeChange;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleShuffle;
  final VoidCallback onToggleRepeat;
  final VoidCallback onToggleRepeatOne;
  final VoidCallback onToggleFavorite;
  final VoidCallback? onOpenVoiceAssistant;
  final bool condensed;
  final VoidCallback onMoreClick;

  @override
  Widget build(BuildContext context) {
    final i18n = _mediaControlI18n(context);

    return SizedBox(
      width: condensed ? 132 : 280,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (condensed)
                _PlayerCompactVolumeAction(
                  tooltip:
                      isMuted ? i18n.t('player.unmute') : i18n.t('player.mute'),
                  icon: playerVolumeIcon(volumeValue, isMuted),
                  active: isMuted,
                  disabled: disabled,
                  volumeValue: volumeValue,
                  onVolumeChange: onVolumeChange,
                )
              else ...[
                _PlayerIconButton(
                  tooltip:
                      isMuted ? i18n.t('player.unmute') : i18n.t('player.mute'),
                  icon: playerVolumeIcon(volumeValue, isMuted),
                  active: isMuted,
                  disabled: disabled,
                  onPressed: onToggleMute,
                ),
                SizedBox(
                  width: 148,
                  child: VolumeSlider(
                    key: const ValueKey('MediaControl.WideVolumeSlider'),
                    value: volumeValue,
                    disabled: disabled,
                    onChange: onVolumeChange,
                  ),
                ),
              ],
              if (trackId != null)
                _PlayerIconButton(
                  tooltip:
                      favorite
                          ? i18n.t('player.unlike')
                          : i18n.t('player.like'),
                  icon:
                      favorite
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                  active: favorite,
                  disabled: disabled,
                  favorite: favorite,
                  onPressed: onToggleFavorite,
                ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (condensed)
                Builder(
                  builder: (modeButtonContext) {
                    return _PlayerIconButton(
                      key: const ValueKey('MediaControl.CompactModeButton'),
                      tooltip:
                          '${i18n.t('player.playbackMode')}: ${_playbackModeName(i18n, mode)}',
                      icon: _playbackModeIcon(mode),
                      active: mode != PlaybackMode.once,
                      disabled: disabled,
                      onPressed: () {
                        switch (getNextPlaybackMode(mode)) {
                          case PlaybackMode.shuffle:
                            onToggleShuffle();
                          case PlaybackMode.repeat:
                            onToggleRepeat();
                          case PlaybackMode.repeatOne:
                            onToggleRepeatOne();
                          case PlaybackMode.once:
                            if (mode == PlaybackMode.shuffle) {
                              onToggleShuffle();
                            } else if (mode == PlaybackMode.repeat) {
                              onToggleRepeat();
                            } else {
                              onToggleRepeatOne();
                            }
                        }
                      },
                      onLongPress: () {
                        _showPlaybackModeMenu(
                          modeButtonContext,
                          i18n: i18n,
                          mode: mode,
                          onToggleShuffle: onToggleShuffle,
                          onToggleRepeat: onToggleRepeat,
                          onToggleRepeatOne: onToggleRepeatOne,
                        );
                      },
                    );
                  },
                )
              else ...[
                _PlayerIconButton(
                  tooltip:
                      mode == PlaybackMode.shuffle
                          ? i18n.t('player.shuffleEnabled')
                          : i18n.t('player.shuffleDisabled'),
                  icon: Icons.shuffle_rounded,
                  active: mode == PlaybackMode.shuffle,
                  disabled: disabled,
                  onPressed: onToggleShuffle,
                ),
                const SizedBox(width: 14),
                _PlayerIconButton(
                  tooltip:
                      mode == PlaybackMode.repeat
                          ? i18n.t('player.repeatEnabled')
                          : i18n.t('player.repeatDisabled'),
                  icon: Icons.repeat_rounded,
                  active: mode == PlaybackMode.repeat,
                  disabled: disabled,
                  onPressed: onToggleRepeat,
                ),
                const SizedBox(width: 14),
                _PlayerIconButton(
                  tooltip:
                      mode == PlaybackMode.repeatOne
                          ? i18n.t('player.repeatOneEnabled')
                          : i18n.t('player.repeatOneDisabled'),
                  icon: Icons.repeat_one_rounded,
                  active: mode == PlaybackMode.repeatOne,
                  disabled: disabled,
                  onPressed: onToggleRepeatOne,
                ),
                const SizedBox(width: 14),
              ],
              if (onOpenVoiceAssistant != null) ...[
                _PlayerIconButton(
                  tooltip: i18n.t('player.voiceAssistant'),
                  icon: Icons.mic_rounded,
                  disabled: false,
                  onPressed: onOpenVoiceAssistant!,
                ),
                const SizedBox(width: 14),
              ],
              _PlayerIconButton(
                tooltip: i18n.t('player.more'),
                icon: Icons.more_horiz_rounded,
                onPressed: onMoreClick,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlayerCompactVolumeAction extends StatefulWidget {
  const _PlayerCompactVolumeAction({
    required this.tooltip,
    required this.icon,
    required this.active,
    required this.disabled,
    required this.volumeValue,
    required this.onVolumeChange,
  });

  final String tooltip;
  final IconData icon;
  final bool active;
  final bool disabled;
  final int volumeValue;
  final ValueChanged<int> onVolumeChange;

  @override
  State<_PlayerCompactVolumeAction> createState() =>
      _PlayerCompactVolumeActionState();
}

class _PlayerCompactVolumeActionState
    extends State<_PlayerCompactVolumeAction> {
  var _open = false;

  @override
  Widget build(BuildContext context) {
    return TapRegion(
      onTapOutside: (_) {
        if (_open) {
          setState(() {
            _open = false;
          });
        }
      },
      child: SizedBox(
        width: 36,
        height: 36,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            _PlayerIconButton(
              key: const ValueKey('MediaControl.CompactVolumeButton'),
              tooltip: widget.tooltip,
              icon: widget.icon,
              active: widget.active || _open,
              disabled: widget.disabled,
              onPressed: () {
                setState(() {
                  _open = !_open;
                });
              },
            ),
            if (_open)
              Positioned(
                key: const ValueKey('MediaControl.CompactVolumePopover'),
                right: -6,
                bottom: 44,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xf5ffffff),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0x1a323e4e)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x2e2a384e),
                        offset: Offset(0, 16),
                        blurRadius: 36,
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
                    child: VolumeSlider(
                      value: widget.volumeValue,
                      disabled: widget.disabled,
                      orientation: VolumeSliderOrientation.vertical,
                      showTooltipOnMount: true,
                      onChange: widget.onVolumeChange,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PlayerVolumeMenuItem extends StatefulWidget {
  const _PlayerVolumeMenuItem({
    required this.label,
    required this.muted,
    required this.volumeValue,
    required this.disabled,
    required this.onToggleMute,
    required this.onVolumeChange,
  });

  final String label;
  final bool muted;
  final int volumeValue;
  final bool disabled;
  final VoidCallback onToggleMute;
  final ValueChanged<int> onVolumeChange;

  @override
  State<_PlayerVolumeMenuItem> createState() => _PlayerVolumeMenuItemState();
}

class _PlayerVolumeMenuItemState extends State<_PlayerVolumeMenuItem> {
  late var _liveValue = widget.volumeValue;

  @override
  void didUpdateWidget(covariant _PlayerVolumeMenuItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.volumeValue != widget.volumeValue) {
      _liveValue = widget.volumeValue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const ValueKey('MediaControl.VolumeMenuItem'),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          _PlayerIconButton(
            tooltip: widget.label,
            icon: playerVolumeIcon(_liveValue, widget.muted),
            active: widget.muted,
            disabled: widget.disabled,
            onPressed: widget.onToggleMute,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: VolumeSlider(
              value: widget.volumeValue,
              disabled: widget.disabled,
              onChange: (value) {
                setState(() {
                  _liveValue = value;
                });
                widget.onVolumeChange(value);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaProgressSlider extends StatelessWidget {
  const _MediaProgressSlider({
    required this.value,
    required this.max,
    required this.disabled,
    required this.onChanged,
    required this.onChangeStart,
    required this.onChangeEnd,
  });

  final double value;
  final double max;
  final bool disabled;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeStart;
  final ValueChanged<double> onChangeEnd;

  @override
  Widget build(BuildContext context) {
    final inactiveTrackColor = MediaControlColors.sliderInactiveFor(context);
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 2,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
        activeTrackColor: MediaControlColors.accent,
        inactiveTrackColor: inactiveTrackColor,
        thumbColor: MediaControlColors.accent,
        overlayColor: MediaControlColors.accentHover,
      ),
      child: Slider(
        value: max > 0 ? value.clamp(0, max).toDouble() : 0,
        min: 0,
        max: max > 0 ? max : 1,
        onChanged: disabled ? null : onChanged,
        onChangeStart: disabled ? null : onChangeStart,
        onChangeEnd: disabled ? null : onChangeEnd,
      ),
    );
  }
}

class _MediaProgressLoading extends StatefulWidget {
  const _MediaProgressLoading();

  @override
  State<_MediaProgressLoading> createState() => _MediaProgressLoadingState();
}

class _MediaProgressLoadingState extends State<_MediaProgressLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inactiveTrackColor = MediaControlColors.sliderInactiveFor(context);
    return SizedBox(
      key: const ValueKey('MediaControl.ProgressLoading'),
      height: 18,
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 2,
            child: DecoratedBox(
              decoration: BoxDecoration(color: inactiveTrackColor),
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  return FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: 1,
                    child: CustomPaint(
                      painter: _MediaProgressLoadingPainter(_controller.value),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MediaProgressLoadingPainter extends CustomPainter {
  const _MediaProgressLoadingPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = MediaControlColors.accent;
    final segmentWidth = size.width * 0.35;
    final left = -segmentWidth + progress * (size.width + segmentWidth * 2);
    canvas.drawRect(Rect.fromLTWH(left, 0, segmentWidth, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant _MediaProgressLoadingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _PlayerIconButton extends StatefulWidget {
  const _PlayerIconButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.onLongPress,
    this.disabled = false,
    this.primary = false,
    this.active = false,
    this.favorite = false,
    this.loading = false,
    this.buttonSize,
    this.padding,
    this.iconSize,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final VoidCallback? onLongPress;
  final bool disabled;
  final bool primary;
  final bool active;
  final bool favorite;
  final bool loading;
  final double? buttonSize;
  final double? padding;
  final double? iconSize;

  @override
  State<_PlayerIconButton> createState() => _PlayerIconButtonState();
}

class _PlayerIconButtonState extends State<_PlayerIconButton> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final size = widget.buttonSize ?? (widget.primary ? 56.0 : 36.0);
    final padding = widget.padding ?? (widget.primary ? 14.0 : 6.0);
    final iconSize = widget.iconSize ?? (widget.primary ? 28.0 : 22.0);
    final textStrong = MediaControlColors.textStrongFor(context);
    final accentStrong = MediaControlColors.accentStrongFor(context);
    final accentHover = MediaControlColors.accentHoverFor(context);
    final color =
        widget.favorite
            ? MediaControlColors.favorite
            : widget.primary
            ? Colors.white
            : widget.active || _hovered
            ? accentStrong
            : textStrong;
    final background =
        widget.primary
            ? MediaControlColors.accent
            : widget.active || _hovered
            ? accentHover
            : Colors.transparent;

    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor:
            widget.disabled
                ? SystemMouseCursors.forbidden
                : SystemMouseCursors.click,
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
          behavior: HitTestBehavior.opaque,
          onTap: widget.disabled ? null : widget.onPressed,
          onLongPress: widget.disabled ? null : widget.onLongPress,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: size,
            height: size,
            padding: EdgeInsets.all(padding),
            decoration: BoxDecoration(
              color:
                  widget.disabled
                      ? background.withValues(alpha: 0.45)
                      : background,
              borderRadius: BorderRadius.circular(size / 2),
              border:
                  widget.primary
                      ? Border.all(color: MediaControlColors.accentBorder)
                      : null,
              boxShadow:
                  widget.primary
                      ? const [
                        BoxShadow(
                          color: MediaControlColors.accentShadow,
                          offset: Offset(0, 12),
                          blurRadius: 24,
                        ),
                      ]
                      : null,
            ),
            child:
                widget.loading
                    ? const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    )
                    : Icon(widget.icon, color: color, size: iconSize),
          ),
        ),
      ),
    );
  }
}

class _DefaultAlbumArtwork extends StatelessWidget {
  const _DefaultAlbumArtwork();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xff5b87b6), Color(0xff9ec5ff)],
        ),
      ),
      child: Icon(
        Icons.music_note_rounded,
        color: Colors.white.withValues(alpha: 0.82),
        size: 38,
      ),
    );
  }
}

class _PlayerArtwork extends StatelessWidget {
  const _PlayerArtwork({required this.artworkPath, this.onError});

  final String? artworkPath;
  final VoidCallback? onError;

  @override
  Widget build(BuildContext context) {
    final path = artworkPath;
    if (path != null && path.isNotEmpty) {
      final file = File(path);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) {
            onError?.call();
            return const _DefaultAlbumArtwork();
          },
        );
      }
    }

    return const _DefaultAlbumArtwork();
  }
}

IconData _playbackModeIcon(PlaybackMode mode) {
  return switch (mode) {
    PlaybackMode.shuffle => Icons.shuffle_rounded,
    PlaybackMode.repeat => Icons.repeat_rounded,
    PlaybackMode.repeatOne => Icons.repeat_one_rounded,
    PlaybackMode.once => Icons.queue_music_rounded,
  };
}

@visibleForTesting
Color selectPlayerArtworkAccentColorFromRgba(
  Uint8List rgbaPixels,
  int width,
  int height,
) {
  var selected = _defaultArtworkAccentColor;
  var selectedDistance = -1;
  for (var xIndex = 1; xIndex < _artworkColorGridDivisions; xIndex += 1) {
    for (var yIndex = 1; yIndex < _artworkColorGridDivisions; yIndex += 1) {
      final x = min(width - 1, (width * xIndex) ~/ _artworkColorGridDivisions);
      final y = min(
        height - 1,
        (height * yIndex) ~/ _artworkColorGridDivisions,
      );
      final offset = (y * width + x) * 4;
      final red = rgbaPixels[offset];
      final green = rgbaPixels[offset + 1];
      final blue = rgbaPixels[offset + 2];
      final alpha = rgbaPixels[offset + 3];

      if (alpha == 0 ||
          red < _artworkColorMinValue ||
          red > _artworkColorMaxValue ||
          green < _artworkColorMinValue ||
          green > _artworkColorMaxValue ||
          blue < _artworkColorMinValue ||
          blue > _artworkColorMaxValue) {
        continue;
      }

      final distance =
          pow(red - _artworkColorMinValue, 2) +
          pow(green - _artworkColorMinValue, 2) +
          pow(blue - _artworkColorMinValue, 2);
      if (distance > selectedDistance) {
        selected = Color.fromARGB(255, red, green, blue);
        selectedDistance = distance.toInt();
      }
    }
  }
  return selected;
}

Future<Color> extractPlayerArtworkAccentColor(String artworkPath) async {
  try {
    final bytes = await File(artworkPath).readAsBytes();
    final codec = await instantiateImageCodec(
      bytes,
    ).timeout(const Duration(seconds: 2));
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final width = image.width;
    final height = image.height;
    final byteData = await image.toByteData(format: ImageByteFormat.rawRgba);
    image.dispose();
    codec.dispose();
    if (byteData == null) {
      return _defaultArtworkAccentColor;
    }
    return selectPlayerArtworkAccentColorFromRgba(
      byteData.buffer.asUint8List(),
      width,
      height,
    );
  } on Object {
    return _defaultArtworkAccentColor;
  }
}

class MediaControlColors {
  const MediaControlColors._();

  static const textStrong = Color(0xff1f252b);
  static const textMuted = Color(0xff5f625f);
  static const nightText = Color(0xfff8fafc);
  static const nightMuted = Color(0xffcbd5e1);
  static const accent = Color(0xff0078d7);
  static const accentStrong = Color(0xff0063b1);
  static const accentHover = Color(0x1f0078d7);
  static const nightAccentStrong = Color(0xffffffff);
  static const nightAccentHover = Color(0x380078d7);
  static const accentBorder = Color(0x2e0078d7);
  static const accentShadow = Color(0x330078d7);
  static const favorite = Color(0xffd83b7d);
  static const playerSurface = Color(0xe0ffffff);
  static const playerAccentWash = Color(0x1a0078d7);
  static const playerSurfaceSolid = Color(0xd1ffffff);
  static const playerBorder = Color(0xa8ffffff);
  static const nightPlayerHighlight = Color(0x0effffff);
  static const nightPlayerSurface = Color(0xe611161c);
  static const nightPlayerBorder = Color(0x3dffffff);
  static const playerShadow = Color(0x382a384e);
  static const nightPlayerShadow = Color(0x57000000);
  static const artworkShadow = Color(0x382a384e);
  static const sliderInactive = Color(0x2e323e4e);
  static const nightSliderInactive = Color(0x2ecbd5e1);
  static const buttonSurface = Color(0xb8ffffff);

  static bool isNight(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color textStrongFor(BuildContext context) =>
      isNight(context) ? nightText : textStrong;

  static Color textMutedFor(BuildContext context) =>
      isNight(context) ? nightMuted : textMuted;

  static Color accentStrongFor(BuildContext context) =>
      isNight(context) ? nightAccentStrong : accentStrong;

  static Color accentHoverFor(BuildContext context) =>
      isNight(context) ? nightAccentHover : accentHover;

  static Color sliderInactiveFor(BuildContext context) =>
      isNight(context) ? nightSliderInactive : sliderInactive;

  static Color playerBorderFor(bool night) =>
      night ? nightPlayerBorder : playerBorder;

  static Color playerShadowFor(bool night) =>
      night ? nightPlayerShadow : playerShadow;
}
