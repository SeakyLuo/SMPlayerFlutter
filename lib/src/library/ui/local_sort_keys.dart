import '../data/library_models.dart';
import 'artist_text_sort_key.dart';
import 'artists_page_model.dart';

// Owned by the displayed library. Snapshot reloads reuse unchanged text keys;
// retainLibrary removes names and song objects that are no longer displayed.
class LocalSortKeys {
  final _textKeys = <String, ArtistTextSortKey>{};
  final _artistNames = <LibrarySong, String>{};

  void retainLibrary(List<LibrarySong> songs, Iterable<String> folderNames) {
    final currentSongs = songs.toSet();
    _artistNames.removeWhere((song, _) => !currentSongs.contains(song));
    final currentTexts = {
      ...folderNames,
      for (final song in songs) ...[song.title, song.album, _artists(song)],
    };
    _textKeys.removeWhere((text, _) => !currentTexts.contains(text));
  }

  int compareText(String left, String right) {
    return compareArtistTextSortKeys(
      _textKeys.putIfAbsent(left, () => buildArtistTextSortKey(left)),
      _textKeys.putIfAbsent(right, () => buildArtistTextSortKey(right)),
    );
  }

  String _artists(LibrarySong song) {
    return _artistNames.putIfAbsent(
      song,
      () => getSongArtists(song).join(' / '),
    );
  }

  int compareSongs(LibrarySong left, LibrarySong right, int criterion) {
    switch (criterion) {
      case 1:
        final artistCompare = compareText(_artists(left), _artists(right));
        return artistCompare != 0
            ? artistCompare
            : compareText(left.title, right.title);
      case 2:
        final albumCompare = compareText(left.album, right.album);
        return albumCompare != 0
            ? albumCompare
            : compareText(left.title, right.title);
      case 3:
        return left.duration.compareTo(right.duration);
      case 4:
        return left.playCount.compareTo(right.playCount);
      case 5:
        return left.dateAdded.compareTo(right.dateAdded);
      case 7:
        return -compareText(left.title, right.title);
      case 0:
      case 6:
        return compareText(left.title, right.title);
      default:
        return left.id.compareTo(right.id);
    }
  }
}
