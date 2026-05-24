part of 'media_control.dart';

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
    this.utilityCondensed = false,
    this.utilityMinimal = false,
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
  final bool utilityCondensed;
  final bool utilityMinimal;
  final ValueChanged<BuildContext> onMoreClick;

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

    return Row(
      children: [
        Expanded(
          child: MediaControlButtons(
            isLoading: widget.isLoading,
            disabled: widget.disabled,
            isPlaying: widget.isPlaying,
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
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: MediaControlUtilityRows(
            trackId: widget.trackId,
            favorite: widget.favorite,
            disabled: widget.disabled,
            volumeValue: clampVolumeValue(widget.volume),
            isMuted: widget.isMuted,
            mode: widget.mode,
            onVolumeChange: widget.onVolumeChange,
            onToggleMute: widget.onToggleMute,
            onToggleShuffle: widget.onToggleShuffle,
            onToggleRepeat: widget.onToggleRepeat,
            onToggleRepeatOne: widget.onToggleRepeatOne,
            onToggleFavorite: widget.onToggleFavorite,
            onOpenVoiceAssistant: widget.onOpenVoiceAssistant,
            condensed: widget.utilityCondensed,
            minimal: widget.utilityMinimal,
            onMoreClick: widget.onMoreClick,
          ),
        ),
      ],
    );
  }
}

class MediaControlButtons extends StatelessWidget {
  const MediaControlButtons({
    super.key,
    required this.isLoading,
    required this.disabled,
    required this.isPlaying,
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
  });

  final bool isLoading;
  final bool disabled;
  final bool isPlaying;
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
                icon: _previousIcon,
                buttonSize: 36,
                padding: 6,
                iconSize: 24,
                disabled: disabled,
                onPressed: onPrevious,
              ),
              const SizedBox(width: 26),
              _PlayerIconButton(
                key: const ValueKey('MediaControl.PlayPauseButton'),
                tooltip: playTitle,
                icon: isPlaying ? _pauseIcon : _playIcon,
                primary: true,
                iconSize: 28,
                loading: isLoading,
                disabled: disabled,
                onPressed: onTogglePlayPause,
              ),
              const SizedBox(width: 26),
              _PlayerIconButton(
                key: const ValueKey('MediaControl.NextButton'),
                tooltip: i18n.t('player.next'),
                icon: _nextIcon,
                buttonSize: 36,
                padding: 6,
                iconSize: 24,
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
