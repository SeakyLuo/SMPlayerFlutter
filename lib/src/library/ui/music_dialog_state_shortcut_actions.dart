part of 'music_dialog.dart';

extension _MusicDialogStateShortcutActions on _MusicDialogState {
  KeyEventResult _handleShortcutKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    final keyboard = HardwareKeyboard.instance;
    if (!keyboard.isControlPressed) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.keyS) {
      unawaited(_saveActiveMode());
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyR) {
      _resetActiveMode();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyF && _mode == SongDialogMode.lyrics) {
      unawaited(_searchLyrics());
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _saveActiveMode() {
    return switch (_mode) {
      SongDialogMode.properties => _saveProperties(),
      SongDialogMode.lyrics => _saveLyrics(),
      SongDialogMode.albumArt => _saveArtwork(),
    };
  }

  void _resetActiveMode() {
    switch (_mode) {
      case SongDialogMode.properties:
        _resetProperties();
      case SongDialogMode.lyrics:
        _resetLyrics();
      case SongDialogMode.albumArt:
        _resetArtwork();
    }
  }
}
