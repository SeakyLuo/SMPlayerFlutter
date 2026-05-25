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
    if (!file.existsSync()) {
      return fallback;
    }

    return Image.file(
      file,
      fit: fit,
      errorBuilder: (_, _, _) {
        onError?.call();
        return fallback;
      },
    );
  }
}
