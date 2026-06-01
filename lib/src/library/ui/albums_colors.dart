part of 'albums_page.dart';

class _AlbumsColors {
  const _AlbumsColors._();

  static Color accentFor(Brightness brightness) {
    return brightness == Brightness.dark ? accent : accentStrong;
  }

  static Color accentProgressTrackFor(Brightness brightness) {
    return brightness == Brightness.dark
        ? const Color(0x1f0078d7)
        : accentProgressTrack;
  }

  static Color textStrongFor(Brightness brightness) {
    return brightness == Brightness.dark ? const Color(0xf0f6f9fc) : textStrong;
  }

  static Color textMutedFor(Brightness brightness) {
    return brightness == Brightness.dark ? const Color(0xadcbd5e1) : textMuted;
  }

  static Color emptyStateSurfaceFor(Brightness brightness) {
    return brightness == Brightness.dark
        ? const Color(0x0bffffff)
        : emptyStateSurface;
  }

  static Color emptyStateBorderFor(Brightness brightness) {
    return brightness == Brightness.dark
        ? const Color(0x1fdee0ec)
        : emptyStateBorder;
  }

  static Color quickJumpForeground(Brightness brightness) {
    return brightness == Brightness.dark ? const Color(0xadcbd5e1) : textMuted;
  }

  static Color quickJumpActiveBackground(Brightness brightness) {
    return brightness == Brightness.dark ? const Color(0x2e0078d7) : accentSoft;
  }

  static Color quickJumpActiveForeground(Brightness brightness) {
    return brightness == Brightness.dark
        ? const Color(0xff459de2)
        : accentStrong;
  }

  static Color quickJumpDisabled(Brightness brightness) {
    return brightness == Brightness.dark ? const Color(0x40dee7f2) : disabled;
  }

  static Color previewBackdropFor(Brightness brightness) {
    return brightness == Brightness.dark
        ? const Color(0x9e04080d)
        : const Color(0x61101824);
  }

  static Color previewDialogSurfaceFor(Brightness brightness) {
    return brightness == Brightness.dark
        ? const Color(0xfa161c24)
        : const Color(0xfafafcff);
  }

  static Color previewDialogBorderFor(Brightness brightness) {
    return brightness == Brightness.dark
        ? const Color(0x1fdee0ec)
        : const Color(0xadffffff);
  }

  static Color previewDialogShadowFor(Brightness brightness) {
    return brightness == Brightness.dark
        ? const Color(0x7a000000)
        : const Color(0x2435495f);
  }

  static Color previewCloseSurfaceFor(Brightness brightness) {
    return brightness == Brightness.dark
        ? const Color(0x0effffff)
        : const Color(0x94ffffff);
  }

  static Color surfaceControlHoverFor(Brightness brightness) {
    return brightness == Brightness.dark ? const Color(0x290078d7) : accentSoft;
  }

  static const accent = Color(0xff0078d7);
  static const accentStrong = Color(0xff0063b1);
  static const accentSoft = Color(0x1a0078d7);
  static const accentProgressTrack = Color(0x1f0063b1);
  static const textStrong = Color(0xff1f252b);
  static const textMuted = Color(0xff5f625f);
  static const disabled = Color(0x3d5b697a);
  static const emptyStateSurface = Color(0x94ffffff);
  static const emptyStateBorder = Color(0x94ffffff);
}
