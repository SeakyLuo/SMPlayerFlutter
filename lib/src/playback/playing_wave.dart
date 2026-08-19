import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:smplayer_flutter/src/library/ui/artwork_overlay_glass.dart';
import 'package:smplayer_flutter/src/playback/media_control_model.dart';
import 'package:smplayer_flutter/src/playback/media_control_provider.dart';

const smPlayerPlayingWaveSaturate150 = ColorFilter.matrix([
  1.3935,
  -0.3575,
  -0.036,
  0,
  0,
  -0.1065,
  1.1425,
  -0.036,
  0,
  0,
  -0.1065,
  -0.3575,
  1.464,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
]);

class SmPlayerPlayingWaveGlass extends StatelessWidget {
  const SmPlayerPlayingWaveGlass({
    super.key,
    required this.playing,
    this.dimension = 34,
    this.backgroundColor = artworkOverlayGlassColor,
    this.shadowColor = const Color(0x470e1620),
    this.keyPrefix = 'PlayingWave',
  });

  final bool playing;
  final double dimension;
  final Color backgroundColor;
  final Color shadowColor;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipOval(
          child: GlassContainer(
            key: ValueKey('$keyPrefix.Backdrop'),
            width: dimension,
            height: dimension,
            useOwnLayer: true,
            quality: GlassQuality.minimal,
            shape: const LiquidOval(),
            settings: LiquidGlassSettings(
              glassColor: backgroundColor,
              thickness: artworkOverlayGlassSettings.thickness,
              blur: artworkOverlayGlassSettings.blur,
              chromaticAberration:
                  artworkOverlayGlassSettings.chromaticAberration,
              lightIntensity: artworkOverlayGlassSettings.lightIntensity,
              ambientStrength: artworkOverlayGlassSettings.ambientStrength,
              refractiveIndex: artworkOverlayGlassSettings.refractiveIndex,
              saturation: artworkOverlayGlassSettings.saturation,
              glowIntensity: artworkOverlayGlassSettings.glowIntensity,
              standardOpacityMultiplier: artworkOverlayGlassOpacityMultiplier,
            ),
            clipBehavior: Clip.hardEdge,
            allowElevation: false,
            child: ColorFiltered(
              key: ValueKey('$keyPrefix.Saturate150'),
              colorFilter: smPlayerPlayingWaveSaturate150,
              child: SizedBox.square(
                dimension: dimension,
                child: SmPlayerPlayingWaveBars(
                  playing: playing,
                  keyPrefix: keyPrefix,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SmPlayerPlayingWaveBars extends ConsumerStatefulWidget {
  const SmPlayerPlayingWaveBars({
    super.key,
    required this.playing,
    this.color = Colors.white,
    this.keyPrefix = 'PlayingWave',
  });

  final bool playing;
  final Color color;
  final String keyPrefix;

  @override
  ConsumerState<SmPlayerPlayingWaveBars> createState() =>
      _SmPlayerPlayingWaveBarsState();
}

typedef _PlayingWavePlayback =
    ({int? trackId, double progressSeconds, bool seeking, bool userSeeking});

class _SmPlayerPlayingWaveBarsState
    extends ConsumerState<SmPlayerPlayingWaveBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final ProviderSubscription<_PlayingWavePlayback> _playbackSubscription;
  late _PlayingWavePlayback _playback;
  var _hasAnimated = false;

  static const _period = Duration(milliseconds: 800);
  static const _periodMilliseconds = 800.0;
  static const _staticHeights = [7.0, 12.0, 15.0, 9.0];
  static const _delays = [0.0, 0.25, 0.5, 0.75];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _period);
    final playbackProvider = mediaControlControllerProvider.select(
      (controller) => (
        trackId: controller.state.track.id,
        progressSeconds: controller.state.progressSeconds,
        seeking: controller.state.playbackStatus == PlaybackStatus.seeking,
        userSeeking: controller.state.isProgressSeeking,
      ),
    );
    _playback = ref.read(playbackProvider);
    _hasAnimated = _playback.trackId != null;
    if (_hasAnimated) {
      _controller.value = _phaseFor(_playback.progressSeconds);
    }
    _playbackSubscription = ref.listenManual(
      playbackProvider,
      (_, playback) => _syncPlaybackPosition(playback),
    );
    _syncPlaying(widget.playing);
  }

  @override
  void didUpdateWidget(SmPlayerPlayingWaveBars oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.playing != oldWidget.playing) {
      _syncPlaying(widget.playing);
    }
  }

  @override
  void dispose() {
    _playbackSubscription.close();
    _controller.dispose();
    super.dispose();
  }

  void _syncPlaybackPosition(_PlayingWavePlayback playback) {
    final trackChanged = playback.trackId != _playback.trackId;
    final seekStarted = playback.seeking && !_playback.seeking;
    final userSeekMoved =
        playback.userSeeking &&
        playback.progressSeconds != _playback.progressSeconds;
    _playback = playback;
    if (!trackChanged && !seekStarted && !userSeekMoved) {
      return;
    }
    _hasAnimated = playback.trackId != null;
    if (_hasAnimated) {
      _controller.value = _phaseFor(playback.progressSeconds);
      if (widget.playing) {
        _controller.repeat();
      }
    } else {
      _controller.stop();
      setState(() {});
    }
  }

  void _syncPlaying(bool playing) {
    if (playing) {
      _hasAnimated = true;
      _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  static double _phaseFor(double progressSeconds) {
    return (progressSeconds * 1000 % _periodMilliseconds) / _periodMilliseconds;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      key: ValueKey('${widget.keyPrefix}.Wave'),
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < _staticHeights.length; index += 1)
              _PlayingWaveBar(
                key: ValueKey('${widget.keyPrefix}.Bar.$index'),
                color: widget.color,
                height:
                    _hasAnimated
                        ? _animatedHeight(_controller.value, _delays[index])
                        : _staticHeights[index],
              ),
          ],
        );
      },
    );
  }

  static double _animatedHeight(double progress, double delay) {
    final shifted = (progress - delay) % 1;
    final triangle = shifted <= 0.5 ? shifted * 2 : (1 - shifted) * 2;
    final eased = Curves.easeInOut.transform(triangle);
    return 5 + eased * 10;
  }
}

class _PlayingWaveBar extends StatelessWidget {
  const _PlayingWaveBar({super.key, required this.color, required this.height});

  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 2,
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}
