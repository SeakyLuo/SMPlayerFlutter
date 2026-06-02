part of 'local_page.dart';

extension _LocalPageSelectionActions on _LocalPageState {
  void _enableMultiSelect() {
    _updateLocalPageState(() {
      _multiSelect = true;
    });
  }

  void _selectFolder(FolderNode folder) {
    _updateLocalPageState(() {
      _multiSelect = true;
      _selectedFolderPaths
        ..clear()
        ..add(folder.relativePath);
      _selectedSongIds.clear();
    });
  }

  void _selectSong(int songId) {
    _updateLocalPageState(() {
      _multiSelect = true;
      _selectedSongIds
        ..clear()
        ..add(songId);
      _selectedFolderPaths.clear();
    });
  }

  void _toggleFolderSelection(String folderPath) {
    _updateLocalPageState(() {
      _multiSelect = true;
      if (_selectedFolderPaths.contains(folderPath)) {
        _selectedFolderPaths.remove(folderPath);
      } else {
        _selectedFolderPaths.add(folderPath);
      }
    });
  }

  void _toggleSongSelection(int songId) {
    _updateLocalPageState(() {
      _multiSelect = true;
      if (_selectedSongIds.contains(songId)) {
        _selectedSongIds.remove(songId);
      } else {
        _selectedSongIds.add(songId);
      }
    });
  }

  void _clearMultiSelectStatus() {
    _multiSelect = false;
    _selectedFolderPaths.clear();
    _selectedSongIds.clear();
  }

  void _hideMultiSelectAfterOperation(
    bool hideMultiSelectCommandBarAfterOperation,
  ) {
    if (hideMultiSelectCommandBarAfterOperation) {
      _clearMultiSelectStatus();
    }
  }
}
