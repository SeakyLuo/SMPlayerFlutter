part of 'shell_page.dart';

bool _usesNativeDesktopLyricsWindow() {
  return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
}

bool _supportsVoiceAssistant() {
  return Platform.isWindows ||
      Platform.isMacOS ||
      Platform.isIOS ||
      Platform.isAndroid;
}

class _DesktopLyricsOverlay extends StatefulWidget {
  const _DesktopLyricsOverlay({
    required this.song,
    required this.settings,
    required this.repository,
    required this.i18n,
    required this.progressSeconds,
    required this.isPlaying,
    required this.onPrevious,
    required this.onNext,
    required this.onTogglePlayPause,
    required this.onSeekOffset,
    required this.onResetOffset,
    required this.onToggleLock,
    required this.onClose,
    required this.onOpenSettings,
  });

  final LibrarySong song;
  final SettingsSnapshot settings;
  final LibraryRepository repository;
  final SmPlayerI18n i18n;
  final double progressSeconds;
  final bool isPlaying;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onTogglePlayPause;
  final ValueChanged<int> onSeekOffset;
  final VoidCallback onResetOffset;
  final VoidCallback onToggleLock;
  final VoidCallback onClose;
  final VoidCallback onOpenSettings;

  @override
  State<_DesktopLyricsOverlay> createState() => _DesktopLyricsOverlayState();
}

class _DesktopLyricsOverlayState extends State<_DesktopLyricsOverlay> {
  LyricsSnapshot? _lyrics;
  var _loadingSongId = 0;

  @override
  void initState() {
    super.initState();
    _loadLyrics();
  }

  @override
  void didUpdateWidget(covariant _DesktopLyricsOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.song.id != widget.song.id ||
        oldWidget.settings.playerLyricsSource !=
            widget.settings.playerLyricsSource) {
      _loadLyrics();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;
    final textColor = _parseShellHexColor(
      settings.desktopLyricsColor,
    ).withValues(alpha: settings.desktopLyricsOpacity / 100);
    final strokeColor = _parseShellHexColor(
      settings.desktopLyricsStrokeColor,
    ).withValues(alpha: settings.desktopLyricsOpacity / 100);
    final lyricText = _resolveDesktopLyricText(
      lyrics: _lyrics,
      song: widget.song,
      progressSeconds: widget.progressSeconds,
    );

    return IgnorePointer(
      ignoring: settings.desktopLyricsLocked,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xcc101820),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0x30ffffff)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 24,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!settings.desktopLyricsLocked)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          _DesktopLyricsIconButton(
                            tooltip: widget.i18n.t('player.previous'),
                            icon: Icons.skip_previous_rounded,
                            onPressed: widget.onPrevious,
                          ),
                          _DesktopLyricsIconButton(
                            tooltip:
                                widget.isPlaying
                                    ? widget.i18n.t('player.pause')
                                    : widget.i18n.t('player.play'),
                            icon:
                                widget.isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                            onPressed: widget.onTogglePlayPause,
                          ),
                          _DesktopLyricsIconButton(
                            tooltip: widget.i18n.t('player.next'),
                            icon: Icons.skip_next_rounded,
                            onPressed: widget.onNext,
                          ),
                          const SizedBox(width: 8),
                          _DesktopLyricsTextButton(
                            label: '-0.1s',
                            onPressed: () => widget.onSeekOffset(-100),
                          ),
                          _DesktopLyricsTextButton(
                            label: '+0.1s',
                            onPressed: () => widget.onSeekOffset(100),
                          ),
                          _DesktopLyricsIconButton(
                            tooltip: widget.i18n.t(
                              'settings.desktopLyricsResetOffset',
                            ),
                            icon: Icons.restart_alt_rounded,
                            onPressed: widget.onResetOffset,
                          ),
                          const Spacer(),
                          _DesktopLyricsIconButton(
                            tooltip: widget.i18n.t(
                              'settings.desktopLyricsLockAction',
                            ),
                            icon: Icons.lock_open_rounded,
                            onPressed: widget.onToggleLock,
                          ),
                          _DesktopLyricsIconButton(
                            tooltip: widget.i18n.t('common.settings'),
                            icon: Icons.settings_rounded,
                            onPressed: widget.onOpenSettings,
                          ),
                          _DesktopLyricsIconButton(
                            tooltip: widget.i18n.t('common.close'),
                            icon: Icons.close_rounded,
                            onPressed: widget.onClose,
                          ),
                        ],
                      ),
                    ),
                  _ScrollingStrokeText(
                    text: lyricText,
                    textColor: textColor,
                    strokeColor: strokeColor,
                    fontFamily:
                        settings.desktopLyricsFontFamily == 'system'
                            ? null
                            : settings.desktopLyricsFontFamily,
                    fontSize: settings.desktopLyricsFontSize.toDouble(),
                    fontWeight: FontWeight.w600,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _loadLyrics() async {
    final songId = widget.song.id;
    _loadingSongId = songId;
    final lyrics = await widget.repository.getSongLyrics(
      songId,
      mode: widget.settings.playerLyricsSource,
    );
    if (!mounted || _loadingSongId != songId) {
      return;
    }
    setState(() {
      _lyrics = lyrics;
    });
  }
}

class _StrokeText extends StatelessWidget {
  const _StrokeText({
    required this.text,
    required this.textColor,
    required this.strokeColor,
    required this.fontSize,
    required this.fontWeight,
    this.fontFamily,
    this.overflow = TextOverflow.ellipsis,
    this.textAlign = TextAlign.center,
  });

  final String text;
  final Color textColor;
  final Color strokeColor;
  final double fontSize;
  final FontWeight fontWeight;
  final String? fontFamily;
  final TextOverflow overflow;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final baseStyle = TextStyle(
      fontFamily: fontFamily,
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: 1.15,
    );
    return Stack(
      alignment:
          textAlign == TextAlign.left ? Alignment.centerLeft : Alignment.center,
      children: [
        Text(
          text,
          maxLines: 1,
          overflow: overflow,
          textAlign: textAlign,
          style: baseStyle.copyWith(
            foreground:
                Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 3
                  ..color = strokeColor,
          ),
        ),
        Text(
          text,
          maxLines: 1,
          overflow: overflow,
          textAlign: textAlign,
          style: baseStyle.copyWith(color: textColor),
        ),
      ],
    );
  }
}

class _ScrollingStrokeText extends StatefulWidget {
  const _ScrollingStrokeText({
    required this.text,
    required this.textColor,
    required this.strokeColor,
    required this.fontSize,
    required this.fontWeight,
    this.fontFamily,
  });

  final String text;
  final Color textColor;
  final Color strokeColor;
  final double fontSize;
  final FontWeight fontWeight;
  final String? fontFamily;

  @override
  State<_ScrollingStrokeText> createState() => _ScrollingStrokeTextState();
}

class _ScrollingStrokeTextState extends State<_ScrollingStrokeText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void didUpdateWidget(covariant _ScrollingStrokeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.fontSize != widget.fontSize ||
        oldWidget.fontFamily != widget.fontFamily) {
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: widget.fontFamily,
      fontSize: widget.fontSize,
      fontWeight: widget.fontWeight,
      height: 1.15,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          maxLines: 1,
          textDirection: TextDirection.ltr,
        )..layout();
        final overflowDistance = max(0.0, painter.width - constraints.maxWidth);
        if (overflowDistance <= 0) {
          _controller.stop();
          return _StrokeText(
            text: widget.text,
            textColor: widget.textColor,
            strokeColor: widget.strokeColor,
            fontSize: widget.fontSize,
            fontWeight: widget.fontWeight,
            fontFamily: widget.fontFamily,
          );
        }

        final durationSeconds = min(
          12,
          max(5, (overflowDistance / 28).round() + 4),
        );
        _controller.duration = Duration(seconds: durationSeconds);
        if (!_controller.isAnimating) {
          _controller.repeat(reverse: true);
        }
        return ClipRect(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final value = Curves.easeInOut.transform(_controller.value);
              return Transform.translate(
                offset: Offset(-overflowDistance * value, 0),
                child: child,
              );
            },
            child: Align(
              alignment: Alignment.centerLeft,
              widthFactor: 1,
              child: SizedBox(
                width: painter.width,
                child: _StrokeText(
                  text: widget.text,
                  textColor: widget.textColor,
                  strokeColor: widget.strokeColor,
                  fontSize: widget.fontSize,
                  fontWeight: widget.fontWeight,
                  fontFamily: widget.fontFamily,
                  overflow: TextOverflow.visible,
                  textAlign: TextAlign.left,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DesktopLyricsIconButton extends StatelessWidget {
  const _DesktopLyricsIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      color: Colors.white,
      onPressed: onPressed,
      icon:
          icon == Icons.play_arrow_rounded
              ? const SmPlayerPlayIcon(size: 20, color: Colors.white)
              : Icon(icon, size: 20),
    );
  }
}

class _DesktopLyricsTextButton extends StatelessWidget {
  const _DesktopLyricsTextButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: TextButton(
        style: TextButton.styleFrom(
          foregroundColor: Colors.white,
          visualDensity: VisualDensity.compact,
          minimumSize: const Size(46, 34),
        ),
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
}

String _resolveDesktopLyricText({
  required LyricsSnapshot? lyrics,
  required LibrarySong song,
  required double progressSeconds,
}) {
  final snapshot = lyrics;
  if (snapshot == null || snapshot.lines.isEmpty || song.duration <= 0) {
    return song.title;
  }
  final adjustedProgressSeconds = max(
    0.0,
    progressSeconds + song.lyricsOffsetMs / 1000,
  );
  final lyricText = _resolveMiniModeLyricText(
    lyrics: snapshot,
    progressSeconds: adjustedProgressSeconds,
    progressRatio: adjustedProgressSeconds / song.duration,
  );
  return lyricText.isEmpty ? song.title : lyricText;
}

Color _parseShellHexColor(String value) {
  return Color(0xff000000 + int.parse(value.substring(1), radix: 16));
}
