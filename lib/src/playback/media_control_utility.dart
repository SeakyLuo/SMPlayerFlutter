part of 'media_control.dart';

class MediaControlUtilityRows extends StatelessWidget {
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
    this.onOpenVoiceAssistant,
    this.condensed = false,
    this.minimal = false,
    this.width,
    this.sliderActiveColor,
    this.sliderInactiveColor,
    this.sliderThumbColor,
    this.sliderOverlayColor,
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
  final bool minimal;
  final double? width;
  final Color? sliderActiveColor;
  final Color? sliderInactiveColor;
  final Color? sliderThumbColor;
  final Color? sliderOverlayColor;
  final ValueChanged<BuildContext> onMoreClick;

  @override
  Widget build(BuildContext context) {
    final i18n = _mediaControlI18n(context);
    final compactMinimal =
        minimal && (width == null ? condensed : width! <= 68);
    final utilityButtonSize = compactMinimal ? 34.0 : 36.0;
    final utilityButtonPadding = compactMinimal ? 5.0 : 6.0;
    final utilityIconSize = utilityButtonSize - utilityButtonPadding * 2;
    final modeRowGap =
        minimal
            ? 6.0
            : condensed
            ? 8.0
            : 14.0;
    final showCompactModeButton =
        (condensed || minimal) && !(minimal && onOpenVoiceAssistant != null);
    final modeRow = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showCompactModeButton) ...[
          Builder(
            builder: (modeButtonContext) {
              return _PlayerIconButton(
                key: const ValueKey('MediaControl.CompactModeButton'),
                tooltip:
                    '${i18n.t('player.playbackMode')}: ${_playbackModeName(i18n, mode)}',
                icon: _playbackModeIcon(mode),
                active: mode != PlaybackMode.once,
                disabled: disabled,
                buttonSize: utilityButtonSize,
                padding: utilityButtonPadding,
                iconSize: utilityIconSize,
                showLongPressProgress: false,
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
          ),
          SizedBox(width: modeRowGap),
        ] else if (!condensed && !minimal) ...[
          _PlayerIconButton(
            key: const ValueKey('MediaControl.ShuffleButton'),
            tooltip:
                mode == PlaybackMode.shuffle
                    ? i18n.t('player.shuffleEnabled')
                    : i18n.t('player.shuffleDisabled'),
            icon: _shuffleIcon,
            active: mode == PlaybackMode.shuffle,
            disabled: disabled,
            onPressed: onToggleShuffle,
          ),
          SizedBox(width: modeRowGap),
          _PlayerIconButton(
            tooltip:
                mode == PlaybackMode.repeat
                    ? i18n.t('player.repeatEnabled')
                    : i18n.t('player.repeatDisabled'),
            icon: _repeatIcon,
            active: mode == PlaybackMode.repeat,
            disabled: disabled,
            onPressed: onToggleRepeat,
          ),
          SizedBox(width: modeRowGap),
          _PlayerIconButton(
            tooltip:
                mode == PlaybackMode.repeatOne
                    ? i18n.t('player.repeatOneEnabled')
                    : i18n.t('player.repeatOneDisabled'),
            icon: _repeatOneIcon,
            active: mode == PlaybackMode.repeatOne,
            disabled: disabled,
            onPressed: onToggleRepeatOne,
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
            onPressed: onOpenVoiceAssistant!,
          ),
          SizedBox(width: modeRowGap),
        ],
        Builder(
          builder: (moreButtonContext) {
            return _PlayerIconButton(
              key: const ValueKey('MediaControl.MoreButton'),
              tooltip: i18n.t('player.more'),
              icon: _moreIcon,
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
      width:
          width ??
          _mediaControlUtilityWidth(
            minimal: minimal,
            condensed: condensed,
            hasVoiceAssistant: onOpenVoiceAssistant != null,
          ),
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
                  child:
                      condensed
                          ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _PlayerCompactVolumeAction(
                                tooltip:
                                    isMuted
                                        ? i18n.t('player.unmute')
                                        : i18n.t('player.mute'),
                                icon: playerVolumeIcon(volumeValue, isMuted),
                                active: isMuted,
                                disabled: disabled,
                                volumeValue: volumeValue,
                                sliderActiveColor: sliderActiveColor,
                                sliderInactiveColor: sliderInactiveColor,
                                sliderThumbColor: sliderThumbColor,
                                sliderOverlayColor: sliderOverlayColor,
                                onVolumeChange: onVolumeChange,
                              ),
                              const SizedBox(width: 8),
                              if (trackId != null)
                                _PlayerIconButton(
                                  key: const ValueKey(
                                    'MediaControl.FavoriteButton',
                                  ),
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
                          )
                          : SizedBox(
                            width: 248,
                            child: Row(
                              children: [
                                _PlayerIconButton(
                                  tooltip:
                                      isMuted
                                          ? i18n.t('player.unmute')
                                          : i18n.t('player.mute'),
                                  icon: playerVolumeIcon(volumeValue, isMuted),
                                  active: isMuted,
                                  disabled: disabled,
                                  onPressed: onToggleMute,
                                ),
                                const SizedBox(width: 14),
                                SizedBox(
                                  width: 148,
                                  height: 22,
                                  child: VolumeSlider(
                                    key: const ValueKey(
                                      'MediaControl.WideVolumeSlider',
                                    ),
                                    value: volumeValue,
                                    disabled: disabled,
                                    activeTrackColor:
                                        sliderActiveColor ??
                                        MediaControlColors.accent,
                                    inactiveTrackColor:
                                        sliderInactiveColor ??
                                        MediaControlColors.sliderInactive,
                                    thumbColor:
                                        sliderThumbColor ??
                                        MediaControlColors.accent,
                                    overlayColor:
                                        sliderOverlayColor ??
                                        MediaControlColors.accentHover,
                                    onChange: onVolumeChange,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                if (trackId != null)
                                  _PlayerIconButton(
                                    key: const ValueKey(
                                      'MediaControl.FavoriteButton',
                                    ),
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
}

double _mediaControlUtilityWidth({
  required bool minimal,
  required bool condensed,
  required bool hasVoiceAssistant,
}) {
  if (minimal) {
    return condensed ? 68 : 80;
  }
  if (condensed) {
    return hasVoiceAssistant ? 140 : 132;
  }
  return 280;
}

class _PlayerCompactVolumeAction extends StatefulWidget {
  const _PlayerCompactVolumeAction({
    required this.tooltip,
    required this.icon,
    required this.active,
    required this.disabled,
    required this.volumeValue,
    this.sliderActiveColor,
    this.sliderInactiveColor,
    this.sliderThumbColor,
    this.sliderOverlayColor,
    required this.onVolumeChange,
  });

  final String tooltip;
  final IconData icon;
  final bool active;
  final bool disabled;
  final int volumeValue;
  final Color? sliderActiveColor;
  final Color? sliderInactiveColor;
  final Color? sliderThumbColor;
  final Color? sliderOverlayColor;
  final ValueChanged<int> onVolumeChange;

  @override
  State<_PlayerCompactVolumeAction> createState() =>
      _PlayerCompactVolumeActionState();
}

class _PlayerCompactVolumeActionState
    extends State<_PlayerCompactVolumeAction> {
  static const _popoverSize = Size(48, 116);
  static const _popoverBackground = Color(0xf5222222);
  static const _popoverBorder = Color(0x2effffff);
  static const _popoverShadow = Color(0x6b000000);
  static const _sliderActive = Color(0xf5ffffff);
  static const _sliderInactive = Color(0x52ffffff);

  final _tapRegionGroup = Object();
  OverlayEntry? _popoverEntry;
  var _open = false;
  var _popoverRebuildScheduled = false;

  @override
  void didUpdateWidget(covariant _PlayerCompactVolumeAction oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_open) {
      _schedulePopoverRebuild();
    }
  }

  @override
  void dispose() {
    _removePopover();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TapRegion(
      groupId: _tapRegionGroup,
      onTapOutside: (_) {
        _closePopover();
      },
      child: SizedBox(
        width: 36,
        height: 36,
        child: _PlayerIconButton(
          key: const ValueKey('MediaControl.CompactVolumeButton'),
          tooltip: widget.tooltip,
          icon: widget.icon,
          active: widget.active || _open,
          disabled: widget.disabled,
          onPressed: _togglePopover,
        ),
      ),
    );
  }

  void _togglePopover() {
    if (_open) {
      _closePopover();
    } else {
      _openPopover();
    }
  }

  void _openPopover() {
    if (_open) {
      return;
    }
    setState(() {
      _open = true;
    });
    _popoverEntry = OverlayEntry(builder: _buildPopoverOverlay);
    Overlay.of(context, rootOverlay: true).insert(_popoverEntry!);
  }

  void _closePopover() {
    if (!_open) {
      return;
    }
    setState(() {
      _open = false;
    });
    _removePopover();
  }

  void _removePopover() {
    _popoverEntry?.remove();
    _popoverEntry = null;
  }

  void _schedulePopoverRebuild() {
    if (_popoverRebuildScheduled) {
      return;
    }
    _popoverRebuildScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _popoverRebuildScheduled = false;
      if (!mounted) {
        return;
      }
      _popoverEntry?.markNeedsBuild();
    });
  }

  Widget _buildPopoverOverlay(BuildContext context) {
    final buttonBox = this.context.findRenderObject()! as RenderBox;
    final overlayBox =
        Overlay.of(this.context, rootOverlay: true).context.findRenderObject()!
            as RenderBox;
    final buttonTopRight = overlayBox.globalToLocal(
      buttonBox.localToGlobal(Offset(buttonBox.size.width, 0)),
    );
    final decoration = BoxDecoration(
      color: _popoverBackground,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: _popoverBorder),
      boxShadow: const [
        BoxShadow(color: _popoverShadow, offset: Offset(0, 16), blurRadius: 36),
      ],
    );
    return Positioned(
      left: buttonTopRight.dx - _popoverSize.width - 6,
      top: buttonTopRight.dy - _popoverSize.height - 8,
      width: _popoverSize.width,
      height: _popoverSize.height,
      child: TapRegion(
        groupId: _tapRegionGroup,
        child: Material(
          color: Colors.transparent,
          child: DecoratedBox(
            key: const ValueKey('MediaControl.CompactVolumePopover'),
            decoration: decoration,
            child: VolumeSlider(
              value: widget.volumeValue,
              disabled: widget.disabled,
              activeTrackColor: _sliderActive,
              inactiveTrackColor: _sliderInactive,
              thumbColor: Colors.white,
              overlayColor: Colors.transparent,
              orientation: VolumeSliderOrientation.vertical,
              verticalHeight: _popoverSize.height,
              verticalTrackLength: 96,
              trackHeight: 2,
              thumbRadius: 6,
              overlayRadius: 6,
              verticalTooltipSide: VolumeSliderVerticalTooltipSide.left,
              tooltipBackgroundColor: _popoverBackground,
              tooltipForegroundColor: Colors.white,
              showTooltipOnMount: true,
              onChange: widget.onVolumeChange,
            ),
          ),
        ),
      ),
    );
  }
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

  @override
  void didUpdateWidget(covariant PlayerVolumeMenuItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.volumeValue != widget.volumeValue) {
      _liveValue = widget.volumeValue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const ValueKey('MediaControl.VolumeMenuItem'),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          Tooltip(
            message: widget.label,
            child: SizedBox(
              width: 20,
              height: 32,
              child: IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 20,
                  height: 32,
                ),
                style: IconButton.styleFrom(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  minimumSize: const Size(20, 32),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
                color: MediaControlColors.textStrongFor(context),
                disabledColor: MediaControlColors.textStrongFor(
                  context,
                ).withValues(alpha: 0.46),
                icon: Icon(
                  playerVolumeIcon(_liveValue, widget.muted),
                  size: 18,
                ),
                onPressed: widget.disabled ? null : widget.onToggleMute,
              ),
            ),
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
