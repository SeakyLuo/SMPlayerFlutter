part of 'artists_page.dart';

class _ArtistsColors {
  const _ArtistsColors._();

  static Color detailBackground(Brightness brightness) {
    return brightness == Brightness.dark
        ? const Color(0xff0f1318)
        : const Color(0xf5f8fbfe);
  }

  static Color? masterBackground(Brightness brightness) {
    return brightness == Brightness.dark ? const Color(0x06ffffff) : null;
  }

  static Color albumSection(Brightness brightness) {
    return brightness == Brightness.dark
        ? const Color(0xff171c22)
        : const Color(0xa3ffffff);
  }

  static Color albumShadow(Brightness brightness) {
    return brightness == Brightness.dark
        ? const Color(0x33000000)
        : const Color(0x14685870);
  }

  static Color panelBorder(Brightness brightness) {
    return brightness == Brightness.dark
        ? const Color(0x1fd6e0ec)
        : const Color(0x2e7e8b9a);
  }

  static Color masterBorder(Brightness brightness) {
    return brightness == Brightness.dark
        ? const Color(0x1fd6e0ec)
        : const Color(0x2e566271);
  }

  static Color emptyStateSurfaceFor(Brightness brightness) {
    return brightness == Brightness.dark
        ? const Color(0x0bffffff)
        : emptyStateSurface;
  }

  static Color emptyStateBorderFor(Brightness brightness) {
    return brightness == Brightness.dark
        ? const Color(0x1fd6e0ec)
        : emptyStateBorder;
  }

  static BoxDecoration detailEmptyStateDecoration(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return BoxDecoration(
        color: emptyStateSurfaceFor(brightness),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: emptyStateBorderFor(brightness)),
      );
    }
    return const BoxDecoration();
  }

  static BoxDecoration detailHeaderDecoration(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xf70f1319), Color(0xe00f1319)],
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x29000000),
            offset: Offset(0, 12),
            blurRadius: 24,
          ),
        ],
      );
    }

    return const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xf5f8fbfe), Color(0xe0f8fbfe)],
      ),
      boxShadow: [
        BoxShadow(
          color: Color(0x0a445870),
          offset: Offset(0, 12),
          blurRadius: 24,
        ),
      ],
    );
  }

  static BoxDecoration compactDetailHeaderDecoration(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return const BoxDecoration(color: Color(0xff0f1319));
    }

    return const BoxDecoration(color: Color(0xfff8fbfe));
  }

  static Color textStrongFor(Brightness brightness) {
    return brightness == Brightness.dark ? const Color(0xf0f6f9fc) : textStrong;
  }

  static Color textMutedFor(Brightness brightness) {
    return brightness == Brightness.dark ? const Color(0xadcbd5e1) : textMuted;
  }

  static Color detailSummaryFor(Brightness brightness) {
    return brightness == Brightness.dark
        ? const Color(0xadcbd5e1)
        : const Color(0xff111111);
  }

  static Color headerActionForeground(Brightness brightness) {
    return textStrongFor(brightness);
  }

  static Color headerActionHoverBackground(Brightness brightness) {
    return brightness == Brightness.dark
        ? const Color(0x290078d7)
        : const Color(0x0f0c1623);
  }

  static Color albumTitleHoverForeground(Brightness brightness) {
    return brightness == Brightness.dark
        ? const Color(0xff459de2)
        : accentStrong;
  }

  static Color artistRowActiveBackground(Brightness brightness) {
    return brightness == Brightness.dark
        ? const Color(0x330078d7)
        : accentProgressTrack;
  }

  static Color artistRowHoverBackground(Brightness brightness) {
    return brightness == Brightness.dark
        ? const Color(0x210078d7)
        : const Color(0x140078d7);
  }

  static Color artistRowActiveForeground(Brightness brightness) {
    return brightness == Brightness.dark ? const Color(0xff459de2) : textStrong;
  }

  static const artistRowActiveShadow = BoxShadow(
    color: Color(0x290078d7),
    offset: Offset(0, 14),
    blurRadius: 30,
  );

  static Color artistArtworkBackground(
    Brightness brightness, {
    required bool hasArtwork,
  }) {
    if (brightness != Brightness.dark) {
      return const Color(0xb8ffffff);
    }
    return hasArtwork ? const Color(0x14ffffff) : const Color(0xff1d4a70);
  }

  static BoxShadow artistArtworkShadow(
    Brightness brightness, {
    required bool elevated,
  }) {
    if (elevated) {
      return const BoxShadow(
        color: Color(0x33202d3f),
        offset: Offset(0, 12),
        blurRadius: 24,
      );
    }
    return brightness == Brightness.dark
        ? const BoxShadow(
          color: Color(0x4d000000),
          offset: Offset(0, 8),
          blurRadius: 18,
        )
        : const BoxShadow(
          color: Color(0x21202d3f),
          offset: Offset(0, 8),
          blurRadius: 18,
        );
  }

  static Color albumArtworkBackground(Brightness brightness) {
    return brightness == Brightness.dark
        ? const Color(0x14ffffff)
        : const Color(0x24818b98);
  }

  static Color artistSongListBorder(Brightness brightness) {
    return brightness == Brightness.dark
        ? const Color(0x1fd6e0ec)
        : const Color(0x297e8b9a);
  }

  static PlaylistControlItemColors? artistSongRowColors(Brightness brightness) {
    if (brightness != Brightness.dark) {
      return const PlaylistControlItemColors(
        border: Colors.transparent,
        hover: Color(0x140078d7),
        hoverBorder: Colors.transparent,
        current: Color(0x1f0078d7),
        currentForeground: accentStrong,
        currentMuted: accentStrong,
        textStrong: Color(0xff111827),
        textMuted: Color(0xff5b697a),
        artworkBackground: Colors.transparent,
        actionForeground: Color(0xb8586474),
        actionHover: Color(0x9effffff),
      );
    }
    return const PlaylistControlItemColors(
      border: Colors.transparent,
      hover: Color(0x240078d7),
      hoverBorder: Color(0x380078d7),
      current: Color(0x330078d7),
      currentForeground: Color(0xff459de2),
      currentMuted: Color(0xc276b5dc),
      textStrong: Color(0xf0f6f9fc),
      textMuted: Color(0xadcbd5e1),
      artworkBackground: Color(0x14ffffff),
      actionForeground: Color(0xadcbd5e1),
      actionHover: Color(0x2e0078d7),
    );
  }

  static Color quickJumpForeground(Brightness brightness) {
    return brightness == Brightness.dark ? const Color(0xadcbd5e1) : textMuted;
  }

  static Color quickJumpActiveBackground(Brightness brightness) {
    return brightness == Brightness.dark
        ? const Color(0x2e0078d7)
        : accentProgressTrack;
  }

  static Color quickJumpActiveForeground(Brightness brightness) {
    return brightness == Brightness.dark
        ? const Color(0xff459de2)
        : accentStrong;
  }

  static Color quickJumpDisabled(Brightness brightness) {
    return brightness == Brightness.dark ? const Color(0x40dee7f2) : disabled;
  }

  static const accent = Color(0xff0078d7);
  static const accentStrong = Color(0xff0063b1);
  static const accentProgressTrack = Color(0x1f0078d7);
  static const activeBorder = Color(0x6b0078d7);
  static const textStrong = Color(0xff1f252b);
  static const textMuted = Color(0xff5f625f);
  static const disabled = Color(0x3d5b697a);
  static const loadingSpinnerTrack = Color(0x2e0078d7);
  static const emptyStateSurface = Color(0x94ffffff);
  static const emptyStateBorder = Color(0x94ffffff);

  static Color scrollbarThumb(Brightness brightness) {
    return brightness == Brightness.dark
        ? const Color(0x7396a4b6)
        : const Color(0x805b697a);
  }

  static Color scrollbarThumbHover(Brightness brightness) {
    return brightness == Brightness.dark
        ? const Color(0x9ebccadc)
        : const Color(0xad435060);
  }
}
