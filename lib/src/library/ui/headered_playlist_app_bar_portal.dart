import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final headeredPlaylistAppBarPortalProvider =
    StateProvider<HeaderedPlaylistAppBarPortalEntry?>((ref) => null);

class HeaderedPlaylistAppBarPortalEntry {
  const HeaderedPlaylistAppBarPortalEntry({
    required this.owner,
    required this.title,
    required this.commandBar,
  });

  final Object owner;
  final String title;
  final Widget commandBar;
}
