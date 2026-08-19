import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

const _libraryDetailEnterDuration = Duration(milliseconds: 240);
const _libraryDetailExitDuration = Duration(milliseconds: 200);
const _libraryDetailEnterOffset = 18.0;

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
      final direction =
          Directionality.of(context) == TextDirection.ltr ? 1.0 : -1.0;
      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      final offsetAnimation = Tween<double>(
        begin: _libraryDetailEnterOffset * direction,
        end: 0,
      ).animate(curvedAnimation);

      return FadeTransition(
        opacity: curvedAnimation,
        child: AnimatedBuilder(
          animation: offsetAnimation,
          builder:
              (context, child) => Transform.translate(
                offset: Offset(offsetAnimation.value, 0),
                child: child,
              ),
          child: child,
        ),
      );
    },
    child: child,
  );
}
