part of 'media_control.dart';

IconData _playbackModeIcon(PlaybackMode mode) {
  return switch (mode) {
    PlaybackMode.shuffle => _shuffleIcon,
    PlaybackMode.repeat => _repeatIcon,
    PlaybackMode.repeatOne => _repeatOneIcon,
    PlaybackMode.once => _listPlaybackIcon,
  };
}

@visibleForTesting
Color selectPlayerArtworkAccentColorFromRgba(
  Uint8List rgbaPixels,
  int width,
  int height,
) {
  var selected = _defaultArtworkAccentColor;
  var selectedDistance = -1;
  for (var xIndex = 1; xIndex < _artworkColorGridDivisions; xIndex += 1) {
    for (var yIndex = 1; yIndex < _artworkColorGridDivisions; yIndex += 1) {
      final x = min(width - 1, (width * xIndex) ~/ _artworkColorGridDivisions);
      final y = min(
        height - 1,
        (height * yIndex) ~/ _artworkColorGridDivisions,
      );
      final offset = (y * width + x) * 4;
      final red = rgbaPixels[offset];
      final green = rgbaPixels[offset + 1];
      final blue = rgbaPixels[offset + 2];
      final alpha = rgbaPixels[offset + 3];

      if (alpha == 0 ||
          red < _artworkColorMinValue ||
          red > _artworkColorMaxValue ||
          green < _artworkColorMinValue ||
          green > _artworkColorMaxValue ||
          blue < _artworkColorMinValue ||
          blue > _artworkColorMaxValue) {
        continue;
      }

      final distance =
          pow(red - _artworkColorMinValue, 2) +
          pow(green - _artworkColorMinValue, 2) +
          pow(blue - _artworkColorMinValue, 2);
      if (distance > selectedDistance) {
        selected = Color.fromARGB(255, red, green, blue);
        selectedDistance = distance.toInt();
      }
    }
  }
  return selected;
}

Future<Color> extractPlayerArtworkAccentColor(String artworkPath) async {
  try {
    final bytes = await File(artworkPath).readAsBytes();
    final codec = await instantiateImageCodec(
      bytes,
    ).timeout(const Duration(seconds: 2));
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final width = image.width;
    final height = image.height;
    final byteData = await image.toByteData(format: ImageByteFormat.rawRgba);
    image.dispose();
    codec.dispose();
    if (byteData == null) {
      return _defaultArtworkAccentColor;
    }
    return selectPlayerArtworkAccentColorFromRgba(
      byteData.buffer.asUint8List(),
      width,
      height,
    );
  } on Object {
    return _defaultArtworkAccentColor;
  }
}
