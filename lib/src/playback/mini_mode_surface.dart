import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:smplayer_flutter/src/app/shell_widgets.dart';
import 'package:smplayer_flutter/src/app/smplayer_vector_icons.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_repository.dart';
import 'package:smplayer_flutter/src/library/ui/default_album_artwork.dart';
import 'package:smplayer_flutter/src/library/ui/song_artwork.dart';
import 'package:smplayer_flutter/src/lyrics/lyric_text_resolver.dart';
import 'package:smplayer_flutter/src/playback/media_control.dart';
import 'package:smplayer_flutter/src/playback/hold_release_action.dart';
import 'package:smplayer_flutter/src/playback/media_control_model.dart';
import 'package:smplayer_flutter/src/settings/settings_model.dart';

class MiniModeSurface extends StatefulWidget {
  const MiniModeSurface({
    super.key,
    required this.state,
    required this.i18n,
    required this.currentSong,
    required this.repository,
    required this.playerLyricsSource,
    required this.previousButtonRestartsTrack,
    required this.onExit,
    required this.onTogglePlayPause,
    required this.onPrevious,
    required this.onForcePrevious,
    required this.onNext,
    required this.onSeek,
    required this.onBeginSeek,
    required this.onEndSeek,
    required this.onToggleFavorite,
    required this.onQuickPlay,
    required this.onCycleRepeatMode,
    required this.onToggleMute,
    required this.onVolumeChange,
    required this.onOpenVoiceAssistant,
    required this.onWindowDragStart,
    required this.onWindowDragEnd,
  });

  final MediaControlState state;
  final SmPlayerI18n i18n;
  final LibrarySong? currentSong;
  final LibraryRepository repository;
  final LyricsRequestMode playerLyricsSource;
  final bool previousButtonRestartsTrack;
  final VoidCallback onExit;
  final VoidCallback onTogglePlayPause;
  final VoidCallback onPrevious;
  final VoidCallback onForcePrevious;
  final VoidCallback onNext;
  final ValueChanged<double> onSeek;
  final VoidCallback onBeginSeek;
  final VoidCallback onEndSeek;
  final VoidCallback onToggleFavorite;
  final VoidCallback onQuickPlay;
  final VoidCallback onCycleRepeatMode;
  final VoidCallback onToggleMute;
  final ValueChanged<int> onVolumeChange;
  final VoidCallback? onOpenVoiceAssistant;
  final VoidCallback? onWindowDragStart;
  final VoidCallback? onWindowDragEnd;

  @override
  State<MiniModeSurface> createState() => _MiniModeSurfaceState();
}

class _MiniModeSurfaceState extends State<MiniModeSurface> {
  Timer? _controlsHideTimer;
  var _controlsVisible = false;
  var _volumeOpen = false;
  var _isProgressSeeking = false;
  var _draftProgressSeconds = 0.0;

  @override
  void dispose() {
    _controlsHideTimer?.cancel();
    super.dispose();
  }

  void _showControls([PointerEvent? _]) {
    _controlsHideTimer?.cancel();
    if (!_controlsVisible) {
      setState(() {
        _controlsVisible = true;
      });
    }
  }

  void _scheduleControlsHide([PointerEvent? _]) {
    _controlsHideTimer?.cancel();
    _controlsHideTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted) {
        return;
      }
      if (_volumeOpen || _isProgressSeeking) {
        _showControls();
        return;
      }
      setState(() {
        _controlsVisible = false;
        _volumeOpen = false;
      });
    });
  }

  Widget _visibleControls(Widget child, {Key? key}) {
    return IgnorePointer(
      ignoring: !_controlsVisible,
      child: AnimatedOpacity(
        key: key,
        opacity: _controlsVisible ? 1 : 0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final i18n = widget.i18n;
    final currentSong = widget.currentSong;
    final repository = widget.repository;
    final playerLyricsSource = widget.playerLyricsSource;
    final onExit = widget.onExit;
    final onTogglePlayPause = widget.onTogglePlayPause;
    final onPrevious = widget.onPrevious;
    final onNext = widget.onNext;
    final onSeek = widget.onSeek;
    final onBeginSeek = widget.onBeginSeek;
    final onEndSeek = widget.onEndSeek;
    final onToggleFavorite = widget.onToggleFavorite;
    final onQuickPlay = widget.onQuickPlay;
    final onCycleRepeatMode = widget.onCycleRepeatMode;
    final onVolumeChange = widget.onVolumeChange;
    final onOpenVoiceAssistant = widget.onOpenVoiceAssistant;
    final artworkPath = currentSong?.thumbnailPath ?? state.track.artworkUrl;
    final title =
        state.track.title.isEmpty
            ? i18n.t('app.chooseSong')
            : state.track.title;
    final artist =
        state.track.artist.isEmpty
            ? i18n.t('common.artistUnknown')
            : state.track.artist;
    final noticeKey = state.playbackNoticeKey;
    final noticeText = noticeKey == null ? null : i18n.t(noticeKey);
    final duration = state.durationSeconds <= 0 ? 1.0 : state.durationSeconds;
    final displayProgressSeconds =
        _isProgressSeeking ? _draftProgressSeconds : state.progressSeconds;
    final progress = displayProgressSeconds.clamp(0, duration).toDouble();

    return MouseRegion(
      onEnter: _showControls,
      onHover: _showControls,
      onExit: _scheduleControlsHide,
      child: Focus(
        onFocusChange: (focused) {
          if (focused) {
            _showControls();
          }
        },
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xff28394f), Color(0xff162130)],
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _MiniModeArtwork(path: artworkPath),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(
                    alpha: _controlsVisible ? 0.54 : 0,
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: 48,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: ShellWindowDragRegion(
                                onWindowDragStart: widget.onWindowDragStart,
                                onWindowDragEnd: widget.onWindowDragEnd,
                                child: const SizedBox.expand(),
                              ),
                            ),
                            _visibleControls(
                              Row(
                                children: [
                                  IconButton(
                                    tooltip: i18n.t('player.exitMiniMode'),
                                    onPressed: onExit,
                                    color: Colors.white,
                                    icon: const Icon(Icons.arrow_back_rounded),
                                  ),
                                  const Spacer(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      _visibleControls(
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xd9ffffff),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (noticeText != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                noticeText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xff8bc8ff),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                            _MiniModeLyricLine(
                              song: currentSong,
                              repository: repository,
                              playerLyricsSource: playerLyricsSource,
                              progressSeconds: state.progressSeconds,
                              durationSeconds: state.durationSeconds,
                            ),
                          ],
                        ),
                        key: const ValueKey('MiniMode.TrackCopyOpacity'),
                      ),
                      const SizedBox(height: 18),
                      _visibleControls(
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _MiniModeButton(
                              tooltip:
                                  widget.previousButtonRestartsTrack
                                      ? i18n.t(
                                        'player.restartCurrentTrackHoldPrevious',
                                      )
                                      : i18n.t('player.previous'),
                              longPressTooltip: i18n.t('player.forcePrevious'),
                              icon: Icons.skip_previous_rounded,
                              disabled: state.disabled,
                              onPressed: onPrevious,
                              onLongPress:
                                  widget.previousButtonRestartsTrack
                                      ? widget.onForcePrevious
                                      : null,
                            ),
                            const SizedBox(width: 12),
                            _MiniModeButton(
                              primary: true,
                              tooltip:
                                  state.isPlaying
                                      ? i18n.t('player.pause')
                                      : i18n.t('player.play'),
                              icon:
                                  state.isPlaying
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                              loading: state.track.isLoading,
                              disabled: state.disabled,
                              onPressed: onTogglePlayPause,
                            ),
                            const SizedBox(width: 12),
                            _MiniModeButton(
                              tooltip: i18n.t('player.next'),
                              icon: Icons.skip_next_rounded,
                              disabled: state.disabled,
                              onPressed: onNext,
                            ),
                          ],
                        ),
                      ),
                      _visibleControls(
                        Column(
                          children: [
                            const SizedBox(height: 18),
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 3,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 5,
                                ),
                              ),
                              child: Slider(
                                key: const ValueKey('MiniMode.ProgressSlider'),
                                min: 0,
                                max: duration,
                                value: progress,
                                activeColor: Colors.white,
                                inactiveColor: Colors.white24,
                                onChanged:
                                    state.disabled
                                        ? null
                                        : (value) {
                                          setState(() {
                                            _draftProgressSeconds = value;
                                          });
                                        },
                                onChangeStart:
                                    state.disabled
                                        ? null
                                        : (_) {
                                          setState(() {
                                            _isProgressSeeking = true;
                                            _draftProgressSeconds = progress;
                                            _controlsVisible = true;
                                          });
                                          onBeginSeek();
                                        },
                                onChangeEnd:
                                    state.disabled
                                        ? null
                                        : (value) {
                                          onSeek(value);
                                          onEndSeek();
                                          setState(() {
                                            _isProgressSeeking = false;
                                          });
                                        },
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  tooltip: i18n.t('nowPlaying.quickPlay'),
                                  onPressed:
                                      state.disabled ? null : onQuickPlay,
                                  color: Colors.white,
                                  disabledColor: Colors.white38,
                                  icon: const Icon(Icons.casino_rounded),
                                ),
                                IconButton(
                                  tooltip: i18n.t('player.playbackModeRepeat'),
                                  onPressed:
                                      state.disabled ? null : onCycleRepeatMode,
                                  color:
                                      state.mode == PlaybackMode.repeat ||
                                              state.mode ==
                                                  PlaybackMode.repeatOne
                                          ? const Color(0xff8bc8ff)
                                          : Colors.white,
                                  disabledColor: Colors.white38,
                                  icon: Icon(
                                    state.mode == PlaybackMode.repeatOne
                                        ? Icons.repeat_one_rounded
                                        : Icons.repeat_rounded,
                                  ),
                                ),
                                IconButton(
                                  tooltip:
                                      state.track.favorite
                                          ? i18n.t('player.unlike')
                                          : i18n.t('player.like'),
                                  onPressed:
                                      state.disabled ? null : onToggleFavorite,
                                  color:
                                      state.track.favorite
                                          ? const Color(0xffff78a6)
                                          : Colors.white,
                                  disabledColor: Colors.white38,
                                  icon: Icon(
                                    state.track.favorite
                                        ? Icons.favorite_rounded
                                        : Icons.favorite_border_rounded,
                                  ),
                                ),
                                if (onOpenVoiceAssistant != null)
                                  IconButton(
                                    tooltip: i18n.t('player.voiceAssistant'),
                                    onPressed:
                                        state.disabled
                                            ? null
                                            : onOpenVoiceAssistant,
                                    color: Colors.white,
                                    disabledColor: Colors.white38,
                                    icon: const Icon(Icons.mic_rounded),
                                  ),
                                SizedBox(
                                  width: 48,
                                  height: 48,
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    alignment: Alignment.center,
                                    children: [
                                      IconButton(
                                        tooltip:
                                            state.isMuted
                                                ? i18n.t('player.unmute')
                                                : i18n.t('player.mute'),
                                        onPressed:
                                            state.disabled
                                                ? null
                                                : () {
                                                  setState(() {
                                                    _volumeOpen = !_volumeOpen;
                                                    _controlsVisible = true;
                                                  });
                                                },
                                        color:
                                            _volumeOpen || state.isMuted
                                                ? const Color(0xff8bc8ff)
                                                : Colors.white,
                                        disabledColor: Colors.white38,
                                        icon: Icon(
                                          playerVolumeIcon(
                                            state.volume,
                                            state.isMuted,
                                          ),
                                        ),
                                      ),
                                      if (_volumeOpen)
                                        Positioned(
                                          bottom: 52,
                                          child: DecoratedBox(
                                            decoration: BoxDecoration(
                                              color: const Color(0xcc0d1726),
                                              borderRadius:
                                                  BorderRadius.circular(18),
                                              border: Border.all(
                                                color: Colors.white24,
                                              ),
                                            ),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 12,
                                                  ),
                                              child: VolumeSlider(
                                                value: clampVolumeValue(
                                                  state.volume,
                                                ),
                                                disabled: state.disabled,
                                                orientation:
                                                    VolumeSliderOrientation
                                                        .vertical,
                                                showTooltipOnMount: true,
                                                activeTrackColor: Colors.white,
                                                inactiveTrackColor:
                                                    Colors.white24,
                                                thumbColor: Colors.white,
                                                overlayColor: Colors.white24,
                                                tooltipBackgroundColor:
                                                    const Color(0xcc000000),
                                                tooltipForegroundColor:
                                                    Colors.white,
                                                onChange: onVolumeChange,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
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

class _MiniModeLyricLine extends StatefulWidget {
  const _MiniModeLyricLine({
    required this.song,
    required this.repository,
    required this.playerLyricsSource,
    required this.progressSeconds,
    required this.durationSeconds,
  });

  final LibrarySong? song;
  final LibraryRepository repository;
  final LyricsRequestMode playerLyricsSource;
  final double progressSeconds;
  final double durationSeconds;

  @override
  State<_MiniModeLyricLine> createState() => _MiniModeLyricLineState();
}

class _MiniModeLyricLineState extends State<_MiniModeLyricLine> {
  LyricsSnapshot? _lyrics;
  int? _loadingSongId;

  @override
  void initState() {
    super.initState();
    _loadLyricsForSong();
  }

  @override
  void didUpdateWidget(covariant _MiniModeLyricLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.song?.id != widget.song?.id ||
        oldWidget.playerLyricsSource != widget.playerLyricsSource) {
      _lyrics = null;
      _loadLyricsForSong();
    }
  }

  @override
  Widget build(BuildContext context) {
    final lyrics = _lyrics;
    if (lyrics == null || lyrics.lines.isEmpty) {
      return const SizedBox.shrink();
    }

    final progressRatio =
        widget.durationSeconds > 0
            ? widget.progressSeconds / widget.durationSeconds
            : 0.0;
    final text = resolveLyricText(
      lyrics: lyrics,
      progressSeconds: widget.progressSeconds,
      progressRatio: progressRatio,
    );
    if (text.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.24),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.lyrics_rounded,
                color: Color(0xd9ffffff),
                size: 15,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadLyricsForSong() async {
    final song = widget.song;
    if (song == null) {
      _loadingSongId = null;
      return;
    }

    final songId = song.id;
    _loadingSongId = songId;
    final lyrics = await widget.repository.getSongLyrics(
      songId,
      mode: widget.playerLyricsSource,
    );
    if (!mounted || _loadingSongId != songId) {
      return;
    }
    setState(() {
      _lyrics = lyrics;
    });
  }
}

String? resolvePlayerLyricLine({
  required LyricsSnapshot? lyrics,
  required LibrarySong? song,
  required double progressSeconds,
  required double durationSeconds,
}) {
  final snapshot = lyrics;
  if (snapshot == null || snapshot.lines.isEmpty || song == null) {
    return null;
  }
  final effectiveDurationSeconds =
      durationSeconds > 0 ? durationSeconds : song.duration.toDouble();
  final adjustedProgressSeconds = max(
    0.0,
    progressSeconds + song.lyricsOffsetMs / 1000,
  );
  final progressRatio =
      effectiveDurationSeconds > 0
          ? adjustedProgressSeconds / effectiveDurationSeconds
          : 0.0;
  return resolveLyricText(
    lyrics: snapshot,
    progressSeconds: adjustedProgressSeconds,
    progressRatio: progressRatio,
  );
}

class _MiniModeArtwork extends StatelessWidget {
  const _MiniModeArtwork({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: SongArtwork(
        artworkPath: path,
        fallback: const DefaultAlbumArtwork(logoOpacity: 0.9),
      ),
    );
  }
}

class _MiniModeButton extends StatelessWidget {
  const _MiniModeButton({
    required this.tooltip,
    required this.icon,
    required this.disabled,
    required this.onPressed,
    this.onLongPress,
    this.longPressTooltip,
    this.primary = false,
    this.loading = false,
  });

  final String tooltip;
  final IconData icon;
  final bool disabled;
  final VoidCallback onPressed;
  final VoidCallback? onLongPress;
  final String? longPressTooltip;
  final bool primary;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final size = primary ? 64.0 : 52.0;
    final iconSize = primary ? 34.0 : 30.0;
    final iconColor = primary ? const Color(0xff172130) : Colors.white;
    final disabledColor = primary ? const Color(0xff5e6b7a) : Colors.white38;
    final progressColor = primary ? const Color(0xff172130) : Colors.white;
    return HoldReleaseAction(
      tooltip: tooltip,
      holdTooltip: longPressTooltip,
      disabled: disabled,
      onPressed: onPressed,
      onHoldRelease: onLongPress,
      builder: (context, holdProgress) {
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: primary ? Colors.white : Colors.white24,
            shape: BoxShape.circle,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (onLongPress != null)
                Positioned.fill(
                  child: CustomPaint(
                    key: const ValueKey('MiniMode.LongPressProgress'),
                    painter: HoldReleaseProgressPainter(
                      progress: holdProgress,
                      color: progressColor,
                      strokeScale: 0.06,
                    ),
                  ),
                ),
              IconTheme(
                data: IconThemeData(
                  color: disabled ? disabledColor : iconColor,
                  size: iconSize,
                ),
                child:
                    loading
                        ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        )
                        : icon == Icons.play_arrow_rounded
                        ? SmPlayerPlayIcon(size: iconSize, color: iconColor)
                        : Icon(icon, size: iconSize),
              ),
            ],
          ),
        );
      },
    );
  }
}
