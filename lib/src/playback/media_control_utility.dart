part of 'media_control.dart';

class MediaControlUtilityRows extends StatefulWidget {
  const MediaControlUtilityRows({
    super.key,
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
    this.desktopLyricsEnabled = false,
    this.onToggleDesktopLyrics,
    this.onOpenVoiceAssistant,
    this.condensed = false,
    this.minimal = false,
    this.width,
    this.sliderActiveColor,
    this.sliderInactiveColor,
    this.sliderThumbColor,
    this.sliderThumbShadow,
    this.sliderOverlayColor,
    this.volumeSliderActiveColor,
    this.volumeSliderInactiveColor,
    this.volumeSliderThumbColor,
    this.volumeSliderThumbShadow,
    this.volumeSliderOverlayColor,
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
  final bool desktopLyricsEnabled;
  final VoidCallback? onToggleDesktopLyrics;
  final VoidCallback? onOpenVoiceAssistant;
  final bool condensed;
  final bool minimal;
  final double? width;
  final Color? sliderActiveColor;
  final Color? sliderInactiveColor;
  final Color? sliderThumbColor;
  final BoxShadow? sliderThumbShadow;
  final Color? sliderOverlayColor;
  final Color? volumeSliderActiveColor;
  final Color? volumeSliderInactiveColor;
  final Color? volumeSliderThumbColor;
  final BoxShadow? volumeSliderThumbShadow;
  final Color? volumeSliderOverlayColor;
  final ValueChanged<BuildContext> onMoreClick;

  @override
  State<MediaControlUtilityRows> createState() =>
      _MediaControlUtilityRowsState();
}

class _MediaControlUtilityRowsState extends State<MediaControlUtilityRows> {
  late var _liveVolumeValue = widget.volumeValue;

  @override
  void didUpdateWidget(covariant MediaControlUtilityRows oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.volumeValue != widget.volumeValue) {
      _liveVolumeValue = widget.volumeValue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final trackId = widget.trackId;
    final favorite = widget.favorite;
    final disabled = widget.disabled;
    final volumeValue = widget.volumeValue;
    final isMuted = widget.isMuted;
    final mode = widget.mode;
    final onToggleMute = widget.onToggleMute;
    final onToggleShuffle = widget.onToggleShuffle;
    final onToggleRepeat = widget.onToggleRepeat;
    final onToggleRepeatOne = widget.onToggleRepeatOne;
    final onToggleFavorite = widget.onToggleFavorite;
    final desktopLyricsEnabled = widget.desktopLyricsEnabled;
    final onToggleDesktopLyrics = widget.onToggleDesktopLyrics;
    final onOpenVoiceAssistant = widget.onOpenVoiceAssistant;
    final condensed = widget.condensed;
    final minimal = widget.minimal;
    final width = widget.width;
    final sliderActiveColor = widget.sliderActiveColor;
    final sliderInactiveColor = widget.sliderInactiveColor;
    final sliderThumbColor = widget.sliderThumbColor;
    final sliderThumbShadow = widget.sliderThumbShadow;
    final sliderOverlayColor = widget.sliderOverlayColor;
    final volumeSliderActiveColor =
        widget.volumeSliderActiveColor ?? sliderActiveColor;
    final volumeSliderInactiveColor =
        widget.volumeSliderInactiveColor ?? sliderInactiveColor;
    final volumeSliderThumbColor =
        widget.volumeSliderThumbColor ?? sliderThumbColor;
    final volumeSliderThumbShadow =
        widget.volumeSliderThumbShadow ?? sliderThumbShadow;
    final volumeSliderOverlayColor =
        widget.volumeSliderOverlayColor ?? sliderOverlayColor;
    final onMoreClick = widget.onMoreClick;
    final i18n = _mediaControlI18n(context);
    final compactMinimal = _usesCompactMinimalUtility(
      width: width,
      minimal: minimal,
      condensed: condensed,
      hasVoiceAssistant: onOpenVoiceAssistant != null,
      hasDesktopLyrics: onToggleDesktopLyrics != null,
    );
    final resolvedWidth = _resolvedMediaControlUtilityWidth(
      width: width,
      minimal: minimal,
      condensed: condensed,
      hasVoiceAssistant: onOpenVoiceAssistant != null,
      hasDesktopLyrics: onToggleDesktopLyrics != null,
    );
    final utilityButtonSize = compactMinimal ? 34.0 : 36.0;
    final utilityButtonPadding = compactMinimal ? 5.0 : 6.0;
    final utilityIconSize = utilityButtonSize - utilityButtonPadding * 2;
    final modeRowGap = minimal ? 6.0 : 14.0;
    final volumeRowGap = condensed ? 8.0 : 14.0;
    final modeRow = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Builder(
          builder: (modeButtonContext) {
            return _PlayerIconButton(
              key: const ValueKey('MediaControl.CompactModeButton'),
              tooltip:
                  '${i18n.t('player.playbackMode')}: ${_playbackModeName(i18n, mode)}',
              icon: _playbackModeIcon(mode),
              disabled: false,
              buttonSize: utilityButtonSize,
              padding: utilityButtonPadding,
              iconSize: utilityIconSize,
              showLongPressProgress: false,
              holdDuration: const Duration(milliseconds: 520),
              onPressed: () {
                _cyclePlaybackMode(
                  mode: mode,
                  onToggleShuffle: onToggleShuffle,
                  onToggleRepeat: onToggleRepeat,
                  onToggleRepeatOne: onToggleRepeatOne,
                );
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
              onSecondaryTap: () {
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
        ),
        SizedBox(width: modeRowGap),
        if (onToggleDesktopLyrics != null) ...[
          _PlayerIconButton(
            key: const ValueKey('MediaControl.DesktopLyricsButton'),
            tooltip: _desktopLyricsTooltip(i18n, desktopLyricsEnabled),
            icon: _desktopLyricsIcon,
            active: desktopLyricsEnabled,
            disabled: disabled,
            buttonSize: utilityButtonSize,
            padding: utilityButtonPadding,
            iconSize: utilityIconSize,
            onPressed: onToggleDesktopLyrics,
          ),
          SizedBox(width: modeRowGap),
        ],
        if (onOpenVoiceAssistant != null) ...[
          _PlayerIconButton(
            tooltip: i18n.t('player.voiceAssistant'),
            icon: _voiceIcon,
            disabled: false,
            buttonSize: utilityButtonSize,
            padding: utilityButtonPadding,
            iconSize: utilityIconSize,
            onPressed: onOpenVoiceAssistant,
          ),
          SizedBox(width: modeRowGap),
        ],
        Builder(
          builder: (moreButtonContext) {
            return _PlayerIconButton(
              key: const ValueKey('MediaControl.MoreButton'),
              tooltip: i18n.t('player.more'),
              icon: _moreIcon,
              disabled: false,
              buttonSize: utilityButtonSize,
              padding: utilityButtonPadding,
              iconSize: utilityIconSize,
              onPressed: () {
                onMoreClick(moreButtonContext);
              },
            );
          },
        ),
      ],
    );

    return SizedBox(
      width: resolvedWidth,
      child: Padding(
        padding:
            minimal
                ? EdgeInsets.zero
                : condensed
                ? const EdgeInsets.symmetric(horizontal: 8)
                : const EdgeInsets.only(left: 12, right: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!minimal)
              SizedBox(
                key: const ValueKey('MediaControl.VolumeRow'),
                height: 44,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 250),
                    child: Row(
                      children: [
                        _PlayerIconButton(
                          key: const ValueKey('MediaControl.VolumeButton'),
                          tooltip:
                              isMuted
                                  ? i18n.t('player.unmute')
                                  : i18n.t('player.mute'),
                          icon: playerVolumeIcon(_liveVolumeValue, isMuted),
                          active: isMuted,
                          disabled: disabled,
                          onPressed: onToggleMute,
                        ),
                        SizedBox(width: volumeRowGap),
                        Expanded(
                          child: SizedBox(
                            height: 22,
                            child: VolumeSlider(
                              key: const ValueKey(
                                'MediaControl.WideVolumeSlider',
                              ),
                              value: volumeValue,
                              disabled: disabled,
                              activeTrackColor:
                                  volumeSliderActiveColor ??
                                  MediaControlColors.accent,
                              inactiveTrackColor:
                                  volumeSliderInactiveColor ??
                                  MediaControlColors.sliderInactive,
                              thumbColor:
                                  volumeSliderThumbColor ??
                                  MediaControlColors.accent,
                              thumbShadow: volumeSliderThumbShadow,
                              overlayColor:
                                  volumeSliderOverlayColor ??
                                  MediaControlColors.accentHover,
                              onChange: _handleVolumeChange,
                            ),
                          ),
                        ),
                        SizedBox(width: volumeRowGap),
                        if (trackId != null)
                          _PlayerIconButton(
                            key: const ValueKey('MediaControl.FavoriteButton'),
                            tooltip:
                                favorite
                                    ? i18n.t('player.unlike')
                                    : i18n.t('player.like'),
                            icon:
                                favorite
                                    ? _favoriteFilledIcon
                                    : _favoriteOutlineIcon,
                            active: favorite,
                            disabled: disabled,
                            favorite: favorite,
                            onPressed: onToggleFavorite,
                          )
                        else
                          const SizedBox(width: 36),
                      ],
                    ),
                  ),
                ),
              ),
            SizedBox(
              key: const ValueKey('MediaControl.ModeRow'),
              height: minimal ? 36 : 44,
              child: Align(
                alignment: minimal ? Alignment.center : Alignment.centerRight,
                child:
                    compactMinimal
                        ? OverflowBox(
                          alignment:
                              minimal
                                  ? Alignment.center
                                  : Alignment.centerRight,
                          minWidth: 0,
                          maxWidth: double.infinity,
                          child: modeRow,
                        )
                        : modeRow,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleVolumeChange(int value) {
    setState(() {
      _liveVolumeValue = value;
    });
    widget.onVolumeChange(value);
  }
}

void _cyclePlaybackMode({
  required PlaybackMode mode,
  required VoidCallback onToggleShuffle,
  required VoidCallback onToggleRepeat,
  required VoidCallback onToggleRepeatOne,
}) {
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
}

String _desktopLyricsTooltip(SmPlayerI18n i18n, bool enabled) {
  return i18n.t(
    enabled ? 'player.desktopLyricsEnabled' : 'player.desktopLyricsDisabled',
  );
}

double _mediaControlUtilityWidth({
  required bool minimal,
  required bool condensed,
  required bool compactMinimal,
  required bool hasVoiceAssistant,
  required bool hasDesktopLyrics,
}) {
  final modeButtonCount =
      2 + (hasVoiceAssistant ? 1 : 0) + (hasDesktopLyrics ? 1 : 0);
  final compactWidth = modeButtonCount * 36.0 + (modeButtonCount - 1) * 14.0;
  final minimalWidth = modeButtonCount * 34.0 + (modeButtonCount - 1) * 6.0;
  if (minimal) {
    final width =
        compactMinimal
            ? minimalWidth
            : modeButtonCount * 36.0 + (modeButtonCount - 1) * 6.0;
    return condensed ? width : max(80, width);
  }
  if (condensed) {
    return max(hasVoiceAssistant ? 140 : 132, compactWidth + 16);
  }
  return 280;
}

double _resolvedMediaControlUtilityWidth({
  required double? width,
  required bool minimal,
  required bool condensed,
  required bool hasVoiceAssistant,
  required bool hasDesktopLyrics,
}) {
  final compactMinimal = _usesCompactMinimalUtility(
    width: width,
    minimal: minimal,
    condensed: condensed,
    hasVoiceAssistant: hasVoiceAssistant,
    hasDesktopLyrics: hasDesktopLyrics,
  );
  final utilityWidth = _mediaControlUtilityWidth(
    minimal: minimal,
    condensed: condensed,
    compactMinimal: compactMinimal,
    hasVoiceAssistant: hasVoiceAssistant,
    hasDesktopLyrics: hasDesktopLyrics,
  );
  return max(width ?? utilityWidth, utilityWidth);
}

bool _usesCompactMinimalUtility({
  required double? width,
  required bool minimal,
  required bool condensed,
  required bool hasVoiceAssistant,
  required bool hasDesktopLyrics,
}) {
  if (!minimal) {
    return false;
  }
  if (width == null) {
    return condensed;
  }
  final buttonCount =
      2 + (hasVoiceAssistant ? 1 : 0) + (hasDesktopLyrics ? 1 : 0);
  final fullWidth = buttonCount * 36.0 + (buttonCount - 1) * 6.0;
  return width < fullWidth;
}

class PlayerVolumeMenuItem extends StatefulWidget {
  const PlayerVolumeMenuItem({
    super.key,
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
  State<PlayerVolumeMenuItem> createState() => _PlayerVolumeMenuItemState();
}

class _PlayerVolumeMenuItemState extends State<PlayerVolumeMenuItem> {
  late var _liveValue = widget.volumeValue;
  late var _liveMuted = widget.muted;

  @override
  void didUpdateWidget(covariant PlayerVolumeMenuItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.volumeValue != widget.volumeValue) {
      _liveValue = widget.volumeValue;
    }
    if (oldWidget.muted != widget.muted) {
      _liveMuted = widget.muted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sliderColors = MediaControlSliderColors.forBrightness(
      Theme.of(context).brightness,
    );
    final menuColors = MenuFlyoutThemeColors.of(context);
    return Padding(
      key: const ValueKey('MediaControl.VolumeMenuItem'),
      padding: const EdgeInsets.only(left: 6, right: 10),
      child: Row(
        children: [
          Tooltip(
            message: widget.label,
            child: SizedBox(
              width: 28,
              height: 28,
              child: IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 28,
                  height: 28,
                ),
                style: IconButton.styleFrom(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  minimumSize: const Size.square(28),
                  shape: const CircleBorder(),
                  overlayColor: Colors.transparent,
                ).copyWith(
                  foregroundColor: WidgetStateProperty.resolveWith(
                    (states) =>
                        states.contains(WidgetState.disabled)
                            ? menuColors.disabledText
                            : menuColors.text,
                  ),
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.hovered) ||
                        states.contains(WidgetState.focused)) {
                      return menuColors.hoverSurface;
                    }
                    return Colors.transparent;
                  }),
                ),
                icon: MediaControlIconGlyph(
                  icon: playerVolumeIcon(_liveValue, _liveMuted),
                  size: 18,
                ),
                onPressed:
                    widget.disabled
                        ? null
                        : () {
                          setState(() {
                            _liveMuted = !_liveMuted;
                          });
                          widget.onToggleMute();
                        },
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: VolumeSlider(
              value: widget.volumeValue,
              disabled: widget.disabled,
              activeTrackColor: sliderColors.volumeActive,
              inactiveTrackColor: sliderColors.volumeInactive,
              thumbColor: sliderColors.volumeThumb,
              thumbShadow: MediaControlSliderColors.volumeThumbShadow,
              overlayColor: Colors.transparent,
              onChange: (value) {
                setState(() {
                  _liveValue = value;
                  if (value > 0) {
                    _liveMuted = false;
                  }
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
