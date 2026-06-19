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
  final _compactVolumeKey = GlobalKey<_PlayerCompactVolumeActionState>();
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
    final resolvedWidth = _resolvedMediaControlUtilityWidth(
      width: width,
      minimal: minimal,
      condensed: condensed,
      hasVoiceAssistant: onOpenVoiceAssistant != null,
      hasDesktopLyrics: onToggleDesktopLyrics != null,
    );
    final compactMinimal = minimal && (width == null ? condensed : width <= 68);
    final utilityButtonSize = compactMinimal ? 34.0 : 36.0;
    final utilityButtonPadding = compactMinimal ? 5.0 : 6.0;
    final utilityIconSize = utilityButtonSize - utilityButtonPadding * 2;
    final modeRowGap =
        minimal
            ? 6.0
            : condensed
            ? 8.0
            : 14.0;
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
              active: mode != PlaybackMode.once,
              disabled: disabled,
              buttonSize: utilityButtonSize,
              padding: utilityButtonPadding,
              iconSize: utilityIconSize,
              showLongPressProgress: false,
              holdDuration: const Duration(milliseconds: 520),
              onPressed: () {
                _compactVolumeKey.currentState?._closePopover();
                _cyclePlaybackMode(
                  mode: mode,
                  onToggleShuffle: onToggleShuffle,
                  onToggleRepeat: onToggleRepeat,
                  onToggleRepeatOne: onToggleRepeatOne,
                );
              },
              onLongPress: () {
                _showPlaybackModeMenuClosingVolume(
                  modeButtonContext,
                  i18n: i18n,
                  mode: mode,
                  onToggleShuffle: onToggleShuffle,
                  onToggleRepeat: onToggleRepeat,
                  onToggleRepeatOne: onToggleRepeatOne,
                );
              },
              onSecondaryTap: () {
                _showPlaybackModeMenuClosingVolume(
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
            disabled: false,
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
                  child:
                      condensed
                          ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _PlayerCompactVolumeAction(
                                key: _compactVolumeKey,
                                tooltip:
                                    isMuted
                                        ? i18n.t('player.unmute')
                                        : i18n.t('player.mute'),
                                icon: playerVolumeIcon(
                                  _liveVolumeValue,
                                  isMuted,
                                ),
                                disabled: false,
                                volumeValue: volumeValue,
                                sliderActiveColor: sliderActiveColor,
                                sliderInactiveColor: sliderInactiveColor,
                                sliderThumbColor: sliderThumbColor,
                                sliderOverlayColor: sliderOverlayColor,
                                onVolumeChange: _handleVolumeChange,
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
                                  key: const ValueKey(
                                    'MediaControl.VolumeButton',
                                  ),
                                  tooltip:
                                      isMuted
                                          ? i18n.t('player.unmute')
                                          : i18n.t('player.mute'),
                                  icon: playerVolumeIcon(
                                    _liveVolumeValue,
                                    isMuted,
                                  ),
                                  active: isMuted,
                                  disabled: false,
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
                                    disabled: false,
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

  void _handleVolumeChange(int value) {
    setState(() {
      _liveVolumeValue = value;
    });
    widget.onVolumeChange(value);
  }

  void _showPlaybackModeMenuClosingVolume(
    BuildContext context, {
    required SmPlayerI18n i18n,
    required PlaybackMode mode,
    required VoidCallback onToggleShuffle,
    required VoidCallback onToggleRepeat,
    required VoidCallback onToggleRepeatOne,
  }) {
    _compactVolumeKey.currentState?._closePopover();
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
  required bool hasVoiceAssistant,
  required bool hasDesktopLyrics,
}) {
  final modeButtonCount =
      2 + (hasVoiceAssistant ? 1 : 0) + (hasDesktopLyrics ? 1 : 0);
  final compactWidth = modeButtonCount * 36.0 + (modeButtonCount - 1) * 8.0;
  final minimalWidth = modeButtonCount * 34.0 + (modeButtonCount - 1) * 6.0;
  if (minimal) {
    return condensed ? minimalWidth : max(80, minimalWidth);
  }
  if (condensed) {
    return max(hasVoiceAssistant ? 140 : 132, compactWidth);
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
  final utilityWidth = _mediaControlUtilityWidth(
    minimal: minimal,
    condensed: condensed,
    hasVoiceAssistant: hasVoiceAssistant,
    hasDesktopLyrics: hasDesktopLyrics,
  );
  return max(width ?? utilityWidth, utilityWidth);
}

class _PlayerCompactVolumeAction extends StatefulWidget {
  const _PlayerCompactVolumeAction({
    super.key,
    required this.tooltip,
    required this.icon,
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
  static const _sliderInactive = Color(0x52ffffff);
  static const _popoverGlassSettings = LiquidGlassSettings(
    blur: 46,
    thickness: 20,
    refractiveIndex: 1.06,
    saturation: 1.65,
    chromaticAberration: 0,
    lightIntensity: 0.1,
    ambientStrength: 0.08,
    glowIntensity: 0.04,
    glassColor: _popoverBackground,
    standardOpacityMultiplier: 0.24,
  );

  final _tapRegionGroup = Object();
  OverlayEntry? _popoverEntry;
  var _open = false;

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
          active: _open,
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

  Widget _buildPopoverOverlay(BuildContext context) {
    final buttonBox = this.context.findRenderObject()! as RenderBox;
    final overlayBox =
        Overlay.of(this.context, rootOverlay: true).context.findRenderObject()!
            as RenderBox;
    final buttonTopRight = overlayBox.globalToLocal(
      buttonBox.localToGlobal(Offset(buttonBox.size.width, 0)),
    );
    final decoration = BoxDecoration(
      borderRadius: BorderRadius.circular(8),
      boxShadow: const [
        BoxShadow(color: _popoverShadow, offset: Offset(0, 16), blurRadius: 36),
      ],
    );
    return Positioned(
      left: buttonTopRight.dx - _popoverSize.width + 6,
      top: buttonTopRight.dy - _popoverSize.height - 8,
      width: _popoverSize.width,
      height: _popoverSize.height,
      child: TapRegion(
        groupId: _tapRegionGroup,
        child: Material(
          color: Colors.transparent,
          child: DecoratedBox(
            decoration: decoration,
            child: SizedBox(
              key: const ValueKey('MediaControl.CompactVolumePopover'),
              width: _popoverSize.width,
              height: _popoverSize.height,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: GlassContainer(
                      width: _popoverSize.width,
                      height: _popoverSize.height,
                      useOwnLayer: true,
                      quality: GlassQuality.minimal,
                      clipBehavior: Clip.hardEdge,
                      shape: const LiquidRoundedRectangle(borderRadius: 8),
                      settings: _popoverGlassSettings,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _popoverBorder),
                        ),
                      ),
                    ),
                  ),
                  VolumeSlider(
                    value: widget.volumeValue,
                    disabled: widget.disabled,
                    activeTrackColor:
                        widget.sliderActiveColor ?? MediaControlColors.accent,
                    inactiveTrackColor:
                        widget.sliderInactiveColor ?? _sliderInactive,
                    thumbColor:
                        widget.sliderThumbColor ?? MediaControlColors.accent,
                    overlayColor:
                        widget.sliderOverlayColor ?? Colors.transparent,
                    orientation: VolumeSliderOrientation.vertical,
                    verticalHeight: _popoverSize.height,
                    verticalTrackLength: 96,
                    trackHeight: 2,
                    thumbRadius: 6,
                    overlayRadius: 6,
                    verticalTooltipSide: VolumeSliderVerticalTooltipSide.left,
                    tooltipBackgroundColor: _popoverBackground,
                    tooltipForegroundColor: Colors.white,
                    tooltipBorderColor: _popoverBorder,
                    tooltipShadow: const BoxShadow(
                      color: Color(0x57000000),
                      offset: Offset(0, 8),
                      blurRadius: 18,
                    ),
                    showTooltipOnMount: true,
                    showTooltipOnHoverOrFocus: false,
                    onChange: (value) {
                      widget.onVolumeChange(value);
                      _popoverEntry?.markNeedsBuild();
                    },
                  ),
                ],
              ),
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
                  overlayColor: Colors.transparent,
                ),
                color: MediaControlColors.textStrongFor(context),
                disabledColor: MediaControlColors.textStrongFor(
                  context,
                ).withValues(alpha: 0.46),
                icon: MediaControlIconGlyph(
                  icon: playerVolumeIcon(_liveValue, widget.muted),
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
