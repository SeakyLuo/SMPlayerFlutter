part of 'popup_dialog.dart';

class _PopupDialogClassNames {
  const _PopupDialogClassNames({
    required this.className,
    required this.navClassName,
  });

  final String className;
  final String navClassName;

  bool get usesMobileTabGrid {
    if (_contains(className, 'release-notes-dialog') ||
        _contains(className, 'artist-split-review-dialog') ||
        _contains(className, 'album-art-library-picker-dialog') ||
        _contains(className, 'remote-share-dialog') ||
        _contains(className, 'voice-assistant-help-dialog') ||
        _contains(className, 'preference-modal')) {
      return false;
    }
    return _contains(navClassName, 'music-dialog-pivot') ||
        _contains(className, 'music-dialog') ||
        _contains(className, 'album-artwork-dialog');
  }

  bool get usesFullWidthNavTitle {
    return _contains(className, 'album-art-library-picker-dialog');
  }

  bool _contains(String source, String token) {
    return source.split(' ').contains(token);
  }
}
