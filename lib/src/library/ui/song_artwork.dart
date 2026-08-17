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
