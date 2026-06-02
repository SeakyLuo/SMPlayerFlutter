import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smplayer_flutter/src/app/shell_player_host.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
import 'package:smplayer_flutter/src/library/ui/music_dialog.dart';
import 'package:smplayer_flutter/src/playback/media_control_model.dart';
import 'package:smplayer_flutter/src/settings/artist_split_review_dialog.dart';
import 'package:smplayer_flutter/src/settings/release_notes_dialog.dart';

class ShellOverlayHost extends ConsumerWidget {
  const ShellOverlayHost({
    super.key,
    required this.playerDialogNotifier,
    required this.playerDialogRefreshNotifier,
    required this.mediaControlController,
    required this.releaseNotesDialogVersion,
    required this.startupArtistSplitResult,
    required this.startupArtistSplitApplying,
    required this.onTogglePlayPause,
    required this.onRevealPath,
    required this.onCloseReleaseNotes,
    required this.onDismissStartupArtistSplitReview,
    required this.onApplyStartupArtistSplits,
  });

  final ValueNotifier<ShellPlayerDialog?> playerDialogNotifier;
  final ValueNotifier<int> playerDialogRefreshNotifier;
  final MediaControlController mediaControlController;
  final String? releaseNotesDialogVersion;
  final ArtistSplitAnalysisResult? startupArtistSplitResult;
  final bool startupArtistSplitApplying;
  final VoidCallback onTogglePlayPause;
  final ValueChanged<String> onRevealPath;
  final Future<void> Function(String version) onCloseReleaseNotes;
  final VoidCallback onDismissStartupArtistSplitReview;
  final Future<void> Function(List<ArtistSplitResultItem> splits)
  onApplyStartupArtistSplits;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      children: [
        ValueListenableBuilder<ShellPlayerDialog?>(
          valueListenable: playerDialogNotifier,
          builder: (context, dialog, _) {
            if (dialog == null) {
              return const SizedBox.shrink();
            }
            return ValueListenableBuilder<int>(
              valueListenable: playerDialogRefreshNotifier,
              builder: (context, _, _) {
                return MusicDialog(
                  song: dialog.song,
                  initialMode: dialog.mode,
                  canPause:
                      mediaControlController.state.isPlaying &&
                      mediaControlController.state.track.id == dialog.song.id,
                  onPlay: onTogglePlayPause,
                  onReveal: onRevealPath,
                  onSaved: () {
                    playerDialogRefreshNotifier.value += 1;
                  },
                  onClose: () {
                    playerDialogNotifier.value = null;
                  },
                );
              },
            );
          },
        ),
        if (releaseNotesDialogVersion case final String version)
          ReleaseNotesDialog(
            version: version,
            onClose: () {
              unawaited(onCloseReleaseNotes(version));
            },
          ),
        if (startupArtistSplitResult
            case final ArtistSplitAnalysisResult result)
          ArtistSplitReviewDialog(
            result: result,
            applying: startupArtistSplitApplying,
            artworkPathBySongId: {
              for (final song
                  in ref.watch(libraryContentDataProvider).valueOrNull?.songs ??
                      const <LibrarySong>[])
                song.id: song.thumbnailPath,
            },
            onCancel: onDismissStartupArtistSplitReview,
            onApply: onApplyStartupArtistSplits,
          ),
      ],
    );
  }
}
