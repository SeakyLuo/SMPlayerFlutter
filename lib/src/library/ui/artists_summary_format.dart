part of 'artists_page.dart';

String _formatArtistSummary(SmPlayerI18n i18n, int albums, int songs) {
  return i18n.t('artists.artistSummary', {'albums': albums, 'songs': songs});
}
