part of 'search_page.dart';

extension _SearchPageLyricsSearch on _SearchPageState {
  void _syncLocalLyricsSearch({
    required String query,
    required String folderPath,
    required int lyricsSavedRevision,
  }) {
    final source = ref.read(musicShareProvider).selectedSource;
    final signature =
        '$source\u0000${_SearchPageState._lyricsSearchRevision}\u0000$query\u0000$folderPath\u0000'
        '$lyricsSavedRevision';
    if (_lyricsSearchSignature == signature) {
      return;
    }
    _lyricsSearchSignature = signature;
    final generation = ++_lyricsSearchGeneration;
    final queryLength = query.trim().runes.length;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || generation != _lyricsSearchGeneration) {
        return;
      }
      if (queryLength < 2) {
        _updateSearchPageState(() {
          _lyricsIndexProgress = null;
        });
        _leaveEmptyLyricsFilter();
        return;
      }

      _updateSearchPageState(() {
        _lyricsIndexProgress = null;
      });
      final repository = ref.read(libraryRepositoryProvider);
      if (source != 'local') return;
      try {
        await repository.indexMissingLocalLyrics(
          folderPath: folderPath,
          onProgress: (progress) {
            if (!mounted || generation != _lyricsSearchGeneration) {
              return;
            }
            _updateSearchPageState(() {
              _lyricsIndexProgress = progress;
            });
          },
        );
        if (!mounted || generation != _lyricsSearchGeneration) {
          return;
        }
        _updateSearchPageState(() {
          _lyricsIndexProgress = null;
        });
        ref.invalidate(_lyricsWindowProvider(_lyricsQuery!));
      } catch (_) {
        if (!mounted || generation != _lyricsSearchGeneration) {
          return;
        }
        _updateSearchPageState(() {
          _lyricsIndexProgress = null;
        });
        showAppNotification(
          context: context,
          message: context.smPlayerI18n.t('search.lyricsSearchFailed'),
        );
      }
    });
  }

  void _leaveEmptyLyricsFilter() {
    if (_activeFilter == SearchFilterKey.lyrics) {
      _changeFilter(SearchFilterKey.all);
    }
  }
}
