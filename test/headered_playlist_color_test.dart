import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:smplayer_flutter/src/library/ui/headered_playlist_control.dart';

void main() {
  test('selectHeaderArtworkColorFromRgba matches Electron grid selection', () {
    const width = 16;
    const height = 16;
    final pixels = Uint8List(width * height * 4);

    void setPixel(int x, int y, int red, int green, int blue, int alpha) {
      final offset = (y * width + x) * 4;
      pixels[offset] = red;
      pixels[offset + 1] = green;
      pixels[offset + 2] = blue;
      pixels[offset + 3] = alpha;
    }

    setPixel(1, 1, 20, 20, 20, 255);
    setPixel(8, 8, 245, 20, 20, 255);
    setPixel(15, 15, 120, 130, 140, 255);

    expect(
      selectHeaderArtworkColorFromRgba(pixels, width, height),
      const Color(0xff78828c),
    );
  });

  test('mixHeaderArtworkColors averages first resolved artwork colors', () {
    expect(
      mixHeaderArtworkColors(const [
        Color(0xff0a141e),
        Color(0xff1e2832),
        Color(0xff323c46),
      ]),
      const Color(0xff1e2832),
    );
  });

  test('mixHeaderArtworkColors uses muted header fallback without artwork', () {
    expect(mixHeaderArtworkColors(const []), const Color(0xff9ebbd8));
  });

  test('HeaderedPlaylist day backdrop keeps muted cover wash', () {
    expect(HeaderedPlaylistThemeColors.day.backdropAlphaA, 0.18);
    expect(HeaderedPlaylistThemeColors.day.backdropAlphaB, 0.08);
    expect(HeaderedPlaylistThemeColors.day.backdropBlurAlphaA, 0.24);
    expect(HeaderedPlaylistThemeColors.day.backdropBlurAlphaB, 0.12);
    expect(HeaderedPlaylistThemeColors.day.backdropBlurAlphaC, 0.08);
    expect(HeaderedPlaylistThemeColors.day.backdropBlurAlphaD, 0.06);
  });
}
