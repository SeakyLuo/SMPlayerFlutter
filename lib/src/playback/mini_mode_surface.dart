import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:smplayer_flutter/src/app/shell_widgets.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_repository.dart';
import 'package:smplayer_flutter/src/library/ui/menu_flyout.dart';
import 'package:smplayer_flutter/src/library/ui/default_album_artwork.dart';
import 'package:smplayer_flutter/src/library/ui/song_artwork.dart';
import 'package:smplayer_flutter/src/lyrics/lyric_text_resolver.dart';
import 'package:smplayer_flutter/src/playback/media_control.dart';
import 'package:smplayer_flutter/src/playback/media_control_model.dart';
import 'package:smplayer_flutter/src/settings/settings_model.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

class MiniModeSurface extends StatefulWidget {
  const MiniModeSurface({
    super.key,
    required this.state,
    required this.i18n,
    required this.currentSong,
    required this.repository,
    required this.playerLyricsSource,
    required this.lyricsRefreshRevision,
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
    required this.onCyclePlaybackMode,
    required this.onToggleShuffle,
    required this.onToggleRepeat,
    required this.onToggleRepeatOne,
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
  final int lyricsRefreshRevision;
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
  final VoidCallback onCyclePlaybackMode;
  final VoidCallback onToggleShuffle;
  final VoidCallback onToggleRepeat;
  final VoidCallback onToggleRepeatOne;
  final VoidCallback onToggleMute;
  final ValueChanged<int> onVolumeChange;
  final VoidCallback? onOpenVoiceAssistant;
  final VoidCallback? onWindowDragStart;
  final VoidCallback? onWindowDragEnd;

  @override
  State<MiniModeSurface> createState() => _MiniModeSurfaceState();
}

class _MiniModeSurfaceState extends State<MiniModeSurface> {
  static const _animationDuration = Duration(milliseconds: 180);

  Timer? _controlsHideTimer;
  var _controlsVisible = false;
  var _volumeOpen = false;
  var _isProgressSeeking = false;
  var _draftProgressSeconds = 0.0;
  LyricsSnapshot? _lyrics;
  int? _loadingLyricsSongId;

  @override
  void initState() {
    super.initState();
    _loadLyricsForSong();
  }

  @override
  void didUpdateWidget(covariant MiniModeSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentSong?.id != widget.currentSong?.id ||
        oldWidget.playerLyricsSource != widget.playerLyricsSource ||
        oldWidget.lyricsRefreshRevision != widget.lyricsRefreshRevision) {
      _lyrics = null;
      _loadLyricsForSong();
    }
  }

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
        duration: _animationDuration,
        curve: Curves.ease,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final i18n = widget.i18n;
    final currentSong = widget.currentSong;
    final artworkPath = currentSong?.thumbnailPath ?? state.track.artworkUrl;
    final title =
        state.track.title.isEmpty
            ? i18n.t('nowPlaying.noActiveTrack')
            : state.track.title;
    final artist =
        state.track.artist.isEmpty
            ? i18n.t('common.artistUnknown')
            : state.track.artist;
    final effectiveDuration =
        state.durationSeconds > 0
            ? state.durationSeconds
            : currentSong?.duration.toDouble() ?? 0;
    final duration = effectiveDuration <= 0 ? 1.0 : effectiveDuration;
    final displayProgressSeconds =
        _isProgressSeeking ? _draftProgressSeconds : state.progressSeconds;
    final progress = displayProgressSeconds.clamp(0, duration).toDouble();
    final lyricLine = resolvePlayerLyricLine(
      lyrics: _lyrics,
      song: currentSong,
      progressSeconds: state.progressSeconds,
      durationSeconds: effectiveDuration,
    );
    final playbackModeTooltip =
        '${i18n.t('player.playbackMode')}: ${_miniModePlaybackModeName(i18n, state.mode)}';

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
        child: ColoredBox(
          color: const Color(0xff050607),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _MiniModeArtwork(path: artworkPath),
              AnimatedContainer(
                duration: _animationDuration,
                curve: Curves.ease,
                color: Colors.black.withValues(
                  alpha: _controlsVisible ? 0.75 : 0,
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                left: 0,
                height: 32,
                child: ShellWindowDragRegion(
                  onWindowDragStart: widget.onWindowDragStart,
                  onWindowDragEnd: widget.onWindowDragEnd,
                  child: const SizedBox.expand(),
                ),
              ),
              Positioned(
                top: 7,
                right: 8,
                left: 8,
                child: _visibleControls(
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _MiniModeButton(
                      tooltip: i18n.t('player.exitMiniMode'),
                      icon: _MiniModeIconName.arrowLeft,
                      disabled: false,
                      onPressed: widget.onExit,
                      size: 34,
                      padding: 8,
                    ),
                  ),
                ),
              ),
              Center(
                child: _visibleControls(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _MiniModeButton(
                        tooltip:
                            widget.previousButtonRestartsTrack
                                ? i18n.t(
                                  'player.restartCurrentTrackHoldPrevious',
                                )
                                : i18n.t('player.previous'),
                        icon: _MiniModeIconName.previous,
                        disabled: state.disabled,
                        onPressed: widget.onPrevious,
                        size: 40,
                        padding: 9,
                      ),
                      const SizedBox(width: 10),
                      _MiniModeButton(
                        primary: true,
                        tooltip:
                            state.isPlaying
                                ? i18n.t('player.pause')
                                : i18n.t('player.play'),
                        icon:
                            state.isPlaying
                                ? _MiniModeIconName.pause
                                : _MiniModeIconName.play,
                        loading: state.track.isLoading,
                        disabled: state.disabled,
                        onPressed: widget.onTogglePlayPause,
                        size: 48,
                        padding: 12,
                      ),
                      const SizedBox(width: 10),
                      _MiniModeButton(
                        tooltip: i18n.t('player.next'),
                        icon: _MiniModeIconName.next,
                        disabled: state.disabled,
                        onPressed: widget.onNext,
                        size: 40,
                        padding: 9,
                      ),
                    ],
                  ),
                ),
              ),
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final copyHidden = constraints.maxHeight <= 249;
                    final showControlLyrics = constraints.maxHeight >= 361;
                    final copyCenter =
                        (constraints.maxHeight / 2 +
                            24 +
                            constraints.maxHeight -
                            52) /
                        2;
                    return Stack(
                      children: [
                        if (!copyHidden)
                          Positioned(
                            top: copyCenter,
                            right: 16,
                            left: 16,
                            child: AnimatedSlide(
                              duration: _animationDuration,
                              curve: Curves.ease,
                              offset:
                                  _controlsVisible
                                      ? Offset.zero
                                      : const Offset(0, 0.18),
                              child: Transform.translate(
                                offset: const Offset(0, -27),
                                child: _visibleControls(
                                  _MiniModeTrackCopy(
                                    title: title,
                                    artist: artist,
                                    lyricLine:
                                        showControlLyrics ? lyricLine : null,
                                  ),
                                  key: const ValueKey(
                                    'MiniMode.TrackCopyOpacity',
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (lyricLine != null)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            left: 0,
                            height: 58,
                            child: IgnorePointer(
                              child: AnimatedOpacity(
                                opacity: _controlsVisible ? 0 : 1,
                                duration: _animationDuration,
                                curve: Curves.ease,
                                child: _MiniModeLyricsStrip(
                                  lyricLine: lyricLine,
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
              Positioned(
                right: 10,
                bottom: 0,
                left: 10,
                child: IgnorePointer(
                  ignoring: !_controlsVisible,
                  child: AnimatedOpacity(
                    opacity: _controlsVisible ? 1 : 0,
                    duration: _animationDuration,
                    curve: Curves.ease,
                    child: SizedBox(
                      height: 220,
                      child: AnimatedSlide(
                        duration: _animationDuration,
                        curve: Curves.ease,
                        offset:
                            _controlsVisible
                                ? Offset.zero
                                : const Offset(0, 0.3),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            if (_volumeOpen)
                              Positioned(
                                right: -4,
                                bottom: 50,
                                child: _MiniModeVolumePopover(
                                  value: clampVolumeValue(state.volume),
                                  disabled: state.disabled,
                                  onChange: widget.onVolumeChange,
                                ),
                              ),
                            Positioned(
                              right: 0,
                              bottom: 18,
                              left: 0,
                              height: 34,
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  _MiniModeButton(
                                    tooltip: i18n.t('nowPlaying.quickPlay'),
                                    icon: _MiniModeIconName.dice,
                                    disabled: state.disabled,
                                    onPressed: () {
                                      setState(() {
                                        _volumeOpen = false;
                                      });
                                      widget.onQuickPlay();
                                    },
                                    size: 34,
                                    padding: 8,
                                  ),
                                  Builder(
                                    builder: (modeButtonContext) {
                                      return _MiniModeButton(
                                        key: const ValueKey(
                                          'MiniMode.PlaybackModeButton',
                                        ),
                                        tooltip: playbackModeTooltip,
                                        icon: _miniModePlaybackModeIcon(
                                          state.mode,
                                        ),
                                        disabled: state.disabled,
                                        active: state.mode != PlaybackMode.once,
                                        onPressed: () {
                                          setState(() {
                                            _volumeOpen = false;
                                          });
                                          widget.onCyclePlaybackMode();
                                        },
                                        onLongPress: () {
                                          setState(() {
                                            _volumeOpen = false;
                                            _controlsVisible = true;
                                          });
                                          _showMiniModePlaybackModeMenu(
                                            modeButtonContext,
                                            i18n: i18n,
                                            mode: state.mode,
                                            onToggleShuffle:
                                                widget.onToggleShuffle,
                                            onToggleRepeat:
                                                widget.onToggleRepeat,
                                            onToggleRepeatOne:
                                                widget.onToggleRepeatOne,
                                          );
                                        },
                                        size: 34,
                                        padding: 8,
                                      );
                                    },
                                  ),
                                  _MiniModeButton(
                                    tooltip:
                                        state.track.favorite
                                            ? i18n.t('player.unlike')
                                            : i18n.t('player.like'),
                                    icon:
                                        state.track.favorite
                                            ? _MiniModeIconName.heartFilled
                                            : _MiniModeIconName.heart,
                                    disabled: state.disabled,
                                    favorite: state.track.favorite,
                                    onPressed: widget.onToggleFavorite,
                                    size: 34,
                                    padding: 8,
                                  ),
                                  if (widget.onOpenVoiceAssistant != null)
                                    _MiniModeButton(
                                      tooltip: i18n.t('player.voiceAssistant'),
                                      icon: _MiniModeIconName.voice,
                                      disabled: state.disabled,
                                      onPressed: () {
                                        setState(() {
                                          _volumeOpen = false;
                                        });
                                        widget.onOpenVoiceAssistant!();
                                      },
                                      size: 34,
                                      padding: 8,
                                    ),
                                  _MiniModeButton(
                                    key: const ValueKey(
                                      'MiniMode.VolumeButton',
                                    ),
                                    tooltip:
                                        state.isMuted
                                            ? i18n.t('player.unmute')
                                            : i18n.t('player.mute'),
                                    icon: _miniModeVolumeIcon(
                                      state.volume,
                                      state.isMuted,
                                    ),
                                    disabled: state.disabled,
                                    active: _volumeOpen,
                                    onPressed: () {
                                      setState(() {
                                        _volumeOpen = !_volumeOpen;
                                        _controlsVisible = true;
                                      });
                                    },
                                    size: 34,
                                    padding: 8,
                                  ),
                                ],
                              ),
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              left: 0,
                              height: 18,
                              child: _MiniModeProgressSlider(
                                value: progress,
                                max: duration,
                                disabled:
                                    state.disabled || effectiveDuration <= 0,
                                onBeginSeek: () {
                                  setState(() {
                                    _isProgressSeeking = true;
                                    _draftProgressSeconds = progress;
                                    _controlsVisible = true;
                                  });
                                  widget.onBeginSeek();
                                },
                                onChanged: (value) {
                                  setState(() {
                                    _draftProgressSeconds = value;
                                  });
                                },
                                onEndSeek: (value) {
                                  widget.onSeek(value);
                                  widget.onEndSeek();
                                  setState(() {
                                    _isProgressSeeking = false;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
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

  Future<void> _loadLyricsForSong() async {
    final song = widget.currentSong;
    if (song == null) {
      _loadingLyricsSongId = null;
      return;
    }

    final songId = song.id;
    _loadingLyricsSongId = songId;
    final lyrics = await widget.repository.getSongLyrics(
      songId,
      mode: widget.playerLyricsSource,
    );
    if (!mounted || _loadingLyricsSongId != songId) {
      return;
    }
    setState(() {
      _lyrics = lyrics;
    });
  }
}

class _MiniModeTrackCopy extends StatelessWidget {
  const _MiniModeTrackCopy({
    required this.title,
    required this.artist,
    required this.lyricLine,
  });

  final String title;
  final String artist;
  final String? lyricLine;

  @override
  Widget build(BuildContext context) {
    final lyricLine = this.lyricLine;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          artist,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xd1ffffff),
            fontSize: 13,
            fontWeight: FontWeight.w500,
            height: 1.2,
          ),
        ),
        if (lyricLine != null) ...[
          const SizedBox(height: 3),
          SizedBox(
            height: 17,
            width: double.infinity,
            child: _MiniModeLyricText(lyricLine),
          ),
        ],
      ],
    );
  }
}

class _MiniModeLyricsStrip extends StatelessWidget {
  const _MiniModeLyricsStrip({required this.lyricLine});

  final String lyricLine;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0x9e000000), Color(0x61000000), Color(0x00000000)],
          stops: [0, 0.48, 1],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 22, 14, 11),
        child: Align(
          alignment: Alignment.bottomLeft,
          child: _MiniModeLyricText(lyricLine),
        ),
      ),
    );
  }
}

class _MiniModeLyricText extends StatelessWidget {
  const _MiniModeLyricText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      key: ValueKey(text),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Color(0xefffffff),
        fontSize: 13,
        fontWeight: FontWeight.w600,
        height: 17 / 13,
        shadows: [
          Shadow(offset: Offset(0, 1), blurRadius: 5, color: Color(0xb8000000)),
        ],
      ),
    );
  }
}

class _MiniModeProgressSlider extends StatefulWidget {
  const _MiniModeProgressSlider({
    required this.value,
    required this.max,
    required this.disabled,
    required this.onBeginSeek,
    required this.onChanged,
    required this.onEndSeek,
  });

  final double value;
  final double max;
  final bool disabled;
  final VoidCallback onBeginSeek;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onEndSeek;

  @override
  State<_MiniModeProgressSlider> createState() =>
      _MiniModeProgressSliderState();
}

class _MiniModeProgressSliderState extends State<_MiniModeProgressSlider> {
  var _hovered = false;
  var _focused = false;
  var _dragging = false;

  @override
  Widget build(BuildContext context) {
    final showThumb = _hovered || _focused || _dragging;
    return MouseRegion(
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
        child: SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 2,
            thumbShape: RoundSliderThumbShape(
              enabledThumbRadius: showThumb ? 5 : 0,
              disabledThumbRadius: 0,
            ),
            overlayShape: SliderComponentShape.noOverlay,
            activeTrackColor: Colors.white.withValues(alpha: 0.96),
            inactiveTrackColor: Colors.white.withValues(alpha: 0.32),
            thumbColor: Colors.white,
          ),
          child: Transform.translate(
            offset: const Offset(0, -3),
            child: Slider(
              key: const ValueKey('MiniMode.ProgressSlider'),
              min: 0,
              max: widget.max,
              value: widget.value,
              onChangeStart:
                  widget.disabled
                      ? null
                      : (_) {
                        setState(() {
                          _dragging = true;
                        });
                        widget.onBeginSeek();
                      },
              onChanged: widget.disabled ? null : widget.onChanged,
              onChangeEnd:
                  widget.disabled
                      ? null
                      : (value) {
                        widget.onEndSeek(value);
                        setState(() {
                          _dragging = false;
                        });
                      },
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniModeVolumePopover extends StatelessWidget {
  const _MiniModeVolumePopover({
    required this.value,
    required this.disabled,
    required this.onChange,
  });

  final int value;
  final bool disabled;
  final ValueChanged<int> onChange;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xf5222222),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.42),
            offset: const Offset(0, 16),
            blurRadius: 36,
          ),
        ],
      ),
      child: SizedBox(
        width: 48,
        height: 116,
        child: Center(
          child: VolumeSlider(
            key: const ValueKey('MiniMode.VolumeSlider'),
            value: value,
            disabled: disabled,
            onChange: onChange,
            orientation: VolumeSliderOrientation.vertical,
            verticalHeight: 116,
            verticalTrackLength: 96,
            trackHeight: 2,
            thumbRadius: 6,
            overlayRadius: 8,
            verticalTooltipSide: VolumeSliderVerticalTooltipSide.left,
            activeTrackColor: Colors.white.withValues(alpha: 0.96),
            inactiveTrackColor: Colors.white.withValues(alpha: 0.32),
            thumbColor: Colors.white,
            overlayColor: Colors.white.withValues(alpha: 0.18),
            tooltipBackgroundColor: const Color(0xf5222222),
            tooltipForegroundColor: Colors.white,
            tooltipBorderColor: const Color(0x2effffff),
            tooltipShadow: const BoxShadow(
              color: Color(0x57000000),
              offset: Offset(0, 8),
              blurRadius: 18,
            ),
          ),
        ),
      ),
    );
  }
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

class _MiniModeButton extends StatefulWidget {
  const _MiniModeButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.disabled,
    required this.onPressed,
    required this.size,
    required this.padding,
    this.onLongPress,
    this.primary = false,
    this.active = false,
    this.favorite = false,
    this.loading = false,
  });

  final String tooltip;
  final _MiniModeIconName icon;
  final bool disabled;
  final VoidCallback onPressed;
  final VoidCallback? onLongPress;
  final double size;
  final double padding;
  final bool primary;
  final bool active;
  final bool favorite;
  final bool loading;

  @override
  State<_MiniModeButton> createState() => _MiniModeButtonState();
}

class _MiniModeButtonState extends State<_MiniModeButton> {
  static const _favoriteAccent = Color(0xffff1d1d);
  static const _electronActiveGlassColor = Color(0x2effffff);
  static const _electronHoverGlassColor = Color(0x33ffffff);

  LiquidGlassSettings _glassSettings(Color glassColor) {
    return LiquidGlassSettings(
      glassColor: glassColor,
      thickness: 20,
      blur: 46,
      chromaticAberration: 0,
      lightIntensity: 0.1,
      ambientStrength: 0.08,
      refractiveIndex: 1.06,
      saturation: 1.65,
      glowIntensity: 0.04,
      standardOpacityMultiplier: 0.35,
    );
  }

  var _hovered = false;
  var _pressed = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.favorite ? _favoriteAccent : Colors.white;
    final showGlass =
        !widget.disabled && (widget.primary || widget.active || _hovered);
    final glassColor =
        _hovered && !widget.primary && !widget.active && !widget.favorite
            ? _electronHoverGlassColor
            : _electronActiveGlassColor;
    final icon = _MiniModeIcon(
      icon: widget.icon,
      color: color,
      size: widget.size - widget.padding * 2,
    );
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor:
            widget.disabled
                ? SystemMouseCursors.basic
                : SystemMouseCursors.click,
        onEnter: (_) {
          setState(() {
            _hovered = true;
          });
        },
        onExit: (_) {
          setState(() {
            _hovered = false;
            _pressed = false;
          });
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.disabled ? null : widget.onPressed,
          onLongPress: widget.disabled ? null : widget.onLongPress,
          onTapDown:
              widget.disabled
                  ? null
                  : (_) {
                    setState(() {
                      _pressed = true;
                    });
                  },
          onTapCancel:
              widget.disabled
                  ? null
                  : () {
                    setState(() {
                      _pressed = false;
                    });
                  },
          onTapUp:
              widget.disabled
                  ? null
                  : (_) {
                    setState(() {
                      _pressed = false;
                    });
                  },
          child: AnimatedScale(
            scale:
                _pressed && !widget.disabled
                    ? 0.97
                    : _hovered && !widget.disabled
                    ? 1.08
                    : 1,
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            child: Opacity(
              opacity: widget.disabled ? 0.48 : 1,
              child: SizedBox(
                width: widget.size,
                height: widget.size,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeOutCubic,
                  child:
                      showGlass
                          ? IgnorePointer(
                            key: const ValueKey('glass'),
                            child: GlassIconButton(
                              size: widget.size,
                              iconSize: widget.size - widget.padding * 2,
                              useOwnLayer: true,
                              settings: _glassSettings(glassColor),
                              glowColor: Colors.white.withValues(alpha: 0.18),
                              glowRadius: widget.size * 0.44,
                              onPressed: () {},
                              icon: IconTheme(
                                data: IconThemeData(color: color),
                                child:
                                    widget.loading
                                        ? const CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        )
                                        : icon,
                              ),
                            ),
                          )
                          : Padding(
                            key: const ValueKey('plain'),
                            padding: EdgeInsets.all(widget.padding),
                            child:
                                widget.loading
                                    ? const CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    )
                                    : icon,
                          ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void _showMiniModePlaybackModeMenu(
  BuildContext context, {
  required SmPlayerI18n i18n,
  required PlaybackMode mode,
  required VoidCallback onToggleShuffle,
  required VoidCallback onToggleRepeat,
  required VoidCallback onToggleRepeatOne,
}) {
  final box = context.findRenderObject() as RenderBox;
  showMenuFlyout(
    context,
    position: box.localToGlobal(const Offset(0, -8)),
    avoidPlayerBar: false,
    items: buildPlaybackModeMenuFlyoutItems(
      i18n: i18n,
      mode: mode,
      onToggleShuffle: onToggleShuffle,
      onToggleRepeat: onToggleRepeat,
      onToggleRepeatOne: onToggleRepeatOne,
    ),
  );
}

class _MiniModeIcon extends StatelessWidget {
  const _MiniModeIcon({
    required this.icon,
    required this.color,
    required this.size,
  });

  final _MiniModeIconName icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final mediaControlIcon = _miniModeMediaControlIcon(icon);
    if (mediaControlIcon != null) {
      return MediaControlIconGlyph(
        key: ValueKey('MiniMode.Icon.${icon.name}'),
        icon: mediaControlIcon,
        size: size,
        color: color,
      );
    }
    return SizedBox.square(
      key: ValueKey('MiniMode.Icon.${icon.name}'),
      dimension: size,
      child: CustomPaint(painter: _MiniModeIconPainter(icon, color)),
    );
  }
}

enum _MiniModeIconName {
  arrowLeft,
  previous,
  next,
  play,
  pause,
  dice,
  listPlayback,
  shuffle,
  repeat,
  repeatOne,
  heart,
  heartFilled,
  voice,
  volume,
  volumeOff,
  volumeLow,
  volumeMedium,
  volumeMuted,
}

_MiniModeIconName _miniModePlaybackModeIcon(PlaybackMode mode) {
  return switch (mode) {
    PlaybackMode.once => _MiniModeIconName.listPlayback,
    PlaybackMode.shuffle => _MiniModeIconName.shuffle,
    PlaybackMode.repeat => _MiniModeIconName.repeat,
    PlaybackMode.repeatOne => _MiniModeIconName.repeatOne,
  };
}

String _miniModePlaybackModeName(SmPlayerI18n i18n, PlaybackMode mode) {
  return switch (mode) {
    PlaybackMode.once => i18n.t('player.playbackModeList'),
    PlaybackMode.shuffle => i18n.t('player.playbackModeShuffle'),
    PlaybackMode.repeat => i18n.t('player.playbackModeRepeat'),
    PlaybackMode.repeatOne => i18n.t('player.playbackModeRepeatOne'),
  };
}

_MiniModeIconName _miniModeVolumeIcon(int volume, bool isMuted) {
  if (isMuted) {
    return _MiniModeIconName.volumeMuted;
  }
  if (volume <= 0) {
    return _MiniModeIconName.volumeOff;
  }
  if (volume < 34) {
    return _MiniModeIconName.volumeLow;
  }
  if (volume < 67) {
    return _MiniModeIconName.volumeMedium;
  }
  return _MiniModeIconName.volume;
}

IconData? _miniModeMediaControlIcon(_MiniModeIconName icon) {
  return switch (icon) {
    _MiniModeIconName.previous => mediaControlPreviousIcon,
    _MiniModeIconName.next => mediaControlNextIcon,
    _MiniModeIconName.play => mediaControlPlayIcon,
    _MiniModeIconName.pause => mediaControlPauseIcon,
    _MiniModeIconName.shuffle => mediaControlQuickPlayIcon,
    _MiniModeIconName.listPlayback => mediaControlPlaybackModeIcon(
      PlaybackMode.once,
    ),
    _MiniModeIconName.heart => mediaControlFavoriteIcon(false),
    _MiniModeIconName.heartFilled => mediaControlFavoriteIcon(true),
    _MiniModeIconName.voice => mediaControlVoiceIcon,
    _MiniModeIconName.repeat => mediaControlPlaybackModeIcon(
      PlaybackMode.repeat,
    ),
    _MiniModeIconName.repeatOne => mediaControlPlaybackModeIcon(
      PlaybackMode.repeatOne,
    ),
    _MiniModeIconName.volumeMuted => playerVolumeIcon(50, true),
    _MiniModeIconName.volumeOff => playerVolumeIcon(0, false),
    _MiniModeIconName.volumeLow => playerVolumeIcon(20, false),
    _MiniModeIconName.volumeMedium => playerVolumeIcon(50, false),
    _MiniModeIconName.volume => playerVolumeIcon(80, false),
    _MiniModeIconName.dice || _MiniModeIconName.arrowLeft => null,
  };
}

class _MiniModeIconPainter extends CustomPainter {
  const _MiniModeIconPainter(this.icon, this.color);

  final _MiniModeIconName icon;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 24;
    canvas.save();
    canvas.scale(scale);
    final strokeWidth =
        icon == _MiniModeIconName.volume ||
                icon == _MiniModeIconName.volumeOff ||
                icon == _MiniModeIconName.volumeLow ||
                icon == _MiniModeIconName.volumeMedium ||
                icon == _MiniModeIconName.volumeMuted
            ? 1.3
            : icon == _MiniModeIconName.dice
            ? 1.55
            : 2.2;
    final stroke =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
    final fill =
        Paint()
          ..color = color
          ..style = PaintingStyle.fill;

    switch (icon) {
      case _MiniModeIconName.arrowLeft:
        _drawPolyline(canvas, stroke, const [
          Offset(15, 18),
          Offset(9, 12),
          Offset(15, 6),
        ]);
      case _MiniModeIconName.previous:
        _drawSkipTransport(canvas, stroke, reverse: true);
      case _MiniModeIconName.next:
        _drawSkipTransport(canvas, stroke, reverse: false);
      case _MiniModeIconName.listPlayback:
        _drawListPlayback(canvas, stroke);
      case _MiniModeIconName.repeat:
        _drawRepeat(canvas, stroke, false);
      case _MiniModeIconName.repeatOne:
        _drawRepeat(canvas, stroke, true);
      case _MiniModeIconName.heart:
        canvas.drawPath(_heartOutlinePath(), stroke);
      case _MiniModeIconName.heartFilled:
        canvas.drawPath(_heartFilledPath(), fill);
      case _MiniModeIconName.voice:
        _drawVoice(canvas, stroke);
      case _MiniModeIconName.volume:
      case _MiniModeIconName.volumeOff:
      case _MiniModeIconName.volumeLow:
      case _MiniModeIconName.volumeMedium:
      case _MiniModeIconName.volumeMuted:
        _drawVolume(canvas, stroke, fill);
      case _MiniModeIconName.dice:
        _drawDice(canvas, stroke, fill);
      case _MiniModeIconName.play:
      case _MiniModeIconName.pause:
      case _MiniModeIconName.shuffle:
        break;
    }
    canvas.restore();
  }

  void _drawDice(Canvas canvas, Paint stroke, Paint fill) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(4, 4, 16, 16),
        const Radius.circular(3.5),
      ),
      stroke,
    );
    for (final point in const [
      Offset(8.5, 8.5),
      Offset(15.5, 8.5),
      Offset(12, 12),
      Offset(8.5, 15.5),
      Offset(15.5, 15.5),
    ]) {
      canvas.drawCircle(point, 0.9, fill);
    }
  }

  void _drawRepeat(Canvas canvas, Paint stroke, bool repeatOne) {
    _drawPolyline(canvas, stroke, const [
      Offset(17, 2),
      Offset(21, 6),
      Offset(17, 10),
    ]);
    canvas.drawLine(const Offset(3, 11), const Offset(3, 9), stroke);
    canvas.drawArc(const Rect.fromLTWH(3, 6, 6, 6), pi, pi / 2, false, stroke);
    canvas.drawLine(const Offset(6, 6), const Offset(21, 6), stroke);
    _drawPolyline(canvas, stroke, const [
      Offset(7, 22),
      Offset(3, 18),
      Offset(7, 14),
    ]);
    canvas.drawLine(const Offset(21, 13), const Offset(21, 15), stroke);
    canvas.drawArc(const Rect.fromLTWH(15, 12, 6, 6), 0, pi / 2, false, stroke);
    canvas.drawLine(const Offset(18, 18), const Offset(3, 18), stroke);
    if (repeatOne) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: '1',
          style: TextStyle(
            color: color,
            fontSize: 8,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(12 - textPainter.width / 2, 12 - textPainter.height / 2),
      );
    }
  }

  void _drawSkipTransport(
    Canvas canvas,
    Paint stroke, {
    required bool reverse,
  }) {
    canvas.save();
    if (reverse) {
      canvas.translate(24, 0);
      canvas.scale(-1, 1);
    }
    final path = _roundedMiniModeTransportPolygon(const [
      Offset(7.25, 5.5),
      Offset(16.25, 12),
      Offset(7.25, 18.5),
    ], 1.5);
    canvas.drawPath(path, stroke);
    canvas.drawLine(const Offset(18, 5.75), const Offset(18, 18.25), stroke);
    canvas.restore();
  }

  void _drawListPlayback(Canvas canvas, Paint stroke) {
    canvas.drawLine(const Offset(4, 6), const Offset(14, 6), stroke);
    canvas.drawLine(const Offset(4, 12), const Offset(13, 12), stroke);
    canvas.drawLine(const Offset(4, 18), const Offset(10, 18), stroke);
    canvas.drawLine(const Offset(17, 8), const Offset(17, 17), stroke);
    canvas.drawPath(
      Path()
        ..moveTo(17, 8)
        ..quadraticBezierTo(20.5, 9, 21, 6.5),
      stroke,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(15.4, 18.1),
        width: 5.1,
        height: 4.1,
      ),
      stroke,
    );
  }

  void _drawVoice(Canvas canvas, Paint stroke) {
    const centerX = 12.0;
    final micBody = RRect.fromRectAndRadius(
      const Rect.fromLTWH(8.3, 3.2, 7.4, 11.8),
      const Radius.circular(3.7),
    );
    canvas.drawRRect(micBody, stroke);
    final cradle =
        Path()
          ..moveTo(5.8, 11.2)
          ..cubicTo(5.8, 15.0, 8.5, 17.8, centerX, 17.8)
          ..cubicTo(15.5, 17.8, 18.2, 15.0, 18.2, 11.2);
    canvas.drawPath(cradle, stroke);
    canvas.drawLine(
      const Offset(centerX, 17.8),
      const Offset(centerX, 20.9),
      stroke,
    );
    canvas.drawLine(const Offset(9.0, 20.9), const Offset(15.0, 20.9), stroke);
  }

  void _drawVolume(Canvas canvas, Paint stroke, Paint fill) {
    final speaker =
        Path()
          ..moveTo(4.7, 9.4)
          ..lineTo(7.9, 9.4)
          ..lineTo(12.1, 5.7)
          ..quadraticBezierTo(13, 4.9, 13, 6.15)
          ..lineTo(13, 17.85)
          ..quadraticBezierTo(13, 19.1, 12.1, 18.3)
          ..lineTo(7.9, 14.6)
          ..lineTo(4.7, 14.6)
          ..quadraticBezierTo(3.9, 14.6, 3.9, 13.8)
          ..lineTo(3.9, 10.2)
          ..quadraticBezierTo(3.9, 9.4, 4.7, 9.4)
          ..close();
    canvas.drawPath(speaker, stroke);
    if (icon == _MiniModeIconName.volumeMuted) {
      canvas.drawLine(const Offset(16, 10), const Offset(20, 14), stroke);
      canvas.drawLine(const Offset(20, 10), const Offset(16, 14), stroke);
      return;
    }
    if (icon == _MiniModeIconName.volumeOff) {
      return;
    }
    canvas.drawArc(
      const Rect.fromLTWH(13.8, 8.4, 4.2, 7.2),
      -0.78,
      1.56,
      false,
      stroke,
    );
    if (icon == _MiniModeIconName.volumeLow) {
      return;
    }
    canvas.drawArc(
      const Rect.fromLTWH(14.8, 6.4, 7.2, 11.2),
      -0.78,
      1.56,
      false,
      stroke,
    );
    if (icon == _MiniModeIconName.volumeMedium) {
      return;
    }
    canvas.drawArc(
      const Rect.fromLTWH(15.5, 4.4, 10.4, 15.2),
      -0.78,
      1.56,
      false,
      stroke,
    );
  }

  Path _heartOutlinePath() {
    return Path()
      ..moveTo(20.8, 7.6)
      ..cubicTo(18.8, 5.6, 15.6, 5.6, 13.6, 7.6)
      ..lineTo(12, 9.2)
      ..lineTo(10.4, 7.6)
      ..cubicTo(8.4, 5.6, 5.2, 5.6, 3.2, 7.6)
      ..cubicTo(1.2, 9.6, 1.2, 12.8, 3.2, 14.8)
      ..lineTo(12, 22)
      ..lineTo(20.8, 14.8)
      ..cubicTo(22.8, 12.8, 22.8, 9.6, 20.8, 7.6);
  }

  Path _heartFilledPath() {
    return _heartOutlinePath()..close();
  }

  void _drawPolyline(Canvas canvas, Paint paint, List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _MiniModeIconPainter oldDelegate) {
    return oldDelegate.icon != icon || oldDelegate.color != color;
  }
}

Path _roundedMiniModeTransportPolygon(List<Offset> points, double radius) {
  final path = Path();
  for (var index = 0; index < points.length; index += 1) {
    final previous = points[(index - 1 + points.length) % points.length];
    final current = points[index];
    final next = points[(index + 1) % points.length];
    final incoming = previous - current;
    final outgoing = next - current;
    final incomingLength = incoming.distance;
    final outgoingLength = outgoing.distance;
    final cornerRadius = min(radius, min(incomingLength, outgoingLength) / 2);
    final start = current + incoming / incomingLength * cornerRadius;
    final end = current + outgoing / outgoingLength * cornerRadius;
    if (index == 0) {
      path.moveTo(start.dx, start.dy);
    } else {
      path.lineTo(start.dx, start.dy);
    }
    path.quadraticBezierTo(current.dx, current.dy, end.dx, end.dy);
  }
  return path..close();
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
