import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/ui/command_bar.dart';
import 'package:smplayer_flutter/src/playback/media_control_model.dart';

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
    required this.onEnterMiniMode,
    this.currentSong,
    this.playlists = const [],
    this.preferenceLevel,
    this.onAddToNowPlaying,
    this.onCreatePlaylist,
    this.onAddToPlaylist,
    this.onUndoPreference,
    this.onSetPreference,
    this.onSeeAlbum,
    this.onSeeMusicInfo,
    this.onSeeLyrics,
    this.onSeeAlbumArt,
    this.onSeeLocal,
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
  final VoidCallback onEnterMiniMode;
  final String? preferenceLevel;
  final VoidCallback? onAddToNowPlaying;
  final VoidCallback? onCreatePlaylist;
  final ValueChanged<int>? onAddToPlaylist;
  final VoidCallback? onUndoPreference;
  final ValueChanged<String>? onSetPreference;
  final VoidCallback? onSeeAlbum;
  final VoidCallback? onSeeMusicInfo;
  final VoidCallback? onSeeLyrics;
  final VoidCallback? onSeeAlbumArt;
  final VoidCallback? onSeeLocal;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: MediaControlColors.playerBorder),
                left: BorderSide(color: MediaControlColors.playerBorder),
                right: BorderSide(color: MediaControlColors.playerBorder),
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  MediaControlColors.playerSurface,
                  MediaControlColors.playerAccentWash,
                  MediaControlColors.playerSurfaceSolid,
                ],
                stops: [0, 0.52, 1],
              ),
              boxShadow: [
                BoxShadow(
                  color: MediaControlColors.playerShadow,
                  offset: Offset(0, -18),
                  blurRadius: 48,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth <= 720;

                  if (compact) {
                    return _CompactMediaControlLayout(
                      track: track,
                      disabled: disabled,
                      isPlaying: isPlaying,
                      volume: volume,
                      isMuted: isMuted,
                      mode: mode,
                      progressSeconds: progressSeconds,
                      durationSeconds: durationSeconds,
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
                      onEnterMiniMode: onEnterMiniMode,
                    );
                  }

                  return Row(
                    children: [
                      Expanded(
                        flex: 9,
                        child: _PlayerTrack(
                          track: track,
                          artworkPath:
                              currentSong?.thumbnailPath ?? track.artworkUrl,
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
                          volume: volume,
                          isMuted: isMuted,
                          mode: mode,
                          progressSeconds: progressSeconds,
                          durationSeconds: durationSeconds,
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
                            volumeValue: disabled ? 0 : volume,
                            isMuted: isMuted,
                            mode: mode,
                            onVolumeChange: onVolumeChange,
                            onToggleMute: onToggleMute,
                            onToggleShuffle: onToggleShuffle,
                            onToggleRepeat: onToggleRepeat,
                            onToggleRepeatOne: onToggleRepeatOne,
                            onToggleFavorite: onToggleFavorite,
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
  }) {
    return showMenuFlyout(
      context,
      items: _buildPlayerMoreMenuItems(
        i18n: i18n,
        disabled: disabled,
        trackId: track.id,
        mode: mode,
        isMuted: isMuted,
        onQuickPlay: onQuickPlay,
        onToggleMute: onToggleMute,
        onToggleShuffle: onToggleShuffle,
        onToggleRepeat: onToggleRepeat,
        onToggleRepeatOne: onToggleRepeatOne,
        onToggleFavorite: onToggleFavorite,
        onOpenNowPlaying: onOpenNowPlaying,
        onToggleWindowFullScreen: onToggleWindowFullScreen,
        onEnterMiniMode: onEnterMiniMode,
        currentSong: currentSong,
        playlists: playlists,
        preferenceLevel: preferenceLevel,
        onAddToNowPlaying: onAddToNowPlaying,
        onCreatePlaylist: onCreatePlaylist,
        onAddToPlaylist: onAddToPlaylist,
        onUndoPreference: onUndoPreference,
        onSetPreference: onSetPreference,
        onSeeAlbum: onSeeAlbum ?? onOpenNowPlaying,
        onSeeMusicInfo: onSeeMusicInfo ?? onOpenNowPlaying,
        onSeeLyrics: onSeeLyrics ?? onOpenNowPlaying,
        onSeeAlbumArt: onSeeAlbumArt ?? onOpenNowPlaying,
        onSeeLocal: onSeeLocal ?? onOpenNowPlaying,
      ),
    );
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
      volumeValue: widget.disabled ? 0 : widget.volume,
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
  final bool isMuted;
  final VoidCallback onMoreClick;

  @override
  Widget build(BuildContext context) {
    final i18n = _mediaControlI18n(context);
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
                    color: MediaControlColors.textMuted,
                    fontSize: 13,
                  ),
                ),
              ),
              Expanded(
                child: _MediaProgressSlider(
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
                    color: MediaControlColors.textMuted,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class VolumeSlider extends StatefulWidget {
  const VolumeSlider({
    super.key,
    required this.value,
    required this.disabled,
    required this.onChange,
  });

  final int value;
  final bool disabled;
  final ValueChanged<int> onChange;

  @override
  State<VolumeSlider> createState() => _VolumeSliderState();
}

class _VolumeSliderState extends State<VolumeSlider> {
  late var _liveValue = widget.value.toDouble();

  @override
  void didUpdateWidget(covariant VolumeSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _liveValue = widget.value.toDouble();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 2,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
        activeTrackColor: MediaControlColors.accent,
        inactiveTrackColor: MediaControlColors.sliderInactive,
        thumbColor: MediaControlColors.accent,
        overlayColor: MediaControlColors.accentHover,
      ),
      child: Slider(
        value: widget.disabled ? 0 : _liveValue.clamp(0, 100).toDouble(),
        min: 0,
        max: 100,
        onChanged:
            widget.disabled
                ? null
                : (value) {
                  setState(() {
                    _liveValue = value;
                  });
                  widget.onChange(value.round());
                },
      ),
    );
  }
}

class _CompactMediaControlLayout extends StatelessWidget {
  const _CompactMediaControlLayout({
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
    required this.onEnterMiniMode,
  });

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
  final VoidCallback onEnterMiniMode;

  @override
  Widget build(BuildContext context) {
    final i18n = _mediaControlI18n(context);

    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: _PlayerTrack(
                  track: track,
                  artworkPath: track.artworkUrl,
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
                    tooltip:
                        isPlaying
                            ? i18n.t('player.pause')
                            : i18n.t('player.play'),
                    icon:
                        isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                    primary: true,
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
                    _PlayerIconButton(
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
                    ),
                    _PlayerIconButton(
                      tooltip: i18n.t('player.more'),
                      icon: Icons.more_horiz_rounded,
                      onPressed: () {
                        _showCompactMoreMenu(
                          context,
                          i18n: i18n,
                          disabled: disabled,
                          trackId: track.id,
                          mode: mode,
                          isMuted: isMuted,
                          onQuickPlay: onQuickPlay,
                          onToggleMute: onToggleMute,
                          onToggleShuffle: onToggleShuffle,
                          onToggleRepeat: onToggleRepeat,
                          onToggleRepeatOne: onToggleRepeatOne,
                          onOpenNowPlaying: onOpenNowPlaying,
                          onToggleWindowFullScreen: onToggleWindowFullScreen,
                          onEnterMiniMode: onEnterMiniMode,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 28,
          child: Row(
            children: [
              SizedBox(
                width: 42,
                child: Text(
                  formatDuration(progressSeconds),
                  style: const TextStyle(
                    color: MediaControlColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ),
              Expanded(
                child: _MediaProgressSlider(
                  value: progressSeconds,
                  max: durationSeconds,
                  disabled: disabled || durationSeconds <= 0,
                  onChanged: onSeek,
                  onChangeStart: (_) {
                    onBeginSeek();
                  },
                  onChangeEnd: (value) {
                    onSeek(value);
                    onEndSeek();
                  },
                ),
              ),
              SizedBox(
                width: 42,
                child: Text(
                  formatDuration(durationSeconds),
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    color: MediaControlColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showCompactMoreMenu(
    BuildContext context, {
    required SmPlayerI18n i18n,
    required bool disabled,
    required int? trackId,
    required PlaybackMode mode,
    required bool isMuted,
    required VoidCallback onQuickPlay,
    required VoidCallback onToggleMute,
    required VoidCallback onToggleShuffle,
    required VoidCallback onToggleRepeat,
    required VoidCallback onToggleRepeatOne,
    required VoidCallback onOpenNowPlaying,
    required VoidCallback onToggleWindowFullScreen,
    required VoidCallback onEnterMiniMode,
  }) {
    showMenuFlyout(
      context,
      items: _buildPlayerMoreMenuItems(
        i18n: i18n,
        disabled: disabled,
        trackId: trackId,
        mode: mode,
        isMuted: isMuted,
        onQuickPlay: onQuickPlay,
        onToggleMute: onToggleMute,
        onToggleShuffle: onToggleShuffle,
        onToggleRepeat: onToggleRepeat,
        onToggleRepeatOne: onToggleRepeatOne,
        onToggleFavorite: onToggleFavorite,
        onOpenNowPlaying: onOpenNowPlaying,
        onToggleWindowFullScreen: onToggleWindowFullScreen,
        onEnterMiniMode: onEnterMiniMode,
        onSeeAlbum: onOpenNowPlaying,
        onSeeMusicInfo: onOpenNowPlaying,
        onSeeLyrics: onOpenNowPlaying,
        onSeeAlbumArt: onOpenNowPlaying,
        onSeeLocal: onOpenNowPlaying,
      ),
    );
  }
}

List<MenuFlyoutItem> _buildPlayerMoreMenuItems({
  required SmPlayerI18n i18n,
  required bool disabled,
  required int? trackId,
  required PlaybackMode mode,
  required bool isMuted,
  required VoidCallback onQuickPlay,
  required VoidCallback onToggleMute,
  required VoidCallback onToggleShuffle,
  required VoidCallback onToggleRepeat,
  required VoidCallback onToggleRepeatOne,
  required VoidCallback onToggleFavorite,
  required VoidCallback onOpenNowPlaying,
  required VoidCallback onToggleWindowFullScreen,
  required VoidCallback onEnterMiniMode,
  LibrarySong? currentSong,
  List<LibraryPlaylist> playlists = const [],
  String? preferenceLevel,
  VoidCallback? onAddToNowPlaying,
  VoidCallback? onCreatePlaylist,
  ValueChanged<int>? onAddToPlaylist,
  VoidCallback? onUndoPreference,
  ValueChanged<String>? onSetPreference,
  required VoidCallback onSeeAlbum,
  required VoidCallback onSeeMusicInfo,
  required VoidCallback onSeeLyrics,
  required VoidCallback onSeeAlbumArt,
  required VoidCallback onSeeLocal,
}) {
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
  final addToItem =
      currentSong == null
          ? null
          : buildAddToPlaylistMenuFlyoutItem(
            i18n: i18n,
            songIds: [currentSong.id],
            playlists: customPlaylists,
            includeFavorites: !currentSong.favorite,
            onToggleFavorite: currentSong.favorite ? null : onToggleFavorite,
            onCreatePlaylist: onCreatePlaylist,
            onAddToPlaylist: onAddToPlaylist,
          );

  return [
    MenuFlyoutItem(
      key: 'quick',
      text: i18n.t('nowPlaying.quickPlay'),
      icon: Icons.play_arrow_rounded,
      onPressed: onQuickPlay,
    ),
    if (addToItem != null) addToItem,
    MenuFlyoutItem(
      key: 'playback-mode',
      text:
          '${i18n.t('player.playbackMode')}: ${_playbackModeName(i18n, mode)}',
      icon: _playbackModeIcon(mode),
      disabled: disabled,
      submenu: [
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
          onPressed: onToggleShuffle,
        ),
        MenuFlyoutItem(
          key: 'playback-mode-repeat',
          text: i18n.t('player.playbackModeRepeat'),
          icon: Icons.repeat_rounded,
          checked: mode == PlaybackMode.repeat,
          onPressed: onToggleRepeat,
        ),
        MenuFlyoutItem(
          key: 'playback-mode-repeat-one',
          text: i18n.t('player.playbackModeRepeatOne'),
          icon: Icons.repeat_one_rounded,
          checked: mode == PlaybackMode.repeatOne,
          onPressed: onToggleRepeatOne,
        ),
      ],
    ),
    MenuFlyoutItem(
      key: 'player-volume',
      text: isMuted ? i18n.t('player.unmute') : i18n.t('player.mute'),
      icon: isMuted ? Icons.volume_up_rounded : Icons.volume_off_rounded,
      disabled: disabled,
      checked: isMuted,
      onPressed: onToggleMute,
    ),
    if (currentSong != null && onSetPreference != null)
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
    MenuFlyoutItem(
      key: 'see-album',
      text: i18n.t('context.seeAlbum'),
      icon: Icons.album_rounded,
      disabled: trackId == null,
      onPressed: onSeeAlbum,
    ),
    MenuFlyoutItem(
      key: 'see-music-info',
      text: i18n.t('context.seeMusicInfo'),
      icon: Icons.info_outline_rounded,
      disabled: trackId == null,
      onPressed: onSeeMusicInfo,
    ),
    MenuFlyoutItem(
      key: 'see-lyrics',
      text: i18n.t('context.seeLyrics'),
      icon: Icons.lyrics_rounded,
      disabled: trackId == null,
      onPressed: onSeeLyrics,
    ),
    MenuFlyoutItem(
      key: 'see-album-art',
      text: i18n.t('context.seeAlbumArt'),
      icon: Icons.image_rounded,
      disabled: trackId == null,
      onPressed: onSeeAlbumArt,
    ),
    MenuFlyoutItem(
      key: 'see-local-file',
      text: i18n.t('context.seeLocalFile'),
      icon: Icons.folder_open_rounded,
      disabled: trackId == null,
      onPressed: onSeeLocal,
    ),
    MenuFlyoutItem(
      key: 'now-playing',
      text: i18n.t('common.nowPlaying'),
      icon: Icons.queue_music_rounded,
      disabled: trackId == null,
      onPressed: onOpenNowPlaying,
    ),
    MenuFlyoutItem(
      key: 'full-screen',
      text: i18n.t('nowPlaying.fullScreen'),
      icon: Icons.fullscreen_rounded,
      onPressed: onToggleWindowFullScreen,
    ),
    MenuFlyoutItem(
      key: 'mini-mode',
      text: i18n.t('player.enterMiniMode'),
      icon: Icons.picture_in_picture_alt_rounded,
      onPressed: onEnterMiniMode,
    ),
  ];
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

class _PlayerTrack extends StatelessWidget {
  const _PlayerTrack({
    required this.track,
    required this.artworkPath,
    required this.disabled,
    required this.onOpenNowPlaying,
    this.compact = false,
  });

  final MediaControlTrack track;
  final String? artworkPath;
  final bool disabled;
  final bool compact;
  final VoidCallback onOpenNowPlaying;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: TextButton.styleFrom(
        foregroundColor: MediaControlColors.textStrong,
        disabledForegroundColor: MediaControlColors.textStrong,
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      onPressed: disabled ? null : onOpenNowPlaying,
      child: Row(
        children: [
          Container(
            width: compact ? 68 : 72,
            height: compact ? 68 : 72,
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
            child: _PlayerArtwork(artworkPath: artworkPath),
          ),
          const SizedBox(width: 14),
          Flexible(
            child: SizedBox(
              height: compact ? 68 : 72,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: MediaControlColors.textStrong,
                      fontSize: compact ? 15 : 17,
                      fontWeight: FontWeight.w600,
                      height: 1.08,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    track.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: MediaControlColors.textMuted,
                      fontSize: compact ? 12 : 14,
                      fontWeight: FontWeight.w600,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
  final VoidCallback onMoreClick;

  @override
  Widget build(BuildContext context) {
    final i18n = _mediaControlI18n(context);

    return SizedBox(
      width: 280,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _PlayerIconButton(
                tooltip:
                    isMuted ? i18n.t('player.unmute') : i18n.t('player.mute'),
                icon:
                    isMuted || volumeValue == 0
                        ? Icons.volume_off_rounded
                        : Icons.volume_up_rounded,
                active: isMuted,
                disabled: disabled,
                onPressed: onToggleMute,
              ),
              SizedBox(
                width: 148,
                child: VolumeSlider(
                  value: volumeValue,
                  disabled: disabled,
                  onChange: onVolumeChange,
                ),
              ),
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
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 2,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
        activeTrackColor: MediaControlColors.accent,
        inactiveTrackColor: MediaControlColors.sliderInactive,
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

class _PlayerIconButton extends StatefulWidget {
  const _PlayerIconButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.disabled = false,
    this.primary = false,
    this.active = false,
    this.favorite = false,
    this.loading = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final bool disabled;
  final bool primary;
  final bool active;
  final bool favorite;
  final bool loading;

  @override
  State<_PlayerIconButton> createState() => _PlayerIconButtonState();
}

class _PlayerIconButtonState extends State<_PlayerIconButton> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final size = widget.primary ? 56.0 : 36.0;
    final color =
        widget.favorite
            ? MediaControlColors.favorite
            : widget.primary
            ? Colors.white
            : widget.active || _hovered
            ? MediaControlColors.accentStrong
            : MediaControlColors.textStrong;
    final background =
        widget.primary
            ? MediaControlColors.accent
            : widget.active || _hovered
            ? MediaControlColors.accentHover
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
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: size,
            height: size,
            padding: EdgeInsets.all(widget.primary ? 14 : 6),
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
                    : Icon(
                      widget.icon,
                      color: color,
                      size: widget.primary ? 28 : 22,
                    ),
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
  const _PlayerArtwork({required this.artworkPath});

  final String? artworkPath;

  @override
  Widget build(BuildContext context) {
    final path = artworkPath;
    if (path != null && path.isNotEmpty) {
      final file = File(path);
      if (file.existsSync()) {
        return Image.file(file, fit: BoxFit.cover);
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

class MediaControlColors {
  const MediaControlColors._();

  static const textStrong = Color(0xff1f252b);
  static const textMuted = Color(0xff5f625f);
  static const accent = Color(0xff0078d7);
  static const accentStrong = Color(0xff0063b1);
  static const accentHover = Color(0x1f0078d7);
  static const accentBorder = Color(0x2e0078d7);
  static const accentShadow = Color(0x330078d7);
  static const favorite = Color(0xffd83b7d);
  static const playerSurface = Color(0xe0ffffff);
  static const playerAccentWash = Color(0x1a0078d7);
  static const playerSurfaceSolid = Color(0xd1ffffff);
  static const playerBorder = Color(0xa8ffffff);
  static const playerShadow = Color(0x382a384e);
  static const artworkShadow = Color(0x382a384e);
  static const sliderInactive = Color(0x2e323e4e);
  static const buttonSurface = Color(0xb8ffffff);
}
