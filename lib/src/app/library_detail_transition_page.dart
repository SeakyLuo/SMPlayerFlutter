import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

const _libraryDetailEnterDuration = Duration(milliseconds: 260);
const _libraryDetailExitDuration = Duration(milliseconds: 200);

Page<void> smPlayerLibraryDetailPage({
  required BuildContext context,
  required LocalKey key,
  required Widget child,
}) {
  final animationsDisabled = MediaQuery.disableAnimationsOf(context);
  return CustomTransitionPage<void>(
    key: key,
    transitionDuration:
        animationsDisabled ? Duration.zero : _libraryDetailEnterDuration,
    reverseTransitionDuration:
        animationsDisabled ? Duration.zero : _libraryDetailExitDuration,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (MediaQuery.disableAnimationsOf(context)) {
        return child;
      }
      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeInOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(opacity: curvedAnimation, child: child);
    },
    child: child,
  );
}
