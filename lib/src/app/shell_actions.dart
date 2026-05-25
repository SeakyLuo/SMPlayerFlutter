import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final smPlayerShellActionsProvider = Provider<SmPlayerShellActions?>((ref) {
  return null;
});

class SmPlayerShellActions {
  const SmPlayerShellActions({
    required this.onOpenVoiceAssistant,
    required this.onExitWindowFullScreen,
  });

  final VoidCallback? onOpenVoiceAssistant;
  final Future<void> Function()? onExitWindowFullScreen;
}
