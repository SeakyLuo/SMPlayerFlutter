import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/ui/artists_page_model.dart'
    as artists_model;

class SmPlayerShellMetrics {
  const SmPlayerShellMetrics._();

  static const playerHeight = 120.0;
  static const playerTopRadius = 18.0;
  static const sidebarWidth = 320.0;
  static const collapsedSidebarWidth = 78.0;
  static const navigationPaneHorizontalPadding = 8.0;
  static const navigationButtonSize = 40.0;
  static const navigationIconSize = 20.0;
  static const navigationButtonRadius = 10.0;
  static const navigationCollapsedButtonSize = navigationButtonSize;
  static const mainWindowMinimumWidth = 506.0;
  static const mainWindowMinimumHeight = 698.0;
  static const minimalTitlebarHeight = 32.0;
  static const macOSTitlebarLeadingInset = 78.0;
  static const workspaceHeaderHeight = 92.0;
  static const navigationMinimalBreakpoint = 720.0;
  static const navigationOverlayBreakpoint = 1200.0;
  static const navigationPlaylistChildrenCollapseHeight =
      mainWindowMinimumHeight - playerHeight;

  static SmPlayerNavigationMode navigationModeForWidth(double width) {
    if (width < navigationMinimalBreakpoint) {
      return SmPlayerNavigationMode.minimal;
    }

    if (width < navigationOverlayBreakpoint) {
      return SmPlayerNavigationMode.overlay;
    }

    return SmPlayerNavigationMode.wide;
  }
}

String resolvePlayerArtistRouteName(LibrarySong song, SmPlayerI18n i18n) {
  final artists = artists_model.getSongArtists(song);
  return artists.isEmpty ? i18n.t('common.artistUnknown') : artists.first;
}

LibrarySong? resolveShellPlayerSong(
  LibraryContentData? snapshot,
  int? trackId,
) {
  if (trackId == null || snapshot == null) {
    return null;
  }
  final songsById = {for (final song in snapshot.songs) song.id: song};
  return songsById[trackId];
}

double resolveQueuePlaybackStartSeconds({
  required int? currentTrackId,
  required int nextTrackId,
  required double currentProgressSeconds,
}) {
  return currentTrackId == nextTrackId ? currentProgressSeconds : 0;
}

bool shouldIgnoreAudioPositionForPendingSeek({
  required double positionSeconds,
  required double? pendingSeekSeconds,
  required double toleranceSeconds,
}) {
  return pendingSeekSeconds != null &&
      (positionSeconds - pendingSeekSeconds).abs() > toleranceSeconds;
}

bool shouldApplyAudioBackendPlayingState({
  required bool backendLoading,
  required bool backendPlaying,
  required bool pendingAutoplay,
}) {
  return backendPlaying || (!backendLoading && !pendingAutoplay);
}

bool shouldShowAudioBackendLoading({
  required bool backendLoading,
  required bool waitingForCurrentLoad,
  required bool pendingAutoplay,
  required bool backendPlaying,
}) {
  return backendLoading ||
      (waitingForCurrentLoad && pendingAutoplay && !backendPlaying);
}

enum SmPlayerNavigationMode { minimal, overlay, wide }

enum SmPlayerPlaybackShortcut {
  play,
  pause,
  togglePlayPause,
  next,
  previous,
  seekForwardShort,
  seekBackwardShort,
  seekForwardLong,
  seekBackwardLong,
  toggleShuffle,
  toggleRepeat,
  toggleRepeatOne,
}

SmPlayerPlaybackShortcut? playbackShortcutForKey({
  required LogicalKeyboardKey key,
  required bool control,
  required bool alt,
  required bool meta,
  required bool shift,
}) {
  if (key == LogicalKeyboardKey.mediaPlay) {
    return SmPlayerPlaybackShortcut.play;
  }

  if (key == LogicalKeyboardKey.mediaPause) {
    return SmPlayerPlaybackShortcut.pause;
  }

  if (key == LogicalKeyboardKey.space ||
      key == LogicalKeyboardKey.mediaPlayPause ||
      key == LogicalKeyboardKey.f8) {
    return SmPlayerPlaybackShortcut.togglePlayPause;
  }

  if (alt && !control && !meta) {
    if (key == LogicalKeyboardKey.keyS) {
      return SmPlayerPlaybackShortcut.toggleShuffle;
    }
    if (key == LogicalKeyboardKey.keyR) {
      return SmPlayerPlaybackShortcut.toggleRepeat;
    }
    if (key == LogicalKeyboardKey.digit1) {
      return SmPlayerPlaybackShortcut.toggleRepeatOne;
    }
  }

  if (alt || meta) {
    return null;
  }

  if (key == LogicalKeyboardKey.mediaTrackNext ||
      key == LogicalKeyboardKey.f9 ||
      (control && key == LogicalKeyboardKey.arrowRight)) {
    return SmPlayerPlaybackShortcut.next;
  }
  if (key == LogicalKeyboardKey.mediaTrackPrevious ||
      key == LogicalKeyboardKey.f7 ||
      (control && key == LogicalKeyboardKey.arrowLeft)) {
    return SmPlayerPlaybackShortcut.previous;
  }

  if (key == LogicalKeyboardKey.arrowRight) {
    return shift
        ? SmPlayerPlaybackShortcut.seekForwardLong
        : SmPlayerPlaybackShortcut.seekForwardShort;
  }
  if (key == LogicalKeyboardKey.arrowLeft) {
    return shift
        ? SmPlayerPlaybackShortcut.seekBackwardLong
        : SmPlayerPlaybackShortcut.seekBackwardShort;
  }

  return null;
}

int compareAppVersions(String left, String right) {
  final leftParts = left.split('.').map(int.parse).toList();
  final rightParts = right.split('.').map(int.parse).toList();
  final length = max(leftParts.length, rightParts.length);

  for (var index = 0; index < length; index += 1) {
    final leftPart = index < leftParts.length ? leftParts[index] : 0;
    final rightPart = index < rightParts.length ? rightParts[index] : 0;
    if (leftPart != rightPart) {
      return leftPart - rightPart;
    }
  }

  return 0;
}

class SmPlayerShellKeys {
  const SmPlayerShellKeys._();

  static const sidebar = ValueKey('SmPlayerShell.Sidebar');
  static const workspace = ValueKey('SmPlayerShell.Workspace');
  static const reservedPlayer = ValueKey('SmPlayerShell.ReservedPlayer');
  static const minimalMenuButton = ValueKey('SmPlayerShell.MinimalMenuButton');
  static const navigationDismissLayer = ValueKey(
    'SmPlayerShell.NavigationDismissLayer',
  );
}
