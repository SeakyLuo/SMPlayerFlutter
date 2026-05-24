import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final headeredPlaylistAppBarPortalProvider =
    StateProvider<HeaderedPlaylistAppBarPortalEntry?>((ref) => null);

class HeaderedPlaylistAppBarPortalEntry {
  const HeaderedPlaylistAppBarPortalEntry({
    required this.owner,
    required this.title,
    required this.coverColor,
    required this.collapseProgress,
    this.commandBarBuilder,
  });

  final Object owner;
  final String title;
  final WidgetBuilder? commandBarBuilder;
  final Color coverColor;
  final double collapseProgress;
}
