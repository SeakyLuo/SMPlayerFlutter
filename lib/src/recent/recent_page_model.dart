import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_time_codec.dart';
import 'package:smplayer_flutter/src/library/ui/song_display_helpers.dart'
    as song_display;

class RecentPlaylistView {
  const RecentPlaylistView({
    required this.playlist,
    required this.songs,
    required this.playedAt,
  });

  final LibraryPlaylist playlist;
  final List<LibrarySong> songs;
  final String playedAt;
}

class RecentAlbumView {
  const RecentAlbumView({
    required this.name,
    required this.artist,
    required this.songs,
    required this.songIds,
    required this.playedAt,
  });

  final String name;
  final String artist;
  final List<LibrarySong> songs;
  final List<int> songIds;
  final String playedAt;
}

class RecentArtistView {
  const RecentArtistView({
    required this.name,
    required this.songs,
    required this.playedAt,
  });

  final String name;
  final List<LibrarySong> songs;
  final String playedAt;
}

List<RecentPlaylistView> buildRecentPlaylistViews(
  List<LibraryPlaylist> playlists,
  List<LibrarySong> songs,
  List<RecentPlaylistPlayback> recentPlaylists,
) {
  final songsById = {for (final song in songs) song.id: song};
  final playlistsById = {
    for (final playlist in playlists) playlist.id: playlist,
  };
  final views = <RecentPlaylistView>[];
  for (final recentPlaylist in recentPlaylists) {
    final playlist = playlistsById[recentPlaylist.playlistId];
    if (playlist != null) {
      views.add(
        RecentPlaylistView(
          playlist: playlist,
          songs:
              playlist.songIds
                  .map((songId) => songsById[songId])
                  .whereType<LibrarySong>()
                  .toList(),
          playedAt: recentPlaylist.playedAt,
        ),
      );
    }
  }
  return views;
}

List<RecentAlbumView> buildRecentAlbumViews(
  List<LibrarySong> songs,
  List<RecentAlbumPlayback> recentAlbums,
  SmPlayerI18n i18n,
) {
  final songsByAlbum = <String, List<LibrarySong>>{};
  for (final song in songs) {
    final albumName = displayAlbum(song, i18n);
    final albumSongs = songsByAlbum[albumName] ?? <LibrarySong>[];
    albumSongs.add(song);
    songsByAlbum[albumName] = albumSongs;
  }

  final views = <RecentAlbumView>[];
  for (final recentAlbum in recentAlbums) {
    final albumSongs = songsByAlbum[recentAlbum.album];
    if (albumSongs != null) {
      views.add(
        RecentAlbumView(
          name: recentAlbum.album,
          artist: getRecentAlbumArtistLabel(albumSongs, i18n),
          songs: albumSongs,
          songIds: albumSongs.map((song) => song.id).toList(),
          playedAt: recentAlbum.playedAt,
        ),
      );
    }
  }
  return views;
}

List<RecentArtistView> buildRecentArtistViews(
  List<LibrarySong> songs,
  List<RecentArtistPlayback> recentArtists,
  SmPlayerI18n i18n,
) {
  final songsByArtist = <String, List<LibrarySong>>{};
  for (final song in songs) {
    for (final artistName in getSongArtists(song, i18n)) {
      final artistSongs = songsByArtist[artistName] ?? <LibrarySong>[];
      artistSongs.add(song);
      songsByArtist[artistName] = artistSongs;
    }
  }

  final views = <RecentArtistView>[];
  for (final recentArtist in recentArtists) {
    final artistSongs = songsByArtist[recentArtist.artist];
    if (artistSongs != null) {
      views.add(
        RecentArtistView(
          name: recentArtist.artist,
          songs: artistSongs,
          playedAt: recentArtist.playedAt,
        ),
      );
    }
  }
  return views;
}

int dateValue(String value) {
  return LibraryTimeCodec.toSortMilliseconds(value);
}

String categorizeRecentDate(String value, SmPlayerI18n i18n) {
  if (value.trim().isEmpty) {
    return '';
  }
  final date = LibraryTimeCodec.parseStoredDateTime(value).toLocal();
  final now = DateTime.now();

  if (sameCalendarDate(date, now)) {
    return i18n.t('recent.time.today');
  }

  final yesterday = now.subtract(const Duration(days: 1));
  if (sameCalendarDate(date, yesterday)) {
    return i18n.t('recent.time.yesterday');
  }

  if (date.isAfter(now.subtract(const Duration(days: 7)))) {
    return i18n.t('recent.time.recent7Days');
  }

  if (date.year == now.year && date.month == now.month) {
    return i18n.t('recent.time.thisMonth');
  }

  if (date.isAfter(now.subtract(const Duration(days: 30)))) {
    return i18n.t('recent.time.recent30Days');
  }

  if (date.year == now.year) {
    return i18n.t('recent.time.month${date.month}');
  }

  return '${date.year}.${date.month.toString().padLeft(2, '0')}';
}

String formatRecentDateTime(String value) {
  if (value.trim().isEmpty) {
    return '';
  }
  final date = LibraryTimeCodec.parseStoredDateTime(value).toLocal();
  final now = DateTime.now();
  final datePart =
      date.year == now.year
          ? '${date.month}/${date.day}'
          : '${date.year}/${date.month}/${date.day}';
  return '$datePart ${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';
}

String displayAlbum(LibrarySong song, [SmPlayerI18n? i18n]) {
  final locale = i18n;
  if (locale != null) {
    return song_display.displayAlbum(song, locale);
  }
  final album = song_display.canonicalAlbumName(song);
  return album.isEmpty ? 'Unknown Album' : album;
}

List<String> getSongArtists(LibrarySong song, [SmPlayerI18n? i18n]) {
  final artists = song_display.songArtists(song);
  return artists.isEmpty
      ? [i18n?.t('common.artistUnknown') ?? 'Unknown Artist']
      : artists;
}

String displayArtists(LibrarySong song, [SmPlayerI18n? i18n]) {
  return getSongArtists(song, i18n).join(' / ');
}

String formatDuration(int seconds) {
  final duration = Duration(seconds: seconds);
  final minutes = duration.inMinutes.remainder(60).toString();
  final remainingSeconds = duration.inSeconds
      .remainder(60)
      .toString()
      .padLeft(2, '0');
  if (duration.inHours > 0) {
    return '${duration.inHours}:$minutes:$remainingSeconds';
  }
  return '$minutes:$remainingSeconds';
}

String searchHistoryTypeLabel(SearchHistoryType type, SmPlayerI18n i18n) {
  return switch (type) {
    SearchHistoryType.artists => i18n.t('common.artists'),
    SearchHistoryType.albums => i18n.t('common.albums'),
    SearchHistoryType.songs => i18n.t('common.songs'),
    SearchHistoryType.playlists => i18n.t('common.playlists'),
    SearchHistoryType.folders => i18n.t('common.folders'),
    SearchHistoryType.sidebar => i18n.t('common.all'),
  };
}

String getRecentAlbumArtistLabel(List<LibrarySong> songs, SmPlayerI18n i18n) {
  final artists =
      songs.expand((song) => getSongArtists(song, i18n)).toSet().toList();
  if (artists.length >= 3) {
    return i18n.t('albums.artistsAndMore', {
      'first': artists[0],
      'second': artists[1],
      'count': artists.length - 2,
    });
  }
  return artists.join(' / ');
}

bool sameCalendarDate(DateTime left, DateTime right) {
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}
