part of 'headered_playlist_control.dart';

const _defaultHeaderArtworkColor = Color(0xff5b87b6);
const _headerArtworkColorMinValue = 10;
const _headerArtworkColorMaxValue = 205;
const _headerArtworkColorGridDivisions = 16;

@visibleForTesting
Color selectHeaderArtworkColorFromRgba(
  Uint8List rgbaPixels,
  int width,
  int height,
) {
  var selected = _defaultHeaderArtworkColor;
  var selectedDistance = -1;
  for (var xIndex = 1; xIndex < _headerArtworkColorGridDivisions; xIndex += 1) {
    for (
      var yIndex = 1;
      yIndex < _headerArtworkColorGridDivisions;
      yIndex += 1
    ) {
      final x = min(
        width - 1,
        (width * xIndex) ~/ _headerArtworkColorGridDivisions,
      );
      final y = min(
        height - 1,
        (height * yIndex) ~/ _headerArtworkColorGridDivisions,
      );
      final offset = (y * width + x) * 4;
      final red = rgbaPixels[offset];
      final green = rgbaPixels[offset + 1];
      final blue = rgbaPixels[offset + 2];
      final alpha = rgbaPixels[offset + 3];

      if (alpha == 0 ||
          red < _headerArtworkColorMinValue ||
          red > _headerArtworkColorMaxValue ||
          green < _headerArtworkColorMinValue ||
          green > _headerArtworkColorMaxValue ||
          blue < _headerArtworkColorMinValue ||
          blue > _headerArtworkColorMaxValue) {
        continue;
      }

      final distance =
          pow(red - _headerArtworkColorMinValue, 2) +
          pow(green - _headerArtworkColorMinValue, 2) +
          pow(blue - _headerArtworkColorMinValue, 2);
      if (distance > selectedDistance) {
        selected = Color.fromARGB(255, red, green, blue);
        selectedDistance = distance.toInt();
      }
    }
  }
  return selected;
}

@visibleForTesting
Color mixHeaderArtworkColors(List<Color> colors) {
  if (colors.isEmpty) {
    return _defaultHeaderArtworkColor;
  }
  var red = 0;
  var green = 0;
  var blue = 0;
  for (final color in colors) {
    red += (color.r * 255).round().clamp(0, 255);
    green += (color.g * 255).round().clamp(0, 255);
    blue += (color.b * 255).round().clamp(0, 255);
  }
  return Color.fromARGB(
    255,
    (red / colors.length).round(),
    (green / colors.length).round(),
    (blue / colors.length).round(),
  );
}

extension _HeaderedPlaylistControlArtwork on _HeaderedPlaylistControlState {
  List<LibrarySong> _visibleSongs(Map<int, LibrarySong> songsById) {
    final orderedSongIds = _orderedSongIds;
    if (orderedSongIds == null) {
      return widget.songs;
    }

    final orderedSongIdSet = orderedSongIds.toSet();
    return [
      ...orderedSongIds
          .map((songId) => songsById[songId])
          .whereType<LibrarySong>(),
      ...widget.songs.where((song) => !orderedSongIdSet.contains(song.id)),
    ];
  }

  void _refreshPlaylistArtwork() {
    if (widget.type == HeaderedPlaylistType.album) {
      _playlistArtworkSignature = '';
      _resolvedPlaylistArtworkUrls = const [];
      _refreshHeaderArtworkColor(_currentHeaderArtworkUrls());
      return;
    }

    final songs = widget.headerSongs ?? widget.songs;
    final signature = getPlaylistArtworkSignature(songs);
    if (signature == _playlistArtworkSignature) {
      return;
    }

    _playlistArtworkSignature = signature;
    final cachedArtworkUrls = getCachedPlaylistArtworkUrls(signature);
    if (cachedArtworkUrls != null) {
      _resolvedPlaylistArtworkUrls = cachedArtworkUrls;
      _refreshHeaderArtworkColor(_currentHeaderArtworkUrls());
      return;
    }

    _resolvedPlaylistArtworkUrls = const [];
    _refreshHeaderArtworkColor(_currentHeaderArtworkUrls());
    final generation = ++_playlistArtworkGeneration;
    unawaited(
      resolvePlaylistArtworkUrls(
        songs,
        ref.read(libraryRepositoryProvider),
      ).then((artworkUrls) {
        cachePlaylistArtworkUrls(signature, artworkUrls);
        if (!mounted ||
            generation != _playlistArtworkGeneration ||
            signature != _playlistArtworkSignature) {
          return;
        }
        _refreshHeaderArtworkColor(getPlaylistArtworkDisplayUrls(artworkUrls));
        _updateState(() {
          _resolvedPlaylistArtworkUrls = artworkUrls;
        });
      }),
    );
  }

  List<String> _currentHeaderArtworkUrls() {
    if (widget.type == HeaderedPlaylistType.album) {
      return widget.artworkUrl.isEmpty ? const [] : [widget.artworkUrl];
    }
    return getPlaylistArtworkDisplayUrls(_resolvedPlaylistArtworkUrls);
  }

  void _refreshHeaderArtworkColor(List<String> artworkUrls) {
    final signature = artworkUrls.take(4).join('\n');
    if (signature == _headerArtworkColorSignature) {
      return;
    }
    _headerArtworkColorSignature = signature;
    if (signature.isEmpty) {
      _headerCoverColor = _defaultHeaderArtworkColor;
      return;
    }

    final generation = ++_headerArtworkColorGeneration;
    unawaited(
      Future.wait(artworkUrls.take(4).map(_extractHeaderArtworkColor)).then((
        colors,
      ) {
        if (!mounted ||
            generation != _headerArtworkColorGeneration ||
            signature != _headerArtworkColorSignature) {
          return;
        }
        final nextColor = mixHeaderArtworkColors(colors);
        if (nextColor == _headerCoverColor) {
          return;
        }
        _updateState(() {
          _headerCoverColor = nextColor;
        });
      }),
    );
  }

  Future<Color> _extractHeaderArtworkColor(String artworkPath) async {
    try {
      final bytes = await File(artworkPath).readAsBytes();
      final codec = await instantiateImageCodec(
        bytes,
      ).timeout(const Duration(seconds: 2));
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final byteData = await image.toByteData(format: ImageByteFormat.rawRgba);
      final width = image.width;
      final height = image.height;
      image.dispose();
      codec.dispose();
      if (byteData == null) {
        return _defaultHeaderArtworkColor;
      }
      return selectHeaderArtworkColorFromRgba(
        byteData.buffer.asUint8List(),
        width,
        height,
      );
    } on Object {
      return _defaultHeaderArtworkColor;
    }
  }
}
