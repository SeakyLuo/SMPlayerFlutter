part of 'headered_playlist_control.dart';

class HeaderedPlaylistThemeColors
    extends ThemeExtension<HeaderedPlaylistThemeColors> {
  const HeaderedPlaylistThemeColors({
    required this.pageSurface,
    required this.heroCover,
    required this.textStrong,
    required this.textMuted,
    required this.listSurface,
    required this.listBorder,
    required this.listShadow,
    required this.scrollbarThumb,
    required this.scrollbarThumbHover,
    required this.coverInset,
    required this.coverShadow,
    required this.coverA,
    required this.coverB,
    required this.commandText,
    required this.commandControl,
    required this.commandControlHover,
    required this.commandControlBorder,
    required this.backdropAlphaA,
    required this.backdropAlphaB,
    required this.backdropBlurAlphaA,
    required this.backdropBlurAlphaB,
    required this.backdropBlurAlphaC,
    required this.backdropBlurAlphaD,
    required this.coverFallbackGradient,
    required this.coverFallbackColor,
    required this.compactListSurface,
    required this.compactListBorder,
    required this.compactListShadows,
  });

  final Color pageSurface;
  final Color heroCover;
  final Color textStrong;
  final Color textMuted;
  final Color listSurface;
  final Color listBorder;
  final Color listShadow;
  final Color scrollbarThumb;
  final Color scrollbarThumbHover;
  final Color coverInset;
  final Color coverShadow;
  final Color coverA;
  final Color coverB;
  final Color commandText;
  final Color commandControl;
  final Color commandControlHover;
  final Color commandControlBorder;
  final double backdropAlphaA;
  final double backdropAlphaB;
  final double backdropBlurAlphaA;
  final double backdropBlurAlphaB;
  final double backdropBlurAlphaC;
  final double backdropBlurAlphaD;
  final Gradient? coverFallbackGradient;
  final Color? coverFallbackColor;
  final Color compactListSurface;
  final Color compactListBorder;
  final List<BoxShadow> compactListShadows;

  static const day = HeaderedPlaylistThemeColors(
    pageSurface: Color(0xfff6f9fc),
    heroCover: Color(0xff5b87b6),
    textStrong: Color(0xff1f252b),
    textMuted: Color(0xff5f625f),
    listSurface: Color(0xc2ffffff),
    listBorder: Color(0x2e7e8b9a),
    listShadow: Color(0x14685870),
    scrollbarThumb: Color(0x705b697a),
    scrollbarThumbHover: Color(0xa6435060),
    coverInset: Color(0x9effffff),
    coverShadow: Color(0x38364456),
    coverA: Color(0xff6794c6),
    coverB: Color(0xff6f7fc8),
    commandText: Color(0xff1f252b),
    commandControl: Color(0xa8ffffff),
    commandControlHover: Color(0xdbffffff),
    commandControlBorder: Color(0x2e768497),
    backdropAlphaA: 0.32,
    backdropAlphaB: 0.16,
    backdropBlurAlphaA: 0.48,
    backdropBlurAlphaB: 0.24,
    backdropBlurAlphaC: 0.18,
    backdropBlurAlphaD: 0.12,
    coverFallbackGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0x330078d7), Color(0xb8ffffff)],
    ),
    coverFallbackColor: null,
    compactListSurface: Color(0xb8ffffff),
    compactListBorder: Color(0xa8ffffff),
    compactListShadows: [
      BoxShadow(
        color: Color(0x1a212d3e),
        offset: Offset(0, 18),
        blurRadius: 42,
      ),
      BoxShadow(
        color: Color(0x6bffffff),
        offset: Offset(0, 0),
        blurRadius: 0,
        spreadRadius: -1,
      ),
    ],
  );

  static const night = HeaderedPlaylistThemeColors(
    pageSurface: Color(0xff0f1318),
    heroCover: Color(0xff5b87b6),
    textStrong: Color(0xf0f6f9fc),
    textMuted: Color(0xadcbd5e1),
    listSurface: Color(0xc7171c22),
    listBorder: Color(0x1fd6e0ec),
    listShadow: Color(0x3d000000),
    scrollbarThumb: Color(0x5cd0dbe8),
    scrollbarThumbHover: Color(0x94dee7f2),
    coverInset: Color(0x1affffff),
    coverShadow: Color(0x61000000),
    coverA: Color(0xff2d4f72),
    coverB: Color(0xff33406d),
    commandText: Color(0xf0f6f9fc),
    commandControl: Color(0x0effffff),
    commandControlHover: Color(0x17ffffff),
    commandControlBorder: Color(0x1fd6e0ec),
    backdropAlphaA: 0.20,
    backdropAlphaB: 0.10,
    backdropBlurAlphaA: 0.36,
    backdropBlurAlphaB: 0.18,
    backdropBlurAlphaC: 0.14,
    backdropBlurAlphaD: 0.10,
    coverFallbackGradient: null,
    coverFallbackColor: Color(0x14ffffff),
    compactListSurface: Color(0xb8171c22),
    compactListBorder: Color(0x1fd6e0ec),
    compactListShadows: [
      BoxShadow(
        color: Color(0x47000000),
        offset: Offset(0, 18),
        blurRadius: 42,
      ),
      BoxShadow(
        color: Color(0x0effffff),
        offset: Offset(0, 0),
        blurRadius: 0,
        spreadRadius: -1,
      ),
    ],
  );

  static HeaderedPlaylistThemeColors of(BuildContext context) {
    return Theme.of(context).extension<HeaderedPlaylistThemeColors>() ?? day;
  }

  @override
  HeaderedPlaylistThemeColors copyWith() {
    return this;
  }

  @override
  HeaderedPlaylistThemeColors lerp(
    covariant ThemeExtension<HeaderedPlaylistThemeColors>? other,
    double t,
  ) {
    return this;
  }
}
