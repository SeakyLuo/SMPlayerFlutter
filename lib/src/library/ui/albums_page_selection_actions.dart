part of 'albums_page.dart';

extension _AlbumsPageSelectionActions on _AlbumsPageState {
  void _changeAlbumSort(AlbumSortCriterion criterion) {
    _showProcessing();
    setState(() {
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
    setState(() {
      _selection.toggleMultiSelect();
    });
  }

  void _toggleAlbumSelection(String albumName) {
    setState(() {
      _selection.toggle(albumName);
    });
  }

  void _hideSelectionAfterOperation(
    bool hideMultiSelectCommandBarAfterOperation,
  ) {
    setState(() {
      _selection.hideAfterOperation(hideMultiSelectCommandBarAfterOperation);
    });
  }

  void _openAlbum(String albumName) {
    setState(() {
      _searchDraft = albumName;
      _searchQuery = albumName;
      _selection.clearSelection();
    });
    context.go('/albums?album=${Uri.encodeQueryComponent(albumName)}');
    _scrollAlbumsToTop();
  }
}
