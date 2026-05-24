import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/ui/song_display_helpers.dart';
import 'package:smplayer_flutter/src/playback/media_control_model.dart';

MediaControlTrack mediaControlTrackForSong(
  LibrarySong song,
  SmPlayerI18n i18n, {
  bool isLoading = false,
}) {
  return MediaControlTrack(
    id: song.id,
    title: song.title,
    artist: displayArtists(song, i18n),
    artworkUrl: song.thumbnailPath,
    isLoading: isLoading,
    favorite: song.favorite,
  );
}
