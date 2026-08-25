part of 'artists_page.dart';

// ignore_for_file: invalid_use_of_protected_member

extension _ArtistsBrowseHistory on _ArtistsPageState {
  void _openArtistDetail(String artistName) {
    _openArtistDetailForArtistsPage(this, artistName);
  }

  void _recordBrowseAfterFrame(String artistName) {
    if (_recordedBrowseArtistName == artistName) {
      return;
    }
    _recordedBrowseArtistName = artistName;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _recordedBrowseArtistName != artistName) {
        return;
      }
      unawaited(_recordBrowse(artistName));
    });
  }

  Future<void> _recordBrowse(String artistName) async {
    final recentBrowses = ref.read(recentBrowsesProvider.notifier);
    final entry = await ref
        .read(libraryRepositoryProvider)
        .recordRecentBrowse(RecentBrowseType.artist, artistName);
    await recentBrowses.record(entry);
  }

  void _clearAppBarPortalOwner() {
    _clearArtistsAppBarPortalOwner(this);
  }

  void _updateArtistsPageState(VoidCallback update) {
    setState(update);
  }
}
