import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final workspaceAppBarPortalProvider =
    StateProvider<WorkspaceAppBarPortalEntry?>((ref) => null);

class WorkspaceAppBarPortalEntry {
  const WorkspaceAppBarPortalEntry({
    required this.owner,
    required this.routePath,
    required this.content,
    this.routeLocation,
    this.title,
    this.bottomContent,
    this.replacesTitle = false,
  });

  final Object owner;
  final String routePath;
  final String? routeLocation;
  final Widget content;
  final String? title;
  final Widget? bottomContent;
  final bool replacesTitle;
}

class WorkspaceNavigationAppBarScope extends InheritedWidget {
  const WorkspaceNavigationAppBarScope({
    super.key,
    required this.active,
    required super.child,
  });

  final bool active;

  static bool of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<
              WorkspaceNavigationAppBarScope
            >()
            ?.active ??
        false;
  }

  @override
  bool updateShouldNotify(WorkspaceNavigationAppBarScope oldWidget) {
    return oldWidget.active != active;
  }
}
