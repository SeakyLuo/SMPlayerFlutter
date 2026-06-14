part of 'music_library_page.dart';

Map<String, int> _buildQuickJumpMap(
  List<LibrarySong> songs,
  MusicLibrarySortCriterion criterion,
  SmPlayerI18n i18n,
) {
  final indexes = <String, int>{};
  for (var index = 0; index < songs.length; index += 1) {
    final bucket = _quickJumpBucket(songs[index], criterion, i18n);
    indexes.putIfAbsent(bucket, () => index);
  }
  return indexes;
}

String _quickJumpBucket(
  LibrarySong song,
  MusicLibrarySortCriterion criterion,
  SmPlayerI18n i18n,
) {
  final value = _quickJumpValue(song, criterion, i18n).trim();
  if (value.isEmpty) {
    return '#';
  }

  return getArtistQuickJumpBucket(value);
}

String _quickJumpValue(
  LibrarySong song,
  MusicLibrarySortCriterion criterion,
  SmPlayerI18n i18n,
) {
  switch (criterion) {
    case MusicLibrarySortCriterion.artist:
      return _displayArtists(song, i18n);
    case MusicLibrarySortCriterion.album:
      return _displayAlbum(song, i18n);
    case MusicLibrarySortCriterion.duration:
      return _formatDuration(song.duration);
    case MusicLibrarySortCriterion.playCount:
      return song.playCount.toString();
    case MusicLibrarySortCriterion.dateAdded:
      return _formatDateTime(song.dateAdded);
    case MusicLibrarySortCriterion.title:
      return song.title;
  }
}

int _compareSongs(
  LibrarySong left,
  LibrarySong right,
  MusicLibrarySortCriterion criterion,
  SmPlayerI18n i18n,
) {
  switch (criterion) {
    case MusicLibrarySortCriterion.artist:
      return _compareText(
        _displayArtists(left, i18n),
        _displayArtists(right, i18n),
      );
    case MusicLibrarySortCriterion.album:
      return _compareText(left.album, right.album);
    case MusicLibrarySortCriterion.duration:
      return left.duration.compareTo(right.duration);
    case MusicLibrarySortCriterion.playCount:
      return left.playCount.compareTo(right.playCount);
    case MusicLibrarySortCriterion.dateAdded:
      return _parseDate(left.dateAdded).compareTo(_parseDate(right.dateAdded));
    case MusicLibrarySortCriterion.title:
      return _compareText(left.title, right.title);
  }
}

int _compareText(String left, String right) {
  return compareArtistText(left, right);
}

String _displayArtists(LibrarySong song, SmPlayerI18n i18n) {
  return song_display.displayArtists(song, i18n);
}

String _displayAlbum(LibrarySong song, SmPlayerI18n i18n) {
  return song_display.displayAlbum(song, i18n);
}

String _formatDuration(int seconds) {
  final duration = Duration(seconds: seconds);
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final remainingSeconds = duration.inSeconds.remainder(60);
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:'
        '${remainingSeconds.toString().padLeft(2, '0')}';
  }
  return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
}

String _formatDateTime(String value) {
  final date = _parseDate(value);
  if (date == DateTime.fromMillisecondsSinceEpoch(0)) {
    return '';
  }

  return '${date.year}/${date.month}/${date.day} '
      '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';
}

DateTime _parseDate(String value) {
  return LibraryTimeCodec.parseStoredDateTime(value).toLocal();
}

class _LibraryColors {
  const _LibraryColors._();

  static const panel = Color(0xffffffff);
  static const panelBorder = Color(0x29677486);
  static const emptyStateSurface = Color(0x94ffffff);
  static const emptyStateBorder = Color(0x94ffffff);
  static const panelShadow = Color(0x1f1f2a38);
  static const quickJumpPanel = Color(0xf5f4f6f9);
  static const quickJumpPanelShadow = Color(0x1f2a384e);
  static const quickJumpPanelButton = Color(0xadffffff);
  static const quickJumpPanelButtonBorder = Color(0x1a677486);
  static const quickJumpBorder = Color(0x1a677486);
  static const appBarButtonHover = Color(0x12111827);
  static const rowBorder = Color(0x21727e8c);
  static const rowHover = GlobalUI.hoverBgColorDay;
  static const rowSelected = GlobalUI.selectedBgColorDay;
  static const selectionMark = Color(0xdfffffff);
  static const selectionBorder = Color(0x55677486);
  static const accentStrong = Color(0xff0063b1);
  static const accentSoft = Color(0x1a0078d7);
  static const favorite = Color(0xffd13438);
  static const textStrong = Color(0xff111827);
  static const textMuted = Color(0xff5b697a);
  static const headerText = Color(0xff565656);
  static const disabled = Color(0x3d5b697a);
}

class _LibraryPalette {
  const _LibraryPalette({
    required this.panel,
    required this.panelGradient,
    required this.panelBorder,
    required this.emptyStateSurface,
    required this.emptyStateBorder,
    required this.panelShadow,
    required this.quickJumpBorder,
    required this.rowBorder,
    required this.rowHover,
    required this.rowCurrent,
    required this.rowSelected,
    required this.selectionMark,
    required this.selectionBorder,
    required this.accentStrong,
    required this.accentSoft,
    required this.currentForeground,
    required this.currentMuted,
    required this.favorite,
    required this.textStrong,
    required this.textMuted,
    required this.headerText,
    required this.disabled,
    required this.routeText,
  });

  final Color panel;
  final Gradient? panelGradient;
  final Color panelBorder;
  final Color emptyStateSurface;
  final Color emptyStateBorder;
  final Color panelShadow;
  final Color quickJumpBorder;
  final Color rowBorder;
  final Color rowHover;
  final Color rowCurrent;
  final Color rowSelected;
  final Color selectionMark;
  final Color selectionBorder;
  final Color accentStrong;
  final Color accentSoft;
  final Color currentForeground;
  final Color currentMuted;
  final Color favorite;
  final Color textStrong;
  final Color textMuted;
  final Color headerText;
  final Color disabled;
  final Color routeText;

  static const light = _LibraryPalette(
    panel: _LibraryColors.panel,
    panelGradient: null,
    panelBorder: _LibraryColors.panelBorder,
    emptyStateSurface: _LibraryColors.emptyStateSurface,
    emptyStateBorder: _LibraryColors.emptyStateBorder,
    panelShadow: _LibraryColors.panelShadow,
    quickJumpBorder: _LibraryColors.quickJumpBorder,
    rowBorder: _LibraryColors.rowBorder,
    rowHover: _LibraryColors.rowHover,
    rowCurrent: Color(0x1f0078d7),
    rowSelected: _LibraryColors.rowSelected,
    selectionMark: _LibraryColors.selectionMark,
    selectionBorder: _LibraryColors.selectionBorder,
    accentStrong: _LibraryColors.accentStrong,
    accentSoft: _LibraryColors.accentSoft,
    currentForeground: _LibraryColors.accentStrong,
    currentMuted: _LibraryColors.accentStrong,
    favorite: _LibraryColors.favorite,
    textStrong: _LibraryColors.textStrong,
    textMuted: _LibraryColors.textMuted,
    headerText: _LibraryColors.headerText,
    disabled: _LibraryColors.disabled,
    routeText: _LibraryColors.textMuted,
  );

  static const dark = _LibraryPalette(
    panel: Color(0xff171c22),
    panelGradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0x09ffffff), Color(0x05ffffff)],
    ),
    panelBorder: Color(0x1fd6e0ec),
    emptyStateSurface: Color(0xdb171c22),
    emptyStateBorder: Color(0x1fd6e0ec),
    panelShadow: Color(0x57000000),
    quickJumpBorder: Color(0x1fd6e0ec),
    rowBorder: Color(0x1fd6e0ec),
    rowHover: GlobalUI.hoverBgColorNight,
    rowCurrent: Color(0x2e0078d7),
    rowSelected: GlobalUI.selectedBgColorNight,
    selectionMark: Color(0x0effffff),
    selectionBorder: Color(0x1fd6e0ec),
    accentStrong: Color(0xff459de2),
    accentSoft: Color(0x290078d7),
    currentForeground: Color(0xff459de2),
    currentMuted: Color(0xc276b5dc),
    favorite: _LibraryColors.favorite,
    textStrong: Color(0xeff6f9fc),
    textMuted: Color(0xadcbd5e1),
    headerText: Color(0xadcbd5e1),
    disabled: Color(0x3dcbd5e1),
    routeText: Color(0xadcbd5e1),
  );

  static _LibraryPalette of(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? dark : light;
  }
}

class _LibraryQuickJumpPanelColors {
  const _LibraryQuickJumpPanelColors({
    required this.panel,
    required this.panelShadow,
    required this.headerText,
    required this.toggleHover,
    required this.buttonBackground,
    required this.buttonBorder,
    required this.text,
    required this.activeBackground,
    required this.activeBorder,
    required this.activeText,
    required this.disabledBackground,
    required this.disabledText,
  });

  final Color panel;
  final Color panelShadow;
  final Color headerText;
  final Color toggleHover;
  final Color buttonBackground;
  final Color buttonBorder;
  final Color text;
  final Color activeBackground;
  final Color activeBorder;
  final Color activeText;
  final Color disabledBackground;
  final Color disabledText;

  static const light = _LibraryQuickJumpPanelColors(
    panel: _LibraryColors.quickJumpPanel,
    panelShadow: _LibraryColors.quickJumpPanelShadow,
    headerText: _LibraryColors.textStrong,
    toggleHover: _LibraryColors.appBarButtonHover,
    buttonBackground: _LibraryColors.quickJumpPanelButton,
    buttonBorder: _LibraryColors.quickJumpPanelButtonBorder,
    text: _LibraryColors.textMuted,
    activeBackground: _LibraryColors.accentSoft,
    activeBorder: Color(0x2e0078d7),
    activeText: _LibraryColors.accentStrong,
    disabledBackground: _LibraryColors.quickJumpPanelButton,
    disabledText: _LibraryColors.disabled,
  );

  static const dark = _LibraryQuickJumpPanelColors(
    panel: Color(0xf5101419),
    panelShadow: Color(0x5c000000),
    headerText: Color(0xf0f6f9fc),
    toggleHover: Color(0x14ffffff),
    buttonBackground: Color(0xff1d232b),
    buttonBorder: Color(0x1fd6e0ec),
    text: Color(0xadcbd5e1),
    activeBackground: Color(0x2e0078d7),
    activeBorder: Color(0x570078d7),
    activeText: Colors.white,
    disabledBackground: Colors.transparent,
    disabledText: Color(0x3dcbd5e1),
  );

  static _LibraryQuickJumpPanelColors of(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? dark : light;
  }
}
