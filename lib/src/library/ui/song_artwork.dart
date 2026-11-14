import 'dart:async';
import '../../remote/music_share_access.dart';
import '../../remote/music_share_models.dart';
import 'dart:io';

import 'package:flutter/material.dart';

import 'default_album_artwork.dart';

class SongArtwork extends StatelessWidget {
  const SongArtwork({
    super.key,
    required this.artworkPath,
    this.fit = BoxFit.cover,
    this.fallback = const DefaultAlbumArtwork(),
    this.onError,
  });

  final String? artworkPath;
  final BoxFit fit;
  final Widget fallback;
  final VoidCallback? onError;

  @override
  Widget build(BuildContext context) {
    final path = artworkPath;
    if (path == null || path.isEmpty) {
      return fallback;
    }

    if (isRemoteMusicPath(path)) {
      return _RemoteArtwork(path: path, fit: fit, fallback: fallback);
    }
    final file = File(path);
    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
          final cacheWidth =
              constraints.hasBoundedWidth && constraints.maxWidth > 0
                  ? (constraints.maxWidth * devicePixelRatio).ceil()
                  : null;
          final cacheHeight =
              cacheWidth == null &&
                      constraints.hasBoundedHeight &&
                      constraints.maxHeight > 0
                  ? (constraints.maxHeight * devicePixelRatio).ceil()
                  : null;
          return Image.file(
            file,
            key: ValueKey(path),
            fit: fit,
            cacheWidth: cacheWidth,
            cacheHeight: cacheHeight,
            gaplessPlayback: true,
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              if (wasSynchronouslyLoaded) return child;
              if (MediaQuery.disableAnimationsOf(context)) {
                return frame == null
                    ? const _ArtworkLoadingPlaceholder()
                    : child;
              }
              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: frame == null ? 0 : 1),
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                child: child,
                builder: (context, opacity, image) {
                  return Stack(
                    fit: StackFit.passthrough,
                    children: [
                      Positioned.fill(
                        child:
                            opacity == 1
                                ? const SizedBox.shrink()
                                : Opacity(
                                  opacity: 1 - opacity,
                                  child: const _ArtworkLoadingPlaceholder(),
                                ),
                      ),
                      Opacity(opacity: opacity, child: image),
                    ],
                  );
                },
              );
            },
            errorBuilder: (_, _, _) {
              onError?.call();
              return fallback;
            },
          );
        },
      ),
    );
  }
}

class _ArtworkLoadingPlaceholder extends StatefulWidget {
  const _ArtworkLoadingPlaceholder();

  @override
  State<_ArtworkLoadingPlaceholder> createState() =>
      _ArtworkLoadingPlaceholderState();
}

class _ArtworkLoadingPlaceholderState extends State<_ArtworkLoadingPlaceholder>
    with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _animation.stop();
    } else if (!_animation.isAnimating) {
      _animation.repeat();
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return RepaintBoundary(
      child: CustomPaint(
        painter: _ArtworkLoadingPainter(
          animation: _animation,
          background: colors.surfaceContainerHigh,
          highlight: colors.onSurface.withValues(alpha: 0.09),
        ),
        child: Center(
          child: FractionallySizedBox(
            widthFactor: 0.56,
            heightFactor: 0.56,
            child: RepaintBoundary(
              child: Opacity(
                opacity: 0.5,
                child: Image.asset(
                  'assets/branding/app-icon.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ArtworkLoadingPainter extends CustomPainter {
  _ArtworkLoadingPainter({
    required this.animation,
    required this.background,
    required this.highlight,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final Color background;
  final Color highlight;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(bounds, Paint()..color = background);
    final bandWidth = size.width * 0.7;
    final left = -bandWidth + (size.width + bandWidth) * animation.value;
    final gradient = LinearGradient(
      begin: const Alignment(-1, -0.3),
      end: const Alignment(1, 0.3),
      colors: [
        highlight.withValues(alpha: 0),
        highlight,
        highlight.withValues(alpha: 0),
      ],
    );
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = gradient.createShader(
          Rect.fromLTWH(left, 0, bandWidth, size.height),
        ),
    );
  }

  @override
  bool shouldRepaint(covariant _ArtworkLoadingPainter oldDelegate) =>
      animation != oldDelegate.animation ||
      background != oldDelegate.background ||
      highlight != oldDelegate.highlight;
}

class _RemoteArtwork extends StatefulWidget {
  const _RemoteArtwork({
    required this.path,
    required this.fit,
    required this.fallback,
  });
  final String path;
  final BoxFit fit;
  final Widget fallback;
  @override
  State<_RemoteArtwork> createState() => _RemoteArtworkState();
}

class _RemoteArtworkState extends State<_RemoteArtwork> {
  late Future<File?> _file;
  late StreamSubscription<String> _changes;
  var _failed = false;

  @override
  void initState() {
    super.initState();
    _file = _load(widget.path);
    _changes = activeMusicShareAccess!.remoteDataChanges.listen((device) {
      if (!mounted || !_failed || Uri.parse(widget.path).host != device) return;
      setState(() {
        _failed = false;
        _file = _load(widget.path);
      });
    });
  }

  Future<File?> _load(String path) async {
    try {
      return await activeMusicShareAccess!.artwork(path);
    } catch (_) {
      if (mounted && widget.path == path) _failed = true;
      rethrow;
    }
  }

  @override
  void didUpdateWidget(covariant _RemoteArtwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _failed = false;
      _file = _load(widget.path);
    }
  }

  @override
  void dispose() {
    unawaited(_changes.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cached = activeMusicShareAccess!.cachedArtwork(widget.path);
    return FutureBuilder<File?>(
      key: ValueKey(widget.path),
      future: _file,
      initialData: cached,
      builder: (context, snapshot) {
        final file = snapshot.data;
        if (file == null && snapshot.connectionState != ConnectionState.done) {
          return const _ArtworkLoadingPlaceholder();
        }
        if (file == null) return widget.fallback;
        return SongArtwork(
          artworkPath: file.path,
          fit: widget.fit,
          fallback: widget.fallback,
        );
      },
    );
  }
}
