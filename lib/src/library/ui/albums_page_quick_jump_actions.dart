part of 'albums_page.dart';

extension _AlbumsPageQuickJumpActions on _AlbumsPageState {
  void _jumpToAlbumKey(
    Map<String, int> albumQuickJumpMap,
    String key,
    int columns,
    double albumRowHeight,
  ) {
    final targetIndex = albumQuickJumpMap[key];
    if (targetIndex == null) {
      return;
    }
    final targetRow = targetIndex ~/ columns;

    setState(() {
      _albumQuickJumpTargetKey = key;
      _albumQuickJumpJumping = true;
    });
    _albumGridScrollController.jumpTo(targetRow * albumRowHeight);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _albumQuickJumpJumping = false;
        });
      }
    });
  }

  void _scrollAlbumsToTop() {
    if (!_albumGridScrollController.hasClients) {
      return;
    }

    setState(() {
      _albumScrollTop = 0;
      _albumQuickJumpTargetKey = null;
      _albumQuickJumpJumping = false;
    });
    _albumGridScrollController.jumpTo(0);
  }

  void _handleAlbumGridScroll() {
    final nextScrollTop = _albumGridScrollController.offset;
    if (nextScrollTop == _albumScrollTop) {
      return;
    }

    setState(() {
      _albumScrollTop = nextScrollTop;
      if (!_albumQuickJumpJumping) {
        _albumQuickJumpTargetKey = null;
      }
    });
  }

  String _getActiveAlbumQuickJumpKey(
    List<AlbumView> visibleAlbums,
    int columns,
    double albumRowHeight,
  ) {
    if (visibleAlbums.isEmpty) {
      return '';
    }

    final topRow = max(0, (_albumScrollTop / albumRowHeight).floor());
    if (_albumQuickJumpTargetKey != null) {
      return _albumQuickJumpTargetKey!;
    }

    final activeIndex = min(visibleAlbums.length - 1, topRow * columns);
    return getArtistQuickJumpBucket(visibleAlbums[activeIndex].name);
  }

  void _showProcessing() {
    _processingTimer?.cancel();
    setState(() {
      _processing = true;
    });
    _processingTimer = Timer(const Duration(milliseconds: 180), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _processing = false;
      });
    });
  }

  String _allAlbumsTitle(
    LibraryContentData snapshot,
    List<AlbumView> albums,
    SmPlayerI18n i18n,
  ) {
    return snapshot.showCount
        ? i18n.t('library.allAlbumsWithCount', {'count': albums.length})
        : i18n.t('library.allAlbums');
  }
}
