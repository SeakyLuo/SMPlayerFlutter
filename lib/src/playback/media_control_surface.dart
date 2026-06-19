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
    required this.previousButtonRestartsTrack,
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
    this.onOpenVoiceAssistant,
    this.condensed = false,
    this.navMinimal = false,
    this.utilityCondensed = false,
    this.utilityMinimal = false,
    this.utilityWidth,
    this.includeUtility = true,
    this.progressSideOverflow = 0,
    this.sliderActiveColor,
    this.sliderInactiveColor,
    this.sliderThumbColor,
    this.sliderThumbShadow,
    this.sliderOverlayColor,
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
  final bool previousButtonRestartsTrack;
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
  final VoidCallback? onOpenVoiceAssistant;
  final bool condensed;
  final bool navMinimal;
  final bool utilityCondensed;
  final bool utilityMinimal;
  final double? utilityWidth;
  final bool includeUtility;
  final double progressSideOverflow;
  final Color? sliderActiveColor;
  final Color? sliderInactiveColor;
  final Color? sliderThumbColor;
  final BoxShadow? sliderThumbShadow;
  final Color? sliderOverlayColor;
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = widget.includeUtility && constraints.maxWidth <= 452;
        final medium = widget.includeUtility && constraints.maxWidth <= 640;
        final condensed = widget.condensed || narrow;
        final utilityCondensed =
            widget.navMinimal ? condensed : widget.utilityCondensed || medium;
        final utilityMinimal =
            widget.navMinimal || widget.utilityMinimal || medium;
        final buttons = MediaControlButtons(
          isLoading: widget.isLoading,
          disabled: widget.disabled,
          isPlaying: widget.isPlaying,
          condensed: condensed,
          navMinimal: widget.navMinimal,
          progressSeconds: progressValue,
          progressValue: progressValue,
          progressMax: progressMax,
          durationSeconds: widget.durationSeconds,
          progressSideOverflow: widget.progressSideOverflow,
          sliderActiveColor: widget.sliderActiveColor,
          sliderInactiveColor: widget.sliderInactiveColor,
          sliderThumbColor: widget.sliderThumbColor,
          sliderThumbShadow: widget.sliderThumbShadow,
          sliderOverlayColor: widget.sliderOverlayColor,
          previousButtonRestartsTrack: widget.previousButtonRestartsTrack,
          onTogglePlayPause: widget.onTogglePlayPause,
          onPrevious: widget.onPrevious,
          onForcePrevious: widget.onForcePrevious,
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
        );
        if (!widget.includeUtility) {
          return buttons;
        }
        return Row(
          children: [
            Expanded(child: buttons),
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
                desktopLyricsEnabled: widget.desktopLyricsEnabled,
                onToggleDesktopLyrics: widget.onToggleDesktopLyrics,
                onOpenVoiceAssistant: widget.onOpenVoiceAssistant,
                condensed: utilityCondensed,
                minimal: utilityMinimal,
                width: widget.utilityWidth,
                sliderActiveColor: widget.sliderActiveColor,
                sliderInactiveColor: widget.sliderInactiveColor,
                sliderThumbColor: widget.sliderThumbColor,
                sliderThumbShadow: widget.sliderThumbShadow,
                sliderOverlayColor: widget.sliderOverlayColor,
                onMoreClick: widget.onMoreClick,
              ),
            ),
          ],
        );
      },
    );
  }
}

class MediaControlButtons extends StatelessWidget {
  const MediaControlButtons({
    super.key,
    required this.isLoading,
    required this.disabled,
    required this.isPlaying,
    required this.condensed,
    required this.navMinimal,
    required this.progressSeconds,
    required this.progressValue,
    required this.progressMax,
    required this.durationSeconds,
    required this.progressSideOverflow,
    this.sliderActiveColor,
    this.sliderInactiveColor,
    this.sliderThumbColor,
    this.sliderThumbShadow,
    this.sliderOverlayColor,
    required this.previousButtonRestartsTrack,
    required this.onTogglePlayPause,
    required this.onPrevious,
    this.onForcePrevious,
    required this.onNext,
    required this.onSeekChange,
    required this.onSeekBegin,
    required this.onSeekEnd,
  });

  final bool isLoading;
  final bool disabled;
  final bool isPlaying;
  final bool condensed;
  final bool navMinimal;
  final double progressSeconds;
  final double progressValue;
  final double progressMax;
  final double durationSeconds;
  final double progressSideOverflow;
  final Color? sliderActiveColor;
  final Color? sliderInactiveColor;
  final Color? sliderThumbColor;
  final BoxShadow? sliderThumbShadow;
  final Color? sliderOverlayColor;
  final bool previousButtonRestartsTrack;
  final VoidCallback onTogglePlayPause;
  final VoidCallback onPrevious;
  final VoidCallback? onForcePrevious;
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
    final previousTitle =
        previousButtonRestartsTrack
            ? i18n.t('player.restartCurrentTrackHoldPrevious')
            : i18n.t('player.previous');
    final transportGap = navMinimal || condensed ? 16.0 : 26.0;
    final primarySize =
        navMinimal && condensed
            ? 48.0
            : navMinimal
            ? 52.0
            : condensed
            ? 48.0
            : 56.0;
    final primaryPadding =
        navMinimal && condensed
            ? 12.0
            : navMinimal
            ? 13.0
            : condensed
            ? 12.0
            : 14.0;
    final primaryIconSize = primarySize - primaryPadding * 2;
    final transportHeight = navMinimal || condensed ? 56.0 : 52.0;
    final progressHeight = navMinimal || condensed ? 28.0 : 36.0;
    final progressTextWidth = navMinimal || condensed ? 42.0 : 44.0;
    final progressTextSize = navMinimal || condensed ? 12.0 : 13.0;
    final progressGap = navMinimal || condensed ? 8.0 : 12.0;
    final navMinimalTopRowHeight =
        navMinimal
            ? condensed
                ? 72.0
                : 74.0
            : 0.0;
    final navMinimalTransportOffset =
        navMinimal ? (navMinimalTopRowHeight - transportHeight) / 2 : 0.0;
    final centerGap = navMinimal ? 0.0 : 4.0;

    return Column(
      mainAxisAlignment:
          navMinimal ? MainAxisAlignment.start : MainAxisAlignment.center,
      children: [
        if (navMinimalTransportOffset > 0)
          SizedBox(height: navMinimalTransportOffset),
        SizedBox(
          key: const ValueKey('MediaControl.TransportRow'),
          height: transportHeight,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _PlayerIconButton(
                key: const ValueKey('MediaControl.PreviousButton'),
                tooltip: previousTitle,
                longPressTooltip:
                    previousButtonRestartsTrack
                        ? i18n.t('player.forcePrevious')
                        : null,
                icon: _previousIcon,
                buttonSize: 36,
                padding: 6,
                iconSize: 21,
                disabled: disabled,
                onPressed: onPrevious,
                onLongPress:
                    previousButtonRestartsTrack ? onForcePrevious : null,
              ),
              SizedBox(width: transportGap),
              SizedBox(
                width: primarySize,
                height: transportHeight,
                child: OverflowBox(
                  minWidth: primarySize,
                  maxWidth: primarySize,
                  minHeight: primarySize,
                  maxHeight: primarySize,
                  child: _PlayerIconButton(
                    key: const ValueKey('MediaControl.PlayPauseButton'),
                    tooltip: playTitle,
                    icon: isPlaying ? _pauseIcon : _playIcon,
                    primary: true,
                    buttonSize: primarySize,
                    padding: primaryPadding,
                    iconSize: primaryIconSize,
                    loading: isLoading,
                    disabled: disabled,
                    onPressed: onTogglePlayPause,
                  ),
                ),
              ),
              SizedBox(width: transportGap),
              _PlayerIconButton(
                key: const ValueKey('MediaControl.NextButton'),
                tooltip: i18n.t('player.next'),
                icon: _nextIcon,
                buttonSize: 36,
                padding: 6,
                iconSize: 21,
                disabled: disabled,
                onPressed: onNext,
              ),
            ],
          ),
        ),
        if (navMinimalTransportOffset > 0)
          SizedBox(height: navMinimalTransportOffset),
        if (centerGap > 0) SizedBox(height: centerGap),
        LayoutBuilder(
          builder: (context, constraints) {
            final progressWidth =
                constraints.maxWidth + progressSideOverflow * 2;
            return SizedBox(
              key: const ValueKey('MediaControl.ProgressRow'),
              height: progressHeight,
              child: OverflowBox(
                alignment: Alignment.centerLeft,
                minWidth: progressWidth,
                maxWidth: progressWidth,
                minHeight: progressHeight,
                maxHeight: progressHeight,
                child: Transform.translate(
                  offset: Offset(-progressSideOverflow, 0),
                  child: SizedBox(
                    width: progressWidth,
                    height: progressHeight,
                    child: Row(
                      children: [
                        SizedBox(
                          key: const ValueKey(
                            'MediaControl.ProgressElapsedColumn',
                          ),
                          width: progressTextWidth,
                          child: Text(
                            formatDuration(progressSeconds),
                            style: TextStyle(
                              fontSize: progressTextSize,
                            ).copyWith(color: textMuted),
                          ),
                        ),
                        SizedBox(width: progressGap),
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
                                    activeTrackColor: sliderActiveColor,
                                    inactiveTrackColor: sliderInactiveColor,
                                    thumbColor: sliderThumbColor,
                                    thumbShadow: sliderThumbShadow,
                                    overlayColor: sliderOverlayColor,
                                  ),
                        ),
                        SizedBox(width: progressGap),
                        SizedBox(
                          key: const ValueKey(
                            'MediaControl.ProgressDurationColumn',
                          ),
                          width: progressTextWidth,
                          child: Text(
                            formatDuration(durationSeconds),
                            textAlign: TextAlign.end,
                            style: TextStyle(
                              fontSize: progressTextSize,
                            ).copyWith(color: textMuted),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
