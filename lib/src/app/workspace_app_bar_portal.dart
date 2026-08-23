import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final workspaceAppBarPortalProvider =
    StateProvider<WorkspaceAppBarPortalEntry?>((ref) => null);

void clearWorkspaceAppBarPortalOwnerAfterDispose(
  StateController<WorkspaceAppBarPortalEntry?> notifier,
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

class WorkspaceAppBarPortalEntry {
  const WorkspaceAppBarPortalEntry({
    required this.owner,
    required this.routePath,
    required this.content,
    this.routeLocation,
    this.title,
    this.titleTooltip,
    this.bottomContent,
    this.bottomPadding,
    this.replacesTitle = false,
  });

  final Object owner;
  final String routePath;
  final String? routeLocation;
  final Widget content;
  final String? title;
  final String? titleTooltip;
  final Widget? bottomContent;
  final double? bottomPadding;
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
