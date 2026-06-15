part of 'playlists_page.dart';

class _PlaylistsColors {
  const _PlaylistsColors._();

  static const accentStrong = Color(0xff0063b1);
  static const textMuted = Color(0xff607085);

  static Color emptyStateSurfaceFor(Brightness brightness) {
    return brightness == Brightness.dark
        ? const Color(0xff141a22)
        : const Color(0xffffffff);
  }

  static Color emptyStateBorderFor(Brightness brightness) {
    return brightness == Brightness.dark
        ? const Color(0xff2c3745)
        : const Color(0xffd8e0ea);
  }

  static Color textStrongFor(Brightness brightness) {
    return brightness == Brightness.dark
        ? const Color(0xfff2f6fb)
        : const Color(0xff101827);
  }

  static Color textMutedFor(Brightness brightness) {
    return brightness == Brightness.dark ? const Color(0xffa5afbd) : textMuted;
  }
}
