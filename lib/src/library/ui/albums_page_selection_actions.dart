part of 'albums_page.dart';

extension _AlbumsPageSelectionActions on _AlbumsPageState {
  void _changeAlbumSort(AlbumSortCriterion criterion) {
    _showProcessing();
    _updateState(() {
      if (criterion == AlbumSortCriterion.reverse) {
        _reverseDisplayOrder = !_reverseDisplayOrder;
      } else {
        _reverseDisplayOrder = false;
        _sortCriterion = criterion;
      }
    });
    if (criterion != AlbumSortCriterion.reverse) {
      ref.read(libraryRepositoryProvider).updateAlbumsSort(criterion);
    }
    _scrollAlbumsToTop();
  }

  void _toggleMultiSelect() {
    _updateState(() {
      _selection.toggleMultiSelect();
    });
  }

  void _toggleAlbumSelection(String albumName) {
    _updateState(() {
      _selection.toggle(albumName);
    });
  }

  void _hideSelectionAfterOperation(
    bool hideMultiSelectCommandBarAfterOperation,
  ) {
    _updateState(() {
      _selection.hideAfterOperation(hideMultiSelectCommandBarAfterOperation);
    });
  }

  void _openAlbum(String albumName) {
    _updateState(() {
      _searchDraft = albumName;
      _searchQuery = albumName;
      _selection.clearSelection();
    });
    context.go('/albums?album=${Uri.encodeQueryComponent(albumName)}');
    _scrollAlbumsToTop();
  }
}
