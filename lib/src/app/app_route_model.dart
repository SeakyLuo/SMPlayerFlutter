const restorableRoutes = {
  '/songs',
  '/artists',
  '/albums',
  '/now-playing',
  '/immersive-mode',
  '/recent',
  '/local',
  '/playlists',
  '/favorites',
};

String resolveRestoredPage(String lastPage) {
  final normalizedPath = lastPage.trim();
  final uri = Uri.tryParse(normalizedPath);
  final routePath = uri?.path ?? normalizedPath;
  return restorableRoutes.contains(routePath) ? routePath : '/songs';
}
