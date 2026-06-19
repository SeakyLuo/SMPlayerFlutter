import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final headeredPlaylistAppBarPortalProvider =
    StateProvider<HeaderedPlaylistAppBarPortalEntry?>((ref) => null);

const _pendingHeaderedPlaylistAppBarOwner = Object();

HeaderedPlaylistAppBarPortalEntry? resolveHeaderedPlaylistAppBarForLocation({
  required HeaderedPlaylistAppBarPortalEntry? rawEntry,
  required String currentLocation,
}) {
  if (rawEntry != null &&
      (rawEntry.routeLocation == null ||
          rawEntry.routeLocation == currentLocation)) {
    return rawEntry;
  }
  if (!isHeaderedPlaylistRouteLocation(currentLocation)) {
    return null;
  }
  return HeaderedPlaylistAppBarPortalEntry(
    owner: _pendingHeaderedPlaylistAppBarOwner,
    routeLocation: currentLocation,
    title: '',
    coverColor: Colors.transparent,
    collapseProgress: 0,
  );
}

bool isHeaderedPlaylistRouteLocation(String location) {
  final uri = Uri.parse(location);
  final path = uri.path;
  return path == '/favorites' ||
      path.startsWith('/playlists/') ||
      path == '/albums' && uri.queryParameters.containsKey('album');
}

void clearHeaderedPlaylistAppBarPortalOwnerAfterDispose(
  StateController<HeaderedPlaylistAppBarPortalEntry?> notifier,
  Object owner,
) {
  scheduleMicrotask(() {
    if (!notifier.mounted) {
      return;
    }
    if (notifier.state?.owner == owner) {
      notifier.state = null;
    }
  });
}

class HeaderedPlaylistAppBarPortalEntry {
  const HeaderedPlaylistAppBarPortalEntry({
    required this.owner,
    required this.routeLocation,
    required this.title,
    required this.coverColor,
    required this.collapseProgress,
    this.commandBarBuilder,
  });

  final Object owner;
  final String? routeLocation;
  final String title;
  final WidgetBuilder? commandBarBuilder;
  final Color coverColor;
  final double collapseProgress;
}
