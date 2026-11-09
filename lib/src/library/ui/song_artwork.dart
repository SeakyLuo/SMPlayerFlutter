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
      return _RemoteArtwork(path: path, fit: fit, placeholder: fallback);
    }
    final file = File(path);
    return LayoutBuilder(
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
          fit: fit,
          cacheWidth: cacheWidth,
          cacheHeight: cacheHeight,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) {
            onError?.call();
            return fallback;
          },
        );
      },
    );
  }
}

class _RemoteArtwork extends StatefulWidget {
  const _RemoteArtwork({
    required this.path,
    required this.fit,
    required this.placeholder,
  });
  final String path;
  final BoxFit fit;
  final Widget placeholder;
  @override
  State<_RemoteArtwork> createState() => _RemoteArtworkState();
}

class _RemoteArtworkState extends State<_RemoteArtwork> {
  late Future<File?> _file = activeMusicShareAccess!.artwork(widget.path);
  @override
  void didUpdateWidget(covariant _RemoteArtwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _file = activeMusicShareAccess!.artwork(widget.path);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<File?>(
    future: _file,
    builder:
        (context, snapshot) =>
            snapshot.data == null
                ? widget.placeholder
                : SongArtwork(
                  artworkPath: snapshot.data!.path,
                  fit: widget.fit,
                  fallback: widget.placeholder,
                ),
  );
}
