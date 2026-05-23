part of 'media_control.dart';

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
      key: const ValueKey('MediaControl.UtilityRows'),
      width: condensed ? 132 : 280,
      child: Padding(
        padding:
            condensed
                ? EdgeInsets.zero
                : const EdgeInsets.only(left: 12, right: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              key: const ValueKey('MediaControl.VolumeRow'),
              height: 44,
              child: Align(
                alignment: Alignment.centerRight,
                child:
                    condensed
                        ? _PlayerCompactVolumeAction(
                          tooltip:
                              isMuted
                                  ? i18n.t('player.unmute')
                                  : i18n.t('player.mute'),
                          icon: playerVolumeIcon(volumeValue, isMuted),
                          active: isMuted,
                          disabled: false,
                          volumeValue: volumeValue,
                          onVolumeChange: onVolumeChange,
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
                                  onChange: onVolumeChange,
                                ),
                              ),
                              const SizedBox(width: 14),
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
              height: 44,
              child: Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (condensed)
                      Builder(
                        builder: (modeButtonContext) {
                          return _PlayerIconButton(
                            key: const ValueKey(
                              'MediaControl.CompactModeButton',
                            ),
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
                        icon: _shuffleIcon,
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
                        icon: _repeatIcon,
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
                        icon: _repeatOneIcon,
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
                      icon: _moreIcon,
                      onPressed: onMoreClick,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
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

class PlayerVolumeMenuItem extends StatefulWidget {
  const PlayerVolumeMenuItem({
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
