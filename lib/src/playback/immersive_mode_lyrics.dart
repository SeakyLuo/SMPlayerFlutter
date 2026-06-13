import 'dart:async';
import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smplayer_flutter/src/app/smplayer_vector_icons.dart';
import 'package:smplayer_flutter/src/app/text_icon_button.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
import 'package:smplayer_flutter/src/playback/media_control.dart';
import 'package:smplayer_flutter/src/playback/immersive_mode_theme.dart';
import 'package:smplayer_flutter/src/playback/immersive_mode_top_button_style.dart';

String formatImmersiveModeLyricSeekTimeValue(double seconds) {
  final wholeSeconds = seconds.floor();
  final minutes = wholeSeconds ~/ 60;
  final remainingSeconds = wholeSeconds % 60;
  return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
}

class _ImmersiveLyricsLine {
  const _ImmersiveLyricsLine({
    required this.id,
    required this.text,
    required this.seekSeconds,
    required this.active,
  });

  final int id;
  final String text;
  final double seekSeconds;
  final bool active;
}

List<_ImmersiveLyricsLine> _getImmersiveLyricsLines({
  required LyricsSnapshot? lyrics,
  required double progressSeconds,
  required double durationSeconds,
}) {
  final snapshot = lyrics;
  if (snapshot == null || snapshot.lines.isEmpty) {
    return const [];
  }

  final lines =
      snapshot.lines.where((line) => line.text.trim().isNotEmpty).toList();
  if (lines.isEmpty) {
    return const [];
  }
  final lastLineIndex = max(1, lines.length - 1);
  final progressRatio =
      durationSeconds > 0 ? (progressSeconds / durationSeconds).clamp(0, 1) : 0;
  final timedLines = lines.where((line) => line.timestampMs != null).toList();
  if (timedLines.isNotEmpty) {
    final progressMs = (progressSeconds * 1000).floor();
    var activeLineId = timedLines.first.id;
    for (final line in timedLines) {
      if (line.timestampMs! > progressMs) {
        break;
      }
      activeLineId = line.id;
    }
    return [
      for (var index = 0; index < lines.length; index += 1)
        _ImmersiveLyricsLine(
          id: lines[index].id,
          text: lines[index].text.trim(),
          seekSeconds:
              lines[index].timestampMs == null
                  ? durationSeconds * (index / lastLineIndex)
                  : lines[index].timestampMs! / 1000,
          active: lines[index].id == activeLineId,
        ),
    ];
  }

  final activeIndex = min(
    lines.length - 1,
    (lines.length * progressRatio).floor(),
  );
  return [
    for (var index = 0; index < lines.length; index += 1)
      _ImmersiveLyricsLine(
        id: lines[index].id,
        text: lines[index].text.trim(),
        seekSeconds: durationSeconds * (index / lastLineIndex),
        active: index == activeIndex,
      ),
  ];
}

class ImmersiveModeLyrics extends ConsumerStatefulWidget {
  const ImmersiveModeLyrics({
    super.key,
    required this.song,
    required this.progressSeconds,
    required this.durationSeconds,
    required this.isPlaying,
    required this.i18n,
    required this.onSeekAndPlay,
    required this.refreshRevision,
    required this.compact,
    required this.midCompact,
    required this.anchorOffset,
  });

  final LibrarySong? song;
  final double progressSeconds;
  final double durationSeconds;
  final bool isPlaying;
  final SmPlayerI18n i18n;
  final ValueChanged<double> onSeekAndPlay;
  final int refreshRevision;
  final bool compact;
  final bool midCompact;
  final double? anchorOffset;

  @override
  ConsumerState<ImmersiveModeLyrics> createState() =>
      _ImmersiveModeLyricsState();
}

class _ImmersiveModeLyricsState extends ConsumerState<ImmersiveModeLyrics> {
  final _scrollController = ScrollController();
  final _lineKeys = <int, GlobalKey>{};
  LyricsSnapshot? _lyrics;
  int? _lyricsSongId;
  var _loading = false;
  var _previewing = false;
  var _dragging = false;
  var _lyricsDragMoved = false;
  var _lyricsDragPendingDeltaY = 0.0;
  var _scrollActiveAfterBuild = false;
  int? _previewIndex;
  Timer? _restoreTimer;

  @override
  void initState() {
    super.initState();
    _loadLyrics();
  }

  @override
  void didUpdateWidget(covariant ImmersiveModeLyrics oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.song?.id != widget.song?.id ||
        oldWidget.refreshRevision != widget.refreshRevision) {
      _loadLyrics();
    }
    final lines = _displayLines();
    final activeIndex = lines.indexWhere((line) => line.active);
    if (!_previewing && activeIndex >= 0) {
      _scrollActiveLineIntoView();
    }
  }

  @override
  void dispose() {
    _restoreTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadLyrics() async {
    final song = widget.song;
    if (song == null) {
      setState(() {
        _lyricsSongId = null;
        _lyrics = null;
        _loading = false;
      });
      return;
    }

    setState(() {
      _lyricsSongId = song.id;
      _lyrics = null;
      _loading = true;
      _previewing = false;
      _dragging = false;
      _lyricsDragMoved = false;
      _lyricsDragPendingDeltaY = 0;
      _previewIndex = null;
    });
    final lyrics = await ref
        .read(libraryRepositoryProvider)
        .getSongLyrics(song.id);
    if (!mounted || _lyricsSongId != song.id) {
      return;
    }
    setState(() {
      _lyrics = lyrics;
      _loading = false;
      _scrollActiveAfterBuild = true;
    });
  }

  List<_ImmersiveLyricsLine> _displayLines() {
    final song = widget.song;
    final adjustedProgressSeconds = max(
      0.0,
      widget.progressSeconds + (song?.lyricsOffsetMs ?? 0) / 1000,
    );
    final effectiveDuration = resolvePlayerDurationSeconds(
      widget.durationSeconds,
      song,
    );
    return _getImmersiveLyricsLines(
      lyrics: _lyrics,
      progressSeconds: adjustedProgressSeconds,
      durationSeconds: effectiveDuration,
    );
  }

  bool _scrollToIndex(int index) {
    if (!_scrollController.hasClients) {
      return false;
    }
    final lineContext = _lineKeys[index]?.currentContext;
    if (lineContext == null) {
      return false;
    }
    final lineBox = lineContext.findRenderObject();
    if (lineBox is! RenderBox) {
      return false;
    }
    final position = _scrollController.position;
    final estimatedTargetOffset =
        index * (_lyricMinHeight() + _lyricGap()) +
        _lyricMinHeight() / 2 -
        _anchorOffset(position.viewportDimension);
    final viewport = RenderAbstractViewport.maybeOf(lineBox);
    final targetOffset =
        viewport == null
            ? estimatedTargetOffset
            : max(
              viewport.getOffsetToReveal(lineBox, 0).offset +
                  lineBox.size.height / 2 -
                  _anchorOffset(position.viewportDimension),
              estimatedTargetOffset,
            );
    _scrollController.animateTo(
      targetOffset.clamp(position.minScrollExtent, position.maxScrollExtent),
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
    );
    return true;
  }

  void _scrollActiveLineIntoView([int attempt = 0]) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final activeIndex = _displayLines().indexWhere((line) => line.active);
      if (activeIndex >= 0) {
        final didScroll = _scrollToIndex(activeIndex);
        if (!didScroll && attempt < 3) {
          _scrollActiveLineIntoView(attempt + 1);
        }
      }
    });
  }

  double _anchorOffset(double viewportHeight) {
    return widget.anchorOffset ?? viewportHeight / 2;
  }

  void _previewFromScroll({bool scheduleRestore = true}) {
    final lines = _displayLines();
    if (lines.isEmpty || !_scrollController.hasClients) {
      return;
    }
    setState(() {
      _previewing = true;
      _previewIndex = _nearestLineIndex(lines);
    });
    if (scheduleRestore) {
      _scheduleLyricsRestore();
    }
  }

  void _scheduleLyricsRestore() {
    _restoreTimer?.cancel();
    _restoreTimer = Timer(const Duration(seconds: 5), _restoreLyricsToPlayback);
  }

  void _restoreLyricsToPlayback() {
    if (!mounted) {
      return;
    }
    setState(() {
      _previewing = false;
      _dragging = false;
      _lyricsDragMoved = false;
      _lyricsDragPendingDeltaY = 0;
      _previewIndex = null;
    });
    final activeIndex = _displayLines().indexWhere((line) => line.active);
    if (activeIndex >= 0) {
      _scrollToIndex(activeIndex);
    }
  }

  void _previewFromWheel() {
    final lines = _displayLines();
    if (lines.isEmpty) {
      return;
    }
    _restoreTimer?.cancel();
    setState(() {
      _previewing = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _previewFromScroll(scheduleRestore: true);
    });
  }

  void _scrollLyricsBy(double deltaY, {bool scheduleRestore = false}) {
    if (!_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    _scrollController.jumpTo(
      (position.pixels + deltaY).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _previewFromScroll(scheduleRestore: scheduleRestore);
      }
    });
  }

  void _beginLyricsDrag() {
    _restoreTimer?.cancel();
    _lyricsDragMoved = false;
    _lyricsDragPendingDeltaY = 0;
    if (!_dragging || !_previewing) {
      setState(() {
        _dragging = true;
        _previewing = true;
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _previewFromScroll(scheduleRestore: false);
      }
    });
  }

  void _finishLyricsDrag() {
    if (!_dragging) {
      return;
    }
    if (_lyricsDragMoved) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _previewFromScroll(scheduleRestore: true);
        }
      });
      setState(() {
        _dragging = false;
        _lyricsDragPendingDeltaY = 0;
      });
    } else {
      _restoreTimer?.cancel();
      _restoreLyricsToPlayback();
    }
  }

  int _nearestLineIndex(List<_ImmersiveLyricsLine> lines) {
    var nearestIndex = 0;
    var nearestDistance = double.infinity;
    final scrollableBox = context.findRenderObject() as RenderBox;
    final scrollableTop = scrollableBox.localToGlobal(Offset.zero).dy;
    final anchorOffset =
        _scrollController.offset + _anchorOffset(scrollableBox.size.height);
    for (var index = 0; index < lines.length; index += 1) {
      final lineBox = _lineKeys[index]?.currentContext?.findRenderObject();
      if (lineBox is! RenderBox) {
        continue;
      }
      final localTop =
          lineBox.localToGlobal(Offset.zero).dy -
          scrollableTop +
          _scrollController.offset;
      final center = localTop + lineBox.size.height / 2;
      final distance = (center - anchorOffset).abs();
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestIndex = index;
      }
    }
    return nearestIndex;
  }

  void _seekToLine(_ImmersiveLyricsLine line) {
    _restoreTimer?.cancel();
    widget.onSeekAndPlay(line.seekSeconds);
    setState(() {
      _previewing = false;
      _dragging = false;
      _lyricsDragMoved = false;
      _lyricsDragPendingDeltaY = 0;
      _previewIndex = null;
    });
  }

  double _lyricGap() {
    if (widget.compact) {
      return 10;
    }
    return widget.midCompact ? 14 : 18;
  }

  double _lyricMinHeight() {
    if (widget.compact) {
      return 0;
    }
    return widget.midCompact ? 48 : 54;
  }

  double _lyricFontSize() {
    if (widget.compact) {
      return 18;
    }
    return widget.midCompact ? 17.92 : 19.84;
  }

  double _activeLyricFontSize() {
    if (widget.compact) {
      return 22;
    }
    return widget.midCompact ? 22.72 : 26.56;
  }

  Color _lyricTextColor(ImmersiveModeThemeColors colors, bool active) {
    final dark = colors.artworkShadowOpacity > 0.3;
    if (active) {
      return dark ? const Color(0xf0ffffff) : ImmersiveModeColors.dayText;
    }
    if (dark) {
      return widget.compact ? const Color(0x29ffffff) : const Color(0x33ffffff);
    }
    return widget.compact ? const Color(0x425b697a) : const Color(0x525b697a);
  }

  @override
  Widget build(BuildContext context) {
    final colors = ImmersiveModeThemeColors.of(context);
    final topButtonColors = immersiveModeLyricSeekButtonColors(context, colors);
    final glassSettings = immersiveModeTopButtonGlassSettingsFor(colors);
    final lines = _displayLines();
    final hasLyrics = lines.isNotEmpty;
    final displayLines =
        hasLyrics
            ? lines
            : [
              _ImmersiveLyricsLine(
                id: -1,
                text:
                    _loading
                        ? widget.i18n.t('nowPlaying.loadingLyrics')
                        : widget.i18n.t('nowPlaying.noLyrics'),
                seekSeconds: 0,
                active: false,
              ),
            ];
    final previewIndex = hasLyrics && _previewing ? _previewIndex : null;
    final previewLine =
        previewIndex == null
            ? null
            : displayLines[min(previewIndex, displayLines.length - 1)];
    if (_scrollActiveAfterBuild && hasLyrics) {
      _scrollActiveAfterBuild = false;
      _scrollActiveLineIntoView();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final visualStageWidth =
            widget.compact
                ? min(360.0, constraints.maxWidth)
                : constraints.maxWidth;
        final viewportWidth = MediaQuery.sizeOf(context).width;
        final seekButtonRight =
            widget.compact
                ? (constraints.maxWidth - viewportWidth) / 2 + 10
                : 0.0;
        final seekButtonIconSize = widget.compact ? 16.0 : 18.0;
        final seekButtonGap = widget.compact ? 6.0 : 8.0;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Align(
              alignment: Alignment.center,
              child: SizedBox(
                width: visualStageWidth,
                height: constraints.maxHeight,
                child: Stack(
                  key: const ValueKey('ImmersiveMode.LyricsStage'),
                  children: [
                    LayoutBuilder(
                      builder: (context, stageConstraints) {
                        final lyricsScroll = MouseRegion(
                          cursor:
                              _dragging
                                  ? SystemMouseCursors.grabbing
                                  : SystemMouseCursors.grab,
                          child: Listener(
                            onPointerSignal: (event) {
                              if (event is PointerScrollEvent) {
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  if (mounted) {
                                    _previewFromWheel();
                                  }
                                });
                              }
                            },
                            child: ScrollConfiguration(
                              behavior: ScrollConfiguration.of(
                                context,
                              ).copyWith(
                                scrollbars: false,
                                dragDevices: {
                                  PointerDeviceKind.touch,
                                  PointerDeviceKind.mouse,
                                  PointerDeviceKind.trackpad,
                                  PointerDeviceKind.stylus,
                                  PointerDeviceKind.invertedStylus,
                                },
                              ),
                              child: GestureDetector(
                                behavior: HitTestBehavior.translucent,
                                onVerticalDragStart: (_) {
                                  _beginLyricsDrag();
                                },
                                onVerticalDragUpdate: (details) {
                                  _lyricsDragPendingDeltaY += details.delta.dy;
                                  if (!_lyricsDragMoved &&
                                      _lyricsDragPendingDeltaY.abs() < 3) {
                                    return;
                                  }
                                  final dragDelta =
                                      _lyricsDragMoved
                                          ? details.delta.dy
                                          : _lyricsDragPendingDeltaY;
                                  _lyricsDragMoved = true;
                                  _scrollLyricsBy(
                                    dragDelta * -1,
                                    scheduleRestore: false,
                                  );
                                },
                                onVerticalDragEnd: (_) {
                                  _finishLyricsDrag();
                                },
                                onVerticalDragCancel: _finishLyricsDrag,
                                child: SingleChildScrollView(
                                  key: const ValueKey(
                                    'ImmersiveMode.LyricsList',
                                  ),
                                  controller: _scrollController,
                                  padding: EdgeInsets.fromLTRB(
                                    0,
                                    stageConstraints.maxHeight / 2,
                                    widget.compact ? 0 : 20,
                                    widget.compact ? 0 : 32,
                                  ),
                                  child: Column(
                                    children: [
                                      for (
                                        var index = 0;
                                        index < displayLines.length;
                                        index += 1
                                      ) ...[
                                        Builder(
                                          builder: (context) {
                                            final line = displayLines[index];
                                            if (hasLyrics) {
                                              _lineKeys[index] =
                                                  _lineKeys[index] ??
                                                  GlobalKey();
                                            }
                                            final active = line.active;
                                            return ConstrainedBox(
                                              key:
                                                  hasLyrics
                                                      ? _lineKeys[index]
                                                      : null,
                                              constraints: BoxConstraints(
                                                minHeight: _lyricMinHeight(),
                                              ),
                                              child: Center(
                                                child: AnimatedDefaultTextStyle(
                                                  duration: const Duration(
                                                    milliseconds: 180,
                                                  ),
                                                  curve: Curves.easeOutCubic,
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    color: _lyricTextColor(
                                                      colors,
                                                      active,
                                                    ),
                                                    fontSize:
                                                        active
                                                            ? _activeLyricFontSize()
                                                            : _lyricFontSize(),
                                                    fontWeight:
                                                        widget.compact && active
                                                            ? const FontWeight(
                                                              760,
                                                            )
                                                            : const FontWeight(
                                                              620,
                                                            ),
                                                    height:
                                                        widget.compact
                                                            ? (active
                                                                ? 1.34
                                                                : 1.44)
                                                            : 1.35,
                                                  ),
                                                  child: AnimatedScale(
                                                    duration: const Duration(
                                                      milliseconds: 180,
                                                    ),
                                                    curve: Curves.easeOutCubic,
                                                    scale:
                                                        active &&
                                                                !widget.compact
                                                            ? 1.02
                                                            : 1,
                                                    child: Text(
                                                      line.text,
                                                      textAlign:
                                                          TextAlign.center,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                        if (index < displayLines.length - 1)
                                          SizedBox(height: _lyricGap()),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                        return NotificationListener<ScrollNotification>(
                          onNotification: (notification) {
                            if (notification is ScrollUpdateNotification &&
                                notification.dragDetails != null) {
                              _previewFromScroll(scheduleRestore: !_dragging);
                            }
                            return false;
                          },
                          child:
                              widget.compact
                                  ? lyricsScroll
                                  : ShaderMask(
                                    shaderCallback:
                                        (rect) => const LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Colors.transparent,
                                            Colors.black,
                                            Colors.black,
                                            Colors.transparent,
                                          ],
                                          stops: [0, 0.17, 0.83, 1],
                                        ).createShader(rect),
                                    blendMode: BlendMode.dstIn,
                                    child: lyricsScroll,
                                  ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            if (previewLine != null)
              Positioned(
                top: _anchorOffset(constraints.maxHeight),
                right: seekButtonRight,
                child: FractionalTranslation(
                  translation: const Offset(0, -0.5),
                  child: MouseRegion(
                    opaque: true,
                    cursor: SystemMouseCursors.click,
                    onEnter: (_) {
                      _restoreTimer?.cancel();
                    },
                    onExit: (_) {
                      if (_previewing) {
                        _scheduleLyricsRestore();
                      }
                    },
                    child: SmPlayerTextIconButtonTheme(
                      colors: topButtonColors,
                      child: SmPlayerTextIconButton(
                        key: const ValueKey('ImmersiveMode.LyricSeekButton'),
                        label: formatImmersiveModeLyricSeekTimeValue(
                          previewLine.seekSeconds,
                        ),
                        tooltipEnabled: false,
                        borderRadius: 999,
                        height: 34,
                        horizontalPadding: 12,
                        verticalPadding: 0,
                        iconSize: seekButtonIconSize,
                        iconGap: seekButtonGap,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        fontVariations: const [FontVariation.weight(750)],
                        glassSettings: glassSettings,
                        onPressed: () {
                          _seekToLine(previewLine);
                        },
                        iconWidget: SmPlayerPlayIcon(
                          key: const ValueKey('ImmersiveMode.LyricSeekIcon'),
                          size: seekButtonIconSize,
                        ),
                        child: Text(
                          formatImmersiveModeLyricSeekTimeValue(
                            previewLine.seekSeconds,
                          ),
                          style: const TextStyle(
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
