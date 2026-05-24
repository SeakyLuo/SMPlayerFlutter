import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

const nowPlayingFullRoutePath = '/now-playing/full';
const nowPlayingRoutePath = '/now-playing';

String nowPlayingFullRouteFrom(String currentLocation) {
  return Uri(
    path: nowPlayingFullRoutePath,
    queryParameters: {'from': currentLocation},
  ).toString();
}

String nowPlayingFullReturnLocation(BuildContext context) {
  return nowPlayingFullReturnLocationFromLocation(
    GoRouterState.of(context).uri.toString(),
  );
}

String nowPlayingFullReturnLocationFromLocation(String location) {
  return Uri.parse(location).queryParameters['from'] ?? nowPlayingRoutePath;
}
