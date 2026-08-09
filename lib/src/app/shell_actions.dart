import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final smPlayerShellActionsProvider = Provider<SmPlayerShellActions?>((ref) {
  return null;
});

class SmPlayerShellActions {
  const SmPlayerShellActions({
    required this.onOpenVoiceAssistant,
    required this.onExitWindowFullScreen,
    this.onToggleWindowFullScreen,
    this.isWindowFullScreen = false,
    this.onEnterMiniMode,
    this.onToggleDesktopLyrics,
    this.onExitImmersiveMode,
    this.onNavigate,
  });

  final VoidCallback? onOpenVoiceAssistant;
  final Future<void> Function()? onExitWindowFullScreen;
  final VoidCallback? onToggleWindowFullScreen;
  final bool isWindowFullScreen;
  final VoidCallback? onEnterMiniMode;
  final VoidCallback? onToggleDesktopLyrics;
  final VoidCallback? onExitImmersiveMode;
  final ValueChanged<String>? onNavigate;
}
