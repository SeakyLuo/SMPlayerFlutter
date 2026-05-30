import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';

List<String> songArtists(LibrarySong song) {
  final artists = song.artists.where((artist) => artist.trim().isNotEmpty);
  if (artists.isNotEmpty) {
    return artists.toList();
  }

  final seen = <String>{};
  final normalizedArtists = <String>[];
  for (final artist in song.artist
      .split(RegExp(r'\s*(?:;|；|、|\|)\s*'))
      .map((artist) => artist.trim())
      .where((artist) => artist.isNotEmpty)) {
    final key = artist.toLowerCase();
    if (seen.add(key)) {
      normalizedArtists.add(artist);
    }
  }
  return normalizedArtists;
}

String displayArtists(LibrarySong song, SmPlayerI18n i18n) {
  final artists = songArtists(song);
  return artists.isEmpty
      ? i18n.t('common.artistUnknown')
      : artists.join(i18n.t('common.artistSeparator'));
}

String primaryDisplayArtist(LibrarySong song, SmPlayerI18n i18n) {
  final artists = songArtists(song);
  return artists.isEmpty ? i18n.t('common.artistUnknown') : artists.first;
}

String displayAlbum(LibrarySong song, SmPlayerI18n i18n) {
  final album = song.album.trim();
  return album.isEmpty ? i18n.t('common.albumUnknown') : album;
}

String canonicalAlbumName(LibrarySong song) {
  return song.album.trim();
}

String searchableSongText(LibrarySong song) {
  return [
    song.title,
    ...songArtists(song),
    canonicalAlbumName(song),
    song.path,
  ].join(' ');
}
