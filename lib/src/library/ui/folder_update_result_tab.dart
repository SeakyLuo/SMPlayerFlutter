import 'package:flutter/widgets.dart';

enum FolderUpdateResultTab { added, removed, moved, artists }

class FolderUpdateResultTabItem {
  const FolderUpdateResultTabItem({
    required this.tab,
    required this.label,
    required this.count,
    required this.icon,
  });

  final FolderUpdateResultTab tab;
  final String label;
  final int count;
  final IconData icon;
}
