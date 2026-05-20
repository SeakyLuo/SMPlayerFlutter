import 'package:smplayer_flutter/src/library/data/library_models.dart';

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
) {
  final songsByAlbum = <String, List<LibrarySong>>{};
  for (final song in songs) {
    final albumName = displayAlbum(song);
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
          artist: getRecentAlbumArtistLabel(albumSongs),
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
) {
  final songsByArtist = <String, List<LibrarySong>>{};
  for (final song in songs) {
    for (final artistName in getSongArtists(song)) {
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
  return DateTime.tryParse(value)?.millisecondsSinceEpoch ?? 0;
}

String categorizeRecentDate(String value) {
  final date = DateTime.tryParse(value);
  if (date == null) {
    return '';
  }
  final now = DateTime.now();

  if (sameCalendarDate(date, now)) {
    return '今天';
  }

  final yesterday = now.subtract(const Duration(days: 1));
  if (sameCalendarDate(date, yesterday)) {
    return '昨天';
  }

  if (date.isAfter(now.subtract(const Duration(days: 7)))) {
    return '最近 7 天';
  }

  if (date.year == now.year && date.month == now.month) {
    return '本月';
  }

  if (date.isAfter(now.subtract(const Duration(days: 30)))) {
    return '最近 30 天';
  }

  if (date.year == now.year) {
    return '${date.month} 月';
  }

  return '${date.year}.${date.month.toString().padLeft(2, '0')}';
}

String formatRecentDateTime(String value) {
  final date = DateTime.tryParse(value);
  if (date == null) {
    return '';
  }
  final now = DateTime.now();
  final datePart =
      date.year == now.year
          ? '${date.month}/${date.day}'
          : '${date.year}/${date.month}/${date.day}';
  return '$datePart ${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';
}

String displayAlbum(LibrarySong song) {
  return song.album.isEmpty ? '未知专辑' : song.album;
}

List<String> getSongArtists(LibrarySong song) {
  return song.artists.where((artist) => artist.trim().isNotEmpty).isEmpty
      ? [song.artist.isEmpty ? '未知艺术家' : song.artist]
      : song.artists;
}

String displayArtists(LibrarySong song) {
  return getSongArtists(song).join(' / ');
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

String searchHistoryTypeLabel(SearchHistoryType type) {
  return switch (type) {
    SearchHistoryType.artists => '歌手',
    SearchHistoryType.albums => '专辑',
    SearchHistoryType.songs => '歌曲',
    SearchHistoryType.playlists => '播放列表',
    SearchHistoryType.folders => '本地',
    SearchHistoryType.sidebar => '全部',
  };
}

String getRecentAlbumArtistLabel(List<LibrarySong> songs) {
  final artists = songs.expand(getSongArtists).toSet().toList();
  if (artists.length >= 3) {
    return '${artists[0]}、${artists[1]} 等 ${artists.length - 2} 位艺术家';
  }
  return artists.join(' / ');
}

bool sameCalendarDate(DateTime left, DateTime right) {
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}
