import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smplayer_flutter/src/app/shell_layout_state.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
import 'package:smplayer_flutter/src/lyrics/desktop_lyrics_overlay.dart';
import 'package:smplayer_flutter/src/playback/media_control_model.dart';
import 'package:smplayer_flutter/src/settings/settings_controller.dart';

class ShellDesktopLyricsHost extends ConsumerWidget {
  const ShellDesktopLyricsHost({
    super.key,
    required this.layout,
    required this.mediaControlController,
    required this.settingsController,
    required this.resolvePlayerSong,
    required this.onPrevious,
    required this.onNext,
    required this.onTogglePlayPause,
    required this.onSeekOffset,
    required this.onResetOffset,
    required this.onToggleLock,
    required this.onClose,
    required this.onOpenSettings,
  });

  final ShellLayoutState layout;
  final MediaControlController mediaControlController;
  final SettingsController settingsController;
  final LibrarySong? Function(
    MediaControlState mediaControlState,
    LibraryContentData? snapshot,
  )
  resolvePlayerSong;
  final bool Function({bool forcePrevious}) onPrevious;
  final bool Function() onNext;
  final bool Function() onTogglePlayPause;
  final void Function(LibrarySong song, int deltaMs) onSeekOffset;
  final ValueChanged<LibrarySong> onResetOffset;
  final VoidCallback onToggleLock;
  final VoidCallback onClose;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Positioned.fill(
      child: Consumer(
        builder: (context, ref, _) {
          final snapshot = ref.watch(libraryContentDataProvider).valueOrNull;
          final state = mediaControlController.state;
          final currentSong = resolvePlayerSong(state, snapshot);
          final settings = settingsController.snapshot;
          if (!settings.desktopLyricsEnabled ||
              currentSong == null ||
              usesNativeDesktopLyricsWindow()) {
            return const SizedBox.shrink();
          }
          return Padding(
            padding: EdgeInsets.only(
              left: layout.shellSidebarWidth + 24,
              right: 24,
              top: 26,
            ),
            child: Align(
              alignment: Alignment.topCenter,
              child: DesktopLyricsOverlay(
                song: currentSong,
                settings: settings,
                repository: ref.read(libraryRepositoryProvider),
                i18n: context.smPlayerI18n,
                progressSeconds: state.progressSeconds,
                isPlaying: state.isPlaying,
                onPrevious: onPrevious,
                onNext: onNext,
                onTogglePlayPause: onTogglePlayPause,
                onSeekOffset: (deltaMs) {
                  onSeekOffset(currentSong, deltaMs);
                },
                onResetOffset: () {
                  onResetOffset(currentSong);
                },
                onToggleLock: onToggleLock,
                onClose: onClose,
                onOpenSettings: onOpenSettings,
              ),
            ),
          );
        },
      ),
    );
  }
}
